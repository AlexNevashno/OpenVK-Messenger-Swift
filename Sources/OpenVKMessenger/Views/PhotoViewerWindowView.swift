import SwiftUI
#if os(macOS)
import AppKit

public final class PhotoViewerWindowController: NSWindowController, NSWindowDelegate {
    private var hostingView: NSHostingView<PhotoViewerWindowView>?

    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1060, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 480, height: 380)
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self
    }

    public func show(items: [PhotoViewerItem], initialIndex: Int) {
        guard let window = self.window else { return }

        let rootView = PhotoViewerWindowView(onClose: { [weak self] in
            self?.close()
        })
        self.hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        PhotoViewerService.shared.isOpen = false
    }
}
#elseif os(iOS)
import UIKit
#endif

public struct PhotoViewerWindowView: View {
    @ObservedObject private var service = PhotoViewerService.shared
    public var onClose: () -> Void

    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var dismissDragY: CGFloat = 0
    @State private var loadedImage: PlatformImage? = nil
    @State private var showSavedToast: Bool = false
    @State private var keyMonitor: Any? = nil

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            // Dark background with dynamic opacity during swipe down dismiss
            Color.black
                .opacity(dismissDragY > 0 ? max(0.12, 1.0 - Double(dismissDragY / 420.0)) : 1.0)
                .ignoresSafeArea()

