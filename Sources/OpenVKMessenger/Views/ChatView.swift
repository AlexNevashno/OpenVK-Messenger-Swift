import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

public struct ChatView: View {
    @ObservedObject var store: MessengerStore
    @ObservedObject private var theme = ThemeManager.shared
    @State private var inputText: String = ""
    @State private var isInfoSheetPresented: Bool = false
    @State private var showScrollToBottom: Bool = false
    @State private var viewportHeight: CGFloat = 0
    @State private var bottomAnchorMaxY: CGFloat = 0
    @State private var isNearBottom: Bool = true
    @State private var isBottomAnchorVisible: Bool = true
    @State private var isDropTargeted: Bool = false
    @State private var keyMonitor: Any? = nil
    @State private var highlightedMessageId: Int? = nil
    @State private var previewThemePack: VKThemePack? = nil
    @State private var dragDismissOffset: CGFloat = 0
    @State private var isSwipingBack: Bool = false
    @State private var hasInitialScrolledToBottom: Bool = false

    public var body: some View {
        ZStack {
            // Full-window wallpaper covering all empty spaces in chat
            ChatWallpaperBackgroundView()

            if store.selectedConversation != nil {
                VStack(spacing: 0) {
                    // Chat Header
                    ChatHeaderView(
                        conversation: store.selectedConversation,
                        typingText: store.typingStatus(for: store.selectedPeerId ?? 0),
                        isSearchActive: store.isMessageSearchActive,
                        connectionStatus: store.connectionStatus,
                        onToggleSearch: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.isMessageSearchActive.toggle()
                                if !store.isMessageSearchActive {
                                    store.messageSearchQuery = ""
                                    store.messageSearchResults = []
                                }
                            }
                        },
                        onOpenInfo: {
                            if store.selectedConversation != nil {
                                isInfoSheetPresented = true
                            }
                        },
                        onBack: {
                            #if os(iOS)
                            withAnimation(.easeOut(duration: 0.22)) {
                                dragDismissOffset = UIScreen.main.bounds.width + 30
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
                                store.selectedPeerId = nil
                                dragDismissOffset = 0
                            }
                            #else
                            store.selectedPeerId = nil
                            #endif
                        }
                    )

                    // Telegram Audio Miniplayer (pinned below header)
                    if AudioPlayerService.shared.activeId != nil {
                        TelegramAudioMiniplayerView()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Chat Messages Scroll Area
                    ScrollViewReader { proxy in
                        VStack(spacing: 0) {
                            // In-conversation message search bar
                            if store.isMessageSearchActive {
                                ChatMessageSearchBarView(
                                    store: store,
                                    onNavigateMatch: { targetIndex in
                                        navigateToMatch(at: targetIndex, proxy: proxy)
                                    },
                                    onClose: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            store.isMessageSearchActive = false
                                            store.messageSearchQuery = ""
                                            store.messageSearchResults = []
                                        }
                                    }
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            if let pinnedMsg = store.selectedConversation?.pinnedMessage {
                                PinnedMessageBarView(
                                    message: pinnedMsg,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            proxy.scrollTo(pinnedMsg.id, anchor: .center)
                                            highlightedMessageId = pinnedMsg.id
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                            withAnimation(.easeOut(duration: 0.5)) {
                                                if highlightedMessageId == pinnedMsg.id {
                                                    highlightedMessageId = nil
                                                }
                                            }
                                        }
                                    },
                                    onUnpin: {
                                        Task {
                                            await store.unpinMessage(peerId: store.selectedPeerId ?? 0)
                                        }
                                    }
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            ZStack(alignment: .bottomTrailing) {
                                ScrollView {
                                    LazyVStack(spacing: 6) {
                                        // Message List
                                        if let peerId = store.selectedPeerId {
                                            if let list = store.messages[peerId], !list.isEmpty {
                                                ChatMessageListView(
                                                    peerId: peerId,
                                                    messages: list,
                                                    highlightedMessageId: highlightedMessageId,
                                                    isLoadingOlder: store.isLoadingOlderHistory[peerId] == true,
                                                    canLoadMore: store.canLoadMoreHistory[peerId] ?? true,
                                                    canTriggerLoadOlder: hasInitialScrolledToBottom && showScrollToBottom,
                                                    onReply: { repMsg in
                                                        store.replyingToMessage = repMsg
                                                    },
                                                    onEdit: { editMsg in
                                                        store.editingMessage = editMsg
                                                        inputText = editMsg.text
                                                    },
                                                    onDelete: { delMsg in
                                                        store.deleteMessage(peerId: peerId, messageId: delMsg.id)
                                                    },
                                                    onJumpToMessage: { targetId in
                                                        withAnimation(.easeInOut(duration: 0.35)) {
                                                            proxy.scrollTo(targetId, anchor: .center)
                                                            highlightedMessageId = targetId
                                                        }
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                                            withAnimation(.easeOut(duration: 0.5)) {
                                                                if highlightedMessageId == targetId {
                                                                    highlightedMessageId = nil
                                                                }
                                                            }
                                                        }
                                                    },
                                                    onPreviewTheme: { pack in
                                                        previewThemePack = pack
                                                    },
                                                    onLoadOlder: { topMsgId in
                                                        Task {
                                                            await store.loadOlderHistory(for: peerId)
                                                            if let anchorId = topMsgId {
                                                                DispatchQueue.main.async {
                                                                    proxy.scrollTo(anchorId, anchor: .top)
                                                                }
                                                            }
                                                        }
                                                    }
                                                )
                                            } else if store.isLoadingHistory[peerId] == true || store.messages[peerId] == nil {
                                                VStack(spacing: 12) {
                                                    ProgressView()
                                                        .controlSize(.regular)
                                                    Text("Загрузка сообщений...")
                                                        .font(VKTypography.subhead)
                                                        .foregroundColor(theme.chatAuthorNameColor(for: 0, baseColor: .white.opacity(0.85)))
                                                        .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)
                                                }
                                                .frame(maxWidth: .infinity, minHeight: 180)
                                                .padding(.top, 40)
                                                .task {
                                                    if store.messages[peerId] == nil && store.isLoadingHistory[peerId] != true {
                                                        await store.fetchHistory(for: peerId)
                                                    }
                                                }
                                            } else {
                                                VStack(spacing: 8) {
                                                    Image(systemName: "bubble.left.and.bubble.right")
                                                        .font(.system(size: 28))
                                                        .foregroundColor(theme.chatAuthorNameColor(for: 0, baseColor: .white.opacity(0.7)))
                                                    Text("Нет сообщений")
                                                        .font(VKTypography.subhead)
                                                        .foregroundColor(theme.chatAuthorNameColor(for: 0, baseColor: .white.opacity(0.85)))
                                                }
                                                .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)
                                                .frame(maxWidth: .infinity, minHeight: 180)
                                                .padding(.top, 40)
                                            }
                                        }

                                        // Bottom anchor
                                        Color.clear
                                            .frame(height: 1)
                                            .id("bottomAnchor")
                                            .background(
                                                GeometryReader { geo in
                                                    Color.clear.preference(
                                                        key: BottomOffsetPreferenceKey.self,
                                                        value: geo.frame(in: .named("chatScrollSpace")).maxY
                                                    )
                                                }
                                            )
                                            .onAppear {
                                                isBottomAnchorVisible = true
                                                checkBottomStatus()
                                            }
                                    }
                                    .padding(.vertical, 8)
                                }
                                #if os(iOS)
                                .scrollDismissesKeyboard(.interactively)
                                #endif
                                .background(Color.clear)
                                .coordinateSpace(name: "chatScrollSpace")
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: ScrollViewHeightPreferenceKey.self,
                                            value: geo.size.height
                                        )
                                    }
                                )
                                .onPreferenceChange(ScrollViewHeightPreferenceKey.self) { height in
                                    self.viewportHeight = height
                                    checkBottomStatus()
                                }
                                .onPreferenceChange(BottomOffsetPreferenceKey.self) { maxY in
                                    self.bottomAnchorMaxY = maxY
                                    checkBottomStatus()
                                }
                                .onChange(of: store.messages[store.selectedPeerId ?? 0]?.last?.id) { _ in
                                    let lastMsg = store.messages[store.selectedPeerId ?? 0]?.last
                                    let isSelf = lastMsg?.out == true
                                    if isSelf || isNearBottom || !showScrollToBottom {
                                        triggerAutoScrollToBottom(proxy: proxy)
                                    }
                                }
                                .onChange(of: store.selectedPeerId) { newPeerId in
                                    hasInitialScrolledToBottom = false
                                    isNearBottom = true
                                    showScrollToBottom = false
                                    scrollToBottom(proxy: proxy, animated: false)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        scrollToBottom(proxy: proxy, animated: false)
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        scrollToBottom(proxy: proxy, animated: false)
                                        hasInitialScrolledToBottom = true
                                    }
                                    if let p = newPeerId {
                                        Task {
                                            await store.fetchHistory(for: p)
                                        }
                                    }
                                }
                                .onAppear {
                                    hasInitialScrolledToBottom = false
                                    isNearBottom = true
                                    scrollToBottom(proxy: proxy, animated: false)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        scrollToBottom(proxy: proxy, animated: false)
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        scrollToBottom(proxy: proxy, animated: false)
                                        hasInitialScrolledToBottom = true
                                    }
                                    if let p = store.selectedPeerId {
                                        Task {
                                            await store.fetchHistory(for: p)
                                        }
                                    }
                                }
                                .task(id: store.selectedPeerId) {
                                    if let peerId = store.selectedPeerId {
                                        await store.fetchHistory(for: peerId)
                                    }
                                }
                                .onChange(of: store.messages[store.selectedPeerId ?? 0]?.count) { newCount in
                                    if (newCount ?? 0) > 0 {
                                        scrollToBottom(proxy: proxy, animated: false)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                            scrollToBottom(proxy: proxy, animated: false)
                                            hasInitialScrolledToBottom = true
                                        }
                                    }
                                }

                                // Floating Scroll-To-Bottom Button: ONLY visible when scrolled up!
                                if showScrollToBottom {
                                    Button(action: {
                                        triggerAutoScrollToBottom(proxy: proxy)
                                    }) {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(VKColors.accent)
                                            .frame(width: 34, height: 34)
                                            .background(VKColors.surface)
                                            .clipShape(Circle())
                                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 16)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                    .overlay(
                        // Drag & Drop visual highlight
                        Group {
                            if isDropTargeted {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(VKColors.accent, lineWidth: 2)
                                    .background(VKColors.accent.opacity(0.06))
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "arrow.down.doc.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(VKColors.accent)
                                            Text("Перетащите фото сюда для отправки")
                                                .font(VKTypography.headline)
                                                .foregroundColor(VKColors.accent)
                                        }
                                    )
                            }
                        }
                    )
                    // Support drag and drop anywhere in chat
                    .onDrop(of: [.fileURL, .image, .png, .jpeg, .tiff], isTargeted: $isDropTargeted) { providers in
                        handleDroppedProviders(providers)
                    }

                    // Input Write Bar
                    WriteBarView(
                        text: $inputText,
                        placeholder: placeholderText,
                        onSend: {
                            if let editMsg = store.editingMessage {
                                store.editMessage(peerId: editMsg.peerId, messageId: editMsg.id, newText: inputText)
                                store.editingMessage = nil
                                inputText = ""
                            } else {
                                store.sendMessage(text: inputText)
                                inputText = ""
                            }
                        },
                        onTyping: {
                            store.sendTypingActivity()
                        },
                        store: store,
                        onSendSticker: { stickerId in
                            store.sendSticker(stickerId: stickerId)
                        },
                        onSendMedia: { attachmentCode, caption in
                            store.sendMessage(text: caption, attachment: attachmentCode)
                        }
                    )
                }
            } else {
                // Empty state when no dialog is selected: Telegram-style centered pill
                VStack(spacing: 12) {
                    Spacer()
                    Text("Выберите диалог для начала общения")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                    Spacer()
                }
            }
        }
        #if os(iOS)
        .offset(x: max(0, dragDismissOffset))
        .overlay(
            Group {
                if dragDismissOffset > 0 {
                    LinearGradient(
                        colors: [Color.black.opacity(0.22), Color.clear],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                    .frame(width: 14)
                    .offset(x: -14)
                }
            },
            alignment: .leading
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                .onChanged { val in
                    // Only start swipe back from left screen edge (within 45pt) so write bar, text field, and message taps are never hijacked
                    guard val.startLocation.x < 45 || isSwipingBack else { return }

                    let screenHeight = UIScreen.main.bounds.height
                    if val.startLocation.y > screenHeight - 340 && !isSwipingBack {
                        return
                    }

                    if isSwipingBack {
                        dragDismissOffset = max(0, val.translation.width)
                    } else if val.translation.width > 15 && val.translation.width > abs(val.translation.height) * 1.35 {
                        isSwipingBack = true
                        dragDismissOffset = max(0, val.translation.width)
                    }
                }
                .onEnded { val in
                    guard isSwipingBack else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragDismissOffset = 0
                        }
                        return
                    }
                    isSwipingBack = false

                    let screenWidth = UIScreen.main.bounds.width
                    let shouldDismiss = dragDismissOffset > screenWidth * 0.25 || val.predictedEndTranslation.width > 200

                    if shouldDismiss {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeOut(duration: 0.22)) {
                            dragDismissOffset = screenWidth + 20
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
                            store.selectedPeerId = nil
                            dragDismissOffset = 0
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragDismissOffset = 0
                        }
                    }
                }
        )
        #endif
        .sheet(isPresented: $isInfoSheetPresented) {
            if let conv = store.selectedConversation {
                VKConversationInfoView(store: store, conversation: conv)
            }
        }
        .sheet(item: $previewThemePack) { pack in
            ThemePreviewModalView(themePack: pack)
        }
        .onAppear {
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func checkBottomStatus() {
        guard viewportHeight > 0, bottomAnchorMaxY > 0 else { return }
        let distanceToBottom = bottomAnchorMaxY - viewportHeight
        let near = distanceToBottom <= 140
        if near != isNearBottom {
            isNearBottom = near
        }
        let shouldShow = distanceToBottom > 140
        if shouldShow != showScrollToBottom {
            withAnimation(.easeInOut(duration: 0.2)) {
                showScrollToBottom = shouldShow
            }
        }
    }

    private func triggerAutoScrollToBottom(proxy: ScrollViewProxy) {
        isNearBottom = true
        showScrollToBottom = false
        scrollToBottom(proxy: proxy, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            scrollToBottom(proxy: proxy, animated: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            scrollToBottom(proxy: proxy, animated: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            scrollToBottom(proxy: proxy, animated: false)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = false) {
        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo("bottomAnchor", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottomAnchor", anchor: .bottom)
        }
    }

    private var placeholderText: String {
        if let conv = store.selectedConversation {
            if conv.isSavedMessages {
                return "Сохранить в Избранное..."
            }
            let title = conv.displayTitle
            let firstName = title.split(separator: " ").first ?? Substring(title)
            return "Напишите \(firstName)..."
        }
        return "Напишите сообщение..."
    }

    // MARK: - Drag & Drop Handling
    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: NSURL.self) { nsUrl, _ in
                    if let url = nsUrl as? URL {
                        DispatchQueue.main.async {
                            handleDroppedURL(url)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let d = data, let img = PlatformImage.from(data: d) {
                        let jpeg = MessengerStore.convertToJPEGData(image: img) ?? d
                        DispatchQueue.main.async {
                            store.startUploadingPhoto(data: jpeg, preview: img, filename: "dropped.jpg")
                        }
                    }
                }
            }
        }
        return true
    }

    private func handleDroppedURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "webp", "bmp", "gif", "tiff"]
        if imageExtensions.contains(ext),
           let fileData = try? Data(contentsOf: url),
           let img = PlatformImage.from(data: fileData) {
            let jpeg = MessengerStore.convertToJPEGData(image: img) ?? fileData
            let cleanName = url.deletingPathExtension().appendingPathExtension("jpg").lastPathComponent
            store.startUploadingPhoto(data: jpeg, preview: img, filename: cleanName)
        }
    }

    // MARK: - Global Interception (Key and Trackpad Gestures)
    private func installKeyMonitor() {
        #if os(macOS)
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel, .swipe]) { event in
            // Trackpad swipe or horizontal two-finger scroll to the right
            if event.type == .swipe {
                if event.deltaX > 0.7 && abs(event.deltaY) < 0.25 {
                    // Deliberate right swipe gesture -> close chat
                    withAnimation(.easeInOut(duration: 0.22)) {
                        store.selectedPeerId = nil
                    }
                    return nil
                }
            } else if event.type == .scrollWheel {
                // Precise trackpad two-finger scroll: require strong, predominantly horizontal motion
                if event.hasPreciseScrollingDeltas {
                    let dx = event.scrollingDeltaX
                    let dy = event.scrollingDeltaY
                    // Must be a deliberate rightward swipe (dx > 85), vertical movement must be small (abs(dy) < 25),
                    // and horizontal delta must be at least 2.5x larger than vertical delta.
                    if dx > 85 && abs(dy) < 25 && dx > (abs(dy) * 2.5) {
                        if event.phase == .ended || event.momentumPhase == .began {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                store.selectedPeerId = nil
                            }
                        }
                    }
                }
            } else if event.type == .keyDown {
                let isCmd = event.modifierFlags.contains(.command)
                let isCtrl = event.modifierFlags.contains(.control)
                let char = event.charactersIgnoringModifiers?.lowercased()
                // Cmd+F / Ctrl+F: Message Search toggle
                let isSearchKey = event.keyCode == 3 || char == "f" || char == "а"
                if (isCmd || isCtrl) && isSearchKey {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isMessageSearchActive.toggle()
                        if !store.isMessageSearchActive {
                            store.messageSearchQuery = ""
                            store.messageSearchResults = []
                        }
                    }
                    return nil
                }

                // Esc: Close search if active
                if event.keyCode == 53 && store.isMessageSearchActive {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isMessageSearchActive = false
                        store.messageSearchQuery = ""
                        store.messageSearchResults = []
                    }
                    return nil
                }

                // macOS key code 9 is the physical 'V' key on ANSI layout.
                // Check keyCode 9 and characters "v" / "м" (Russian layout).
                let isPasteKey = event.keyCode == 9 || char == "v" || char == "м"
                if (isCmd || isCtrl) && isPasteKey {
                    // If clipboard contains an image or copied image file, intercept paste and start upload
                    if let clip = MessengerStore.getClipboardImageData() {
                        store.startUploadingPhoto(data: clip.data, preview: clip.preview, filename: clip.filename)
                        return nil
                    }
                }
            }
            return event
        }
        #endif
    }

    private func removeKeyMonitor() {
        #if os(macOS)
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        #endif
    }

    private func navigateToMatch(at index: Int, proxy: ScrollViewProxy) {
        guard index >= 0 && index < store.messageSearchResults.count else { return }
        store.currentSearchMatchIndex = index
        let match = store.messageSearchResults[index]
        store.ensureMessageLoadedInCurrentConversation(match)
        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(match.id, anchor: .center)
            highlightedMessageId = match.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.5)) {
                if highlightedMessageId == match.id {
                    highlightedMessageId = nil
                }
            }
        }
    }

    private func formatDateBubble(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Сегодня"
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            let df = DateFormatter()
            df.locale = Locale(identifier: "ru_RU")
            df.dateFormat = "d MMMM"
            return df.string(from: date)
        }
    }
}

