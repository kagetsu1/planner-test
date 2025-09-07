import SwiftUI
import CoreData
import WidgetKit

@main
struct PlanoraApp: App {
    @StateObject private var dataController = DataController.shared
    @StateObject private var moodleService = MoodleService()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var goodNotesService = GoodNotesService()
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var backupService = BackupService.shared
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(moodleService)
                .environmentObject(calendarService)
                .environmentObject(notificationService)
                .environmentObject(goodNotesService)
                .environmentObject(authService)
                .onAppear {
                    themeManager.applyTheme()
                    themeManager.syncAccentToAppGroup()
                }
        }
    }
}
