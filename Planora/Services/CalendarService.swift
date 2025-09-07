import Foundation
import EventKit
import Combine

class CalendarService: ObservableObject {
    @Published var isAuthorized = false
    @Published var events: [EKEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    func initialize() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAccess() {
        isLoading = true
        
        if #available(iOS 17.0, *) {
            _Concurrency.Task {
                do {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    self.isAuthorized = granted
                    self.isLoading = false
                    if granted {
                        self.fetchEvents()
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    self?.isLoading = false
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else if granted {
                        self?.fetchEvents()
                    }
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        if #available(iOS 17.0, *) {
            isAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } else {
            isAuthorized = EKEventStore.authorizationStatus(for: .event) == .authorized
        }
        
        if isAuthorized {
            fetchEvents()
        }
    }
    
    // MARK: - Event Management
    func fetchEvents() {
        guard isAuthorized else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.startOfDay(for: now)
        let endDate = calendar.date(byAdding: .month, value: 3, to: startDate) ?? now
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let fetchedEvents = eventStore.events(matching: predicate)
        
        DispatchQueue.main.async {
            self.events = fetchedEvents
        }
    }
    
    func addEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil, location: String? = nil) {
        guard isAuthorized else { return }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.location = location
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            fetchEvents()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func updateEvent(_ event: EKEvent) {
        guard isAuthorized else { return }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            fetchEvents()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func deleteEvent(_ event: EKEvent) {
        guard isAuthorized else { return }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
            fetchEvents()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Class Integration
    func addClassToCalendar(course: Course) {
        // This method is now deprecated - use addClassSlotToCalendar instead
        // Keeping for backward compatibility
    }
    
    func addClassSlotToCalendar(slot: ClassSlot) {
        guard let startTime = slot.startTime,
              let endTime = slot.endTime,
              let courseName = slot.course?.courseName else {
            return
        }
        
        let title = "\(courseName) - \(slot.slotType ?? "Class")"
        let location = slot.room ?? ""
        
        var notes = ""
        if let instructor = slot.instructor?.name {
            notes += "Instructor: \(instructor)\n"
        }
        if let courseCode = slot.course?.courseCode {
            notes += "Course Code: \(courseCode)\n"
        }
        notes += "Type: \(slot.slotType ?? "")"
        
        addEvent(title: title, startDate: startTime, endDate: endTime, notes: notes, location: location)
    }
    
    // MARK: - Google Calendar Integration
    func syncWithGoogleCalendar() {
        // This would implement Google Calendar API integration
        // Requires Google Calendar API setup and OAuth2 authentication
    }
    
    // MARK: - Meeting Integration
    func addZoomMeeting(title: String, startDate: Date, endDate: Date, meetingURL: String, password: String? = nil) {
        let notes = """
        Zoom Meeting
        URL: \(meetingURL)
        Password: \(password ?? "No password required")
        """
        
        addEvent(title: title, startDate: startDate, endDate: endDate, notes: notes)
    }
    
    func addGoogleMeet(title: String, startDate: Date, endDate: Date, meetingURL: String) {
        let notes = """
        Google Meet
        URL: \(meetingURL)
        """
        
        addEvent(title: title, startDate: startDate, endDate: endDate, notes: notes)
    }
    
    // MARK: - Utility Methods
    func getEventsForDate(_ date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    func getUpcomingEvents(limit: Int = 10) -> [EKEvent] {
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let upcomingEvents = eventStore.events(matching: predicate)
        
        return Array(upcomingEvents.prefix(limit))
    }
}