// MARK: - Isolated Equatable Message List (prevents typing lag in WriteBar)

struct ChatMessageListView: View, Equatable {
    let peerId: Int
    let messages: [VKMessage]
    let highlightedMessageId: Int?
    let isLoadingOlder: Bool
    let canLoadMore: Bool
    let canTriggerLoadOlder: Bool
    let onReply: (VKMessage) -> Void
    var onEdit: ((VKMessage) -> Void)? = nil
    var onDelete: ((VKMessage) -> Void)? = nil
    let onJumpToMessage: (Int) -> Void
    let onPreviewTheme: (VKThemePack) -> Void
    let onLoadOlder: (Int?) -> Void

    static func == (lhs: ChatMessageListView, rhs: ChatMessageListView) -> Bool {
        lhs.peerId == rhs.peerId &&
        lhs.highlightedMessageId == rhs.highlightedMessageId &&
        lhs.isLoadingOlder == rhs.isLoadingOlder &&
        lhs.canLoadMore == rhs.canLoadMore &&
        lhs.canTriggerLoadOlder == rhs.canTriggerLoadOlder &&
        lhs.messages.count == rhs.messages.count &&
        lhs.messages.last?.id == rhs.messages.last?.id &&
        lhs.messages.last?.isRead == rhs.messages.last?.isRead &&
        lhs.messages.first?.id == rhs.messages.first?.id
    }

