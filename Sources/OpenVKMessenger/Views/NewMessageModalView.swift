import SwiftUI

public struct NewMessageModalView: View {
    @ObservedObject var store: MessengerStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var isCreatingGroup: Bool = false
    @State private var groupTitle: String = ""
    @State private var selectedUserIds: Set<Int> = []
    @State private var searchResults: [VKUser] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil

    public init(store: MessengerStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().background(VKColors.separator)

            if isCreatingGroup {
                groupCreationHeaderView
                Divider().background(VKColors.separator)
            } else {
                // Search Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(VKColors.textSecondary)
                        .font(.system(size: 13))

                    TextField("Поиск друзей или ID (например, id1)...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onChange(of: searchText) { _ in
                            performSearch(query: searchText)
                        }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(VKColors.textSecondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(VKColors.secondarySurface)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            // Direct ID Quick Action
            if let directId = parseDirectId(searchText), !isCreatingGroup {
                Button(action: {
                    store.selectConversation(directId)
                    dismiss()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13))
                            .foregroundColor(VKColors.accent)
                            .frame(width: 32, height: 32)
                            .background(VKColors.accent.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Написать пользователю id\(directId)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(VKColors.accent)
                            Text("Открыть диалог напрямую по идентификатору")
                                .font(.system(size: 11))
                                .foregroundColor(VKColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(VKColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(VKColors.surface)
                }
                .buttonStyle(.plain)

                Divider().background(VKColors.separator)
            }

            // Create Group Toggle Button (when not in group creation mode and not searching)
            if !isCreatingGroup && searchText.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCreatingGroup = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 13))
                            .foregroundColor(VKColors.accent)
                            .frame(width: 32, height: 32)
                            .background(VKColors.accent.opacity(0.12))
                            .clipShape(Circle())

                        Text("Создать беседу")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(VKColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(VKColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Divider().background(VKColors.separator)
            }

            // Users List
            usersListView
        }
        #if os(macOS)
        .frame(width: 420, height: 530)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .background(VKColors.surface)
        .task {
            if store.friends.isEmpty {
                await store.fetchFriends()
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            if isCreatingGroup {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCreatingGroup = false
                        selectedUserIds.removeAll()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Назад")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(VKColors.accent)
                }
                .buttonStyle(.plain)
            }

            Text(isCreatingGroup ? "Новая беседа" : "Новое сообщение")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(VKColors.textPrimary)

            Spacer()

            if isCreatingGroup {
                Button(action: createGroupAction) {
                    Text("Создать")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(!groupTitle.trimmingCharacters(in: .whitespaces).isEmpty && !selectedUserIds.isEmpty ? VKColors.accent : Color.gray.opacity(0.5))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(groupTitle.trimmingCharacters(in: .whitespaces).isEmpty || selectedUserIds.isEmpty)
            } else {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(VKColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Group Creation Header View
    private var groupCreationHeaderView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(VKColors.accent)
                    .font(.system(size: 13))

                TextField("Название беседы...", text: $groupTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VKColors.secondarySurface)
            .cornerRadius(8)

            HStack {
                Text("Выберите участников (\(selectedUserIds.count)):")
                    .font(.system(size: 11))
                    .foregroundColor(VKColors.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Users List View
    private var usersListView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 2) {
                let displayedUsers = currentDisplayedUsers

                if displayedUsers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: isSearching ? "magnifyingglass" : "person.2")
                            .font(.system(size: 28))
                            .foregroundColor(VKColors.textSecondary.opacity(0.5))
                        Text(isSearching ? "Поиск..." : (searchText.isEmpty ? "Список друзей пуст" : "Пользователи не найдены"))
                            .font(.system(size: 13))
                            .foregroundColor(VKColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(displayedUsers) { user in
                        userRow(user: user)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var currentDisplayedUsers: [VKUser] {
        if !searchText.isEmpty {
            if !searchResults.isEmpty {
                return searchResults
            }
            // Filter local friends by name
            let q = searchText.lowercased()
            return store.friends.filter { $0.fullName.lowercased().contains(q) }
        }
        return store.friends
    }

    // MARK: - User Row
    private func userRow(user: VKUser) -> some View {
        Button(action: {
            if isCreatingGroup {
                if selectedUserIds.contains(user.id) {
                    selectedUserIds.remove(user.id)
                } else {
                    selectedUserIds.insert(user.id)
                }
            } else {
                store.selectConversation(user.id)
                dismiss()
            }
        }) {
            HStack(spacing: 10) {
                // Avatar with online status
                ZStack(alignment: .bottomTrailing) {
                    VKAvatarView(url: user.avatarURL, name: user.fullName, size: 36)

                    if user.isOnline {
                        Circle()
                            .fill(VKColors.onlineGreen)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(VKColors.surface, lineWidth: 1.5))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(user.fullName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(VKColors.textPrimary)
                            .lineLimit(1)

                        if user.isVerified {
                            VKVerifiedBadge()
                        }
                    }

                    Text(user.isOnline ? "В сети" : "id\(user.id)")
                        .font(.system(size: 11))
                        .foregroundColor(user.isOnline ? VKColors.accent : VKColors.textSecondary)
                }

                Spacer()

                if isCreatingGroup {
                    Image(systemName: selectedUserIds.contains(user.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(selectedUserIds.contains(user.id) ? VKColors.accent : VKColors.textSecondary)
                } else {
                    Image(systemName: "message.fill")
                        .font(.system(size: 12))
                        .foregroundColor(VKColors.textSecondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isCreatingGroup && selectedUserIds.contains(user.id) ? VKColors.accent.opacity(0.08) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions
    private func performSearch(query: String) {
        searchTask?.cancel()
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            isSearching = true
            if let results = try? await store.api.searchUsers(query: clean) {
                guard !Task.isCancelled else { return }
                self.searchResults = results
            }
            self.isSearching = false
        }
    }

    private func parseDirectId(_ text: String) -> Int? {
        let clean = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.starts(with: "id") {
            let numStr = String(clean.dropFirst(2))
            return Int(numStr)
        }
        if let intVal = Int(clean), intVal > 0 {
            return intVal
        }
        return nil
    }

    private func createGroupAction() {
        let title = groupTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !selectedUserIds.isEmpty else { return }

        Task {
            if let _ = await store.createGroupChat(userIds: Array(selectedUserIds), title: title) {
                dismiss()
            }
        }
    }
}
