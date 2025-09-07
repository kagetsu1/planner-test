import CoreData
import Foundation

class DataController: ObservableObject {
    static let shared = DataController()
    let container: NSPersistentContainer
    
    private init() {
        container = NSPersistentContainer(name: "StudentPlanner")
        
        // Configure store location for App Group sharing
        if let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.planora.app")?.appendingPathComponent("StudentPlanner.sqlite") {
            let description = NSPersistentStoreDescription(url: storeURL)
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            container.persistentStoreDescriptions = [description]
        }
        
        // Configure for lightweight migration
        for description in container.persistentStoreDescriptions {
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func save() {
        let context = container.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            // Handle save error gracefully
            print("Failed to save context: \(error)")
            
            // Rollback changes
            context.rollback()
            
            // Post notification for error handling
            NotificationCenter.default.post(
                name: .coreDataSaveError,
                object: error
            )
        }
    }
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func delete(_ object: NSManagedObject) {
        container.viewContext.delete(object)
        save()
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let coreDataSaveError = Notification.Name("coreDataSaveError")
}
