import SwiftUI

/// Setup Center with guided checklist for onboarding and configuration
struct SetupCenterView: View {
    @StateObject private var setupManager = SetupManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: UITheme.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Progress Overview
                    progressSection
                    
                    // Setup Steps
                    setupStepsSection
                    
                    // Quick Actions
                    if setupManager.completionPercentage >= 0.5 {
                        quickActionsSection
                    }
                }
                .padding()
            }
            .background(UITheme.Colors.groupedBackground)
            .navigationTitle("Setup Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupManager.checkSetupStatus()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: UITheme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(setupManager.isCompletelySetup ? UITheme.Colors.success : UITheme.Colors.primary)
            
            Text(setupManager.isCompletelySetup ? "Setup Complete!" : "Welcome to Planora")
                .font(UITheme.Typography.title1)
                .multilineTextAlignment(.center)
                .foregroundColor(UITheme.Colors.primaryText)
            
            Text(setupManager.isCompletelySetup 
                 ? "Your student planner is ready to use. You can always come back here to adjust settings."
                 : "Let's get your student planner set up. Complete these steps to get the most out of Planora.")
                .font(UITheme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(UITheme.Colors.secondaryText)
        }
        .themeCard()
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            HStack {
                Text("Setup Progress")
                    .font(UITheme.Typography.title2)
                    .foregroundColor(UITheme.Colors.primaryText)
                
                Spacer()
                
                Text("\(Int(setupManager.completionPercentage * 100))%")
                    .font(UITheme.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(UITheme.Colors.primary)
            }
            
            ProgressView(value: setupManager.completionPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: UITheme.Colors.primary))
                .scaleEffect(y: 2.0)
            
            HStack {
                Text("\(setupManager.completedSteps.count) of \(setupManager.allSteps.count) steps completed")
                    .font(UITheme.Typography.caption)
                    .foregroundColor(UITheme.Colors.secondaryText)
                
                Spacer()
                
                if !setupManager.nextSteps.isEmpty {
                    Text("Next: \(setupManager.nextSteps.first?.title ?? "")")
                        .font(UITheme.Typography.caption)
                        .foregroundColor(UITheme.Colors.primary)
                        .lineLimit(1)
                }
            }
        }
        .themeCard()
    }
    
    private var setupStepsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            Text("Setup Steps")
                .font(UITheme.Typography.title2)
                .foregroundColor(UITheme.Colors.primaryText)
            
            LazyVStack(spacing: UITheme.Spacing.sm) {
                ForEach(SetupStep.allCases, id: \.self) { step in
                    setupStepRow(step)
                }
            }
        }
    }
    
    private func setupStepRow(_ step: SetupStep) -> some View {
        HStack(spacing: UITheme.Spacing.md) {
            // Status icon
            Group {
                if setupManager.completedSteps.contains(step) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(UITheme.Colors.success)
                } else if setupManager.inProgressSteps.contains(step) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(UITheme.Colors.warning)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(UITheme.Colors.tertiary)
                }
            }
            .font(.title2)
            
            // Step content
            VStack(alignment: .leading, spacing: UITheme.Spacing.xs) {
                HStack {
                    Text(step.title)
                        .font(UITheme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(UITheme.Colors.primaryText)
                    
                    if step.isRequired {
                        Text("REQUIRED")
                            .font(UITheme.Typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(UITheme.Colors.error)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                
                Text(step.description)
                    .font(UITheme.Typography.caption)
                    .foregroundColor(UITheme.Colors.secondaryText)
                    .lineLimit(2)
            }
            
            // Action button
            if !setupManager.completedSteps.contains(step) {
                Button(action: {
                    setupManager.performSetupStep(step)
                }) {
                    Text(step.actionTitle)
                        .font(UITheme.Typography.caption)
                        .fontWeight(.medium)
                }
                .themeButton(style: .primary)
                .scaleEffect(0.9)
            }
        }
        .padding(UITheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: UITheme.CornerRadius.card)
                .fill(stepBackgroundColor(step))
        )
        .overlay(
            RoundedRectangle(cornerRadius: UITheme.CornerRadius.card)
                .stroke(stepBorderColor(step), lineWidth: 1)
        )
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            Text("Quick Actions")
                .font(UITheme.Typography.title2)
                .foregroundColor(UITheme.Colors.primaryText)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: UITheme.Spacing.md) {
                quickActionButton(
                    title: "Sync Moodle",
                    icon: "arrow.triangle.2.circlepath",
                    action: { setupManager.syncMoodle() }
                )
                
                quickActionButton(
                    title: "Import Calendar",
                    icon: "calendar.badge.plus",
                    action: { setupManager.importCalendar() }
                )
                
                quickActionButton(
                    title: "Test Notifications",
                    icon: "bell.badge",
                    action: { setupManager.testNotifications() }
                )
                
                quickActionButton(
                    title: "View Tutorial",
                    icon: "play.circle",
                    action: { setupManager.showTutorial() }
                )
            }
        }
    }
    
    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: UITheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(UITheme.Colors.primary)
                
                Text(title)
                    .font(UITheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UITheme.Colors.primaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(UITheme.Spacing.md)
        }
        .themeCard()
    }
    
    // MARK: - Helper Methods
    
    private func stepBackgroundColor(_ step: SetupStep) -> Color {
        if setupManager.completedSteps.contains(step) {
            return UITheme.Colors.success.opacity(0.1)
        } else if setupManager.inProgressSteps.contains(step) {
            return UITheme.Colors.warning.opacity(0.1)
        } else {
            return UITheme.Colors.cardBackground
        }
    }
    
    private func stepBorderColor(_ step: SetupStep) -> Color {
        if setupManager.completedSteps.contains(step) {
            return UITheme.Colors.success.opacity(0.3)
        } else if setupManager.inProgressSteps.contains(step) {
            return UITheme.Colors.warning.opacity(0.3)
        } else {
            return UITheme.Colors.cardBorder
        }
    }
}

