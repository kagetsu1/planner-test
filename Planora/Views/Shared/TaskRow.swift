import SwiftUI

/// Reusable task row component for displaying tasks in lists
struct SharedTaskRow: View {
    @ObservedObject var task: Task
    let showProject: Bool
    let showDueDate: Bool
    let showCourse: Bool
    let onToggle: ((Task) -> Void)?
    let onTap: ((Task) -> Void)?
    
    @State private var isToggling = false
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    init(
        task: Task,
        showProject: Bool = true,
        showDueDate: Bool = true,
        showCourse: Bool = false,
        onToggle: ((Task) -> Void)? = nil,
        onTap: ((Task) -> Void)? = nil
    ) {
        self.task = task
        self.showProject = showProject
        self.showDueDate = showDueDate
        self.showCourse = showCourse
        self.onToggle = onToggle
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: UITheme.Spacing.md) {
            // Completion checkbox
            completionButton
            
            // Task content
            VStack(alignment: .leading, spacing: UITheme.Spacing.xs) {
                // Title row
                HStack {
                    taskTitle
                    
                    Spacer()
                    
                    // Priority indicator
                    if taskPriority > 0 {
                        priorityIndicator
                    }
                }
                
                // Metadata row
                if hasMetadata {
                    metadataRow
                }
                
                // Labels and project
                if hasLabelsOrProject {
                    labelsAndProjectRow
                }
            }
            
            // Calendar toggle
            if task.showOnCalendar {
                calendarIndicator
            }
        }
        .padding(UITheme.Spacing.md)
        .background(taskBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: UITheme.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: UITheme.CornerRadius.card)
                .stroke(taskBorderColor, lineWidth: 0.5)
        )
        .scaleEffect(isToggling ? 0.98 : 1.0)
        .animation(UITheme.Animation.buttonPress, value: isToggling)
        .onTapGesture {
            onTap?(task)
        }
    }
    
    private var completionButton: some View {
        Button(action: toggleCompletion) {
            ZStack {
                Circle()
                    .stroke(checkboxStrokeColor, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .modifier(iOS16FontWeight(.semibold))
                        .foregroundColor(checkboxStrokeColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .scaleEffect(isToggling ? 1.2 : 1.0)
        .animation(UITheme.Animation.buttonPress, value: isToggling)
    }
    
    private var taskTitle: some View {
        Text(task.title ?? "Untitled Task")
            .font(UITheme.Typography.body)
            .foregroundColor(titleColor)
            .strikethrough(isCompleted)
            .lineLimit(2)
            .animation(UITheme.Animation.standard, value: isCompleted)
    }
    
    private var priorityIndicator: some View {
        HStack(spacing: UITheme.Spacing.xs) {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
            
            Text("P\(taskPriority)")
                .font(UITheme.Typography.caption2)
                .foregroundColor(priorityColor)
        }
    }
    
    private var metadataRow: some View {
        HStack(spacing: UITheme.Spacing.sm) {
            // Due date
            if showDueDate, let dueDate = task.dueDate {
                dueDateView(dueDate)
            }
            
            // Course
            if showCourse, let course = task.course {
                courseView(course)
            }
            
            Spacer()
            
            // Reminder indicator
            if task.reminderTime != nil {
                reminderIndicator
            }
        }
    }
    
    private func dueDateView(_ dueDate: Date) -> some View {
        HStack(spacing: UITheme.Spacing.xs) {
            Image(systemName: "clock.fill")
                .font(.caption2)
                .foregroundColor(dueDateColor(dueDate))
            
            Text(formatDueDate(dueDate))
                .font(UITheme.Typography.caption)
                .foregroundColor(dueDateColor(dueDate))
        }
    }
    
    private func courseView(_ course: Course) -> some View {
        HStack(spacing: UITheme.Spacing.xs) {
            Image(systemName: "book.fill")
                .font(.caption2)
                .foregroundColor(UITheme.Colors.tertiary)
            
            Text(course.courseCode ?? course.courseName ?? "Course")
                .font(UITheme.Typography.caption)
                .foregroundColor(UITheme.Colors.secondaryText)
        }
    }
    
    private var reminderIndicator: some View {
        Image(systemName: "bell.fill")
            .font(.caption2)
            .foregroundColor(UITheme.Colors.info)
    }
    
    private var labelsAndProjectRow: some View {
        HStack(spacing: UITheme.Spacing.sm) {
            // Project
            if showProject, let project = task.projectName, !project.isEmpty {
                projectTag(project)
            }
            
            // Labels
            if let labelsString = task.labels, !labelsString.isEmpty {
                labelsView(labelsString)
            }
            
            Spacer()
        }
    }
    
    private func projectTag(_ project: String) -> some View {
        HStack(spacing: UITheme.Spacing.xs) {
            Text("#")
                .font(UITheme.Typography.caption2)
                .foregroundColor(UITheme.Colors.primary)
            
            Text(project)
                .font(UITheme.Typography.caption)
                .foregroundColor(UITheme.Colors.primary)
        }
        .padding(.horizontal, UITheme.Spacing.xs)
        .padding(.vertical, 2)
        .background(UITheme.Colors.primary.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private func labelsView(_ labelsString: String) -> some View {
        let labels = labelsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        return HStack(spacing: UITheme.Spacing.xs) {
            ForEach(labels.prefix(3), id: \.self) { label in
                labelTag(label)
            }
            
            if labels.count > 3 {
                Text("+\(labels.count - 3)")
                    .font(UITheme.Typography.caption2)
                    .foregroundColor(UITheme.Colors.tertiary)
            }
        }
    }
    
    private func labelTag(_ label: String) -> some View {
        HStack(spacing: UITheme.Spacing.xs) {
            Text("@")
                .font(UITheme.Typography.caption2)
                .foregroundColor(UITheme.Colors.secondary)
            
            Text(label)
                .font(UITheme.Typography.caption)
                .foregroundColor(UITheme.Colors.secondaryText)
        }
        .padding(.horizontal, UITheme.Spacing.xs)
        .padding(.vertical, 2)
        .background(UITheme.Colors.secondaryBackground)
        .clipShape(Capsule())
    }
    
    private var calendarIndicator: some View {
        Image(systemName: "calendar.badge.clock")
            .font(.caption)
            .foregroundColor(UITheme.Colors.info)
    }
    
    // MARK: - Computed Properties
    
    private var isCompleted: Bool {
        return task.isCompleted || task.completed
    }
    
    private var taskPriority: Int {
        return Int(task.priority)
    }
    
    private var hasMetadata: Bool {
        return (showDueDate && task.dueDate != nil) ||
               (showCourse && task.course != nil) ||
               task.reminderTime != nil
    }
    
    private var hasLabelsOrProject: Bool {
        return (showProject && task.projectName != nil && !task.projectName!.isEmpty) ||
               (task.labels != nil && !task.labels!.isEmpty)
    }
    
    private var titleColor: Color {
        if isCompleted {
            return UITheme.Colors.tertiary
        } else {
            return UITheme.Colors.primaryText
        }
    }
    
    private var taskBackgroundColor: Color {
        if isCompleted {
            return UITheme.Colors.tertiaryBackground
        } else {
            return UITheme.Colors.cardBackground
        }
    }
    
    private var taskBorderColor: Color {
        if isCompleted {
            return UITheme.Colors.tertiary.opacity(0.3)
        } else {
            return UITheme.Colors.cardBorder
        }
    }
    
    private var checkboxStrokeColor: Color {
        if isCompleted {
            return UITheme.Colors.success
        } else {
            return priorityColor
        }
    }
    
    private var priorityColor: Color {
        switch taskPriority {
        case 1: return UITheme.Colors.priority1
        case 2: return UITheme.Colors.priority2
        case 3: return UITheme.Colors.priority3
        case 4: return UITheme.Colors.priority4
        default: return UITheme.Colors.secondary
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleCompletion() {
        isToggling = true
        hapticFeedback.impactOccurred()
        
        // Visual feedback delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isToggling = false
            
            // Toggle task completion
            if task.isCompleted {
                task.isCompleted = false
                task.completed = false
                task.completedAt = nil
            } else {
                task.isCompleted = true
                task.completed = true
                task.completedAt = Date()
            }
            
            task.updatedAt = Date()
            onToggle?(task)
        }
    }
    
    private func dueDateColor(_ dueDate: Date) -> Color {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(dueDate, inSameDayAs: now) {
            return UITheme.Colors.warning
        } else if dueDate < now {
            return UITheme.Colors.error
        } else if calendar.dateInterval(of: .day, for: now)?.end ?? now < dueDate {
            return UITheme.Colors.secondaryText
        } else {
            return UITheme.Colors.warning
        }
    }
    
    private func formatDueDate(_ dueDate: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(dueDate, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: dueDate))"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        } else if calendar.isDate(dueDate, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: dueDate)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: dueDate)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension Task {
    static func sampleTask(
        title: String,
        isCompleted: Bool = false,
        priority: Int = 0,
        dueDate: Date? = nil,
        project: String? = nil,
        labels: String? = nil,
        showOnCalendar: Bool = false
    ) -> Task {
        let task = Task()
        task.id = UUID()
        task.title = title
        task.isCompleted = isCompleted
        task.completed = isCompleted
        task.priority = Int16(priority)
        task.dueDate = dueDate
        task.projectName = project
        task.labels = labels
        task.showOnCalendar = showOnCalendar
        task.createdAt = Date()
        task.updatedAt = Date()
        
        if isCompleted {
            task.completedAt = Date()
        }
        
        return task
    }
}

struct TaskRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: UITheme.Spacing.md) {
            SharedTaskRow(
                task: .sampleTask(
                    title: "Complete iOS app development",
                    priority: 1,
                    dueDate: Date().addingTimeInterval(3600),
                    project: "SchoolApp",
                    labels: "urgent,coding"
                ),
                onToggle: { _ in print("Toggle tapped") },
                onTap: { _ in print("Task tapped") }
            )
            
            SharedTaskRow(
                task: .sampleTask(
                    title: "Review team presentation",
                    isCompleted: true,
                    priority: 2,
                    project: "TeamWork"
                ),
                onToggle: { _ in print("Toggle tapped") }
            )
            
            SharedTaskRow(
                task: .sampleTask(
                    title: "Study for final exam",
                    priority: 3,
                    dueDate: Date().addingTimeInterval(-3600), // Overdue
                    labels: "study,exam",
                    showOnCalendar: true
                ),
                showCourse: true,
                onToggle: { _ in print("Toggle tapped") }
            )
            
            SharedTaskRow(
                task: .sampleTask(
                    title: "Simple task with no metadata"
                ),
                showProject: false,
                showDueDate: false,
                onToggle: { _ in print("Toggle tapped") }
            )
        }
        .padding()
        .background(UITheme.Colors.groupedBackground)
        .previewDisplayName("Light Mode")
        
        VStack(spacing: UITheme.Spacing.md) {
            SharedTaskRow(task: .sampleTask(title: "Dark mode task", priority: 1))
            SharedTaskRow(task: .sampleTask(title: "Completed task", isCompleted: true))
        }
        .padding()
        .background(UITheme.Colors.groupedBackground)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}

// MARK: - iOS 16+ FontWeight ViewModifier
struct iOS16FontWeight: ViewModifier {
    let weight: Font.Weight
    
    init(_ weight: Font.Weight) {
        self.weight = weight
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.fontWeight(weight)
        } else {
            content
        }
    }
}
#endif
