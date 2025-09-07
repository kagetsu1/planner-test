import SwiftUI

// Re-declare App Group ID here so the widget target is self-contained
let APP_GROUP_ID = "group.com.planora.app"

// A tiny theme bridge usable inside widgets (no dependency on ThemeManager)
enum WidgetAccent: String {
    case system, blue, green, purple, orange, pink, red, teal, indigo
    static func fromStored(_ raw: String?) -> WidgetAccent {
        guard let raw = raw, let v = WidgetAccent(rawValue: raw) else { return .system }
        return v
    }
    var color: Color {
        switch self {
        case .system: return Color.accentColor
        case .blue:   return .blue
        case .green:  return .green
        case .purple: return .purple
        case .orange: return .orange
        case .pink:   return .pink
        case .red:    return .red
        case .teal:   return .teal
        case .indigo: return .indigo
        }
    }
}

struct WidgetTheme {
    static let appGroupId = APP_GROUP_ID
    static func accentColor() -> Color {
        let suite = UserDefaults(suiteName: appGroupId)
        let stored = suite?.string(forKey: "accentColor")
        return WidgetAccent.fromStored(stored).color
    }
}
