import Foundation
import CoreData

/// Service for parsing natural language input into tasks and events
class QuickAddParser: ObservableObject {
    private let dateTimeParser = DateTimeParser()
    private let recurrenceParser = RecurrenceParser()
    
    private var ctx: NSManagedObjectContext {
        DataController.shared.container.viewContext
    }
    
    /// Parse input text and determine if it should be a task or event
    func parse(_ input: String) -> ParsedItem? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        
        var item = ParsedItem()
        
        // Extract project (#project)
        item.projectName = extractProject(from: &text)
        
        // Extract labels (@label)
        item.labels = extractLabels(from: &text)
        
        // Extract priority (p1, p2, p3, p4)
        item.priority = extractPriority(from: &text)
        
        // Extract time information
        let timeInfo = dateTimeParser.extractTimeInfo(from: &text)
        item.dueDate = timeInfo.dueDate
        item.startTime = timeInfo.startTime
        item.endTime = timeInfo.endTime
        
        // Extract recurrence
        item.recurrenceRule = recurrenceParser.parseRecurrence(from: &text)
        
        // Extract reminder
        item.reminderOffset = extractReminder(from: &text)
        
        // Clean up the remaining text as title
        item.title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Determine type: if there's a time range, it's an event; otherwise it's a task
        if timeInfo.startTime != nil && timeInfo.endTime != nil {
            item.type = .event
        } else {
            item.type = .task
        }
        
