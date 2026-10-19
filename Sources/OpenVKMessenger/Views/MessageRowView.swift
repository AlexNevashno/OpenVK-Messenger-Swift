import SwiftUI

public struct MessageRowView: View {
    public let message: VKMessage
    public var isHighlighted: Bool = false
    public var store: MessengerStore? = nil
    public var onReply: ((VKMessage) -> Void)? = nil
    public var onEdit: ((VKMessage) -> Void)? = nil
    public var onDelete: ((VKMessage) -> Void)? = nil
    public var onJumpToMessage: ((Int) -> Void)? = nil
    public var onPreviewTheme: ((VKThemePack) -> Void)? = nil

    @ObservedObject private var theme = ThemeManager.shared
    @State private var isHovered: Bool = false
    @State private var swipeOffset: CGFloat = 0
    @State private var didHapticReply: Bool = false

    public init(
        message: VKMessage,
        isHighlighted: Bool = false,
        store: MessengerStore? = nil,
        onReply: ((VKMessage) -> Void)? = nil,
        onEdit: ((VKMessage) -> Void)? = nil,
        onDelete: ((VKMessage) -> Void)? = nil,
        onJumpToMessage: ((Int) -> Void)? = nil,
        onPreviewTheme: ((VKThemePack) -> Void)? = nil
    ) {
        self.message = message
        self.isHighlighted = isHighlighted
        self.store = store
        self.onReply = onReply
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onJumpToMessage = onJumpToMessage
        self.onPreviewTheme = onPreviewTheme
    }

