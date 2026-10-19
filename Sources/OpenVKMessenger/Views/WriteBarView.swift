import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import PhotosUI
#endif
import UniformTypeIdentifiers

public struct WriteBarView: View {
    @Binding public var text: String
    public let placeholder: String
    public let onSend: () -> Void
    public var onTyping: (() -> Void)? = nil
    @ObservedObject public var store: MessengerStore
    @ObservedObject private var theme = ThemeManager.shared
    public var onSendSticker: ((Int) -> Void)? = nil
    public var onSendMedia: ((String, String) -> Void)? = nil

    @State private var isPickerPresented = false
    @State private var isAttachSheetPresented = false
    @State private var inputHeight: CGFloat = 22
    @State private var isWebLoginPresented = false
    @State private var webLoginUsername = ""
    @State private var webLoginPassword = ""
    @State private var webLoginError: String? = nil
    @State private var isAuthenticatingWeb = false
    #if os(iOS)
    @State private var isPhotosPickerPresented = false
    @State private var selectedPhotosItems: [PhotosPickerItem] = []
    @State private var isDocumentPickerPresented = false
    #endif

    public init(
        text: Binding<String>,
        placeholder: String,
        onSend: @escaping () -> Void,
        onTyping: (() -> Void)? = nil,
        store: MessengerStore,
        onSendSticker: ((Int) -> Void)? = nil,
        onSendMedia: ((String, String) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSend = onSend
        self.onTyping = onTyping
        self.store = store
        self.onSendSticker = onSendSticker
        self.onSendMedia = onSendMedia
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Edit message banner (if active)
            if let editMsg = store.editingMessage {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(VKColors.accent)
                        .frame(width: 3, height: 32)

                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(VKColors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Редактирование")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(VKColors.accent)

                        Text(editMsg.text.isEmpty ? "Сообщение" : editMsg.text)
                            .font(.system(size: 11))
                            .foregroundColor(VKColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: {
                        store.editingMessage = nil
                        text = ""
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(VKColors.textSecondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .help("Отменить редактирование")
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 6)

                Divider()
                    .padding(.horizontal, 10)
            }

            // 1. Reply to message banner (if active)
            if let replyMsg = store.replyingToMessage {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(ThemeManager.shared.replyAuthorNameColor(isOutgoingBubble: false))
                        .frame(width: 3, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(replyMsg.sender?.fullName ?? "Пользователь")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ThemeManager.shared.replyAuthorNameColor(isOutgoingBubble: false))

                        Text(replyMsg.text.isEmpty ? "Вложение" : replyMsg.text)
                            .font(.system(size: 11))
                            .foregroundColor(VKColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: {
                        store.replyingToMessage = nil
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(VKColors.textSecondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .help("Отменить ответ")
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 6)

                Divider()
                    .padding(.horizontal, 10)
            }

            // 2. Pending Uploads Attachment Tray (Matches user's reference screenshot media_1791641555504_4c32faaf.png)
            if !store.pendingUploads.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.pendingUploads) { item in
                            ZStack {
                                if item.isDocument {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(VKColors.secondarySurface)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            VStack(spacing: 2) {
                                                Image(systemName: "doc.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(VKColors.accent)
                                                Text(URL(fileURLWithPath: item.filename).pathExtension.uppercased())
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(VKColors.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        )
                                } else {
                                    // Thumbnail Image
                                    Image(platformImage: item.preview)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                // Circular Progress Ring & Cancel Button
                                Button(action: {
                                    store.removePendingUpload(id: item.id)
                                }) {
                                    ZStack {
                                        // Dark circular backing (red if error)
                                        Circle()
                                            .fill(item.error != nil ? Color.red.opacity(0.85) : Color.black.opacity(0.48))
                                            .frame(width: 34, height: 34)

                                        if item.isUploading {
                                            // Circular background track
                                            Circle()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                                .frame(width: 26, height: 26)

                                            // White progress arc
                                            Circle()
                                                .trim(from: 0, to: CGFloat(max(0.06, min(item.progress, 1.0))))
                                                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                                .frame(width: 26, height: 26)
                                                .rotationEffect(.degrees(-90))
                                                .animation(.easeInOut(duration: 0.2), value: item.progress)

                                            // Centered '✕' cancel icon
                                            Image(systemName: "xmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                        } else if item.error != nil {
                                            // Error indicator
                                            Image(systemName: "exclamationmark")
                                                .font(.system(size: 14, weight: .black))
                                                .foregroundColor(.white)
                                        } else {
                                            // Upload completed cross
                                            Image(systemName: "xmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(item.error != nil ? "Ошибка загрузки: нажмите, чтобы удалить" : "Удалить фото")
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }

                if let err = store.pendingUploads.first(where: { $0.error != nil })?.error {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(err)
                            .font(VKTypography.caption)
                            .foregroundColor(VKColors.textSecondary)
                            .lineLimit(2)
                        Spacer()
                        if err.contains("веб-сессия") || err.contains("логину и паролю") {
                            Button("Войти") {
                                webLoginUsername = store.api.savedLogin ?? (store.api.currentUser != nil ? "id\(store.api.currentUser!.id)" : "")
                                webLoginPassword = ""
                                webLoginError = nil
                                isWebLoginPresented = true
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(VKColors.accent)
                            .buttonStyle(.plain)
                        }
                        Button("Убрать") {
                            store.pendingUploads.removeAll(where: { $0.error != nil })
                        }
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                }

                Divider()
                    .padding(.horizontal, 10)
            }

            // 3. Bottom Row: (+) [Input Field + Smiley] (Video/Mic/Send)
            HStack(alignment: .bottom, spacing: 8) {
                // (+) Attachment Menu Button
                Menu {
                    #if os(iOS)
                    Button(action: { isPhotosPickerPresented = true }) {
                        Label("Медиатека / Фото", systemImage: "photo.on.rectangle")
                    }
                    Button(action: { isDocumentPickerPresented = true }) {
                        Label("Файлы / Документы", systemImage: "folder")
                    }
                    #else
                    Button(action: pickPhotoFromComputer) {
                        Label("Фото с компьютера", systemImage: "photo")
                    }
                    Button(action: pickDocumentFromComputer) {
                        Label("Файл / Документ с компьютера", systemImage: "doc")
                    }
                    #endif
                    Button(action: pastePhotoFromClipboard) {
                        Label("Из буфера обмена", systemImage: "doc.on.clipboard")
                    }
                    Divider()
                    Button(action: { isAttachSheetPresented = true }) {
                        Label("Медиа с OpenVK (музыка, видео, документы)", systemImage: "rectangle.stack.badge.play")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 21, weight: .regular))
                        .foregroundColor(VKColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 36, height: 36)
                .help("Прикрепить фото или медиа")

                // Center: Capsule Text Field with embedded Smiley/Sticker button
                HStack(alignment: .center, spacing: 4) {
                    #if os(iOS)
                    TextField(placeholder, text: $text, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(1...5)
                        .submitLabel(.send)
                        .onSubmit {
                            handleSendAction()
                        }
                        .padding(.vertical, 7)
                        .padding(.leading, 12)
                        .onChange(of: text) { newText in
                            if !newText.isEmpty && isPickerPresented {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    isPickerPresented = false
                                }
                            }
                            if !newText.isEmpty {
                                onTyping?()
                            }
                        }
                    #else
                    VKChatInputTextView(
                        text: $text,
                        dynamicHeight: $inputHeight,
                        placeholder: placeholder,
                        onCommit: { handleSendAction() },
                        onTyping: onTyping,
                        onCancel: {
                            store.replyingToMessage = nil
                            if store.editingMessage != nil {
                                store.editingMessage = nil
                                text = ""
                            }
                        },
                        onPasteImage: { data, preview, filename in
                            store.startUploadingPhoto(data: data, preview: preview, filename: filename)
                        },
                        onPasteFiles: { urls in
                            for url in urls {
                                guard let data = try? Data(contentsOf: url) else { continue }
                                let ext = url.pathExtension.lowercased()
                                let filename = url.lastPathComponent
                                if ["jpg", "jpeg", "png", "heic", "webp"].contains(ext), let img = PlatformImage.from(data: data) {
                                    store.startUploadingPhoto(data: data, preview: img, filename: filename)
                                } else {
                                    store.startUploadingDocument(data: data, filename: filename)
                                }
                            }
                        }
                    )
                    .frame(height: min(max(inputHeight, 22), 100))
                    .padding(.vertical, 6)
                    .padding(.leading, 8)
                    #endif

                    // Emoji / Stickers button embedded inside the capsule (Telegram style)
                    Button(action: {
                        #if os(iOS)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isPickerPresented.toggle()
                        }
                        #else
                        isPickerPresented.toggle()
                        #endif
                    }) {
                        if isPickerPresented {
                            Image(systemName: "keyboard")
                                .font(.system(size: 20))
                                .foregroundColor(VKColors.accent)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        } else {
                            TelegramStickerIcon(color: VKColors.textSecondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .padding(.trailing, 4)
                    .help("Стикеры и эмодзи")
                    #if os(macOS)
                    .popover(isPresented: $isPickerPresented, arrowEdge: .top) {
                        VKEmojiStickerPickerView(
                            store: store,
                            onSelectEmoji: { emoji in
                                text.append(emoji)
                            },
                            onSelectSticker: { sid in
                                onSendSticker?(sid)
                                isPickerPresented = false
                            }
                        )
                    }
                    #endif
                }
                .frame(minHeight: 36)
                #if os(iOS)
                .background(Color(UIColor.secondarySystemBackground).opacity(0.96))
                #else
                .background(VKColors.secondarySurface)
                #endif
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(VKColors.separator.opacity(0.5), lineWidth: 0.5)
                )

                // Right Actions: Send button (appears dynamically when typing or pending media)
                if canSend {
                    Button(action: handleSendAction) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(VKColors.accent)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .layoutPriority(2)
                    .transition(.scale.combined(with: .opacity))
                    .help("Отправить")
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: canSend)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 6)

            #if os(iOS)
            if isPickerPresented {
                VKEmojiStickerPickerView(
                    store: store,
                    onSelectEmoji: { emoji in
                        text.append(emoji)
                    },
                    onSelectSticker: { sid in
                        onSendSticker?(sid)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif
        }
        #if os(iOS)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                VKColors.surface.opacity(0.96)
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(VKColors.separator.opacity(0.6))
                .frame(height: 0.33),
            alignment: .top
        )
        #else
        .background(.ultraThinMaterial.opacity(0.6))
        .background(VKColors.surface.opacity(0.92))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VKColors.separator.opacity(0.7), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 4)
        #endif
        .sheet(isPresented: $isAttachSheetPresented) {
            VKMediaAttachSheetView(
                store: store,
                onSendMedia: { attachmentCode, caption in
                    onSendMedia?(attachmentCode, caption)
                }
            )
        }
        .sheet(isPresented: $isWebLoginPresented) {
            VStack(spacing: 16) {
                Text("Вход в веб-сессию OpenVK")
                    .font(VKTypography.headline)

                Text("Для отправки документов и тем оформления серверу требуется веб-сессия. Введите ваш пароль от OpenVK:")
                    .font(VKTypography.caption)
                    .foregroundColor(VKColors.textSecondary)
                    .multilineTextAlignment(.center)

                #if os(macOS)
                TextField("Email или телефон", text: $webLoginUsername)
                    .textFieldStyle(.roundedBorder)
                    .font(VKTypography.body)

                SecureField("Пароль", text: $webLoginPassword)
                    .textFieldStyle(.roundedBorder)
                    .font(VKTypography.body)
                #else
                TextField("Email или телефон", text: $webLoginUsername)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .font(VKTypography.body)

                SecureField("Пароль", text: $webLoginPassword)
                    .textFieldStyle(.roundedBorder)
                    .font(VKTypography.body)
                #endif

                if let err = webLoginError {
                    Text(err)
                        .font(VKTypography.caption)
                        .foregroundColor(.red)
                }

                HStack(spacing: 12) {
                    Button("Отмена") {
                        isWebLoginPresented = false
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(VKColors.textSecondary)

                    Spacer()

                    Button(action: {
                        isAuthenticatingWeb = true
                        webLoginError = nil
                        Task {
                            let ok = await store.api.ensureWebSession(login: webLoginUsername, password: webLoginPassword)
                            await MainActor.run {
                                isAuthenticatingWeb = false
                                if ok {
                                    isWebLoginPresented = false
                                    // Retry any failed uploads
                                    let failed = store.pendingUploads.filter { $0.error != nil }
                                    store.pendingUploads.removeAll(where: { $0.error != nil })
                                    for item in failed {
                                        if item.isDocument {
                                            store.startUploadingDocument(data: item.data, filename: item.filename)
                                        } else {
                                            store.startUploadingPhoto(data: item.data, preview: item.preview, filename: item.filename)
                                        }
                                    }
                                } else {
                                    webLoginError = "Неверный логин или пароль, либо ошибка сессии."
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isAuthenticatingWeb {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isAuthenticatingWeb ? "Вход..." : "Подтвердить")
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(VKColors.accent)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthenticatingWeb || webLoginUsername.isEmpty || webLoginPassword.isEmpty)
                }
            }
            .padding(24)
            #if os(macOS)
            .frame(width: 360)
            #else
            .frame(maxWidth: 380)
            #endif
        }
        #if os(iOS)
        .photosPicker(
            isPresented: $isPhotosPickerPresented,
            selection: $selectedPhotosItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotosItems) { items in
            guard !items.isEmpty else { return }
            for item in items {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            let fname = "photo_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 100...999)).jpg"
                            store.startUploadingPhoto(data: data, preview: img, filename: fname)
                        }
                    }
                }
            }
            selectedPhotosItems = []
        }
        .fileImporter(
            isPresented: $isDocumentPickerPresented,
            allowedContentTypes: [.item, .content, .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task.detached(priority: .userInitiated) {
                    for url in urls {
                        guard url.startAccessingSecurityScopedResource() else { continue }
                        defer { url.stopAccessingSecurityScopedResource() }
                        guard let data = try? Data(contentsOf: url) else { continue }
                        let ext = url.pathExtension.lowercased()
                        let filename = url.lastPathComponent
                        await MainActor.run {
                            if ["jpg", "jpeg", "png", "heic", "webp"].contains(ext), let img = UIImage(data: data) {
                                store.startUploadingPhoto(data: data, preview: img, filename: filename)
                            } else {
                                store.startUploadingDocument(data: data, filename: filename)
                            }
                        }
                    }
                }
            case .failure(let err):
                print("WriteBar doc picker error: \(err)")
            }
        }
        #endif
        #if os(macOS)
        .onPasteCommand(of: [.image, .png, .tiff]) { _ in
            if let clip = MessengerStore.getClipboardImageData() {
                DispatchQueue.main.async {
                    store.startUploadingPhoto(data: clip.data, preview: clip.preview, filename: clip.filename)
                }
            }
        }
        #endif
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.pendingUploads.isEmpty
    }

    private func pickPhotoFromComputer() {
        #if os(macOS)
        let files = MessengerStore.pickLocalImageFiles()
        for file in files {
            store.startUploadingPhoto(data: file.data, preview: file.preview, filename: file.filename)
        }
        #endif
    }

    private func pickDocumentFromComputer() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item, .content, .data]
        panel.begin { response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task.detached(priority: .userInitiated) {
                for url in urls {
                    guard let data = try? Data(contentsOf: url) else { continue }
                    let ext = url.pathExtension.lowercased()
                    let filename = url.lastPathComponent
                    await MainActor.run {
                        if ["jpg", "jpeg", "png", "heic", "webp"].contains(ext), let img = NSImage(data: data) {
                            store.startUploadingPhoto(data: data, preview: img, filename: filename)
                        } else {
                            store.startUploadingDocument(data: data, filename: filename)
                        }
                    }
                }
            }
        }
        #endif
    }

    private func pastePhotoFromClipboard() {
        if let clip = MessengerStore.getClipboardImageData() {
            store.startUploadingPhoto(data: clip.data, preview: clip.preview, filename: clip.filename)
        }
    }

    private func handleSendAction() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !store.pendingUploads.isEmpty else { return }

        // Filter out failed uploads so they don't block sending
        store.pendingUploads.removeAll(where: { $0.error != nil })

        if store.pendingUploads.contains(where: { $0.isUploading }) {
            Task {
                while store.pendingUploads.contains(where: { $0.isUploading }) {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                await MainActor.run {
                    store.pendingUploads.removeAll(where: { $0.error != nil })
                    let readyCodes = store.pendingUploads.compactMap { $0.attachmentCode }
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !readyCodes.isEmpty {
                        onSend()
                        text = ""
                        inputHeight = 22
                    }
                }
            }
        } else {
            let readyCodes = store.pendingUploads.compactMap { $0.attachmentCode }
            if !trimmed.isEmpty || !readyCodes.isEmpty {
                onSend()
                text = ""
                inputHeight = 22
            }
        }
    }
}

#if os(macOS)
// MARK: - Native Multiline Chat Input with Shift+Enter Support (macOS)
public struct VKChatInputTextView: NSViewRepresentable {
    @Binding public var text: String
    @Binding public var dynamicHeight: CGFloat
    public var placeholder: String
    public var onCommit: () -> Void
    public var onTyping: (() -> Void)? = nil
    public var onCancel: (() -> Void)? = nil
    public var onPasteImage: ((Data, PlatformImage, String) -> Void)? = nil
    public var onPasteFiles: (([URL]) -> Void)? = nil

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = VKInternalInputTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 13.5)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.placeholderString = placeholder
        textView.onCommit = onCommit
        textView.onTyping = onTyping
        textView.onCancel = onCancel
        textView.onPasteImage = onPasteImage
        textView.onPasteFiles = onPasteFiles

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        if let container = textView.textContainer {
            container.widthTracksTextView = true
        }

        scrollView.documentView = textView
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? VKInternalInputTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.updateHeight(textView: textView)
        }
        textView.placeholderString = placeholder
        textView.onCommit = onCommit
        textView.onTyping = onTyping
        textView.onCancel = onCancel
        textView.onPasteImage = onPasteImage
        textView.onPasteFiles = onPasteFiles

        let isDark = ThemeManager.shared.isSurfaceDark
        textView.textColor = isDark ? NSColor.white : NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: VKChatInputTextView

        init(_ parent: VKChatInputTextView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            updateHeight(textView: textView)
            if !textView.string.isEmpty {
                parent.onTyping?()
            }
        }

        func updateHeight(textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let calculated = max(22, ceil(usedRect.height + 4))
            if abs(parent.dynamicHeight - calculated) > 1 {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = calculated
                }
            }
        }
    }
}

final class VKInternalInputTextView: NSTextView {
    var onCommit: (() -> Void)?
    var onTyping: (() -> Void)?
    var onCancel: (() -> Void)?
    var onPasteImage: ((Data, PlatformImage, String) -> Void)?
    var onPasteFiles: (([URL]) -> Void)?
    var placeholderString: String = "" {
        didSet { needsDisplay = true }
    }

    override func paste(_ sender: Any?) {
        if let clip = MessengerStore.getClipboardImageData() {
            onPasteImage?(clip.data, clip.preview, clip.filename)
            return
        }
        if let urls = MessengerStore.getClipboardFileURLs(), !urls.isEmpty {
            onPasteFiles?(urls)
            return
        }
        super.paste(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Intercept arrow keys so SwiftUI's parent ScrollView/Focus doesn't steal them
        if event.keyCode >= 123 && event.keyCode <= 126 {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        // Escape key: 53 -> cancel edit/reply
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        // Return key: 36, Keypad enter: 76
        if event.keyCode == 36 || event.keyCode == 76 {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers.contains(.shift) || modifiers.contains(.option) {
                // Shift+Enter or Option+Enter -> insert newline
                self.insertText("\n", replacementRange: self.selectedRange())
                return
            } else {
                // Return alone -> Send!
                onCommit?()
                return
            }
        }

        // Arrow keys: Left(123), Right(124), Down(125), Up(126)
        if event.keyCode >= 123 && event.keyCode <= 126 {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch event.keyCode {
            case 123: // Left Arrow
                if modifiers.contains(.command) {
                    if modifiers.contains(.shift) {
                        moveToBeginningOfLineAndModifySelection(nil)
                    } else {
                        moveToBeginningOfLine(nil)
                    }
                } else if modifiers.contains(.option) {
                    if modifiers.contains(.shift) {
                        moveWordBackwardAndModifySelection(nil)
                    } else {
                        moveWordBackward(nil)
                    }
                } else if modifiers.contains(.shift) {
                    moveBackwardAndModifySelection(nil)
                } else {
                    moveBackward(nil)
                }
                return

            case 124: // Right Arrow
                if modifiers.contains(.command) {
                    if modifiers.contains(.shift) {
                        moveToEndOfLineAndModifySelection(nil)
                    } else {
                        moveToEndOfLine(nil)
                    }
                } else if modifiers.contains(.option) {
                    if modifiers.contains(.shift) {
                        moveWordForwardAndModifySelection(nil)
                    } else {
                        moveWordForward(nil)
                    }
                } else if modifiers.contains(.shift) {
                    moveForwardAndModifySelection(nil)
                } else {
                    moveForward(nil)
                }
                return

            case 125: // Down Arrow
                if modifiers.contains(.command) {
                    if modifiers.contains(.shift) {
                        moveToEndOfDocumentAndModifySelection(nil)
                    } else {
                        moveToEndOfDocument(nil)
                    }
                } else if modifiers.contains(.shift) {
                    moveDownAndModifySelection(nil)
                } else {
                    moveDown(nil)
                }
                return

            case 126: // Up Arrow
                if modifiers.contains(.command) {
                    if modifiers.contains(.shift) {
                        moveToBeginningOfDocumentAndModifySelection(nil)
                    } else {
                        moveToBeginningOfDocument(nil)
                    }
                } else if modifiers.contains(.shift) {
                    moveUpAndModifySelection(nil)
                } else {
                    moveUp(nil)
                }
                return

            default:
                break
            }
        }

        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty && !placeholderString.isEmpty {
            let isDark = ThemeManager.shared.isSurfaceDark
            let placeholderColor = isDark ? NSColor(white: 0.65, alpha: 1.0) : NSColor(white: 0.50, alpha: 1.0)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: 13.5),
                .foregroundColor: placeholderColor
            ]
            let rect = NSRect(x: 1, y: 2, width: bounds.width - 2, height: 20)
            placeholderString.draw(in: rect, withAttributes: attrs)
        }
    }
}
#elseif os(iOS)
// MARK: - Native Multiline Chat Input (iOS)
public struct VKChatInputTextView: UIViewRepresentable {
    @Binding public var text: String
    @Binding public var dynamicHeight: CGFloat
    public var placeholder: String
    public var onCommit: () -> Void
    public var onTyping: (() -> Void)? = nil

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.returnKeyType = .send
        return textView
    }

    public func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        let isDark = ThemeManager.shared.isSurfaceDark
        uiView.textColor = isDark ? UIColor.white : UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        let size = uiView.sizeThatFits(CGSize(width: uiView.bounds.width, height: .infinity))
        let calculated = max(22, ceil(size.height))
        if abs(dynamicHeight - calculated) > 1 {
            DispatchQueue.main.async {
                self.dynamicHeight = calculated
            }
        }
    }

    public class Coordinator: NSObject, UITextViewDelegate {
        var parent: VKChatInputTextView

        init(_ parent: VKChatInputTextView) {
            self.parent = parent
        }

        public func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            if !textView.text.isEmpty {
                parent.onTyping?()
            }
            let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .infinity))
            let calculated = max(22, ceil(size.height))
            if abs(parent.dynamicHeight - calculated) > 1 {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = calculated
                }
            }
        }

        public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onCommit()
                return false
            }
            return true
        }
    }
}
#endif

// MARK: - Telegram Sticker Icon (matching reference media_1791705607992_dd0953c7.jpg)
@MainActor
public struct TelegramStickerIcon: View {
    public var color: Color?

    public init(color: Color? = nil) {
        self.color = color
    }

    public var body: some View {
        let strokeColor = color ?? VKColors.textSecondary
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.0001))
                .frame(width: 22, height: 22)

            Circle()
                .strokeBorder(strokeColor, lineWidth: 1.6)
                .frame(width: 22, height: 22)

            // Folded sticker peel arc at bottom right
            Path { path in
                path.move(to: CGPoint(x: 11, y: 19.5))
                path.addCurve(
                    to: CGPoint(x: 19.5, y: 11),
                    control1: CGPoint(x: 11, y: 13),
                    control2: CGPoint(x: 13, y: 11)
                )
            }
            .stroke(strokeColor, lineWidth: 1.6)
        }
        .frame(width: 22, height: 22)
        .contentShape(Rectangle())
    }
}
