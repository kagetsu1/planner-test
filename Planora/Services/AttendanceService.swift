import Foundation
import CoreData
import AVFoundation

/// Service for managing attendance sessions and check-ins
class AttendanceService: ObservableObject {
    @Published var isScanning = false
    @Published var currentSession: AttendanceSession?
    
    private var moodleService: MoodleService?
    private var ctx: NSManagedObjectContext {
        DataController.shared.container.viewContext
    }
    
    init() {
        // Initialize moodle service lazily to avoid crashes
        DispatchQueue.main.async {
            self.moodleService = MoodleService()
        }
    }
    
    /// Get attendance sessions for today that are within check-in window
    func getOpenSessions() -> [AttendanceSession] {
        let request: NSFetchRequest<AttendanceSession> = AttendanceSession.fetchRequest()
        
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(format: "start >= %@ AND start <= %@ AND start <= %@ AND end >= %@",
                                      startOfDay as NSDate,
                                      endOfDay as NSDate,
                                      now as NSDate,
                                      now as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceSession.start, ascending: true)]
        
        do {
            return try ctx.fetch(request)
        } catch {
            print("Error fetching open sessions: \(error)")
            return []
        }
    }
    
    /// Get next class that's coming up (for Home view display)
    func getNextClass() -> (session: AttendanceSession, timeToStart: TimeInterval)? {
        let request: NSFetchRequest<AttendanceSession> = AttendanceSession.fetchRequest()
        
        let now = Date()
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        
        request.predicate = NSPredicate(format: "start > %@ AND start <= %@",
                                      now as NSDate,
                                      endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceSession.start, ascending: true)]
        request.fetchLimit = 1
        
        do {
            if let session = try ctx.fetch(request).first {
                let timeToStart = session.start?.timeIntervalSince(now) ?? 0
                return (session, timeToStart)
            }
        } catch {
            print("Error fetching next class: \(error)")
        }
        
        return nil
    }
    
    /// Check if a session is currently open for check-in
    func isSessionOpen(_ session: AttendanceSession) -> Bool {
        guard let start = session.start,
              let end = session.end else { return false }
        
        let now = Date()
        return now >= start && now <= end
    }
    
    /// Submit attendance with passcode
    func submitAttendance(for session: AttendanceSession, passcode: String?) async throws -> Bool {
        guard isSessionOpen(session) else {
            throw AttendanceError.sessionClosed
        }
        
        guard let moodleService = moodleService else {
            throw AttendanceError.networkError(NSError(domain: "AttendanceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Moodle service not available"]))
        }
        
        // Default status ID for "Present" - this may vary by Moodle instance
        let statusId = 1
        
        let success = try await moodleService.submitAttendance(
            sessionId: session.id,
            statusId: statusId,
            passcode: passcode
        )
        
        if success {
            // Update local status
            DispatchQueue.main.async {
                session.status = "Present"
                try? self.ctx.save()
            }
        }
        
        return success
    }
    
    /// Parse QR code for attendance data
    func parseQRCode(_ qrString: String) -> QRAttendanceData? {
        // QR codes typically contain session info in various formats
        // Common formats:
        // 1. Simple session ID: "12345"
        // 2. URL with parameters: "https://moodle.site/mod/attendance/view.php?sessid=12345&code=ABC123"
        // 3. JSON: {"sessionId": 12345, "passcode": "ABC123"}
        
        // Try parsing as JSON first
        if let data = qrString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let sessionId = json["sessionId"] as? Int64 {
            let passcode = json["passcode"] as? String
            return QRAttendanceData(sessionId: sessionId, passcode: passcode)
        }
        
        // Try parsing as URL
        if let url = URL(string: qrString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            var sessionId: Int64?
            var passcode: String?
            
            for item in queryItems {
                switch item.name.lowercased() {
                case "sessid", "sessionid", "id":
                    sessionId = Int64(item.value ?? "")
                case "code", "passcode", "password":
                    passcode = item.value
                default:
                    break
                }
            }
            
            if let sessionId = sessionId {
                return QRAttendanceData(sessionId: sessionId, passcode: passcode)
            }
        }
        
        // Try parsing as simple session ID
        if let sessionId = Int64(qrString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return QRAttendanceData(sessionId: sessionId, passcode: nil)
        }
        
        return nil
    }
    
    /// Start QR code scanning
    func startQRScanning() {
        isScanning = true
    }
    
    /// Stop QR code scanning
    func stopQRScanning() {
        isScanning = false
    }
    
    /// Merge attendance sessions into week timetable blocks
    func mergeIntoTimetable(_ sessions: [AttendanceSession]) -> [TimetableBlock] {
        return sessions.compactMap { session in
            guard let start = session.start,
                  let end = session.end else { return nil }
            
            let calendar = Calendar.current
            let dayOfWeek = calendar.component(.weekday, from: start)
            
            return TimetableBlock(
                id: UUID(),
                title: getCourseTitle(for: session.courseId) ?? "Class",
                startTime: start,
                endTime: end,
                dayOfWeek: dayOfWeek,
                location: session.room,
                courseId: session.courseId,
                attendanceSession: session,
                isOpen: isSessionOpen(session)
            )
        }
    }
    
    private func getCourseTitle(for courseId: String?) -> String? {
        guard let courseId = courseId else { return nil }
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "moodleId == %@", courseId)
        request.fetchLimit = 1
        
        do {
            let course = try ctx.fetch(request).first
            return course?.courseName
        } catch {
            return nil
        }
    }
}

// MARK: - Data Models

struct QRAttendanceData {
    let sessionId: Int64
    let passcode: String?
}

struct TimetableBlock {
    let id: UUID
    let title: String
    let startTime: Date
    let endTime: Date
    let dayOfWeek: Int
    let location: String?
    let courseId: String?
    let attendanceSession: AttendanceSession?
    let isOpen: Bool
}

enum AttendanceError: LocalizedError {
    case sessionClosed
    case invalidPasscode
    case networkError(Error)
    case qrParsingFailed
    
    var errorDescription: String? {
        switch self {
        case .sessionClosed:
            return "Attendance session is not currently open"
        case .invalidPasscode:
            return "Invalid passcode provided"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .qrParsingFailed:
            return "Could not parse QR code data"
        }
    }
}
