import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
import UIKit

// MARK: - Root iOS Main View (Classic Telegram Layout)
public struct iOSMainView: View {
    @ObservedObject var store: MessengerStore
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject private var photoViewer = PhotoViewerService.shared
    @ObservedObject private var videoPlayer = VideoPlayerService.shared
    @Binding var showSettings: Bool
    @Binding var showLogin: Bool

    @State private var selectedTab: Int = 1 // Default to Chats (Tab 1)
    @State private var showNewMessageModal: Bool = false
    @State private var showFolderManager: Bool = false

    public init(store: MessengerStore, showSettings: Binding<Bool>, showLogin: Binding<Bool>) {
        self.store = store
        self._showSettings = showSettings
        self._showLogin = showLogin
    }

    public var body: some View {
        ZStack {
            // Base layer: Tab views (Contacts, Conversations, Settings)
            VStack(spacing: 0) {
                ZStack {
                    if selectedTab == 0 {
                        iOSContactsView(store: store)
                    } else if selectedTab == 1 {
                        iOSConversationsView(
                            store: store,
                            showNewMessageModal: $showNewMessageModal,
                            showFolderManager: $showFolderManager
                        )
                    } else {
                        iOSSettingsView(
                            store: store,
                            showLogin: $showLogin,
                            showFolderManager: $showFolderManager
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Classic Telegram Bottom Tab Bar (Edge-to-Edge pinned)
                TelegramBottomTabBar(
                    selectedTab: $selectedTab,
                    unreadCount: store.totalUnreadCount
                )
            }

            // Top layer: Active Chat View (slides over conversation list)
            if store.selectedPeerId != nil {
                ChatView(store: store)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .identity
                    ))
                    .zIndex(1)
            }
        }
        .sheet(isPresented: $showNewMessageModal) {
            NewMessageModalView(store: store)
        }
        .sheet(isPresented: $showFolderManager) {
            FolderManagerModalView(store: store)
        }
        .fullScreenCover(isPresented: $photoViewer.isOpen) {
            PhotoViewerWindowView(onClose: {
                photoViewer.close()
            })
        }
        .fullScreenCover(isPresented: $videoPlayer.isOpen) {
            VideoPlayerWindowView(onClose: {
                videoPlayer.close()
            })
        }
        .tint(VKColors.accent)
    }
}

// MARK: - Classic Telegram Bottom Tab Bar
struct TelegramBottomTabBar: View {
    @Binding var selectedTab: Int
    let unreadCount: Int
    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Hairline separator
            Rectangle()
                .fill(VKColors.separator.opacity(0.8))
                .frame(height: 0.33)

