import SwiftUI
import EventKit

struct AddEventView: View {
    @EnvironmentObject var calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 1 hour later
    @State private var location = ""
    @State private var notes = ""
    @State private var isAllDay = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                    
                    Toggle("All Day", isOn: $isAllDay)
                    
                    if !isAllDay {
                        DatePicker("Start Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    } else {
                        DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    }
                }
                
                Section("Location & Notes") {
                    TextField("Location (Optional)", text: $location)
                    
                                    if #available(iOS 16.0, *) {
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    TextField("Notes (Optional)", text: $notes)
                        .lineLimit(3)
                }
                }
                
                Section {
                    Button("Add Event") {
                        addEvent()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle("Add Event")
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
            .onChange(of: startDate) { newStartDate in
                if !isAllDay && endDate <= newStartDate {
                    endDate = newStartDate.addingTimeInterval(3600)
                }
            }
        }
    }
    
    private func addEvent() {
        guard !title.isEmpty else {
            errorMessage = "Please enter an event title"
            showingError = true
            return
        }
        
        let finalStartDate = isAllDay ? startDate : startDate
        let finalEndDate = isAllDay ? startDate : endDate
        
        calendarService.addEvent(
            title: title,
            startDate: finalStartDate,
            endDate: finalEndDate,
            notes: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location
        )
        
        dismiss()
    }
}

struct AddEventView_Previews: PreviewProvider {
    static var previews: some View {
        AddEventView()
            .environmentObject(CalendarService())
    }
}
