import SwiftUI

public struct ChatHeaderView: View {
    public let conversation: VKConversation?
    public var typingText: String? = nil
    public var isSearchActive: Bool = false
    public var connectionStatus: ConnectionStatus = .connected
    public var onToggleSearch: (() -> Void)? = nil
    public var onOpenInfo: (() -> Void)? = nil
    public var onBack: (() -> Void)? = nil
    @ObservedObject private var theme = ThemeManager.shared

    public var body: some View {
        HStack(spacing: 8) {
            #if os(iOS)
            if onBack != nil {
                Button(action: {
                    onBack?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                        let total = MessengerStore.shared.totalUnreadCount
                        if total > 0 {
                            Text("\(total)")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(VKColors.accent)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(VKColors.accent)
                    .padding(.trailing, 2)
                }
                .buttonStyle(.plain)
            }
            #endif

            if let conv = conversation {
                #if os(iOS)
                VKAvatarView(
                    url: conv.avatarURL,
                    name: conv.displayTitle,
                    size: 38,
                    isOnline: conv.isSavedMessages ? false : conv.isOnline,
                    isMobile: conv.isSavedMessages ? false : conv.isMobile,
                    isSavedMessages: conv.isSavedMessages
                )
                .onTapGesture {
                    onOpenInfo?()
                }
                #endif

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(conv.displayTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VKColors.textPrimary)
                            .lineLimit(1)

                        if conv.isVerified && !conv.isSavedMessages {
                            VKVerifiedBadge()
                        }

                        if MessengerStore.shared.isMuted(peerId: conv.peerId) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 11))
                                .foregroundColor(VKColors.textSecondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenInfo?()
                    }

                    // Status line
                    HStack(spacing: 4) {
                        if connectionStatus == .connecting {
                            ProgressView()
                                .controlSize(.mini)
                            Text("соединение...")
                                .font(.system(size: 12))
                                .foregroundColor(VKColors.textSecondary)
                        } else if connectionStatus == .updating {
                            ProgressView()
                                .controlSize(.mini)
                            Text("обновление...")
                                .font(.system(size: 12))
                                .foregroundColor(VKColors.accent)
                        } else if let typing = typingText {
                            TypingDotsIndicator()
                            Text(typing)
                                .font(.system(size: 12))
                                .foregroundColor(VKColors.accent)
                        } else if conv.isSavedMessages {
                            Text("чат с собой")
                                .font(.system(size: 12))
                                .foregroundColor(VKColors.textSecondary)
                        } else if conv.isChat {
                            if let count = conv.membersCount, count > 0 {
                                Text(pluralizeMembers(count))
                                    .font(.system(size: 12))
                                    .foregroundColor(VKColors.textSecondary)
                            } else {
                                Text("Групповая беседа")
                                    .font(.system(size: 12))
                                    .foregroundColor(VKColors.textSecondary)
                            }
                        } else if conv.peerId < 0 {
                            Text("Сообщество")
                                .font(.system(size: 12))
                                .foregroundColor(VKColors.textSecondary)
                        } else {
                            Text(formatUserOnlineStatus(for: conv))
                                .font(.system(size: 12))
                                .foregroundColor(conv.isOnline ? VKColors.accent : VKColors.textSecondary)
                        }
                    }
                }
            } else {
                Text("Выберите диалог")
                    .font(VKTypography.title)
                    .foregroundColor(VKColors.textSecondary)
            }

            Spacer()

            // Header Action Buttons
            HStack(spacing: 12) {
                if let conv = conversation {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            MessengerStore.shared.toggleMute(peerId: conv.peerId)
                        }
                    }) {
                        Image(systemName: MessengerStore.shared.isMuted(peerId: conv.peerId) ? "bell.slash.fill" : "bell")
                            .font(.system(size: 15))
                            .foregroundColor(MessengerStore.shared.isMuted(peerId: conv.peerId) ? VKColors.textSecondary : VKColors.accent)
                            #if os(macOS)
                            .frame(width: 28, height: 28)
                            .background(MessengerStore.shared.isMuted(peerId: conv.peerId) ? Color.black.opacity(0.06) : Color.clear)
                            .clipShape(Circle())
                            #endif
                    }
                    .buttonStyle(.plain)
                    .help(MessengerStore.shared.isMuted(peerId: conv.peerId) ? "Включить уведомления" : "Отключить уведомления")
                }

                #if os(iOS)
                Button(action: {
                    onOpenInfo?()
                }) {
                    Image(systemName: conversation?.isChat == true ? "person.badge.plus" : "info.circle")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundColor(VKColors.accent)
                }
                .buttonStyle(.plain)
                #else
                Button(action: {
                    onToggleSearch?()
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(isSearchActive ? VKColors.accent : VKColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(isSearchActive ? VKColors.accent.opacity(0.14) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Поиск по сообщениям (⌘F)")

                Button(action: {
                    onOpenInfo?()
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(VKColors.accent)
                }
                .buttonStyle(.plain)
                .help("Информация о беседе")
                #endif
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.85))
        .background(VKColors.surface.opacity(0.78))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(VKColors.separator.opacity(0.6)),
            alignment: .bottom
        )
        #if os(iOS)
        .simultaneousGesture(
            DragGesture(minimumDistance: 25)
                .onEnded { value in
                    if value.translation.width > 50 && abs(value.translation.height) < 40 {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onBack?()
                    }
                }
        )
        #endif
    }

    private func pluralizeMembers(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 {
            return "\(count) участников"
        }
        if mod10 == 1 {
            return "\(count) участник"
        }
        if mod10 >= 2 && mod10 <= 4 {
            return "\(count) участника"
        }
        return "\(count) участников"
    }

    private func formatUserOnlineStatus(for conv: VKConversation) -> String {
        if conv.isOnline {
            return conv.isMobile ? "в сети с телефона" : "в сети"
        }

        let isFemale = conv.sex == 1
        let prefix = isFemale ? "была в сети" : "был в сети"

        guard let ls = conv.lastSeen, ls.time > 0 else {
            return "\(prefix) недавно"
        }

        let date = Date(timeIntervalSince1970: ls.time)
        let diff = Date().timeIntervalSince(date)

        if diff < 60 && diff >= 0 {
            return "\(prefix) только что"
        }

        if diff < 3600 && diff >= 60 {
            let minutes = max(1, Int(diff / 60))
            let minWord = pluralizeMinutes(minutes)
            return "\(prefix) \(minutes) \(minWord) назад"
        }

        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.locale = Locale(identifier: "ru_RU")
        let timeStr = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "\(prefix) сегодня в \(timeStr)"
        }

        if calendar.isDateInYesterday(date) {
            return "\(prefix) вчера в \(timeStr)"
        }

        let curYear = calendar.component(.year, from: Date())
        let dateYear = calendar.component(.year, from: date)

        if curYear == dateYear {
            let df = DateFormatter()
            df.locale = Locale(identifier: "ru_RU")
            df.dateFormat = "d MMMM"
            return "\(prefix) \(df.string(from: date)) в \(timeStr)"
        } else {
            let df = DateFormatter()
            df.locale = Locale(identifier: "ru_RU")
            df.dateFormat = "d MMMM yyyy г."
            return "\(prefix) \(df.string(from: date))"
        }
    }

    private func pluralizeMinutes(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 19 {
            return "минут"
        }
        if mod10 == 1 {
            return "минуту"
        }
        if mod10 >= 2 && mod10 <= 4 {
            return "минуты"
        }
        return "минут"
    }
}
