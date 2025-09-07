import SwiftUI
import CoreData

struct TasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var notificationService: NotificationService
    
    @State private var showingAddTask = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var searchText = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)],
        animation: .default)
    private var tasks: FetchedResults<Task>
    
    var filteredTasks: [Task] {
        let filtered = tasks.filter { task in
            if !searchText.isEmpty {
                return (task.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (task.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered
        case .pending:
            return filtered.filter { !$0.completed }
        case .completed:
            return filtered.filter { $0.completed }
        case .overdue:
            return filtered.filter { !$0.completed && ($0.dueDate ?? Date()) < Date() }
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            return filtered.filter { !$0.completed && ($0.dueDate ?? Date()) >= today && ($0.dueDate ?? Date()) < tomorrow }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Task Statistics
                taskStatistics
                
                // Tasks List
                tasksList
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView()
            }
        }
    }
    
    // MARK: - Search and Filter Bar
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search tasks...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TaskFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            title: filter.title,
                            count: countForFilter(filter),
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Task Statistics
    private var taskStatistics: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total",
                value: "\(tasks.count)",
                subtitle: "tasks",
                color: .blue
            )
            
            StatCard(
                title: "Pending",
                value: "\(tasks.filter { !$0.completed }.count)",
                subtitle: "remaining",
                color: .orange
            )
            
            StatCard(
                title: "Completed",
                value: "\(tasks.filter { $0.completed }.count)",
                subtitle: "done",
                color: .green
            )
            
            StatCard(
                title: "Overdue",
                value: "\(tasks.filter { !$0.completed && ($0.dueDate ?? Date()) < Date() }.count)",
                subtitle: "late",
                color: .red
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tasks List
    private var tasksList: some View {
        Group {
            if filteredTasks.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredTasks, id: \.id) { task in
                        TaskRow(task: task) {
                            toggleTaskCompletion(task)
                        }
                    }
                    .onDelete(perform: deleteTasks)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Task") {
                showingAddTask = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Methods
    private func countForFilter(_ filter: TaskFilter) -> Int {
        switch filter {
        case .all:
            return tasks.count
        case .pending:
            return tasks.filter { !$0.completed }.count
        case .completed:
            return tasks.filter { $0.completed }.count
        case .overdue:
            return tasks.filter { !$0.completed && ($0.dueDate ?? Date()) < Date() }.count
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            return tasks.filter { !$0.completed && ($0.dueDate ?? Date()) >= today && ($0.dueDate ?? Date()) < tomorrow }.count
        }
    }
    
    private func toggleTaskCompletion(_ task: Task) {
        task.completed.toggle()
        task.completedAt = task.completed ? Date() : nil
        
        if task.completed {
            notificationService.cancelTaskReminders(for: task)
        } else if task.dueDate != nil {
            notificationService.scheduleTaskReminder(for: task)
            notificationService.scheduleTaskDueNotification(for: task)
        }
        
        saveContext()
    }
    
    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredTasks[$0] }.forEach { task in
                notificationService.cancelTaskReminders(for: task)
                viewContext.delete(task)
            }
            saveContext()
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "No tasks yet"
        case .pending:
            return "No pending tasks"
        case .completed:
            return "No completed tasks"
        case .overdue:
            return "No overdue tasks"
        case .today:
            return "No tasks due today"
        }
    }
    
    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .all:
            return "Create your first task to get started"
        case .pending:
            return "All caught up! Great job"
        case .completed:
            return "Complete some tasks to see them here"
        case .overdue:
            return "You're all caught up with deadlines"
        case .today:
            return "No tasks scheduled for today"
        }
    }
}

// MARK: - Task Filter
enum TaskFilter: CaseIterable {
    case all, pending, completed, overdue, today
    
    var title: String {
        switch self {
        case .all: return "All"
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .overdue: return "Overdue"
        case .today: return "Today"
        }
    }
}



// MARK: - Task Row
struct TaskRow: View {
    let task: Task
    let onToggle: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion Button
            Button(action: onToggle) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.completed ? .green : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Task Details
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled Task")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(task.completed)
                    .foregroundColor(task.completed ? .secondary : .primary)
                
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        Label(
                            dateFormatter.string(from: dueDate),
                            systemImage: "calendar"
                        )
                        .font(.caption)
                        .foregroundColor(isOverdue ? .red : .secondary)
                    }
                    
                    if task.priority > 0 {
                        let priorityString = task.priority == 2 ? "High" : task.priority == 1 ? "Medium" : "Low"
                        PriorityBadge(priority: priorityString)
                    }
                }
            }
            
            Spacer()
            
            // Course indicator
            if let courseInfo = task.course {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(courseInfo.courseCode ?? "")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text(courseInfo.courseName ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var isOverdue: Bool {
        guard let dueDate = task.dueDate else { return false }
        return !task.completed && dueDate < Date()
    }
}

// MARK: - Priority Badge
struct PriorityBadge: View {
    let priority: String
    
    var body: some View {
        Text(priority.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(priorityColor)
            )
            .foregroundColor(.white)
    }
    
    private var priorityColor: Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }
}

// MARK: - Supporting Views
private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview
struct TasksView_Previews: PreviewProvider {
    static var previews: some View {
        TasksView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(NotificationService())
    }
}
