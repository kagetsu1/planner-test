import Foundation
import CoreData

// MARK: - Course Extensions
extension Course {
    var slotsArray: [ClassSlot] {
        let set = slots as? Set<ClassSlot> ?? []
        return Array(set).sorted { slot1, slot2 in
            guard let time1 = slot1.startTime, let time2 = slot2.startTime else { return false }
            return time1 < time2
        }
    }
    
    var instructorsArray: [Instructor] {
        let set = instructors as? Set<Instructor> ?? []
        return Array(set).sorted { $0.name ?? "" < $1.name ?? "" }
    }
    
    var tasksArray: [Task] {
        let set = tasks as? Set<Task> ?? []
        return Array(set).sorted { $0.dueDate ?? Date() < $1.dueDate ?? Date() }
    }
    
    var gradesArray: [Grade] {
        let set = grades as? Set<Grade> ?? []
        return Array(set).sorted { $0.createdAt ?? Date() < $1.createdAt ?? Date() }
    }
}
