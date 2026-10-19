import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import PhotosUI
#endif

public struct VKMediaAttachSheetView: View {
    @ObservedObject public var store: MessengerStore
    public let onSendMedia: (String, String) -> Void // (attachmentCode, optionalText)
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: VKInstanceMediaType = .photos
    @State private var mediaItems: [VKInstanceMediaItem] = []
    @State private var isLoading = false
    @State private var captionText = ""
    @State private var selectedItem: VKInstanceMediaItem? = nil

    // Local / Clipboard photo selection
    @State private var localPhotoData: Data? = nil
    @State private var localPhotoPreview: PlatformImage? = nil
    @State private var localPhotoName: String? = nil
    @State private var clipboardNotice: String? = nil
    #if os(iOS)
    @State private var selectedPhotoPickerItem: PhotosPickerItem? = nil
    #endif

    public init(store: MessengerStore, onSendMedia: @escaping (String, String) -> Void) {
        self.store = store
        self.onSendMedia = onSendMedia
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Прикрепить медиа")
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

            // MARK: - Top Quick Actions: From PC/Photos and From Clipboard
            HStack(spacing: 12) {
                #if os(iOS)
                PhotosPicker(selection: $selectedPhotoPickerItem, matching: .images) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 16))
                            .foregroundColor(VKColors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Медиатека")
                                .font(VKTypography.subhead)
                                .foregroundColor(VKColors.textPrimary)
                            Text("Выбрать из фото")
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(VKColors.secondarySurface)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .onChange(of: selectedPhotoPickerItem) { item in
                    guard let item = item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            await MainActor.run {
                                clearInstanceSelection()
                                self.localPhotoData = data
                                self.localPhotoName = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
                                self.localPhotoPreview = img
                                self.clipboardNotice = nil
                            }
                        }
                    }
                }
                #else
                Button(action: pickFromComputer) {
                    HStack(spacing: 10) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 16))
                            .foregroundColor(VKColors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("С компьютера")
                                .font(VKTypography.subhead)
                                .foregroundColor(VKColors.textPrimary)
                            Text("Выбрать файл фото")
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(VKColors.secondarySurface)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                #endif

                // Button: Paste from Clipboard
                Button(action: pasteFromClipboard) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 16))
                            .foregroundColor(VKColors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Из буфера обмена")
                                .font(VKTypography.subhead)
                                .foregroundColor(VKColors.textPrimary)
                            Text("Вставить скопированное")
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(VKColors.secondarySurface)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if let notice = clipboardNotice {
                Text(notice)
                    .font(VKTypography.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            Divider()

            // MARK: - Content Area
            if let preview = localPhotoPreview {
                // Selected Local/Clipboard Photo Preview
                VStack(spacing: 14) {
                    Spacer()

                    Image(platformImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)

                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                            .foregroundColor(VKColors.accent)
                        Text(localPhotoName ?? "Изображение для отправки")
                            .font(VKTypography.subhead)
                            .foregroundColor(VKColors.textPrimary)
                    }

                    Button(action: clearLocalPhoto) {
                        Text("Выбрать другое")
                            .font(VKTypography.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VKColors.background)
            } else {
                // Instance Media Browser
                VStack(spacing: 0) {
                    // Custom VKUI Tabs Switcher
                    HStack(spacing: 8) {
                        ForEach(VKInstanceMediaType.allCases, id: \.self) { type in
                            Button(action: {
                                if selectedTab != type {
                                    selectedTab = type
                                    mediaItems = []
                                    selectedItem = nil
                                    loadMedia()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(type.rawValue)
                                        .font(VKTypography.subhead)
                                }
                                .foregroundColor(selectedTab == type ? VKColors.accent : VKColors.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedTab == type ? VKColors.secondarySurface : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(VKColors.surface)

                    Divider()

                    // Media Grid or List
                    if isLoading {
                        VStack(spacing: 10) {
                            Spacer()
                            ProgressView()
                            Text("Загрузка с инстанса OpenVK...")
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if mediaItems.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: selectedTab.icon)
                                .font(.system(size: 42))
                                .foregroundColor(VKColors.textSecondary)
                            Text("Нет доступных медиафайлов")
                                .font(VKTypography.headline)
                                .foregroundColor(VKColors.textPrimary)
                            Text("На вашем аккаунте нет файлов в категории «\(selectedTab.rawValue)». Вы можете загрузить фото с компьютера кнопкой выше.")
                                .font(VKTypography.caption)
                                .foregroundColor(VKColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            if selectedTab == .photos {
                                // Photos: 3-column Grid
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                                    ForEach(mediaItems) { item in
                                        Button(action: {
                                            selectedItem = item
                                        }) {
                                            ZStack(alignment: .bottomTrailing) {
                                                if let url = item.thumbnailURL {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .success(let img):
                                                            img.resizable().scaledToFill()
                                                                .frame(height: 110)
                                                                .clipped()
                                                                .cornerRadius(8)
                                                        default:
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill(VKColors.secondarySurface)
                                                                .frame(height: 110)
                                                                .overlay(
                                                                    Image(systemName: "photo")
                                                                        .foregroundColor(VKColors.textSecondary)
                                                                )
                                                        }
                                                    }
                                                } else {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(VKColors.secondarySurface)
                                                        .frame(height: 110)
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .foregroundColor(VKColors.textSecondary)
                                                        )
                                                }

                                                if selectedItem?.id == item.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 22))
                                                        .foregroundColor(VKColors.accent)
                                                        .background(Circle().fill(Color.white))
                                                        .padding(6)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(16)
                            } else if selectedTab == .audio {
                                // Music: Track list with artist, title, duration
                                LazyVStack(spacing: 4) {
                                    ForEach(mediaItems) { item in
                                        Button(action: {
                                            selectedItem = item
                                        }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "music.note")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(VKColors.accent)
                                                    .frame(width: 38, height: 38)
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

                                                if selectedItem?.id == item.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(VKColors.accent)
                                                }
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedItem?.id == item.id ? VKColors.secondarySurface : Color.clear)
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(14)
                            } else if selectedTab == .video {
                                // Video: Video list with title, duration
                                LazyVStack(spacing: 6) {
                                    ForEach(mediaItems) { item in
                                        Button(action: {
                                            selectedItem = item
                                        }) {
                                            HStack(spacing: 12) {
                                                ZStack {
                                                    if let thumb = item.thumbnailURL {
                                                        AsyncImage(url: thumb) { phase in
                                                            switch phase {
                                                            case .success(let img):
                                                                img.resizable().scaledToFill()
                                                                    .frame(width: 60, height: 44)
                                                                    .clipped()
                                                                    .cornerRadius(6)
                                                            default:
                                                                RoundedRectangle(cornerRadius: 6)
                                                                    .fill(VKColors.secondarySurface)
                                                                    .frame(width: 60, height: 44)
                                                            }
                                                        }
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(VKColors.secondarySurface)
                                                            .frame(width: 60, height: 44)
                                                    }

                                                    Image(systemName: "play.fill")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.white)
                                                        .padding(6)
                                                        .background(Color.black.opacity(0.5))
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
                                                        .lineLimit(1)
                                                }

                                                Spacer()

                                                if selectedItem?.id == item.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(VKColors.accent)
                                                }
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedItem?.id == item.id ? VKColors.secondarySurface : Color.clear)
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(14)
                            } else if selectedTab == .docs {
                                // Documents list with doc icon, filename, size
                                LazyVStack(spacing: 4) {
                                    ForEach(mediaItems) { item in
                                        Button(action: {
                                            selectedItem = item
                                        }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "doc.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(VKColors.accent)
                                                    .frame(width: 38, height: 38)
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

                                                if selectedItem?.id == item.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(VKColors.accent)
                                                }
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedItem?.id == item.id ? VKColors.secondarySurface : Color.clear)
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(14)
                            }
                        }
                    }
                }
            }

            Divider()

            // MARK: - Footer / Send Action Bar
            VStack(spacing: 10) {
                if let localName = localPhotoName {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                            .foregroundColor(VKColors.accent)
                        Text("Выбран файл: \(localName)")
                            .font(VKTypography.caption)
                            .foregroundColor(VKColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                } else if let sel = selectedItem {
                    HStack(spacing: 8) {
                        Image(systemName: sel.type.icon)
                            .foregroundColor(VKColors.accent)
                        Text("Выбрано: \(sel.title)")
                            .font(VKTypography.caption)
                            .foregroundColor(VKColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }

                HStack(spacing: 12) {
                    TextField("Подпись к медиа (необязательно)...", text: $captionText)
                        .textFieldStyle(.plain)
                        .font(VKTypography.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(VKColors.secondarySurface)
                        .cornerRadius(10)

                    Button(action: sendCurrentMedia) {
                        Text("Отправить")
                            .font(VKTypography.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(canSend ? VKColors.accent : Color.gray.opacity(0.4))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(VKColors.surface)
        }
        #if os(macOS)
        .frame(width: 560, height: 640)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .background(VKColors.surface)
        .onAppear {
            loadMedia()
        }
    }

    private var canSend: Bool {
        localPhotoData != nil || selectedItem != nil
    }

    private func pickFromComputer() {
        #if os(macOS)
        if let file = MessengerStore.pickLocalImageFile() {
            clearInstanceSelection()
            self.localPhotoData = file.data
            self.localPhotoName = file.filename
            self.localPhotoPreview = file.preview
            self.clipboardNotice = nil
        }
        #endif
    }

    private func pasteFromClipboard() {
        if let clip = MessengerStore.getClipboardImageData() {
            clearInstanceSelection()
            self.localPhotoData = clip.data
            self.localPhotoName = clip.filename
            self.localPhotoPreview = clip.preview
            self.clipboardNotice = nil
        } else {
            self.clipboardNotice = "В буфере обмена сейчас нет скопированного изображения"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.clipboardNotice != nil {
                    self.clipboardNotice = nil
                }
            }
        }
    }

    private func clearLocalPhoto() {
        self.localPhotoData = nil
        self.localPhotoPreview = nil
        self.localPhotoName = nil
    }

    private func clearInstanceSelection() {
        self.selectedItem = nil
    }

    private func sendCurrentMedia() {
        if let data = localPhotoData {
            let img = localPhotoPreview ?? PlatformImage()
            store.startUploadingPhoto(
                data: data,
                preview: img,
                filename: localPhotoName ?? "photo.jpg"
            )
            if !captionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                store.sendMessage(text: captionText)
            }
            dismiss()
        } else if let sel = selectedItem {
            onSendMedia(sel.attachmentCode, captionText)
            dismiss()
        }
    }

    private func loadMedia() {
        isLoading = true
        selectedItem = nil
        Task {
            do {
                let items = try await store.api.getUserMedia(type: selectedTab)
                await MainActor.run {
                    self.mediaItems = items
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.mediaItems = []
                    self.isLoading = false
                }
            }
        }
    }
}
