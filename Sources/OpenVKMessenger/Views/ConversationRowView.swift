import SwiftUI

public struct ConversationRowView: View {
    public let conversation: VKConversation
    public let isSelected: Bool
    public var isPinned: Bool = false
    public var typingText: String? = nil
    @ObservedObject private var theme = ThemeManager.shared

    public init(
        conversation: VKConversation,
        isSelected: Bool,
        isPinned: Bool = false,
        typingText: String? = nil
    ) {
        self.conversation = conversation
        self.isSelected = isSelected
        self.isPinned = isPinned
        self.typingText = typingText
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Avatar with online status
            VKAvatarView(
                url: conversation.avatarURL,
                name: conversation.displayTitle,
                size: 46,
                isOnline: conversation.isSavedMessages ? false : conversation.isOnline,
                isMobile: conversation.isSavedMessages ? false : conversation.isMobile,
                isSavedMessages: conversation.isSavedMessages
            )

            // Content
            VStack(alignment: .leading, spacing: 3) {
                // Top line: Name + Verified + Pinned Icon + Time
                HStack(spacing: 4) {
                    Text(conversation.displayTitle)
                        .font(VKTypography.headline)
                        .foregroundColor(isSelected ? theme.textOnAccentColor : VKColors.textPrimary)
                        .lineLimit(1)

                    if conversation.isVerified && !conversation.isSavedMessages {
                        VKVerifiedBadge()
                    }

                    Spacer()

                    if MessengerStore.shared.isMuted(peerId: conversation.peerId) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.85) : VKColors.textSecondary)
                    }

                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.85) : VKColors.accent)
                            .rotationEffect(.degrees(45))
                    }

                    Text(timeString)
                        .font(VKTypography.caption)
                        .foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.8) : VKColors.textSecondary)
                }

                // Bottom line: Message preview + Unread badge
                HStack {
                    if let typing = typingText {
                        Text(typing)
                            .font(VKTypography.subhead)
                            .foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.9) : VKColors.accent)
                            .lineLimit(1)
                    } else if conversation.lastMessage != nil {
                        messagePreviewView
                    }

                    Spacer()

                    if conversation.hasUnreadMention {
                        Text("@")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(VKColors.accent))
                    }

                    if conversation.unreadCount > 0 {
                        VKUnreadBadge(count: conversation.unreadCount)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? VKColors.accent : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func formatMentions(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\\[(?:id|club)\d+\\|([^\\]]+)\\]"#, options: []) else { return text }
        return regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "@$1")
    }

    private var timeString: String {
        guard let date = conversation.lastMessage?.date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "вчера"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            formatter.locale = Locale(identifier: "ru_RU")
            return formatter.string(from: date)
        }
    }

    @ViewBuilder
    private var messagePreviewView: some View {
        if let msg = conversation.lastMessage {
            let cleanText = msg.text.replacingOccurrences(of: "&#8203;", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let formattedText = formatMentions(cleanText)
            let bodyText = formattedText.isEmpty ? (msg.wallPost != nil ? "Запись со стены" : (msg.hasAttachments ? "Вложение" : (msg.sticker != nil ? "Стикер" : ""))) : formattedText

            if conversation.isChat {
                if msg.out {
                    (Text("Вы: ").foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.85) : VKColors.accent) +
                     Text(bodyText).foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.9) : VKColors.textSecondary))
                        .font(VKTypography.subhead)
                        .lineLimit(1)
                } else {
                    let senderName = msg.sender?.firstName ?? OpenVKAPIService.shared.cachedUsers[msg.fromId]?.firstName ?? ""
                    if !senderName.isEmpty {
                        (Text("\(senderName): ").foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.85) : VKColors.accent) +
                         Text(bodyText).foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.9) : VKColors.textSecondary))
                            .font(VKTypography.subhead)
                            .lineLimit(1)
                    } else {
                        Text(bodyText)
                            .font(VKTypography.subhead)
                            .foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.9) : VKColors.textSecondary)
                            .lineLimit(1)
                    }
                }
            } else if msg.out {
                (Text("Вы: ").foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.85) : VKColors.textSecondary) +
                 Text(bodyText).foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.9) : VKColors.textSecondary))
                    .font(VKTypography.subhead)
                    .lineLimit(1)
            } else {
                Text(bodyText)
                    .font(VKTypography.subhead)
                    .foregroundColor(isSelected ? theme.textOnAccentColor.opacity(0.9) : VKColors.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
