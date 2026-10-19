import Foundation
import SwiftUI
import zlib
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Universal parser and converter for Telegram themes:
/// - Telegram Desktop: `.tdesktop-theme`, `.palette`, `.tdesktop-palette`, `.zip`
/// - Telegram Android: `.attheme` (with signed/unsigned int32 colors & embedded WPS binary wallpaper)
/// - Telegram iOS: `.tgios-theme`, `.tgtheme`, `.palette`, `.txt` (hierarchical YAML format)
/// - Telegram X: `.tgx-theme` (comma-separated color lists)
public enum TelegramThemeImporter {

    public enum ImportError: LocalizedError {
        case fileNotFound
        case cannotReadArchive
        case noColorsFound
        case invalidFormat

        public var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Файл темы Telegram не найден."
            case .cannotReadArchive:
                return "Не удалось распаковать архив темы Telegram."
            case .noColorsFound:
                return "В файле не найдено цветовых переменных Telegram."
            case .invalidFormat:
                return "Неподдерживаемый формат темы."
            }
        }
    }

    /// Import a theme file from URL
    public static func importTheme(from fileURL: URL) throws -> VKThemePack {
        let fileData = try Data(contentsOf: fileURL)
        let isZip = fileData.count > 4 && fileData[0] == 0x50 && fileData[1] == 0x4B // "PK" zip signature

        var paletteText = ""
        var wallpaperBase64: String? = nil

        if isZip {
            let (extractedText, extractedB64) = try extractFromZip(fileURL: fileURL)
            paletteText = extractedText
            wallpaperBase64 = extractedB64
        } else {
            // Check for Android .attheme with attached WPS wallpaper binary data
            let wpsLF = "WPS\n".data(using: .utf8)!
            let wpsCRLF = "WPS\r\n".data(using: .utf8)!

            if let range = fileData.range(of: wpsLF) {
                let textData = fileData.subdata(in: 0..<range.lowerBound)
                paletteText = String(data: textData, encoding: .utf8) ?? String(data: textData, encoding: .isoLatin1) ?? ""
                let imgData = fileData.subdata(in: range.upperBound..<fileData.count)
                wallpaperBase64 = encodeImageDataToBase64(imgData)
            } else if let range = fileData.range(of: wpsCRLF) {
                let textData = fileData.subdata(in: 0..<range.lowerBound)
                paletteText = String(data: textData, encoding: .utf8) ?? String(data: textData, encoding: .isoLatin1) ?? ""
                let imgData = fileData.subdata(in: range.upperBound..<fileData.count)
                wallpaperBase64 = encodeImageDataToBase64(imgData)
            } else {
                if let str = String(data: fileData, encoding: .utf8) ?? String(data: fileData, encoding: .isoLatin1) {
                    paletteText = str
                } else {
                    throw ImportError.invalidFormat
                }
            }
        }

        // If no embedded wallpaper found, check for companion wallpaper in the same folder
        if wallpaperBase64 == nil {
            wallpaperBase64 = searchCompanionWallpaper(fileURL: fileURL)
        }

        // Parse color dictionary
        let rawColors = parseColorVariables(from: paletteText)
        guard !rawColors.isEmpty else {
            throw ImportError.noColorsFound
        }

        // Resolve aliases (e.g., "msgInBg: windowBg;")
        let resolved = resolveAliases(rawColors)

        // Extract theme name from file or metadata
        var themeName = extractThemeName(from: fileURL, paletteText: paletteText)

        return buildThemePack(name: themeName, colors: resolved, wallpaperBase64: wallpaperBase64)
    }

    // MARK: - Companion Wallpaper Search

    private static func searchCompanionWallpaper(fileURL: URL) -> String? {
        let dir = fileURL.deletingLastPathComponent()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return nil
        }

        // 1. Direct image files
        for url in files {
            let name = url.lastPathComponent.lowercased()
            let ext = url.pathExtension.lowercased()
            if (ext == "jpg" || ext == "jpeg" || ext == "png") &&
                (name.contains("background") || name.contains("wallpaper") || name.contains("tiled") || name.contains("bg")) {
                if let data = try? Data(contentsOf: url),
                   let b64 = encodeImageDataToBase64(data) {
                    return b64
                }
            }
        }

        // 2. Companion .tdesktop-theme archive in the same folder
        for url in files {
            if url != fileURL && url.pathExtension.lowercased() == "tdesktop-theme" {
                if let (_, bgB64) = try? extractFromZip(fileURL: url), let bgB64 = bgB64 {
                    return bgB64
                }
            }
        }

        return nil
    }

    // MARK: - Name Extraction

    private static func extractThemeName(from fileURL: URL, paletteText: String) -> String {
        // 1. Try reading `name: ...` from file content
        for rawLine in paletteText.components(separatedBy: .newlines).prefix(15) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.lowercased().starts(with: "name:") {
                let val = line.dropFirst(5).trimmingCharacters(in: CharacterSet(charactersIn: " \"';\t\r\n"))
                if !val.isEmpty && val.count > 1 && !val.lowercased().contains("unnamed") {
                    return val
                }
            }
        }

        // 2. Parse from file/folder name
        var rawName = fileURL.deletingPathExtension().lastPathComponent
        let genericNames = ["pc", "colors", "theme", "iphone", "telegram x", "android", "default"]
        if genericNames.contains(rawName.lowercased()) {
            let parent = fileURL.deletingLastPathComponent().lastPathComponent
            if !parent.isEmpty && parent != "Downloads" && parent != "Documents" {
                rawName = parent
            }
        }

        // Clean up hashes like "_2199eefde9_VSTHEMES-ORG"
        if let idx = rawName.range(of: "_") {
            let prefix = String(rawName[..<idx.lowerBound])
            if prefix.count >= 3 {
                rawName = prefix
            }
        }

        return rawName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    // MARK: - ZIP Extraction (.tdesktop-theme)

    private static func extractFromZip(fileURL: URL) throws -> (palette: String, wallpaperBase64: String?) {
        let fileData = try Data(contentsOf: fileURL)
        return try extractFromZipData(data: fileData)
    }

    public static func extractFromZipData(data: Data) throws -> (palette: String, wallpaperBase64: String?) {
        var paletteContent = ""
        var wallpaperB64: String? = nil

        var offset = 0
        while offset + 30 <= data.count {
            let sig = data.subdata(in: offset..<offset+4)
            if sig != Data([0x50, 0x4b, 0x03, 0x04]) { break }
            let method = data.subdata(in: offset+8..<offset+10).withUnsafeBytes { $0.load(as: UInt16.self) }
            let compSize = Int(data.subdata(in: offset+18..<offset+22).withUnsafeBytes { $0.load(as: UInt32.self) })
            let uncompSize = Int(data.subdata(in: offset+22..<offset+26).withUnsafeBytes { $0.load(as: UInt32.self) })
            let nameLen = Int(data.subdata(in: offset+26..<offset+28).withUnsafeBytes { $0.load(as: UInt16.self) })
            let extraLen = Int(data.subdata(in: offset+28..<offset+30).withUnsafeBytes { $0.load(as: UInt16.self) })

            guard offset + 30 + nameLen <= data.count else { break }
            let name = String(data: data.subdata(in: offset+30..<offset+30+nameLen), encoding: .utf8) ?? ""
            let dataStart = offset + 30 + nameLen + extraLen
            guard dataStart + compSize <= data.count else { break }
            let entryCompressed = data.subdata(in: dataStart..<dataStart+compSize)
            offset = dataStart + compSize

            let decompressedData: Data?
            if method == 0 {
                decompressedData = entryCompressed
            } else if method == 8 {
                decompressedData = decompressDeflate(compressed: entryCompressed, uncompressedSize: uncompSize)
            } else {
                decompressedData = nil
            }

            guard let entryData = decompressedData else { continue }
            let lowerName = name.lowercased()

            // 1. Scan for background/wallpaper image
            if lowerName.hasPrefix("background") || lowerName.hasPrefix("wallpaper") || lowerName.hasPrefix("tiled") || lowerName.hasSuffix(".jpg") || lowerName.hasSuffix(".png") || lowerName.hasSuffix(".jpeg") {
                if wallpaperB64 == nil, let b64 = encodeImageDataToBase64(entryData) {
                    wallpaperB64 = b64
                }
            }

            // 2. Scan for palette / colors file
            let isPalette = lowerName.contains("tdesktop-theme") ||
                            lowerName.contains("palette") ||
                            lowerName.contains("scheme") ||
                            lowerName.hasSuffix(".txt") ||
                            lowerName == "colors" ||
                            lowerName == "theme"

            if isPalette {
                if let str = String(data: entryData, encoding: .utf8) ?? String(data: entryData, encoding: .isoLatin1) {
                    if str.contains("windowBg") || str.contains("dialogsBg") || str.contains("msgInBg") || str.contains("chat_") || str.contains(":") {
                        paletteContent = str
                    } else if paletteContent.isEmpty {
                        paletteContent = str
                    }
                }
            }
        }

        // If no palette matched by name, check any decompressed text with ':' or '='
        if paletteContent.isEmpty {
            offset = 0
            while offset + 30 <= data.count {
                let sig = data.subdata(in: offset..<offset+4)
                if sig != Data([0x50, 0x4b, 0x03, 0x04]) { break }
                let method = data.subdata(in: offset+8..<offset+10).withUnsafeBytes { $0.load(as: UInt16.self) }
                let compSize = Int(data.subdata(in: offset+18..<offset+22).withUnsafeBytes { $0.load(as: UInt32.self) })
                let uncompSize = Int(data.subdata(in: offset+22..<offset+26).withUnsafeBytes { $0.load(as: UInt32.self) })
                let nameLen = Int(data.subdata(in: offset+26..<offset+28).withUnsafeBytes { $0.load(as: UInt16.self) })
                let extraLen = Int(data.subdata(in: offset+28..<offset+30).withUnsafeBytes { $0.load(as: UInt16.self) })

                guard offset + 30 + nameLen <= data.count else { break }
                let name = String(data: data.subdata(in: offset+30..<offset+30+nameLen), encoding: .utf8) ?? ""
                let dataStart = offset + 30 + nameLen + extraLen
                guard dataStart + compSize <= data.count else { break }
                let entryCompressed = data.subdata(in: dataStart..<dataStart+compSize)
                offset = dataStart + compSize

                if !name.hasSuffix(".jpg") && !name.hasSuffix(".png") && !name.hasSuffix(".jpeg") {
                    let decomp = (method == 0) ? entryCompressed : (method == 8 ? decompressDeflate(compressed: entryCompressed, uncompressedSize: uncompSize) : nil)
                    if let d = decomp, let str = String(data: d, encoding: .utf8) ?? String(data: d, encoding: .isoLatin1) {
                        if (str.contains(":") || str.contains("=")) && (str.contains("Bg") || str.contains("Fg") || str.contains("Color") || str.contains("chat")) {
                            paletteContent = str
                            break
                        }
                    }
                }
            }
        }

        return (paletteContent, wallpaperB64)
    }

    private static func decompressDeflate(compressed: Data, uncompressedSize: Int) -> Data? {
        guard uncompressedSize > 0 else { return Data() }
        var dest = Data(count: uncompressedSize)
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }

        let success: Bool = compressed.withUnsafeBytes { compPtr in
            dest.withUnsafeMutableBytes { destPtr in
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: compPtr.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(compressed.count)
                stream.next_out = destPtr.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(uncompressedSize)
                let status = inflate(&stream, Z_FINISH)
                return (status == Z_STREAM_END || status == Z_OK)
            }
        }
        return success ? dest : nil
    }

    // MARK: - Image Conversion Helper

    private static func encodeImageDataToBase64(_ data: Data) -> String? {
        #if canImport(AppKit)
        if let img = NSImage(data: data),
           let tiff = img.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
            return jpeg.base64EncodedString()
        }
        #elseif canImport(UIKit)
        if let img = UIImage(data: data),
           let jpeg = img.jpegData(compressionQuality: 0.85) {
            return jpeg.base64EncodedString()
        }
        #endif
        return nil
    }

    // MARK: - Universal Palette Parsing (Desktop, Android .attheme, iOS .tgios-theme, Telegram X)

    private static func parseColorVariables(from text: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)
        var indentStack: [(indent: Int, key: String)] = []

        for rawLine in lines {
            var line = rawLine
            if let commentIdx = line.range(of: "//") {
                line = String(line[..<commentIdx.lowerBound])
            }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.starts(with: "#") || trimmed.starts(with: "!") || trimmed.starts(with: "@") {
                continue
            }

            // Leading spaces for hierarchical YAML-style structure (.tgios-theme / iOS palettes)
            let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            while let last = indentStack.last, last.indent >= leadingSpaces {
                indentStack.removeLast()
            }

            if trimmed.contains(":") {
                let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
                let rawKeyPart = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                var valPart = parts.count > 1 ? parts[1] : ""
                if let cIdx = valPart.range(of: "//") {
                    valPart = String(valPart[..<cIdx.lowerBound])
                }
                valPart = valPart.trimmingCharacters(in: CharacterSet(charactersIn: "; \t\r\n"))

                if valPart.isEmpty {
                    // Indented block header (e.g., "root:", "navBar:", "chat:")
                    indentStack.append((indent: leadingSpaces, key: rawKeyPart))
                } else {
                    let pathPrefix = indentStack.map { $0.key }.joined(separator: "_")
                    let subKeys = rawKeyPart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    for subKey in subKeys {
                        let fullKey = pathPrefix.isEmpty ? subKey : "\(pathPrefix)_\(subKey)"
                        if let normalized = normalizeColor(valPart) {
                            result[fullKey] = normalized
                            result[subKey] = normalized
                        } else {
                            result[fullKey] = valPart
                            result[subKey] = valPart
                        }
                    }
                }
            } else if trimmed.contains("=") {
                let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    let rawKey = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    var valPart = parts[1]
                    if let cIdx = valPart.range(of: "//") {
                        valPart = String(valPart[..<cIdx.lowerBound])
                    }
                    valPart = valPart.trimmingCharacters(in: CharacterSet(charactersIn: "; \t\r\n"))

                    let subKeys = rawKey.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    for subKey in subKeys {
                        if let normalized = normalizeColor(valPart) {
                            result[subKey] = normalized
                        } else {
                            result[subKey] = valPart
                        }
                    }
                }
            }
        }

        return result
    }

    /// Normalizes colors into uppercase #RRGGBB hex string
    private static func normalizeColor(_ raw: String) -> String? {
        let str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str == "clear" || str == "none" { return "#00000000" }

        // 1. Hex color with or without '#' (e.g., #RRGGBB, #RRGGBBAA, RRGGBB, RRGGBBAA)
        let clean = str.trimmingCharacters(in: CharacterSet(charactersIn: "# ;,\t\r\n"))
        if clean.allSatisfy({ $0.isHexDigit }) {
            if clean.count == 6 {
                return "#" + clean.uppercased()
            } else if clean.count == 8 {
                let r = clean.prefix(2)
                let g = clean.dropFirst(2).prefix(2)
                let b = clean.dropFirst(4).prefix(2)
                let a = clean.suffix(2)
                if a == "00" {
                    return "#00000000"
                }
                if a.uppercased() == "FF" {
                    return "#\(r)\(g)\(b)".uppercased()
                }
                // Telegram Desktop colors are RRGGBBAA
                return "#\(r)\(g)\(b)\(a)".uppercased()
            } else if clean.count == 4 {
                let r = clean[clean.startIndex]
                let g = clean[clean.index(clean.startIndex, offsetBy: 1)]
                let b = clean[clean.index(clean.startIndex, offsetBy: 2)]
                let a = clean[clean.index(clean.startIndex, offsetBy: 3)]
                if a == "0" {
                    return "#00000000"
                }
                return "#\(r)\(r)\(g)\(g)\(b)\(b)".uppercased()
            } else if clean.count == 3 {
                let r = clean[clean.startIndex]
                let g = clean[clean.index(clean.startIndex, offsetBy: 1)]
                let b = clean[clean.index(clean.startIndex, offsetBy: 2)]
                return "#\(r)\(r)\(g)\(g)\(b)\(b)".uppercased()
            }
        }

        // 2. Signed 32-bit integer (Android .attheme standard format)
        if let intVal = Int32(str) {
            let uintVal = UInt32(bitPattern: intVal)
            let a = (uintVal >> 24) & 0xFF
            if a == 0 {
                return "#00000000"
            }
            let r = (uintVal >> 16) & 0xFF
            let g = (uintVal >> 8) & 0xFF
            let b = uintVal & 0xFF
            return String(format: "#%02X%02X%02X", r, g, b)
        }

        // 3. Unsigned 32-bit integer
        if let uintVal = UInt32(str) {
            let a = (uintVal >> 24) & 0xFF
            if a == 0 {
                return "#00000000"
            }
            let r = (uintVal >> 16) & 0xFF
            let g = (uintVal >> 8) & 0xFF
            let b = uintVal & 0xFF
            return String(format: "#%02X%02X%02X", r, g, b)
        }

        // 4. rgba(r, g, b, a) or rgb(r, g, b)
        if str.lowercased().hasPrefix("rgb") {
            let comps = str.replacingOccurrences(of: "rgba", with: "")
                .replacingOccurrences(of: "rgb", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "() \t"))
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if comps.count >= 3,
               let r = Int(comps[0]),
               let g = Int(comps[1]),
               let b = Int(comps[2]) {
                if comps.count >= 4, let a = Double(comps[3]), a == 0 {
                    return "#00000000"
                }
                return String(format: "#%02X%02X%02X", min(255, max(0, r)), min(255, max(0, g)), min(255, max(0, b)))
            }
        }

        return nil
    }

    /// Resolve variable aliases recursively (up to 6 levels)
    private static func resolveAliases(_ dict: [String: String]) -> [String: String] {
        var resolved = dict

        for (key, _) in dict {
            var current = dict[key] ?? ""
            var hops = 0
            while !current.hasPrefix("#") && hops < 6 {
                if let next = dict[current] {
                    current = next
                    hops += 1
                } else {
                    break
                }
            }
            if current.hasPrefix("#") {
                resolved[key] = current
            }
        }

        return resolved
    }

    // MARK: - Construct VKThemePack (Desktop + Mobile Mapping)

    private static func buildThemePack(name: String, colors: [String: String], wallpaperBase64: String?) -> VKThemePack {
        func findColor(_ keys: [String], fallback: String) -> String {
            for k in keys {
                if let val = colors[k], val.hasPrefix("#") {
                    if val == "#00000000" {
                        continue
                    }
                    let hexBody = String(val.dropFirst())
                    if hexBody.count == 6 || hexBody.count == 8 {
                        let clean = "#" + hexBody.uppercased()
                        if k == "windowBgActive" && (clean == "#000000" || clean == "#000000FF") {
                            continue
                        }
                        return clean
                    }
                }
            }
            return fallback
        }

        // 1. Accent Color
        let accent = findColor([
            "root_navBar_accentText", "root_navBar_control", "root_tabBar_selectedIcon", "list_accent",
            "chatList_unreadBadgeActiveBg", "badge", "controlActive", "actionBarDefault", "chats_actionBackground",
            "chats_unreadCounter", "windowActiveTextFg", "dialogsUnreadBg", "historyPeer1NameFg", "msgInDateFg",
            "dialogsNameFgActive", "dialogsChatIconFg", "chat_outBubble", "chat_outTime",
            "accent_color", "activeButtonBg", "dialogsBgActive", "windowBgActive"
        ], fallback: "#2B82E0")

        // 2. Background Color (Chat wallpaper / chat background)
        let background = findColor([
            "chat_defaultWallpaper", "chatBackground", "chat_background", "chat_wallpaper", "chatList_bg",
            "windowBackgroundWhite", "windowBg", "dialogsBg"
        ], fallback: "#18222D")

        // 3. Surface Color (Dialogs sidebar / headers / Navigation bar)
        let surface = findColor([
            "root_navBar_background", "root_tabBar_background", "chatList_bg", "headerBackground",
            "actionBarDefault", "dialogsBg", "windowBg", "windowBackgroundWhite", "chat_list_background"
        ], fallback: "#18222D")

        // 4. Secondary Surface
        let secondarySurface = findColor([
            "list_itemBlocksBg", "headerLightBackground", "windowBackgroundGray",
            "dialogsBgOver", "windowBgOver", "scrollBg", "dialogsBgActive"
        ], fallback: "#212D3B")

        // 5. Separator
        let separator = findColor([
            "chatList_itemSeparator", "root_navBar_separator", "root_tabBar_separator",
            "list_plainSeparator", "list_blocksSeparator", "divider", "dialogsSeparator", "shadowFg", "windowSubTextFg"
        ], fallback: "#2A3644")

        // 6. Incoming Bubble
        let bubbleIncoming = findColor([
            "chat_message_incoming_bubble_withWp_bg", "chat_message_incoming_bubble_withoutWp_bg",
            "bubbleIn_background", "chat_inBubble", "msgInBg", "chat_message_in", "msgInShadow"
        ], fallback: "#212D3B")

        // 7. Outgoing Bubble
        let bubbleOutgoing = findColor([
            "chat_message_outgoing_bubble_withWp_bg", "chat_message_outgoing_bubble_withoutWp_bg",
            "bubbleOut_background", "chat_outBubble", "msgOutBg", "chat_message_out"
        ], fallback: accent)

        // 8. Incoming Text
        let rawIncomingText = findColor([
            "chat_message_incoming_primaryText", "chat_messageTextIn", "chat_inText",
            "historyTextInFg", "msgInFg", "chat_message_in_text", "windowFg", "primaryText"
        ], fallback: "#FFFFFF")
        let bubbleIncomingText = ColorContrast.ensureContrast(foregroundHex: rawIncomingText, on: bubbleIncoming, minRatio: 4.5)

        // 9. Outgoing Text
        let rawOutgoingText = findColor([
            "chat_message_outgoing_primaryText", "chat_messageTextOut", "chat_outText",
            "historyTextOutFg", "msgOutFg", "chat_message_out_text", "primaryText"
        ], fallback: "#FFFFFF")
        let bubbleOutgoingText = ColorContrast.ensureContrast(foregroundHex: rawOutgoingText, on: bubbleOutgoing, minRatio: 4.5)

        // 10. Bubble Stroke
        let bubbleStroke = findColor([
            "chat_message_incoming_bubble_withWp_stroke", "chat_message_outgoing_bubble_withWp_stroke",
            "msgInShadow", "chat_inBubbleSelected", "msgOutShadow"
        ], fallback: "")
        let strokeHex: String? = (bubbleStroke.hasPrefix("#") && bubbleStroke != bubbleIncoming) ? bubbleStroke : nil

        // Compute base theme from background & surface luminance
        let bgLum = luminance(hex: background)
        let surfLum = luminance(hex: surface)
        let avgLum = (bgLum + surfLum) / 2.0

        let baseTheme: String
        if avgLum < 0.22 {
            baseTheme = "night"
        } else if avgLum < 0.52 {
            baseTheme = "tinted"
        } else if avgLum > 0.82 {
            baseTheme = "classic"
        } else {
            baseTheme = "day"
        }

        let pattern = (wallpaperBase64 != nil) ? "custom" : (avgLum < 0.5 ? "telegram_doodles" : "none")

        return VKThemePack(
            id: UUID().uuidString,
            name: name,
            author: "Telegram Port",
            baseTheme: baseTheme,
            accentHex: accent,
            backgroundHex: background,
            surfaceHex: surface,
            secondarySurfaceHex: secondarySurface,
            separatorHex: separator,
            bubbleIncomingHex: bubbleIncoming,
            bubbleOutgoingHex: bubbleOutgoing,
            bubbleIncomingTextHex: bubbleIncomingText,
            bubbleOutgoingTextHex: bubbleOutgoingText,
            bubbleStrokeHex: strokeHex,
            bubbleStrokeWidth: strokeHex != nil ? 0.8 : 0.0,
            interfaceStrokeHex: nil,
            wallpaperBase64: wallpaperBase64,
            wallpaperPattern: pattern,
            wallpaperOpacity: 0.9,
            wallpaperBlur: 0.0
        )
    }

    /// Calculate relative luminance from #RRGGBB
    private static func luminance(hex: String) -> Double {
        guard let color = Color(hex: hex) else { return 0.5 }
        #if canImport(AppKit)
        let ns = NSColor(color)
        guard let rgb = ns.usingColorSpace(.sRGB) else { return 0.5 }
        return 0.299 * Double(rgb.redComponent) + 0.587 * Double(rgb.greenComponent) + 0.114 * Double(rgb.blueComponent)
        #elseif canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
        #else
        return 0.5
        #endif
    }
}
