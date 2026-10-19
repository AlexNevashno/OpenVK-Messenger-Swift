import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

public enum VKBaseTheme: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case day = "Day"
    case tinted = "Tinted"
    case night = "Night"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classic: return "Classic"
        case .day: return "Day"
        case .tinted: return "Tinted"
        case .night: return "Night"
        }
    }

    public var isDark: Bool {
        self == .tinted || self == .night
    }
}

public enum VKAccentPreset: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case lightBlue = "Light blue"
    case green = "Green"
    case pink = "Pink"
    case orange = "Orange"
    case purple = "Purple"
    case red = "Red"
    case darkGray = "Dark gray"
    case yellow = "Yellow"
    case custom = "Custom color"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .blue: return Color(red: 0.176, green: 0.506, blue: 0.878) // #2D81E0
        case .lightBlue: return Color(red: 0.227, green: 0.659, blue: 0.969) // #3AA8F7
        case .green: return Color(red: 0.294, green: 0.702, blue: 0.294) // #4BB34B
        case .pink: return Color(red: 1.0, green: 0.294, blue: 0.545) // #FF4B8B
        case .orange: return Color(red: 1.0, green: 0.549, blue: 0.0) // #FF8C00
        case .purple: return Color(red: 0.557, green: 0.322, blue: 0.925) // #8E52EC
        case .red: return Color(red: 0.902, green: 0.275, blue: 0.275) // #E64646
        case .darkGray: return Color(red: 0.435, green: 0.475, blue: 0.522) // #6F7985
        case .yellow: return Color(red: 1.0, green: 0.725, blue: 0.0) // #FFB900
        case .custom: return Color(red: 0.176, green: 0.506, blue: 0.878)
        }
    }
}

