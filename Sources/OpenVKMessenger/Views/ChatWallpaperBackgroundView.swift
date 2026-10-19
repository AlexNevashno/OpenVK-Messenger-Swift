import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct ChatWallpaperBackgroundView: View {
    @ObservedObject private var theme = ThemeManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            theme.backgroundColor

            if let img = theme.chatWallpaperImage {
                if theme.wallpaperPattern == "telegram_doodles" {
                    // Tileable/repeated clean doodle pattern
                    let tile = Image(platformImage: img)
                        .renderingMode(.template)
                        .resizable(resizingMode: .tile)
                        .foregroundColor(theme.isDarkTheme ? Color.white.opacity(theme.wallpaperOpacity * 0.16) : Color.black.opacity(theme.wallpaperOpacity * 0.18))
                    if theme.wallpaperBlur > 0.5 {
                        tile.blur(radius: theme.wallpaperBlur)
                    } else {
                        tile
                    }
                } else {
                    GeometryReader { geo in
                        let pic = Image(platformImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .opacity(theme.wallpaperOpacity)
                        if theme.wallpaperBlur > 0.5 {
                            pic.blur(radius: theme.wallpaperBlur)
                        } else {
                            pic
                        }
                    }
                }
            }
        }
        .clipped()
    }
}
