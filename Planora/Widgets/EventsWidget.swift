import SwiftUI
import WidgetKit
import CoreData

struct EventsWidget: Widget {
    let kind: String = "EventsWidget"
    
    var body: some WidgetConfiguration {
        if #available(iOS 16.0, *) {
            return StaticConfiguration(kind: kind, provider: EventsTimelineProvider()) { entry in
                EventsWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Events")
            .description("Shows your upcoming events and classes from all sources.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
            .containerBackgroundRemovable(false) // iOS 17+
        } else {
            return StaticConfiguration(kind: kind, provider: EventsTimelineProvider()) { entry in
                EventsWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Events")
            .description("Shows your upcoming events and classes from all sources.")
            .supportedFamilies([.systemSmall, .systemMedium])
        }
    }
}

struct EventsEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEventEntry]
    let nextClass: WidgetEventEntry?
}

struct WidgetEventEntry: Identifiable {
    let id = UUID()
    let title: String
    let time: Date
    let endTime: Date?
    let source: String // "moodle", "local", "eventkit"
    let location: String?
    let hasConferenceLink: Bool
    let isOngoing: Bool
    
    var sourceIcon: String {
        switch source {
        case "moodle": return "graduationcap.fill"
        case "eventkit": return "calendar"
        default: return "plus.circle.fill"
        }
    }
    
    var sourceColor: Color {
        switch source {
        case "moodle": return .blue
        case "eventkit": return WidgetTheme.accentColor()
        default: return .green
        }
    }
}

struct EventsTimelineProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> EventsEntry {
        EventsEntry(date: .now, events: sampleEvents, nextClass: sampleNextClass)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (EventsEntry) -> Void) {
                    _Concurrency.Task {
            let events = await fetchUnifiedEvents()
            let nextClass = await fetchNextClass()
            let entry = EventsEntry(date: .now, events: events, nextClass: nextClass)
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<EventsEntry>) -> Void) {
                    _Concurrency.Task {
            let events = await fetchUnifiedEvents()
            let nextClass = await fetchNextClass()
            let entry = EventsEntry(date: .now, events: events, nextClass: nextClass)
            
            // Update every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func fetchUnifiedEvents() async -> [WidgetEventEntry] {
        // Fetch from Core Data in the widget context
        let persistentContainer = NSPersistentContainer(name: "StudentPlanner")
        
        // Configure for widget context
        if let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetTheme.appGroupId)?.appendingPathComponent("StudentPlanner.sqlite") {
            let description = NSPersistentStoreDescription(url: storeURL)
            persistentContainer.persistentStoreDescriptions = [description]
        }
        
        return await withCheckedContinuation { continuation in
            persistentContainer.loadPersistentStores { _, error in
                if let error = error {
                    print("Widget Core Data error: \(error)")
                    continuation.resume(returning: self.sampleEvents)
                    return
                }
                
                let context = persistentContainer.viewContext
                let events = self.fetchEventsFromContext(context)
                continuation.resume(returning: events)
            }
        }
    }
    
    private func fetchEventsFromContext(_ context: NSManagedObjectContext) -> [WidgetEventEntry] {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        
        // Fetch CalendarEvent entities
        let calendarRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        calendarRequest.predicate = NSPredicate(format: "start >= %@ AND start <= %@", startDate as NSDate, endDate as NSDate)
        calendarRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarEvent.start, ascending: true)]
        calendarRequest.fetchLimit = 10
        
        do {
            let calendarEvents = try context.fetch(calendarRequest)
            
            return calendarEvents.compactMap { event in
                guard let title = event.title,
                      let start = event.start else { return nil }
                
                let now = Date()
                let isOngoing = start <= now && (event.end ?? start.addingTimeInterval(3600)) >= now
                
                return WidgetEventEntry(
                    title: title,
                    time: start,
                    endTime: event.end,
                    source: event.source ?? "local",
                    location: event.location,
                    hasConferenceLink: event.meetingURL != nil,
                    isOngoing: isOngoing
                )
            }
        } catch {
            print("Error fetching events: \(error)")
            return sampleEvents
        }
    }
    
    private func fetchNextClass() async -> WidgetEventEntry? {
        // Similar to fetchUnifiedEvents but specifically for attendance sessions
        return sampleNextClass
    }
    
    // Sample data for fallback
    private var sampleEvents: [WidgetEventEntry] {
        [
            WidgetEventEntry(
                title: "iOS Development",
                time: .now.addingTimeInterval(3600),
                endTime: .now.addingTimeInterval(7200),
                source: "moodle",
                location: "Room 101",
                hasConferenceLink: true,
                isOngoing: false
            ),
            WidgetEventEntry(
                title: "Study Group",
                time: .now.addingTimeInterval(7200),
                endTime: .now.addingTimeInterval(10800),
                source: "local",
                location: "Library",
                hasConferenceLink: false,
                isOngoing: false
            ),
            WidgetEventEntry(
                title: "Team Meeting",
                time: .now.addingTimeInterval(10800),
                endTime: .now.addingTimeInterval(14400),
                source: "eventkit",
                location: "Conference Room",
                hasConferenceLink: true,
                isOngoing: false
            )
        ]
    }
    
    private var sampleNextClass: WidgetEventEntry? {
        WidgetEventEntry(
            title: "Data Structures",
            time: .now.addingTimeInterval(1800), // 30 minutes
            endTime: .now.addingTimeInterval(5400),
            source: "moodle",
            location: "Room 205",
            hasConferenceLink: false,
            isOngoing: false
        )
    }
}

