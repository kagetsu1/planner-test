//
// HomeView.swift
// Minimal dashboard: QuickAdd, Next Class, Upcoming Events, Grade Insights, Habits, Weather, Quick Actions
// Uses Fantastical × Todoist aesthetic with edge-to-edge style

import SwiftUI
import CoreData
import EventKit

struct HomeView: View {
    @Environment(\.managedObjectContext) private var moc
    @State private var attendanceService: AttendanceService?
    @State private var eventKitBridge: EventKitBridge?
    @State private var quickAddParser: QuickAddParser?
    
    @State private var upcomingEvents: [UnifiedEvent] = []
    @State private var showingQuickActions = false
    @State private var isInitialized = false
    
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
        Group {
            if isInitialized {
                homeContent
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(UITheme.Colors.background)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            initializeServices()
        }
    }
    
    private var homeContent: some View {
        ScrollView {
            VStack(spacing: UITheme.Spacing.lg) {
                // Quick Add Bar
                if let parser = quickAddParser {
                    QuickAddBar { parsedItem in
                        handleQuickAddItem(parsedItem)
                    }
                        .screenPadding()
                }
                
                // Next Class Section
                if let attendanceService = attendanceService,
                   let nextClass = attendanceService.getNextClass() {
                    nextClassSection(nextClass.session, timeToStart: nextClass.timeToStart)
                        .screenPadding()
                }
                
                // Content sections
                contentSections
                    .screenPadding()
            }
            .padding(.bottom, UITheme.Spacing.xl)
        }
        .background(UITheme.Colors.background)
        .refreshable {
            await refreshData()
        }
    }
    
    private var contentSections: some View {
        VStack(spacing: UITheme.Spacing.lg) {
            // Upcoming Events
            upcomingEventsSection
            
            // Grade Insights
            if !grades.isEmpty {
                gradeInsightsSection
            }
            
            // Habits Today
            if !habits.isEmpty {
                habitsTodaySection
            }
            
            // Weather Card
            WeatherCard(compact: false) {
                // Handle location tap
            }
            
            // Quick Actions
            quickActionsSection
        }
    }
    
    private func initializeServices() {
        guard !isInitialized else { return }
        
        DispatchQueue.main.async {
            self.attendanceService = AttendanceService()
            self.eventKitBridge = EventKitBridge()
            self.quickAddParser = QuickAddParser()
            
            self.isInitialized = true
            
            // Load initial data
            self.loadUpcomingEvents()
        }
    }
    
    // MARK: - Section Views (simplified to avoid crashes)
    
    private func nextClassSection(_ session: AttendanceSession, timeToStart: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Next Class")
            
            VStack(alignment: .leading, spacing: UITheme.Spacing.sm) {
                Text("Upcoming Class")
                    .font(UITheme.Typography.title3)
                    .foregroundColor(UITheme.Colors.primaryText)
                
                if let room = session.room {
                    Text("Room: \(room)")
                        .font(UITheme.Typography.caption)
                        .foregroundColor(UITheme.Colors.secondaryText)
                }
                
                if timeToStart > 0 {
                    Text("Starts in \(formatTimeToStart(timeToStart))")
                        .font(UITheme.Typography.caption)
                        .foregroundColor(UITheme.Colors.primary)
                }
            }
            .themeCard()
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
                        SimpleEventRow(event: event)
                    }
                }
            }
        }
    }
    
    private var gradeInsightsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Recent Grades")
            
            LazyVStack(spacing: UITheme.Spacing.sm) {
                ForEach(grades.prefix(3), id: \.objectID) { grade in
                    SimpleGradeRow(grade: grade)
                }
            }
        }
    }
    
    private var habitsTodaySection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Today's Habits")
            
            LazyVStack(spacing: UITheme.Spacing.sm) {
                ForEach(habits.prefix(3), id: \.objectID) { habit in
                    SimpleHabitRow(habit: habit)
                }
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Quick Actions")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: UITheme.Spacing.md) {
                quickActionButton("Add Task", "plus.circle.fill", UITheme.Colors.primary) {
                    // Add task action
                }
                
                quickActionButton("Start Timer", "timer.circle.fill", UITheme.Colors.warning) {
                    // Start pomodoro action
                }
                
                quickActionButton("Add Journal", "book.circle.fill", UITheme.Colors.info) {
                    // Add journal action
                }
                
                quickActionButton("View Calendar", "calendar.circle.fill", UITheme.Colors.success) {
                    // View calendar action
                }
            }
        }
    }
    
    private func quickActionButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: UITheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(UITheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UITheme.Colors.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(UITheme.Spacing.md)
        }
        .themeCard()
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
    
    private func formatTimeToStart(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
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
        guard let eventKitBridge = eventKitBridge else { return }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        upcomingEvents = eventKitBridge.getUnifiedEvents(from: startDate, to: endDate)
    }
    
    private func refreshData() async {
        // Refresh all data sources
        loadUpcomingEvents()
        // Add other refresh logic here
    }
}