// MARK: - Setup Manager

class SetupManager: ObservableObject {
    @Published var completedSteps: Set<SetupStep> = []
    @Published var inProgressSteps: Set<SetupStep> = []
    
    var allSteps: [SetupStep] { SetupStep.allCases }
    var nextSteps: [SetupStep] { 
        allSteps.filter { !completedSteps.contains($0) && !inProgressSteps.contains($0) }
    }
    
    var completionPercentage: Double {
        guard !allSteps.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(allSteps.count)
    }
    
    var isCompletelySetup: Bool {
        return completedSteps.count == allSteps.count
    }
    
    func checkSetupStatus() {
        // Check each setup step and update status
        for step in allSteps {
            if isStepCompleted(step) {
                completedSteps.insert(step)
                inProgressSteps.remove(step)
            }
        }
    }
    
    func performSetupStep(_ step: SetupStep) {
        inProgressSteps.insert(step)
        
        _Concurrency.Task {
            do {
                try await executeSetupStep(step)
                self.inProgressSteps.remove(step)
                self.completedSteps.insert(step)
            } catch {
                self.inProgressSteps.remove(step)
                print("Setup step failed: \(error)")
            }
        }
    }
    
    private func isStepCompleted(_ step: SetupStep) -> Bool {
        switch step {
        case .connectMoodle:
            return UserDefaults.standard.string(forKey: "MoodleBaseURL") != nil
        case .authorizeCalendar:
            return UserDefaults.standard.bool(forKey: "CalendarAuthorized")
        case .enableNotifications:
            return UserDefaults.standard.bool(forKey: "NotificationsAuthorized")
        case .connectReminders:
            return UserDefaults.standard.bool(forKey: "RemindersConnected")
        case .setupGoodNotes:
            return UserDefaults.standard.bool(forKey: "GoodNotesSetup")
        case .configureGPA:
            return UserDefaults.standard.object(forKey: "GPAConfigured") != nil
        case .setAcademicTerm:
            return UserDefaults.standard.object(forKey: "AcademicTermSet") != nil
        case .customizeAppearance:
            return UserDefaults.standard.bool(forKey: "AppearanceCustomized")
        }
    }
    
