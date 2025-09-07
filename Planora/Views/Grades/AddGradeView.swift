import SwiftUI
import CoreData

struct AddGradeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var assignmentName = ""
    @State private var assignmentType = "Assignment"
    @State private var score = ""
    @State private var totalPoints = ""
    @State private var selectedClass: Course?
    @State private var dueDate = Date()
    @State private var notes = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Course.courseName, ascending: true)],
        animation: .default)
    private var classes: FetchedResults<Course>
    
    private let assignmentTypes = ["Assignment", "Quiz", "Project", "Midterm", "Final", "Lab", "Participation", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Assignment Details") {
                    TextField("Assignment Name", text: $assignmentName)
                    
                    Picker("Type", selection: $assignmentType) {
                        ForEach(assignmentTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                
                Section("Grade") {
                    HStack {
                        TextField("Score", text: $score)
                            .keyboardType(.decimalPad)
                        
                        Text("/")
                            .foregroundColor(.secondary)
                        
                        TextField("Total Points", text: $totalPoints)
                            .keyboardType(.decimalPad)
                    }
                    
                    if let percentage = calculatedPercentage {
                        HStack {
                            Text("Percentage:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", percentage))
                                .fontWeight(.semibold)
                                .foregroundColor(gradeColor(for: percentage))
                        }
                    }
                }
                
                Section("Course") {
                    Picker("Course", selection: $selectedClass) {
                        Text("Select Course").tag(nil as Course?)
                        ForEach(classes, id: \.id) { course in
                            Text(course.courseName ?? "Unknown Course").tag(course as Course?)
                        }
                    }
                }
                
                Section("Notes (Optional)") {
                    if #available(iOS 16.0, *) {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        TextField("Notes", text: $notes)
                            .lineLimit(3)
                    }
                }
                
                Section {
                    Button("Add Grade") {
                        addGrade()
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Add Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var calculatedPercentage: Double? {
        guard let scoreValue = Double(score),
              let totalValue = Double(totalPoints),
              totalValue > 0 else { return nil }
        
        return (scoreValue / totalValue) * 100
    }
    
    private var canSave: Bool {
        !assignmentName.isEmpty &&
        !score.isEmpty &&
        !totalPoints.isEmpty &&
        selectedClass != nil &&
        Double(score) != nil &&
        Double(totalPoints) != nil
    }
    
    private func addGrade() {
        guard !assignmentName.isEmpty else {
            errorMessage = "Please enter an assignment name"
            showingError = true
            return
        }
        
        guard let scoreValue = Double(score) else {
            errorMessage = "Please enter a valid score"
            showingError = true
            return
        }
        
        guard let totalValue = Double(totalPoints), totalValue > 0 else {
            errorMessage = "Please enter a valid total points"
            showingError = true
            return
        }
        
        guard let selectedClass = selectedClass else {
            errorMessage = "Please select a course"
            showingError = true
            return
        }
        
        let newGrade = Grade(context: viewContext)
        newGrade.id = UUID()
        newGrade.name = assignmentName
        newGrade.assignmentType = assignmentType
        newGrade.score = scoreValue
        newGrade.totalPoints = totalValue
        newGrade.dueDate = dueDate
        newGrade.notes = notes.isEmpty ? nil : notes
        newGrade.createdAt = Date()
        newGrade.updatedAt = Date()
        newGrade.course = selectedClass
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save grade: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func gradeColor(for percentage: Double) -> Color {
        switch percentage {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }
}

struct AddGradeView_Previews: PreviewProvider {
    static var previews: some View {
        AddGradeView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
    }
}