    var body: some View {
        Group {
            if canLoadMore {
                HStack {
                    Spacer()
                    if isLoadingOlder {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.vertical, 8)
                    } else if canTriggerLoadOlder {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                let topMsgId = messages.first?.id
                                onLoadOlder(topMsgId)
                            }
                    }
                    Spacer()
                }
            }

            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                let isFirstInDay = (index == 0) || !Calendar.current.isDate(message.date, inSameDayAs: messages[index - 1].date)
                if isFirstInDay {
                    HStack {
                        Spacer()
                        Text(formatChatDateBubble(message.date))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4.5)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                MessageRowView(
                    message: message,
                    isHighlighted: highlightedMessageId == message.id,
                    store: MessengerStore.shared,
                    onReply: onReply,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onJumpToMessage: onJumpToMessage,
                    onPreviewTheme: onPreviewTheme
                )
                .id(message.id)
            }
        }
    }
}

fileprivate func formatChatDateBubble(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return "Сегодня"
    } else if calendar.isDateInYesterday(date) {
        return "Вчера"
    } else {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM"
        return df.string(from: date)
    }
}

// MARK: - In-Conversation Message Search Bar View

public struct ChatMessageSearchBarView: View {
    @ObservedObject var store: MessengerStore
    public var onNavigateMatch: (Int) -> Void
    public var onClose: () -> Void