        return item
    }
    
    /// Create a task from parsed item
    func createTask(from parsedItem: ParsedItem) throws -> Task {
        let task = Task(context: ctx)
        task.id = UUID()
        task.title = parsedItem.title
        task.dueDate = parsedItem.dueDate
        task.projectName = parsedItem.projectName
        task.labels = parsedItem.labels?.joined(separator: ",")
        task.priority = Int16(parsedItem.priority)
        task.isCompleted = false
        task.showOnCalendar = parsedItem.startTime != nil
        task.createdAt = Date()
        task.updatedAt = Date()
        
        if let reminderOffset = parsedItem.reminderOffset,
           let dueDate = parsedItem.dueDate {
            task.reminderTime = dueDate.addingTimeInterval(-reminderOffset)
        }
        
        try ctx.save()
        return task
    }
    
    /// Create an event from parsed item (via EventKit or Core Data)
    func createEvent(from parsedItem: ParsedItem, useEventKit: Bool = true) throws -> String {
        guard let startTime = parsedItem.startTime else {
            throw QuickAddError.missingStartTime
        }
        
        let endTime = parsedItem.endTime ?? startTime.addingTimeInterval(3600) // Default 1 hour
        
        if useEventKit {
            _ = EventKitBridge()
            // Note: This should be called from an async context
            // For now, we'll create a local calendar event
        }
        
        // Create local calendar event
        let event = CalendarEvent(context: ctx)
        event.id = UUID()
        event.title = parsedItem.title
        event.start = startTime
        event.end = endTime
        event.source = "local"
        event.notes = buildEventNotes(from: parsedItem)
        
        try ctx.save()
        return event.id?.uuidString ?? ""
    }
    
    // MARK: - Extraction Methods
    
    private func extractProject(from text: inout String) -> String? {
        let pattern = #"#(\w+)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = regex.firstMatch(in: text, range: range) {
            let projectRange = Range(match.range(at: 1), in: text)!
            let project = String(text[projectRange])
            
            // Remove the project from text
            let fullMatchRange = Range(match.range, in: text)!
            text.removeSubrange(fullMatchRange)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return project
        }
        
        return nil
    }
    
    private func extractLabels(from text: inout String) -> [String]? {
        let pattern = #"@(\w+)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        var labels: [String] = []
        let matches = regex.matches(in: text, range: range).reversed() // Reverse to remove from end to start
        
        for match in matches {
            let labelRange = Range(match.range(at: 1), in: text)!
            let label = String(text[labelRange])
            labels.insert(label, at: 0)
            
            // Remove the label from text
            let fullMatchRange = Range(match.range, in: text)!
            text.removeSubrange(fullMatchRange)
        }
        
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return labels.isEmpty ? nil : labels
    }
    
    private func extractPriority(from text: inout String) -> Int {
        let pattern = #"\bp([1-4])\b"#
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = regex.firstMatch(in: text, range: range) {
            let priorityRange = Range(match.range(at: 1), in: text)!
            let priorityString = String(text[priorityRange])
            
            // Remove the priority from text
            let fullMatchRange = Range(match.range, in: text)!
            text.removeSubrange(fullMatchRange)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Int(priorityString) ?? 0
        }
        
        return 0 // Default priority
    }
    
    private func extractReminder(from text: inout String) -> TimeInterval? {
        let patterns = [
            (#"remind (\d+)m"#, 60.0), // minutes
            (#"remind (\d+)h"#, 3600.0), // hours
            (#"remind (\d+)d"#, 86400.0), // days
            (#"reminder (\d+)m"#, 60.0),
            (#"reminder (\d+)h"#, 3600.0),
            (#"reminder (\d+)d"#, 86400.0)
        ]
        
        for (pattern, multiplier) in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            
            if let match = regex.firstMatch(in: text, range: range) {
                let numberRange = Range(match.range(at: 1), in: text)!
                let numberString = String(text[numberRange])
                
                // Remove the reminder from text
                let fullMatchRange = Range(match.range, in: text)!
                text.removeSubrange(fullMatchRange)
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let number = Double(numberString) {
                    return number * multiplier
                }
            }
        }
        
        return nil
    }
    
    private func buildEventNotes(from parsedItem: ParsedItem) -> String? {
        var notes: [String] = []
        
        if let project = parsedItem.projectName {
            notes.append("Project: \(project)")
        }
        
        if let labels = parsedItem.labels, !labels.isEmpty {
            notes.append("Labels: \(labels.joined(separator: ", "))")
        }
        
        if parsedItem.priority > 0 {
            notes.append("Priority: P\(parsedItem.priority)")
        }
        
        return notes.isEmpty ? nil : notes.joined(separator: "\n")
    }
}

// MARK: - Supporting Classes

class DateTimeParser {
    private let calendar = Calendar.current
    
    struct TimeInfo {
        let dueDate: Date?
        let startTime: Date?
        let endTime: Date?
    }
    
    func extractTimeInfo(from text: inout String) -> TimeInfo {
        var dueDate: Date?
        var startTime: Date?
        var endTime: Date?
        
        // Extract time ranges (e.g., "3-4pm", "9:00-10:30")
        if let timeRange = extractTimeRange(from: &text) {
            startTime = timeRange.start
            endTime = timeRange.end
        }
        
        // Extract specific times (e.g., "tomorrow 3pm", "friday 11am")
        if let specificTime = extractSpecificTime(from: &text) {
            if startTime == nil {
                dueDate = specificTime
            }
        }
        
        // Extract relative dates (e.g., "tomorrow", "next week", "in 3 days")
        if let relativeDate = extractRelativeDate(from: &text) {
            if dueDate == nil && startTime == nil {
                dueDate = relativeDate
            }
        }
        
        // Extract absolute dates (e.g., "Dec 15", "12/15", "2024-12-15")
        if let absoluteDate = extractAbsoluteDate(from: &text) {
            if dueDate == nil && startTime == nil {
                dueDate = absoluteDate
            }
        }
        
        return TimeInfo(dueDate: dueDate, startTime: startTime, endTime: endTime)
    }
    
    private func extractTimeRange(from text: inout String) -> (start: Date, end: Date)? {
        let patterns = [
            #"(\d{1,2})-(\d{1,2})(am|pm)"#, // "3-4pm"
            #"(\d{1,2}:\d{2})-(\d{1,2}:\d{2})"#, // "9:00-10:30"
            #"(\d{1,2})(am|pm)-(\d{1,2})(am|pm)"# // "9am-10am"
        ]
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            
            if let match = regex.firstMatch(in: text, range: range) {
                // Remove from text
                let fullMatchRange = Range(match.range, in: text)!
                let matchedText = String(text[fullMatchRange])
                text.removeSubrange(fullMatchRange)
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Parse the matched time range
                return parseTimeRange(matchedText)
            }
        }
        
        return nil
    }
    
    private func extractSpecificTime(from text: inout String) -> Date? {
        let patterns = [
            (#"(today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s+(\d{1,2})(am|pm)"#, true),
            (#"(\d{1,2})(am|pm)\s+(today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#, false),
            (#"by\s+(today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s+(\d{1,2})(am|pm)"#, true)
        ]
        
        for (pattern, dayFirst) in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            
            if let match = regex.firstMatch(in: text, range: range) {
                // Remove from text
                let fullMatchRange = Range(match.range, in: text)!
                text.removeSubrange(fullMatchRange)
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Parse the specific time
                return parseSpecificTime(match, in: text, dayFirst: dayFirst)
            }
        }
        
        return nil
    }
    
    private func extractRelativeDate(from text: inout String) -> Date? {
        let patterns: [(String, (NSTextCheckingResult, String) -> Date?)] = [
            (#"tomorrow"#, { _, _ in Calendar.current.date(byAdding: .day, value: 1, to: Date()) }),
            (#"today"#, { _, _ in Date() }),
            (#"next week"#, { _, _ in Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) }),
            (#"in (\d+) days?"#, { (match: NSTextCheckingResult, text: String) in
                guard let range = Range(match.range(at: 1), in: text),
                      let days = Int(String(text[range])) else { return nil }
                return Calendar.current.date(byAdding: .day, value: days, to: Date())
            })
        ]
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern.0, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            
            if let match = regex.firstMatch(in: text, range: range) {
                // Remove from text
                let fullMatchRange = Range(match.range, in: text)!
                text.removeSubrange(fullMatchRange)
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Calculate date using the pattern's closure
                return pattern.1(match, String(text))
            }
        }
        
        return nil
    }
    
    private func extractAbsoluteDate(from text: inout String) -> Date? {
        // This would parse dates like "Dec 15", "12/15/2024", etc.
        // Implementation would be similar to above patterns
        return nil
    }
    
    private func parseTimeRange(_ text: String) -> (start: Date, end: Date)? {
        // Simplified implementation - would need more robust parsing
        return nil
    }
    
    private func parseSpecificTime(_ match: NSTextCheckingResult, in text: String, dayFirst: Bool) -> Date? {
        // Simplified implementation - would need more robust parsing
        return nil
    }
}

class RecurrenceParser {
    func parseRecurrence(from text: inout String) -> String? {
        let patterns = [
            (#"every (day|daily)"#, "daily"),
            (#"every (week|weekly)"#, "weekly"),
            (#"every (month|monthly)"#, "monthly"),
            (#"every (year|yearly)"#, "yearly"),
            (#"every (monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#, "weekly"),
            (#"weekly on (monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#, "weekly")
        ]
        
        for (pattern, recurrence) in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            
            if let match = regex.firstMatch(in: text, range: range) {
                // Remove from text
                let fullMatchRange = Range(match.range, in: text)!
                text.removeSubrange(fullMatchRange)
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                return recurrence
            }
        }
        
        return nil
    }
}

// MARK: - Data Models

struct ParsedItem {
    var title: String = ""
    var type: ItemType = .task
    var dueDate: Date?
    var startTime: Date?
    var endTime: Date?
    var projectName: String?
    var labels: [String]?
    var priority: Int = 0
    var recurrenceRule: String?
    var reminderOffset: TimeInterval?
}

enum ItemType {
    case task
    case event
}

enum QuickAddError: LocalizedError {
    case missingStartTime
    case invalidInput
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .missingStartTime:
            return "Event must have a start time"
        case .invalidInput:
            return "Invalid input provided"
        case .parsingFailed:
            return "Failed to parse input"
        }
    }
}
