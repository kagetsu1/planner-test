//
// MoodleService.swift
// Complete service for Moodle API interactions including:
// - Courses, contents, assignments, grades, calendar events
// - Attendance plugin support with capability detection
// - Maps to Core Data entities with graceful fallbacks
//

import Foundation
import CoreData
import WebKit

struct MoodleConfig: Codable, Equatable {
    var baseURL: URL
    var token: String
}

@MainActor
final class MoodleService: NSObject, ObservableObject {
    @Published var isSyncing = false
    @Published var lastSync: Date?
    @Published var availableCapabilities: Set<String> = []

    var config: MoodleConfig?

    var isAuthenticated: Bool {
        return config != nil
    }

    private var ctx: NSManagedObjectContext {
        DataController.shared.container.viewContext
    }
    
    // Capability cache
    private var checkedCapabilities: [String: Bool] = [:]

    func updateConfig(baseURL: URL, token: String) {
        self.config = MoodleConfig(baseURL: baseURL, token: token)
    }

    // MARK: - Public entry
    func syncAll() async {
        guard let cfg = config else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Check capabilities first
            await checkCapabilities(cfg: cfg)
            
            let courses = try await fetchCourses(cfg: cfg)
            let classMap = try upsertClasses(from: courses)

            let assignmentsPayload = try await fetchAssignments(cfg: cfg, courseIds: courses.compactMap { $0["id"] as? Int })
            try upsertAssignments(from: assignmentsPayload, classMap: classMap)

            let gradesPayload = try await fetchGrades(cfg: cfg)
            try upsertGrades(from: gradesPayload, classMap: classMap)

            let calendarPayload = try await fetchCalendarEvents(cfg: cfg)
            try upsertCalendarEvents(from: calendarPayload, classMap: classMap)
            
            // Sync attendance if available
            if isCapabilityAvailable("mod_attendance_get_sessions") {
                let attendancePayload = try await fetchAttendanceSessions(cfg: cfg, courseIds: courses.compactMap { $0["id"] as? Int })
                try upsertAttendanceSessions(from: attendancePayload, classMap: classMap)
            }

            try ctx.save()
            lastSync = Date()
        } catch {
            print("Moodle sync failed: \(error)")
        }
    }

    // MARK: - Networking helper
    private func callJSON(_ cfg: MoodleConfig, function: String, params: [String: String]) async throws -> Any {
        var comps = URLComponents(url: cfg.baseURL.appendingPathComponent("/webservice/rest/server.php"), resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "wstoken", value: cfg.token),
            URLQueryItem(name: "moodlewsrestformat", value: "json"),
            URLQueryItem(name: "wsfunction", value: function),
        ]
        for (k,v) in params { items.append(URLQueryItem(name: k, value: v)) }
        comps.queryItems = items

        let (data, response) = try await URLSession.shared.data(from: comps.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONSerialization.jsonObject(with: data, options: [])
    }

    // MARK: - Endpoints
    private func fetchCourses(cfg: MoodleConfig) async throws -> [[String: Any]] {
        (try await callJSON(cfg, function: "core_enrol_get_users_courses", params: ["userid": "me"])) as? [[String: Any]] ?? []
    }

    private func fetchAssignments(cfg: MoodleConfig, courseIds: [Int]) async throws -> [String: Any] {
        var q: [String:String] = [:]
        for (i, id) in courseIds.enumerated() { q["courseids[\(i)]"] = String(id) }
        return (try await callJSON(cfg, function: "mod_assign_get_assignments", params: q)) as? [String: Any] ?? [:]
    }

    private func fetchGrades(cfg: MoodleConfig) async throws -> [[String: Any]] {
        (try await callJSON(cfg, function: "gradereport_user_get_grade_items", params: ["userid": "me"])) as? [[String: Any]] ?? []
    }

    private func fetchCalendarEvents(cfg: MoodleConfig) async throws -> [String: Any] {
        let to = Int(Date().addingTimeInterval(60*60*24*60).timeIntervalSince1970)
        let from = Int(Date().addingTimeInterval(-60*60*24*14).timeIntervalSince1970)
        return (try await callJSON(cfg, function: "core_calendar_get_calendar_events", params: [
            "options[timestart]": String(from),
            "options[timeend]": String(to),
            "options[userevents]": "1",
            "options[siteevents]": "1"
        ])) as? [String: Any] ?? [:]
    }
    
    // MARK: - Attendance API
    
    private func fetchAttendanceSessions(cfg: MoodleConfig, courseIds: [Int]) async throws -> [[String: Any]] {
        var allSessions: [[String: Any]] = []
        
        for courseId in courseIds {
            do {
                let sessions = try await callJSON(cfg, function: "mod_attendance_get_sessions", params: [
                    "courseid": String(courseId)
                ])
                
                if let sessionArray = sessions as? [[String: Any]] {
                    allSessions.append(contentsOf: sessionArray)
                }
            } catch {
                // If attendance plugin not available for this course, continue with others
                continue
            }
        }
        
        return allSessions
    }
    
    private func fetchAttendanceStatuses(cfg: MoodleConfig, courseId: Int) async throws -> [[String: Any]] {
        let result = try await callJSON(cfg, function: "mod_attendance_get_statuses", params: [
            "courseid": String(courseId)
        ])
        return result as? [[String: Any]] ?? []
    }
    
    func submitAttendance(sessionId: Int64, statusId: Int, passcode: String? = nil) async throws -> Bool {
        guard let cfg = config else { throw MoodleError.notAuthenticated }
        
        var params = [
            "sessionid": String(sessionId),
            "statusid": String(statusId)
        ]
        
        if let passcode = passcode {
            params["studentpassword"] = passcode
        }
        
        do {
            let result = try await callJSON(cfg, function: "mod_attendance_update_user_status", params: params)
            
            // Check if result indicates success
            if let resultDict = result as? [String: Any],
               let success = resultDict["success"] as? Bool {
                return success
            }
            
            // If no explicit success field, assume success if no exception
            return true
        } catch {
            throw error
        }
    }
    
    // MARK: - Capability Detection
    
    func checkCapabilities(cfg: MoodleConfig) async {
        let capabilities = [
            "mod_attendance_get_sessions",
            "mod_attendance_get_statuses", 
            "mod_attendance_update_user_status",
            "core_message_get_conversations",
            "core_message_send_messages_to_conversation"
        ]
        
        for capability in capabilities {
            let isAvailable = await checkCapability(cfg: cfg, function: capability)
            checkedCapabilities[capability] = isAvailable
            
            if isAvailable {
                availableCapabilities.insert(capability)
            } else {
                availableCapabilities.remove(capability)
            }
        }
    }
    
    private func checkCapability(cfg: MoodleConfig, function: String) async -> Bool {
        do {
            // Try to call the function with minimal parameters
            _ = try await callJSON(cfg, function: function, params: [:])
            return true
        } catch {
            // If function returns exception or 404, it's not available
            return false
        }
    }
    
    func isCapabilityAvailable(_ capability: String) -> Bool {
        return checkedCapabilities[capability] ?? false
    }
    
    func getFallbackURL(for feature: String, courseId: Int? = nil) -> URL? {
        guard let cfg = config else { return nil }
        
        switch feature {
        case "attendance":
            if let courseId = courseId {
                return cfg.baseURL.appendingPathComponent("/mod/attendance/view.php?id=\(courseId)")
            }
        case "messages":
            return cfg.baseURL.appendingPathComponent("/message/index.php")
        case "grades":
            if let courseId = courseId {
                return cfg.baseURL.appendingPathComponent("/grade/report/user/index.php?id=\(courseId)")
            }
        default:
            break
        }
        
        return cfg.baseURL
    }

    // MARK: - Upsert helpers
    private func upsertClasses(from courses: [[String: Any]]) throws -> [Int: Course] {
        var map: [Int: Course] = [:]
        for c in courses {
            guard let courseId = c["id"] as? Int else { continue }
            let fullName = (c["fullname"] as? String) ?? (c["displayname"] as? String) ?? "Course \(courseId)"
            let shortName = (c["shortname"] as? String) ?? ""

            // Find existing by code or name
            let req: NSFetchRequest<Course> = Course.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSPredicate(format: "courseCode == %@ OR courseName == %@", shortName, fullName)
            let existing = try ctx.fetch(req).first

            let obj = existing ?? Course(context: ctx)
            if existing == nil { obj.id = obj.id ?? UUID() }
            if obj.courseName != fullName { obj.courseName = fullName }
            if !shortName.isEmpty { obj.courseCode = shortName }
            map[courseId] = obj
        }
        return map
    }

    private func upsertAssignments(from payload: [String: Any], classMap: [Int: Course]) throws {
        guard let courses = payload["courses"] as? [[String: Any]] else { return }
        for course in courses {
            let courseId = course["id"] as? Int
            guard let assignments = course["assignments"] as? [[String: Any]] else { continue }
            let targetCourse = courseId.flatMap { classMap[$0] }

            for a in assignments {
                let name = a["name"] as? String ?? "Assignment"
                let dueEpoch = (a["duedate"] as? Double) ?? (a["duedate"] as? Int).map(Double.init) ?? 0
                let due = dueEpoch > 0 ? Date(timeIntervalSince1970: dueEpoch) : nil

                // Dedup by title + due + course
                let req: NSFetchRequest<Task> = Task.fetchRequest()
                var subpreds: [NSPredicate] = [NSPredicate(format: "title == %@", name)]
                if let due { subpreds.append(NSPredicate(format: "dueDate == %@", due as NSDate)) }
                if let targetCourse { subpreds.append(NSPredicate(format: "course == %@", targetCourse)) }
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpreds)
                req.fetchLimit = 1

                let task = try ctx.fetch(req).first ?? Task(context: ctx)
                if task.id == nil { task.id = UUID() }
                task.title = name
                task.dueDate = due
                task.completed = false
                task.priority = task.priority == 0 ? 1 : task.priority // Default to Medium (1)
                if let targetCourse { task.course = targetCourse }
                task.updatedAt = Date()
                if task.createdAt == nil { task.createdAt = Date() }
            }
        }
    }

    private func upsertGrades(from items: [[String: Any]], classMap: [Int: Course]) throws {
        // 'items' format varies; try generic mapping
        for courseObj in items {
            guard let courseId = courseObj["courseid"] as? Int else { continue }
            guard let gradeItems = courseObj["gradeitems"] as? [[String: Any]] else { continue }
            let targetCourse = classMap[courseId]

            for gi in gradeItems {
                let name = gi["itemname"] as? String ?? "Grade"
                let score = (gi["graderaw"] as? Double) ?? (gi["graderaw"] as? Int).map(Double.init) ?? (gi["grade"] as? Double) ?? 0
                let max = (gi["grademax"] as? Double) ?? (gi["grademax"] as? Int).map(Double.init) ?? 100

                // Dedup by name + course
                let req: NSFetchRequest<Grade> = Grade.fetchRequest()
                var preds: [NSPredicate] = [NSPredicate(format: "name == %@", name)]
                if let targetCourse { preds.append(NSPredicate(format: "course == %@", targetCourse)) }
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: preds)
                req.fetchLimit = 1

                let grade = try ctx.fetch(req).first ?? Grade(context: ctx)
                if grade.id == nil { grade.id = UUID() }
                grade.name = name
                grade.score = score
                grade.totalPoints = max
                grade.assignmentType = grade.assignmentType ?? "Moodle"
                if let targetCourse { grade.course = targetCourse }
                grade.updatedAt = Date()
                if grade.createdAt == nil { grade.createdAt = Date() }
            }
        }
    }

    private func upsertCalendarEvents(from payload: [String: Any], classMap: [Int: Course]) throws {
        guard let events = payload["events"] as? [[String: Any]] else { return }
        for e in events {
            let name = e["name"] as? String ?? "Event"
            let courseId = e["courseid"] as? Int ?? e["course"] as? Int
            let startEpoch = (e["timestart"] as? Double) ?? (e["timestart"] as? Int).map(Double.init) ?? 0
            let startDate = startEpoch > 0 ? Date(timeIntervalSince1970: startEpoch) : nil
            let eventType = e["eventtype"] as? String ?? ""

            // Dedup by title + date + course
            let req: NSFetchRequest<Task> = Task.fetchRequest()
            var preds: [NSPredicate] = [NSPredicate(format: "title == %@", name)]
            if let startDate { preds.append(NSPredicate(format: "dueDate == %@", startDate as NSDate)) }
            if let c = courseId.flatMap({ classMap[$0] }) { preds.append(NSPredicate(format: "course == %@", c)) }
            req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: preds)
            req.fetchLimit = 1

            let task = try ctx.fetch(req).first ?? Task(context: ctx)
            if task.id == nil { task.id = UUID() }
            task.title = name
            task.dueDate = startDate
            task.completed = false
            task.priority = task.priority == 0 ? 1 : task.priority // Default to Medium (1)
            if let c = courseId.flatMap({ classMap[$0] }) { task.course = c }
            if !eventType.isEmpty {
                task.notes = (task.notes ?? "") + (task.notes == nil || task.notes!.isEmpty ? "" : "\n") + "Type: \(eventType)"
            }
            task.updatedAt = Date()
            if task.createdAt == nil { task.createdAt = Date() }
        }
    }
    
    private func upsertAttendanceSessions(from sessions: [[String: Any]], classMap: [Int: Course]) throws {
        for session in sessions {
            guard let sessionId = session["id"] as? Int64 else { continue }
            
            let courseId = session["courseid"] as? Int
            let startEpoch = (session["sessdate"] as? Double) ?? (session["sessdate"] as? Int).map(Double.init) ?? 0
            let duration = (session["duration"] as? Double) ?? (session["duration"] as? Int).map(Double.init) ?? 3600
            
            let startDate = startEpoch > 0 ? Date(timeIntervalSince1970: startEpoch) : Date()
            let endDate = Date(timeIntervalSince1970: startEpoch + duration)
            
            let statusValue = session["statusset"] as? String ?? ""
            let requiresPasscode = (session["studentpassword"] as? String)?.isEmpty == false
            
            // Find existing session
            let req: NSFetchRequest<AttendanceSession> = AttendanceSession.fetchRequest()
            req.predicate = NSPredicate(format: "id == %lld", sessionId)
            req.fetchLimit = 1
            
            let attendanceSession = try ctx.fetch(req).first ?? AttendanceSession(context: ctx)
            attendanceSession.id = sessionId
            attendanceSession.courseId = courseId.map(String.init)
            attendanceSession.start = startDate
            attendanceSession.end = endDate
            attendanceSession.status = statusValue
            attendanceSession.requiresPasscode = requiresPasscode
            
            if let description = session["description"] as? String {
                attendanceSession.room = description
            }
        }
    }
}

// MARK: - Error Types

enum MoodleError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case capabilityNotAvailable(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Moodle"
        case .invalidResponse:
            return "Invalid response from Moodle server"
        case .capabilityNotAvailable(let capability):
            return "Moodle capability '\(capability)' is not available"
        }
    }
}