// MARK: - Simplified Row Components

private struct SimpleEventRow: View {
    let event: UnifiedEvent
    
    var body: some View {
        HStack(spacing: UITheme.Spacing.md) {
            VStack(alignment: .leading, spacing: UITheme.Spacing.xs) {
                Text(event.title)
                    .font(UITheme.Typography.body)
                    .foregroundColor(UITheme.Colors.primaryText)
                    .lineLimit(1)
                
                Text(event.startDate, style: .time)
                    .font(UITheme.Typography.caption)
                    .foregroundColor(UITheme.Colors.secondaryText)
            }
            
            Spacer()
            
            if let location = event.location {
                Text(location)
                    .font(UITheme.Typography.caption)
                    .foregroundColor(UITheme.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .themeCard()
    }
}

private struct SimpleGradeRow: View {
    let grade: Grade
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(grade.name ?? "Assignment")
                    .font(UITheme.Typography.caption)
                    .foregroundColor(UITheme.Colors.primaryText)
                
                if let courseName = grade.course?.courseName {
                    Text(courseName)
                        .font(UITheme.Typography.caption2)
                        .foregroundColor(UITheme.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            Text(formatGrade(grade))
                .font(UITheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(gradeColor(grade))
        }
        .themeCard()
    }
    
    private func formatGrade(_ grade: Grade) -> String {
        let percentage = grade.totalPoints > 0 ? (grade.score / grade.totalPoints) * 100 : 0
        return String(format: "%.0f%%", percentage)
    }
    
    private func gradeColor(_ grade: Grade) -> Color {
        let percentage = grade.totalPoints > 0 ? (grade.score / grade.totalPoints) * 100 : 0
        
        if percentage >= 90 {
            return UITheme.Colors.success
        } else if percentage >= 80 {
            return UITheme.Colors.info
        } else if percentage >= 70 {
            return UITheme.Colors.warning
        } else {
            return UITheme.Colors.error
        }
    }
}

private struct SimpleHabitRow: View {
    let habit: Habit
    
    var body: some View {
        HStack {
            Text(habit.name ?? "Habit")
                .font(UITheme.Typography.caption)
                .foregroundColor(UITheme.Colors.primaryText)
            
            Spacer()
            
            Circle()
                .stroke(UITheme.Colors.primary, lineWidth: 2)
                .frame(width: 16, height: 16)
        }
        .themeCard()
    }
}

// Remove the complex components that were causing issues

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

private struct GradeGlance: View {
    let grades: [Grade]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(grades.prefix(3), id: \.objectID) { g in
                HStack {
                    Text(g.name ?? "Grade")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(scoreString(g))
                        .font(.caption)
                        .bold()
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

// MARK: - Simplified sections to avoid crashes

extension HomeView {
    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Upcoming Events")
            
            if upcomingEvents.isEmpty {
                emptyStateView("No upcoming events", systemImage: "calendar")
            } else {
                LazyVStack(spacing: UITheme.Spacing.sm) {
                    ForEach(upcomingEvents.prefix(3), id: \.id) { event in
                        SimpleEventRow(event: event)
                    }
                }
            }
        }
    }
    
    private var gradeInsightsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Recent Grades")
            
            LazyVStack(spacing: UITheme.Spacing.sm) {
                ForEach(grades.prefix(3), id: \.objectID) { grade in
                    SimpleGradeRow(grade: grade)
                }
            }
        }
    }
    
    private var habitsTodaySection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Today's Habits")
            
            LazyVStack(spacing: UITheme.Spacing.sm) {
                ForEach(habits.prefix(3), id: \.objectID) { habit in
                    SimpleHabitRow(habit: habit)
                }
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            sectionHeader("Quick Actions")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: UITheme.Spacing.md) {
                quickActionButton("Add Task", "plus.circle.fill", UITheme.Colors.primary) {
                    // Add task action
                }
                
                quickActionButton("Start Timer", "timer.circle.fill", UITheme.Colors.warning) {
                    // Start pomodoro action
                }
                
                quickActionButton("Add Journal", "book.circle.fill", UITheme.Colors.info) {
                    // Add journal action
                }
                
                quickActionButton("View Calendar", "calendar.circle.fill", UITheme.Colors.success) {
                    // View calendar action
                }
            }
        }
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
        guard let eventKitBridge = eventKitBridge else { return }
        
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

// Remove complex components that were causing crashes

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

private struct GradeGlance: View {
    let grades: [Grade]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(grades.prefix(3), id: \.objectID) { g in
                HStack {
                    Text(g.name ?? "Grade")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(scoreString(g))
                        .font(.caption)
                        .bold()
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

// Remove the complex components that were causing issues

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
            ForEach(grades.prefix(3), id: \.objectID) { g in
                HStack {
                    Text(g.name ?? "Grade")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(scoreString(g))
                        .font(.caption)
                        .bold()
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

// Remove the complex components that were causing issues

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
