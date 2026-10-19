import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct ThemePreviewModalView: View {
    public let previewTheme: VKThemePack
    public var onApply: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = ThemeManager.shared

    public init(themePack: VKThemePack? = nil, onApply: (() -> Void)? = nil) {
        self.previewTheme = themePack ?? ThemeManager.shared.currentThemePack
        self.onApply = onApply
    }

    // Color helpers derived from previewTheme
    private var isDarkTheme: Bool {
        previewTheme.baseTheme == "night" || previewTheme.baseTheme == "tinted"
    }
    private var textPrimaryColor: Color {
        isDarkTheme ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.1)
    }
    private var textSecondaryColor: Color {
        isDarkTheme ? Color(white: 0.65) : Color(red: 0.51, green: 0.55, blue: 0.60)
    }

    private var accentColor: Color { Color(hex: previewTheme.accentHex) ?? .blue }
    private var backgroundColor: Color { Color(hex: previewTheme.backgroundHex) ?? .black }
    private var surfaceColor: Color { Color(hex: previewTheme.surfaceHex) ?? (isDarkTheme ? Color(white: 0.15) : Color.white) }
    private var secondarySurfaceColor: Color { Color(hex: previewTheme.secondarySurfaceHex) ?? (isDarkTheme ? Color(white: 0.2) : Color(red: 0.94, green: 0.945, blue: 0.955)) }
    private var separatorColor: Color { Color(hex: previewTheme.separatorHex) ?? (isDarkTheme ? Color(white: 0.25) : Color(white: 0.85)) }

    private var bubbleIncomingColor: Color { Color(hex: previewTheme.bubbleIncomingHex) ?? (isDarkTheme ? Color(white: 0.2) : Color.white) }
    private var bubbleOutgoingColor: Color { Color(hex: previewTheme.bubbleOutgoingHex) ?? accentColor }

    private var bubbleIncomingTextColor: Color {
        let raw = Color(hex: previewTheme.bubbleIncomingTextHex) ?? (isDarkTheme ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
        return ColorContrast.ensureContrast(foreground: raw, on: bubbleIncomingColor, minRatio: 4.5)
    }
    private var bubbleOutgoingTextColor: Color {
        let raw = Color(hex: previewTheme.bubbleOutgoingTextHex) ?? .white
        return ColorContrast.ensureContrast(foreground: raw, on: bubbleOutgoingColor, minRatio: 4.5)
    }
    private var replyAuthorNameColor: Color {
        ColorContrast.ensureContrast(foreground: accentColor, on: bubbleIncomingColor, minRatio: 4.5)
    }

    private var bubbleStrokeColor: Color? {
        if let h = previewTheme.bubbleStrokeHex, !h.isEmpty { return Color(hex: h) }
        return nil
    }
    private var bubbleStrokeWidth: CGFloat { CGFloat(previewTheme.bubbleStrokeWidth) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Modal Title
            Text("Предпросмотр темы")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(VKColors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Live Window Mockup (matches Telegram theme preview)
            #if os(macOS)
            ZStack {
                VStack(spacing: 0) {
                    // Window Titlebar
                    windowTitlebar

                    // Window Body (Sidebar + Chat)
                    HStack(spacing: 0) {
                        mockDialogsSidebar
                            .frame(width: 220)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)

                        Rectangle()
                            .fill(separatorColor)
                            .frame(width: 0.8)

                        mockChatArea
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .clipped()
                    }
                }
                .background(surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 20)
            .frame(height: 510)
            #else
            mockMobileTelegramPreview
                .padding(.horizontal, 16)
            #endif

            // Bottom Actions Bar
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(previewTheme.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VKColors.textPrimary)
                    Text("Автор: \(previewTheme.author)")
                        .font(.system(size: 11))
                        .foregroundColor(VKColors.textSecondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Отмена")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(VKColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(VKColors.secondarySurface)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    theme.applyThemePack(previewTheme)
                    onApply?()
                    dismiss()
                }) {
                    Text("Применить тему")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(Color(red: 0.2, green: 0.6, blue: 0.95)) // Telegram blue button
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        #if os(macOS)
        .frame(width: 790, height: 615)
        #endif
        .background(VKColors.surface)
    }

    // MARK: - Window Titlebar
    private var windowTitlebar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 10, height: 10)
                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 10, height: 10)
                Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 10, height: 10)
            }
            .padding(.leading, 12)

            Spacer()

            Text("Telegram")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(textSecondaryColor)

            Spacer()

            Color.clear.frame(width: 48)
        }
        .frame(height: 28)
        .background(surfaceColor)
        .overlay(
            Rectangle()
                .fill(separatorColor)
                .frame(height: 0.8),
            alignment: .bottom
        )
    }

    // MARK: - Left Dialogs Sidebar
    private var mockDialogsSidebar: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(textSecondaryColor)
                Text("Search")
                    .font(.system(size: 11.5))
                    .foregroundColor(textSecondaryColor)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(secondarySurfaceColor)
            .cornerRadius(12)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            // Dialog Rows
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    sidebarRow(avatarText: "E", avatarColor: Color(red: 0.89, green: 0.32, blue: 0.25), name: "Eva Summer", time: "11:00", snippet: "We are too smart for this world. ...", isPinned: true, isSelected: true)
                    sidebarRow(avatarText: "A", avatarColor: Color(red: 0.90, green: 0.31, blue: 0.22), name: "Alexandra Smith", time: "10:00", snippet: "This is amazing!", badgeCount: 2)
                    sidebarRow(avatarText: "M", avatarColor: Color(red: 0.65, green: 0.35, blue: 0.70), name: "Mike Apple", time: "9:00", snippet: "😁 Sticker", badgeCount: 2)
                    sidebarRow(avatarText: "E", avatarColor: Color(red: 0.90, green: 0.50, blue: 0.15), name: "Evening Club", time: "8:00", snippet: "Eva: Photo", isGroup: true)
                    sidebarRow(avatarText: "O", avatarColor: Color(red: 0.10, green: 0.60, blue: 0.55), name: "Old Pirates", time: "7:00", snippet: "Max: Yo-ho-ho!", isGroup: true)
                    sidebarRow(avatarText: "M", avatarColor: Color(red: 0.80, green: 0.75, blue: 0.20), name: "Max Bright", time: "6:00", snippet: "How about some coffee?", isRead: true)
                    sidebarRow(avatarText: "N", avatarColor: Color(red: 0.20, green: 0.70, blue: 0.40), name: "Natalie Parker", time: "5:00", snippet: "OK, great)", isRead: true)
                    sidebarRow(avatarText: "D", avatarColor: Color(red: 0.40, green: 0.40, blue: 0.40), name: "Davy Jones", time: "4:00", snippet: "Keynote.pdf")
                }
                .padding(.horizontal, 4)
            }
        }
        .background(surfaceColor)
    }

    private func sidebarRow(
        avatarText: String,
        avatarColor: Color,
        name: String,
        time: String,
        snippet: String,
        badgeCount: Int = 0,
        isPinned: Bool = false,
        isGroup: Bool = false,
        isRead: Bool = false,
        isSelected: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(avatarColor)
                Text(avatarText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if isGroup {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 9))
                            .foregroundColor(textSecondaryColor)
                    }
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? (isDarkTheme ? .white : accentColor) : textPrimaryColor)
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    if isRead {
                        HStack(spacing: -3) {
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(accentColor)
                    }

                    Text(time)
                        .font(.system(size: 10))
                        .foregroundColor(textSecondaryColor)
                }

                HStack {
                    Text(snippet)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? accentColor : textSecondaryColor)
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(textSecondaryColor)
                    } else if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(isSelected ? (isDarkTheme ? secondarySurfaceColor.opacity(0.8) : accentColor.opacity(0.12)) : Color.clear)
        .cornerRadius(6)
    }

    // MARK: - Mobile Telegram Mockup (iOS)
    private var mockMobileTelegramPreview: some View {
        VStack(spacing: 0) {
            // Status bar with Dynamic Island
            HStack {
                Text("09:41")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimaryColor)

                Spacer()

                // Dynamic Island
                Capsule()
                    .fill(Color.black)
                    .frame(width: 76, height: 16)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: 11))
                .foregroundColor(textPrimaryColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(surfaceColor)

            // Mobile Telegram Chat Header
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Чаты")
                        .font(.system(size: 16))
                }
                .foregroundColor(accentColor)

                Spacer()

                HStack(spacing: 8) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                            .overlay(Text("E").font(.system(size: 13, weight: .bold)).foregroundColor(.white))

                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(surfaceColor, lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Eva Summer")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(textPrimaryColor)
                        Text("в сети")
                            .font(.system(size: 10.5))
                            .foregroundColor(accentColor)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Image(systemName: "phone")
                        .font(.system(size: 15))
                        .foregroundColor(accentColor)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(surfaceColor)
            .overlay(
                Rectangle()
                    .fill(separatorColor)
                    .frame(height: 0.5),
                alignment: .bottom
            )

            // Chat Messages with Wallpaper
            ZStack {
                chatWallpaper

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        // Date Pill
                        Text("Сегодня")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.38))
                            .clipShape(Capsule())
                            .padding(.vertical, 4)

                        // 1. Incoming Message with Reply Quote
                        incomingReplyMessage

                        // 2. Outgoing Bubble
                        outgoingBubble(text: "Привет! Как тебе эта тема оформления? Все цвета идеально сочетаются 👌", time: "09:41")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
            .frame(height: 250)

            // Mobile Write Bar
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(accentColor)

                HStack {
                    Text("Сообщение...")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondaryColor)
                    Spacer()
                    Image(systemName: "face.smiling")
                        .font(.system(size: 16))
                        .foregroundColor(textSecondaryColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(secondarySurfaceColor)
                .clipShape(Capsule())

                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(surfaceColor)
            .overlay(
                Rectangle()
                    .fill(separatorColor)
                    .frame(height: 0.5),
                alignment: .top
            )

            // Home Indicator
            Capsule()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 100, height: 4)
                .padding(.vertical, 5)
                .background(surfaceColor)
        }
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(separatorColor, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
    }

    // MARK: - Right Chat Area
    private var mockChatArea: some View {
        VStack(spacing: 0) {
            // Chat Header
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Eva Summer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textPrimaryColor)
                    Text("online")
                        .font(.system(size: 10.5))
                        .foregroundColor(accentColor)
                }

                Spacer()

                HStack(spacing: 14) {
                    Image(systemName: "magnifyingglass")
                    Image(systemName: "phone")
                    Image(systemName: "ellipsis")
                }
                .font(.system(size: 12))
                .foregroundColor(textSecondaryColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(surfaceColor)
            .overlay(
                Rectangle()
                    .fill(separatorColor)
                    .frame(height: 0.8),
                alignment: .bottom
            )

            // Chat Messages with Wallpaper
            ZStack {
                chatWallpaper

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        // 1. Incoming photo message
                        incomingPhotoMessage

                        // 2. Outgoing voice message
                        outgoingVoiceMessage

                        // Date Pill
                        Text("December 26")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Capsule())
                            .padding(.vertical, 2)

                        // 3. Outgoing long quote text
                        outgoingBubble(text: "Twenty years from now you will be more disappointed by the things that you didn't do than by the ones you did do. 🤭", time: "10:00")

                        // 4. Outgoing short text
                        outgoingBubble(text: "Mark Twain said that ☝️", time: "10:00")

                        // 5. Incoming reply message
                        incomingReplyMessage
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }

            // Bottom Write Bar
            HStack(spacing: 10) {
                Image(systemName: "paperclip")
                    .font(.system(size: 13))
                    .foregroundColor(Color.gray)

                Text("Write a message...")
                    .font(.system(size: 12))
                    .foregroundColor(Color.gray.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "face.smiling")
                    .font(.system(size: 13))
                    .foregroundColor(Color.gray)

                Image(systemName: "mic.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(surfaceColor)
            .overlay(
                Rectangle()
                    .fill(separatorColor)
                    .frame(height: 0.8),
                alignment: .top
            )
        }
    }

    // MARK: - Chat Wallpaper in Preview
    @ViewBuilder
    private var chatWallpaper: some View {
        ZStack {
            backgroundColor

            if let b64 = previewTheme.wallpaperBase64, !b64.isEmpty,
               let data = Data(base64Encoded: b64),
               let img = PlatformImage.from(data: data) {
                Image(platformImage: img)
                    .resizable()
                    .scaledToFill()
                    .opacity(previewTheme.wallpaperOpacity)
                    .blur(radius: previewTheme.wallpaperBlur)
            } else if previewTheme.wallpaperPattern == "telegram_doodles",
                      let doodles = ThemeAssets.telegramDoodlesImage {
                let isDark = (previewTheme.baseTheme == "night" || previewTheme.baseTheme == "tinted")
                Image(platformImage: doodles)
                    .renderingMode(.template)
                    .resizable(resizingMode: .tile)
                    .foregroundColor(isDark ? Color.white.opacity(previewTheme.wallpaperOpacity * 0.16) : Color.black.opacity(previewTheme.wallpaperOpacity * 0.18))
                    .blur(radius: previewTheme.wallpaperBlur)
            }
        }
    }

    // MARK: - Messages Mockups

    private var incomingPhotoMessage: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                if let burano = ThemeAssets.buranoImage {
                    Image(platformImage: burano)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 120)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Rectangle()
                        .fill(Color.orange.opacity(0.7))
                        .frame(width: 220, height: 120)
                        .cornerRadius(6)
                }

                HStack {
                    Text("To reach a port, we must sail. 😇")
                        .font(.system(size: 11))
                        .foregroundColor(bubbleIncomingTextColor)
                    Spacer(minLength: 4)
                    Text("7:00")
                        .font(.system(size: 9))
                        .foregroundColor(bubbleIncomingTextColor.opacity(0.6))
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
            .padding(4)
            .background(bubbleIncomingColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(bubbleStrokeColor ?? Color.clear, lineWidth: bubbleStrokeWidth)
            )
            .frame(maxWidth: 240, alignment: .leading)

            Spacer()
        }
    }

    private var outgoingVoiceMessage: some View {
        HStack {
            Spacer()

            HStack(spacing: 8) {
                // Play button
                ZStack {
                    Circle().fill(Color.white.opacity(0.2))
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundColor(bubbleOutgoingTextColor)
                }
                .frame(width: 24, height: 24)

                // Fake waveform bars
                HStack(alignment: .center, spacing: 1.5) {
                    ForEach([4, 8, 12, 10, 6, 14, 18, 12, 8, 16, 10, 6, 12, 14, 8, 4, 10, 6, 8, 4], id: \.self) { h in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(bubbleOutgoingTextColor.opacity(0.7))
                            .frame(width: 2, height: CGFloat(h))
                    }
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("0:07")
                        .font(.system(size: 9))
                        .foregroundColor(bubbleOutgoingTextColor.opacity(0.7))

                    HStack(spacing: 2) {
                        Text("8:00")
                            .font(.system(size: 8.5))
                            .foregroundColor(bubbleOutgoingTextColor.opacity(0.6))
                        HStack(spacing: -3) {
                            Image(systemName: "checkmark").font(.system(size: 7, weight: .bold))
                            Image(systemName: "checkmark").font(.system(size: 7, weight: .bold))
                        }
                        .foregroundColor(accentColor)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(bubbleOutgoingColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(bubbleStrokeColor ?? Color.clear, lineWidth: bubbleStrokeWidth)
            )
        }
    }

    private func outgoingBubble(text: String, time: String) -> some View {
        HStack {
            Spacer(minLength: 40)
            HStack(alignment: .bottom, spacing: 6) {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(bubbleOutgoingTextColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 2) {
                    Text(time)
                        .font(.system(size: 8.5))
                        .foregroundColor(bubbleOutgoingTextColor.opacity(0.6))
                    HStack(spacing: -3) {
                        Image(systemName: "checkmark").font(.system(size: 7, weight: .bold))
                        Image(systemName: "checkmark").font(.system(size: 7, weight: .bold))
                    }
                    .foregroundColor(accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(bubbleOutgoingColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(bubbleStrokeColor ?? Color.clear, lineWidth: bubbleStrokeWidth)
            )
            .frame(maxWidth: 270, alignment: .trailing)
        }
    }

    private var incomingReplyMessage: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Quote banner
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(replyAuthorNameColor)
                        .frame(width: 2.5, height: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Alex Cassio")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(replyAuthorNameColor)
                        Text("Mark Twain said that ☝️")
                            .font(.system(size: 9.5))
                            .foregroundColor(bubbleIncomingTextColor.opacity(0.8))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)

                HStack(alignment: .bottom, spacing: 6) {
                    Text("We are too smart for this world. 😂😂")
                        .font(.system(size: 11))
                        .foregroundColor(bubbleIncomingTextColor)

                    Text("11:00")
                        .font(.system(size: 8.5))
                        .foregroundColor(bubbleIncomingTextColor.opacity(0.6))
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
            .padding(4)
            .background(bubbleIncomingColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(bubbleStrokeColor ?? Color.clear, lineWidth: bubbleStrokeWidth)
            )
            .frame(maxWidth: 270, alignment: .leading)

            Spacer(minLength: 40)
        }
    }
}