@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @Published public var themeVersion: Int = 0

    // MARK: - Core Active Theme Pack
    @Published public var currentThemePack: VKThemePack {
        didSet {
            scheduleSaveCurrentThemePack()
        }
    }

    // Cached wallpaper image loaded from base64
    @Published public private(set) var customWallpaperImage: PlatformImage? = nil
    @Published public private(set) var customWallpaperLuminance: Double? = nil

    // Backwards-compatible properties
    @Published public var baseTheme: VKBaseTheme {
        didSet {
            currentThemePack.baseTheme = baseTheme.rawValue.lowercased()
            UserDefaults.standard.set(baseTheme.rawValue, forKey: "app_theme_base")
            applyAppearance()
        }
    }

    public var isDarkTheme: Bool {
        baseTheme.isDark
    }

    @Published public var accentPreset: VKAccentPreset {
        didSet {
            UserDefaults.standard.set(accentPreset.rawValue, forKey: "app_theme_accent_preset")
            if accentPreset != .custom {
                if let hex = accentPreset.color.toHex() {
                    currentThemePack.accentHex = hex
                }
            }
        }
    }

    @Published public var customColor: Color {
        didSet {
            if let hex = customColor.toHex() {
                UserDefaults.standard.set(hex, forKey: "app_theme_custom_hex")
                currentThemePack.accentHex = hex
            }
        }
    }

    private init() {
        let savedBase = UserDefaults.standard.string(forKey: "app_theme_base") ?? VKBaseTheme.classic.rawValue
        let base = VKBaseTheme(rawValue: savedBase) ?? .classic
        self.baseTheme = base

        let savedPreset = UserDefaults.standard.string(forKey: "app_theme_accent_preset") ?? VKAccentPreset.blue.rawValue
        self.accentPreset = VKAccentPreset(rawValue: savedPreset) ?? .blue

        let savedHex = UserDefaults.standard.string(forKey: "app_theme_custom_hex") ?? "#2D81E0"
        self.customColor = Color(hex: savedHex) ?? Color(red: 0.176, green: 0.506, blue: 0.878)

        // Load theme pack from UserDefaults if exists
        if let data = UserDefaults.standard.data(forKey: "app_theme_pack_json"),
           let loadedPack = try? JSONDecoder().decode(VKThemePack.self, from: data) {
            self.currentThemePack = loadedPack
        } else {
            // Default to Telegram Dark if dark mode, else Classic VK
            self.currentThemePack = base.isDark ? .telegramDark : .classicVK
        }

        self.updateWallpaperCache()
        applyAppearance()
    }

    private var saveTask: Task<Void, Never>? = nil

    private func scheduleSaveCurrentThemePack() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000) // 350ms debounce
            guard !Task.isCancelled else { return }
            self.saveCurrentThemePackImmediate()
        }
    }

    private func saveCurrentThemePackImmediate() {
        if let data = try? JSONEncoder().encode(currentThemePack) {
            UserDefaults.standard.set(data, forKey: "app_theme_pack_json")
        }
    }

    private func updateWallpaperCache() {
        if let b64 = currentThemePack.wallpaperBase64, !b64.isEmpty,
           let data = Data(base64Encoded: b64),
           let img = PlatformImage.from(data: data) {
            self.customWallpaperImage = img
            self.customWallpaperLuminance = ColorContrast.calculateAverageLuminance(of: img)
        } else {
            self.customWallpaperImage = nil
            self.customWallpaperLuminance = nil
        }
    }

    public func applyThemePack(_ pack: VKThemePack) {
        withAnimation(.easeInOut(duration: 0.35)) {
            self.currentThemePack = pack
            let base = VKBaseTheme(rawValue: pack.baseTheme.capitalized) ?? (pack.baseTheme == "night" ? .night : (pack.baseTheme == "tinted" ? .tinted : (pack.baseTheme == "day" ? .day : .classic)))
            self.baseTheme = base
            self.customColor = Color(hex: pack.accentHex) ?? self.customColor
            self.accentPreset = .custom
            self.updateWallpaperCache()
            self.themeVersion += 1
            self.saveCurrentThemePackImmediate()
            self.applyAppearance()
        }
    }

    public func setBaseTheme(_ newTheme: VKBaseTheme) {
        withAnimation(.easeInOut(duration: 0.35)) {
            self.baseTheme = newTheme
            self.currentThemePack.baseTheme = newTheme.rawValue.lowercased()
            self.themeVersion += 1
        }
    }

    public func setAccentPreset(_ newPreset: VKAccentPreset) {
        withAnimation(.easeInOut(duration: 0.35)) {
            self.accentPreset = newPreset
            if let hex = newPreset.color.toHex() {
                self.currentThemePack.accentHex = hex
            }
            self.themeVersion += 1
        }
    }

    public func setCustomColor(_ newColor: Color) {
        withAnimation(.easeInOut(duration: 0.35)) {
            self.accentPreset = .custom
            self.customColor = newColor
            if let hex = newColor.toHex() {
                self.currentThemePack.accentHex = hex
            }
            self.themeVersion += 1
        }
    }

    // MARK: - Bubble & Stroke Customization

    public func setBubbleIncomingColor(_ color: Color) {
        if let hex = color.toHex() {
            currentThemePack.bubbleIncomingHex = hex
            themeVersion += 1
        }
    }

    public func setBubbleOutgoingColor(_ color: Color) {
        if let hex = color.toHex() {
            currentThemePack.bubbleOutgoingHex = hex
            themeVersion += 1
        }
    }

    public func setBubbleStroke(color: Color?, width: Double) {
        currentThemePack.bubbleStrokeHex = color?.toHex()
        currentThemePack.bubbleStrokeWidth = width
        themeVersion += 1
    }

    public func setInterfaceStroke(color: Color?) {
        currentThemePack.interfaceStrokeHex = color?.toHex()
        themeVersion += 1
    }

    // MARK: - Wallpaper Customization

    public func setCustomWallpaper(image: PlatformImage) {
        guard let jpegData = image.jpegDataRepresentation(quality: 0.85) else {
            return
        }
        currentThemePack.wallpaperBase64 = jpegData.base64EncodedString()
        currentThemePack.wallpaperPattern = "custom"
        self.customWallpaperImage = image
        self.customWallpaperLuminance = ColorContrast.calculateAverageLuminance(of: image)
        themeVersion += 1
    }

    public func setTelegramDoodlesWallpaper() {
        currentThemePack.wallpaperBase64 = nil
        currentThemePack.wallpaperPattern = "telegram_doodles"
        self.customWallpaperImage = nil
        self.customWallpaperLuminance = nil
        themeVersion += 1
    }

    public func removeWallpaper() {
        currentThemePack.wallpaperBase64 = nil
        currentThemePack.wallpaperPattern = "none"
        self.customWallpaperImage = nil
        self.customWallpaperLuminance = nil
        themeVersion += 1
    }

    public func setWallpaperOpacity(_ opacity: Double) {
        currentThemePack.wallpaperOpacity = max(0.05, min(1.0, opacity))
    }

    public func setWallpaperBlur(_ blur: Double) {
        currentThemePack.wallpaperBlur = max(0.0, min(30.0, blur))
    }

    // MARK: - File Export / Import / Share

    public func exportThemePackData() -> Data? {
        try? JSONEncoder().encode(currentThemePack)
    }

    // MARK: - File Export / Import / Share
    #if os(macOS)
    public func saveThemeToFile(window: NSWindow? = nil) {
        let panel = NSSavePanel()
        panel.title = "Сохранить тему оформления"
        // By default save as .themepack.txt so OpenVK server document upload allows it (OpenVK accepts .txt)
        panel.nameFieldStringValue = "\(currentThemePack.name).themepack.txt"
        panel.allowedContentTypes = [
            UTType.plainText,
            UTType(filenameExtension: "themepack") ?? .data,
            .json
        ]
        panel.allowsOtherFileTypes = true

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            if let data = exportThemePackData() {
                do {
                    try data.write(to: url)
                    let alert = NSAlert()
                    alert.messageText = "Тема успешно сохранена"
                    alert.informativeText = "Файл \(url.lastPathComponent) сохранён. Вы можете отправить его в OpenVK как документ!"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                } catch {
                    print("DEBUG: Failed to save themepack: \(error)")
                }
            }
        }
    }

    public func loadThemeFromFile(completion: @escaping (VKThemePack?) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Импортировать тему оформления"
        panel.allowedContentTypes = [
            UTType.plainText,
            UTType(filenameExtension: "themepack") ?? .data,
            .json
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url),
               let pack = try? JSONDecoder().decode(VKThemePack.self, from: data) {
                completion(pack)
                return
            }
        }
        completion(nil)
    }

    public func importTelegramThemeFile() -> VKThemePack? {
        let panel = NSOpenPanel()
        panel.title = "Портировать тему Telegram"
        panel.message = "Выберите файл темы Telegram (.tdesktop-theme, .attheme, .tgios-theme, .tgx-theme, .palette, .tgtheme, .zip, .txt)"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "tdesktop-theme") ?? .data,
            UTType(filenameExtension: "attheme") ?? .plainText,
            UTType(filenameExtension: "tgios-theme") ?? .plainText,
            UTType(filenameExtension: "tgx-theme") ?? .plainText,
            UTType(filenameExtension: "palette") ?? .plainText,
            UTType(filenameExtension: "tgtheme") ?? .plainText,
            UTType.plainText,
            UTType.zip,
            UTType.data
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            do {
                let pack = try TelegramThemeImporter.importTheme(from: url)
                return pack
            } catch {
                let alert = NSAlert()
                alert.messageText = "Не удалось импортировать тему Telegram"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        return nil
    }
    #endif

    public func importTheme(from url: URL) throws -> VKThemePack {
        #if os(iOS)
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        #endif
        return try TelegramThemeImporter.importTheme(from: url)
    }

    public func shareThemeInChat(store: MessengerStore) {
        guard store.selectedPeerId != nil else { return }
        guard let data = exportThemePackData(),
              let jsonStr = String(data: data, encoding: .utf8) else { return }

        let text = "🎨 [OpenVK-ThemePack:\(currentThemePack.name)]\n\(jsonStr)"
        store.sendMessage(text: text)
    }

    public func applyAppearance() {
        #if os(macOS)
        DispatchQueue.main.async {
            switch self.baseTheme {
            case .classic, .day:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .tinted, .night:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
        #endif
    }

    // MARK: - Dynamic Theme Colors

    public var accentColor: Color {
        Color(hex: currentThemePack.accentHex) ?? (accentPreset == .custom ? customColor : accentPreset.color)
    }

    public var backgroundColor: Color {
        Color(hex: currentThemePack.backgroundHex) ?? {
            switch baseTheme {
            case .classic: return Color(red: 0.94, green: 0.945, blue: 0.955)
            case .day: return Color(red: 0.91, green: 0.92, blue: 0.94)
            case .tinted: return Color(red: 0.09, green: 0.13, blue: 0.18)
            case .night: return Color(red: 0.07, green: 0.07, blue: 0.08)
            }
        }()
    }

    public var surfaceColor: Color {
        Color(hex: currentThemePack.surfaceHex) ?? {
            switch baseTheme {
            case .classic: return Color.white
            case .day: return Color(red: 0.96, green: 0.965, blue: 0.975)
            case .tinted: return Color(red: 0.13, green: 0.18, blue: 0.23)
            case .night: return Color(red: 0.11, green: 0.11, blue: 0.12)
            }
        }()
    }

    public var secondarySurfaceColor: Color {
        Color(hex: currentThemePack.secondarySurfaceHex) ?? {
            switch baseTheme {
            case .classic: return Color(red: 0.96, green: 0.96, blue: 0.97)
            case .day: return Color(red: 0.93, green: 0.935, blue: 0.945)
            case .tinted: return Color(red: 0.17, green: 0.22, blue: 0.28)
            case .night: return Color(red: 0.15, green: 0.15, blue: 0.16)
            }
        }()
    }

    public var separatorColor: Color {
        Color(hex: currentThemePack.separatorHex) ?? {
            switch baseTheme {
            case .classic: return Color(red: 0.90, green: 0.91, blue: 0.93)
            case .day: return Color(red: 0.86, green: 0.87, blue: 0.89)
            case .tinted: return Color(red: 0.20, green: 0.26, blue: 0.33)
            case .night: return Color(red: 0.19, green: 0.19, blue: 0.21)
            }
        }()
    }

    public var bubbleIncomingColor: Color {
        Color(hex: currentThemePack.bubbleIncomingHex) ?? {
            switch baseTheme {
            case .classic: return Color.white
            case .day: return Color(red: 0.98, green: 0.98, blue: 0.99)
            case .tinted: return Color(red: 0.16, green: 0.22, blue: 0.29)
            case .night: return Color(red: 0.14, green: 0.14, blue: 0.16)
            }
        }()
    }

    public var bubbleOutgoingColor: Color {
        Color(hex: currentThemePack.bubbleOutgoingHex) ?? {
            switch baseTheme {
            case .classic: return accentColor.opacity(0.18)
            case .day: return accentColor.opacity(0.22)
            case .tinted: return accentColor.opacity(0.35)
            case .night: return accentColor.opacity(0.38)
            }
        }()
    }

    public var isSurfaceDark: Bool {
        ColorContrast.luminance(of: surfaceColor) < 0.5
    }

    public var isBackgroundDark: Bool {
        ColorContrast.luminance(of: backgroundColor) < 0.5
    }

    public var chatBackgroundLuminance: Double {
        if let customLum = customWallpaperLuminance {
            return customLum
        }
        return ColorContrast.luminance(of: backgroundColor)
    }

    public var isChatBackgroundDark: Bool {
        chatBackgroundLuminance < 0.5
    }

    /// Color for author names rendered over the chat wallpaper / background.
    /// Guaranteed WCAG AA contrast (ratio >= 4.5) against the effective chat background.
    public func chatAuthorNameColor(for id: Int = 0, baseColor: Color? = nil) -> Color {
        let palette = [
            "#E55353", "#3B82F6", "#10B981", "#F59E0B",
            "#8B5CF6", "#EC4899", "#06B6D4", "#F97316"
        ]
        let candidate: Color
        if let base = baseColor {
            candidate = base
        } else if id != 0 {
            let idx = abs(id) % palette.count
            candidate = Color(hex: palette[idx]) ?? accentColor
        } else {
            candidate = accentColor
        }

        let effectiveBg = isChatBackgroundDark ? Color(white: 0.08) : Color(white: 0.95)
        return ColorContrast.ensureContrast(foreground: candidate, on: effectiveBg, minRatio: 4.5)
    }

    /// High-contrast timestamp color for time labels placed directly over chat wallpaper
    public var chatTimestampColor: Color {
        isChatBackgroundDark ? Color(white: 0.88) : Color(white: 0.30)
    }

    /// Author name inside a reply quote box inside a bubble.
    /// Guaranteed high contrast against the parent message bubble.
    public func replyAuthorNameColor(isOutgoingBubble: Bool) -> Color {
        let bubbleBg = isOutgoingBubble ? bubbleOutgoingColor : bubbleIncomingColor
        return ColorContrast.ensureContrast(foreground: accentColor, on: bubbleBg, minRatio: 4.5)
    }

    /// Text color inside a reply quote box inside a bubble.
    public func replyTextColor(isOutgoingBubble: Bool) -> Color {
        isOutgoingBubble ? bubbleOutgoingTextColor : bubbleIncomingTextColor
    }

    /// Date/subtext color inside a reply quote box inside a bubble.
    public func replyDateColor(isOutgoingBubble: Bool) -> Color {
        let base = isOutgoingBubble ? bubbleOutgoingTextColor : bubbleIncomingTextColor
        return base.opacity(0.72)
    }

    /// Background tint for reply quote box inside a bubble.
    public func replyBoxBackground(isOutgoingBubble: Bool) -> Color {
        let bubbleBg = isOutgoingBubble ? bubbleOutgoingColor : bubbleIncomingColor
        let isDark = ColorContrast.luminance(of: bubbleBg) < 0.5
        return isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.06)
    }

    /// Best contrasting text color (white or black) on any given color
    public func textOnColor(_ color: Color) -> Color {
        ColorContrast.luminance(of: color) < 0.52 ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.1)
    }

    public var bubbleIncomingTextColor: Color {
        let raw = Color(hex: currentThemePack.bubbleIncomingTextHex) ?? textPrimaryColor
        return ColorContrast.ensureContrast(foreground: raw, on: bubbleIncomingColor, minRatio: 4.5)
    }

    public var bubbleOutgoingTextColor: Color {
        let raw = Color(hex: currentThemePack.bubbleOutgoingTextHex) ?? (baseTheme.isDark ? Color.white : textPrimaryColor)
        return ColorContrast.ensureContrast(foreground: raw, on: bubbleOutgoingColor, minRatio: 4.5)
    }

    public var bubbleStrokeColor: Color? {
        if let hex = currentThemePack.bubbleStrokeHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return nil
    }

    public var bubbleStrokeWidth: CGFloat {
        CGFloat(currentThemePack.bubbleStrokeWidth)
    }

    public var interfaceStrokeColor: Color? {
        if let hex = currentThemePack.interfaceStrokeHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return nil
    }

    public var chatWallpaperImage: PlatformImage? {
        if let custom = customWallpaperImage {
            return custom
        }
        if currentThemePack.wallpaperPattern == "telegram_doodles" {
            return ThemeAssets.telegramDoodlesImage
        }
        return nil
    }

    public var wallpaperPattern: String {
        currentThemePack.wallpaperPattern
    }

    public var wallpaperOpacity: Double {
        currentThemePack.wallpaperOpacity
    }

    public var wallpaperBlur: Double {
        currentThemePack.wallpaperBlur
    }

    public var textPrimaryColor: Color {
        isSurfaceDark ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.1)
    }

    public var textSecondaryColor: Color {
        isSurfaceDark ? Color(white: 0.72) : Color(red: 0.45, green: 0.48, blue: 0.53)
    }

    public var textMutedColor: Color {
        isSurfaceDark ? Color(white: 0.52) : Color(white: 0.65)
    }

    public var textOnAccentColor: Color {
        textOnColor(accentColor)
    }

    public var foldersSidebarBackgroundColor: Color {
        switch baseTheme {
        case .classic: return Color(red: 0.93, green: 0.935, blue: 0.95)
        case .day: return Color(red: 0.89, green: 0.90, blue: 0.92)
        case .tinted: return Color(red: 0.07, green: 0.10, blue: 0.14)
        case .night: return Color(red: 0.05, green: 0.05, blue: 0.06)
        }
    }
}

