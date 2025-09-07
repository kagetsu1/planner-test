import SwiftUI
import WidgetKit
// AppIntents used only under availability checks
#if canImport(AppIntents)
import AppIntents
#endif
import CoreData

struct TasksWidget: Widget {
    let kind: String = "TasksWidget"

    var body: some WidgetConfiguration {
        if #available(iOS 16.0, *) {
            return StaticConfiguration(kind: kind, provider: TasksTimelineProvider()) { entry in
                TasksWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Tasks")
            .description("Shows your upcoming tasks and deadlines.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
        } else {
            return StaticConfiguration(kind: kind, provider: TasksTimelineProvider()) { entry in
                TasksWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Tasks")
            .description("Shows your upcoming tasks and deadlines.")
            .supportedFamilies([.systemSmall, .systemMedium])
        }
    }
}

struct TasksEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskEntry]
}

struct WidgetTaskEntry: Identifiable {
    let id = UUID()
    let title: String
    let dueDate: Date?
    let priority: Int
    let isCompleted: Bool
    let projectName: String?
    let labels: [String]
    
    var priorityColor: Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .blue
        default: return .gray
        }
    }
    
    var priorityText: String {
        switch priority {
        case 1: return "P1"
        case 2: return "P2"
        case 3: return "P3"
        case 4: return "P4"
        default: return ""
        }
    }
}

struct TaskEntry: Identifiable {
    let id = UUID()
    let title: String
    let dueDate: Date
    let priority: String
}

struct TasksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(date: .now, tasks: [
            TaskEntry(title: "Math Assignment", dueDate: .now.addingTimeInterval(86400), priority: "High"),
            TaskEntry(title: "Essay Draft", dueDate: .now.addingTimeInterval(172800), priority: "Medium")
        ])
    }
    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        let entry = TasksEntry(date: .now, tasks: getUpcomingTasks())
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900)))
        completion(timeline)
    }
    private func getUpcomingTasks() -> [TaskEntry] {
        // TODO: read snapshot from App Group or Core Data
        return [
            TaskEntry(title: "Math Assignment", dueDate: .now.addingTimeInterval(86400), priority: "High"),
            TaskEntry(title: "Essay Draft", dueDate: .now.addingTimeInterval(172800), priority: "Medium"),
            TaskEntry(title: "Lab Report", dueDate: .now.addingTimeInterval(259200), priority: "Low")
        ]
    }
}

struct TasksWidgetEntryView: View {
    let entry: TasksEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "checklist")
                    .font(.headline)
                    .foregroundColor(WidgetTheme.accentColor())
                Text("Tasks")
                    .font(.caption).fontWeight(.semibold)
                Spacer()
            }
            if let first = entry.tasks.first {
                Text(first.title).font(.footnote).lineLimit(2)
                Text(first.dueDate, style: .date).font(.caption2).foregroundColor(.secondary)
            } else {
                Text("No upcoming tasks").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundColor(WidgetTheme.accentColor())
                Text("Upcoming Tasks")
                    .font(.headline).fontWeight(.semibold)
                Spacer()
                Text("\(entry.tasks.count)")
                    .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
            }
            ForEach(entry.tasks.prefix(3)) { task in
                HStack {
                    Image(systemName: "circle")
                        .foregroundColor(priorityColor(for: task.priority))
                    VStack(alignment: .leading) {
                        Text(task.title).font(.subheadline).lineLimit(1)
                        Text(task.dueDate, style: .date).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    if #available(iOS 17.0, *), let _ = Optional(task) {
                        // Button with intent available on iOS 17+
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func priorityColor(for p: String) -> Color {
        switch p.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }
}
