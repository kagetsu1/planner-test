import SwiftUI
import CoreData
import WidgetKit
import UserNotifications

@main
struct PlanoraApp: App {
    @StateObject private var dataController = DataController.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var backupService = BackupService.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        // Configure notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.currentUser != nil {
                    MainAppView()
                } else {
                    LoginView()
                }
            }
            .environment(\.managedObjectContext, dataController.container.viewContext)
            .environmentObject(authService)
            .environmentObject(themeManager)
            .onAppear {
                setupApp()
            }
        }
    }
    
    private func setupApp() {
        themeManager.applyTheme()
        themeManager.syncAccentToAppGroup()
        
        // Initialize Core Data
        _ = dataController.container.viewContext
    }
}

struct MainAppView: View {
    @StateObject private var moodleService = MoodleService()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var goodNotesService = GoodNotesService()
    
    var body: some View {
        ContentView()
            .environmentObject(moodleService)
            .environmentObject(calendarService)
            .environmentObject(notificationService)
            .environmentObject(goodNotesService)
            .onAppear {
                initializeServices()
            }
    }
    
    private func initializeServices() {
        calendarService.initialize()
        notificationService.checkAuthorizationStatus()
    }
}