    private func executeSetupStep(_ step: SetupStep) async throws {
        switch step {
        case .connectMoodle:
            // Launch Moodle setup
            NotificationCenter.default.post(name: .launchMoodleSetup, object: nil)
        case .authorizeCalendar:
            // Request calendar permission
            let eventKitBridge = EventKitBridge()
            _ = await eventKitBridge.requestAccess()
            UserDefaults.standard.set(true, forKey: "CalendarAuthorized")
        case .enableNotifications:
            // Request notification permission
            let notificationService = NotificationService()
            _ = await notificationService.requestAuthorization()
            UserDefaults.standard.set(true, forKey: "NotificationsAuthorized")
        case .connectReminders:
            // Connect to Apple Reminders
            UserDefaults.standard.set(true, forKey: "RemindersConnected")
        case .setupGoodNotes:
            // Setup GoodNotes integration
            UserDefaults.standard.set(true, forKey: "GoodNotesSetup")
        case .configureGPA:
            // Configure GPA calculation
            UserDefaults.standard.set(Date(), forKey: "GPAConfigured")
        case .setAcademicTerm:
            // Set academic term dates
            UserDefaults.standard.set(Date(), forKey: "AcademicTermSet")
        case .customizeAppearance:
            // Mark appearance as customized
            UserDefaults.standard.set(true, forKey: "AppearanceCustomized")
        }
    }
    
    // MARK: - Quick Actions
    
    func syncMoodle() {
        // Trigger Moodle sync
        NotificationCenter.default.post(name: .syncMoodle, object: nil)
    }
    
    func importCalendar() {
        // Import calendar events
        NotificationCenter.default.post(name: .importCalendar, object: nil)
    }
    
    func testNotifications() {
        // Send test notification
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Notifications are working correctly!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Failed to send test notification: \(error)")
            }
        }
    }
    
    func showTutorial() {
        // Show app tutorial
        NotificationCenter.default.post(name: .showTutorial, object: nil)
    }
}

// MARK: - Setup Steps

enum SetupStep: String, CaseIterable {
    case connectMoodle
    case authorizeCalendar
    case enableNotifications
    case connectReminders
    case setupGoodNotes
    case configureGPA
    case setAcademicTerm
    case customizeAppearance
    
    var title: String {
        switch self {
        case .connectMoodle:
            return "Connect to Moodle"
        case .authorizeCalendar:
            return "Authorize Calendar Access"
        case .enableNotifications:
            return "Enable Notifications"
        case .connectReminders:
            return "Connect Apple Reminders"
        case .setupGoodNotes:
            return "Setup GoodNotes Integration"
        case .configureGPA:
            return "Configure GPA Calculation"
        case .setAcademicTerm:
            return "Set Academic Term"
        case .customizeAppearance:
            return "Customize Appearance"
        }
    }
    
    var description: String {
        switch self {
        case .connectMoodle:
            return "Sync courses, assignments, and grades from your Moodle site"
        case .authorizeCalendar:
            return "Allow Planora to read and create calendar events"
        case .enableNotifications:
            return "Get reminders for classes, assignments, and deadlines"
        case .connectReminders:
            return "Sync tasks with Apple Reminders app"
        case .setupGoodNotes:
            return "Link course notes and materials"
        case .configureGPA:
            return "Set up automatic GPA calculation and tracking"
        case .setAcademicTerm:
            return "Define your current academic term dates"
        case .customizeAppearance:
            return "Choose your preferred theme and accent color"
        }
    }
    
    var actionTitle: String {
        switch self {
        case .connectMoodle:
            return "Connect"
        case .authorizeCalendar:
            return "Authorize"
        case .enableNotifications:
            return "Enable"
        case .connectReminders:
            return "Connect"
        case .setupGoodNotes:
            return "Setup"
        case .configureGPA:
            return "Configure"
        case .setAcademicTerm:
            return "Set Dates"
        case .customizeAppearance:
            return "Customize"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .connectMoodle, .authorizeCalendar, .enableNotifications:
            return true
        default:
            return false
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let launchMoodleSetup = Notification.Name("launchMoodleSetup")
    static let syncMoodle = Notification.Name("syncMoodle")
    static let importCalendar = Notification.Name("importCalendar")
    static let showTutorial = Notification.Name("showTutorial")
}

// MARK: - Preview Support

#if DEBUG
struct SetupCenterView_Previews: PreviewProvider {
    static var previews: some View {
        SetupCenterView()
            .previewDisplayName("Setup Center")
        
        SetupCenterView()
            .preferredColorScheme(.dark)
            .previewDisplayName("Setup Center - Dark")
    }
}
#endif
