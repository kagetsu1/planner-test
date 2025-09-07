import SwiftUI

/// Global UI theme and styling system for Planora
struct UITheme {
    
    // MARK: - Typography
    
    struct Typography {
        // Headlines
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.medium)
        static let title3 = Font.title3.weight(.medium)
        
        // Body text
        static let body = Font.body
        static let bodyMedium = Font.body.weight(.medium)
        static let bodyLarge = Font.title3
        
        // Supporting text
        static let caption = Font.caption
        static let caption2 = Font.caption2
        static let footnote = Font.footnote
        static let subheadline = Font.subheadline
        
        // UI elements
        static let buttonText = Font.body.weight(.medium)
        static let navigationTitle = Font.headline
    }
    
    // MARK: - Colors
    
    struct Colors {
        // System colors that adapt to light/dark mode
        static let primary = Color.accentColor
        static let secondary = Color.secondary
        static let tertiary = Color(.tertiaryLabel)
        
        // Backgrounds
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
        
        // Text colors
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(.tertiaryLabel)
        
        // Interactive elements
        static let link = Color.accentColor
        static let button = Color.accentColor
        static let destructive = Color.red
        
        // Semantic colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // Priority colors
        static let priority1 = Color.red
        static let priority2 = Color.orange
        static let priority3 = Color.yellow
        static let priority4 = Color.blue
        
        // Card and surface colors
        static let cardBackground = Color(.systemBackground)
        static let cardBorder = Color(.separator)
        
        // Overlay colors
        static let overlay = Color.black.opacity(0.3)
        static let modalBackground = Color(.systemBackground)
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        
        // Common layout values
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let listItemSpacing: CGFloat = 12
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
        
        // Common component values
        static let button: CGFloat = 10
        static let card: CGFloat = 12
        static let modal: CGFloat = 16
    }
    
    // MARK: - Shadows
    
    struct Shadows {
        static let small = ShadowStyle(
            color: Color.black.opacity(0.08),
            radius: 2,
            x: 0,
            y: 1
        )
        
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.12),
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let large = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 16,
            x: 0,
            y: 8
        )
        
        static let card = medium
        static let modal = large
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        
        // Common animations
        static let buttonPress = SwiftUI.Animation.easeOut(duration: 0.1)
        static let modalPresentation = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let listUpdate = SwiftUI.Animation.easeInOut(duration: 0.25)
    }
}

// MARK: - Shadow Style Helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    
    /// Apply theme card styling
    func themeCard(padding: CGFloat = UITheme.Spacing.cardPadding) -> some View {
        self
            .padding(padding)
            .background(UITheme.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: UITheme.CornerRadius.card)
                    .stroke(UITheme.Colors.cardBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: UITheme.CornerRadius.card))
    }
    
    /// Apply theme button styling
    func themeButton(style: ThemeButtonStyle = .primary) -> some View {
        self
            .font(UITheme.Typography.buttonText)
            .padding(.horizontal, UITheme.Spacing.md)
            .padding(.vertical, UITheme.Spacing.sm)
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: UITheme.CornerRadius.button))
    }
    
    /// Apply subtle separator
    func themeSeparator() -> some View {
        Rectangle()
            .fill(UITheme.Colors.cardBorder)
            .frame(height: 0.5)
    }
    
    /// Apply screen-level padding
    func screenPadding() -> some View {
        self.padding(.horizontal, UITheme.Spacing.screenPadding)
    }
    
    /// Apply section spacing
    func sectionSpacing() -> some View {
        self.padding(.bottom, UITheme.Spacing.sectionSpacing)
    }
    
    /// Apply theme shadow
    func themeShadow(_ style: ShadowStyle = UITheme.Shadows.card) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
    
    /// Apply priority pip styling
    func priorityPip(_ priority: Int) -> some View {
        Circle()
            .fill(priorityColor(priority))
            .frame(width: 8, height: 8)
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return UITheme.Colors.priority1
        case 2: return UITheme.Colors.priority2
        case 3: return UITheme.Colors.priority3
        case 4: return UITheme.Colors.priority4
        default: return UITheme.Colors.tertiary
        }
    }
}

// MARK: - Button Styles

enum ThemeButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return UITheme.Colors.button
        case .secondary:
            return UITheme.Colors.secondaryBackground
        case .tertiary:
            return Color.clear
        case .destructive:
            return UITheme.Colors.destructive
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary, .destructive:
            return Color.white
        case .secondary:
            return UITheme.Colors.primaryText
        case .tertiary:
            return UITheme.Colors.button
        }
    }
}

// MARK: - iOS 18 Tint Support

extension Color {
    /// Returns the system accent color which automatically adapts to iOS 18 tinting
    static var appTint: Color {
        return Color.accentColor
    }
}

// MARK: - Dynamic Type Support

extension Font {
    /// Creates a font that scales with Dynamic Type settings
    static func scaledFont(
        _ textStyle: Font.TextStyle,
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        let font = Font.custom("", size: size, relativeTo: textStyle)
            .weight(weight)
        
        // Font.design is not available in iOS 15, return font without design modification
        return font
    }
}

// MARK: - Accessibility Support

extension View {
    /// Apply accessibility improvements
    func accessibilityEnhanced(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct UIThemePreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: UITheme.Spacing.lg) {
                // Typography samples
                VStack(alignment: .leading, spacing: UITheme.Spacing.sm) {
                    Text("Typography")
                        .font(UITheme.Typography.title2)
                    
                    Text("Large Title")
                        .font(UITheme.Typography.largeTitle)
                    
                    Text("Title 1")
                        .font(UITheme.Typography.title1)
                    
                    Text("Body text with medium weight")
                        .font(UITheme.Typography.bodyMedium)
                    
                    Text("Caption text")
                        .font(UITheme.Typography.caption)
                        .foregroundColor(UITheme.Colors.secondaryText)
                }
                .themeCard()
                
                // Color samples
                VStack(alignment: .leading, spacing: UITheme.Spacing.sm) {
                    Text("Colors")
                        .font(UITheme.Typography.title2)
                    
                    HStack {
                        ForEach(1...4, id: \.self) { priority in
                            Circle()
                                .fill(priorityColor(priority))
                                .frame(width: 20, height: 20)
                        }
                        Spacer()
                    }
                }
                .themeCard()
                
                // Button samples
                VStack(spacing: UITheme.Spacing.sm) {
                    Text("Buttons")
                        .font(UITheme.Typography.title2)
                    
                    Button("Primary Button") {}
                        .themeButton(style: .primary)
                    
                    Button("Secondary Button") {}
                        .themeButton(style: .secondary)
                    
                    Button("Tertiary Button") {}
                        .themeButton(style: .tertiary)
                }
                .themeCard()
            }
            .screenPadding()
        }
        .background(UITheme.Colors.groupedBackground)
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return UITheme.Colors.priority1
        case 2: return UITheme.Colors.priority2
        case 3: return UITheme.Colors.priority3
        case 4: return UITheme.Colors.priority4
        default: return UITheme.Colors.tertiary
        }
    }
}

struct UITheme_Previews: PreviewProvider {
    static var previews: some View {
        UIThemePreview()
            .previewDisplayName("Light Mode")
        
        UIThemePreview()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}
#endif