            HStack(spacing: 0) {
                // Tab 0: Контакты
                tabItem(
                    index: 0,
                    title: "Контакты",
                    systemImage: selectedTab == 0 ? "person.2.fill" : "person.2",
                    badge: nil
                )

                // Tab 1: Чаты
                tabItem(
                    index: 1,
                    title: "Чаты",
                    systemImage: selectedTab == 1 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right",
                    badge: unreadCount > 0 ? "\(unreadCount)" : nil
                )

                // Tab 2: Настройки
                tabItem(
                    index: 2,
                    title: "Настройки",
                    systemImage: selectedTab == 2 ? "gearshape.fill" : "gearshape",
                    badge: nil
                )
            }
            .frame(height: 49)
        }
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                VKColors.surface.opacity(0.92)
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(index: Int, title: String, systemImage: String, badge: String?) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedTab = index
        }) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.system(size: 21, weight: .regular))
                        .frame(height: 24)

                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color(red: 1.0, green: 0.23, blue: 0.19))
                            .clipShape(Capsule())
                            .offset(x: 14, y: -4)
                    }
                }

                Text(title)
                    .font(.system(size: 10, weight: selectedTab == index ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selectedTab == index ? VKColors.accent : Color(UIColor.systemGray))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - iOS Contacts Tab (Classic Telegram)
struct iOSContactsView: View {
    @ObservedObject var store: MessengerStore
    @State private var searchQuery: String = ""

    private var filteredFriends: [VKUser] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return store.friends
        }
        let q = searchQuery.lowercased()
        return store.friends.filter { $0.fullName.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Контакты")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VKColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(VKColors.surface)

            // Search Bar
            HStack(spacing: 8) {
                VKSearchField(text: $searchQuery, placeholder: "Поиск контактов")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(VKColors.surface)

            Divider()

            if filteredFriends.isEmpty && !store.isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.2")
                        .font(.system(size: 44))
                        .foregroundColor(VKColors.textSecondary.opacity(0.5))
                    Text(searchQuery.isEmpty ? "Список контактов пуст" : "Ничего не найдено")
                        .font(VKTypography.headline)
                        .foregroundColor(VKColors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredFriends) { friend in
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.22)) {
                                store.selectConversation(friend.id)
                            }
                        }) {
                            HStack(spacing: 12) {
                                VKAvatarView(
                                    url: friend.photoURL,
                                    name: friend.fullName,
                                    size: 44,
                                    isOnline: friend.isOnline,
                                    isMobile: friend.isMobileOnline
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(friend.fullName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(VKColors.textPrimary)
                                            .lineLimit(1)

                                        if friend.isVerified {
                                            VKVerifiedBadge()
                                        }
                                    }

                                    Text(friendStatusText(friend))
                                        .font(.system(size: 13))
                                        .foregroundColor(friend.isOnline ? VKColors.accent : VKColors.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 3)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(VKColors.surface)
                        .listRowSeparatorTint(VKColors.separator.opacity(0.5))
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await store.fetchFriends()
                }
            }
        }
        .background(VKColors.surface)
        .task {
            if store.friends.isEmpty {
                await store.fetchFriends()
            }
        }
    }

    private func friendStatusText(_ friend: VKUser) -> String {
        if friend.isOnline {
            return "в сети"
        }
        if let timestamp = friend.lastSeen?.time {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let calendar = Calendar.current
            let formatter = DateFormatter()
            if calendar.isDateInToday(date) {
                formatter.dateFormat = "HH:mm"
                return "был(а) сегодня в \(formatter.string(from: date))"
            } else if calendar.isDateInYesterday(date) {
                formatter.dateFormat = "HH:mm"
                return "был(а) вчера в \(formatter.string(from: date))"
            } else {
                formatter.dateFormat = "d MMM"
                return "был(а) \(formatter.string(from: date))"
            }
        }
        return "не в сети"
    }
}

// MARK: - iOS Conversations List
struct iOSConversationsView: View {
    @ObservedObject var store: MessengerStore
    @ObservedObject var theme = ThemeManager.shared
    @Binding var showNewMessageModal: Bool
    @Binding var showFolderManager: Bool

    @State private var selectedFolderIndex: Int = 0

    struct FolderTab: Identifiable, Equatable {
        let id: String
        let folderId: UUID?
        let name: String
    }

    private var folderTabs: [FolderTab] {
        var tabs = [FolderTab(id: "all", folderId: nil, name: "Все")]
        for f in store.folders {
            tabs.append(FolderTab(id: f.id.uuidString, folderId: f.id, name: f.name))
        }
        return tabs
    }

