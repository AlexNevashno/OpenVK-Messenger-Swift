import SwiftUI

public struct ConversationsSidebarView: View {
    @ObservedObject var store: MessengerStore
    @ObservedObject private var theme = ThemeManager.shared
    @Binding var showSettings: Bool
    @Binding var showLogin: Bool
    @State private var showNewMessageModal: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            // Header: Search + Compose + Actions
            HStack(spacing: 8) {
                VKSearchField(text: $store.searchQuery, placeholder: "Поиск")

                // Написать (Compose) Button
                Button(action: {
                    showNewMessageModal = true
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VKColors.accent)
                        .frame(width: 26, height: 26)
                        .background(VKColors.accent.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Написать сообщение")

                // Refresh Button
                if store.isLoading || store.connectionStatus == .updating {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 20, height: 20)
                } else {
                    Button(action: {
                        Task { await store.fetchConversations() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(VKColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Обновить диалоги")
                }

                // Options Menu
                Menu {
                    if store.api.isAuthenticated {
                        Section("Аккаунт: \(store.api.currentUser?.fullName ?? "OpenVK")") {
                            Button("Обновить диалоги") {
                                Task { await store.fetchConversations() }
                            }
                            Button("Выйти из аккаунта") {
                                store.api.logout()
                                showLogin = true
                            }
                        }
                    } else {
                        Button("Войти в OpenVK...") {
                            showLogin = true
                        }
                    }

                    Divider()

                    Button("Настройки сервера...") {
                        showSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(VKColors.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
                .help("Меню")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(VKColors.surface)

            Divider()
                .background(VKColors.separator)

            // Network Connectivity Banner (Telegram / VK style)
            if store.connectionStatus == .connecting {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Соединение...")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(VKColors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4.5)
                .background(VKColors.secondarySurface.opacity(0.8))
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if store.connectionStatus == .updating {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Обновление...")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(VKColors.accent)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4.5)
                .background(VKColors.accent.opacity(0.08))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Active Filter Banner
            if let activeGroup = store.activeAdminGroup {
                HStack(spacing: 8) {
                    VKAvatarView(url: activeGroup.avatarURL, name: activeGroup.name, size: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("От имени сообщества")
                            .font(.system(size: 9))
                            .foregroundColor(VKColors.textSecondary)
                        Text(activeGroup.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(VKColors.accent)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(action: {
                        store.switchToAdminGroup(nil)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(VKColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Выйти из режима управления")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(VKColors.accent.opacity(0.12))
                .cornerRadius(7)
                .padding(.horizontal, 10)
                .padding(.top, 6)
            } else if store.isCommunityFilterActive {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(VKColors.accent)
                    Text("Только сообщества")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(VKColors.textPrimary)
                    Spacer()
                    Button(action: {
                        store.isCommunityFilterActive = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(VKColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Показать все диалоги")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(VKColors.accent.opacity(0.12))
                .cornerRadius(7)
                .padding(.horizontal, 10)
                .padding(.top, 6)
            }

            // Conversations List
            ScrollView {
                LazyVStack(spacing: 2) {
                    if store.filteredConversations.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 28))
                                .foregroundColor(VKColors.textSecondary)
                            Text(store.isLoading ? "Загрузка диалогов..." : "Нет диалогов")
                                .font(VKTypography.subhead)
                                .foregroundColor(VKColors.textSecondary)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(store.filteredConversations) { conv in
                            Button(action: {
                                store.selectConversation(conv.peerId)
                            }) {
                                ConversationRowView(
                                    conversation: conv,
                                    isSelected: store.selectedPeerId == conv.peerId,
                                    isPinned: store.isPinned(conv.peerId),
                                    typingText: store.typingStatus(for: conv.peerId)
                                )
                                .id(conv.peerId)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(action: {
                                    store.togglePin(conv.peerId)
                                }) {
                                    Label(
                                        store.isPinned(conv.peerId) ? "Открепить чат" : "Закрепить чат",
                                        systemImage: store.isPinned(conv.peerId) ? "pin.slash" : "pin"
                                    )
                                }

                                Button(action: {
                                    store.toggleMute(peerId: conv.peerId)
                                }) {
                                    Label(
                                        store.isMuted(peerId: conv.peerId) ? "Включить звук" : "Без звука",
                                        systemImage: store.isMuted(peerId: conv.peerId) ? "bell.fill" : "bell.slash"
                                    )
                                }

                                if !store.folders.isEmpty {
                                    Menu {
                                        ForEach(store.folders) { folder in
                                            let isIn = store.isChatInFolder(peerId: conv.peerId, folderId: folder.id)
                                            Button(action: {
                                                store.toggleChatInFolder(peerId: conv.peerId, folderId: folder.id)
                                            }) {
                                                HStack {
                                                    Text(folder.name)
                                                    if isIn {
                                                        Spacer()
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Папки", systemImage: "folder")
                                    }
                                }

                                Divider()

                                Button(action: {
                                    Task {
                                        await store.api.markAsRead(peerId: conv.peerId)
                                        if let idx = store.conversations.firstIndex(where: { $0.peerId == conv.peerId }) {
                                            store.conversations[idx].unreadCount = 0
                                        }
                                    }
                                }) {
                                    Label("Прочитано", systemImage: "envelope.open")
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            }
            .background(VKColors.surface)

            Divider()
                .background(VKColors.separator)

            // Bottom Filter Bar: "Только непрочитанные"
            HStack {
                Text("Только непрочитанные")
                    .font(VKTypography.subhead)
                    .foregroundColor(VKColors.textSecondary)

                Spacer()

                Toggle("", isOn: $store.onlyUnread)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(VKColors.surface)
        }
        #if os(macOS)
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
        #endif
        .frame(maxHeight: .infinity)
        .background(VKColors.surface)
        .sheet(isPresented: $showNewMessageModal) {
            NewMessageModalView(store: store)
        }
    }
}
