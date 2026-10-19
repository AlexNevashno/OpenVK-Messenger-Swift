import SwiftUI

@MainActor
public enum VKColors {
    // MARK: - Accent & Brand
    public static var accent: Color { ThemeManager.shared.accentColor }
    public static var accentMuted: Color { ThemeManager.shared.accentColor.opacity(0.15) }
    public static let onlineGreen = Color(red: 0.294, green: 0.702, blue: 0.294) // #4BB34B
    public static let verified = Color(red: 0.176, green: 0.506, blue: 0.878) // #2D81E0

    // MARK: - Backgrounds (Themed)
    public static var background: Color { ThemeManager.shared.backgroundColor }
    public static var surface: Color { ThemeManager.shared.surfaceColor }
    public static var secondarySurface: Color { ThemeManager.shared.secondarySurfaceColor }
    public static var separator: Color { ThemeManager.shared.separatorColor }

    // MARK: - Message Bubbles
    public static var bubbleIncoming: Color { ThemeManager.shared.bubbleIncomingColor }
    public static var bubbleOutgoing: Color { ThemeManager.shared.bubbleOutgoingColor }

    // MARK: - Text
    public static var textPrimary: Color { ThemeManager.shared.textPrimaryColor }
    public static var textSecondary: Color { ThemeManager.shared.textSecondaryColor }
    public static var textMuted: Color { ThemeManager.shared.textMutedColor }
    public static var textOnAccent: Color { ThemeManager.shared.textOnAccentColor }
}

public enum VKTypography {
    public static let title = Font.system(size: 15, weight: .semibold, design: .rounded)
    public static let headline = Font.system(size: 14, weight: .semibold, design: .default)
    public static let body = Font.system(size: 13.5, weight: .regular, design: .default)
    public static let subhead = Font.system(size: 13, weight: .regular, design: .default)
    public static let caption = Font.system(size: 11.5, weight: .regular, design: .default)
    public static let badge = Font.system(size: 11, weight: .bold, design: .rounded)
}
