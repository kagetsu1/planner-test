import SwiftUI

public enum AccentColor: String, CaseIterable, Identifiable {
    case system, blue, green, purple, orange, pink, red, teal, indigo
    public var id: String { rawValue }
    public var color: Color {
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
