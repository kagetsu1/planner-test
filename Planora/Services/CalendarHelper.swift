import Foundation

class CalendarHelper: ObservableObject {
    static let shared = CalendarHelper()
    
    @Published var weekStartDay: WeekStartDay = .monday
    
    private init() {
        // Load saved week start day
        if let savedWeekStart = UserDefaults.standard.string(forKey: "weekStartDay"),
           let weekStart = WeekStartDay(rawValue: savedWeekStart) {
            self.weekStartDay = weekStart
        }
    }
    
    // MARK: - Calendar Configuration
    func getConfiguredCalendar() -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartDay.calendarWeekday
        return calendar
    }
    
    // MARK: - Week Calculations
    func getWeekStartDate(for date: Date) -> Date {
        let calendar = getConfiguredCalendar()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start
        return weekStart ?? date
    }
    
    func getWeekEndDate(for date: Date) -> Date {
        let calendar = getConfiguredCalendar()
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: date)?.end
        return weekEnd ?? date
    }
    
    func getDaysInWeek(for date: Date) -> [Date] {
        let calendar = getConfiguredCalendar()
        let weekStart = getWeekStartDate(for: date)
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }
    
    // MARK: - Day of Week Calculations
    func getDayOfWeek(for date: Date) -> Int {
        let calendar = getConfiguredCalendar()
        return calendar.component(.weekday, from: date)
    }
    
    func isWeekend(_ date: Date) -> Bool {
        let calendar = getConfiguredCalendar()
        let weekday = calendar.component(.weekday, from: date)
        
        // Adjust weekend check based on week start day
        switch weekStartDay {
        case .sunday:
            return weekday == 1 || weekday == 7 // Sunday or Saturday
        case .monday:
            return weekday == 6 || weekday == 7 // Saturday or Sunday
        case .tuesday:
            return weekday == 7 || weekday == 1 // Sunday or Monday
        case .wednesday:
            return weekday == 1 || weekday == 2 // Monday or Tuesday
        case .thursday:
            return weekday == 2 || weekday == 3 // Tuesday or Wednesday
        case .friday:
            return weekday == 3 || weekday == 4 // Wednesday or Thursday
        case .saturday:
            return weekday == 4 || weekday == 5 // Thursday or Friday
        }
    }
    
    // MARK: - Date Formatting
    func getDayName(for date: Date, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = style == .short ? "E" : "EEEE"
        return formatter.string(from: date)
    }
    
    func getMonthName(for date: Date, style: DateFormatter.Style = .long) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = style == .short ? "MMM" : "MMMM"
        return formatter.string(from: date)
    }
    
    // MARK: - Week Start Day Management
    func updateWeekStartDay(_ newWeekStart: WeekStartDay) {
        weekStartDay = newWeekStart
        UserDefaults.standard.set(newWeekStart.rawValue, forKey: "weekStartDay")
        
        // Notify observers that calendar configuration has changed
        objectWillChange.send()
    }
    
    // MARK: - Utility Methods
    func isToday(_ date: Date) -> Bool {
        let calendar = getConfiguredCalendar()
        return calendar.isDateInToday(date)
    }
    
    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = getConfiguredCalendar()
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    func getStartOfDay(_ date: Date) -> Date {
        let calendar = getConfiguredCalendar()
        return calendar.startOfDay(for: date)
    }
    
    func getEndOfDay(_ date: Date) -> Date {
        let calendar = getConfiguredCalendar()
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: getStartOfDay(date)) else {
            return date
        }
        return calendar.date(byAdding: .second, value: -1, to: endOfDay) ?? date
    }
}

// MARK: - WeekStartDay Extension
extension WeekStartDay {
    var localizedDescription: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}
