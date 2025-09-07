//
// HomeView.swift
// Minimal dashboard: QuickAdd, Next Class, Upcoming Events, Grade Insights, Habits, Weather, Quick Actions
// Uses Fantastical × Todoist aesthetic with edge-to-edge style

import SwiftUI
import CoreData
import EventKit

struct HomeView: View {
    @Environment(\.managedObjectContext) private var moc
    @StateObject private var attendanceService = AttendanceService()
    @StateObject private var eventKitBridge = EventKitBridge()
    @StateObject private var quickAddParser = QuickAddParser()
    
    @State private var upcomingEvents: [UnifiedEvent] = []
    @State private var showingQuickActions = false
    
    // Fetch upcoming tasks (next 7 days, incomplete)
    @FetchRequest private var tasks: FetchedResults<Task>
    // Fetch recent grades
    @FetchRequest private var grades: FetchedResults<Grade>
    // Fetch today's habits
    @FetchRequest private var habits: FetchedResults<Habit>

    init() {
        let now = Date()
        let oneWeek = Calendar.current.date(byAdding: .day, value: 7, to: now)!

        _tasks = FetchRequest<Task>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)],
            predicate: NSPredicate(format: "isCompleted == NO AND dueDate >= %@ AND dueDate <= %@", now as NSDate, oneWeek as NSDate)
        )

        _grades = FetchRequest<Grade>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Grade.updatedAt, ascending: false)],
            predicate: nil
        )
        
        _habits = FetchRequest<Habit>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Habit.name, ascending: true)],
            predicate: nil
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: UITheme.Spacing.lg) {
                // Quick Add Bar
                QuickAddBar { parsedItem in
                    handleQuickAddItem(parsedItem)
                }
                .screenPadding()
                
                // Next Class Section
                if let nextClass = attendanceService.getNextClass() {
                    nextClassSection(nextClass.session, timeToStart: nextClass.timeToStart)
                        .screenPadding()
                }
                
                // Upcoming Events
                upcomingEventsSection
                    .screenPadding()
                
                // Grade Insights
                if !grades.isEmpty {
                    gradeInsightsSection
                        .screenPadding()
                }
                
                // Habits Today
                if !habits.isEmpty {
                    habitsTodaySection
                        .screenPadding()
                }
                
                // Weather Card
                WeatherCard(compact: false) {
                    // Handle location tap
                }
                .screenPadding()
                
                // Quick Actions
                quickActionsSection
                    .screenPadding()
            }
            .padding(.bottom, UITheme.Spacing.xl)
        }
        .background(UITheme.Colors.background)
        .navigationBarHidden(true)
        .onAppear {
            loadUpcomingEvents()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - Section Views
    
    private func nextClassSection(_ session: AttendanceSession, timeToStart: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Next Class")
            
            NextClassCard(
                session: session,
                timeToStart: timeToStart,
                isOpen: attendanceService.isSessionOpen(session),
                onJoin: {
                    // Handle join meeting
                },
                onCheckIn: {
                    // Handle attendance check-in
                }
            )
        }
    }
    
    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Upcoming Events")
            
            if upcomingEvents.isEmpty {
                emptyStateView("No upcoming events", systemImage: "calendar")
            } else {
                LazyVStack(spacing: UITheme.Spacing.sm) {
                    ForEach(upcomingEvents.prefix(3), id: \.id) { event in
                        EventRow(
                            event: event,
                            showDate: true,
                            onJoin: {
                                // Handle join
                            },
                            onTap: {
                                // Handle event tap
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var gradeInsightsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Grade Insights")
            
            GradeInsightsCard(grades: Array(grades.prefix(6)))
        }
    }
    
    private var habitsTodaySection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Habits Today")
            
            HabitsTodayCard(habits: Array(habits))
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Quick Actions")
            
            QuickActionsGrid(
                onAddTask: { showingQuickActions = true },
                onStartPomodoro: { startPomodoro() },
                onAddJournal: { addJournalEntry() },
                onJoinMeeting: { joinUpcomingMeeting() }
            )
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(UITheme.Typography.title2)
            .foregroundColor(UITheme.Colors.primaryText)
    }
    
    private func emptyStateView(_ message: String, systemImage: String) -> some View {
        HStack(spacing: UITheme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(UITheme.Colors.tertiary)
            
            Text(message)
                .font(UITheme.Typography.body)
                .foregroundColor(UITheme.Colors.secondaryText)
            
            Spacer()
        }
        .themeCard()
    }
    
    // MARK: - Actions
    
    private func handleQuickAddItem(_ parsedItem: ParsedItem) {
        // Item was already created by QuickAddParser
        // Refresh UI if needed
        if parsedItem.type == .event {
            loadUpcomingEvents()
        }
    }
    
    private func loadUpcomingEvents() {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        upcomingEvents = eventKitBridge.getUnifiedEvents(from: startDate, to: endDate)
    }
    
    private func refreshData() async {
        // Refresh all data sources
        loadUpcomingEvents()
        // Add other refresh logic here
    }
    
    private func startPomodoro() {
        // Navigate to pomodoro view
    }
    
    private func addJournalEntry() {
        // Navigate to journal entry creation
    }
    
    private func joinUpcomingMeeting() {
        // Join the next upcoming meeting
        if upcomingEvents.first(where: { $0.meetingURL != nil }) != nil {
            // Open meeting URL
        }
    }
}

// MARK: - Components

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3).bold()
            content
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }
}

// Removed duplicate NextClassCard; use the one in HomeComponents

// Note: TaskRow is defined in TasksView.swift to avoid duplication

private struct GradeGlance: View {
    let grades: [Grade]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(grades) { g in
                HStack {
                    Text(g.name ?? "Grade")
                    Spacer()
                    Text(scoreString(g)).bold()
                }
            }
        }
    }
    private func scoreString(_ g: Grade) -> String {
        let s = g.score
        let m = g.totalPoints == 0 ? 100 : g.totalPoints
        if m > 0 { return String(format: "%.1f/%.0f", s, m) }
        return String(format: "%.1f", s)
    }
}

private struct QuickActionsRow: View {
    let onJoinMeeting: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: "Add Task", systemName: "plus.circle") { }
            QuickActionButton(title: "Pomodoro", systemName: "timer") { }
            QuickActionButton(title: "Join Meeting", systemName: "video") { onJoinMeeting() }
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: systemName).imageScale(.large)
                Text(title).font(.footnote)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
        }
    }
}
