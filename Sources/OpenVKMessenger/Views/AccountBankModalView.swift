import SwiftUI

public struct AccountBankModalView: View {
    @ObservedObject var store: MessengerStore
    @Environment(\.dismiss) private var dismiss

    @State private var showAddAccountSheet: Bool = false
    @State private var accountToDelete: VKAccount? = nil
    @State private var showDeleteConfirm: Bool = false

    public init(store: MessengerStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Банк аккаунтов")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VKColors.textPrimary)

                    Text("Мгновенное переключение профилей OpenVK")
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

            // Account List
            ScrollView {
                VStack(spacing: 8) {
                    if store.savedAccounts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(VKColors.textSecondary)
                            Text("Нет сохранённых аккаунтов")
                                .font(VKTypography.headline)
                                .foregroundColor(VKColors.textPrimary)
                        }
                        .padding(.top, 30)
                    } else {
                        ForEach(store.savedAccounts) { acc in
                            let isCurrent = acc.id == store.currentAccountId

                            Button(action: {
                                if !isCurrent {
                                    store.switchAccount(to: acc)
                                    dismiss()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    VKAvatarView(url: acc.photoURL, name: acc.fullName, size: 38)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(acc.fullName)
                                            .font(.system(size: 13.5, weight: isCurrent ? .bold : .medium))
                                            .foregroundColor(VKColors.textPrimary)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            Image(systemName: "server.rack")
                                                .font(.system(size: 9))
                                            Text(acc.serverDomain)
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(VKColors.textSecondary)
                                    }

                                    Spacer()

                                    if isCurrent {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(VKColors.onlineGreen)
                                                .frame(width: 7, height: 7)
                                            Text("Активен")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(VKColors.onlineGreen)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(VKColors.onlineGreen.opacity(0.12))
                                        .clipShape(Capsule())
                                    } else {
                                        Button(action: {
                                            accountToDelete = acc
                                            showDeleteConfirm = true
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 12))
                                                .foregroundColor(.red.opacity(0.8))
                                                .padding(6)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Удалить из банка")
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isCurrent ? VKColors.accent.opacity(0.10) : VKColors.secondarySurface.opacity(0.4))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isCurrent ? VKColors.accent : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
            }

            Divider()
                .background(VKColors.separator)

            // Bottom Add Account Action
            HStack {
                Spacer()

                Button(action: {
                    showAddAccountSheet = true
                }) {
                    Label("Добавить аккаунт", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(VKColors.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: 460)
        .background(VKColors.surface)
        .sheet(isPresented: $showAddAccountSheet) {
            LoginView(api: store.api, store: store, isAddingAccount: true)
        }
        .confirmationDialog(
            "Удалить аккаунт \(accountToDelete?.fullName ?? "")?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                if let acc = accountToDelete {
                    store.removeAccount(id: acc.id)
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Сессия будет удалена из памяти приложения.")
        }
    }
}