    @FocusState private var isFieldFocused: Bool

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(VKColors.textSecondary)
                .font(.system(size: 13))

            TextField("Поиск сообщений в беседе...", text: $store.messageSearchQuery)
                .textFieldStyle(.plain)
                .font(VKTypography.subhead)
                .foregroundColor(VKColors.textPrimary)
                .focused($isFieldFocused)
                .onSubmit {
                    if !store.messageSearchResults.isEmpty {
                        let next = (store.currentSearchMatchIndex + 1) % store.messageSearchResults.count
                        onNavigateMatch(next)
                    } else {
                        triggerSearch()
                    }
                }
                .onChange(of: store.messageSearchQuery) { _ in
                    triggerSearch()
                }

            if !store.messageSearchQuery.isEmpty {
                Button(action: {
                    store.messageSearchQuery = ""
                    store.messageSearchResults = []
                    store.currentSearchMatchIndex = 0
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(VKColors.textSecondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }

            if store.isSearchingMessages {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
            } else if !store.messageSearchQuery.isEmpty {
                if store.messageSearchResults.isEmpty {
                    Text("Не найдено")
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)
                } else {
                    Text("\(store.currentSearchMatchIndex + 1) из \(store.messageSearchResults.count)")
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)

                    HStack(spacing: 2) {
                        Button(action: {
                            if !store.messageSearchResults.isEmpty {
                                let prev = store.currentSearchMatchIndex > 0 ? store.currentSearchMatchIndex - 1 : store.messageSearchResults.count - 1
                                onNavigateMatch(prev)
                            }
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(VKColors.textPrimary)
                                .frame(width: 22, height: 22)
                                .background(VKColors.secondarySurface)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Предыдущее (Shift+Enter)")

                        Button(action: {
                            if !store.messageSearchResults.isEmpty {
                                let next = (store.currentSearchMatchIndex + 1) % store.messageSearchResults.count
                                onNavigateMatch(next)
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(VKColors.textPrimary)
                                .frame(width: 22, height: 22)
                                .background(VKColors.secondarySurface)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Следующее (Enter)")
                    }
                }
            }

            Divider()
                .frame(height: 14)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VKColors.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Закрыть (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.96))
        .background(VKColors.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(VKColors.separator.opacity(0.6)),
            alignment: .bottom
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFieldFocused = true
                if !store.messageSearchQuery.isEmpty {
                    triggerSearch()
                }
            }
        }
    }

    private func triggerSearch() {
        let q = store.messageSearchQuery
        Task {
            let res = await store.searchMessagesInCurrentConversation(query: q)
            if !res.isEmpty {
                onNavigateMatch(store.currentSearchMatchIndex)
            }
        }
    }
}

// MARK: - Preference Keys for Scroll Position Tracking
private struct BottomOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollViewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
