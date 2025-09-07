import Foundation
import EventKit
import CoreData

/// Bridge service for EventKit integration
class EventKitBridge: ObservableObject {
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    
    private let eventStore = EKEventStore()
    
    private var ctx: NSManagedObjectContext {
        DataController.shared.container.viewContext
    }
    
    init() {
        checkAuthorizationStatus()
    }
    
    /// Check current EventKit authorization status
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    /// Request access to EventKit
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            await MainActor.run {
                self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            return granted
        } catch {
            print("EventKit access request failed: \(error)")
            return false
        }
    }
    
    /// Create an event in the default calendar
    func createEvent(title: String, startDate: Date, endDate: Date?, location: String? = nil, notes: String? = nil, recurrenceRule: EKRecurrenceRule? = nil) async throws -> String {
        guard authorizationStatus == .authorized else {
            throw EventKitError.notAuthorized
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600) // Default 1 hour
        event.location = location
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        if let recurrenceRule = recurrenceRule {
            event.recurrenceRules = [recurrenceRule]
        }
        
        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }
    
    /// Update an existing event
    func updateEvent(eventId: String, title: String? = nil, startDate: Date? = nil, endDate: Date? = nil, location: String? = nil, notes: String? = nil) async throws {
        guard authorizationStatus == .authorized else {
            throw EventKitError.notAuthorized
        }
        
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw EventKitError.eventNotFound
        }
        
        if let title = title { event.title = title }
        if let startDate = startDate { event.startDate = startDate }
        if let endDate = endDate { event.endDate = endDate }
        if let location = location { event.location = location }
        if let notes = notes { event.notes = notes }
        
        try eventStore.save(event, span: .thisEvent)
    }
    
    /// Delete an event
    func deleteEvent(eventId: String) async throws {
        guard authorizationStatus == .authorized else {
            throw EventKitError.notAuthorized
        }
        
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw EventKitError.eventNotFound
        }
        
        try eventStore.remove(event, span: .thisEvent)
    }
    
    /// Fetch events for a date range
    func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard authorizationStatus == .authorized else { return [] }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    /// Sync tasks to calendar as time blocks
    func syncTasksToCalendar(_ tasks: [Task]) async throws {
        guard authorizationStatus == .authorized else {
            throw EventKitError.notAuthorized
        }
        
        for task in tasks {
            guard task.showOnCalendar,
                  let dueDate = task.dueDate,
                  let title = task.title else { continue }
            
            // Check if event already exists for this task
            let eventTitle = "📝 \(title)"
            let predicate = eventStore.predicateForEvents(
                withStart: Calendar.current.startOfDay(for: dueDate),
                end: Calendar.current.date(byAdding: .day, value: 1, to: dueDate) ?? dueDate,
                calendars: nil
            )
            
            let existingEvents = eventStore.events(matching: predicate).filter { $0.title == eventTitle }
            
            if existingEvents.isEmpty {
                // Create new time block
                let duration: TimeInterval = 3600 // 1 hour default
                let startTime = dueDate
                let endTime = startTime.addingTimeInterval(duration)
                
                let event = EKEvent(eventStore: eventStore)
                event.title = eventTitle
                event.startDate = startTime
                event.endDate = endTime
                event.notes = task.notes
                event.calendar = eventStore.defaultCalendarForNewEvents
                
                try eventStore.save(event, span: .thisEvent)
            }
        }
    }
    
    /// Create a recurrence rule from string description
    func createRecurrenceRule(from description: String) -> EKRecurrenceRule? {
        let lowercased = description.lowercased()
        
        if lowercased.contains("daily") || lowercased.contains("every day") {
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        } else if lowercased.contains("weekly") || lowercased.contains("every week") {
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        } else if lowercased.contains("monthly") || lowercased.contains("every month") {
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        } else if lowercased.contains("yearly") || lowercased.contains("every year") {
            return EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        }
        
        // Parse specific days
        let daysMap: [String: EKWeekday] = [
            "monday": .monday,
            "tuesday": .tuesday,
            "wednesday": .wednesday,
            "thursday": .thursday,
            "friday": .friday,
            "saturday": .saturday,
            "sunday": .sunday,
            "mon": .monday,
            "tue": .tuesday,
            "wed": .wednesday,
            "thu": .thursday,
            "fri": .friday,
            "sat": .saturday,
            "sun": .sunday
        ]
        
        for (dayName, weekday) in daysMap {
            if lowercased.contains(dayName) {
                return EKRecurrenceRule(
                    recurrenceWith: .weekly,
                    interval: 1,
                    daysOfTheWeek: [EKRecurrenceDayOfWeek(weekday)],
                    daysOfTheMonth: nil,
                    monthsOfTheYear: nil,
                    weeksOfTheYear: nil,
                    daysOfTheYear: nil,
                    setPositions: nil,
                    end: nil
                )
            }
        }
        
        return nil
    }
    
    /// Convert CalendarEvent entities to EKEvents for unified display
    func convertToEKEvents(_ calendarEvents: [CalendarEvent]) -> [EKEvent] {
        return calendarEvents.compactMap { calendarEvent in
            guard let title = calendarEvent.title,
                  let start = calendarEvent.start else { return nil }
            
            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.startDate = start
            event.endDate = calendarEvent.end ?? start.addingTimeInterval(3600)
            event.location = calendarEvent.location
            event.notes = calendarEvent.notes
            
            return event
        }
    }
    
    /// Get calendar events from Core Data and EventKit for unified view
    func getUnifiedEvents(from startDate: Date, to endDate: Date) -> [UnifiedEvent] {
        var unifiedEvents: [UnifiedEvent] = []
        
        // Get EventKit events
        if authorizationStatus == .authorized {
            let ekEvents = fetchEvents(from: startDate, to: endDate)
            unifiedEvents.append(contentsOf: ekEvents.map { event in
                UnifiedEvent(
                    id: event.eventIdentifier,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    notes: event.notes,
                    source: .eventKit,
                    courseId: nil,
                    meetingURL: nil
                )
            })
        }
        
        // Get Core Data calendar events
        let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        request.predicate = NSPredicate(format: "start >= %@ AND start <= %@", startDate as NSDate, endDate as NSDate)
        
        do {
            let calendarEvents = try ctx.fetch(request)
            unifiedEvents.append(contentsOf: calendarEvents.map { event in
                UnifiedEvent(
                    id: event.id?.uuidString ?? UUID().uuidString,
                    title: event.title ?? "Event",
                    startDate: event.start ?? Date(),
                    endDate: event.end,
                    location: event.location,
                    notes: event.notes,
                    source: EventSource(rawValue: event.source ?? "local") ?? .local,
                    courseId: event.courseId,
                    meetingURL: event.meetingURL
                )
            })
        } catch {
            print("Error fetching calendar events: \(error)")
        }
        
        return unifiedEvents.sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Data Models

struct UnifiedEvent {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let location: String?
    let notes: String?
    let source: EventSource
    let courseId: String?
    let meetingURL: String?
}

enum EventSource: String, CaseIterable {
    case eventKit = "eventkit"
    case moodle = "moodle"
    case local = "local"
    case device = "device"
}

enum EventKitError: LocalizedError {
    case notAuthorized
    case eventNotFound
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access not authorized"
        case .eventNotFound:
            return "Event not found"
        case .saveFailed(let error):
            return "Failed to save event: \(error.localizedDescription)"
        }
    }
}