#if os(macOS)
// MARK: - Native macOS Color Panel Observer
public final class ColorPanelObserver: NSObject {
    public static let shared = ColorPanelObserver()

    private var onChange: ((Color) -> Void)?

    public func open(currentColor: Color, onChange: @escaping (Color) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        let ns = NSColor(currentColor)
        if let rgb = ns.usingColorSpace(.deviceRGB) ?? ns.usingColorSpace(.sRGB) {
            panel.color = rgb
        } else if let hex = currentColor.toHex(), let c = Color(hex: hex) {
            panel.color = NSColor(c)
        } else {
            panel.color = NSColor.gray
        }
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.isContinuous = true
        panel.showsAlpha = true
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        if let rgb = sender.color.usingColorSpace(.deviceRGB) ?? sender.color.usingColorSpace(.sRGB) {
            let r = max(0, min(255, Int(round(rgb.redComponent * 255))))
            let g = max(0, min(255, Int(round(rgb.greenComponent * 255))))
            let b = max(0, min(255, Int(round(rgb.blueComponent * 255))))
            let a = max(0, min(255, Int(round(rgb.alphaComponent * 255))))
            let hex = (a < 255)
                ? String(format: "#%02X%02X%02X%02X", r, g, b, a)
                : String(format: "#%02X%02X%02X", r, g, b)
            if let color = Color(hex: hex) {
                onChange?(color)
            }
        }
    }
}
#endif

