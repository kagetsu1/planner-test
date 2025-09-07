//
import SwiftUI

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            // Home (new)
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(1)

            CoursesView()
                .tabItem { Label("Courses", systemImage: "book") }
                .tag(2)

            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(3)

            GradesView()
                .tabItem { Label("Grades", systemImage: "chart.bar") }
                .tag(4)

            HabitsView()
                .tabItem { Label("Habits", systemImage: "target") }
                .tag(5)

            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(6)

            PomodoroView()
                .tabItem { Label("Pomodoro", systemImage: "timer") }
                .tag(7)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(8)
        }
        .themedAccentColor()
        .onAppear { themeManager.applyTheme() }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(MoodleService())
            .environmentObject(CalendarService())
            .environmentObject(NotificationService())
    }
}
