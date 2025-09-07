import SwiftUI

// MARK: - Next Class Card

struct NextClassCard: View {
    let session: AttendanceSession
    let timeToStart: TimeInterval
    let isOpen: Bool
    let onJoin: () -> Void
    let onCheckIn: () -> Void
    
    private let conferenceDetector = ConferenceLinkDetector()
    @State private var conferenceLink: ConferenceLink?
    
    var body: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: UITheme.Spacing.xs) {
                    Text(courseTitle)
                        .font(UITheme.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(UITheme.Colors.primaryText)
                    
                    if let room = session.room {
                        HStack(spacing: UITheme.Spacing.xs) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(UITheme.Colors.secondary)
                            
                            Text(room)
                                .font(UITheme.Typography.caption)
                                .foregroundColor(UITheme.Colors.secondaryText)
                        }
                    }
                }
                
                Spacer()
                
                timeIndicator
            }
            
            HStack(spacing: UITheme.Spacing.sm) {
                // Join button (if meeting link available)
                if conferenceLink != nil {
                    Button(action: onJoin) {
                        HStack(spacing: UITheme.Spacing.xs) {
                            Image(systemName: "video.fill")
                                .font(.caption)
                            Text("Join")
                                .font(UITheme.Typography.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .themeButton(style: .primary)
                }
                
                // Check-in button (if session is open)
                if isOpen {
                    Button(action: onCheckIn) {
                        HStack(spacing: UITheme.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("Check In")
                                .font(UITheme.Typography.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .themeButton(style: .secondary)
                }
                
                Spacer()
            }
        }
        .themeCard()
        .onAppear {
            detectConferenceLink()
        }
    }
    
    private var courseTitle: String {
        // Get course title from course ID if available
        return "Next Class" // Simplified for now
    }
    
    private var timeIndicator: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if timeToStart > 0 {
                Text(formatTimeToStart(timeToStart))
                    .font(UITheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(timeToStart < 900 ? UITheme.Colors.warning : UITheme.Colors.primary) // 15 minutes
                
                Text("until class")
                    .font(UITheme.Typography.caption2)
                    .foregroundColor(UITheme.Colors.secondaryText)
            } else if isOpen {
                Text("Now")
                    .font(UITheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(UITheme.Colors.success)
                
                Text("in session")
                    .font(UITheme.Typography.caption2)
                    .foregroundColor(UITheme.Colors.secondaryText)
            }
        }
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
    
    private func detectConferenceLink() {
        let textToCheck = session.room ?? ""
        let links = conferenceDetector.detectLinks(in: textToCheck)
        conferenceLink = links.first
    }
}

// MARK: - Grade Insights Card

struct GradeInsightsCard: View {
    let grades: [Grade]
    
    var body: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            HStack {
                Text("Recent Grades")
                    .font(UITheme.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(UITheme.Colors.primaryText)
                
                Spacer()
                
                if let gpa = calculateGPA() {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f", gpa))
                            .font(UITheme.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(UITheme.Colors.primary)
                        
                        Text("GPA")
                            .font(UITheme.Typography.caption2)
                            .foregroundColor(UITheme.Colors.secondaryText)
                    }
                }
            }
            
            LazyVStack(spacing: UITheme.Spacing.sm) {
                ForEach(grades.prefix(4), id: \.objectID) { grade in
                    gradeRow(grade)
                }
            }
        }
        .themeCard()
    }
    
    private func gradeRow(_ grade: Grade) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(grade.name ?? "Assignment")
                    .font(UITheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UITheme.Colors.primaryText)
                
                if let courseName = grade.course?.courseName {
                    Text(courseName)
                        .font(UITheme.Typography.caption2)
                        .foregroundColor(UITheme.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatGrade(grade))
                    .font(UITheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(gradeColor(grade))
                
                Text("\(Int(grade.totalPoints))pts")
                    .font(UITheme.Typography.caption2)
                    .foregroundColor(UITheme.Colors.secondaryText)
            }
        }
    }
    
    private func formatGrade(_ grade: Grade) -> String {
        let percentage = (grade.score / grade.totalPoints) * 100
        return String(format: "%.0f%%", percentage)
    }
    
    private func gradeColor(_ grade: Grade) -> Color {
        let percentage = (grade.score / grade.totalPoints) * 100
        
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
    
    private func calculateGPA() -> Double? {
        guard !grades.isEmpty else { return nil }
        
        let totalPoints = grades.reduce(0) { $0 + $1.score }
        let maxPoints = grades.reduce(0) { $0 + $1.totalPoints }
        
        guard maxPoints > 0 else { return nil }
        
        let percentage = (totalPoints / maxPoints) * 100
        
        // Convert percentage to 4.0 scale (simplified)
        if percentage >= 97 { return 4.0 }
        else if percentage >= 93 { return 3.7 }
        else if percentage >= 90 { return 3.3 }
        else if percentage >= 87 { return 3.0 }
        else if percentage >= 83 { return 2.7 }
        else if percentage >= 80 { return 2.3 }
        else if percentage >= 77 { return 2.0 }
        else if percentage >= 73 { return 1.7 }
        else if percentage >= 70 { return 1.3 }
        else if percentage >= 67 { return 1.0 }
        else if percentage >= 65 { return 0.7 }
        else { return 0.0 }
    }
}

// MARK: - Habits Today Card

struct HabitsTodayCard: View {
    let habits: [Habit]
    
    var body: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            Text("Today's Habits")
                .font(UITheme.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(UITheme.Colors.primaryText)
            
            LazyVStack(spacing: UITheme.Spacing.sm) {
                ForEach(habits.prefix(3), id: \.objectID) { habit in
                    habitRow(habit)
                }
            }
        }
        .themeCard()
    }
    
    private func habitRow(_ habit: Habit) -> some View {
        HStack(spacing: UITheme.Spacing.md) {
            // Completion indicator
            Button(action: {
                toggleHabit(habit)
            }) {
                Circle()
                    .stroke(habitColor(habit), lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .fill(habitColor(habit))
                            .frame(width: 12, height: 12)
                            .opacity(isHabitCompleted(habit) ? 1 : 0)
                    )
            }
            
            // Habit info
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name ?? "Habit")
                    .font(UITheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UITheme.Colors.primaryText)
                
                if let frequency = habit.frequency {
                    Text(frequency)
                        .font(UITheme.Typography.caption2)
                        .foregroundColor(UITheme.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            // Progress indicator
            progressIndicator(habit)
        }
    }
    
    private func habitColor(_ habit: Habit) -> Color {
        guard let colorName = habit.color else { return UITheme.Colors.primary }
        
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        default: return UITheme.Colors.primary
        }
    }
    
    private func isHabitCompleted(_ habit: Habit) -> Bool {
        // Check if habit is completed today
        let today = Calendar.current.startOfDay(for: Date())
        
        return habit.entries?.contains { entry in
            guard let entryDate = (entry as? HabitEntry)?.date else { return false }
            return Calendar.current.isDate(entryDate, inSameDayAs: today)
        } ?? false
    }
    
    private func progressIndicator(_ habit: Habit) -> some View {
        let targetCount = Int(habit.targetCount)
        let completedToday = todayCompletionCount(habit)
        
        return HStack(spacing: UITheme.Spacing.xs) {
            Text("\(completedToday)/\(targetCount)")
                .font(UITheme.Typography.caption2)
                .foregroundColor(UITheme.Colors.secondaryText)
            
            if targetCount > 1 {
                ProgressView(value: Double(completedToday), total: Double(targetCount))
                    .progressViewStyle(LinearProgressViewStyle(tint: habitColor(habit)))
                    .frame(width: 30)
            }
        }
    }
    
    private func todayCompletionCount(_ habit: Habit) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        
        return habit.entries?.compactMap { entry in
            guard let habitEntry = entry as? HabitEntry,
                  let entryDate = habitEntry.date,
                  Calendar.current.isDate(entryDate, inSameDayAs: today) else { return nil }
            return Int(habitEntry.count)
        }.reduce(0, +) ?? 0
    }
    
    private func toggleHabit(_ habit: Habit) {
        // Implementation would toggle habit completion for today
        // This is a simplified version
    }
}

// MARK: - Quick Actions Grid

struct QuickActionsGrid: View {
    let onAddTask: () -> Void
    let onStartPomodoro: () -> Void
    let onAddJournal: () -> Void
    let onJoinMeeting: () -> Void
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: UITheme.Spacing.md) {
            QuickActionButton(
                title: "Add Task",
                icon: "plus.circle.fill",
                color: UITheme.Colors.primary,
                action: onAddTask
            )
            
            QuickActionButton(
                title: "Pomodoro",
                icon: "timer.circle.fill",
                color: UITheme.Colors.warning,
                action: onStartPomodoro
            )
            
            QuickActionButton(
                title: "Journal",
                icon: "book.circle.fill",
                color: UITheme.Colors.info,
                action: onAddJournal
            )
            
            QuickActionButton(
                title: "Join Meeting",
                icon: "video.circle.fill",
                color: UITheme.Colors.success,
                action: onJoinMeeting
            )
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
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
}
