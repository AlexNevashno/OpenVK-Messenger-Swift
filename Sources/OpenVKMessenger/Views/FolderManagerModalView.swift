import SwiftUI

public struct FolderManagerModalView: View {
    @ObservedObject var store: MessengerStore
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingOrEditing: Bool = false
    @State private var editingId: UUID? = nil
    @State private var folderName: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedPeerIds: Set<Int> = []
    @State private var chatSearchQuery: String = ""

    public let availableIcons: [String] = [
        "folder.fill",
        "person.fill",
        "bubble.left.and.bubble.right.fill",
        "briefcase.fill",
        "star.fill",
        "heart.fill",
        "gamecontroller.fill",
        "music.note",
        "film.fill",
        "newspaper.fill",
        "tag.fill",
        "bell.fill"
    ]

    public init(store: MessengerStore, initialFolder: VKChatFolder? = nil) {
        self.store = store
        if let folder = initialFolder {
            self._isCreatingOrEditing = State(initialValue: true)
            self._editingId = State(initialValue: folder.id)
            self._folderName = State(initialValue: folder.name)
            self._selectedIcon = State(initialValue: folder.icon)
            self._selectedPeerIds = State(initialValue: Set(folder.peerIds))
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isCreatingOrEditing ? (editingId != nil ? "Редактировать папку" : "Новая папка") : "Папки с чатами")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(VKColors.textPrimary)

                Spacer()

                Button(action: {
                    if isCreatingOrEditing {
                        isCreatingOrEditing = false
                        editingId = nil
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(VKColors.textSecondary)
                        .padding(6)
                        .background(VKColors.secondarySurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .background(VKColors.separator)

            if isCreatingOrEditing {
                folderEditView
            } else {
                folderListView
            }
        }
        #if os(macOS)
        .frame(width: 480, height: 520)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .background(VKColors.surface)
    }

    // MARK: - Folder List View
    private var folderListView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    if store.folders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(VKColors.textSecondary)
                            Text("У вас пока нет папок")
                                .font(VKTypography.headline)
                                .foregroundColor(VKColors.textPrimary)
                            Text("Создайте папки для организации чатов: Личные, Работа, Беседы и т.д.")
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        .padding(.top, 50)
                    } else {
                        ForEach(store.folders) { folder in
                            HStack(spacing: 12) {
                                Image(systemName: folder.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(VKColors.accent)
                                    .frame(width: 32, height: 32)
                                    .background(VKColors.secondarySurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.name)
                                        .font(VKTypography.headline)
                                        .foregroundColor(VKColors.textPrimary)

                                    Text("\(folder.peerIds.count) чатов")
                                        .font(VKTypography.caption)
                                        .foregroundColor(VKColors.textSecondary)
                                }

                                Spacer()

                                Button(action: {
                                    editingId = folder.id
                                    folderName = folder.name
                                    selectedIcon = folder.icon
                                    selectedPeerIds = Set(folder.peerIds)
                                    isCreatingOrEditing = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 13))
                                        .foregroundColor(VKColors.textSecondary)
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                                .help("Редактировать")

                                Button(action: {
                                    withAnimation {
                                        store.deleteFolder(id: folder.id)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                        .foregroundColor(.red.opacity(0.85))
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                                .help("Удалить")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(VKColors.secondarySurface.opacity(0.5))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(18)
            }

            Divider()

            HStack {
                Spacer()

                Button(action: {
                    editingId = nil
                    folderName = ""
                    selectedIcon = "folder.fill"
                    selectedPeerIds = []
                    isCreatingOrEditing = true
                }) {
                    Label("Создать папку", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(VKColors.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Folder Edit View
    private var folderEditView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Название папки:")
                            .font(VKTypography.caption)
                            .foregroundColor(VKColors.textSecondary)

                        TextField("Например: Работа, Друзья...", text: $folderName)
                            .textFieldStyle(.roundedBorder)
                            .font(VKTypography.body)
                    }

                    // Icon Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Иконка:")
                            .font(VKTypography.caption)
                            .foregroundColor(VKColors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(availableIcons, id: \.self) { iconName in
                                    Button(action: {
                                        selectedIcon = iconName
                                    }) {
                                        Image(systemName: iconName)
                                            .font(.system(size: 18))
                                            .foregroundColor(selectedIcon == iconName ? .white : VKColors.textSecondary)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedIcon == iconName ? VKColors.accent : VKColors.secondarySurface)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Divider()

                    // Chat Selection Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Включённые чаты (\(selectedPeerIds.count)):")
                                .font(VKTypography.headline)
                                .foregroundColor(VKColors.textPrimary)

                            Spacer()
                        }

                        // Search chats
                        VKSearchField(text: $chatSearchQuery, placeholder: "Поиск чатов для добавления")

                        VStack(spacing: 4) {
                            ForEach(filteredDialogs) { conv in
                                let isIncluded = selectedPeerIds.contains(conv.peerId)
                                Button(action: {
                                    if isIncluded {
                                        selectedPeerIds.remove(conv.peerId)
                                    } else {
                                        selectedPeerIds.insert(conv.peerId)
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        VKAvatarView(url: conv.avatarURL, name: conv.displayTitle, size: 28)

                                        Text(conv.displayTitle)
                                            .font(VKTypography.body)
                                            .foregroundColor(VKColors.textPrimary)
                                            .lineLimit(1)

                                        Spacer()

                                        Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundColor(isIncluded ? VKColors.accent : VKColors.textSecondary.opacity(0.4))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isIncluded ? VKColors.accent.opacity(0.08) : Color.clear)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Отмена") {
                    isCreatingOrEditing = false
                }
                .buttonStyle(.plain)
                .foregroundColor(VKColors.textSecondary)

                Spacer()

                Button("Сохранить папку") {
                    saveFolder()
                }
                .buttonStyle(.borderedProminent)
                .tint(VKColors.accent)
                .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var filteredDialogs: [VKConversation] {
        if chatSearchQuery.isEmpty {
            return store.conversations
        }
        return store.conversations.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(chatSearchQuery)
        }
    }

    private func saveFolder() {
        let trimmed = folderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let id = editingId {
            let updated = VKChatFolder(id: id, name: trimmed, icon: selectedIcon, peerIds: Array(selectedPeerIds))
            store.updateFolder(updated)
        } else {
            store.createFolder(name: trimmed, icon: selectedIcon, peerIds: Array(selectedPeerIds))
        }

        isCreatingOrEditing = false
        editingId = nil
    }
}
