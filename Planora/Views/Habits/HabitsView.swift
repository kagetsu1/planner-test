import SwiftUI
import CoreData

struct HabitsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var notificationService: NotificationService
    
    @State private var showingAddHabit = false
    @State private var selectedHabit: Habit?
    @State private var showingHabitDetails = false
    @State private var selectedTimeframe: HabitTimeframe = .week
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Habit.createdAt, ascending: false)],
        animation: .default)
    private var habits: FetchedResults<Habit>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Progress Overview
                    progressOverview
                    
                    // Timeframe Selector
                    timeframeSelector
                    
                    // Habits Grid
                    habitsGrid
                    
                    // Streak Leaderboard
                    streakLeaderboard
                }
                .padding()
            }
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddHabit = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
            }
            .sheet(isPresented: $showingHabitDetails) {
                if let habit = selectedHabit {
                    HabitDetailsView(habit: habit)
                }
            }
        }
    }
    
    // MARK: - Progress Overview
    private var progressOverview: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Progress")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(completedToday)/\(totalHabits)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Completion Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.0f%%", completionRate))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(completionRateColor)
                }
            }
            
            // Progress Bar
            ProgressView(value: completionRate, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: completionRateColor))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Timeframe Selector
    private var timeframeSelector: some View {
        HStack(spacing: 0) {
            ForEach(HabitTimeframe.allCases, id: \.self) { timeframe in
                Button(action: { selectedTimeframe = timeframe }) {
                    Text(timeframe.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTimeframe == timeframe ? Color.blue : Color.clear)
                        )
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Habits Grid
    private var habitsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(habits, id: \.id) { habit in
                HabitCard(habit: habit) {
                    selectedHabit = habit
                    showingHabitDetails = true
                }
            }
        }
    }
    
    // MARK: - Streak Leaderboard
    private var streakLeaderboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Streaks")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                if index < 3 {
                    StreakRow(habit: habit, rank: index + 1)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Computed Properties
    private var totalHabits: Int {
        habits.count
    }
    
    private var completedToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return habits.filter { habit in
            habit.entriesArray.contains { entry in
                Calendar.current.isDate(entry.date ?? Date(), inSameDayAs: today)
            }
        }.count
    }
    
    private var completionRate: Double {
        guard totalHabits > 0 else { return 0 }
        return (Double(completedToday) / Double(totalHabits)) * 100
    }
    
    private var completionRateColor: Color {
        switch completionRate {
        case 80...: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - Habit Timeframe
enum HabitTimeframe: CaseIterable {
    case week, month, year
    
    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

// MARK: - Habit Card
struct HabitCard: View {
    @Environment(\.managedObjectContext) private var viewContext
    let habit: Habit
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Circle()
                        .fill(Color(habit.color ?? "blue"))
                        .frame(width: 12, height: 12)
                    
                    Text(habit.name ?? "Untitled Habit")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(currentStreak)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                // Progress
                VStack(spacing: 4) {
                    HStack {
                        Text("This \(selectedTimeframe)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(completedCount)/\(targetCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: Double(completedCount), total: Double(targetCount))
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(habit.color ?? "blue")))
                }
                
                // Quick Action
                Button(action: toggleToday) {
                    HStack {
                        Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCompletedToday ? .green : .secondary)
                        
                        Text(isCompletedToday ? "Completed" : "Mark Complete")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isCompletedToday ? .green : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isCompletedToday ? Color.green.opacity(0.1) : Color(.systemGray6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    private var selectedTimeframe: String {
        // This would be based on the selected timeframe in the parent view
        return "week"
    }
    
    private var targetCount: Int {
        Int(habit.targetCount)
    }
    
    private var completedCount: Int {
        let startDate = getStartDate()
        return habit.entriesArray.filter { entry in
            guard let entryDate = entry.date else { return false }
            return entryDate >= startDate
        }.count
    }
    
    private var currentStreak: Int {
        var streak = 0
        let today = Calendar.current.startOfDay(for: Date())
        
        for dayOffset in 0... {
            let checkDate = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let hasEntry = habit.entriesArray.contains { entry in
                Calendar.current.isDate(entry.date ?? Date(), inSameDayAs: checkDate)
            }
            
            if hasEntry {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var isCompletedToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return habit.entriesArray.contains { entry in
            Calendar.current.isDate(entry.date ?? Date(), inSameDayAs: today)
        }
    }
    
    // MARK: - Helper Methods
    private func getStartDate() -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        // This would be based on the selected timeframe
        return Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
    }
    
    private func toggleToday() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if isCompletedToday {
            // Remove today's entry
            if let entry = habit.entriesArray.first(where: { entry in
                Calendar.current.isDate(entry.date ?? Date(), inSameDayAs: today)
            }) {
                viewContext.delete(entry)
            }
        } else {
            // Add today's entry
            let entry = HabitEntry(context: viewContext)
            entry.id = UUID()
            entry.date = today
            entry.completedAt = Date()
            entry.count = 1
            entry.habit = habit
        }
        
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

// MARK: - Streak Row
struct StreakRow: View {
    let habit: Habit
    let rank: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rankColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(rankColor.opacity(0.1))
                )
            
            // Habit Info
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name ?? "Untitled Habit")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(habit.frequency ?? "Daily")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Streak
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currentStreak)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var currentStreak: Int {
        var streak = 0
        let today = Calendar.current.startOfDay(for: Date())
        
        for dayOffset in 0... {
            let checkDate = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let hasEntry = habit.entriesArray.contains { entry in
                Calendar.current.isDate(entry.date ?? Date(), inSameDayAs: checkDate)
            }
            
            if hasEntry {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .blue
        }
    }
}

// MARK: - Extensions
extension Habit {
    var entriesArray: [HabitEntry] {
        let set = entries as? Set<HabitEntry> ?? []
        return Array(set).sorted { $0.date ?? Date() > $1.date ?? Date() }
    }
}

// MARK: - Preview
struct HabitsView_Previews: PreviewProvider {
    static var previews: some View {
        HabitsView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(NotificationService())
    }
}
