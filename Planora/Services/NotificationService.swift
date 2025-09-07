import Foundation
import UserNotifications
import CoreData

/// Service for managing local notifications for tasks and events
class NotificationService: ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var settings: NotificationSettings = NotificationSettings()
    
    var isAuthorized: Bool {
        return authorizationStatus == .authorized
    }
    
    // MARK: - Task Notifications
    func cancelTaskReminders(for task: Task) {
        // Cancel existing notifications for this task
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["task_\(task.objectID)"])
    }
    
    func scheduleTaskReminder(for task: Task) {
        guard let dueDate = task.dueDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = task.title ?? "You have a task due soon"
        content.sound = .default
        
        let triggerDate = Calendar.current.dateInterval(of: .hour, for: dueDate)?.start.addingTimeInterval(-3600) // 1 hour before
        guard let trigger = triggerDate else { return }
        
        let triggerComponent = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: trigger)
        let notificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerComponent, repeats: false)
        
        let request = UNNotificationRequest(identifier: "task_\(task.objectID)", content: content, trigger: notificationTrigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule task reminder: \(error)")
            }
        }
    }
    
    func scheduleTaskDueNotification(for task: Task) {
        guard let dueDate = task.dueDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = "\(task.title ?? "Task") is due now!"
        content.sound = .default
        
        let triggerComponent = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let notificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerComponent, repeats: false)
        
        let request = UNNotificationRequest(identifier: "task_due_\(task.objectID)", content: content, trigger: notificationTrigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule task due notification: \(error)")
            }
        }
    }
    
    // MARK: - Habit Notifications
    func scheduleHabitReminder(for habit: Habit) {
        // Schedule daily reminder for habit
        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder"
        content.body = "Don't forget to complete: \(habit.name ?? "your habit")"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 9 // 9 AM reminder
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "habit_\(habit.objectID)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule habit reminder: \(error)")
            }
        }
    }
    
    private let center = UNUserNotificationCenter.current()
    private let userDefaultsKey = "NotificationSettings"
    
    init() {
        loadSettings()
        checkAuthorizationStatus()
        setupNotificationCategories()
    }
    
    // MARK: - Authorization
    
    /// Request notification permission
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                checkAuthorizationStatus()
            }
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    /// Schedule notification for a task
    func scheduleTaskNotification(_ task: Task) {
        guard authorizationStatus == .authorized else { return }
        guard let dueDate = task.dueDate else { return }
        guard let title = task.title, !title.isEmpty else { return }
        
        let identifier = "task-\(task.id?.uuidString ?? UUID().uuidString)"
        
        // Calculate notification time based on settings
        let notificationDate = calculateNotificationDate(for: dueDate, leadTime: settings.taskLeadTime)
        
        // Don't schedule if notification time is in the past
        guard notificationDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due Soon"
        content.body = title
        content.sound = settings.soundEnabled ? .default : nil
        content.categoryIdentifier = "TASK_REMINDER"
        
        // Add priority info to userInfo
        content.userInfo = [
            "type": "task",
            "taskId": task.id?.uuidString ?? "",
            "priority": task.priority
        ]
        
        // Create trigger
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule notification
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule task notification: \(error)")
            }
        }
    }
    
    /// Schedule notification for an event
    func scheduleEventNotification(_ event: UnifiedEvent) {
        guard authorizationStatus == .authorized else { return }
        
        let identifier = "event-\(event.id)"
        
        // Calculate notification time based on settings
        let notificationDate = calculateNotificationDate(for: event.startDate, leadTime: settings.eventLeadTime)
        
        // Don't schedule if notification time is in the past
        guard notificationDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Event Starting Soon"
        content.body = event.title
        content.sound = settings.soundEnabled ? .default : nil
        content.categoryIdentifier = "EVENT_REMINDER"
        
        // Add event info to userInfo
        content.userInfo = [
            "type": "event",
            "eventId": event.id,
            "source": event.source.rawValue,
            "hasConferenceLink": event.meetingURL != nil
        ]
        
        // Create trigger
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule notification
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule event notification: \(error)")
            }
        }
    }
    
    /// Schedule notification for next class
    func scheduleNextClassNotification(_ session: AttendanceSession) {
        guard authorizationStatus == .authorized else { return }
        guard let startDate = session.start else { return }
        
        let identifier = "class-\(session.id)"
        
        // Notify 15 minutes before class starts
        let notificationDate = startDate.addingTimeInterval(-900) // 15 minutes before
        
        // Don't schedule if notification time is in the past
        guard notificationDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Class Starting Soon"
        content.body = "Your class starts in 15 minutes"
        content.sound = settings.soundEnabled ? .default : nil
        content.categoryIdentifier = "CLASS_REMINDER"
        
        // Add session info to userInfo
        content.userInfo = [
            "type": "class",
            "sessionId": session.id,
            "courseId": session.courseId ?? "",
            "requiresCheckin": session.requiresPasscode
        ]
        
        // Create trigger
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule notification
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule class notification: \(error)")
            }
        }
    }
    
    /// Cancel notification for a task
    func cancelTaskNotification(_ task: Task) {
        let identifier = "task-\(task.id?.uuidString ?? "")"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// Cancel notification for an event
    func cancelEventNotification(_ eventId: String) {
        let identifier = "event-\(eventId)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// Cancel all pending notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Bulk Operations
    
    /// Schedule notifications for all upcoming tasks
    func scheduleNotificationsForTasks(_ tasks: [Task]) {
        for task in tasks {
            if !task.isCompleted && !task.completed {
                scheduleTaskNotification(task)
            }
        }
    }
    
    /// Schedule notifications for all upcoming events
    func scheduleNotificationsForEvents(_ events: [UnifiedEvent]) {
        for event in events {
            scheduleEventNotification(event)
        }
    }
    
    /// Reschedule all notifications (useful after settings change)
    func rescheduleAllNotifications() {
        // Cancel existing notifications
        cancelAllNotifications()
        
        // Fetch and reschedule tasks
        let context = DataController.shared.container.viewContext
        let taskRequest: NSFetchRequest<Task> = Task.fetchRequest()
        taskRequest.predicate = NSPredicate(format: "isCompleted == NO AND dueDate >= %@", Date() as NSDate)
        
        do {
            let tasks = try context.fetch(taskRequest)
            scheduleNotificationsForTasks(tasks)
        } catch {
            print("Failed to fetch tasks for rescheduling: \(error)")
        }
        
        // Fetch and reschedule calendar events
        let eventRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        eventRequest.predicate = NSPredicate(format: "start >= %@ AND start <= %@", Date() as NSDate, weekFromNow as NSDate)
        
        do {
            let calendarEvents = try context.fetch(eventRequest)
            let unifiedEvents = calendarEvents.compactMap { event -> UnifiedEvent? in
                guard let title = event.title,
                      let start = event.start else { return nil }
                
                return UnifiedEvent(
                    id: event.id?.uuidString ?? UUID().uuidString,
                    title: title,
                    startDate: start,
                    endDate: event.end,
                    location: event.location,
                    notes: event.notes,
                    source: EventSource(rawValue: event.source ?? "local") ?? .local,
                    courseId: event.courseId,
                    meetingURL: event.meetingURL
                )
            }
            
            scheduleNotificationsForEvents(unifiedEvents)
        } catch {
            print("Failed to fetch events for rescheduling: \(error)")
        }
    }
    
    // MARK: - Settings
    
    /// Update notification settings
    func updateSettings(_ newSettings: NotificationSettings) {
        settings = newSettings
        saveSettings()
        
        // Reschedule notifications with new settings
        rescheduleAllNotifications()
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedSettings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            settings = decodedSettings
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateNotificationDate(for targetDate: Date, leadTime: TimeInterval) -> Date {
        return targetDate.addingTimeInterval(-leadTime)
    }
    
    private func setupNotificationCategories() {
        // Task reminder category with snooze actions
        let snooze10Action = UNNotificationAction(
            identifier: "SNOOZE_10",
            title: "Snooze 10m",
            options: []
        )
        
        let snooze30Action = UNNotificationAction(
            identifier: "SNOOZE_30",
            title: "Snooze 30m",
            options: []
        )
        
        let snooze1hAction = UNNotificationAction(
            identifier: "SNOOZE_1H",
            title: "Snooze 1h",
            options: []
        )
        
        let taskCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [snooze10Action, snooze30Action, snooze1hAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Event reminder category
        let joinAction = UNNotificationAction(
            identifier: "JOIN_EVENT",
            title: "Join",
            options: [.foreground]
        )
        
        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [joinAction, snooze10Action],
            intentIdentifiers: [],
            options: []
        )
        
        // Class reminder category
        let checkinAction = UNNotificationAction(
            identifier: "CHECK_IN",
            title: "Check In",
            options: [.foreground]
        )
        
        let classCategory = UNNotificationCategory(
            identifier: "CLASS_REMINDER",
            actions: [checkinAction, snooze10Action],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([taskCategory, eventCategory, classCategory])
    }
    
    /// Handle notification action
    func handleNotificationAction(_ actionIdentifier: String, notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        switch actionIdentifier {
        case "SNOOZE_10":
            snoozeNotification(notification, minutes: 10)
        case "SNOOZE_30":
            snoozeNotification(notification, minutes: 30)
        case "SNOOZE_1H":
            snoozeNotification(notification, minutes: 60)
        case "JOIN_EVENT":
            handleJoinEvent(userInfo)
        case "CHECK_IN":
            handleCheckIn(userInfo)
        default:
            break
        }
    }
    
    private func snoozeNotification(_ notification: UNNotification, minutes: Int) {
        let content = notification.request.content.mutableCopy() as! UNMutableNotificationContent
        let newDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: newDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "\(notification.request.identifier)-snoozed",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to snooze notification: \(error)")
            }
        }
    }
    
    private func handleJoinEvent(_ userInfo: [AnyHashable: Any]) {
        // This would trigger the app to open and join the event
        NotificationCenter.default.post(
            name: .joinEventFromNotification,
            object: nil,
            userInfo: userInfo
        )
    }
    
    private func handleCheckIn(_ userInfo: [AnyHashable: Any]) {
        // This would trigger the app to open and show check-in
        NotificationCenter.default.post(
            name: .checkInFromNotification,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - Data Models

struct NotificationSettings: Codable {
    var notificationsEnabled: Bool = true
    var soundEnabled: Bool = true
    var taskLeadTime: TimeInterval = 3600 // 1 hour before
    var eventLeadTime: TimeInterval = 900 // 15 minutes before
    var classNotificationsEnabled: Bool = true
    var weekendNotificationsEnabled: Bool = false
    var quietHoursStart: Date? = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())
    var quietHoursEnd: Date? = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())
    
    // Lead time options for UI
    static let leadTimeOptions: [(String, TimeInterval)] = [
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("2 hours", 7200),
        ("1 day", 86400)
    ]
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let joinEventFromNotification = Notification.Name("joinEventFromNotification")
    static let checkInFromNotification = Notification.Name("checkInFromNotification")
}

// MARK: - UNUserNotificationCenterDelegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let notificationService = NotificationService()
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        notificationService.handleNotificationAction(response.actionIdentifier, notification: response.notification)
        completionHandler()
    }
}