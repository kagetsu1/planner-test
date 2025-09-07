import SwiftUI
import CoreData

struct AddClassView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var calendarService: CalendarService
    
    @State private var courseName = ""
    @State private var courseCode = ""
    @State private var classType = "Lecture"
    @State private var room = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // 1 hour later
    @State private var professorName = ""
    @State private var professorEmail = ""
    @State private var professorOfficeHours = ""
    @State private var addToCalendar = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let classTypes = ["Lecture", "Tutorial", "Lab", "Studio"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Course Information") {
                    TextField("Course Name", text: $courseName)
                    TextField("Course Code", text: $courseCode)
                    
                    Picker("Class Type", selection: $classType) {
                        ForEach(classTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                Section("Schedule") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Time", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                    TextField("Room", text: $room)
                }
                
                Section("Professor") {
                    TextField("Professor Name", text: $professorName)
                    TextField("Professor Email", text: $professorEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Office Hours", text: $professorOfficeHours)
                }
                
                Section {
                    Toggle("Add to Calendar", isOn: $addToCalendar)
                }
                
                Section {
                    Button("Add Class") {
                        addClass()
                    }
                    .disabled(courseName.isEmpty)
                }
            }
            .navigationTitle("Add Class")
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
            .onChange(of: startTime) { newStartTime in
                if endTime <= newStartTime {
                    endTime = newStartTime.addingTimeInterval(3600)
                }
            }
        }
    }
    
    private func addClass() {
        guard !courseName.isEmpty else {
            errorMessage = "Please enter a course name"
            showingError = true
            return
        }
        
        let newCourse = Course(context: viewContext)
        newCourse.id = UUID()
        newCourse.courseName = courseName
        newCourse.courseCode = courseCode.isEmpty ? nil : courseCode
        newCourse.createdAt = Date()
        newCourse.updatedAt = Date()
        
        // Create class slot
        let newSlot = ClassSlot(context: viewContext)
        newSlot.id = UUID()
        newSlot.slotType = classType
        newSlot.room = room.isEmpty ? nil : room
        newSlot.startTime = startTime
        newSlot.endTime = endTime
        newSlot.course = newCourse
        
        // Create instructor if name is provided
        if !professorName.isEmpty {
            let instructor = Instructor(context: viewContext)
            instructor.id = UUID()
            instructor.name = professorName
            instructor.email = professorEmail.isEmpty ? nil : professorEmail
            instructor.officeHours = professorOfficeHours.isEmpty ? nil : professorOfficeHours
            newSlot.instructor = instructor
        }
        
        do {
            try viewContext.save()
            
            // Add to calendar if requested
            if addToCalendar {
                calendarService.addClassSlotToCalendar(slot: newSlot)
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to save class: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct AddClassView_Previews: PreviewProvider {
    static var previews: some View {
        AddClassView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(CalendarService())
    }
}
