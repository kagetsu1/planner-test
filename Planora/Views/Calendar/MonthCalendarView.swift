import SwiftUI

/// Month calendar view with event dots and day selection
struct MonthCalendarView: View {
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var events: [UnifiedEvent] = []
    @State private var selectedDayEvents: [UnifiedEvent] = []
    @State private var showingDayDetail = false
    
    @StateObject private var eventKitBridge = EventKitBridge()
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header
            monthHeader
            
            // Days of week header
            daysOfWeekHeader
            
            // Calendar grid
            monthGrid
            
            Spacer()
        }
        .background(UITheme.Colors.background)
        .onAppear {
            loadEvents()
        }
        .onChange(of: displayedMonth) { _ in
            loadEvents()
        }
        .sheet(isPresented: $showingDayDetail) {
            dayDetailSheet
        }
    }
    
    private var monthHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(UITheme.Colors.primary)
            }
            
            Spacer()
            
            Text(dateFormatter.string(from: displayedMonth))
                .font(UITheme.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(UITheme.Colors.primaryText)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(UITheme.Colors.primary)
            }
        }
        .padding(.horizontal, UITheme.Spacing.md)
        .padding(.vertical, UITheme.Spacing.sm)
    }
    
    private var daysOfWeekHeader: some View {
        HStack {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(UITheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UITheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, UITheme.Spacing.md)
        .padding(.bottom, UITheme.Spacing.sm)
    }
    
    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            ForEach(daysInMonth, id: \.self) { date in
                dayCell(for: date)
            }
        }
        .padding(.horizontal, UITheme.Spacing.md)
    }
    
    private func dayCell(for date: Date?) -> some View {
        ZStack {
            // Cell background
            Rectangle()
                .fill(Color.clear)
                .frame(height: 44)
            
            if let date = date {
                dayContent(for: date)
            }
        }
        .onTapGesture {
            if let date = date {
                selectDay(date)
            }
        }
    }
    
    private func dayContent(for date: Date) -> some View {
        VStack(spacing: 2) {
            // Day number
            Text("\(calendar.component(.day, from: date))")
                .font(UITheme.Typography.body)
                .fontWeight(calendar.isDate(date, inSameDayAs: selectedDate) ? .semibold : .regular)
                .foregroundColor(dayTextColor(for: date))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(dayBackgroundColor(for: date))
                )
            
            // Event indicators
            eventIndicators(for: date)
        }
    }
    
    private func eventIndicators(for date: Date) -> some View {
        let dayEvents = eventsForDay(date)
        
        return HStack(spacing: 2) {
            ForEach(Array(dayEvents.prefix(3).enumerated()), id: \.offset) { index, event in
                Circle()
                    .fill(eventColor(for: event))
                    .frame(width: 4, height: 4)
            }
            
            if dayEvents.count > 3 {
                Circle()
                    .fill(UITheme.Colors.tertiary)
                    .frame(width: 2, height: 2)
            }
        }
        .frame(height: 6)
    }
    
    private var dayDetailSheet: some View {
        NavigationView {
            DayDetailView(
                date: selectedDate,
                events: selectedDayEvents
            )
            .navigationTitle(dayDetailTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDayDetail = false
                    }
                }
            }
        }
        .modifier(iOS16PresentationDetents())
    }
    
    // MARK: - Computed Properties
    
    private var daysInMonth: [Date?] {
        let startOfMonth = calendar.dateInterval(of: .month, for: displayedMonth)?.start ?? displayedMonth
        _ = calendar.dateInterval(of: .month, for: displayedMonth)?.end ?? displayedMonth
        
        // Get the first day of the week for the month
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let startOfWeek = calendar.date(byAdding: .day, value: -(firstWeekday - 1), to: startOfMonth) ?? startOfMonth
        
        // Generate dates for 6 weeks (42 days) to fill the grid
        var dates: [Date?] = []
        var currentDate = startOfWeek
        
        for _ in 0..<42 {
            if calendar.isDate(currentDate, equalTo: displayedMonth, toGranularity: .month) {
                dates.append(currentDate)
            } else {
                dates.append(nil) // Empty cells for other months
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    private var dayDetailTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }
    
    // MARK: - Helper Methods
    
    private func previousMonth() {
        withAnimation(UITheme.Animation.standard) {
            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(UITheme.Animation.standard) {
            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        }
    }
    
    private func selectDay(_ date: Date) {
        selectedDate = date
        selectedDayEvents = eventsForDay(date)
        
        if !selectedDayEvents.isEmpty {
            showingDayDetail = true
        }
    }
    
    private func loadEvents() {
        let startOfMonth = calendar.dateInterval(of: .month, for: displayedMonth)?.start ?? displayedMonth
        let endOfMonth = calendar.dateInterval(of: .month, for: displayedMonth)?.end ?? displayedMonth
        
        events = eventKitBridge.getUnifiedEvents(from: startOfMonth, to: endOfMonth)
    }
    
    private func eventsForDay(_ date: Date) -> [UnifiedEvent] {
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }
    
    private func dayTextColor(for date: Date) -> Color {
        if calendar.isDate(date, inSameDayAs: Date()) {
            return .white
        } else if calendar.isDate(date, inSameDayAs: selectedDate) {
            return UITheme.Colors.primary
        } else {
            return UITheme.Colors.primaryText
        }
    }
    
    private func dayBackgroundColor(for date: Date) -> Color {
        if calendar.isDate(date, inSameDayAs: Date()) {
            return UITheme.Colors.primary
        } else if calendar.isDate(date, inSameDayAs: selectedDate) {
            return UITheme.Colors.primary.opacity(0.2)
        } else {
            return Color.clear
        }
    }
    
    private func eventColor(for event: UnifiedEvent) -> Color {
        switch event.source {
        case .moodle:
            return UITheme.Colors.info
        case .eventKit, .device:
            return UITheme.Colors.primary
        case .local:
            return UITheme.Colors.success
        }
    }
}

// MARK: - Day Detail View

private struct DayDetailView: View {
    let date: Date
    let events: [UnifiedEvent]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: UITheme.Spacing.sm) {
                if events.isEmpty {
                    emptyStateView
                } else {
                    ForEach(events, id: \.id) { event in
                        EventRow(
                            event: event,
                            showDate: false,
                            onJoin: {
                                // Handle join action
                            },
                            onTap: {
                                // Handle event tap
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: UITheme.Spacing.md) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(UITheme.Colors.tertiary)
            
            Text("No events")
                .font(UITheme.Typography.title3)
                .foregroundColor(UITheme.Colors.primaryText)
            
            Text("You have no events scheduled for this day.")
                .font(UITheme.Typography.body)
                .foregroundColor(UITheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, UITheme.Spacing.xxl)
    }
}

// MARK: - Preview Support

#if DEBUG
struct MonthCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MonthCalendarView()
                .navigationTitle("Calendar")
                .navigationBarTitleDisplayMode(.large)
        }
        .previewDisplayName("Light Mode")
        
        NavigationView {
            MonthCalendarView()
                .navigationTitle("Calendar")
                .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}

// MARK: - iOS 16+ Presentation Detents ViewModifier
struct iOS16PresentationDetents: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium, .large])
        } else {
            content
        }
    }
}
#endif
