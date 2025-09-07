import SwiftUI
import CoreData

struct AddClassSlotView: View {
    let course: Course
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var calendarService: CalendarService
    
    @State private var slotType = "Lecture"
    @State private var dayOfWeek = 1
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // 1 hour later
    @State private var room = ""
    @State private var selectedInstructor: Instructor?
    @State private var addToCalendar = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Instructor.name, ascending: true)],
        animation: .default)
    private var instructors: FetchedResults<Instructor>
    
    private let slotTypes = ["Lecture", "Tutorial", "Lab", "Studio", "Seminar", "Workshop"]
    private let daysOfWeek = [
        (1, "Monday"),
        (2, "Tuesday"),
        (3, "Wednesday"),
        (4, "Thursday"),
        (5, "Friday"),
        (6, "Saturday"),
        (7, "Sunday")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Slot Details") {
                    Picker("Type", selection: $slotType) {
                        ForEach(slotTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    Picker("Day of Week", selection: $dayOfWeek) {
                        ForEach(daysOfWeek, id: \.0) { day in
                            Text(day.1).tag(day.0)
                        }
                    }
                }
                
                Section("Schedule") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    TextField("Room", text: $room)
                }
                
                Section("Instructor") {
                    Picker("Instructor", selection: $selectedInstructor) {
                        Text("Select Instructor").tag(nil as Instructor?)
                        ForEach(instructors, id: \.id) { instructor in
                            HStack {
                                Text(instructor.name ?? "Unknown")
                                if let role = instructor.role {
                                    Text("(\(role))")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(instructor as Instructor?)
                        }
                    }
                }
                
                Section {
                    Toggle("Add to Calendar", isOn: $addToCalendar)
                }
                
                Section {
                    Button("Add Class Slot") {
                        addClassSlot()
                    }
                    .disabled(room.isEmpty)
                }
            }
            .navigationTitle("Add Class Slot")
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
    
    private func addClassSlot() {
        guard !room.isEmpty else {
            errorMessage = "Please enter a room"
            showingError = true
            return
        }
        
        let newSlot = ClassSlot(context: viewContext)
        newSlot.id = UUID()
        newSlot.slotType = slotType
        newSlot.dayOfWeek = Int16(dayOfWeek)
        newSlot.startTime = startTime
        newSlot.endTime = endTime
        newSlot.room = room
        newSlot.course = course
        newSlot.instructor = selectedInstructor
        
        do {
            try viewContext.save()
            
            // Add to calendar if requested
            if addToCalendar {
                calendarService.addClassSlotToCalendar(slot: newSlot)
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to save class slot: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct AddClassSlotView_Previews: PreviewProvider {
    static var previews: some View {
        AddClassSlotView(course: Course())
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(CalendarService())
    }
}