    @ViewBuilder
    private var photoOnlyTimestampBadge: some View {
        HStack(spacing: 3) {
            if isMessagePinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8.5))
                    .foregroundColor(.white)
            }
            Text(formattedTime(message.date))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
            if message.out {
                deliveryStatusWhiteView
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
        .padding(6)
    }

    public var body: some View {
        if let transfer = message.moneyTransfer {
            // MARK: - Money / Votes Transfer System Message (Matching media_1791710261223_278a09bd.png)
            HStack {
                Spacer()
                VStack(spacing: 3) {
                    let senderName = message.sender?.fullName ?? "Пользователь"
                    let targetText = message.out ? "Вы передали" : "\(senderName) передал(а) вам"
                    let amountText = transfer.amount > 0 ? "\(transfer.amount) \(transfer.currency)" : "голоса"

                    HStack(spacing: 5) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.yellow)

                        (Text("\(targetText) ").font(.system(size: 13, weight: .semibold)) +
                         Text(amountText).font(.system(size: 13, weight: .bold)) +
                         Text(".  \(formattedTime(message.date))").font(.system(size: 11, weight: .regular)).foregroundColor(.white.opacity(0.8)))
                    }
                    .foregroundColor(.white)

                    let comment = !transfer.text.isEmpty ? transfer.text : message.text
                    let trimmedComment = comment.replacingOccurrences(of: "&#8203;", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedComment.isEmpty && !trimmedComment.contains("передал вам") && !trimmedComment.contains("передала вам") {
                        Text("«\(trimmedComment)»")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .padding(.top, 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
        } else if let gift = message.gift {
            // MARK: - Gift System Message
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    let senderName = message.sender?.fullName ?? "Пользователь"
                    let targetText = message.out ? "Вы отправили подарок" : "\(senderName) отправил(а) вам подарок"

                    if let thumb = gift.thumbURL {
                        AsyncImage(url: thumb) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit().frame(width: 96, height: 96)
                            } else {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                            }
                        }
                    } else {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                    }

                    Text("\(targetText).  \(formattedTime(message.date))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    if !message.text.isEmpty {
                        Text("«\(message.text)»")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
        } else if message.isServiceAction {
            // MARK: - Service Action Message (Telegram style)
            HStack {
                Spacer()
                Text(message.serviceDisplayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 4.5)
                    .background(Color.black.opacity(0.38))
                    .clipShape(Capsule())
                    .multilineTextAlignment(.center)
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
        } else if let sticker = message.sticker {
            // MARK: - Sticker Message (No bubble background)
            let url = sticker.url ?? URL(string: "https://vk.com/sticker/1-\(sticker.id)-256.png") ?? URL(string: "about:blank")!

            HStack(alignment: .bottom, spacing: 6) {
                if message.out {
                    Spacer(minLength: 40)
                    if isHovered {
                        replyButton
                    }
                } else {
                    VKAvatarView(
                        url: senderAvatarURL,
                        name: senderFullName,
                        size: 34
                    )
                }

                VStack(alignment: message.out ? .trailing : .leading, spacing: 2) {
                    if !message.out {
                        HStack(spacing: 6) {
                            Text(senderFullName)
                                .font(VKTypography.headline)
                                .foregroundColor(theme.chatAuthorNameColor(for: message.fromId, baseColor: VKColors.accent))
                                .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)

                            Text(formattedTime(message.date))
                                .font(VKTypography.caption)
                                .foregroundColor(theme.chatTimestampColor)
                                .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)

                            if isMessagePinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.chatAuthorNameColor(for: message.fromId, baseColor: VKColors.accent))
                                    .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)
                            }
                        }
                    }

                    VKAnimatedStickerView(
                        url: url,
                        animationURL: sticker.animationURL,
                        size: 140,
                        loop: true
                    )
                    .contextMenu {
                        Button(action: { onReply?(message) }) {
                            Label("Ответить", systemImage: "arrowshape.turn.up.left")
                        }
                        Divider()
                        if isMessagePinned {
                            Button(action: {
                                Task {
                                    let s = store ?? MessengerStore.shared
                                    await s.unpinMessage(peerId: message.peerId)
                                }
                            }) {
                                Label("Открепить сообщение", systemImage: "pin.slash")
                            }
                        } else {
                            Button(action: {
                                Task {
                                    let s = store ?? MessengerStore.shared
                                    await s.pinMessage(peerId: message.peerId, messageId: message.id)
                                }
                            }) {
                                Label("Закрепить сообщение", systemImage: "pin")
                            }
                        }
                    }

                    if message.out {
                        HStack(spacing: 3) {
                            if isMessagePinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(theme.chatAuthorNameColor(for: 0, baseColor: VKColors.accent))
                                    .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)
                            }
                            Text(formattedTime(message.date))
                                .font(VKTypography.caption)
                                .foregroundColor(theme.chatTimestampColor)
                                .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)
                            deliveryStatusView
                        }
                    }
                }

                if !message.out {
                    if isHovered {
                        replyButton
                    }
                    Spacer(minLength: 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .offset(x: swipeOffset)
            .overlay(
                Group {
                    if swipeOffset < -8 {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(VKColors.accent)
                                    .frame(width: 32, height: 32)
                                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(min(1.0, max(0.35, abs(swipeOffset) / 45.0)))
                            .padding(.trailing, 10)
                        }
                    }
                },
                alignment: .trailing
            )
            #if os(iOS)
            .gesture(
                DragGesture(minimumDistance: 22)
                    .onChanged { val in
                        if val.translation.width < -12 && abs(val.translation.width) > abs(val.translation.height) * 2.2 {
                            swipeOffset = max(-65, val.translation.width * 0.75)
                            if swipeOffset <= -40 && !didHapticReply {
                                didHapticReply = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                    }
                    .onEnded { _ in
                        if didHapticReply {
                            onReply?(message)
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                            swipeOffset = 0
                        }
                        didHapticReply = false
                    }
            )
            #elseif os(macOS)
            .onTapGesture(count: 2) {
                onReply?(message)
            }
            #endif
            .onHover { isHovered = $0 }
        } else {
            // MARK: - Standard Message (Incoming/Outgoing)
            let allPhotos = !message.photos.isEmpty ? message.photos : (message.photo != nil ? [message.photo!] : [])
            let cleanText = message.text.replacingOccurrences(of: "&#8203;", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let isPhotoOnly = !allPhotos.isEmpty && cleanText.isEmpty && message.replyMessage == nil && message.voiceMessage == nil && message.doc == nil && message.audio == nil && message.video == nil
            let isShortSingleLine = !cleanText.isEmpty && !cleanText.contains("\n") && cleanText.count <= 75 && !message.hasAttachments && message.replyMessage == nil && message.voiceMessage == nil && message.doc == nil && message.audio == nil && message.video == nil && message.photo == nil && message.wallPost == nil && embeddedThemePack == nil && !(isGroupChat && !message.out)

            HStack(alignment: .bottom, spacing: 6) {
                if message.out {
                    Spacer(minLength: 20)
                    if isHovered {
                        replyButton
                            .padding(.bottom, 4)
                    }
                } else {
                    if isGroupChat {
                        VKAvatarView(
                            url: senderAvatarURL,
                            name: senderFullName,
                            size: 34
                        )
                    }
                }

                VStack(alignment: message.out ? .trailing : .leading, spacing: 2) {
                    // Bubble Content
                    VStack(alignment: .trailing, spacing: 3) {
                        VStack(alignment: .leading, spacing: 4) {
                            // In group chats: sender name inside bubble at top
                        if !message.out && isGroupChat {
                            HStack(spacing: 4) {
                                Text(senderFullName)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundColor(theme.chatAuthorNameColor(for: message.fromId, baseColor: VKColors.accent))
                                    .lineLimit(1)
                                if isMessagePinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(theme.chatAuthorNameColor(for: message.fromId, baseColor: VKColors.accent))
                                }
                            }
                            .padding(.bottom, 1)
                        }

                        // Reply quote block (if message replies to another message)
                        if let reply = message.replyMessage {
                            replyBlockView(reply)
                        }

                        // Attached Photos (Single or Gallery Grid)
                        if allPhotos.count == 1, let photo = allPhotos.first {
                            Button(action: {
                                openPhotoInViewer(photo: photo)
                            }) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let local = photo.localImage {
                                        Image(platformImage: local)
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(12)
                                            .frame(maxHeight: 280)
                                    } else if let url = photo.url {
                                        let aspect: CGFloat = {
                                            if let w = photo.width, let h = photo.height, w > 0 && h > 0 {
                                                return min(max(CGFloat(w) / CGFloat(h), 0.55), 2.2)
                                            }
                                            return 4.0 / 3.0
                                        }()
                                        let isPhotoGIF = url.pathExtension.lowercased() == "gif" || photo.text.lowercased().hasSuffix(".gif")
                                        if isPhotoGIF {
                                            VKAnimatedGIFView(url: url)
                                                .aspectRatio(aspect, contentMode: .fit)
                                                .frame(maxHeight: 280)
                                                .cornerRadius(12)
                                        } else {
                                            VKCachedAsyncImage(url: url) { img in
                                                img
                                                    .resizable()
                                                    .scaledToFit()
                                                    .cornerRadius(12)
                                                    .frame(maxHeight: 280)
                                            } placeholder: {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(VKColors.secondarySurface.opacity(0.4))
                                                    .aspectRatio(aspect, contentMode: .fit)
                                                    .frame(maxHeight: 280)
                                                    .overlay(ProgressView().controlSize(.small))
                                            }
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(VKColors.secondarySurface.opacity(0.4))
                                            .frame(width: 200, height: 160)
                                            .overlay(ProgressView().controlSize(.small))
                                    }

                                    // Floating timestamp badge on photo (Telegram style)
                                    if isPhotoOnly {
                                        photoOnlyTimestampBadge
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            #if os(macOS)
                            .onHover { inside in
                                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                            #endif
                        } else if allPhotos.count > 1 {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                                ForEach(Array(allPhotos.enumerated()), id: \.offset) { idx, p in
                                    Button(action: {
                                        openPhotoInViewer(photo: p)
                                    }) {
                                        ZStack(alignment: .bottomTrailing) {
                                            if let local = p.localImage {
                                                Image(platformImage: local)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 140, height: 130)
                                                    .clipped()
                                                    .cornerRadius(8)
                                             } else if let url = p.url {
                                                let isGIF = url.pathExtension.lowercased() == "gif" || p.text.lowercased().hasSuffix(".gif")
                                                if isGIF {
                                                    VKAnimatedGIFView(url: url)
                                                        .frame(width: 140, height: 130)
                                                        .clipped()
                                                        .cornerRadius(8)
                                                } else {
                                                    VKCachedAsyncImage(url: url) { img in
                                                        img
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 140, height: 130)
                                                            .clipped()
                                                            .cornerRadius(8)
                                                    } placeholder: {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(VKColors.secondarySurface.opacity(0.4))
                                                            .frame(width: 140, height: 130)
                                                            .overlay(ProgressView().controlSize(.small))
                                                    }
                                                }
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(VKColors.secondarySurface.opacity(0.4))
                                                    .frame(width: 140, height: 130)
                                                    .overlay(ProgressView().controlSize(.small))
                                            }

                                            if isPhotoOnly && idx == allPhotos.count - 1 {
                                                photoOnlyTimestampBadge
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    #if os(macOS)
                                    .onHover { inside in
                                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    }
                                    #endif
                                }
                            }
                            .frame(maxWidth: 290)
                        }

                        // Voice Message
                        if let voice = message.voiceMessage {
                            VKAudioTrackView(
                                id: "voice_\(voice.id)_\(message.id)",
                                title: "Голосовое сообщение",
                                subtitle: "",
                                duration: voice.duration,
                                url: voice.audioURL,
                                isOutgoing: message.out
                            )
                        }

                        // Document Attachment
                        if let doc = message.doc {
                            let lower = doc.title.lowercased()
                            let isGIF = lower.hasSuffix(".gif") || doc.ext.lowercased() == "gif"

                            if isGIF, let docURL = doc.url {
                                VKAnimatedGIFView(
                                    url: docURL,
                                    onExpand: {
                                        let item = PhotoViewerItem(
                                            id: "doc_\(doc.id)",
                                            imageURL: docURL,
                                            caption: doc.title,
                                            authorName: message.sender?.fullName ?? "",
                                            date: message.date
                                        )
                                        PhotoViewerService.shared.open(items: [item], initialIndex: 0)
                                    }
                                )
                                .frame(width: 240, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.vertical, 2)
                            } else if lower.hasSuffix(".themepack") || lower.hasSuffix(".themepack.txt") || lower.hasSuffix(".theme.txt") || doc.ext.lowercased() == "themepack" {
                                let cleanName = doc.title
                                    .replacingOccurrences(of: ".themepack.txt", with: "")
                                    .replacingOccurrences(of: ".themepack", with: "")
                                    .replacingOccurrences(of: ".theme.txt", with: "")
                                themePackCard(name: cleanName, pack: nil, docURL: doc.url)
                            } else {
                                Button(action: {
                                    if let u = doc.url {
                                        #if os(macOS)
                                        NSWorkspace.shared.open(u)
                                        #else
                                        UIApplication.shared.open(u)
                                        #endif
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(theme.replyAuthorNameColor(isOutgoingBubble: message.out))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(doc.title)
                                                .font(VKTypography.subhead)
                                                .foregroundColor(message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor)
                                                .lineLimit(1)

                                            Text(doc.size > 0 ? formatFileSize(doc.size) : (doc.ext.isEmpty ? "Файл" : doc.ext.uppercased()))
                                                .font(VKTypography.caption)
                                                .foregroundColor((message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor).opacity(0.72))
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Audio (Music) Attachment
                        if let audio = message.audio {
                            VKAudioTrackView(
                                id: "audio_\(audio.id)_\(message.id)",
                                title: audio.title,
                                subtitle: audio.artist,
                                duration: audio.duration,
                                url: audio.url,
                                allChatTracks: collectAllChatAudioTracks(),
                                isOutgoing: message.out
                            )
                        }

                        // Video Attachment
                        if let video = message.video {
                            Button(action: {
                                openVideoInPlayer(video: video)
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ZStack {
                                        if let url = video.imageURL {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let img):
                                                    img.resizable().scaledToFit().cornerRadius(8)
                                                default:
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(VKColors.secondarySurface)
                                                        .frame(height: 140)
                                                }
                                            }
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(VKColors.secondarySurface)
                                                .frame(height: 140)
                                        }

                                        // Centered Play Button
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.white)
                                            .padding(14)
                                            .background(Color.black.opacity(0.65))
                                            .clipShape(Circle())
                                            .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

                                        // Duration Badge bottom right
                                        if video.duration > 0 {
                                            VStack {
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    Text(formatVideoDuration(video.duration))
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.black.opacity(0.72))
                                                        .cornerRadius(4)
                                                        .padding(8)
                                                }
                                            }
                                        }
                                    }

                                    Text(video.title)
                                        .font(VKTypography.subhead)
                                        .foregroundColor(message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        // Wall Post Repost
                        if let wall = message.wallPost {
                            VKWallPostCard(
                                authorName: wall.authorName,
                                authorAvatarURL: wall.authorPhoto,
                                dateString: formattedWallDate(wall.date),
                                text: wall.text,
                                imageURL: wall.imageURL,
                                photos: wall.photos,
                                audios: wall.audios,
                                videos: wall.videos,
                                docs: wall.docs,
                                isOutgoing: message.out
                            )
                        }

                        // Embedded Theme Pack in message text
                        if let pack = embeddedThemePack {
                            themePackCard(name: pack.name, pack: pack, docURL: nil)
                        } else if isShortSingleLine {
                            // Telegram compact inline layout: text and timestamp side-by-side without line break or wide spacer
                            HStack(alignment: .bottom, spacing: 8) {
                                if isEmojiOnly(cleanText) {
                                    Text(cleanText)
                                        .font(.system(size: 32))
                                } else {
                                    let txt = Text(formatMessageWithLinks(cleanText))
                                        .font(VKTypography.body)
                                        .foregroundColor(message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor)
                                        .tint(theme.replyAuthorNameColor(isOutgoingBubble: message.out))
                                    #if os(macOS)
                                    txt.textSelection(.enabled)
                                    #else
                                    txt
                                    #endif
                                }

                                HStack(spacing: 3) {
                                    if isMessagePinned {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 8.5))
                                            .foregroundColor((message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor).opacity(0.65))
                                    }
                                    Text(formattedTime(message.date))
                                        .font(.system(size: 11))
                                        .foregroundColor((message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor).opacity(0.65))
                                    if message.out {
                                        deliveryStatusView
                                    }
                                }
                                .padding(.bottom, 1)
                            }
                        } else {
                            // Regular multiline text or attachments
                            if !cleanText.isEmpty {
                                if isEmojiOnly(cleanText) {
                                    Text(cleanText)
                                        .font(.system(size: 32))
                                } else {
                                    let txt = Text(formatMessageWithLinks(cleanText))
                                        .font(VKTypography.body)
                                        .foregroundColor(message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor)
                                        .tint(theme.replyAuthorNameColor(isOutgoingBubble: message.out))
                                    #if os(macOS)
                                    txt.textSelection(.enabled)
                                    #else
                                    txt
                                    #endif
                                }
                            } else if !message.hasAttachments {
                                HStack(spacing: 5) {
                                    Image(systemName: "paperclip")
                                        .font(.system(size: 12))
                                        .foregroundColor(VKColors.textSecondary)
                                    Text("Вложение")
                                        .font(VKTypography.subhead)
                                        .foregroundColor(VKColors.textSecondary)
                                }
                            }
                        }

                        }

                        // Timestamp & delivery status inside bubble (for multiline/attachment messages)
                        if !isPhotoOnly && message.voiceMessage == nil && !isShortSingleLine {
                            HStack(spacing: 3) {
                                if isMessagePinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 8.5))
                                        .foregroundColor((message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor).opacity(0.65))
                                }
                                Text(formattedTime(message.date))
                                    .font(.system(size: 11))
                                    .foregroundColor((message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor).opacity(0.65))
                                if message.out {
                                    deliveryStatusView
                                }
                            }
                        }
                    }
                    .padding(.horizontal, isPhotoOnly ? 0 : (isEmojiOnly(message.text) ? 4 : 12))
                    .padding(.vertical, isPhotoOnly ? 0 : (isEmojiOnly(message.text) ? 2 : 7))
                    .background(
                        isEmojiOnly(message.text) || isPhotoOnly
                            ? Color.clear
                            : (message.out ? theme.bubbleOutgoingColor : theme.bubbleIncomingColor)
                    )
                    .cornerRadius(12)
                    .overlay(
                        isPhotoOnly ? nil :
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                theme.bubbleStrokeColor ?? (message.out ? Color.clear : VKColors.separator.opacity(0.6)),
                                lineWidth: theme.bubbleStrokeWidth > 0 ? theme.bubbleStrokeWidth : (message.out ? 0 : 0.8)
                            )
                    )
                    .contextMenu {
                        Button(action: { onReply?(message) }) {
                            Label("Ответить", systemImage: "arrowshape.turn.up.left")
                        }
                        if message.out {
                            Button(action: { onEdit?(message) }) {
                                Label("Редактировать", systemImage: "pencil")
                            }
                        }
                        if !message.text.isEmpty {
                            Button(action: {
                                PlatformPasteboard.copyString(message.text)
                            }) {
                                Label("Копировать текст", systemImage: "doc.on.doc")
                            }
                        }
                        Divider()
                        if isMessagePinned {
                            Button(action: {
                                Task {
                                    let s = store ?? MessengerStore.shared
                                    await s.unpinMessage(peerId: message.peerId)
                                }
                            }) {
                                Label("Открепить сообщение", systemImage: "pin.slash")
                            }
                        } else {
                            Button(action: {
                                Task {
                                    let s = store ?? MessengerStore.shared
                                    await s.pinMessage(peerId: message.peerId, messageId: message.id)
                                }
                            }) {
                                Label("Закрепить сообщение", systemImage: "pin")
                            }
                        }
                        Divider()
                        Button(role: .destructive, action: { onDelete?(message) }) {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    .frame(maxWidth: maxBubbleWidth, alignment: message.out ? .trailing : .leading)
                }

                if !message.out {
                    if isHovered {
                        replyButton
                            .padding(.bottom, 4)
                    }
                    Spacer(minLength: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .offset(x: swipeOffset)
            .overlay(
                Group {
                    if swipeOffset < -8 {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(VKColors.accent)
                                    .frame(width: 32, height: 32)
                                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(min(1.0, max(0.35, abs(swipeOffset) / 45.0)))
                            .padding(.trailing, 10)
                        }
                    }
                },
                alignment: .trailing
            )
            #if os(iOS)
            .gesture(
                DragGesture(minimumDistance: 22)
                    .onChanged { val in
                        // Telegram style: swipe RIGHT to LEFT to reply, only if horizontal!
                        if val.translation.width < -12 && abs(val.translation.width) > abs(val.translation.height) * 2.2 {
                            swipeOffset = max(-65, val.translation.width * 0.75)
                            if swipeOffset <= -40 && !didHapticReply {
                                didHapticReply = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                    }
                    .onEnded { _ in
                        if didHapticReply {
                            onReply?(message)
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                            swipeOffset = 0
                        }
                        didHapticReply = false
                    }
            )
            #elseif os(macOS)
            .onTapGesture(count: 2) {
                onReply?(message)
            }
            #endif
            .onHover { isHovered = $0 }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHighlighted ? VKColors.accent.opacity(0.24) : Color.clear)
                    .padding(.horizontal, -6)
                    .padding(.vertical, -2)
            )
            .animation(.easeInOut(duration: 0.35), value: isHighlighted)
        }
    }

    private var isGroupChat: Bool {
        if message.peerId > 2000000000 { return true }
        if let conv = store?.selectedConversation, conv.isChat { return true }
        return false
    }

    @ViewBuilder
    private var deliveryStatusWhiteView: some View {
        if message.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 9))
                .foregroundColor(.red)
        } else if message.id <= 0 {
            Image(systemName: "clock")
                .font(.system(size: 8.5))
                .foregroundColor(.white.opacity(0.8))
        } else if message.isRead {
            HStack(spacing: -4.5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8.5, weight: .bold))
                Image(systemName: "checkmark")
                    .font(.system(size: 8.5, weight: .bold))
            }
            .foregroundColor(.white)
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private var isMessagePinned: Bool {
        if message.isPinned { return true }
        let currentStore = store ?? MessengerStore.shared
        if let pinId = currentStore.selectedConversation?.pinnedMessage?.id, pinId > 0 {
            return pinId == message.id
        }
        return false
    }

    private var embeddedThemePack: VKThemePack? {
        if message.text.contains("[OpenVK-ThemePack:") {
            let lines = message.text.components(separatedBy: "\n")
            if lines.count >= 2 {
                let jsonStr = lines.dropFirst().joined(separator: "\n")
                if let data = jsonStr.data(using: .utf8),
                   let pack = try? JSONDecoder().decode(VKThemePack.self, from: data) {
                    return pack
                }
            }
        }
        return nil
    }

    @ViewBuilder
    private func themePackCard(name: String, pack: VKThemePack?, docURL: URL?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    LinearGradient(
                        colors: [
                            pack != nil ? (Color(hex: pack!.accentHex) ?? VKColors.accent) : VKColors.accent,
                            pack != nil ? (Color(hex: pack!.bubbleOutgoingHex) ?? VKColors.accent) : VKColors.accent.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor)
                        .lineLimit(1)

                    Text("Тема оформления OpenVK (.themepack)")
                        .font(.system(size: 11))
                        .foregroundColor((message.out ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor).opacity(0.7))
                        .lineLimit(1)
                }
            }

            Button(action: {
                if let p = pack {
                    onPreviewTheme?(p)
                } else if let url = docURL {
                    Task {
                        if let (data, _) = try? await URLSession.shared.data(from: url),
                           let decoded = try? JSONDecoder().decode(VKThemePack.self, from: data) {
                            await MainActor.run {
                                onPreviewTheme?(decoded)
                            }
                        }
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11))
                    Text("Предпросмотр темы...")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(pack != nil ? (Color(hex: pack!.accentHex) ?? VKColors.accent) : VKColors.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func replyBlockView(_ reply: VKReplyMessage) -> some View {
        let photoUrl = resolvedPhotoUrl(for: reply)
        let avatarUrl = resolvedAvatarUrl(for: reply)
        let date = resolvedDate(for: reply)
        let hasPhoto = resolvedHasPhoto(for: reply)
        let replySnippet: String = reply.text.isEmpty ? (hasPhoto ? "Фотография" : "Вложение") : reply.text

        Button(action: {
            onJumpToMessage?(reply.id)
        }) {
            VStack(alignment: .leading, spacing: 3) {
                // Row 1: Avatar + Name + Date
                HStack(spacing: 5) {
                    if let aUrl = avatarUrl {
                        AsyncImage(url: aUrl) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Circle().fill(theme.replyAuthorNameColor(isOutgoingBubble: message.out).opacity(0.3))
                            }
                        }
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                    }

                    Text(reply.senderName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(theme.replyAuthorNameColor(isOutgoingBubble: message.out))
                        .lineLimit(1)

                    if let d = date {
                        Text(formattedWallDate(d))
                            .font(.system(size: 10))
                            .foregroundColor(theme.replyDateColor(isOutgoingBubble: message.out))
                            .lineLimit(1)
                    }
                }

                // Row 2: Photo thumbnail (if any) + Text
                HStack(spacing: 6) {
                    if let pUrl = photoUrl {
                        AsyncImage(url: pUrl) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            case .failure:
                                Rectangle()
                                    .fill(theme.replyBoxBackground(isOutgoingBubble: message.out))
                                    .overlay(Image(systemName: "photo").font(.system(size: 9)).foregroundColor(theme.replyDateColor(isOutgoingBubble: message.out)))
                            default:
                                ProgressView().controlSize(.mini)
                            }
                        }
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Text(replySnippet)
                        .font(.system(size: 11.5))
                        .foregroundColor(theme.replyTextColor(isOutgoingBubble: message.out))
                        .lineLimit(2)
                }
            }
            .padding(.leading, 8)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(theme.replyAuthorNameColor(isOutgoingBubble: message.out))
                    .frame(width: 2.5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.replyBoxBackground(isOutgoingBubble: message.out))
            )
        }
        .buttonStyle(.plain)
    }

    private func resolvedPhotoUrl(for reply: VKReplyMessage) -> URL? {
        if let u = reply.photoURL { return u }
        if let peerId = store?.selectedPeerId, let list = store?.messages[peerId] {
            if let orig = list.first(where: { $0.id == reply.id }) {
                return orig.photo?.url
            }
        }
        return nil
    }

    private var maxBubbleWidth: CGFloat {
        #if os(macOS)
        return 520
        #else
        return min(UIScreen.main.bounds.width * 0.82, 420)
        #endif
    }

    private func resolvedAvatarUrl(for reply: VKReplyMessage) -> URL? {
        if let u = reply.senderAvatarURL { return u }
        if let peerId = store?.selectedPeerId, let list = store?.messages[peerId] {
            if let orig = list.first(where: { $0.id == reply.id }) {
                return orig.sender?.photoURL
            }
        }
        return nil
    }

    private func resolvedDate(for reply: VKReplyMessage) -> Date? {
        if let d = reply.date { return d }
        if let peerId = store?.selectedPeerId, let list = store?.messages[peerId] {
            if let orig = list.first(where: { $0.id == reply.id }) {
                return orig.date
            }
        }
        return nil
    }

    private func resolvedHasPhoto(for reply: VKReplyMessage) -> Bool {
        reply.hasPhoto || resolvedPhotoUrl(for: reply) != nil
    }

    private var replyButton: some View {
        Button(action: { onReply?(message) }) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 11))
                .foregroundColor(VKColors.textSecondary)
                .frame(width: 26, height: 26)
                .background(VKColors.surface)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .help("Ответить")
    }

    @ViewBuilder
    private var deliveryStatusView: some View {
        if message.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 9))
                .foregroundColor(.red)
        } else if message.id <= 0 {
            Image(systemName: "clock")
                .font(.system(size: 8.5))
                .foregroundColor(theme.chatTimestampColor)
                .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)
        } else if message.isRead {
            // Read: Iconic double checkmark
            HStack(spacing: -4.5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8.5, weight: .bold))
                Image(systemName: "checkmark")
                    .font(.system(size: 8.5, weight: .bold))
            }
            .foregroundColor(theme.chatAuthorNameColor(for: 0, baseColor: VKColors.accent))
            .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)
        } else {
            // Sent / Unread: Single checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(theme.chatTimestampColor)
                .chatReadabilityShadow(isDark: theme.isChatBackgroundDark)
        }
    }

    private func isEmojiOnly(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "😃" || trimmed == "👍" || trimmed == "❤️"
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formattedWallDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "сегодня в \(timeStr)"
        } else if calendar.isDateInYesterday(date) {
            return "вчера в \(timeStr)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "ru_RU")
            dayFormatter.dateFormat = "d MMM"
            return "\(dayFormatter.string(from: date)), \(timeStr)"
        }
    }

    private func formatMessageWithLinks(_ text: String) -> AttributedString {
        var result = AttributedString()
        let pattern = #"\\[(id|club)(\d+)\\|([^\\]]+)\\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return buildAttrWithDetector(text)
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        if matches.isEmpty {
            return buildAttrWithDetector(text)
        }

        var lastIndex = 0
        let myId = store?.api.currentUser?.id ?? OpenVKAPIService.shared.currentUser?.id ?? 0

        for match in matches {
            let beforeRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
            if beforeRange.length > 0 {
                let sub = nsString.substring(with: beforeRange)
                result.append(buildAttrWithDetector(sub))
            }

            let typeStr = nsString.substring(with: match.range(at: 1))
            let idStr = nsString.substring(with: match.range(at: 2))
            let nameStr = nsString.substring(with: match.range(at: 3))
            let rawId = Int(idStr) ?? 0
            let targetId = typeStr == "club" ? -rawId : rawId

            var mentionAttr = AttributedString("@\(nameStr)")
            let mentionColor = theme.chatAuthorNameColor(for: targetId, baseColor: VKColors.accent)
            mentionAttr.foregroundColor = mentionColor
            mentionAttr.font = .system(size: 14, weight: .semibold)
            if targetId == myId && myId > 0 {
                mentionAttr.backgroundColor = VKColors.accent.opacity(0.2)
            }
            if let url = URL(string: "https://openvk.su/\(typeStr)\(idStr)") {
                mentionAttr.link = url
            }
            result.append(mentionAttr)

            lastIndex = match.range.location + match.range.length
        }

        if lastIndex < nsString.length {
            let remSub = nsString.substring(from: lastIndex)
            result.append(buildAttrWithDetector(remSub))
        }

        return result
    }

    private func buildAttrWithDetector(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attr
        }

        let nsString = text as NSString
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard let range = Range(match.range, in: text),
                  let attrRange = Range(range, in: attr),
                  let url = match.url else { continue }
            attr[attrRange].link = url
            attr[attrRange].underlineStyle = .single
        }
        return attr
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) Б" }
        if bytes < 1024 * 1024 { return String(format: "%.1f КБ", Double(bytes) / 1024.0) }
        return String(format: "%.1f МБ", Double(bytes) / (1024.0 * 1024.0))
    }

    private var senderFullName: String {
        if let name = message.sender?.fullName, !name.isEmpty {
            return name
        }
        if let cached = OpenVKAPIService.shared.cachedUsers[message.fromId], !cached.fullName.isEmpty {
            return cached.fullName
        }
        if message.fromId < 0 {
            let gid = abs(message.fromId)
            if let g = OpenVKAPIService.shared.cachedGroups[gid] {
                return g.name
            }
            if let conv = (store?.conversations ?? MessengerStore.shared.conversations).first(where: { $0.peerId == message.fromId }) {
                return conv.title
            }
        }
        return "Пользователь"
    }

    private var senderAvatarURL: URL? {
        if let url = message.sender?.avatarURL ?? OpenVKAPIService.shared.cachedUsers[message.fromId]?.avatarURL {
            return url
        }
        if message.fromId < 0 {
            let gid = abs(message.fromId)
            if let g = OpenVKAPIService.shared.cachedGroups[gid] {
                return g.avatarURL
            }
            if let conv = (store?.conversations ?? MessengerStore.shared.conversations).first(where: { $0.peerId == message.fromId }) {
                return conv.avatarURL
            }
        }
        return nil
    }

    private func openPhotoInViewer(photo: VKPhotoAttachment) {
        guard let list = store?.messages[message.peerId] ?? MessengerStore.shared.messages[message.peerId] else {
            let item = PhotoViewerItem(
                id: "\(message.id)_\(photo.id)",
                imageURL: photo.url,
                localImage: photo.localImage,
                caption: message.text,
                authorName: senderFullName,
                date: message.date
            )
            PhotoViewerService.shared.open(items: [item], initialIndex: 0)
            return
        }

        var photoItems: [PhotoViewerItem] = []
        for msg in list {
            let msgPhotos = !msg.photos.isEmpty ? msg.photos : (msg.photo != nil ? [msg.photo!] : [])
            for (pIdx, p) in msgPhotos.enumerated() {
                let author = msg.sender?.fullName ?? (msg.out ? "Вы" : "Пользователь")
                let item = PhotoViewerItem(
                    id: "\(msg.id)_\(p.id)_\(pIdx)",
                    imageURL: p.url,
                    localImage: p.localImage,
                    caption: msg.text,
                    authorName: author,
                    date: msg.date
                )
                photoItems.append(item)
            }
        }

        let targetIdx = photoItems.firstIndex(where: {
            ($0.imageURL != nil && $0.imageURL == photo.url) ||
            ($0.localImage != nil && $0.localImage == photo.localImage) ||
            $0.id.starts(with: "\(message.id)_\(photo.id)")
        }) ?? 0

        PhotoViewerService.shared.open(items: photoItems, initialIndex: targetIdx)
    }

    private func openVideoInPlayer(video: VKVideoAttachment) {
        let item = VideoPlayerItem(
            id: "\(video.ownerId)_\(video.id)",
            title: video.title,
            subtitle: video.duration > 0 ? "Видео • \(formatVideoDuration(video.duration))" : "Видеозапись",
            videoURL: video.directVideoURL,
            playerWebURL: video.playerURL,
            thumbnailURL: video.imageURL,
            duration: video.duration,
            ownerId: video.ownerId,
            videoId: video.id,
            accessKey: video.accessKey
        )
        VideoPlayerService.shared.open(item: item)
    }

    private func formatVideoDuration(_ dur: Int) -> String {
        let mins = dur / 60
        let secs = dur % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func collectAllChatAudioTracks() -> [AudioTrackItem] {
        guard let list = store?.messages[message.peerId] ?? MessengerStore.shared.messages[message.peerId] else { return [] }
        var tracks: [AudioTrackItem] = []
        for msg in list {
            if let a = msg.audio, let u = a.url {
                tracks.append(AudioTrackItem(
                    id: "audio_\(a.id)_\(msg.id)",
                    title: a.title,
                    artist: a.artist,
                    duration: Double(a.duration),
                    url: u
                ))
            }
        }
        return tracks
    }
}

