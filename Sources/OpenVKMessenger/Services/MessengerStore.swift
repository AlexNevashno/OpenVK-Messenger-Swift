import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers
import Network

public enum ConnectionStatus: Equatable {
    case connected
    case updating
    case connecting
}

public struct PendingUploadItem: Identifiable, Equatable {
    public let id: UUID
    public let preview: PlatformImage
    public let data: Data
    public let filename: String
    public var progress: Double
    public var isUploading: Bool
    public var isDocument: Bool
    public var attachmentCode: String?
    public var error: String?

    public init(id: UUID = UUID(), preview: PlatformImage, data: Data, filename: String, progress: Double = 0.05, isUploading: Bool = true, isDocument: Bool = false, attachmentCode: String? = nil, error: String? = nil) {
        self.id = id
        self.preview = preview
        self.data = data
        self.filename = filename
        self.progress = progress
        self.isUploading = isUploading
        self.isDocument = isDocument
        self.attachmentCode = attachmentCode
        self.error = error
    }

    public static func == (lhs: PendingUploadItem, rhs: PendingUploadItem) -> Bool {
        lhs.id == rhs.id && lhs.progress == rhs.progress && lhs.isUploading == rhs.isUploading && lhs.attachmentCode == rhs.attachmentCode && lhs.isDocument == rhs.isDocument
    }
}

@MainActor
public final class MessengerStore: ObservableObject {
    public static let shared = MessengerStore()

    @Published public var conversations: [VKConversation] = [] {
        didSet {
            let totalUnread = conversations.reduce(0) { $0 + $1.unreadCount }
            NotificationService.shared.updateDockBadge(unreadCount: totalUnread)
        }
    }
    @Published public var selectedPeerId: Int?
    @Published public var messages: [Int: [VKMessage]] = [:] // Keyed by peerId
    @Published public var typingUsers: [Int: [TypingUser]] = [:] // Keyed by peerId
    @Published public var searchQuery: String = ""
    @Published public var onlyUnread: Bool = false {
        didSet {
            if api.isAuthenticated {
                Task { await self.fetchConversations() }
            }
        }
    }
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var stickerPacks: [VKStickerPack] = []
    @Published public var activeChatDetails: VKChatDetails? = nil
    @Published public var isLoadingChatDetails: Bool = false
    @Published public var isChatInfoPresented: Bool = false
    @Published public var replyingToMessage: VKMessage? = nil
    @Published public var editingMessage: VKMessage? = nil
    @Published public var pendingUploads: [PendingUploadItem] = []
    @Published public var pinnedPeerIds: Set<Int> = []
    @Published public var mutedPeerIds: Set<Int> = []
    @Published public var folders: [VKChatFolder] = []
    @Published public var selectedFolderId: UUID? = nil // nil = "All Chats"
    @Published public var friends: [VKUser] = []
    @Published public var favoriteStickerIds: [Int] = []
    @Published public var recentStickerIds: [Int] = []
    @Published public var canLoadMoreHistory: [Int: Bool] = [:]
    @Published public var isLoadingOlderHistory: [Int: Bool] = [:]
    @Published public var isLoadingHistory: [Int: Bool] = [:]

    // Message Search in Chat
    @Published public var isMessageSearchActive: Bool = false
    @Published public var messageSearchQuery: String = ""
    @Published public var messageSearchResults: [VKMessage] = []
    @Published public var currentSearchMatchIndex: Int = 0
    @Published public var isSearchingMessages: Bool = false

    // Multi-Account Bank
    @Published public var savedAccounts: [VKAccount] = []
    @Published public var currentAccountId: String? = nil

    // Cache Key for Multi-Account isolation
    public var currentAccountCacheKey: String {
        if let cur = currentAccountId, !cur.isEmpty {
            return cur
        }
        if let u = api.currentUser {
            return "\(u.id)@\(api.serverURL)"
        }
        if !api.token.isEmpty {
            let prefix = String(api.token.prefix(16))
            return "token_\(prefix)@\(api.serverURL)"
        }
        return "default_account"
    }

    // Community Messages & Administration
    @Published public var userGroups: [VKGroup] = []
    @Published public var administeredGroups: [VKGroup] = []
    @Published public var activeAdminGroup: VKGroup? = nil // nil = personal mode
    @Published public var isCommunityFilterActive: Bool = false

