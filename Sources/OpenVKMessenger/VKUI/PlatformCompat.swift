import SwiftUI

#if canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
#endif

extension Image {
    public init(platformImage: PlatformImage) {
        #if canImport(AppKit)
        self.init(nsImage: platformImage)
        #elseif canImport(UIKit)
        self.init(uiImage: platformImage)
        #endif
    }
}

extension Color {
    public init(platformColor: PlatformColor) {
        #if canImport(AppKit)
        self.init(nsColor: platformColor)
        #elseif canImport(UIKit)
        self.init(uiColor: platformColor)
        #endif
    }
}

extension PlatformImage {
    public func jpegDataRepresentation(quality: Double = 0.85) -> Data? {
        #if canImport(AppKit)
        guard let tiff = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #elseif canImport(UIKit)
        return self.jpegData(compressionQuality: CGFloat(quality))
        #endif
    }

    public func jpegDataRepresentation(compressionQuality: Double) -> Data? {
        jpegDataRepresentation(quality: compressionQuality)
    }

    public static func from(data: Data) -> PlatformImage? {
        #if canImport(AppKit)
        return NSImage(data: data)
        #elseif canImport(UIKit)
        return UIImage(data: data)
        #endif
    }
}

public enum PlatformPasteboard {
    public static func copyString(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}

public enum PlatformURLOpener {
    public static func open(_ url: URL) {
        #if canImport(AppKit)
        NSWorkspace.shared.open(url)
        #elseif canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}