    var body: some View {
        VStack(spacing: 0) {
            // Classic Telegram Header Bar
            HStack(spacing: 12) {
                Button(action: {
                    showFolderManager = true
                }) {
                    Text("Изм.")
                        .font(.system(size: 17))
                        .foregroundColor(VKColors.accent)
                }

                Spacer()

                if store.connectionStatus == .connecting {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Соединение...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VKColors.textSecondary)
                    }
                } else if store.connectionStatus == .updating {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Обновление...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VKColors.accent)
                    }
                } else {
                    Text("Чаты")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(VKColors.textPrimary)
                }

                Spacer()

                Button(action: {
                    showNewMessageModal = true
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(VKColors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(VKColors.surface)

            // Search Bar
            HStack(spacing: 8) {
                VKSearchField(text: $store.searchQuery, placeholder: "Поиск по чатам и сообщениям")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(VKColors.surface)

            // Folders Horizontal Pill Bar (if user has custom folders)
            if !store.folders.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(folderTabs.enumerated()), id: \.element.id) { index, tab in
                                folderPill(tab: tab, isSelected: selectedFolderIndex == index) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedFolderIndex = index
                                        store.selectedFolderId = tab.folderId
                                    }
                                }
                                .id(tab.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    .background(VKColors.surface)
                    .onChange(of: selectedFolderIndex) { newIndex in
                        if newIndex >= 0 && newIndex < folderTabs.count {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(folderTabs[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider()

            // Main Content: Swipable Folders or Single List
            if !store.folders.isEmpty {
                TabView(selection: $selectedFolderIndex) {
                    ForEach(Array(folderTabs.enumerated()), id: \.element.id) { index, tab in
                        conversationListView(folderId: tab.folderId)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedFolderIndex) { newIndex in
                    if newIndex >= 0 && newIndex < folderTabs.count {
                        store.selectedFolderId = folderTabs[newIndex].folderId
                    }
                }
            } else {
                conversationListView(folderId: nil)
            }
        }
        .background(VKColors.surface)
    }

    @ViewBuilder
    private func conversationListView(folderId: UUID?) -> some View {
        let list = store.conversations(for: folderId)
        if list.isEmpty && !store.isLoading {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 44))
                    .foregroundColor(VKColors.textSecondary.opacity(0.5))
                Text(store.searchQuery.isEmpty ? "Нет диалогов" : "Ничего не найдено")
                    .font(VKTypography.headline)
                    .foregroundColor(VKColors.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(list) { conv in
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.22)) {
                            store.selectConversation(conv.peerId)
                        }
                    }) {
                        HStack(spacing: 12) {
                            VKAvatarView(
                                url: conv.avatarURL,
                                name: conv.displayTitle,
                                size: 52,
                                isOnline: conv.isSavedMessages ? false : conv.isOnline,
                                isMobile: conv.isSavedMessages ? false : conv.isMobile,
                                isSavedMessages: conv.isSavedMessages
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(conv.displayTitle)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(VKColors.textPrimary)
                                        .lineLimit(1)

                                    if conv.isVerified && !conv.isSavedMessages {
                                        VKVerifiedBadge()
                                    }

                                    Spacer()

                                    if let lastMsg = conv.lastMessage {
                                        Text(lastMsgDateText(lastMsg.date))
                                            .font(.system(size: 12))
                                            .foregroundColor(conv.unreadCount > 0 ? VKColors.accent : VKColors.textSecondary)
                                    }
                                }

                                HStack(alignment: .center, spacing: 4) {
                                    if let lastMsg = conv.lastMessage {
                                        if lastMsg.out {
                                            Text("Вы:")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(VKColors.accent)
                                        }

                                        Text(lastMsgPreviewText(lastMsg))
                                            .font(.system(size: 14))
                                            .foregroundColor(VKColors.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if store.isPinned(conv.peerId) {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(VKColors.textSecondary.opacity(0.85))
                                            .rotationEffect(.degrees(45))
                                    }

                                    if conv.unreadCount > 0 {
                                        VKUnreadBadge(count: conv.unreadCount)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(VKColors.surface)
                    .listRowSeparatorTint(VKColors.separator.opacity(0.5))
                    .contextMenu {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            store.togglePin(conv.peerId)
                        } label: {
                            Label(
                                store.isPinned(conv.peerId) ? "Открепить" : "Закрепить",
                                systemImage: store.isPinned(conv.peerId) ? "pin.slash" : "pin"
                            )
                        }

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            store.toggleMute(peerId: conv.peerId)
                        } label: {
                            Label(
                                store.isMuted(peerId: conv.peerId) ? "Включить звук" : "Без звука",
                                systemImage: store.isMuted(peerId: conv.peerId) ? "bell.fill" : "bell.slash"
                            )
                        }

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            store.markAsRead(peerId: conv.peerId)
                        } label: {
                            Label("Пометить как прочитанное", systemImage: "checkmark.circle")
                        }

                        Divider()

                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            if let idx = store.conversations.firstIndex(where: { $0.peerId == conv.peerId }) {
                                store.conversations.remove(at: idx)
                            }
                        } label: {
                            Label("Удалить диалог", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            store.toggleMute(peerId: conv.peerId)
                        } label: {
                            Label(
                                store.isMuted(peerId: conv.peerId) ? "Вкл. звук" : "Без звука",
                                systemImage: store.isMuted(peerId: conv.peerId) ? "bell.fill" : "bell.slash.fill"
                            )
                        }
                        .tint(store.isMuted(peerId: conv.peerId) ? .blue : .orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            store.togglePin(conv.peerId)
                        } label: {
                            Label(
                                store.isPinned(conv.peerId) ? "Открепить" : "Закрепить",
                                systemImage: store.isPinned(conv.peerId) ? "pin.slash" : "pin"
                            )
                        }
                        .tint(store.isPinned(conv.peerId) ? .gray : .orange)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            if conv.unreadCount > 0 {
                                store.markAsRead(peerId: conv.peerId)
                            }
                        } label: {
                            Label("Прочитано", systemImage: "checkmark.circle")
                        }
                        .tint(VKColors.accent)
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await store.fetchConversations()
            }
        }
    }

    private func folderPill(tab: FolderTab, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(tab.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : VKColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? VKColors.accent : VKColors.secondarySurface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func lastMsgDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }

    private func lastMsgPreviewText(_ msg: VKMessage) -> String {
        let cleanText = msg.text.replacingOccurrences(of: "&#8203;", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanText.isEmpty {
            return cleanText
        }
        if msg.wallPost != nil {
            return "Запись со стены"
        }
        if msg.hasAttachments {
            return "Вложение"
        }
        if msg.sticker != nil {
            return "Стикер"
        }
        return ""
    }
}

// MARK: - iOS Settings View (with Telegram Theme Porting)
struct iOSSettingsView: View {
    @ObservedObject var store: MessengerStore
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var notifications = NotificationService.shared
    @Binding var showLogin: Bool
    @Binding var showFolderManager: Bool

    @State private var showFileImporter: Bool = false
    @State private var importErrorMessage: String? = nil
    @State private var showImportError: Bool = false
    @State private var showAppliedAlert: Bool = false
    @State private var appliedThemeName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var refreshToggle: Bool = false

    private var documentsThemesDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Themes")
    }

    private var installedFilesThemes: [URL] {
        guard let dir = documentsThemesDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "tdesktop-theme" || ext == "attheme" || ext == "tgios-theme" || ext == "zip" || ext == "themepack"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Настройки")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VKColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(VKColors.surface)

            Divider()

            List {
                // Profile Section
                Section {
                    HStack(spacing: 14) {
                        VKAvatarView(
                            url: store.api.currentUser?.photoURL,
                            name: store.api.currentUser?.fullName ?? "OpenVK",
                            size: 60
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.api.currentUser?.fullName ?? "Пользователь OpenVK")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(VKColors.textPrimary)

                            Text(store.api.serverURL)
                                .font(.system(size: 13))
                                .foregroundColor(VKColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // Chat Folders Section
                Section {
                    Button(action: {
                        showFolderManager = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(VKColors.accent.opacity(0.15))
                                    .frame(width: 36, height: 36)

                                Image(systemName: "folder.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(VKColors.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Папки с чатами")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(VKColors.textPrimary)

                                Text(store.folders.isEmpty ? "Создать папки для чатов" : "\(store.folders.count) настроенных папок")
                                    .font(.system(size: 12))
                                    .foregroundColor(VKColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(VKColors.textSecondary.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Appearance & Themes Section
                Section(header: Text("Темы оформления")) {
                    // Button: Портировать тему из Telegram
                    Button(action: {
                        showFileImporter = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(VKColors.accent.opacity(0.15))
                                    .frame(width: 36, height: 36)

                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(VKColors.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Портировать тему Telegram...")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(VKColors.textPrimary)

                                Text("Файлы .tdesktop-theme, .attheme, .tgios-theme, .zip")
                                    .font(.system(size: 12))
                                    .foregroundColor(VKColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(VKColors.textSecondary.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                    }

                    // Themes found in Files app (Documents/Themes)
                    if !installedFilesThemes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Файлы тем в папке OpenVK Messenger:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(VKColors.textSecondary)

                            ForEach(installedFilesThemes, id: \.self) { fileUrl in
                                HStack {
                                    Image(systemName: "paintpalette.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(VKColors.accent)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(fileUrl.deletingPathExtension().lastPathComponent)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(VKColors.textPrimary)
                                        Text(fileUrl.lastPathComponent)
                                            .font(.system(size: 11))
                                            .foregroundColor(VKColors.textSecondary)
                                    }

                                    Spacer()

                                    Button("Применить") {
                                        do {
                                            let pack = try theme.importTheme(from: fileUrl)
                                            theme.applyThemePack(pack)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            appliedThemeName = pack.name
                                            showAppliedAlert = true
                                        } catch {
                                            importErrorMessage = error.localizedDescription
                                            showImportError = true
                                        }
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(VKColors.accent)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Carousel of Telegram Presets
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Готовые темы Telegram")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(VKColors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(VKThemePack.allPresets) { preset in
                                    presetCard(preset)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 4)

                    // Chat Wallpaper
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Обои чатов")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(VKColors.textSecondary)

                        HStack(spacing: 14) {
                            // Wallpaper Preview Box
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(theme.backgroundColor)

                                if let img = theme.chatWallpaperImage {
                                    if theme.wallpaperPattern == "telegram_doodles" {
                                        Image(platformImage: img)
                                            .resizable(resizingMode: .tile)
                                            .opacity(theme.wallpaperOpacity)
                                    } else {
                                        Image(platformImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .opacity(theme.wallpaperOpacity)
                                    }
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 22))
                                        .foregroundColor(VKColors.textSecondary)
                                }
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(VKColors.separator, lineWidth: 1))

                            VStack(alignment: .leading, spacing: 8) {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 13))
                                        Text("Выбрать из Фото...")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(VKColors.accent)
                                }
                                .onChange(of: selectedPhotoItem) { newItem in
                                    Task {
                                        if let item = newItem,
                                           let data = try? await item.loadTransferable(type: Data.self),
                                           let img = UIImage(data: data) {
                                            theme.setCustomWallpaper(image: img)
                                        }
                                    }
                                }

                                HStack(spacing: 10) {
                                    Button("Узор Telegram") {
                                        theme.setTelegramDoodlesWallpaper()
                                    }
                                    .font(.system(size: 13))
                                    .foregroundColor(VKColors.accent)

                                    if theme.chatWallpaperImage != nil {
                                        Button("Сбросить") {
                                            theme.removeWallpaper()
                                        }
                                        .font(.system(size: 13))
                                        .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Accent Presets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Цвет акцента")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(VKColors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(VKAccentPreset.allCases.filter { $0 != .custom }) { preset in
                                    Button(action: {
                                        theme.setAccentPreset(preset)
                                    }) {
                                        Circle()
                                            .fill(preset.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                theme.accentPreset == preset ?
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.white)
                                                    : nil
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Custom Palette ColorPicker for iOS
                                ZStack {
                                    Circle()
                                        .fill(
                                            AngularGradient(
                                                gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red]),
                                                center: .center
                                            )
                                        )
                                        .frame(width: 32, height: 32)

                                    if theme.accentPreset == .custom {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 32, height: 32)
                                    }

                                    ColorPicker("", selection: Binding(
                                        get: { theme.customColor },
                                        set: { theme.setCustomColor($0) }
                                    ), supportsOpacity: false)
                                    .labelsHidden()
                                    .opacity(0.015)
                                    .frame(width: 32, height: 32)
                                }
                                .frame(width: 32, height: 32)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 4)

                    // Base Theme
                    Picker("Базовый режим", selection: Binding(
                        get: { theme.baseTheme },
                        set: { theme.setBaseTheme($0) }
                    )) {
                        ForEach(VKBaseTheme.allCases) { base in
                            Text(base.title).tag(base)
                        }
                    }
                }

                // Notifications Section
                Section(header: Text("Уведомления")) {
                    Toggle("Включить уведомления", isOn: $notifications.isNotificationsEnabled)
                    Toggle("Звук", isOn: $notifications.isSoundEnabled)
                    Toggle("Предпросмотр сообщения", isOn: $notifications.showPreview)
                }

                // About Section
                Section(header: Text("О программе")) {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text("1.0 (Build 2026)")
                            .foregroundColor(VKColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 13))
                            Text("Правовая информация")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(VKColors.textPrimary)
                        }

                        Text("OpenVK является любительской разработкой и никак не связан с ВКонтакте и компанией ООО \"ВК\".")
                            .font(.system(size: 13))
                            .foregroundColor(VKColors.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(.vertical, 4)
                }

                // Account Actions
                Section {
                    Button(role: .destructive, action: {
                        store.api.logout()
                        showLogin = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Выйти из аккаунта")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [
                .item,
                .data,
                .content,
                .archive,
                UTType.zip,
                UTType.plainText,
                UTType(filenameExtension: "tdesktop-theme") ?? .data,
                UTType(filenameExtension: "attheme") ?? .data,
                UTType(filenameExtension: "tgios-theme") ?? .data,
                UTType(filenameExtension: "themepack") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent("theme_\(Int(Date().timeIntervalSince1970))_\(url.lastPathComponent)")
                do {
                    if FileManager.default.fileExists(atPath: tempFile.path) {
                        try? FileManager.default.removeItem(at: tempFile)
                    }
                    try FileManager.default.copyItem(at: url, to: tempFile)

                    // Also save copy to Documents/Themes
                    if let themesDir = documentsThemesDirectory {
                        try? FileManager.default.createDirectory(at: themesDir, withIntermediateDirectories: true)
                        let persistentTarget = themesDir.appendingPathComponent(url.lastPathComponent)
                        if FileManager.default.fileExists(atPath: persistentTarget.path) {
                            try? FileManager.default.removeItem(at: persistentTarget)
                        }
                        try? FileManager.default.copyItem(at: tempFile, to: persistentTarget)
                    }

                    let pack = try theme.importTheme(from: tempFile)
                    theme.applyThemePack(pack)
                    try? FileManager.default.removeItem(at: tempFile)

                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    appliedThemeName = pack.name
                    showAppliedAlert = true
                    refreshToggle.toggle()
                } catch {
                    let msg = error.localizedDescription
                    self.importErrorMessage = msg
                    self.showImportError = true
                }
            case .failure(let error):
                let msg = error.localizedDescription
                self.importErrorMessage = msg
                self.showImportError = true
            }
        }
        .alert("Тема применена", isPresented: $showAppliedAlert) {
            Button("Отлично", role: .cancel) {}
        } message: {
            Text("Тема «\(appliedThemeName)» успешно импортирована и применена.")
        }
        .alert("Ошибка импорта темы", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "Не удалось импортировать файл.")
        }
    }

    private func presetCard(_ preset: VKThemePack) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.25)) {
                theme.applyThemePack(preset)
            }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: preset.accentHex) ?? .blue).frame(width: 14, height: 14)
                    Circle().fill(Color(hex: preset.bubbleOutgoingHex) ?? .blue).frame(width: 14, height: 14)
                    Circle().fill(Color(hex: preset.bubbleIncomingHex) ?? .white).frame(width: 14, height: 14)
                    Circle().fill(Color(hex: preset.backgroundHex) ?? .gray).frame(width: 14, height: 14)
                }

                Text(preset.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(VKColors.textPrimary)
                    .lineLimit(1)

                Text(preset.author)
                    .font(.system(size: 10))
                    .foregroundColor(VKColors.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 130)
            .background(theme.currentThemePack.id == preset.id ? VKColors.accent.opacity(0.15) : VKColors.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.currentThemePack.id == preset.id ? VKColors.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