    // Network & Connection Monitoring
    @Published public var connectionStatus: ConnectionStatus = .connected
    @Published public var isNetworkConnected: Bool = true
    private var isAutoRefreshing: Bool = false
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "com.alexs.openvk.networkMonitor")

    public let api: OpenVKAPIService
    public let longPoll: OpenVKLongPollService
    private var pollTimer: Timer?
    private var typingExpiryTimers: [String: Timer] = [:]
    private var lastTypingSentDate: Date = .distantPast

    public init(api: OpenVKAPIService? = nil) {
        let resolvedAPI = api ?? OpenVKAPIService.shared
        self.api = resolvedAPI
        self.longPoll = OpenVKLongPollService(api: resolvedAPI)

        // Load pinned peers
        if let savedPins = UserDefaults.standard.array(forKey: "openvk_pinned_peers") as? [Int] {
            self.pinnedPeerIds = Set(savedPins)
        }

        // Load muted peers
        if let savedMutes = UserDefaults.standard.array(forKey: "openvk_muted_peers") as? [Int] {
            self.mutedPeerIds = Set(savedMutes)
        }

        // Load favorite & recent stickers
        if let favs = UserDefaults.standard.array(forKey: "openvk_favorite_stickers") as? [Int] {
            self.favoriteStickerIds = favs
        }
        if let recents = UserDefaults.standard.array(forKey: "openvk_recent_stickers") as? [Int] {
            self.recentStickerIds = recents
        }
        if let cachedPacks = VKStickerCache.shared.cachedStickerPacks(), !cachedPacks.isEmpty {
            self.stickerPacks = cachedPacks
        }

        // Load folders
        if let data = UserDefaults.standard.data(forKey: "openvk_chat_folders"),
           let decoded = try? JSONDecoder().decode([VKChatFolder].self, from: data) {
            self.folders = decoded
        } else {
            // Default starter folders
            self.folders = [
                VKChatFolder(name: "Личные", icon: "person.fill", peerIds: []),
                VKChatFolder(name: "Беседы", icon: "bubble.left.and.bubble.right.fill", peerIds: [])
            ]
        }

        // Load saved accounts
        if let data = UserDefaults.standard.data(forKey: "openvk_saved_accounts"),
           let decoded = try? JSONDecoder().decode([VKAccount].self, from: data) {
            self.savedAccounts = decoded
        }
        self.currentAccountId = UserDefaults.standard.string(forKey: "openvk_current_account_id")

        // Instant cache restore (Telegram-like instant startup)
        let cacheKey = self.currentAccountCacheKey
        if let cachedConvs = VKChatCache.shared.loadConversations(for: cacheKey), !cachedConvs.isEmpty {
            self.conversations = cachedConvs
            #if os(macOS)
            if let first = cachedConvs.first {
                self.selectedPeerId = first.peerId
                if let cachedMsgs = VKChatCache.shared.loadMessages(for: first.peerId, accountKey: cacheKey), !cachedMsgs.isEmpty {
                    self.messages[first.peerId] = cachedMsgs
                }
                Task {
                    await self.fetchHistory(for: first.peerId)
                }
            }
            #endif
        }

        // Setup notification click handler
        NotificationService.shared.onNotificationClicked = { [weak self] peerId in
            self?.selectConversation(peerId)
        }

        // Setup real-time callback
        self.longPoll.onNewMessage = { [weak self] newMsg in
            self?.handleIncomingMessage(newMsg)
        }

        self.longPoll.onUserTyping = { [weak self] userId, peerId in
            guard let self = self else { return }
            self.handleUserTyping(userId: userId, peerId: peerId)
        }

        self.longPoll.onUserStoppedTyping = { [weak self] peerId in
            guard let self = self else { return }
            self.typingUsers.removeValue(forKey: peerId)
        }


        self.longPoll.onPeerUpdated = { [weak self] peerId in
            guard let self = self else { return }
            Task {
                if self.selectedPeerId == peerId {
                    await self.fetchHistory(for: peerId)
                }
                do {
                    let (list, _) = try await self.api.getConversations(offset: 0, count: 50)
                    self.conversations = list
                } catch {
                    print("DEBUG: Failed to refresh conversations: \(error)")
                }
            }
        }

        // Handle outgoing & incoming messages read event (Events 6 & 7)
        self.longPoll.onMessagesRead = { [weak self] peerId, upToId, isOut in
            guard let self = self else { return }
            if var list = self.messages[peerId] {
                var changed = false
                for i in 0..<list.count {
                    if list[i].out == isOut && list[i].id <= upToId {
                        if !list[i].isRead {
                            list[i].isRead = true
                            changed = true
                        }
                    }
                }
                if changed {
                    self.messages[peerId] = list
                }
            }
            if !isOut {
                if let idx = self.conversations.firstIndex(where: { $0.peerId == peerId }) {
                    self.conversations[idx].unreadCount = 0
                }
            }
        }

        // Handle flag reset read event (Event 3)
        self.longPoll.onMessageFlagRead = { [weak self] peerId, msgId in
            guard let self = self else { return }
            if var list = self.messages[peerId] {
                for i in 0..<list.count {
                    if list[i].id == msgId {
                        list[i].isRead = true
                    }
                }
                self.messages[peerId] = list
            }
            if let idx = self.conversations.firstIndex(where: { $0.peerId == peerId }) {
                if self.conversations[idx].unreadCount > 0 {
                    self.conversations[idx].unreadCount -= 1
                }
            }
        }


        self.longPoll.onUserOnlineChanged = { [weak self] uid, isOnline in
            guard let self = self else { return }
            if let idx = self.conversations.firstIndex(where: { $0.peerId == uid }) {
                self.conversations[idx].isOnline = isOnline
            }
        }

        self.longPoll.onConnectionStateChange = { [weak self] isConnected in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !isConnected {
                    if self.connectionStatus != .connecting {
                        self.connectionStatus = .connecting
                    }
                } else {
                    let wasConnecting = (self.connectionStatus == .connecting)
                    if wasConnecting || self.conversations.isEmpty {
                        print("DEBUG: LongPoll connection restored, auto-refreshing...")
                        await self.autoRefreshOnReconnect()
                    } else if !self.isLoading {
                        self.connectionStatus = .connected
                    }
                }
            }
        }

        // Setup network connectivity monitor for auto-reconnect
        self.pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let available = (path.status == .satisfied)
                let wasDisconnected = !self.isNetworkConnected
                self.isNetworkConnected = available

                if !available {
                    self.connectionStatus = .connecting
                } else {
                    let shouldRefresh = wasDisconnected || self.connectionStatus == .connecting || self.conversations.isEmpty
                    if shouldRefresh {
                        print("DEBUG: Network connection restored, auto-refreshing...")
                        await self.autoRefreshOnReconnect()
                    } else if self.connectionStatus != .connecting {
                        self.connectionStatus = .connected
                    }
                }
            }
        }
        self.pathMonitor.start(queue: self.pathMonitorQueue)

        #if canImport(AppKit)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.api.isAuthenticated else { return }
                await self.silentBackgroundRefresh()
            }
        }
        #endif

        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.api.isAuthenticated else { return }
                await self.reEnterAppOnIOS()
            }
        }
        #endif

        Task {
            await self.fetchStickerPacks()
        }

        #if canImport(UIKit)
        if resolvedAPI.isAuthenticated {
            Task {
                await self.reEnterAppOnIOS()
            }
            startPeriodicSync()
        }
        #else
        if resolvedAPI.isAuthenticated {
            Task {
                await self.fetchConversations(silent: true)
            }
            startPeriodicSync()
        }
        #endif
    }

    /// Silent background synchronization when returning to app on macOS (no spinners, no 'Обновление...' banner)
    public func silentBackgroundRefresh() async {
        guard api.isAuthenticated, isNetworkConnected else { return }
        self.longPoll.start()
        await self.fetchConversations(silent: true)
        if let currentPeer = self.selectedPeerId {
            await self.fetchHistory(for: currentPeer)
        }
    }

    /// Telegram-style re-entry on iOS: shows cached chats instantly, displays 'Обновление...' in header bar while pulling fresh updates
    public func reEnterAppOnIOS() async {
        guard api.isAuthenticated else { return }
        guard !isAutoRefreshing else { return }
        isAutoRefreshing = true
        defer {
            isAutoRefreshing = false
            if self.isNetworkConnected {
                self.connectionStatus = .connected
            }
        }

        self.connectionStatus = .updating
        self.longPoll.start()
        await self.fetchConversations(silent: true)
        if let currentPeer = self.selectedPeerId {
            await self.fetchHistory(for: currentPeer)
        }
    }

    public func autoRefreshOnReconnect(showUpdatingStatus: Bool = false) async {
        guard api.isAuthenticated else {
            self.connectionStatus = .connected
            return
        }
        guard !isAutoRefreshing else { return }
        isAutoRefreshing = true
        defer {
            isAutoRefreshing = false
            if self.isNetworkConnected {
                self.connectionStatus = .connected
            }
        }

        if showUpdatingStatus || self.connectionStatus == .connecting {
            self.connectionStatus = .updating
        }
        self.longPoll.start()
        await self.fetchConversations(silent: !showUpdatingStatus)
        if let currentPeer = self.selectedPeerId {
            await self.fetchHistory(for: currentPeer)
        }
    }

    private func startPeriodicSync() {
        pollTimer?.invalidate()
        // Throttled slow fallback (every 45s) to eliminate UI freezing and typing lag while LongPoll handles real-time updates
        pollTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard self.api.isAuthenticated else { return }
                if self.connectionStatus == .connecting {
                    await self.autoRefreshOnReconnect()
                } else if self.connectionStatus != .connected, let peerId = self.selectedPeerId {
                    await self.fetchHistory(for: peerId)
                }
            }
        }
    }

    public func isMuted(peerId: Int) -> Bool {
        mutedPeerIds.contains(peerId)
    }

    public func toggleMute(peerId: Int) {
        if mutedPeerIds.contains(peerId) {
            mutedPeerIds.remove(peerId)
        } else {
            mutedPeerIds.insert(peerId)
        }
        UserDefaults.standard.set(Array(mutedPeerIds), forKey: "openvk_muted_peers")
    }

    public var selectedConversation: VKConversation? {
        guard let id = selectedPeerId else { return nil }
        return conversations.first(where: { $0.peerId == id })
    }

    public var filteredConversations: [VKConversation] {
        conversations(for: selectedFolderId)
    }

    public func conversations(for folderId: UUID?) -> [VKConversation] {
        var result = conversations

        // 0. Filter by community conversations toggle (dialogs with groups, peerId < 0)
        if isCommunityFilterActive && activeAdminGroup == nil {
            result = result.filter { $0.peerId < 0 }
        }

        // 1. Filter by active folder (if a custom folder is selected)
        if let folderId = folderId, let folder = folders.first(where: { $0.id == folderId }) {
            result = result.filter { conv in
                folder.peerIds.contains(conv.peerId)
            }
        }

        // 2. Filter by unread toggle
        if onlyUnread {
            result = result.filter { $0.unreadCount > 0 }
        }

        // 3. Search query
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.lastMessage?.text.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        // 4. Pinning sort: pinned chats stay at the very top!
        let pinned = result.filter { isPinned($0.peerId) }
        let unpinned = result.filter { !isPinned($0.peerId) }
        return pinned + unpinned
    }

    public func unreadCount(for folder: VKChatFolder) -> Int {
        conversations
            .filter { folder.peerIds.contains($0.peerId) }
            .reduce(0) { $0 + $1.unreadCount }
    }

    public var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: - Pinning Actions

    public func isPinned(_ peerId: Int) -> Bool {
        pinnedPeerIds.contains(peerId)
    }

    public func togglePin(_ peerId: Int) {
        if pinnedPeerIds.contains(peerId) {
            pinnedPeerIds.remove(peerId)
        } else {
            pinnedPeerIds.insert(peerId)
        }
        UserDefaults.standard.set(Array(pinnedPeerIds), forKey: "openvk_pinned_peers")
    }

    public func markAsRead(peerId: Int) {
        if let idx = conversations.firstIndex(where: { $0.peerId == peerId }) {
            conversations[idx].unreadCount = 0
            let lastMsgId = conversations[idx].lastMessage?.id ?? 0
            Task {
                await self.api.markAsRead(peerId: peerId, startMessageId: lastMsgId)
            }
        }
    }

    // MARK: - Message Pinning Actions

    public func pinMessage(peerId: Int, messageId: Int) async {
        do {
            let pinned = try await api.pinMessage(peerId: peerId, messageId: messageId)
            if let idx = conversations.firstIndex(where: { $0.peerId == peerId }) {
                conversations[idx].pinnedMessage = pinned
            }
            if var list = messages[peerId] {
                for i in 0..<list.count {
                    if list[i].id == messageId {
                        list[i].isPinned = true
                    } else if list[i].isPinned {
                        list[i].isPinned = false
                    }
                }
                messages[peerId] = list
            }
        } catch {
            print("DEBUG: Failed to pin message: \(error)")
        }
    }

    public func unpinMessage(peerId: Int) async {
        do {
            try await api.unpinMessage(peerId: peerId)
            if let idx = conversations.firstIndex(where: { $0.peerId == peerId }) {
                conversations[idx].pinnedMessage = nil
            }
            if var list = messages[peerId] {
                for i in 0..<list.count {
                    list[i].isPinned = false
                }
                messages[peerId] = list
            }
        } catch {
            print("DEBUG: Failed to unpin message: \(error)")
        }
    }

    // MARK: - Folder Management Actions

    public func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: "openvk_chat_folders")
        }
    }

    public func createFolder(name: String, icon: String = "folder.fill", peerIds: [Int] = []) {
        let newFolder = VKChatFolder(name: name, icon: icon, peerIds: peerIds)
        folders.append(newFolder)
        saveFolders()
    }

    public func updateFolder(_ folder: VKChatFolder) {
        if let idx = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[idx] = folder
            saveFolders()
        }
    }

    public func deleteFolder(id: UUID) {
        folders.removeAll(where: { $0.id == id })
        if selectedFolderId == id {
            selectedFolderId = nil
        }
        saveFolders()
    }

    public func toggleChatInFolder(peerId: Int, folderId: UUID) {
        if let idx = folders.firstIndex(where: { $0.id == folderId }) {
            if folders[idx].peerIds.contains(peerId) {
                folders[idx].peerIds.removeAll(where: { $0 == peerId })
            } else {
                folders[idx].peerIds.append(peerId)
            }
            saveFolders()
        }
    }

    public func isChatInFolder(peerId: Int, folderId: UUID) -> Bool {
        folders.first(where: { $0.id == folderId })?.peerIds.contains(peerId) ?? false
    }

    // MARK: - Multi-Account Management

    public func saveAccounts() {
        if let data = try? JSONEncoder().encode(savedAccounts) {
            UserDefaults.standard.set(data, forKey: "openvk_saved_accounts")
        }
        if let cur = currentAccountId {
            UserDefaults.standard.set(cur, forKey: "openvk_current_account_id")
        }
    }

    public func registerCurrentAccount() {
        guard let u = api.currentUser, !api.token.isEmpty else { return }
        let acc = VKAccount(
            userId: u.id,
            firstName: u.firstName,
            lastName: u.lastName,
            photoURL: u.photoURL,
            token: api.token,
            serverURL: api.serverURL
        )
        if let idx = savedAccounts.firstIndex(where: { $0.id == acc.id }) {
            savedAccounts[idx] = acc
        } else {
            savedAccounts.append(acc)
        }
        self.currentAccountId = acc.id
        saveAccounts()
    }

    public func switchAccount(to account: VKAccount) {
        longPoll.stop()
        self.activeAdminGroup = nil
        self.selectedPeerId = nil
        self.currentAccountId = account.id

        // Instantly load target account cached data
        let cacheKey = account.id
        if let cached = VKChatCache.shared.loadConversations(for: cacheKey), !cached.isEmpty {
            self.conversations = cached
            #if os(macOS)
            if let first = cached.first {
                self.selectedPeerId = first.peerId
                if let diskMsgs = VKChatCache.shared.loadMessages(for: first.peerId, accountKey: cacheKey), !diskMsgs.isEmpty {
                    self.messages[first.peerId] = diskMsgs
                }
            }
            #endif
        } else {
            self.conversations = []
            self.messages = [:]
        }

        api.serverURL = account.serverURL
        api.token = account.token
        api.currentUser = VKUser(
            id: account.userId,
            firstName: account.firstName,
            lastName: account.lastName,
            photo100: account.photoURL?.absoluteString,
            photo200: account.photoURL?.absoluteString
        )
        api.saveCredentials(token: account.token, server: account.serverURL)
        saveAccounts()

        Task {
            _ = try? await api.refreshCurrentUser()
            self.registerCurrentAccount()
            await self.fetchConversations()
            await self.fetchAdministeredGroups()
            self.longPoll.start()
        }
    }

    public func removeAccount(id: String) {
        savedAccounts.removeAll(where: { $0.id == id })
        VKChatCache.shared.clearCache(for: id)
        saveAccounts()
        if currentAccountId == id {
            if let first = savedAccounts.first {
                switchAccount(to: first)
            } else {
                api.logout()
            }
        }
    }

    // MARK: - Community Messages Management

    public func fetchAdministeredGroups() async {
        do {
            let all = try await api.getUserGroups()
            self.userGroups = all
            self.administeredGroups = all.filter { $0.isUserAdmin }
        } catch {
            print("DEBUG: Failed to fetch administered groups: \(error)")
        }
    }

    public func switchToAdminGroup(_ group: VKGroup?) {
        self.activeAdminGroup = group
        self.selectedPeerId = nil
        self.conversations = []
        self.messages = [:]

        Task {
            if let g = group {
                do {
                    let (list, _) = try await api.getConversations(groupId: g.id)
                    self.conversations = list
                } catch {
                    print("DEBUG: Failed to fetch group conversations: \(error)")
                }
            } else {
                await self.fetchConversations()
            }
        }
    }

    // MARK: - Friends & Group Creation

    public func fetchFriends() async {
        guard api.isAuthenticated else { return }
        do {
            let list = try await api.getFriends(count: 200)
            await MainActor.run {
                self.friends = list
            }
        } catch {
            print("DEBUG: Failed to fetch friends: \(error)")
        }
    }

    public func createGroupChat(userIds: [Int], title: String) async -> Int? {
        guard api.isAuthenticated else { return nil }
        do {
            let peerId = try await api.createChat(userIds: userIds, title: title)
            if peerId > 0 {
                await self.fetchConversations()
                self.selectConversation(peerId)
                return peerId
            }
        } catch {
            print("DEBUG: Failed to create group chat: \(error)")
        }
        return nil
    }

    // MARK: - API Data Fetching

    public func fetchConversations(silent: Bool = false) async {
        guard api.isAuthenticated else { return }

        if !silent || conversations.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil
        if !self.isNetworkConnected {
            self.connectionStatus = .connecting
        }

        do {
            let filter = onlyUnread ? "unread" : "all"
            let (list, _) = try await api.getConversations(filter: filter, offset: 0, count: 50, groupId: activeAdminGroup?.id)
            self.conversations = list
            if activeAdminGroup == nil {
                VKChatCache.shared.saveConversations(list, for: self.currentAccountCacheKey)
            }

            #if os(macOS)
            if let first = list.first, selectedPeerId == nil {
                self.selectedPeerId = first.peerId
                if self.messages[first.peerId] == nil {
                    if let diskMsgs = VKChatCache.shared.loadMessages(for: first.peerId, accountKey: self.currentAccountCacheKey) {
                        self.messages[first.peerId] = diskMsgs
                    }
                }
                await self.fetchHistory(for: first.peerId)
            } else if let currentId = selectedPeerId {
                await self.fetchHistory(for: currentId)
            }
            #else
            if let currentId = selectedPeerId {
                await self.fetchHistory(for: currentId)
            }
            #endif

            self.longPoll.start()
            startPeriodicSync()
            if self.connectionStatus != .updating {
                self.connectionStatus = .connected
            }
        } catch {
            self.errorMessage = error.localizedDescription
            print("DEBUG: fetchConversations error: \(error)")
            if !self.isNetworkConnected {
                self.connectionStatus = .connecting
            }
        }

        self.isLoading = false
    }

    public func fetchHistory(for peerId: Int) async {
        guard api.isAuthenticated else { return }
        guard isLoadingHistory[peerId] != true else { return }

        self.isLoadingHistory[peerId] = true
        defer { self.isLoadingHistory[peerId] = false }

        do {
            let history = try await api.getHistory(peerId: peerId, offset: 0, count: 60)
            self.mergeHistory(history, for: peerId)
            if history.count < 40 {
                self.canLoadMoreHistory[peerId] = false
            } else if self.canLoadMoreHistory[peerId] == nil {
                self.canLoadMoreHistory[peerId] = true
            }

            if let cIdx = conversations.firstIndex(where: { $0.peerId == peerId }), conversations[cIdx].pinnedMessage == nil {
                if let pinAction = history.reversed().first(where: { $0.action?.type == "chat_pin_message" }) {
                    let targetId = Int(pinAction.action?.text ?? "") ?? 0
                    if let targetMsg = history.first(where: { $0.id == targetId || ($0.id > 0 && "\($0.id)" == pinAction.action?.text) }) {
                        conversations[cIdx].pinnedMessage = targetMsg
                    }
                }
            }
        } catch {
            print("DEBUG: Failed to fetch history for peer \(peerId): \(error)")
            if self.messages[peerId] == nil {
                if let disk = VKChatCache.shared.loadMessages(for: peerId, accountKey: self.currentAccountCacheKey), !disk.isEmpty {
                    self.messages[peerId] = disk
                }
            }
        }
    }

    public func loadOlderHistory(for peerId: Int) async {
        guard api.isAuthenticated else { return }
        guard isLoadingOlderHistory[peerId] != true else { return }
        guard canLoadMoreHistory[peerId] ?? true else { return }

        self.isLoadingOlderHistory[peerId] = true
        defer { self.isLoadingOlderHistory[peerId] = false }

        let currentRealCount = (messages[peerId] ?? []).filter { $0.id > 0 }.count
        guard currentRealCount > 0 else {
            await self.fetchHistory(for: peerId)
            return
        }

        do {
            let olderHistory = try await api.getHistory(peerId: peerId, offset: currentRealCount, count: 60)
            if olderHistory.isEmpty {
                self.canLoadMoreHistory[peerId] = false
            } else {
                let existingIds = Set((messages[peerId] ?? []).map(\.id))
                let newCount = olderHistory.filter { !existingIds.contains($0.id) }.count
                if newCount == 0 {
                    self.canLoadMoreHistory[peerId] = false
                } else {
                    self.mergeHistory(olderHistory, for: peerId)
                    if olderHistory.count < 30 {
                        self.canLoadMoreHistory[peerId] = false
                    }
                }
            }
        } catch {
            print("DEBUG: Failed to load older history for peer \(peerId): \(error)")
        }
    }

    private func mergeHistory(_ incoming: [VKMessage], for peerId: Int) {
        let existing = self.messages[peerId] ?? []
        if incoming.isEmpty {
            if self.messages[peerId] == nil {
                self.messages[peerId] = []
            }
            return
        }

        var messageMap: [Int: VKMessage] = [:]

        // 1. Put all existing real messages into map
        for msg in existing where msg.id > 0 {
            messageMap[msg.id] = msg
        }

        // 2. Merge incoming messages into map (updating or inserting)
        for var inc in incoming where inc.id > 0 {
            if let ex = messageMap[inc.id] {
                // If it was already marked read locally, keep it read
                if ex.isRead {
                    inc.isRead = true
                }
                // Preserve reply message metadata if incoming is missing it
                if inc.replyMessage == nil {
                    inc.replyMessage = ex.replyMessage
                }
                // Preserve local image preview
                if let exPhoto = ex.photo {
                    if inc.photo == nil {
                        inc.photo = exPhoto
                    } else if let localImg = exPhoto.localImage, inc.photo?.localImage == nil {
                        inc.photo?.localImage = localImg
                    }
                }
                if !ex.photos.isEmpty {
                    if inc.photos.isEmpty {
                        inc.photos = ex.photos
                    } else {
                        for (pIdx, exP) in ex.photos.enumerated() {
                            if pIdx < inc.photos.count, let localImg = exP.localImage, inc.photos[pIdx].localImage == nil {
                                inc.photos[pIdx].localImage = localImg
                            }
                        }
                    }
                }
                // Preserve doc metadata (size, title, url)
                if let exDoc = ex.doc {
                    if inc.doc == nil {
                        inc.doc = exDoc
                    } else {
                        if (inc.doc?.size ?? 0) <= 0 && exDoc.size > 0 {
                            inc.doc?.size = exDoc.size
                        }
                        if (inc.doc?.title.isEmpty != false || inc.doc?.title == "Документ") && !exDoc.title.isEmpty && exDoc.title != "Документ" {
                            inc.doc?.title = exDoc.title
                        }
                        if inc.doc?.url == nil {
                            inc.doc?.url = exDoc.url
                        }
                    }
                }
            }
            if self.selectedPeerId == peerId && !inc.out {
                inc.isRead = true
            }
            messageMap[inc.id] = inc
        }

        var merged = Array(messageMap.values)

        // 3. Keep optimistic/pending messages (id <= 0) and transfer local metadata if matching confirmed incoming message
        for pending in existing where pending.id <= 0 {
            if let incIdx = merged.firstIndex(where: {
                $0.id > 0 && $0.out &&
                (($0.text == pending.text && !pending.text.isEmpty) ||
                 ($0.photo != nil && pending.photo != nil) ||
                 ($0.doc != nil && pending.doc != nil)) &&
                abs($0.date.timeIntervalSince(pending.date)) < 120
            }) {
                // Transfer local preview image
                if let local = pending.photo?.localImage, merged[incIdx].photo?.localImage == nil {
                    merged[incIdx].photo?.localImage = local
                }
                if !pending.photos.isEmpty && merged[incIdx].photos.isEmpty {
                    merged[incIdx].photos = pending.photos
                }
                // Transfer local document metadata (avoids 'Вложение 0 КБ' flash)
                if let pendingDoc = pending.doc {
                    if merged[incIdx].doc == nil {
                        merged[incIdx].doc = pendingDoc
                    } else {
                        if (merged[incIdx].doc?.size ?? 0) <= 0 && pendingDoc.size > 0 {
                            merged[incIdx].doc?.size = pendingDoc.size
                        }
                        if (merged[incIdx].doc?.title.isEmpty != false || merged[incIdx].doc?.title == "Документ") && !pendingDoc.title.isEmpty && pendingDoc.title != "Документ" {
                            merged[incIdx].doc?.title = pendingDoc.title
                        }
                        if merged[incIdx].doc?.url == nil {
                            merged[incIdx].doc?.url = pendingDoc.url
                        }
                    }
                }
            } else {
                merged.append(pending)
            }
        }

        // 4. Sort chronologically
        merged.sort {
            if $0.date == $1.date {
                return $0.id < $1.id
            }
            return $0.date < $1.date
        }

        self.messages[peerId] = merged
        if activeAdminGroup == nil {
            VKChatCache.shared.saveMessages(merged, for: peerId, accountKey: self.currentAccountCacheKey)
        }
    }

    public func selectConversation(_ peerId: Int) {
        self.selectedPeerId = peerId
        if self.messages[peerId] == nil || self.messages[peerId]?.isEmpty == true {
            if let cached = VKChatCache.shared.loadMessages(for: peerId, accountKey: self.currentAccountCacheKey), !cached.isEmpty {
                self.messages[peerId] = cached
            }
        }
        if let idx = conversations.firstIndex(where: { $0.peerId == peerId }) {
            conversations[idx].unreadCount = 0
            conversations[idx].hasUnreadMention = false
        } else if peerId < 0 {
            let gid = abs(peerId)
            if let g = (userGroups + administeredGroups).first(where: { $0.id == gid }) {
                let placeholder = VKConversation(
                    peerId: peerId,
                    title: g.name,
                    avatarURL: g.avatarURL,
                    unreadCount: 0,
                    lastMessage: nil
                )
                conversations.insert(placeholder, at: 0)
            }
        } else if peerId > 0 && peerId < 2_000_000_000 {
            let u = api.cachedUsers[peerId] ?? friends.first(where: { $0.id == peerId })
            let placeholder = VKConversation(
                peerId: peerId,
                title: u?.fullName ?? "Пользователь id\(peerId)",
                avatarURL: u?.avatarURL,
                unreadCount: 0,
                lastMessage: nil,
                isOnline: u?.isOnline ?? false,
                isMobile: u?.isMobileOnline ?? false,
                lastSeen: u?.lastSeen,
                sex: u?.sex
            )
            conversations.insert(placeholder, at: 0)
        }
        if var list = messages[peerId] {
            for i in 0..<list.count {
                if !list[i].out {
                    list[i].isRead = true
                }
            }
            messages[peerId] = list
        }

        if api.isAuthenticated {
            // 1. Fetch chat history immediately so messages load without waiting
            Task {
                await self.fetchHistory(for: peerId)
            }

            // 2. Mark as read & refresh status in parallel
            Task {
                let latestId = self.messages[peerId]?.last?.id ?? self.conversations.first(where: { $0.peerId == peerId })?.lastMessage?.id
                let validId = (latestId ?? 0) > 0 ? latestId : nil
                await self.api.markAsRead(peerId: peerId, startMessageId: validId)

                // Refresh online and lastSeen for direct user dialogs
                if peerId > 0 && peerId < 2_000_000_000 {
                    if let users = try? await self.api.getUsers(ids: [peerId]), let u = users.first {
                        await MainActor.run {
                            if let idx = self.conversations.firstIndex(where: { $0.peerId == peerId }) {
                                self.conversations[idx].isOnline = u.isOnline
                                self.conversations[idx].isMobile = u.isMobileOnline
                                self.conversations[idx].lastSeen = u.lastSeen
                                self.conversations[idx].sex = u.sex
                            }
                        }
                    }
                }
            }
        }
    }

    public func sendMessage(text: String, attachment: String? = nil, replyTo: Int? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let peerId = selectedPeerId else { return }

        // Use attachments from pending uploads if not explicitly specified
        var finalAttachment = attachment
        if finalAttachment == nil {
            let readyCodes = pendingUploads.compactMap { $0.attachmentCode }
            if !readyCodes.isEmpty {
                finalAttachment = readyCodes.joined(separator: ",")
            }
        }

        guard !trimmed.isEmpty || finalAttachment != nil else { return }

        let effectiveReply = replyTo ?? replyingToMessage?.id
        var replyObj: VKReplyMessage? = nil
        if let rep = replyingToMessage {
            replyObj = VKReplyMessage(
                id: rep.id,
                fromId: rep.fromId,
                senderName: rep.sender?.fullName ?? "Пользователь",
                senderAvatarURL: rep.sender?.photoURL,
                date: rep.date,
                text: rep.text,
                photoURL: rep.photo?.url,
                hasPhoto: rep.photo != nil
            )
        }

        // Negative ID represents pending/optimistic message
        let tempId = -Int.random(in: 100000...999999)
        var newMsg = VKMessage(
            id: tempId,
            peerId: peerId,
            fromId: api.currentUser?.id ?? 1,
            date: Date(),
            text: trimmed,
            out: true,
            isRead: false,
            sender: api.currentUser,
            replyMessage: replyObj
        )

        if let att = finalAttachment {
            if att.starts(with: "photo") || att.contains("photo") {
                let localPhotos = pendingUploads.filter { !$0.isDocument }.map { VKPhotoAttachment(id: tempId, url: nil, text: "", localImage: $0.preview) }
                if !localPhotos.isEmpty {
                    newMsg.photos = localPhotos
                    newMsg.photo = localPhotos.first
                }
            } else if att.starts(with: "doc") {
                let firstDoc = pendingUploads.first(where: { $0.isDocument })
                let docName = firstDoc?.filename ?? "Документ"
                let ext = (docName as NSString).pathExtension
                newMsg.doc = VKDocAttachment(
                    id: tempId,
                    title: docName,
                    size: firstDoc?.data.count ?? 0,
                    ext: ext,
                    url: nil
                )
            } else if att.starts(with: "audio") {
                newMsg.audio = VKAudioAttachment(id: tempId, ownerId: 0, artist: "Аудиозапись", title: "Трек", duration: 0, url: nil)
            } else if att.starts(with: "video") {
                newMsg.video = VKVideoAttachment(id: tempId, ownerId: 0, title: "Видеозапись", duration: 0, imageURL: nil)
            }
        }

        if messages[peerId] == nil {
            messages[peerId] = []
        }
        messages[peerId]?.append(newMsg)

        if let idx = conversations.firstIndex(where: { $0.peerId == peerId }) {
            conversations[idx].lastMessage = newMsg
            let conv = conversations.remove(at: idx)
            conversations.insert(conv, at: 0)
        }

        // Clear reply state and pending uploads
        self.replyingToMessage = nil
        self.pendingUploads = []

        if api.isAuthenticated {
            Task {
                do {
                    let msgText = trimmed
                    var params: [String: String] = [
                        "peer_id": "\(peerId)",
                        "message": msgText,
                        "random_id": "\(Int.random(in: 1...2_147_483_647))"
                    ]
                    if let g = self.activeAdminGroup {
                        params["group_id"] = "\(g.id)"
                    }
                    if let att = finalAttachment {
                        params["attachment"] = att
                        params["attachments"] = att
                    }
                    if let rep = effectiveReply {
                        params["reply_to"] = "\(rep)"
                    }
                    let res: VKMessageSendResult = try await self.api.callMethod(method: "messages.send", params: params)

                    if let realId = res.messageId {
                        // Replace temp ID with real ID
                        if var list = self.messages[peerId], let msgIdx = list.firstIndex(where: { $0.id == tempId }) {
                            list[msgIdx].id = realId
                            self.messages[peerId] = list
                        }
                    }

                    // Sync history and conversations
                    await self.fetchHistory(for: peerId)
                    let (list, _) = try await self.api.getConversations(offset: 0, count: 50)
                    self.conversations = list
                } catch {
                    print("DEBUG: Failed to send message via OpenVK: \(error)")
                    if var list = self.messages[peerId], let msgIdx = list.firstIndex(where: { $0.id == tempId }) {
                        list[msgIdx].isFailed = true
                        list[msgIdx].sendError = error.localizedDescription
                        self.messages[peerId] = list
                    }
                }
            }
        }
    }

    public func deleteMessage(peerId: Int, messageId: Int) {
        if var list = messages[peerId] {
            list.removeAll(where: { $0.id == messageId })
            messages[peerId] = list
            if activeAdminGroup == nil {
                VKChatCache.shared.saveMessages(list, for: peerId, accountKey: currentAccountCacheKey)
            }
            if let idx = conversations.firstIndex(where: { $0.peerId == peerId }) {
                if conversations[idx].lastMessage?.id == messageId {
                    conversations[idx].lastMessage = list.last
                }
            }
        }
        Task {
            try? await api.deleteMessage(messageId: messageId)
        }
    }

    public func editMessage(peerId: Int, messageId: Int, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if var list = messages[peerId], let idx = list.firstIndex(where: { $0.id == messageId }) {
            list[idx].text = trimmed
            messages[peerId] = list
            if activeAdminGroup == nil {
                VKChatCache.shared.saveMessages(list, for: peerId, accountKey: currentAccountCacheKey)
            }
            if let cIdx = conversations.firstIndex(where: { $0.peerId == peerId }), conversations[cIdx].lastMessage?.id == messageId {
                conversations[cIdx].lastMessage?.text = trimmed
            }
        }
        Task {
            try? await api.editMessage(peerId: peerId, messageId: messageId, message: trimmed)
        }
    }

    public func startUploadingPhoto(data: Data, preview: PlatformImage, filename: String = "photo.jpg") {
        guard let peerId = selectedPeerId else { return }

        let item = PendingUploadItem(preview: preview, data: data, filename: filename, progress: 0.15, isUploading: true)
        self.pendingUploads.append(item)
        let itemId = item.id

        Task {
            // Smooth progress steps
            try? await Task.sleep(nanoseconds: 150_000_000)
            if let idx = self.pendingUploads.firstIndex(where: { $0.id == itemId }) {
                self.pendingUploads[idx].progress = 0.45
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
            if let idx = self.pendingUploads.firstIndex(where: { $0.id == itemId }) {
                self.pendingUploads[idx].progress = 0.75
            }

            do {
                let code = try await self.api.uploadPhotoAttachment(imageData: data, peerId: peerId, filename: filename)
                print("DEBUG: Photo uploaded successfully! Attachment code: \(code)")
                if let idx = self.pendingUploads.firstIndex(where: { $0.id == itemId }) {
                    self.pendingUploads[idx].progress = 1.0
                    self.pendingUploads[idx].isUploading = false
                    self.pendingUploads[idx].attachmentCode = code
                }
            } catch {
                print("DEBUG: Photo upload failed: \(error)")
                if let idx = self.pendingUploads.firstIndex(where: { $0.id == itemId }) {
                    self.pendingUploads[idx].isUploading = false
                    self.pendingUploads[idx].error = "Ошибка: \(error.localizedDescription)"
                }
            }
        }
    }

    public func startUploadingDocument(data: Data, preview: PlatformImage? = nil, filename: String) {
        guard let peerId = selectedPeerId else { return }

        let resolvedPreview: PlatformImage
        if let p = preview {
            resolvedPreview = p
        } else {
            #if os(macOS)
            resolvedPreview = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil) ?? NSImage()
            #else
            resolvedPreview = UIImage(systemName: "doc.fill") ?? UIImage()
            #endif
        }

        let item = PendingUploadItem(preview: resolvedPreview, data: data, filename: filename, progress: 0.15, isUploading: true, isDocument: true)
        self.pendingUploads.append(item)
        let itemId = item.id

        Task.detached(priority: .userInitiated) { [weak self, data, filename] in
            await Task.yield()
            await MainActor.run {
                if let s = self, let idx = s.pendingUploads.firstIndex(where: { $0.id == itemId }) {
                    s.pendingUploads[idx].progress = 0.40
                }
            }

            do {
                guard let s = self else { return }
                let code = try await s.api.uploadDocumentAttachment(data: data, peerId: peerId, filename: filename)
                print("DEBUG: Document uploaded successfully! Attachment code: \(code)")
                await MainActor.run {
                    if let idx = s.pendingUploads.firstIndex(where: { $0.id == itemId }) {
                        s.pendingUploads[idx].progress = 1.0
                        s.pendingUploads[idx].isUploading = false
                        s.pendingUploads[idx].attachmentCode = code
                        s.pendingUploads[idx].error = nil
                    }
                }
            } catch {
                print("DEBUG: Document upload failed: \(error)")
                await MainActor.run {
                    if let s = self, let idx = s.pendingUploads.firstIndex(where: { $0.id == itemId }) {
                        s.pendingUploads[idx].isUploading = false
                        s.pendingUploads[idx].error = error.localizedDescription
                    }
                }
            }
        }
    }

    public func removePendingUpload(id: UUID) {
        pendingUploads.removeAll(where: { $0.id == id })
    }

    nonisolated public static func convertToJPEGData(image: PlatformImage) -> Data? {
        return image.jpegDataRepresentation(quality: 0.85)
    }

    public static func getClipboardImageData() -> (data: Data, preview: PlatformImage, filename: String)? {
        #if os(macOS)
        let pasteboard = NSPasteboard.general

        // 1. Highest priority: Check if file URLs were copied (e.g. Cmd+C on a .png or .jpg in Finder)
        if let urls = getClipboardFileURLs(), let first = urls.first {
            let ext = first.pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "heic", "webp", "bmp", "gif", "tiff"]
            if imageExtensions.contains(ext),
               let fileData = try? Data(contentsOf: first),
               let img = PlatformImage.from(data: fileData) {
                let jpeg = convertToJPEGData(image: img) ?? fileData
                let cleanName = first.deletingPathExtension().appendingPathExtension("jpg").lastPathComponent
                return (jpeg, img, cleanName)
            }
        }

        // 2. Direct image bytes on clipboard (e.g. screenshots, browser "Copy Image", graphics apps)
        let pngType = NSPasteboard.PasteboardType("public.png")
        if let pngData = pasteboard.data(forType: pngType) ?? pasteboard.data(forType: .png),
           let img = PlatformImage.from(data: pngData) {
            let jpeg = convertToJPEGData(image: img) ?? pngData
            return (jpeg, img, "clipboard.jpg")
        }

        let tiffType = NSPasteboard.PasteboardType.tiff
        if let tiffData = pasteboard.data(forType: tiffType),
           let img = PlatformImage.from(data: tiffData) {
            let jpeg = convertToJPEGData(image: img) ?? tiffData
            return (jpeg, img, "clipboard.jpg")
        }

        // 3. Fallback to NSImage(pasteboard:) only if no file URLs were on pasteboard
        if (getClipboardFileURLs()?.isEmpty ?? true), let image = NSImage(pasteboard: pasteboard) {
            if let jpeg = convertToJPEGData(image: image) {
                return (jpeg, image, "clipboard.jpg")
            }
        }
        #elseif os(iOS)
        if let image = UIPasteboard.general.image,
           let data = image.jpegData(compressionQuality: 0.85) {
            return (data, image, "clipboard.jpg")
        }
        #endif

        return nil
    }

    #if os(macOS)
    public static func getClipboardFileURLs() -> [URL]? {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            return urls
        }
        return nil
    }

    public static func pickLocalImageFiles() -> [(data: Data, filename: String, preview: PlatformImage)] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .gif, .webP]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Выберите изображения для отправки"
        panel.prompt = "Выбрать"
        if panel.runModal() == .OK {
            var results: [(data: Data, filename: String, preview: PlatformImage)] = []
            for url in panel.urls {
                if let fileData = try? Data(contentsOf: url), let img = PlatformImage.from(data: fileData) {
                    let jpeg = convertToJPEGData(image: img) ?? fileData
                    let cleanName = url.deletingPathExtension().appendingPathExtension("jpg").lastPathComponent
                    results.append((jpeg, cleanName, img))
                }
            }
            return results
        }
        return []
    }

    public static func pickLocalImageFile() -> (data: Data, filename: String, preview: PlatformImage)? {
        return pickLocalImageFiles().first
    }
    #endif

    public func fetchChatDetails(for peerId: Int) async {
        guard peerId > 2_000_000_000 else { return }
        isLoadingChatDetails = true
        do {
            let details = try await api.getConversationMembers(peerId: peerId)
            self.activeChatDetails = details
        } catch {
            print("DEBUG: Failed to fetch chat details for peer \(peerId): \(error)")
        }
        isLoadingChatDetails = false
    }

    public func fetchStickerPacks() async {
        let packs = await api.getStickerPacks()
        if !packs.isEmpty {
            self.stickerPacks = packs
            VKStickerCache.shared.saveStickerPacks(packs)
        }
    }

    public func isFavoriteSticker(_ id: Int) -> Bool {
        favoriteStickerIds.contains(id)
    }

    public func toggleFavoriteSticker(_ id: Int) {
        if let idx = favoriteStickerIds.firstIndex(of: id) {
            favoriteStickerIds.remove(at: idx)
        } else {
            favoriteStickerIds.insert(id, at: 0)
        }
        UserDefaults.standard.set(favoriteStickerIds, forKey: "openvk_favorite_stickers")
    }

    public func addRecentSticker(_ id: Int) {
        recentStickerIds.removeAll(where: { $0 == id })
        recentStickerIds.insert(id, at: 0)
        if recentStickerIds.count > 60 {
            recentStickerIds = Array(recentStickerIds.prefix(60))
        }
        UserDefaults.standard.set(recentStickerIds, forKey: "openvk_recent_stickers")
    }

    public func stickerItem(for id: Int) -> VKStickerItem {
        for pack in stickerPacks {
            if let item = pack.stickers.first(where: { $0.id == id }) {
                return item
            }
        }
        let base = api.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let stickerUrl = URL(string: "\(base)/images/stickers/\(id)/256b.png") ?? URL(string: "\(base)/sticker/1-\(id)-256.png") ?? URL(string: "https://vk.com/sticker/1-\(id)-256.png")
        return VKStickerItem(id: id, packId: 0, url: stickerUrl)
    }

    public func sendSticker(stickerId: Int) {
        guard let peerId = selectedPeerId else { return }

        addRecentSticker(stickerId)

        let item = stickerItem(for: stickerId)
        let base = api.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let stickerUrl = item.url ?? URL(string: "\(base)/images/stickers/\(stickerId)/256b.png") ?? URL(string: "\(base)/sticker/1-\(stickerId)-256.png") ?? URL(string: "https://vk.com/sticker/1-\(stickerId)-256.png")

        let tempId = -Int.random(in: 100000...999999)
        let newMsg = VKMessage(
            id: tempId,
            peerId: peerId,
            fromId: api.currentUser?.id ?? 1,
            date: Date(),
            text: "",
            out: true,
            isRead: false,
            sticker: VKSticker(id: stickerId, productId: item.packId > 0 ? item.packId : nil, url: stickerUrl, animationURL: item.animationURL),
            sender: api.currentUser
        )

        if messages[peerId] == nil {
            messages[peerId] = []
        }
        messages[peerId]?.append(newMsg)

        if let idx = conversations.firstIndex(where: { $0.peerId == peerId }) {
            conversations[idx].lastMessage = newMsg
            let conv = conversations.remove(at: idx)
            conversations.insert(conv, at: 0)
        }

        if api.isAuthenticated {
            Task {
                do {
                    let res: VKMessageSendResult = try await self.api.callMethod(method: "messages.send", params: [
                        "peer_id": "\(peerId)",
                        "sticker_id": "\(stickerId)",
                        "random_id": "\(Int.random(in: 1...2_147_483_647))"
                    ])

                    if let realId = res.messageId {
                        if var list = self.messages[peerId], let msgIdx = list.firstIndex(where: { $0.id == tempId }) {
                            list[msgIdx].id = realId
                            self.messages[peerId] = list
                        }
                    }

                    await self.fetchHistory(for: peerId)
                    let (list, _) = try await self.api.getConversations(offset: 0, count: 50)
                    self.conversations = list
                } catch {
                    print("DEBUG: Failed to send sticker via OpenVK: \(error)")
                }
            }
        }
    }

    private func handleIncomingMessage(_ msg: VKMessage) {
        var list = messages[msg.peerId] ?? []

        var messageToAdd = msg
        if selectedPeerId == msg.peerId && !msg.out {
            messageToAdd.isRead = true
        }

        // Resolve sender profile if missing
        if messageToAdd.sender == nil {
            if messageToAdd.out {
                messageToAdd.sender = api.currentUser
            } else if let cached = api.cachedUsers[msg.fromId] {
                messageToAdd.sender = cached
            } else if let conv = conversations.first(where: { $0.peerId == msg.peerId && !$0.isChat }) {
                messageToAdd.sender = VKUser(
                    id: msg.fromId,
                    firstName: conv.title,
                    lastName: "",
                    photo100: conv.avatarURL?.absoluteString,
                    photo200: conv.avatarURL?.absoluteString,
                    online: conv.isOnline ? 1 : 0,
                    onlineMobile: conv.isMobile ? 1 : 0,
                    verified: conv.isVerified ? 1 : 0
                )

            }
        }

        // Clear typing indicator for this sender
        if var tList = typingUsers[msg.peerId] {
            tList.removeAll(where: { $0.id == msg.fromId })
            if tList.isEmpty {
                typingUsers.removeValue(forKey: msg.peerId)
            } else {
                typingUsers[msg.peerId] = tList
            }
        }

        if msg.out {
            if let pendingIdx = list.firstIndex(where: { $0.id <= 0 && ($0.text == msg.text || abs($0.date.timeIntervalSince(msg.date)) < 20) }) {
                if messageToAdd.replyMessage == nil {
                    messageToAdd.replyMessage = list[pendingIdx].replyMessage
                }
                if messageToAdd.photo == nil {
                    messageToAdd.photo = list[pendingIdx].photo
                }
                list[pendingIdx] = messageToAdd
            } else if let existingIdx = list.firstIndex(where: { $0.id == msg.id }) {
                if messageToAdd.replyMessage == nil {
                    messageToAdd.replyMessage = list[existingIdx].replyMessage
                }
                if messageToAdd.photo == nil {
                    messageToAdd.photo = list[existingIdx].photo
                }
                list[existingIdx] = messageToAdd
            } else {
                if messageToAdd.replyMessage == nil, let lastWithReply = list.last(where: { $0.replyMessage != nil && $0.out && abs($0.date.timeIntervalSince(msg.date)) < 20 }) {
                    messageToAdd.replyMessage = lastWithReply.replyMessage
                }
                list.append(messageToAdd)
            }
        } else {
            if let existingIdx = list.firstIndex(where: { $0.id == msg.id }) {
                if messageToAdd.replyMessage == nil {
                    messageToAdd.replyMessage = list[existingIdx].replyMessage
                }
                if messageToAdd.photo == nil {
                    messageToAdd.photo = list[existingIdx].photo
                }
                list[existingIdx] = messageToAdd
            } else {
                list.append(messageToAdd)
            }
        }

        list.sort { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
        messages[msg.peerId] = list
        if activeAdminGroup == nil {
            VKChatCache.shared.saveMessages(list, for: msg.peerId, accountKey: self.currentAccountCacheKey)
        }

        // Update pinned message state on pin/unpin service events
        if let act = messageToAdd.action {
            if act.type == "chat_unpin_message" {
                if let cIdx = conversations.firstIndex(where: { $0.peerId == msg.peerId }) {
                    conversations[cIdx].pinnedMessage = nil
                }
            } else if act.type == "chat_pin_message" {
                let targetId = Int(act.text ?? "") ?? 0
                if let found = list.first(where: { $0.id == targetId || ($0.id > 0 && "\($0.id)" == act.text) }) {
                    if let cIdx = conversations.firstIndex(where: { $0.peerId == msg.peerId }) {
                        conversations[cIdx].pinnedMessage = found
                    }
                } else {
                    Task {
                        let (convList, _) = (try? await self.api.getConversations(offset: 0, count: 50)) ?? ([], 0)
                        if let fresh = convList.first(where: { $0.peerId == msg.peerId }), let p = fresh.pinnedMessage {
                            if let cIdx = self.conversations.firstIndex(where: { $0.peerId == msg.peerId }) {
                                self.conversations[cIdx].pinnedMessage = p
                            }
                        }
                    }
                }
            }
        }

        if let idx = conversations.firstIndex(where: { $0.peerId == msg.peerId }) {
            conversations[idx].lastMessage = messageToAdd

            let myId = api.currentUser?.id ?? 0
            let isMention = myId > 0 && (messageToAdd.text.contains("[id\(myId)|") || messageToAdd.text.contains("@id\(myId)"))

            if selectedPeerId == msg.peerId {
                conversations[idx].unreadCount = 0
                conversations[idx].hasUnreadMention = false
                if !msg.out {
                    Task {
                        await self.api.markAsRead(peerId: msg.peerId, startMessageId: msg.id)
                    }
                }
            } else {
                if !msg.out {
                    conversations[idx].unreadCount += 1
                    if isMention {
                        conversations[idx].hasUnreadMention = true
                    }
                }
            }

            if !msg.out {
                let isGiftOrTransfer = messageToAdd.gift != nil || messageToAdd.moneyTransfer != nil ||
                    messageToAdd.text.lowercased().contains("подарок") ||
                    messageToAdd.text.lowercased().contains("голос")
                #if os(macOS)
                let shouldNotify = isGiftOrTransfer || (selectedPeerId != msg.peerId || !NSApp.isActive || AudioPlayerService.shared.isPlaying)
                #else
                let shouldNotify = isGiftOrTransfer || (selectedPeerId != msg.peerId || AudioPlayerService.shared.isPlaying)
                #endif
                if shouldNotify && !isMuted(peerId: msg.peerId) {
                    let conv = conversations[idx]
                    NotificationService.shared.postNotification(for: messageToAdd, conversation: conv)
                }
            }

            let conv = conversations.remove(at: idx)
            conversations.insert(conv, at: 0)
            if activeAdminGroup == nil {
                VKChatCache.shared.saveConversations(conversations, for: self.currentAccountCacheKey)
            }
        }

        // If sender user isn't cached yet, fetch in background
        if api.cachedUsers[msg.fromId] == nil && msg.fromId > 0 && !msg.out {
            Task {
                if let users = try? await self.api.getUsers(ids: [msg.fromId]), let first = users.first {
                    if var curList = self.messages[msg.peerId] {
                        for i in 0..<curList.count {
                            if curList[i].fromId == msg.fromId && curList[i].sender == nil {
                                curList[i].sender = first
                            }
                        }
                        self.messages[msg.peerId] = curList
                    }
                    if let cIdx = self.conversations.firstIndex(where: { $0.peerId == msg.peerId }) {
                        if self.conversations[cIdx].lastMessage?.fromId == msg.fromId {
                            self.conversations[cIdx].lastMessage?.sender = first
                        }
                    }
                }
            }
        }
    }

    // MARK: - Typing Indicator Management

    public func handleUserTyping(userId: Int, peerId: Int) {
        var resolvedName = ""
        if let cached = api.cachedUsers[userId] {
            resolvedName = cached.firstName.isEmpty ? cached.fullName : cached.firstName
        } else if let conv = conversations.first(where: { $0.peerId == peerId && !$0.isChat }) {
            resolvedName = conv.title.split(separator: " ").first.map(String.init) ?? conv.title
        }

        var current = typingUsers[peerId] ?? []
        if let idx = current.firstIndex(where: { $0.id == userId }) {
            current[idx].date = Date()
            if !resolvedName.isEmpty {
                current[idx].name = resolvedName
            }
        } else {
            current.append(TypingUser(id: userId, name: resolvedName.isEmpty ? "Собеседник" : resolvedName))
        }
        typingUsers[peerId] = current

        // Resolve user if not in cache
        if api.cachedUsers[userId] == nil && userId > 0 {
            Task {
                if let users = try? await self.api.getUsers(ids: [userId]), let first = users.first {
                    let uName = first.firstName.isEmpty ? first.fullName : first.firstName
                    if var list = self.typingUsers[peerId], let i = list.firstIndex(where: { $0.id == userId }) {
                        list[i].name = uName
                        self.typingUsers[peerId] = list
                    }
                }
            }
        }

        // Auto-expire after 6 seconds
        let timerKey = "\(peerId)_\(userId)"
        typingExpiryTimers[timerKey]?.invalidate()
        typingExpiryTimers[timerKey] = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if var list = self.typingUsers[peerId] {
                    list.removeAll(where: { $0.id == userId })
                    if list.isEmpty {
                        self.typingUsers.removeValue(forKey: peerId)
                    } else {
                        self.typingUsers[peerId] = list
                    }
                }
            }
        }
    }

    public func typingStatus(for peerId: Int) -> String? {
        guard let users = typingUsers[peerId], !users.isEmpty else { return nil }
        let isGroup = peerId > 2_000_000_000

        if isGroup {
            let names = users.map(\.name).filter { !$0.isEmpty }
            if names.count == 1 {
                return "\(names[0]) печатает..."
            } else if names.count == 2 {
                return "\(names[0]) и \(names[1]) печатают..."
            } else if names.count > 2 {
                return "\(names[0]) и ещё \(names.count - 1) печатают..."
            } else {
                return "кто-то печатает..."
            }
        } else {
            return "печатает..."
        }
    }

    public func sendTypingActivity() {
        guard let peerId = selectedPeerId, api.isAuthenticated else { return }
        guard Date().timeIntervalSince(lastTypingSentDate) > 4.5 else { return }
        lastTypingSentDate = Date()
        Task {
            await self.api.setActivity(peerId: peerId, type: "typing")
        }
    }

    // MARK: - In-Conversation Message Search

    public func searchMessagesInCurrentConversation(query: String) async -> [VKMessage] {
        guard let peerId = selectedPeerId else {
            self.messageSearchResults = []
            return []
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.messageSearchResults = []
            self.currentSearchMatchIndex = 0
            return []
        }

        self.isSearchingMessages = true
        defer { self.isSearchingMessages = false }

        // Local search across loaded messages in memory
        let localMatches: [VKMessage] = (messages[peerId] ?? []).filter { msg in
            msg.text.localizedCaseInsensitiveContains(trimmed) ||
            (msg.photo?.text.localizedCaseInsensitiveContains(trimmed) == true) ||
            (msg.video?.title.localizedCaseInsensitiveContains(trimmed) == true) ||
            (msg.doc?.title.localizedCaseInsensitiveContains(trimmed) == true) ||
            (msg.audio?.title.localizedCaseInsensitiveContains(trimmed) == true) ||
            (msg.audio?.artist.localizedCaseInsensitiveContains(trimmed) == true)
        }

        do {
            let serverResults = try await api.searchMessages(query: trimmed, peerId: peerId, count: 50)
            var combined = localMatches
            for sMsg in serverResults {
                if !combined.contains(where: { $0.id == sMsg.id }) {
                    combined.append(sMsg)
                }
            }
            combined.sort(by: { $0.id < $1.id })
            self.messageSearchResults = combined
            if self.currentSearchMatchIndex >= combined.count {
                self.currentSearchMatchIndex = max(0, combined.count - 1)
            }
            return combined
        } catch {
            self.messageSearchResults = localMatches
            if self.currentSearchMatchIndex >= localMatches.count {
                self.currentSearchMatchIndex = max(0, localMatches.count - 1)
            }
            return localMatches
        }
    }

    public func ensureMessageLoadedInCurrentConversation(_ message: VKMessage) {
        guard let peerId = selectedPeerId else { return }
        var currentList = messages[peerId] ?? []
        if !currentList.contains(where: { $0.id == message.id }) {
            currentList.append(message)
            currentList.sort(by: { $0.id < $1.id })
            messages[peerId] = currentList
        }
    }
}

public struct TypingUser: Identifiable, Hashable {
    public let id: Int
    public var name: String
    public var date: Date

    public init(id: Int, name: String, date: Date = Date()) {
        self.id = id
        self.name = name
        self.date = date
    }
}

