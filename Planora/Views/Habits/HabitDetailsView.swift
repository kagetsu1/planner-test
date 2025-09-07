import SwiftUI
import CoreData

struct HabitDetailsView: View {
    let habit: Habit
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Habit Header
                habitHeader
                
                // Habit Statistics
                habitStatistics
                
                // Recent Entries
                recentEntries
            }
            .padding()
        }
        .navigationTitle(habit.name ?? "Habit Details")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Habit Header
    private var habitHeader: some View {
        VStack(spacing: 12) {
            Text(habit.name ?? "Unknown Habit")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Notes not available in current Habit model
            
            HStack(spacing: 16) {
                StatRow(title: "Target", value: "\(habit.targetCount) times")
                StatRow(title: "Frequency", value: "Daily")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Habit Statistics
    private var habitStatistics: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                HabitStatCard(
                    title: "Total Entries",
                    value: "\(habit.entries?.count ?? 0)",
                    subtitle: "completed",
                    color: Color.blue
                )
                
                HabitStatCard(
                    title: "Success Rate",
                    value: "85%",
                    subtitle: "this week",
                    color: Color.green
                )
            }
        }
    }
    
    // MARK: - Recent Entries
    private var recentEntries: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Entries")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let entries = habit.entries?.allObjects as? [HabitEntry], !entries.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(entries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }.prefix(10), id: \.objectID) { entry in
                        HStack {
                            Text(entry.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown Date")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            if entry.completedAt != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                Text("No entries yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

// MARK: - Helper Views
struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct HabitStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    let context = DataController.shared.container.viewContext
    let habit = Habit(context: context)
    habit.name = "Exercise"
    habit.targetCount = 1
    
    return NavigationView {
        HabitDetailsView(habit: habit)
            .environment(\.managedObjectContext, context)
    }
}
