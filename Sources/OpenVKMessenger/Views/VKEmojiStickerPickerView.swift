import SwiftUI

public enum VKEmojiCategory: String, CaseIterable, Identifiable {
    case smileys = "Смайлы"
    case gestures = "Люди"
    case hearts = "Чувства"
    case animals = "Животные"
    case food = "Еда"
    case activities = "Спорт"
    case symbols = "Символы"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .smileys: return "😀"
        case .gestures: return "👋"
        case .hearts: return "❤️"
        case .animals: return "🐶"
        case .food: return "🍕"
        case .activities: return "⚽️"
        case .symbols: return "💡"
        }
    }

    public var emojis: [String] {
        switch self {
        case .smileys:
            return [
                "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "🥲", "🥹",
                "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗",
                "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓",
                "😎", "🥸", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕",
                "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭", "😤",
                "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨", "😰",
                "😥", "😓", "🤗", "🤔", "🫣", "🤭", "🫢", "🤫", "🤥", "😶",
                "😐", "😑", "😬", "🫨", "🙄", "😯", "😦", "😧", "😮", "😲",
                "🥱", "😴", "🤤", "😪", "😵", "😵‍💫", "🤐", "🥴", "🤢", "🤮",
                "🤧", "😷", "🤒", "🤕", "🤑", "🤠", "😈", "👿", "🤡", "💩",
                "👻", "💀", "☠️", "👽", "👾", "🤖", "🎃", "😺", "😸", "😹",
                "😻", "😼", "😽", "🙀", "😿", "😾"
            ]
        case .gestures:
            return [
                "👋", "🤚", "🖐", "✋", "🖖", "🫱", "🫲", "🫳", "🫴", "👌",
                "🤌", "🤏", "✌️", "🤞", "🫰", "🤟", "🤘", "🤙", "👈", "👉",
                "👆", "🖕", "👇", "☝️", "🫵", "👍", "👎", "✊", "👊", "🤛",
                "🤜", "👏", "🙌", "🫶", "👐", "🤲", "🤝", "🙏", "✍️", "💅",
                "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🫀",
                "🫁", "🧠", "🦷", "🦴", "👀", "👁", "👅", "👄", "🫦", "💋",
                "🫂", "👶", "🧒", "👦", "👧", "🧑", "👱", "👨", "🧔", "👩"
            ]
        case .hearts:
            return [
                "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
                "❤️‍🔥", "❤️‍🩹", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝",
                "💟", "☮️", "✝️", "☪️", "🪷", "💐", "🌸", "💮", "🏵", "🌹",
                "🥀", "🌺", "🌻", "🌼", "🌷", "🪻", "🌱", "🪴", "🌲", "🌳",
                "🌴", "🌵", "🌾", "🌿", "☘️", "🍀", "🍁", "🍂", "🍃", "🍄"
            ]
        case .animals:
            return [
                "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄️", "🐨",
                "🐯", "🦁", "🐮", "🐷", "🐽", "🐸", "🐵", "🙈", "🙉", "🙊",
                "🐒", "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉",
                "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🪱", "🐛", "🦋", "🐌",
                "🐞", "🐜", "🪰", "🪲", "🪳", "🦟", "🦗", "🕷", "🕸", "🦂",
                "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀",
                "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🦭", "🐊", "🐅"
            ]
        case .food:
            return [
                "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐",
                "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑",
                "🥦", "🥬", "🥒", "🌶", "🫑", "🌽", "🥕", "🫒", "🧄", "🧅",
                "🥔", "🍠", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳",
                "🧈", "🥞", "🧇", "🥓", "🥩", "🍗", "🍖", "🌭", "🍔", "🍟",
                "🍕", "🫓", "🥪", "🥙", "🧆", "🌮", "🌯", "🫔", "🥗", "🥘"
            ]
        case .activities:
            return [
                "⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱",
                "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳️",
                "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷",
                "⛸", "🥌", "🎿", "⛷", "🏂", "🪂", "🏋️‍♀️", "🤼‍♀️", "🤸‍♀️", "⛹️‍♀️",
                "🏆", "🥇", "🥈", "🥉", "🏅", "🎖", "🎫", "🎟", "🎪", "🤹",
                "🎭", "🎨", "🎬", "🎤", "🎧", "🎼", "🎹", "🥁", "🎷", "🎸"
            ]
        case .symbols:
            return [
                "💯", "💢", "💬", "💭", "🗯", "💤", "✨", "⭐️", "🌟", "💫",
                "💥", "🔥", "⚡️", "☄️", "🌈", "☀️", "🌤", "⛅️", "🌥", "☁️",
                "🌦", "🌧", "⛈", "🌩", "🌨", "❄️", "☃️", "⛄️", "🌬", "💨",
                "💧", "💦", "🫧", "☔️", "☂️", "💰", "💵", "💳", "💎", "💡",
                "🔮", "🧿", "🪄", "🔑", "🔒", "🔓", "🔔", "🔕", "📢", "📣"
            ]
        }
    }
}

