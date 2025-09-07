import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var moodleService: MoodleService
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var calendarHelper = CalendarHelper.shared
    @StateObject private var authService = AuthenticationService()
    @StateObject private var backupService = BackupService.shared
    
    @State private var showingMoodleSetup = false
    @State private var showingCalendarPermissions = false

    @State private var showingAbout = false
    
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("accentColor") private var accentColor: String = "blue"
    @AppStorage("defaultReminderTime") private var defaultReminderTime: Int = 15
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    @AppStorage("autoSyncMoodle") private var autoSyncMoodle: Bool = true
    @AppStorage("syncInterval") private var syncInterval: SyncInterval = .daily
    @AppStorage("weekStartDay") private var weekStartDay: WeekStartDay = .monday {
        didSet {
            calendarHelper.updateWeekStartDay(weekStartDay)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Account Section
                accountSection
                
                // Integrations Section
                integrationsSection
                
                // Notifications Section
                notificationsSection
                
                // Appearance Section
                appearanceSection
                
                // Data & Sync Section
                dataSyncSection
                
                // Backup Section
                backupSection
                
                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Sync week start day with CalendarHelper
                calendarHelper.updateWeekStartDay(weekStartDay)
            }
        }
        .sheet(isPresented: $showingMoodleSetup) {
            MoodleSetupView()
        }
        .sheet(isPresented: $showingCalendarPermissions) {
            CalendarPermissionsView()
        }

        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        Section("Account") {
            if let user = authService.currentUser {
                // User is signed in
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text((user.name ?? "").isEmpty ? "User" : user.name ?? "User")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(user.email ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: user.provider.iconName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(user.provider.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Sign Out") {
                        authService.signOut()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            } else {
                // User is not signed in
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign In")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Sync data across devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Sign In") {
                        // Show login view
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
    
    // MARK: - Integrations Section
    private var integrationsSection: some View {
        Section("Integrations") {
            // Moodle Integration
            HStack {
                Image(systemName: "graduationcap.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moodle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(moodleService.isAuthenticated ? "Connected" : "Not connected")
                        .font(.caption)
                        .foregroundColor(moodleService.isAuthenticated ? .green : .secondary)
                }
                
                Spacer()
                
                Button(moodleService.isAuthenticated ? "Manage" : "Connect") {
                    showingMoodleSetup = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Calendar Integration
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(calendarService.isAuthorized ? "Authorized" : "Not authorized")
                        .font(.caption)
                        .foregroundColor(calendarService.isAuthorized ? .green : .secondary)
                }
                
                Spacer()
                
                Button(calendarService.isAuthorized ? "Manage" : "Authorize") {
                    showingCalendarPermissions = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Google Calendar
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Calendar")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Sync with Google Calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Connect") {
                    // Connect to Google Calendar
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Notifications Section
    private var notificationsSection: some View {
        Section("Notifications") {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(notificationService.isAuthorized ? "Enabled" : "Disabled")
                        .font(.caption)
                        .foregroundColor(notificationService.isAuthorized ? .green : .secondary)
                }
                
                Spacer()
                
                Button("Settings") {
                    // TODO: Implement notification settings
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Default Reminder Time
            HStack {
                Image(systemName: "clock")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Default Reminder Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(defaultReminderTime) minutes before")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $defaultReminderTime) {
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("1 hour").tag(60)
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    // MARK: - Appearance Section
    private var appearanceSection: some View {
        Section("Appearance") {
            // App Theme
            HStack {
                Image(systemName: "paintbrush.fill")
                    .font(.title2)
                    .foregroundColor(.pink)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Theme")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(appTheme.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $appTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.description).tag(theme)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Accent Color
            HStack {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundColor(AccentColor(rawValue: accentColor)?.color ?? .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accent Color")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(AccentColor(rawValue: accentColor)?.rawValue.capitalized ?? "Blue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $accentColor) {
                    ForEach(AccentColor.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 16, height: 16)
                            Text(color.rawValue.capitalized)
                        }
                        .tag(color.rawValue)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Week Start Day
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Week Start Day")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Start week on \(weekStartDay.description)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $weekStartDay) {
                    ForEach(WeekStartDay.allCases, id: \.self) { day in
                        Text(day.description).tag(day)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: weekStartDay) { newValue in
                    calendarHelper.updateWeekStartDay(newValue)
                }
            }
            
            // Haptic Feedback
            HStack {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Haptic Feedback")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Vibrate on interactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $enableHapticFeedback)
            }
        }
    }
    
    // MARK: - Data & Sync Section
    private var dataSyncSection: some View {
        Section("Data & Sync") {
            // Auto Sync
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto Sync Moodle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Automatically sync data from Moodle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $autoSyncMoodle)
            }
            
            // Sync Interval
            if autoSyncMoodle {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync Interval")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(syncInterval.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $syncInterval) {
                        ForEach(SyncInterval.allCases, id: \.self) { interval in
                            Text(interval.description).tag(interval)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            // Export Data
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Data")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Export your data as backup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Export") {
                    exportData()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Clear All Data
            HStack {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear All Data")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Delete all app data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Clear") {
                    clearAllData()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Backup Section
    private var backupSection: some View {
        Section("Backup & Sync") {
            // iCloud Backup Status
            HStack {
                Image(systemName: "icloud")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Backup")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let lastBackup = backupService.lastBackupDate {
                        Text("Last backup: \(lastBackup, formatter: backupDateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No backup yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if backupService.isBackingUp {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(backupService.backupStatus.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Manual Backup
            HStack {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Backup")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Backup data to iCloud")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Backup") {
                    backupService.createBackup()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(backupService.isBackingUp)
            }
            
            // Restore Backup
            HStack {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restore Backup")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Restore from iCloud backup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Restore") {
                    backupService.restoreFromBackup { success in
                        if success {
                            // Handle successful restore
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(backupService.isBackingUp)
            }
            
            // Setup Automatic Backup
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatic Backup")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Backup every hour")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Setup") {
                    backupService.setupAutomaticBackup()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("About Aera Flow")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Info") {
                    showingAbout = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func exportData() {
        // Implement data export functionality
    }
    
    private func clearAllData() {
        // Implement data clearing functionality
    }
    
    private let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Supporting Types
enum AppTheme: String, CaseIterable {
    case light, dark, system
    
    var description: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum SyncInterval: String, CaseIterable {
    case hourly, daily, weekly
    
    var description: String {
        switch self {
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

enum WeekStartDay: String, CaseIterable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    
    var description: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}



// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(MoodleService())
            .environmentObject(CalendarService())
            .environmentObject(NotificationService())
    }
}
