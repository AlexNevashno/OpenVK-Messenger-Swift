import SwiftUI

public struct VKThemePack: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var author: String
    public var baseTheme: String // "classic", "day", "tinted", "night"

    // Core Interface Colors (Hex)
    public var accentHex: String
    public var backgroundHex: String
    public var surfaceHex: String
    public var secondarySurfaceHex: String
    public var separatorHex: String

    // Message Bubbles (Hex)
    public var bubbleIncomingHex: String
    public var bubbleOutgoingHex: String
    public var bubbleIncomingTextHex: String
    public var bubbleOutgoingTextHex: String

    // Stroke & Borders
    public var bubbleStrokeHex: String?
    public var bubbleStrokeWidth: Double
    public var interfaceStrokeHex: String?

    // Chat Wallpaper
    public var wallpaperBase64: String?
    public var wallpaperPattern: String // "none", "telegram_doodles", "custom"
    public var wallpaperOpacity: Double
    public var wallpaperBlur: Double

    public init(
        id: String = UUID().uuidString,
        name: String,
        author: String = "OpenVK User",
        baseTheme: String = "night",
        accentHex: String = "#E25241",
        backgroundHex: String = "#1E2721",
        surfaceHex: String = "#242424",
        secondarySurfaceHex: String = "#2F2F2F",
        separatorHex: String = "#383838",
        bubbleIncomingHex: String = "#333333",
        bubbleOutgoingHex: String = "#463F38",
        bubbleIncomingTextHex: String = "#FFFFFF",
        bubbleOutgoingTextHex: String = "#FFFFFF",
        bubbleStrokeHex: String? = "#3D3833",
        bubbleStrokeWidth: Double = 0.8,
        interfaceStrokeHex: String? = nil,
        wallpaperBase64: String? = nil,
        wallpaperPattern: String = "telegram_doodles",
        wallpaperOpacity: Double = 0.9,
        wallpaperBlur: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.baseTheme = baseTheme
        self.accentHex = accentHex
        self.backgroundHex = backgroundHex
        self.surfaceHex = surfaceHex
        self.secondarySurfaceHex = secondarySurfaceHex
        self.separatorHex = separatorHex
        self.bubbleIncomingHex = bubbleIncomingHex
        self.bubbleOutgoingHex = bubbleOutgoingHex
        self.bubbleIncomingTextHex = bubbleIncomingTextHex
        self.bubbleOutgoingTextHex = bubbleOutgoingTextHex
        self.bubbleStrokeHex = bubbleStrokeHex
        self.bubbleStrokeWidth = bubbleStrokeWidth
        self.interfaceStrokeHex = interfaceStrokeHex
        self.wallpaperBase64 = wallpaperBase64
        self.wallpaperPattern = wallpaperPattern
        self.wallpaperOpacity = wallpaperOpacity
        self.wallpaperBlur = wallpaperBlur
    }

    // MARK: - Built-in Theme Presets

    /// Telegram Dark theme with green doodle wallpaper as shown in user screenshot
    public static let telegramDark = VKThemePack(
        id: "preset_telegram_dark",
        name: "Telegram Dark",
        author: "Telegram Design",
        baseTheme: "night",
        accentHex: "#E25241",
        backgroundHex: "#1E2721",
        surfaceHex: "#242424",
        secondarySurfaceHex: "#2E2E2E",
        separatorHex: "#383838",
        bubbleIncomingHex: "#333333",
        bubbleOutgoingHex: "#463F38",
        bubbleIncomingTextHex: "#FFFFFF",
        bubbleOutgoingTextHex: "#FFFFFF",
        bubbleStrokeHex: "#3D3833",
        bubbleStrokeWidth: 0.8,
        interfaceStrokeHex: "#383838",
        wallpaperBase64: nil,
        wallpaperPattern: "telegram_doodles",
        wallpaperOpacity: 0.92,
        wallpaperBlur: 0.0
    )

    /// Authentic VKontakte classic light theme
    public static let classicVK = VKThemePack(
        id: "preset_classic_vk",
        name: "Классический ВКонтакте",
        author: "VK UI Design",
        baseTheme: "classic",
        accentHex: "#2D81E0",
        backgroundHex: "#F0F1F4",
        surfaceHex: "#FFFFFF",
        secondarySurfaceHex: "#F2F3F5",
        separatorHex: "#E1E3E6",
        bubbleIncomingHex: "#FFFFFF",
        bubbleOutgoingHex: "#CCE4FF",
        bubbleIncomingTextHex: "#000000",
        bubbleOutgoingTextHex: "#000000",
        bubbleStrokeHex: "#DCE1E6",
        bubbleStrokeWidth: 0.8,
        interfaceStrokeHex: "#E1E3E6",
        wallpaperBase64: nil,
        wallpaperPattern: "none",
        wallpaperOpacity: 1.0,
        wallpaperBlur: 0.0
    )

    /// Telegram Day with green doodles
    public static let telegramDay = VKThemePack(
        id: "preset_telegram_day",
        name: "Telegram Day",
        author: "Telegram Design",
        baseTheme: "day",
        accentHex: "#3390EC",
        backgroundHex: "#D5E3CD",
        surfaceHex: "#FFFFFF",
        secondarySurfaceHex: "#F4F4F5",
        separatorHex: "#E4E4E6",
        bubbleIncomingHex: "#FFFFFF",
        bubbleOutgoingHex: "#EEFFDE",
        bubbleIncomingTextHex: "#000000",
        bubbleOutgoingTextHex: "#000000",
        bubbleStrokeHex: "#D8E4D0",
        bubbleStrokeWidth: 0.8,
        interfaceStrokeHex: "#E4E4E6",
        wallpaperBase64: nil,
        wallpaperPattern: "telegram_doodles",
        wallpaperOpacity: 0.85,
        wallpaperBlur: 0.0
    )

    /// Deep tinted Navy / Midnight Blue
    public static let tintedNavy = VKThemePack(
        id: "preset_tinted_navy",
        name: "Глубокий индиго",
        author: "OpenVK Studio",
        baseTheme: "tinted",
        accentHex: "#5288C1",
        backgroundHex: "#0E1621",
        surfaceHex: "#17212B",
        secondarySurfaceHex: "#202B36",
        separatorHex: "#242F3D",
        bubbleIncomingHex: "#182533",
        bubbleOutgoingHex: "#2B5278",
        bubbleIncomingTextHex: "#FFFFFF",
        bubbleOutgoingTextHex: "#FFFFFF",
        bubbleStrokeHex: "#203347",
        bubbleStrokeWidth: 0.8,
        interfaceStrokeHex: "#242F3D",
        wallpaperBase64: nil,
        wallpaperPattern: "none",
        wallpaperOpacity: 1.0,
        wallpaperBlur: 0.0
    )

    /// Cyberpunk Neon theme with vibrant pink & dark slate
    public static let cyberpunkNeon = VKThemePack(
        id: "preset_cyberpunk",
        name: "Киберпанк Неон",
        author: "Cyberpunk 2077",
        baseTheme: "night",
        accentHex: "#FF007F",
        backgroundHex: "#0B0C10",
        surfaceHex: "#1F2833",
        secondarySurfaceHex: "#2C3539",
        separatorHex: "#45A29E",
        bubbleIncomingHex: "#1F2833",
        bubbleOutgoingHex: "#6F2232",
        bubbleIncomingTextHex: "#E0F2F1",
        bubbleOutgoingTextHex: "#FFFFFF",
        bubbleStrokeHex: "#FF007F",
        bubbleStrokeWidth: 1.2,
        interfaceStrokeHex: "#FF007F",
        wallpaperBase64: nil,
        wallpaperPattern: "none",
        wallpaperOpacity: 1.0,
        wallpaperBlur: 0.0
    )

    /// Emerald Forest dark green theme
    public static let emeraldForest = VKThemePack(
        id: "preset_emerald_forest",
        name: "Изумрудный лес",
        author: "Nordic Green",
        baseTheme: "night",
        accentHex: "#2ECC71",
        backgroundHex: "#0E1A14",
        surfaceHex: "#16281F",
        secondarySurfaceHex: "#1D3529",
        separatorHex: "#264435",
        bubbleIncomingHex: "#182C22",
        bubbleOutgoingHex: "#234C37",
        bubbleIncomingTextHex: "#FFFFFF",
        bubbleOutgoingTextHex: "#FFFFFF",
        bubbleStrokeHex: "#2E5A44",
        bubbleStrokeWidth: 0.8,
        interfaceStrokeHex: "#264435",
        wallpaperBase64: nil,
        wallpaperPattern: "none",
        wallpaperOpacity: 1.0,
        wallpaperBlur: 0.0
    )

    /// All preset themes available out of the box
    public static let allPresets: [VKThemePack] = [
        .telegramDark,
        .classicVK,
        .telegramDay,
        .tintedNavy,
        .emeraldForest,
        .cyberpunkNeon
    ]
}
