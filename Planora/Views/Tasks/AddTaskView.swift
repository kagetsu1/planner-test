import SwiftUI
import CoreData

struct AddTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationService: NotificationService
    
    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var priority = "Medium"
    @State private var selectedClass: Course?
    @State private var addReminder = true
    @State private var reminderTime = 60 // minutes before
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Course.courseName, ascending: true)],
        animation: .default)
    private var classes: FetchedResults<Course>
    
    private let priorities = ["Low", "Medium", "High"]
    private let reminderOptions = [15, 30, 60, 120, 1440] // minutes before
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task Title", text: $title)
                    
                    if #available(iOS 16.0, *) {
                        TextField("Notes (Optional)", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        TextField("Notes (Optional)", text: $notes)
                            .lineLimit(3)
                    }
                }
                
                Section("Due Date") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(priorities, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priorityColor(for: priority))
                                    .frame(width: 12, height: 12)
                                Text(priority)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Course (Optional)") {
                    Picker("Course", selection: $selectedClass) {
                        Text("No Course").tag(nil as Course?)
                        ForEach(classes, id: \.objectID) { classItem in
                            Text(classItem.courseName ?? "Unknown Course").tag(classItem as Course?)
                        }
                    }
                }
                
                Section("Reminder") {
                    Toggle("Add Reminder", isOn: $addReminder)
                    
                    if addReminder {
                        Picker("Remind me", selection: $reminderTime) {
                            ForEach(reminderOptions, id: \.self) { minutes in
                                Text(reminderText(for: minutes)).tag(minutes)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Add Task") {
                        addTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle("Add Task")
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
    
    private func addTask() {
        guard !title.isEmpty else {
            errorMessage = "Please enter a task title"
            showingError = true
            return
        }
        
        let newTask = Task(context: viewContext)
        newTask.id = UUID()
        newTask.title = title
        newTask.notes = notes.isEmpty ? nil : notes
        newTask.dueDate = dueDate
        // Convert priority string to Int16
        switch priority {
        case "Low":
            newTask.priority = 0
        case "Medium":
            newTask.priority = 1
        case "High":
            newTask.priority = 2
        default:
            newTask.priority = 1
        }
        newTask.completed = false
        newTask.createdAt = Date()
        newTask.updatedAt = Date()
        
        // Associate with course if selected
        if let selectedClass = selectedClass {
            newTask.course = selectedClass
        }
        
        do {
            try viewContext.save()
            
            // Add reminder if requested
            if addReminder {
                notificationService.scheduleTaskNotification(newTask)
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to save task: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func priorityColor(for priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }
    
    private func reminderText(for minutes: Int) -> String {
        switch minutes {
        case 15: return "15 minutes before"
        case 30: return "30 minutes before"
        case 60: return "1 hour before"
        case 120: return "2 hours before"
        case 1440: return "1 day before"
        default: return "\(minutes) minutes before"
        }
    }
}

struct AddTaskView_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(NotificationService())
    }
}