struct EventsWidgetEntryView: View {
    let entry: EventsEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall: 
            smallView
        case .systemMedium: 
            mediumView
        case .accessoryRectangular:
            if #available(iOS 16.0, *) {
                accessoryRectangularView
            } else {
                smallView
            }
        case .accessoryCircular:
            if #available(iOS 16.0, *) {
                accessoryCircularView
            } else {
                smallView
            }
        default: 
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(tintColor)
                
                Text("Events")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let nextClass = entry.nextClass {
                    timeUntilNext(nextClass.time)
                }
            }
            
            // Next event or empty state
            if let event = entry.events.first {
                eventContent(event, compact: true)
            } else {
                emptyStateView
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .widgetBackground()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(tintColor)
                
                Text("Upcoming Events")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !entry.events.isEmpty {
                    Text("\(entry.events.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            // Event list
            if entry.events.isEmpty {
                emptyStateView
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.events.prefix(3)) { event in
                        eventRow(event)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .widgetBackground()
    }
    
    @available(iOS 16.0, *)
    private var accessoryRectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundColor(tintColor)
            
            VStack(alignment: .leading, spacing: 2) {
                if let event = entry.events.first {
                    Text(event.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(event.time, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("No Events")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("Today")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .widgetBackground()
    }
    
    @available(iOS 16.0, *)
    private var accessoryCircularView: some View {
        ZStack {
            Circle()
                .stroke(tintColor.opacity(0.3), lineWidth: 3)
            
            if let event = entry.events.first {
                VStack(spacing: 2) {
                    Image(systemName: event.sourceIcon)
                        .font(.caption)
                        .foregroundColor(tintColor)
                    
                    Text(timeUntilText(event.time))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            } else {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(tintColor)
            }
        }
        .widgetBackground()
    }
    
    // MARK: - Helper Views
    
    private func eventContent(_ event: WidgetEventEntry, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.title)
                    .font(compact ? .caption : .subheadline)
                    .fontWeight(.medium)
                    .lineLimit(compact ? 2 : 1)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if event.isOngoing {
                    ongoingIndicator
                }
            }
            
            HStack(spacing: 6) {
                Text(event.time, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let location = event.location {
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if event.hasConferenceLink {
                    Image(systemName: "video.fill")
                        .font(.caption2)
                        .foregroundColor(tintColor)
                }
            }
        }
    }
    
    private func eventRow(_ event: WidgetEventEntry) -> some View {
        HStack(spacing: 8) {
            // Source indicator
            Image(systemName: event.sourceIcon)
                .font(.caption)
                .foregroundColor(event.sourceColor)
                .frame(width: 16)
            
            // Event info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if event.isOngoing {
                        ongoingIndicator
                    }
                }
                
                HStack(spacing: 6) {
                    Text(event.time, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let location = event.location {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(location)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if event.hasConferenceLink {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                            .foregroundColor(tintColor)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("No upcoming events")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var ongoingIndicator: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
    }
    
    private func timeUntilNext(_ time: Date) -> some View {
        let minutes = Int(time.timeIntervalSince(.now) / 60)
        
        return Text(minutes > 0 ? "\(minutes)m" : "Now")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(minutes <= 15 ? .orange : tintColor)
    }
    
    private func timeUntilText(_ time: Date) -> String {
        let minutes = Int(time.timeIntervalSince(.now) / 60)
        
        if minutes <= 0 {
            return "Now"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            return "\(hours)h"
        }
    }
    
    // iOS 18 system tint color support
    private var tintColor: Color {
        if #available(iOS 18.0, *) {
            return Color.accentColor
        } else {
            return WidgetTheme.accentColor()
        }
    }
}

// MARK: - Widget Background Extension

extension View {
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            return self.containerBackground(.background, for: .widget)
        } else {
            return self.background(Color(.systemBackground))
        }
    }
}
