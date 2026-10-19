import SwiftUI

public struct ChatFoldersSidebarView: View {
    @ObservedObject var store: MessengerStore
    @ObservedObject private var theme = ThemeManager.shared
    @State private var showFolderManager: Bool = false
    @State private var showAccountBank: Bool = false
    @State private var showCommunityManager: Bool = false
    @State private var editingFolder: VKChatFolder? = nil

    public init(store: MessengerStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top spacing
            Color.clear
                .frame(height: 8)

            // Scrollable list of folders
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    // 1. "All Chats" item
                    folderItemButton(
                        id: nil,
                        name: "All Chats",
                        icon: "bubble.left.and.bubble.right.fill",
                        badgeCount: store.totalUnreadCount,
                        isSelected: store.selectedFolderId == nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.selectedFolderId = nil
                        }
                    }

                    // 2. Custom User Folders
                    ForEach(store.folders) { folder in
                        folderItemButton(
                            id: folder.id,
                            name: folder.name,
                            icon: folder.icon,
                            badgeCount: store.unreadCount(for: folder),
                            isSelected: store.selectedFolderId == folder.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.selectedFolderId = folder.id
                            }
                        }
                        .contextMenu {
                            Button(action: {
                                editingFolder = folder
                                showFolderManager = true
                            }) {
                                Label("Редактировать папку", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive, action: {
                                withAnimation {
                                    store.deleteFolder(id: folder.id)
                                }
                            }) {
                                Label("Удалить папку", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
            }

            Spacer(minLength: 0)

            Divider()
                .background(VKColors.separator.opacity(0.6))

            // Bottom Actions Dock (Communities, Settings, Multi-Account Bank)
            VStack(spacing: 6) {
                // 1. Community Messages Button
                Button(action: {
                    showCommunityManager = true
                }) {
                    VStack(spacing: 2) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: store.activeAdminGroup != nil ? "building.2.crop.circle.fill" : "building.2.fill")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(store.activeAdminGroup != nil || store.isCommunityFilterActive ? VKColors.accent : VKColors.textSecondary)
                                .frame(width: 36, height: 26)

                            if store.activeAdminGroup != nil {
                                Circle()
                                    .fill(VKColors.onlineGreen)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 4, y: -1)
                            }
                        }

                        Text("Группы")
                            .font(.system(size: 9.5, weight: store.activeAdminGroup != nil ? .semibold : .regular))
                            .foregroundColor(store.activeAdminGroup != nil || store.isCommunityFilterActive ? VKColors.accent : VKColors.textSecondary)
                    }
                    .frame(width: 56, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(store.activeAdminGroup != nil ? "Управление сообществом: \(store.activeAdminGroup?.name ?? "")" : "Сообщения сообществ")

                // 2. Folder Settings Button
                Button(action: {
                    editingFolder = nil
                    showFolderManager = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(VKColors.textSecondary)
                        .frame(width: 44, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Управление папками")

                // 3. Multi-Account Bank (User Avatar button)
                Button(action: {
                    showAccountBank = true
                }) {
                    ZStack(alignment: .bottomTrailing) {
                        VKAvatarView(
                            url: store.api.currentUser?.photoURL,
                            name: store.api.currentUser?.fullName ?? "OpenVK",
                            size: 34
                        )

                        Circle()
                            .fill(VKColors.onlineGreen)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(foldersSidebarBackground, lineWidth: 1.5))
                            .offset(x: 1, y: 1)
                    }
                    .frame(width: 44, height: 38)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Банк аккаунтов (\(store.api.currentUser?.fullName ?? "Вы"))")
            }
            .padding(.vertical, 8)
        }
        .frame(width: 68)
        .frame(maxHeight: .infinity)
        .background(foldersSidebarBackground)
        .sheet(isPresented: $showFolderManager) {
            FolderManagerModalView(store: store, initialFolder: editingFolder)
        }
        .sheet(isPresented: $showAccountBank) {
            AccountBankModalView(store: store)
        }
        .sheet(isPresented: $showCommunityManager) {
            CommunityMessagesModalView(store: store)
        }
    }

    @ViewBuilder
    private func folderItemButton(
        id: UUID?,
        name: String,
        icon: String,
        badgeCount: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundColor(isSelected ? .white : VKColors.textSecondary)
                        .frame(width: 38, height: 32)

                    // Unread Badge Bubble (Telegram style blue circle)
                    if badgeCount > 0 {
                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.35) : VKColors.accent)
                            )
                            .offset(x: 10, y: -2)
                    }
                }

                // Folder Title
                Text(name)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : VKColors.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 58)
            }
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? VKColors.accent : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
    }

    private var foldersSidebarBackground: Color {
        theme.foldersSidebarBackgroundColor
    }
}
