import SwiftUI

/// Reusable event row component for displaying events in lists
struct EventRow: View {
    let event: UnifiedEvent
    let showDate: Bool
    let showJoinButton: Bool
    let onJoin: (() -> Void)?
    let onTap: (() -> Void)?
    
    @State private var conferenceLinks: [ConferenceLink] = []
    private let conferenceLinkDetector = ConferenceLinkDetector()
    
    init(
        event: UnifiedEvent,
        showDate: Bool = true,
        showJoinButton: Bool = true,
        onJoin: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.event = event
        self.showDate = showDate
        self.showJoinButton = showJoinButton
        self.onJoin = onJoin
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: UITheme.Spacing.md) {
            // Event indicator
            eventIndicator
            
            // Event content
            VStack(alignment: .leading, spacing: UITheme.Spacing.xs) {
                // Title and source
                HStack {
                    Text(event.title)
                        .font(UITheme.Typography.body)
                        .foregroundColor(UITheme.Colors.primaryText)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    sourceIcon
                }
                
                // Time and location
                VStack(alignment: .leading, spacing: 2) {
                    timeText
                    
                    if let location = event.location, !location.isEmpty {
                        locationText(location)
                    }
                }
                
                // Conference links
                if !conferenceLinks.isEmpty && showJoinButton {
                    conferenceLinkButtons
                }
            }
            
            // Action buttons
            if showJoinButton && !conferenceLinks.isEmpty {
                joinButton
            }
        }
        .padding(UITheme.Spacing.md)
        .background(UITheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: UITheme.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: UITheme.CornerRadius.card)
                .stroke(UITheme.Colors.cardBorder, lineWidth: 0.5)
        )
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            detectConferenceLinks()
        }
    }
    
    private var eventIndicator: some View {
        VStack(spacing: UITheme.Spacing.xs) {
            // Time indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor)
                .frame(width: 4, height: 40)
            
            // Status indicator (if ongoing)
            if isOngoing {
                Circle()
                    .fill(UITheme.Colors.success)
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private var sourceIcon: some View {
        Group {
            switch event.source {
            case .moodle:
                Image(systemName: "graduationcap.fill")
                    .font(.caption)
                    .foregroundColor(UITheme.Colors.tertiary)
            case .eventKit, .device:
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(UITheme.Colors.tertiary)
            case .local:
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                    .foregroundColor(UITheme.Colors.tertiary)
            }
        }
    }
    
    private var timeText: some View {
        HStack(spacing: UITheme.Spacing.xs) {
            if showDate {
                Text(formatDate(event.startDate))
                    .font(UITheme.Typography.caption)
                    .foregroundColor(UITheme.Colors.secondaryText)
                
                Text("•")
                    .font(UITheme.Typography.caption)
                    .foregroundColor(UITheme.Colors.tertiary)
            }
            
            Text(formatTimeRange(start: event.startDate, end: event.endDate))
                .font(UITheme.Typography.caption)
                .foregroundColor(timeColor)
            
            if let duration = formatDuration(start: event.startDate, end: event.endDate) {
                Text("(\(duration))")
                    .font(UITheme.Typography.caption2)
                    .foregroundColor(UITheme.Colors.tertiary)
            }
        }
    }
    
    private func locationText(_ location: String) -> some View {
        HStack(spacing: UITheme.Spacing.xs) {
            Image(systemName: "location.fill")
                .font(.caption2)
                .foregroundColor(UITheme.Colors.tertiary)
            
            Text(location)
                .font(UITheme.Typography.caption)
                .foregroundColor(UITheme.Colors.secondaryText)
                .lineLimit(1)
        }
    }
    
    private var conferenceLinkButtons: some View {
        HStack(spacing: UITheme.Spacing.xs) {
            ForEach(Array(conferenceLinks.enumerated()), id: \.offset) { index, link in
                Button(action: {
                    conferenceLinkDetector.openConferenceLink(link)
                }) {
                    HStack(spacing: UITheme.Spacing.xs) {
                        Image(systemName: link.iconName)
                            .font(.caption2)
                        
                        Text(link.shortDisplayName)
                            .font(UITheme.Typography.caption2)
                    }
                }
                .themeButton(style: .tertiary)
                .scaleEffect(0.8)
            }
        }
    }
    
    private var joinButton: some View {
        Button(action: {
            if let primaryLink = conferenceLinks.first {
                conferenceLinkDetector.openConferenceLink(primaryLink)
            }
            onJoin?()
        }) {
            Image(systemName: "video.fill")
                .font(.title3)
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 44)
        .background(UITheme.Colors.primary)
        .clipShape(Circle())
        .shadow(color: UITheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    
    private var isOngoing: Bool {
        let now = Date()
        return now >= event.startDate && now <= (event.endDate ?? event.startDate.addingTimeInterval(3600))
    }
    
    private var eventColor: Color {
        if isOngoing {
            return UITheme.Colors.success
        } else if event.startDate < Date() {
            return UITheme.Colors.tertiary
        } else {
            return UITheme.Colors.primary
        }
    }
    
    private var timeColor: Color {
        if isOngoing {
            return UITheme.Colors.success
        } else if event.startDate < Date() {
            return UITheme.Colors.tertiary
        } else {
            return UITheme.Colors.secondaryText
        }
    }
    
    // MARK: - Helper Methods
    
    private func detectConferenceLinks() {
        var textToCheck = event.title
        
        if let notes = event.notes {
            textToCheck += " " + notes
        }
        
        if let meetingURL = event.meetingURL {
            textToCheck += " " + meetingURL
        }
        
        conferenceLinks = conferenceLinkDetector.detectLinks(in: textToCheck)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE" // Day of week
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func formatTimeRange(start: Date, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let startString = formatter.string(from: start)
        
        guard let end = end else {
            return startString
        }
        
        let endString = formatter.string(from: end)
        return "\(startString) - \(endString)"
    }
    
    private func formatDuration(start: Date, end: Date?) -> String? {
        guard let end = end else { return nil }
        
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return nil
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension UnifiedEvent {
    static var sampleEvent: UnifiedEvent {
        UnifiedEvent(
            id: "sample-1",
            title: "iOS Development Team Meeting",
            startDate: Date().addingTimeInterval(3600), // 1 hour from now
            endDate: Date().addingTimeInterval(7200), // 2 hours from now
            location: "Conference Room A",
            notes: "Weekly sync meeting. Zoom link: https://zoom.us/j/123456789",
            source: .moodle,
            courseId: "CS101",
            meetingURL: "https://zoom.us/j/123456789"
        )
    }
    
    static var sampleOngoingEvent: UnifiedEvent {
        UnifiedEvent(
            id: "sample-2",
            title: "Data Structures Lecture",
            startDate: Date().addingTimeInterval(-1800), // 30 minutes ago
            endDate: Date().addingTimeInterval(1800), // 30 minutes from now
            location: "Room 205",
            notes: nil,
            source: .local,
            courseId: nil,
            meetingURL: nil
        )
    }
    
    static var samplePastEvent: UnifiedEvent {
        UnifiedEvent(
            id: "sample-3",
            title: "Project Presentation",
            startDate: Date().addingTimeInterval(-7200), // 2 hours ago
            endDate: Date().addingTimeInterval(-3600), // 1 hour ago
            location: "Auditorium",
            notes: "Final project presentations",
            source: .eventKit,
            courseId: nil,
            meetingURL: nil
        )
    }
}

struct EventRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: UITheme.Spacing.md) {
            EventRow(
                event: .sampleEvent,
                onJoin: { print("Join tapped") },
                onTap: { print("Event tapped") }
            )
            
            EventRow(
                event: .sampleOngoingEvent,
                showJoinButton: false,
                onTap: { print("Ongoing event tapped") }
            )
            
            EventRow(
                event: .samplePastEvent,
                showDate: false,
                showJoinButton: false,
                onTap: { print("Past event tapped") }
            )
        }
        .padding()
        .background(UITheme.Colors.groupedBackground)
        .previewDisplayName("Light Mode")
        
        VStack(spacing: UITheme.Spacing.md) {
            EventRow(event: .sampleEvent)
            EventRow(event: .sampleOngoingEvent)
            EventRow(event: .samplePastEvent)
        }
        .padding()
        .background(UITheme.Colors.groupedBackground)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
#endif
