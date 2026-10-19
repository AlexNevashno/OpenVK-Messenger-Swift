import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum ColorContrast {
    /// Calculate linear gamma-expanded sRGB component
    public static func srgbToLinear(_ c: Double) -> Double {
        if c <= 0.04045 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }

    /// Calculate relative luminance (0.0 to 1.0) according to WCAG 2.1
    public static func luminance(r: Double, g: Double, b: Double) -> Double {
        return 0.2126 * srgbToLinear(r) + 0.7152 * srgbToLinear(g) + 0.0722 * srgbToLinear(b)
    }

    private static func extractRGB(from color: Color) -> (r: Double, g: Double, b: Double)? {
        #if canImport(AppKit)
        let ns = NSColor(color)
        guard let srgb = ns.usingColorSpace(.sRGB) else { return nil }
        return (Double(srgb.redComponent), Double(srgb.greenComponent), Double(srgb.blueComponent))
        #elseif canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (Double(r), Double(g), Double(b))
        #else
        return nil
        #endif
    }

    /// Calculate relative luminance of SwiftUI Color
    public static func luminance(of color: Color) -> Double {
        if let rgb = extractRGB(from: color) {
            return luminance(r: rgb.r, g: rgb.g, b: rgb.b)
        }
        return 0.5
    }

    /// Calculate relative luminance from Hex string (#RRGGBB)
    public static func luminance(hex: String) -> Double {
        guard let color = Color(hex: hex) else { return 0.5 }
        return luminance(of: color)
    }

    /// WCAG Contrast Ratio between two luminance values (1.0 to 21.0)
    public static func contrastRatio(_ l1: Double, _ l2: Double) -> Double {
        let higher = max(l1, l2)
        let lower = min(l1, l2)
        return (higher + 0.05) / (lower + 0.05)
    }

    /// Contrast ratio between two SwiftUI Colors
    public static func contrastRatio(fg: Color, bg: Color) -> Double {
        return contrastRatio(luminance(of: fg), luminance(of: bg))
    }

    /// Ensure that `foreground` has at least `minRatio` (default 4.5:1, WCAG AA) contrast against `background`.
    public static func ensureContrast(foreground: Color, on background: Color, minRatio: Double = 4.5) -> Color {
        guard let fgRGB = extractRGB(from: foreground),
              let bgRGB = extractRGB(from: background) else {
            return foreground
        }

        let fgR = fgRGB.r
        let fgG = fgRGB.g
        let fgB = fgRGB.b
        let fgL = luminance(r: fgR, g: fgG, b: fgB)

        let bgL = luminance(r: bgRGB.r, g: bgRGB.g, b: bgRGB.b)

        if contrastRatio(fgL, bgL) >= minRatio {
            return foreground
        }

        let isBgDark = bgL < 0.5
        var bestR = fgR
        var bestG = fgG
        var bestB = fgB

        for step in 1...100 {
            let t = Double(step) / 100.0
            let newR = isBgDark ? fgR + (1.0 - fgR) * t : fgR * (1.0 - t)
            let newG = isBgDark ? fgG + (1.0 - fgG) * t : fgG * (1.0 - t)
            let newB = isBgDark ? fgB + (1.0 - fgB) * t : fgB * (1.0 - t)
            let newL = luminance(r: newR, g: newG, b: newB)
            if contrastRatio(newL, bgL) >= minRatio {
                bestR = newR
                bestG = newG
                bestB = newB
                break
            }
        }

        return Color(red: bestR, green: bestG, blue: bestB)
    }

    /// Hex string overload of ensureContrast
    public static func ensureContrast(foregroundHex: String, on backgroundHex: String, minRatio: Double = 4.5) -> String {
        guard let fg = Color(hex: foregroundHex),
              let bg = Color(hex: backgroundHex) else {
            return foregroundHex
        }
        let adjusted = ensureContrast(foreground: fg, on: bg, minRatio: minRatio)
        return adjusted.toHex() ?? foregroundHex
    }

    /// Calculate average relative luminance of an image
    public static func calculateAverageLuminance(of image: PlatformImage) -> Double {
        #if canImport(AppKit)
        let size = NSSize(width: 16, height: 16)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 16,
            pixelsHigh: 16,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 16 * 4,
            bitsPerPixel: 32
        ) else { return 0.25 }

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        var totalLum: Double = 0
        var count: Double = 0
        for y in 0..<16 {
            for x in 0..<16 {
                if let color = rep.colorAt(x: x, y: y),
                   let srgb = color.usingColorSpace(.sRGB) {
                    let r = Double(srgb.redComponent)
                    let g = Double(srgb.greenComponent)
                    let b = Double(srgb.blueComponent)
                    totalLum += luminance(r: r, g: g, b: b)
                    count += 1
                }
            }
        }
        return count > 0 ? (totalLum / count) : 0.25
        #else
        return 0.25
        #endif
    }
}

// MARK: - Chat Text Readability Shadow
public struct ChatTextReadabilityShadow: ViewModifier {
    public let isDark: Bool

    public init(isDark: Bool) {
        self.isDark = isDark
    }

    public func body(content: Content) -> some View {
        content
            .shadow(
                color: isDark ? Color.black.opacity(0.85) : Color.white.opacity(0.90),
                radius: 1.5,
                x: 0,
                y: 1
            )
    }
}

extension View {
    public func chatReadabilityShadow(isDark: Bool) -> some View {
        self.modifier(ChatTextReadabilityShadow(isDark: isDark))
    }
}
