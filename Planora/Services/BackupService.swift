import Foundation
import CloudKit
import CryptoKit
import CoreData
import UIKit

class BackupService: ObservableObject {
    static let shared = BackupService()
    
    @Published var isBackingUp = false
    @Published var lastBackupDate: Date?
    @Published var backupStatus: BackupStatus = .idle
    @Published var errorMessage: String?
    
    private let cloudKitContainer = CKContainer.default()
    private let privateDatabase: CKDatabase
    private let backupQueue = DispatchQueue(label: "backup.queue", qos: .utility)
    
    private init() {
        self.privateDatabase = cloudKitContainer.privateCloudDatabase
        loadLastBackupDate()
    }
    
    // MARK: - Backup Status
    enum BackupStatus {
        case idle
        case backingUp
        case restoring
        case completed
        case failed(String)
        
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .backingUp: return "Backing up..."
            case .restoring: return "Restoring..."
            case .completed: return "Completed"
            case .failed(let error): return "Failed: \(error)"
            }
        }
    }
    
    // MARK: - Automatic Backup
    func setupAutomaticBackup() {
        // Check if CloudKit is available
        cloudKitContainer.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.enableAutomaticBackup()
                case .noAccount:
                    self?.errorMessage = "iCloud account not available"
                case .restricted:
                    self?.errorMessage = "iCloud access restricted"
                case .couldNotDetermine:
                    self?.errorMessage = "Could not determine iCloud status"
                case .temporarilyUnavailable:
                    self?.errorMessage = "iCloud temporarily unavailable"
                @unknown default:
                    self?.errorMessage = "Unknown iCloud status"
                }
            }
        }
    }
    
    private func enableAutomaticBackup() {
        // Schedule automatic backups
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.performAutomaticBackup()
        }
    }
    
    private func performAutomaticBackup() {
        guard !isBackingUp else { return }
        
        backupQueue.async { [weak self] in
            self?.createBackup()
        }
    }
    
    // MARK: - Manual Backup
    func createBackup() {
        DispatchQueue.main.async {
            self.isBackingUp = true
            self.backupStatus = .backingUp
        }
        
        backupQueue.async { [weak self] in
            self?.performBackup()
        }
    }
    
    private func performBackup() {
        do {
            // Create encrypted backup data
            let backupData = try createEncryptedBackup()
            
            // Save to CloudKit
            saveToCloudKit(backupData) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.backupStatus = .completed
                        self?.lastBackupDate = Date()
                        self?.saveLastBackupDate()
                    } else {
                        self?.backupStatus = .failed("Failed to save to iCloud")
                    }
                    self?.isBackingUp = false
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.backupStatus = .failed(error.localizedDescription)
                self.isBackingUp = false
            }
        }
    }
    
    // MARK: - Backup Data Creation
    private func createEncryptedBackup() throws -> Data {
        var backup = BackupData()
        
        // Export Core Data
        backup.coreDataExport = try exportCoreData()
        
        // Export UserDefaults
        backup.userDefaults = exportUserDefaults()
        
        // Export app settings
        backup.appSettings = exportAppSettings()
        
        // Encrypt the backup
        return try encryptBackup(backup)
    }
    
    private func exportCoreData() throws -> Data {
        // Export Core Data to JSON format
        let context = DataController.shared.container.viewContext
        let entities = context.persistentStoreCoordinator?.managedObjectModel.entities ?? []
        
        var exportData: [String: Any] = [:]
        
        for entity in entities {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entity.name ?? "")
            let objects = try context.fetch(fetchRequest)
            
            var entityData: [[String: Any]] = []
            for object in objects {
                entityData.append(object.dictionaryWithValues(forKeys: Array(object.entity.attributesByName.keys)))
            }
            
            exportData[entity.name ?? ""] = entityData
        }
        
        return try JSONSerialization.data(withJSONObject: exportData)
    }
    
    private func exportUserDefaults() -> [String: Any] {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { key in
            // Filter out system keys and sensitive data
            !key.hasPrefix("Apple") && 
            !key.hasPrefix("NS") && 
            !key.contains("password") &&
            !key.contains("token")
        }
        
        var exportData: [String: Any] = [:]
        for key in keys {
            if let value = defaults.object(forKey: key) {
                exportData[key] = value
            }
        }
        
        return exportData
    }
    
    private func exportAppSettings() -> [String: Any] {
        return [
            "appTheme": UserDefaults.standard.string(forKey: "appTheme") ?? "system",
            "accentColor": UserDefaults.standard.string(forKey: "accentColor") ?? "blue",
            "weekStartDay": UserDefaults.standard.string(forKey: "weekStartDay") ?? "monday",
            "defaultReminderTime": UserDefaults.standard.integer(forKey: "defaultReminderTime"),
            "enableHapticFeedback": UserDefaults.standard.bool(forKey: "enableHapticFeedback"),
            "autoSyncMoodle": UserDefaults.standard.bool(forKey: "autoSyncMoodle"),
            "syncInterval": UserDefaults.standard.string(forKey: "syncInterval") ?? "daily"
        ]
    }
    
    // MARK: - Encryption
    private func encryptBackup(_ backup: BackupData) throws -> Data {
        let jsonData = try JSONEncoder().encode(backup)
        
        // Generate encryption key from user's device
        let key = generateEncryptionKey()
        
        // Encrypt the data
        let sealedBox = try AES.GCM.seal(jsonData, using: key)
        
        return sealedBox.combined ?? Data()
    }
    
    private func generateEncryptionKey() -> SymmetricKey {
        // Generate a key based on device-specific information
        // This ensures the same device can decrypt the data
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "default"
        let keyData = Data(deviceID.utf8)
        return SymmetricKey(data: keyData)
    }
    
    // MARK: - CloudKit Operations
    private func saveToCloudKit(_ data: Data, completion: @escaping (Bool) -> Void) {
        let record = CKRecord(recordType: "Backup")
        record["data"] = data
        record["timestamp"] = Date()
        record["version"] = "1.0"
        
        privateDatabase.save(record) { _, error in
            if let error = error {
                print("CloudKit save error: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func restoreFromBackup(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.backupStatus = .restoring
        }
        
        backupQueue.async { [weak self] in
            self?.performRestore(completion: completion)
        }
    }
    
    private func performRestore(completion: @escaping (Bool) -> Void) {
        let query = CKQuery(recordType: "Backup", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let performQuery = { [weak self] in
            if #available(iOS 15.0, *) {
                self?.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                    switch result {
                    case .success(let queryResult):
                        let records = queryResult.matchResults.compactMap { matchResult in
                            switch matchResult.1 {
                            case .success(let record):
                                return record
                            case .failure(_):
                                return nil
                            }
                        }
                        self?.handleRestoreResponse(records: records, error: nil, completion: completion)
                    case .failure(let error):
                        self?.handleRestoreResponse(records: nil, error: error, completion: completion)
                    }
                }
            } else {
                self?.privateDatabase.perform(query, inZoneWith: nil) { records, error in
                    self?.handleRestoreResponse(records: records, error: error, completion: completion)
                }
            }
        }
        performQuery()
    }
    
    private func handleRestoreResponse(records: [CKRecord]?, error: Error?, completion: @escaping (Bool) -> Void) {
        guard let record = records?.first,
              let data = record["data"] as? Data else {
            DispatchQueue.main.async {
                self.backupStatus = .failed("No backup found")
                completion(false)
            }
            return
        }
        
        do {
            let backup = try self.decryptBackup(data)
            try self.restoreFromBackupData(backup)
            
            DispatchQueue.main.async {
                self.backupStatus = .completed
                completion(true)
            }
        } catch {
            DispatchQueue.main.async {
                self.backupStatus = .failed(error.localizedDescription)
                completion(false)
            }
        }
    }
    
    private func decryptBackup(_ data: Data) throws -> BackupData {
        let key = generateEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return try JSONDecoder().decode(BackupData.self, from: decryptedData)
    }
    
    private func restoreFromBackupData(_ backup: BackupData) throws {
        // Restore Core Data
        if let coreDataExport = backup.coreDataExport {
            try restoreCoreData(coreDataExport)
        }
        
        // Restore UserDefaults
        restoreUserDefaults(backup.userDefaults)
        
        // Restore app settings
        restoreAppSettings(backup.appSettings)
    }
    
    private func restoreCoreData(_ data: Data) throws {
        let context = DataController.shared.container.viewContext
        
        // Clear existing data
        let entities = context.persistentStoreCoordinator?.managedObjectModel.entities ?? []
        for entity in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name ?? "")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
        }
        
        // Import new data
        let importData = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        for (entityName, entityData) in importData {
            guard let entityData = entityData as? [[String: Any]] else { continue }
            
            for objectData in entityData {
                let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)
                let object = NSManagedObject(entity: entity!, insertInto: context)
                
                for (key, value) in objectData {
                    object.setValue(value, forKey: key)
                }
            }
        }
        
        try context.save()
    }
    
    private func restoreUserDefaults(_ data: [String: Any]) {
        let defaults = UserDefaults.standard
        
        for (key, value) in data {
            defaults.set(value, forKey: key)
        }
    }
    
    private func restoreAppSettings(_ data: [String: Any]) {
        let defaults = UserDefaults.standard
        
        if let appTheme = data["appTheme"] as? String {
            defaults.set(appTheme, forKey: "appTheme")
        }
        if let accentColor = data["accentColor"] as? String {
            defaults.set(accentColor, forKey: "accentColor")
        }
        if let weekStartDay = data["weekStartDay"] as? String {
            defaults.set(weekStartDay, forKey: "weekStartDay")
        }
        if let defaultReminderTime = data["defaultReminderTime"] as? Int {
            defaults.set(defaultReminderTime, forKey: "defaultReminderTime")
        }
        if let enableHapticFeedback = data["enableHapticFeedback"] as? Bool {
            defaults.set(enableHapticFeedback, forKey: "enableHapticFeedback")
        }
        if let autoSyncMoodle = data["autoSyncMoodle"] as? Bool {
            defaults.set(autoSyncMoodle, forKey: "autoSyncMoodle")
        }
        if let syncInterval = data["syncInterval"] as? String {
            defaults.set(syncInterval, forKey: "syncInterval")
        }
    }
    
    // MARK: - Utility Methods
    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    }
    
    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: "lastBackupDate")
    }
}

// MARK: - Backup Data Model
struct BackupData: Codable {
    var coreDataExport: Data?
    var userDefaultsData: Data
    var appSettingsData: Data
    var timestamp: Date
    var version: String
    
    init() {
        self.userDefaultsData = Data()
        self.appSettingsData = Data()
        self.timestamp = Date()
        self.version = "1.0"
    }
    
    var userDefaults: [String: Any] {
        get {
            guard let dict = try? JSONSerialization.jsonObject(with: userDefaultsData) as? [String: Any] else {
                return [:]
            }
            return dict
        }
        set {
            userDefaultsData = (try? JSONSerialization.data(withJSONObject: newValue)) ?? Data()
        }
    }
    
    var appSettings: [String: Any] {
        get {
            guard let dict = try? JSONSerialization.jsonObject(with: appSettingsData) as? [String: Any] else {
                return [:]
            }
            return dict
        }
        set {
            appSettingsData = (try? JSONSerialization.data(withJSONObject: newValue)) ?? Data()
        }
    }
}