public enum VKPickerMainTab: String, CaseIterable, Identifiable {
    case emoji = "Эмодзи"
    case stickers = "Стикеры"
    public var id: String { rawValue }
}

public struct VKEmojiStickerPickerView: View {
    @ObservedObject public var store: MessengerStore
    public let onSelectEmoji: (String) -> Void
    public let onSelectSticker: (Int) -> Void

    @State private var mainTab: VKPickerMainTab = .stickers
    @State private var selectedEmojiCategory: VKEmojiCategory = .smileys
    @State private var activePackId: Int? = nil

    private let emojiColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
    private let stickerColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    public init(
        store: MessengerStore,
        onSelectEmoji: @escaping (String) -> Void,
        onSelectSticker: @escaping (Int) -> Void
    ) {
        self.store = store
        self.onSelectEmoji = onSelectEmoji
        self.onSelectSticker = onSelectSticker
    }

    private var availablePacks: [VKStickerPack] {
        store.stickerPacks.isEmpty ? store.api.defaultStickerPacks(base: store.api.serverURL) : store.stickerPacks
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Segmented Navigation Tabs (Matching Telegram Desktop reference media_1791710407379_e5595869.png)
            topTabBar

            Divider()

            // MARK: - Tab Content Area
            if mainTab == .stickers {
                stickersContinuousContent
            } else {
                emojiPickerContent
            }
        }
        #if os(macOS)
        .frame(width: 360, height: 420)
        #else
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        #endif
        .background(VKColors.surface)
    }

    // MARK: - Top Tab Bar
    private var topTabBar: some View {
        HStack(spacing: 0) {
            ForEach(VKPickerMainTab.allCases) { tab in
                let isSelected = mainTab == tab
                Button(action: {
                    haptic()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        mainTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? VKColors.accent : VKColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)

                        Rectangle()
                            .fill(isSelected ? VKColors.accent : Color.clear)
                            .frame(height: 2.5)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(VKColors.surface)
    }

    // MARK: - Continuous Stickers View (Single ScrollView like Telegram)
    private var stickersContinuousContent: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // 1. Recents section (if any)
                        if !store.recentStickerIds.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Недавние")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(VKColors.textSecondary)
                                    .padding(.horizontal, 14)

                                LazyVGrid(columns: stickerColumns, spacing: 10) {
                                    ForEach(store.recentStickerIds, id: \.self) { sid in
                                        let item = store.stickerItem(for: sid)
                                        Button(action: {
                                            onSelectSticker(sid)
                                        }) {
                                            StickerThumbnailView(sticker: item, store: store)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                            .id("recents_anchor")
                        }

                        // 2. Favorites section (if any)
                        if !store.favoriteStickerIds.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Избранные")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(VKColors.textSecondary)
                                    .padding(.horizontal, 14)

                                LazyVGrid(columns: stickerColumns, spacing: 10) {
                                    ForEach(store.favoriteStickerIds, id: \.self) { sid in
                                        let item = store.stickerItem(for: sid)
                                        Button(action: {
                                            onSelectSticker(sid)
                                        }) {
                                            StickerThumbnailView(sticker: item, store: store)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                            .id("favorites_anchor")
                        }

                        // 3. Continuous packs
                        ForEach(availablePacks) { pack in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(pack.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(VKColors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 4)

                                LazyVGrid(columns: stickerColumns, spacing: 10) {
                                    ForEach(pack.stickers) { sticker in
                                        Button(action: {
                                            onSelectSticker(sticker.id)
                                        }) {
                                            StickerThumbnailView(sticker: sticker, store: store)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                            .id("pack_\(pack.id)")
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Bottom Navigation Dock
                Divider()
                HStack(spacing: 4) {
                    // ⭐ Favorites Anchor
                    Button(action: {
                        haptic()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("favorites_anchor", anchor: .top)
                        }
                    }) {
                        Image(systemName: !store.favoriteStickerIds.isEmpty ? "star.fill" : "star")
                            .font(.system(size: 18))
                            .foregroundColor(VKColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Избранные")

                    // 🕒 Recents Anchor
                    Button(action: {
                        haptic()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("recents_anchor", anchor: .top)
                        }
                    }) {
                        Image(systemName: "clock")
                            .font(.system(size: 18))
                            .foregroundColor(VKColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Недавние")

                    Rectangle()
                        .fill(VKColors.separator.opacity(0.6))
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 2)

                    // Scrollable Packs Row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(availablePacks) { pack in
                                let isSelected = activePackId == pack.id
                                Button(action: {
                                    haptic()
                                    activePackId = pack.id
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        proxy.scrollTo("pack_\(pack.id)", anchor: .top)
                                    }
                                }) {
                                    HStack(spacing: 0) {
                                        if let iconUrl = pack.iconURL ?? pack.stickers.first?.url {
                                            VKCachedAsyncImage(url: iconUrl) { img in
                                                img.resizable().scaledToFit().frame(width: 24, height: 24)
                                            } placeholder: {
                                                Image(systemName: "photo")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(VKColors.textSecondary)
                                                    .frame(width: 24, height: 24)
                                            }
                                        } else {
                                            Image(systemName: "face.smiling")
                                                .font(.system(size: 13))
                                                .foregroundColor(VKColors.textSecondary)
                                        }
                                    }
                                    .frame(width: 30, height: 30)
                                    .background(isSelected ? VKColors.accent.opacity(0.12) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? VKColors.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .help(pack.title)
                            }
                        }
                        .padding(.horizontal, 4)
                        .frame(height: 32)
                    }
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 38)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(VKColors.surface)
            }
        }
    }

    // MARK: - Emoji Picker View
    private var emojiPickerContent: some View {
        VStack(spacing: 0) {
            // Category Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(VKEmojiCategory.allCases) { cat in
                        Button(action: {
                            selectedEmojiCategory = cat
                        }) {
                            Text(cat.icon)
                                .font(.system(size: 16))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedEmojiCategory == cat ? VKColors.secondarySurface : Color.clear)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help(cat.rawValue)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(VKColors.surface)

            Divider()

            // Emojis Grid
            ScrollView {
                LazyVGrid(columns: emojiColumns, spacing: 6) {
                    ForEach(selectedEmojiCategory.emojis, id: \.self) { emoji in
                        Button(action: {
                            onSelectEmoji(emoji)
                        }) {
                            Text(emoji)
                                .font(.system(size: 24))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.0001))
                        )
                    }
                }
                .padding(10)
            }
        }
    }

    private func haptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

public struct StickerThumbnailView: View {
    public let sticker: VKStickerItem
    public let store: MessengerStore
    @State private var isHovered = false

    public var body: some View {
        Group {
            if sticker.animationURL != nil {
                VKAnimatedStickerView(
                    url: sticker.url,
                    animationURL: sticker.animationURL,
                    size: 72,
                    loop: isHovered
                )
            } else if let url = sticker.url {
                VKCachedAsyncImage(url: url) { img in
                    img
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(VKColors.secondarySurface)
                        .frame(width: 72, height: 72)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(VKColors.secondarySurface)
                    .frame(width: 72, height: 72)
            }
        }
        .padding(4)
        .background(isHovered ? VKColors.secondarySurface : Color.clear)
        .cornerRadius(10)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button {
                store.toggleFavoriteSticker(sticker.id)
            } label: {
                if store.isFavoriteSticker(sticker.id) {
                    Label("Удалить из избранного", systemImage: "star.slash")
                } else {
                    Label("В избранное", systemImage: "star.fill")
                }
            }
        }
    }
}
