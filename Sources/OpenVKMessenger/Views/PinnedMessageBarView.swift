import SwiftUI

public struct PinnedMessageBarView: View {
    public let message: VKMessage
    public let onTap: () -> Void
    public let onUnpin: () -> Void
    @ObservedObject private var theme = ThemeManager.shared

    public init(
        message: VKMessage,
        onTap: @escaping () -> Void,
        onUnpin: @escaping () -> Void
    ) {
        self.message = message
        self.onTap = onTap
        self.onUnpin = onUnpin
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Left accent vertical pill
            RoundedRectangle(cornerRadius: 1.5)
                .fill(VKColors.accent)
                .frame(width: 3, height: 32)

            // Pin icon
            Image(systemName: "pin.fill")
                .font(.system(size: 11))
                .foregroundColor(VKColors.accent)
                .rotationEffect(.degrees(45))

            // Text Info & Click Area
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 4) {
                        Text("Закреплённое сообщение")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(VKColors.accent)

                        if let author = message.sender?.fullName, !author.isEmpty {
                            Text("• \(author)")
                                .font(.system(size: 10.5))
                                .foregroundColor(VKColors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Text(displayText)
                        .font(.system(size: 12))
                        .foregroundColor(VKColors.textPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            // Optional photo thumbnail if pinned message contains a photo
            if let photoUrl = message.photo?.url {
                AsyncImage(url: photoUrl) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.15)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Unpin button
            Button(action: onUnpin) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(VKColors.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(VKColors.secondarySurface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Открепить сообщение")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial.opacity(0.85))
        .background(VKColors.surface.opacity(0.78))
        .overlay(
            Rectangle()
                .fill(VKColors.separator.opacity(0.6))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var displayText: String {
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if message.photo != nil { return "Фотография" }
        if message.sticker != nil { return "Стикер" }
        if message.voiceMessage != nil { return "Голосовое сообщение" }
        if message.doc != nil { return "Документ" }
        if message.audio != nil { return "Аудиозапись" }
        if message.video != nil { return "Видеозапись" }
        if message.wallPost != nil { return "Запись со стены" }
        return "Сообщение"
    }
}
