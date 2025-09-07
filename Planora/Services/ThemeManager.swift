import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("accentColor") private var accentColorString: String = "blue"
    
    var accentColor: AccentColor {
        get {
            AccentColor(rawValue: accentColorString) ?? .blue
        }
        set {
            accentColorString = newValue.rawValue
        }
    }
    
    var currentAccentColor: Color {
        accentColor.color
    }
    
    private init() {}
    
    // MARK: - Theme Application
    func applyTheme() {
        // This would be called when the app starts or theme changes
        // The accent color is automatically applied through the AccentColor enum
    }
    
    // MARK: - Dynamic Color Generation
    func generateGradient(from color: Color) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                color.opacity(0.8),
                color.opacity(0.6),
                color.opacity(0.4)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    func generateBackgroundGradient(from color: Color) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                color.opacity(0.1),
                color.opacity(0.05),
                Color.clear
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Extensions for Theme
extension View {
    func themedAccentColor() -> some View {
        self.accentColor(ThemeManager.shared.currentAccentColor)
    }
    
    func themedBackground() -> some View {
        self.background(ThemeManager.shared.generateBackgroundGradient(from: ThemeManager.shared.currentAccentColor))
    }
    
    func themedGradient() -> some View {
        self.background(ThemeManager.shared.generateGradient(from: ThemeManager.shared.currentAccentColor))
    }
}

// MARK: - Color Extensions
extension Color {
    static var themeAccent: Color {
        ThemeManager.shared.currentAccentColor
    }
    
    static var themeBackground: LinearGradient {
        ThemeManager.shared.generateBackgroundGradient(from: ThemeManager.shared.currentAccentColor)
    }
    
    static var themeGradient: LinearGradient {
        ThemeManager.shared.generateGradient(from: ThemeManager.shared.currentAccentColor)
    }
}
