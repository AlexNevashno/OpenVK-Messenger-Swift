import SwiftUI

public struct VKConversationInfoView: View {
    @ObservedObject public var store: MessengerStore
    public let conversation: VKConversation
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var photoViewer = PhotoViewerService.shared
    @ObservedObject private var videoPlayer = VideoPlayerService.shared

    @State private var memberSearchText = ""
    @State private var selectedTab: InfoTab = .members
    @State private var isLeaveAlertPresented = false

    // Materials state
    @State private var selectedMaterialTab: MaterialSubTab = .photos
    @State private var materialsPhotos: [ConversationMaterialItem] = []
    @State private var materialsVideos: [ConversationMaterialItem] = []
    @State private var materialsAudio: [ConversationMaterialItem] = []
    @State private var materialsDocs: [ConversationMaterialItem] = []
    @State private var isLoadingMedia: Bool = false
    @State private var hasLoadedMedia: Bool = false

    private enum InfoTab: String, CaseIterable {
        case members = "Участники"
        case media = "Материалы"
    }

    private enum MaterialSubTab: String, CaseIterable, Identifiable {
        case photos = "Фото"
        case videos = "Видео"
        case audio = "Аудио"
        case docs = "Файлы"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .photos: return "photo"
            case .videos: return "video"
            case .audio: return "music.note"
            case .docs: return "doc"
            }
        }
    }

    public struct ConversationMaterialItem: Identifiable, Hashable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let thumbnailURL: URL?
        public let contentURL: URL?
        public let ext: String?

        public init(id: String, title: String, subtitle: String, thumbnailURL: URL? = nil, contentURL: URL? = nil, ext: String? = nil) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.thumbnailURL = thumbnailURL
            self.contentURL = contentURL
            self.ext = ext
        }
    }

    public init(store: MessengerStore, conversation: VKConversation) {
        self.store = store
        self.conversation = conversation
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Text(conversation.isSavedMessages ? "Избранное" : (conversation.isChat ? "Информация о беседе" : "Информация"))
                    .font(VKTypography.headline)
                    .foregroundColor(VKColors.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(VKColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Hero Profile Card (Avatar + Title + Count)
                    VStack(spacing: 8) {
                        VKAvatarView(
                            url: conversation.avatarURL,
                            name: conversation.displayTitle,
                            size: 76,
                            isSavedMessages: conversation.isSavedMessages
                        )

                        Text(conversation.displayTitle)
                            .font(VKTypography.title)
                            .foregroundColor(VKColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        if conversation.isSavedMessages {
                            Text("Сохранённые сообщения")
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                        } else if let details = store.activeChatDetails {
                            Text(pluralizeMembers(details.membersCount))
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                        } else if let count = conversation.membersCount {
                            Text(pluralizeMembers(count))
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                        } else if !conversation.isChat {
                            Text(conversation.isOnline ? "в сети" : "был(а) недавно")
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                        }
                    }
                    .padding(.top, 16)

                    // MARK: - Quick Action Buttons (VKUI Milkshake round buttons)
                    HStack(spacing: 24) {
                        QuickActionButton(
                            icon: store.isMuted(peerId: conversation.peerId) ? "bell.slash.fill" : "bell.fill",
                            label: store.isMuted(peerId: conversation.peerId) ? "Вкл. звук" : "Без звука"
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.toggleMute(peerId: conversation.peerId)
                            }
                        }
                        QuickActionButton(icon: "magnifyingglass", label: "Поиск") {
                            dismiss()
                            store.isMessageSearchActive = true
                        }
                        if conversation.isChat {
                            QuickActionButton(icon: "link", label: "Ссылка") {}
                        }
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .padding(.horizontal, 16)

                    // MARK: - Tabs Switcher
                    Picker("", selection: $selectedTab) {
                        if conversation.isChat {
                            Text("Участники (\(store.activeChatDetails?.membersCount ?? conversation.membersCount ?? 0))").tag(InfoTab.members)
                        } else {
                            Text("Профиль").tag(InfoTab.members)
                        }
                        Text("Материалы").tag(InfoTab.media)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .onChange(of: selectedTab) { _ in
                        if selectedTab == .media && !hasLoadedMedia {
                            loadMaterials()
                        }
                    }

                    if selectedTab == .members {
                        if conversation.isChat {
                            membersSection
                        } else {
                            directChatDetailsSection
                        }
                    } else {
                        mediaSection
                    }
                }
            }

            // MARK: - Bottom Action (Leave Chat)
            if conversation.isChat {
                Divider()

                HStack {
                    Button(action: {
                        isLeaveAlertPresented = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15))
                            Text("Покинуть беседу")
                                .font(VKTypography.headline)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(VKColors.surface)
            }
        }
        #if os(macOS)
        .frame(width: 520, height: 700)
        #endif
        .background(VKColors.surface)
        .alert("Покинуть беседу?", isPresented: $isLeaveAlertPresented) {
            Button("Отмена", role: .cancel) {}
            Button("Покинуть", role: .destructive) {
                leaveChat()
            }
        } message: {
            Text("Вы уверены, что хотите выйти из беседы «\(conversation.title)»?")
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $photoViewer.isOpen) {
            PhotoViewerWindowView(onClose: {
                photoViewer.close()
            })
        }
        .fullScreenCover(isPresented: $videoPlayer.isOpen) {
            VideoPlayerWindowView(onClose: {
                videoPlayer.close()
            })
        }
        #endif
        .onAppear {
            if conversation.isChat {
                Task {
                    await store.fetchChatDetails(for: conversation.peerId)
                }
            }
            loadMaterials()
        }
    }

    // MARK: - Members Section
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(VKColors.textSecondary)
                TextField("Поиск участников...", text: $memberSearchText)
                    .textFieldStyle(.plain)
                    .font(VKTypography.subhead)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(VKColors.secondarySurface)
            .cornerRadius(8)
            .padding(.horizontal, 16)

            if store.isLoadingChatDetails {
                HStack {
                    Spacer()
                    ProgressView("Загрузка участников...")
                        .font(VKTypography.caption)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                let members = filteredMembers
                LazyVStack(spacing: 2) {
                    ForEach(members) { member in
                        MemberRowView(member: member)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Direct Chat Section
    private var directChatDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ссылка на страницу")
                    .font(VKTypography.caption)
                    .foregroundColor(VKColors.textSecondary)

                let base = store.api.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                Button(action: {
                    if let url = URL(string: "\(base)/id\(conversation.peerId)") {
                        PlatformURLOpener.open(url)
                    }
                }) {
                    Text("\(base)/id\(conversation.peerId)")
                        .font(VKTypography.subhead)
                        .foregroundColor(VKColors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VKColors.secondarySurface)
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Media Section (Материалы беседы)
    private var mediaSection: some View {
        VStack(spacing: 12) {
            // Sub-tabs: Фото, Видео, Аудио, Файлы
            HStack(spacing: 6) {
                ForEach(MaterialSubTab.allCases) { subTab in
                    Button(action: {
                        selectedMaterialTab = subTab
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: subTab.icon)
                                .font(.system(size: 11))
                            Text("\(subTab.rawValue) (\(materialCount(for: subTab)))")
                                .font(VKTypography.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedMaterialTab == subTab ? VKColors.secondarySurface : Color.clear)
                        .foregroundColor(selectedMaterialTab == subTab ? VKColors.accent : VKColors.textSecondary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            Divider()
                .padding(.horizontal, 16)

            if isLoadingMedia && !hasLoadedMedia {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Загрузка материалов...")
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)
                }
                .padding(.vertical, 40)
            } else {
                switch selectedMaterialTab {
                case .photos:
                    photosGridView
                case .videos:
                    videosListView
                case .audio:
                    audioListView
                case .docs:
                    docsListView
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Photos Grid View
    private var photosGridView: some View {
        Group {
            if materialsPhotos.isEmpty {
                emptyMaterialsView(title: "Нет фотографий", subtitle: "В этой беседе пока нет отправленных фотографий")
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(Array(materialsPhotos.enumerated()), id: \.element.id) { index, item in
                        Button(action: {
                            openPhotoInViewer(index: index)
                        }) {
                            GeometryReader { geo in
                                if let url = item.thumbnailURL {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: geo.size.width, height: geo.size.width)
                                                .clipped()
                                        default:
                                            Rectangle()
                                                .fill(VKColors.secondarySurface)
                                                .frame(width: geo.size.width, height: geo.size.width)
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .foregroundColor(VKColors.textSecondary)
                                                )
                                        }
                                    }
                                } else {
                                    Rectangle()
                                        .fill(VKColors.secondarySurface)
                                        .frame(width: geo.size.width, height: geo.size.width)
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Videos List View
    private var videosListView: some View {
        Group {
            if materialsVideos.isEmpty {
                emptyMaterialsView(title: "Нет видеозаписей", subtitle: "В этой беседе пока нет видеозаписей")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(materialsVideos.enumerated()), id: \.element.id) { index, item in
                        Button(action: {
                            openVideoInPlayer(index: index)
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    if let thumb = item.thumbnailURL {
                                        AsyncImage(url: thumb) { phase in
                                            switch phase {
                                            case .success(let img):
                                                img
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 56)
                                                    .clipped()
                                                    .cornerRadius(6)
                                            default:
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(VKColors.secondarySurface)
                                                    .frame(width: 80, height: 56)
                                            }
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(VKColors.secondarySurface)
                                            .frame(width: 80, height: 56)
                                    }

                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.55))
                                        .clipShape(Circle())
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(VKTypography.subhead)
                                        .foregroundColor(VKColors.textPrimary)
                                        .lineLimit(1)

                                    Text(item.subtitle)
                                        .font(VKTypography.caption)
                                        .foregroundColor(VKColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(VKColors.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(VKColors.secondarySurface)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Audio List View
    private var audioListView: some View {
        Group {
            if materialsAudio.isEmpty {
                emptyMaterialsView(title: "Нет музыки", subtitle: "В этой беседе пока нет аудиозаписей")
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(materialsAudio) { item in
                        Button(action: {
                            if let url = item.contentURL {
                                PlatformURLOpener.open(url)
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 15))
                                    .foregroundColor(VKColors.accent)
                                    .frame(width: 36, height: 36)
                                    .background(VKColors.secondarySurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(VKTypography.subhead)
                                        .foregroundColor(VKColors.textPrimary)
                                        .lineLimit(1)

                                    Text(item.subtitle)
                                        .font(VKTypography.caption)
                                        .foregroundColor(VKColors.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if item.contentURL != nil {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(VKColors.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(VKColors.secondarySurface)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Docs List View
    private var docsListView: some View {
        Group {
            if materialsDocs.isEmpty {
                emptyMaterialsView(title: "Нет файлов", subtitle: "В этой беседе пока нет документов или файлов")
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(materialsDocs) { item in
                        Button(action: {
                            if let url = item.contentURL {
                                PlatformURLOpener.open(url)
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(VKColors.accent)
                                    .frame(width: 36, height: 36)
                                    .background(VKColors.secondarySurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(VKTypography.subhead)
                                        .foregroundColor(VKColors.textPrimary)
                                        .lineLimit(1)

                                    Text(item.subtitle)
                                        .font(VKTypography.caption)
                                        .foregroundColor(VKColors.textSecondary)
                                }

                                Spacer()

                                if item.contentURL != nil {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(VKColors.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(VKColors.secondarySurface)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func emptyMaterialsView(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: selectedMaterialTab.icon)
                .font(.system(size: 38))
                .foregroundColor(VKColors.textSecondary.opacity(0.6))
                .padding(.top, 24)

            Text(title)
                .font(VKTypography.headline)
                .foregroundColor(VKColors.textPrimary)

            Text(subtitle)
                .font(VKTypography.caption)
                .foregroundColor(VKColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 30)
    }

    private func materialCount(for tab: MaterialSubTab) -> Int {
        switch tab {
        case .photos: return materialsPhotos.count
        case .videos: return materialsVideos.count
        case .audio: return materialsAudio.count
        case .docs: return materialsDocs.count
        }
    }

    private func loadMaterials() {
        isLoadingMedia = true
        let peerId = conversation.peerId
        let base = store.api.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        Task {
            // 1. Fetch remote attachments via API
            let remotePhotos = (try? await store.api.getHistoryAttachments(peerId: peerId, mediaType: "photo")) ?? []
            let remoteVideos = (try? await store.api.getHistoryAttachments(peerId: peerId, mediaType: "video")) ?? []
            let remoteAudio = (try? await store.api.getHistoryAttachments(peerId: peerId, mediaType: "audio")) ?? []
            let remoteDocs = (try? await store.api.getHistoryAttachments(peerId: peerId, mediaType: "doc")) ?? []

            var photos: [ConversationMaterialItem] = remotePhotos.map {
                ConversationMaterialItem(
                    id: $0.id,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    thumbnailURL: $0.thumbnailURL,
                    contentURL: $0.thumbnailURL
                )
            }

            var videos: [ConversationMaterialItem] = remoteVideos.map {
                ConversationMaterialItem(
                    id: $0.id,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    thumbnailURL: $0.thumbnailURL,
                    contentURL: $0.thumbnailURL
                )
            }

            var audios: [ConversationMaterialItem] = remoteAudio.map {
                ConversationMaterialItem(
                    id: $0.id,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    thumbnailURL: nil,
                    contentURL: nil
                )
            }

            var docs: [ConversationMaterialItem] = remoteDocs.map {
                ConversationMaterialItem(
                    id: $0.id,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    thumbnailURL: nil,
                    contentURL: nil
                )
            }

            // 2. Extract attachments from local messages in store
            if let msgs = store.messages[peerId] {
                for m in msgs {
                    if let p = m.photo, let url = p.url {
                        let id = "photo_\(p.id)"
                        if !photos.contains(where: { $0.id == id || $0.thumbnailURL == url }) {
                            photos.append(ConversationMaterialItem(
                                id: id,
                                title: p.text.isEmpty ? "Фотография" : p.text,
                                subtitle: "Фото",
                                thumbnailURL: url,
                                contentURL: url
                            ))
                        }
                    }
                    if let v = m.video {
                        let id = "video_\(v.ownerId)_\(v.id)"
                        if !videos.contains(where: { $0.id == id }) {
                            let mins = v.duration / 60
                            let secs = v.duration % 60
                            videos.append(ConversationMaterialItem(
                                id: id,
                                title: v.title,
                                subtitle: String(format: "%d:%02d", mins, secs),
                                thumbnailURL: v.imageURL,
                                contentURL: v.directVideoURL ?? v.playerURL ?? v.imageURL
                            ))
                        }
                    }
                    if let a = m.audio {
                        let id = "audio_\(a.ownerId)_\(a.id)"
                        if !audios.contains(where: { $0.id == id }) {
                            let mins = a.duration / 60
                            let secs = a.duration % 60
                            audios.append(ConversationMaterialItem(
                                id: id,
                                title: a.title,
                                subtitle: "\(a.artist) • \(String(format: "%d:%02d", mins, secs))",
                                thumbnailURL: nil,
                                contentURL: a.url
                            ))
                        }
                    }
                    if let d = m.doc {
                        let id = "doc_\(d.id)"
                        if !docs.contains(where: { $0.id == id }) {
                            docs.append(ConversationMaterialItem(
                                id: id,
                                title: d.title,
                                subtitle: formatFileSize(d.size),
                                thumbnailURL: nil,
                                contentURL: d.url,
                                ext: d.ext
                            ))
                        }
                    }
                }
            }

            await MainActor.run {
                self.materialsPhotos = photos
                self.materialsVideos = videos
                self.materialsAudio = audios
                self.materialsDocs = docs
                self.isLoadingMedia = false
                self.hasLoadedMedia = true
            }
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) Б" }
        if bytes < 1024 * 1024 { return String(format: "%.1f КБ", Double(bytes) / 1024.0) }
        return String(format: "%.1f МБ", Double(bytes) / (1024.0 * 1024.0))
    }

    private func openPhotoInViewer(index: Int) {
        let photoItems: [PhotoViewerItem] = materialsPhotos.enumerated().compactMap { (idx, m) in
            guard let url = m.contentURL ?? m.thumbnailURL else { return nil }
            return PhotoViewerItem(
                id: "\(m.id)_\(idx)",
                imageURL: url,
                caption: m.title.starts(with: "Фотография #") ? "" : m.title,
                authorName: conversation.displayTitle,
                date: Date()
            )
        }
        guard !photoItems.isEmpty else { return }
        let targetIdx = min(max(0, index), photoItems.count - 1)
        PhotoViewerService.shared.open(items: photoItems, initialIndex: targetIdx)
    }

    private func openVideoInPlayer(index: Int) {
        let videoItems: [VideoPlayerItem] = materialsVideos.enumerated().map { (idx, v) in
            var cleanId = v.id
            if cleanId.hasPrefix("video_") {
                cleanId = String(cleanId.dropFirst(6))
            } else if cleanId.hasPrefix("video") {
                cleanId = String(cleanId.dropFirst(5))
            }
            let parts = cleanId.split(separator: "_")
            let oid = parts.count > 0 ? Int(parts[0]) : nil
            let vid = parts.count > 1 ? Int(parts[1]) : nil
            let isDirectMp4 = v.contentURL?.pathExtension.lowercased() == "mp4"

            return VideoPlayerItem(
                id: "\(v.id)_\(idx)",
                title: v.title,
                subtitle: v.subtitle,
                videoURL: isDirectMp4 ? v.contentURL : nil,
                playerWebURL: !isDirectMp4 ? v.contentURL : nil,
                thumbnailURL: v.thumbnailURL,
                duration: 0,
                ownerId: oid,
                videoId: vid,
                accessKey: nil
            )
        }
        guard !videoItems.isEmpty else { return }
        let targetIdx = min(max(0, index), videoItems.count - 1)
        VideoPlayerService.shared.open(items: videoItems, initialIndex: targetIdx)
    }

    private var filteredMembers: [VKChatMember] {
        guard let list = store.activeChatDetails?.members else { return [] }
        if memberSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return list
        }
        let query = memberSearchText.lowercased()
        return list.filter {
            ($0.user?.fullName.lowercased().contains(query) ?? false)
        }
    }

    private func leaveChat() {
        let chatId = conversation.peerId - 2_000_000_000
        guard let myId = store.api.currentUser?.id else { return }
        Task {
            do {
                let _: VKIntOrBool = try await store.api.callMethod(
                    method: "messages.removeChatUser",
                    params: [
                        "chat_id": "\(chatId)",
                        "user_id": "\(myId)"
                    ]
                )
                dismiss()
                await store.fetchConversations()
            } catch {
                print("DEBUG: Failed to leave chat: \(error)")
            }
        }
    }

    private func pluralizeMembers(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 { return "\(count) участников" }
        if mod10 == 1 { return "\(count) участник" }
        if mod10 >= 2 && mod10 <= 4 { return "\(count) участника" }
        return "\(count) участников"
    }
}

public struct MemberRowView: View {
    public let member: VKChatMember

    public var body: some View {
        HStack(spacing: 10) {
            VKAvatarView(
                url: member.user?.avatarURL,
                name: member.user?.fullName ?? "Пользователь",
                size: 38
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.user?.fullName ?? "Пользователь #\(member.id)")
                        .font(VKTypography.headline)
                        .foregroundColor(VKColors.textPrimary)
                        .lineLimit(1)

                    if member.user?.isVerified == true {
                        VKVerifiedBadge()
                    }
                }

                if member.isOwner {
                    Text("Создатель")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(VKColors.accent)
                } else if member.isAdmin {
                    Text("Администратор")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(VKColors.accent)
                } else {
                    Text(member.user?.isOnline == true ? "в сети" : "был(а) недавно")
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.clear)
        .cornerRadius(8)
    }
}

public struct QuickActionButton: View {
    public let icon: String
    public let label: String
    public let action: () -> Void

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(VKColors.accent)
                    .frame(width: 44, height: 44)
                    .background(VKColors.secondarySurface)
                    .clipShape(Circle())

                Text(label)
                    .font(VKTypography.caption)
                    .foregroundColor(VKColors.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}
