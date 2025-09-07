import SwiftUI
import CoreData
import EventKit

struct CalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var moodleService: MoodleService
    @StateObject private var calendarHelper = CalendarHelper.shared

    @State private var selectedDate = Date()
    @State private var showingAddEvent = false
    @State private var showingAddClass = false
    @State private var showingMoodleSync = false
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                calendarHeader
                
                // Calendar Grid
                calendarGrid
                
                // Events for selected date
                eventsList
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingMoodleSync = true }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddEvent = true }) {
                            Label("Add Event", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showingAddClass = true }) {
                            Label("Add Class", systemImage: "graduationcap")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView()
            }
            .sheet(isPresented: $showingAddClass) {
                AddClassView()
            }
            .sheet(isPresented: $showingMoodleSync) {
                MoodleSyncView()
            }
        }
    }
    
    // MARK: - Calendar Header
    private var calendarHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(dateFormatter.string(from: selectedDate))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(getWeekdayHeaders(), id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .background(Color(.systemGray6))
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(getDaysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendarHelper.isSameDay(date, selectedDate),
                            hasEvents: hasEvents(for: date),
                            hasClasses: hasClasses(for: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Events List
    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Events for \(selectedDate, formatter: dayFormatter)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(eventsForSelectedDate.count) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            let classSlotsForDate = getClassSlots(for: selectedDate)
            
            if eventsForSelectedDate.isEmpty && classSlotsForDate.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No events scheduled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Add Event") {
                        showingAddEvent = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Show class slots first
                        ForEach(classSlotsForDate, id: \.id) { slot in
                            NavigationLink(destination: CourseDetailView(course: slot.course!)) {
                                ClassSlotEventRow(slot: slot)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Then show calendar events
                        ForEach(eventsForSelectedDate, id: \.eventIdentifier) { event in
                            EKEventRow(event: event)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Computed Properties
    private var daysInMonth: [Date?] {
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
        
        var days: [Date?] = []
        
        // Add empty cells for days before the first day of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add all days in the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private var eventsForSelectedDate: [EKEvent] {
        calendarService.getEventsForDate(selectedDate)
    }
    
    // MARK: - Helper Methods
    private func hasEvents(for date: Date) -> Bool {
        !calendarService.getEventsForDate(date).isEmpty
    }
    
    private func hasClasses(for date: Date) -> Bool {
        // Check if there are class slots on this date
        return !getClassSlots(for: date).isEmpty
    }
    
    private func getClasses(for date: Date) -> [Course] {
        // Get all classes and filter by their slots
        let fetchRequest: NSFetchRequest<Course> = Course.fetchRequest()
        
        do {
            let allClasses = try viewContext.fetch(fetchRequest)
            return allClasses.filter { classItem -> Bool in
                // Check if any slot of this class falls on the given date
                return classItem.slotsArray.contains { slot in
                    guard let slotDate = slot.startTime else { return false }
                    let slotDayOfWeek = Calendar.current.component(.weekday, from: slotDate)
                    let targetDayOfWeek = Calendar.current.component(.weekday, from: date)
                    return slotDayOfWeek == targetDayOfWeek
                }
            }
        } catch {
            return []
        }
    }
    
    private func getClassSlots(for date: Date) -> [ClassSlot] {
        let fetchRequest: NSFetchRequest<ClassSlot> = ClassSlot.fetchRequest()
        let dayOfWeek = calendarHelper.getDayOfWeek(for: date)
        fetchRequest.predicate = NSPredicate(format: "dayOfWeek == %d", dayOfWeek)
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            return []
        }
    }
    
    private func getWeekdayHeaders() -> [String] {
        let calendar = calendarHelper.getConfiguredCalendar()
        return calendar.shortWeekdaySymbols
    }
    
    private func getDaysInMonth() -> [Date?] {
        let calendar = calendarHelper.getConfiguredCalendar()
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        
        var days: [Date?] = []
        
        // Add empty cells for days before the first day of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add all days in the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasEvents: Bool
    let hasClasses: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
            
            // Event indicators
            HStack(spacing: 2) {
                if hasClasses {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                }
                
                if hasEvents {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(height: 50)
    }
}

// MARK: - Event Row
struct EKEventRow: View {
    let event: EKEvent
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // Time
            VStack(alignment: .leading, spacing: 2) {
                Text(timeFormatter.string(from: event.startDate))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Text(timeFormatter.string(from: event.endDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .leading)
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled Event")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Calendar color indicator
            if let calendar = event.calendar {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Class Slot Event Row
struct ClassSlotEventRow: View {
    let slot: ClassSlot
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // Class indicator
            Image(systemName: "graduationcap.fill")
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            // Time
            VStack(alignment: .leading, spacing: 2) {
                if let startTime = slot.startTime {
                    Text(timeFormatter.string(from: startTime))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                if let endTime = slot.endTime {
                    Text(timeFormatter.string(from: endTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, alignment: .leading)
            
            // Class details
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.course?.courseName ?? "Unknown Course")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let slotType = slot.slotType {
                        Text(slotType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let room = slot.room {
                        Text("Room \(room)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Formatters
private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d"
    return formatter
}()

// MARK: - Preview
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(CalendarService())
            .environmentObject(MoodleService())
    }
}
