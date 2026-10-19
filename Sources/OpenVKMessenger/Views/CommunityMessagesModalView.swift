import SwiftUI

public struct CommunityMessagesModalView: View {
    @ObservedObject var store: MessengerStore
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingGroups: Bool = false
    @State private var selectedTab: Int = 0 // 0: All, 1: Administered
    @State private var searchQuery: String = ""

    public init(store: MessengerStore) {
        self.store = store
    }

    private var displayedGroups: [VKGroup] {
        let source = (selectedTab == 1) ? store.administeredGroups : store.userGroups
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return source
        }
        let q = trimmed.lowercased()
        return source.filter {
            $0.name.lowercased().contains(q) || "\($0.id)".contains(q) || ($0.screenName?.lowercased().contains(q) ?? false)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Сообщения сообществ")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VKColors.textPrimary)

                    Text("Диалоги с группами и управление сообществами")
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
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

            // MARK: - Active Mode Banner
            if let cur = store.activeAdminGroup {
                HStack(spacing: 12) {
                    VKAvatarView(url: cur.avatarURL, name: cur.name, size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Вы отвечаете от имени:")
                            .font(.system(size: 11))
                            .foregroundColor(VKColors.textSecondary)
                        Text(cur.name)
                            .font(VKTypography.headline)
                            .foregroundColor(VKColors.textPrimary)
                    }

                    Spacer()

                    Button("Выйти в профиль") {
                        store.switchToAdminGroup(nil)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(VKColors.accent.opacity(0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(VKColors.accent, lineWidth: 1.5)
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // MARK: - Filter Toggle & Tabs
            VStack(spacing: 10) {
                // Chats with communities only toggle
                HStack(spacing: 12) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(VKColors.accent)
                        .frame(width: 30, height: 30)
                        .background(VKColors.secondarySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Только чаты с сообществами")
                            .font(VKTypography.headline)
                            .foregroundColor(VKColors.textPrimary)
                        Text("Скрыть личные переписки в списке диалогов")
                            .font(VKTypography.caption)
                            .foregroundColor(VKColors.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $store.isCommunityFilterActive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(10)
                .background(VKColors.secondarySurface.opacity(0.5))
                .cornerRadius(10)

                // Tab Switcher and Search
                HStack(spacing: 8) {
                    Picker("", selection: $selectedTab) {
                        Text("Все (\(store.userGroups.count))").tag(0)
                        Text("Управляемые (\(store.administeredGroups.count))").tag(1)
                    }
                    .pickerStyle(.segmented)

                    // Search input
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(VKColors.textSecondary)
                        TextField("Поиск...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(VKTypography.caption)
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(VKColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(VKColors.secondarySurface)
                    .cornerRadius(8)
                    .frame(width: 140)

                    // Refresh Button
                    if isLoadingGroups {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                    } else {
                        Button(action: {
                            isLoadingGroups = true
                            Task {
                                await store.fetchAdministeredGroups()
                                isLoadingGroups = false
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundColor(VKColors.textSecondary)
                                .frame(width: 24, height: 24)
                                .background(VKColors.secondarySurface)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Обновить список сообществ")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .background(VKColors.separator)

            // MARK: - Communities List
            ScrollView {
                VStack(spacing: 6) {
                    if displayedGroups.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: selectedTab == 1 ? "shield.slash" : "person.3.fill")
                                .font(.system(size: 28))
                                .foregroundColor(VKColors.textSecondary)
                            Text(selectedTab == 1 ? "Нет управляемых сообществ" : "Сообщества не найдены")
                                .font(VKTypography.subhead)
                                .foregroundColor(VKColors.textPrimary)
                            Text(selectedTab == 1 ? "Сообщества, где вы администратор или редактор, отображаются здесь." : "Проверьте поисковый запрос или обновите список.")
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    } else {
                        ForEach(displayedGroups) { group in
                            communityRow(group)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 530)
        .background(VKColors.surface)
        .onAppear {
            isLoadingGroups = true
            Task {
                await store.fetchAdministeredGroups()
                isLoadingGroups = false
            }
        }
    }

    @ViewBuilder
    private func communityRow(_ group: VKGroup) -> some View {
        let isCurrentAdminActive = store.activeAdminGroup?.id == group.id

        HStack(spacing: 12) {
            VKAvatarView(url: group.avatarURL, name: group.name, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(VKTypography.headline)
                        .foregroundColor(VKColors.textPrimary)
                        .lineLimit(1)

                    if group.isUserAdmin {
                        Text(group.adminRoleTitle ?? "Администратор")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(VKColors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VKColors.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text("ID: \(group.id)")
                    .font(VKTypography.caption)
                    .foregroundColor(VKColors.textSecondary)
            }

            Spacer()

            // Button 1: Open personal dialogue with community
            Button(action: {
                store.selectConversation(-group.id)
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 10))
                    Text("Диалог")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(VKColors.secondarySurface)
                .foregroundColor(VKColors.textPrimary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Открыть личную переписку с сообществом")

            // Button 2: Manage as community
            if group.isUserAdmin {
                Button(action: {
                    store.switchToAdminGroup(isCurrentAdminActive ? nil : group)
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCurrentAdminActive ? "checkmark.circle.fill" : "person.badge.shield.checkmark")
                            .font(.system(size: 10))
                        Text(isCurrentAdminActive ? "Выбрано" : "Управлять")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(isCurrentAdminActive ? VKColors.accent.opacity(0.16) : VKColors.accent)
                    .foregroundColor(isCurrentAdminActive ? VKColors.accent : .white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(isCurrentAdminActive ? "Выйти из режима управления" : "Отвечать от имени группы")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isCurrentAdminActive ? VKColors.accent.opacity(0.08) : VKColors.secondarySurface.opacity(0.4))
        .cornerRadius(9)
    }
}