// MARK: - Color Hex Helpers
extension Color {
    public init?(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        guard clean.allSatisfy({ $0.isHexDigit }) else { return nil }

        let r, g, b, a: Double
        if clean.count == 3 {
            // #RGB -> #RRGGBB
            let rHex = clean[clean.startIndex]
            let gHex = clean[clean.index(clean.startIndex, offsetBy: 1)]
            let bHex = clean[clean.index(clean.startIndex, offsetBy: 2)]
            guard let rgb = UInt64("\(rHex)\(rHex)\(gHex)\(gHex)\(bHex)\(bHex)", radix: 16) else { return nil }
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if clean.count == 4 {
            // #RGBA (e.g. #0000)
            let rHex = clean[clean.startIndex]
            let gHex = clean[clean.index(clean.startIndex, offsetBy: 1)]
            let bHex = clean[clean.index(clean.startIndex, offsetBy: 2)]
            let aHex = clean[clean.index(clean.startIndex, offsetBy: 3)]
            guard let rgb = UInt64("\(rHex)\(rHex)\(gHex)\(gHex)\(bHex)\(bHex)", radix: 16) else { return nil }
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            let aVal = Double(UInt64("\(aHex)\(aHex)", radix: 16) ?? 255) / 255.0
            a = aVal
        } else if clean.count == 6 {
            // #RRGGBB
            guard let rgb = UInt64(clean, radix: 16) else { return nil }
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if clean.count == 8 {
            // #RRGGBBAA
            guard let val = UInt64(clean, radix: 16) else { return nil }
            r = Double((val >> 24) & 0xFF) / 255.0
            g = Double((val >> 16) & 0xFF) / 255.0
            b = Double((val >> 8) & 0xFF) / 255.0
            a = Double(val & 0xFF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    public func toHex() -> String? {
        #if canImport(AppKit)
        let ns = NSColor(self)
        if let srgb = ns.usingColorSpace(.deviceRGB) ?? ns.usingColorSpace(.sRGB) {
            let r = max(0, min(255, Int(round(srgb.redComponent * 255))))
            let g = max(0, min(255, Int(round(srgb.greenComponent * 255))))
            let b = max(0, min(255, Int(round(srgb.blueComponent * 255))))
            let a = max(0, min(255, Int(round(srgb.alphaComponent * 255))))
            if a < 255 {
                return String(format: "#%02X%02X%02X%02X", r, g, b, a)
            }
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        #elseif canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
            let rInt = max(0, min(255, Int(round(r * 255))))
            let gInt = max(0, min(255, Int(round(g * 255))))
            let bInt = max(0, min(255, Int(round(b * 255))))
            let aInt = max(0, min(255, Int(round(a * 255))))
            if aInt < 255 {
                return String(format: "#%02X%02X%02X%02X", rInt, gInt, bInt, aInt)
            }
            return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
        }
        #endif
        return nil
    }
}