// MARK: - Interactive Audio & Voice Track Player
public struct VKAudioTrackView: View {
    public let id: String
    public let title: String
    public let subtitle: String
    public let duration: Int
    public let url: URL?
    public var allChatTracks: [AudioTrackItem]
    public var isOutgoing: Bool

    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var theme = ThemeManager.shared

    public init(id: String, title: String, subtitle: String, duration: Int, url: URL?, allChatTracks: [AudioTrackItem] = [], isOutgoing: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.url = url
        self.allChatTracks = allChatTracks
        self.isOutgoing = isOutgoing
    }

    private var isThisTrackActive: Bool {
        player.activeId == id
    }

    private var isPlaying: Bool {
        isThisTrackActive && player.isPlaying
    }

    private var progress: Double {
        guard isThisTrackActive, player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }

    public var body: some View {
        let btnBg = theme.replyAuthorNameColor(isOutgoingBubble: isOutgoing)
        let textCol = isOutgoing ? theme.bubbleOutgoingTextColor : theme.bubbleIncomingTextColor

        if subtitle.isEmpty {
            // MARK: - Telegram Mobile Voice Message
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    // Circular play button
                    Button(action: {
                        if let url = url {
                            if isThisTrackActive {
                                player.toggleCurrentPlayback()
                            } else {
                                let item = AudioTrackItem(id: id, title: title, artist: subtitle, duration: Double(duration), url: url)
                                player.playTrack(item: item, in: allChatTracks)
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(btnBg)
                                .frame(width: 36, height: 36)

                            if isThisTrackActive && player.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(theme.textOnColor(btnBg))
                            } else {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(theme.textOnColor(btnBg))
                                    .offset(x: isPlaying ? 0 : 1)
                            }
                        }
                        .shadow(color: btnBg.opacity(0.25), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(url == nil)

                    // Vertical Waveform Bars
                    voiceWaveformView(btnBg: btnBg)

                    // "Aa" Speech-to-text badge
                    Text("Aa")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(btnBg)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(btnBg.opacity(0.12))
                        .clipShape(Capsule())
                }

                // Time info below waveform
                HStack {
                    Text(timeDisplay)
                        .font(.system(size: 11))
                        .foregroundColor(textCol.opacity(0.72))
                        .padding(.leading, 44)

                    Spacer()

                    Text(formatDuration(duration))
                        .font(.system(size: 11))
                        .foregroundColor(textCol.opacity(0.72))
                }
            }
            .padding(.vertical, 2)
            .frame(minWidth: 190, maxWidth: 260)
        } else {
            // MARK: - Regular Audio Track Player
            HStack(spacing: 10) {
                Button(action: {
                    if let url = url {
                        if isThisTrackActive {
                            player.toggleCurrentPlayback()
                        } else {
                            let item = AudioTrackItem(id: id, title: title, artist: subtitle, duration: Double(duration), url: url)
                            player.playTrack(item: item, in: allChatTracks)
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(btnBg)
                            .frame(width: 34, height: 34)

                        if isThisTrackActive && player.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(theme.textOnColor(btnBg))
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(theme.textOnColor(btnBg))
                                .offset(x: isPlaying ? 0 : 1)
                        }
                    }
                    .shadow(color: btnBg.opacity(0.3), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(url == nil)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title)
                            .font(VKTypography.subhead)
                            .foregroundColor(textCol)
                            .lineLimit(1)
                        Spacer()
                        Text(timeDisplay)
                            .font(VKTypography.caption)
                            .foregroundColor(textCol.opacity(0.75))
                    }

                    // Interactive Progress Bar / Scrubber
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(textCol.opacity(0.22))
                                .frame(height: 4)

                            Capsule()
                                .fill(btnBg)
                                .frame(width: max(geo.size.width * CGFloat(progress), 0), height: 4)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard isThisTrackActive, player.duration > 0 else { return }
                                    let pct = min(max(Double(value.location.x / geo.size.width), 0), 1)
                                    player.seek(to: pct * player.duration)
                                }
                        )
                    }
                    .frame(height: 6)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(VKTypography.caption)
                            .foregroundColor(textCol.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .frame(minWidth: 170, maxWidth: 260)
            }
            .padding(.vertical, 4)
        }
    }

    private func voiceWaveformView(btnBg: Color) -> some View {
        let barHeights: [CGFloat] = [
            4, 6, 11, 7, 14, 18, 10, 15, 19, 13, 7, 15, 20, 16, 9, 12, 17, 14, 8, 11, 16, 12, 7, 8, 13, 10, 6, 4, 7, 5
        ]
        return GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barHeights.count, id: \.self) { idx in
                    let fraction = Double(idx) / Double(barHeights.count)
                    let isPassed = isThisTrackActive && fraction <= progress
                    Capsule()
                        .fill(isPassed ? btnBg : btnBg.opacity(0.35))
                        .frame(width: 2.2, height: barHeights[idx])
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isThisTrackActive, player.duration > 0 else { return }
                        let pct = min(max(Double(value.location.x / geo.size.width), 0), 1)
                        player.seek(to: pct * player.duration)
                    }
            )
        }
        .frame(height: 22)
    }

    private var timeDisplay: String {
        if isThisTrackActive && player.currentTime > 0 {
            return formatDuration(Int(player.currentTime))
        }
        return formatDuration(duration)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
