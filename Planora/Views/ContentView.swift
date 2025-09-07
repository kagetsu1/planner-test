//
import SwiftUI

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("selectedTab") private var selectedTab = 0
    @State private var isLoading = true
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else {
                mainTabView
            }
        }
        .onAppear {
            initializeApp()
        }
    }
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
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
    }
    
    private func initializeApp() {
        // Simulate initialization delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isLoading = false
            }
        }
        
        themeManager.applyTheme()
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("Planora")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 10)
            }
        }
        .onAppear {
            isAnimating = true
        }
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