            if let item = service.currentItem {
                #if os(iOS)
                // iOS Telegram-style photo gallery with swipeable TabView and swipe-down dismiss
                ZStack {
                    if service.items.count > 1 {
                        TabView(selection: $service.currentIndex) {
                            ForEach(Array(service.items.enumerated()), id: \.element.id) { index, curItem in
                                photoContentView(for: curItem)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    } else {
                        photoContentView(for: item)
                    }

                    // iOS Header
                    VStack {
                        HStack(alignment: .center, spacing: 12) {
                            Button(action: onClose) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.authorName.isEmpty ? "Фотография" : item.authorName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text("\(formattedDate(item.date))\(service.items.count > 1 ? " • \(service.currentIndex + 1) из \(service.items.count)" : "")")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Menu {
                                Button(action: saveImageToPhotos) {
                                    Label("Сохранить в Фото", systemImage: "arrow.down.to.line")
                                }
                                Button(action: shareImageAction) {
                                    Label("Поделиться", systemImage: "square.and.arrow.up")
                                }
                                Button(action: copyImageToClipboard) {
                                    Label("Скопировать", systemImage: "doc.on.doc")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.85), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Spacer()

                        // iOS Bottom Bar
                        VStack(spacing: 8) {
                            if !item.caption.isEmpty {
                                Text(item.caption)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 20)
                            }

                            HStack {
                                Button(action: shareImageAction) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .padding(10)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button(action: saveImageToPhotos) {
                                    Image(systemName: "arrow.down.to.line")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .padding(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            .background(
                                LinearGradient(
                                    colors: [Color.clear, Color.black.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }

                    // Toast: "Сохранено в Фото"
                    if showSavedToast {
                        VStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Сохранено в Фото")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.2).opacity(0.95))
                            .clipShape(Capsule())
                            .padding(.bottom, 70)
                        }
                        .transition(.opacity)
                    }
                }
                .offset(y: max(0, dismissDragY))
                .scaleEffect(dismissDragY > 0 ? max(0.8, 1.0 - (dismissDragY / 1200.0)) : 1.0)
                .simultaneousGesture(swipeDownDismissGesture)
                #else
                // macOS Desktop Layout
                GeometryReader { geo in
                    ZStack {
                        photoContentView(for: item)
                            .padding(.top, 28)
                            .padding(.bottom, 64)

                        // Navigation: Left Chevron Arrow (<)
                        if service.currentIndex > 0 {
                            HStack {
                                Button(action: {
                                    resetZoom()
                                    service.previous()
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 44, height: 64)
                                        .background(Color.black.opacity(0.35))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 16)
                                .help("Предыдущее фото (←)")

                                Spacer()
                            }
                        }

                        // Navigation: Right Chevron Arrow (>)
                        if service.currentIndex < service.items.count - 1 {
                            HStack {
                                Spacer()

                                Button(action: {
                                    resetZoom()
                                    service.next()
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 44, height: 64)
                                        .background(Color.black.opacity(0.35))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 16)
                                .help("Следующее фото (→)")
                            }
                        }

                        // macOS Bottom Bar
                        VStack(spacing: 0) {
                            Spacer()

                            HStack(alignment: .bottom, spacing: 16) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Photo \(service.currentIndex + 1) of \(service.items.count)")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))

                                    Text("\(item.authorName.isEmpty ? "OpenVK" : item.authorName) • \(formattedDate(item.date))\(resolutionString)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                }

                                Spacer()

                                if !item.caption.isEmpty {
                                    Text(item.caption)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(Color(white: 0.16).opacity(0.88)))
                                        .lineLimit(3)

                                    Spacer()
                                }

                                HStack(spacing: 14) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.25)) {
                                            if zoomScale > 1.0 {
                                                zoomScale = 1.0
                                                panOffset = .zero
                                            } else {
                                                zoomScale = 1.8
                                            }
                                        }
                                    }) {
                                        Image(systemName: zoomScale > 1.0 ? "minus.magnifyingglass" : "plus.magnifyingglass")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.85))
                                            .frame(width: 32, height: 32)
                                            .background(Color.white.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Масштаб")

                                    Button(action: copyImageToClipboard) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.85))
                                            .frame(width: 32, height: 32)
                                            .background(Color.white.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Скопировать изображение")

                                    Button(action: saveImageToDownloads) {
                                        Image(systemName: "arrow.down.to.line")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.85))
                                            .frame(width: 32, height: 32)
                                            .background(Color.white.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Сохранить в Загрузки")

                                    Button(action: onClose) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white.opacity(0.85))
                                            .frame(width: 32, height: 32)
                                            .background(Color.white.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Закрыть (Esc)")
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                            .padding(.bottom, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.95)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                #endif
            }
        }
        .onAppear {
            installKeyMonitor()
            if let itm = service.currentItem {
                if let local = itm.localImage {
                    self.loadedImage = local
                } else if let u = itm.imageURL {
                    fetchPlatformImage(url: u)
                }
            }
        }
        .onChange(of: service.currentIndex) { newIdx in
            resetZoom()
            if newIdx >= 0 && newIdx < service.items.count {
                let itm = service.items[newIdx]
                if let local = itm.localImage {
                    self.loadedImage = local
                } else if let u = itm.imageURL {
                    fetchPlatformImage(url: u)
                }
            }
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    @ViewBuilder
    private func photoContentView(for item: PhotoViewerItem) -> some View {
        GeometryReader { geo in
            ZStack {
                let isGIF = item.imageURL?.pathExtension.lowercased() == "gif" || item.caption.lowercased().hasSuffix(".gif")
                if isGIF, let url = item.imageURL {
                    VKAnimatedGIFView(url: url, allowsFullScreen: false)
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                } else if let local = item.localImage {
                    zoomableImageView(Image(platformImage: local))
                } else if let url = item.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            zoomableImageView(img)
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("Не удалось загрузить изображение")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    if zoomScale > 1.0 {
                        zoomScale = 1.0
                        panOffset = .zero
                    } else {
                        zoomScale = 2.0
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func zoomableImageView(_ img: Image) -> some View {
        let base = img
            .resizable()
            .scaledToFit()
            .scaleEffect(zoomScale)
            .offset(panOffset)

        if zoomScale > 1.0 {
            base.gesture(dragGesture)
        } else {
            base
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if zoomScale > 1.0 {
                    panOffset = value.translation
                }
            }
            .onEnded { _ in
                if zoomScale <= 1.0 {
                    panOffset = .zero
                }
            }
    }

    #if os(iOS)
    private var swipeDownDismissGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { val in
                if zoomScale <= 1.0 {
                    if val.translation.height > 0 && val.translation.height > abs(val.translation.width) * 1.15 {
                        dismissDragY = val.translation.height
                    }
                }
            }
            .onEnded { val in
                guard zoomScale <= 1.0 else { return }
                if dismissDragY > 80 || val.predictedEndTranslation.height > 200 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.22)) {
                        dismissDragY = UIScreen.main.bounds.height
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onClose()
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        dismissDragY = 0
                    }
                }
            }
    }
    #endif

    private func resetZoom() {
        zoomScale = 1.0
        panOffset = .zero
        dismissDragY = 0
    }

    private var resolutionString: String {
        if let img = loadedImage {
            return " • \(Int(img.size.width))×\(Int(img.size.height))"
        }
        return ""
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM в HH:mm"
        return formatter.string(from: date)
    }

    private func fetchPlatformImage(url: URL) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let d = data, let img = PlatformImage.from(data: d) {
                DispatchQueue.main.async {
                    self.loadedImage = img
                }
            }
        }.resume()
    }

    private func copyImageToClipboard() {
        guard let img = loadedImage else { return }
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])
        #elseif canImport(UIKit)
        UIPasteboard.general.image = img
        #endif
    }

    private func saveImageToPhotos() {
        guard let img = loadedImage else { return }
        #if os(iOS)
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        withAnimation {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedToast = false
            }
        }
        #elseif os(macOS)
        saveImageToDownloads()
        #endif
    }

    private func shareImageAction() {
        guard let img = loadedImage else { return }
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        let activity = UIActivityViewController(activityItems: [img], applicationActivities: nil)
        rootVC.present(activity, animated: true)
        #endif
    }

    private func saveImageToDownloads() {
        guard let img = loadedImage else { return }
        #if os(macOS)
        guard let pngData = img.jpegDataRepresentation() else { return }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let filename = "OpenVK_Photo_\(Int(Date().timeIntervalSince1970)).jpg"
        let fileURL = downloads.appendingPathComponent(filename)
        try? pngData.write(to: fileURL)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        #endif
    }

    private func installKeyMonitor() {
        #if os(macOS)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                onClose()
                return nil
            }
            if event.keyCode == 123 {
                resetZoom()
                service.previous()
                return nil
            }
            if event.keyCode == 124 {
                resetZoom()
                service.next()
                return nil
            }
            return event
        }
        #endif
    }

    private func removeKeyMonitor() {
        #if os(macOS)
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        #endif
    }
}
