import SwiftUI
import WidgetKit

struct NextClassWidget: Widget {
    let kind: String = "NextClassWidget"
    var body: some WidgetConfiguration {
        if #available(iOS 16.0, *) {
            return StaticConfiguration(kind: kind, provider: NextClassTimelineProvider()) { entry in
                NextClassWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Next Class")
            .description("Shows your next class with details.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
        } else {
            return StaticConfiguration(kind: kind, provider: NextClassTimelineProvider()) { entry in
                NextClassWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Next Class")
            .description("Shows your next class with details.")
            .supportedFamilies([.systemSmall, .systemMedium])
        }
    }
}

struct NextClassEntry: TimelineEntry {
    let date: Date
    let nextClass: SimpleClass?
}

struct SimpleClass {
    let courseName: String
    let professor: String?
    let room: String?
    let startTime: Date?
}

struct NextClassTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextClassEntry {
        NextClassEntry(date: .now, nextClass: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (NextClassEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextClassEntry>) -> Void) {
        let entry = NextClassEntry(date: .now, nextClass: nil) // TODO: read from App Group/Core Data
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }
}

struct NextClassWidgetEntryView: View {
    var entry: NextClassEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let c = entry.nextClass {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(WidgetTheme.accentColor())
                    Text("Next Class")
                        .font(.caption).fontWeight(.medium)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.courseName).font(.headline).lineLimit(1)
                    if let prof = c.professor {
                        Text("Prof. \(prof)").font(.caption).foregroundColor(.secondary)
                    }
                    if let room = c.room {
                        Text("Room \(room)").font(.caption).foregroundColor(.secondary)
                    }
                    if let start = c.startTime {
                        Text(start, style: .time).font(.caption).fontWeight(.medium)
                            .foregroundColor(WidgetTheme.accentColor())
                    }
                }
                Spacer()
            }
            .padding().background(Color(.systemBackground))
        } else {
            VStack {
                Image(systemName: "graduationcap").font(.title).foregroundColor(.secondary)
                Text("No upcoming class").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            }.padding().background(Color(.systemBackground))
        }
    }
}
