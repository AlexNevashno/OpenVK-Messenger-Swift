import SwiftUI
import AVKit
import WebKit
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Video Player Window Controller

#if os(macOS)
public final class VideoPlayerWindowController: NSWindowController, NSWindowDelegate {
    private var hostingView: NSHostingView<VideoPlayerWindowView>?

    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 580),
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
        window.minSize = NSSize(width: 500, height: 320)
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self
    }

    public func show(items: [VideoPlayerItem], initialIndex: Int) {
        guard let window = self.window else { return }

        let rootView = VideoPlayerWindowView(onClose: { [weak self] in
            self?.close()
        })
        self.hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        VideoPlayerService.shared.isOpen = false
    }
}
#endif

// MARK: - Native AVPlayerView Representable

#if os(macOS)
public struct VKNativePlayerView: NSViewRepresentable {
    public let player: AVPlayer

    public func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.showsFullScreenToggleButton = true
        view.allowsPictureInPicturePlayback = true
        return view
    }

    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
#elseif os(iOS)
public struct VKNativePlayerView: UIViewControllerRepresentable {
    public let player: AVPlayer

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        return controller
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
#endif

// MARK: - WebKit Video Player (Fallback for Web / YouTube Embeds)

#if os(macOS)
public struct VKWebVideoPlayerView: NSViewRepresentable {
    public let url: URL

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.load(URLRequest(url: url))
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
#elseif os(iOS)
public struct VKWebVideoPlayerView: UIViewRepresentable {
    public let url: URL

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.load(URLRequest(url: url))
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
}
#endif

// MARK: - Main Video Player Window View

public struct VideoPlayerWindowView: View {
    @ObservedObject private var service = VideoPlayerService.shared
    public var onClose: () -> Void

    @State private var avPlayer: AVPlayer? = nil
    @State private var isResolving: Bool = false
    @State private var resolvedDirectURL: URL? = nil
    @State private var resolvedWebURL: URL? = nil
    @State private var resolvedTitle: String = ""
    @State private var errorMessage: String? = nil
    @State private var showHeader: Bool = true
    @State private var headerTimer: Timer? = nil
    @State private var keyMonitor: Any? = nil

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let item = service.currentItem {
                ZStack {
                    // 1. Playback Surface
                    if let player = avPlayer {
                        VKNativePlayerView(player: player)
                            .ignoresSafeArea()
                    } else if let webURL = resolvedWebURL {
                        VKWebVideoPlayerView(url: webURL)
                            .ignoresSafeArea()
                    } else if isResolving {
                        // Loading placeholder with thumbnail
                        ZStack {
                            if let thumb = item.thumbnailURL {
                                AsyncImage(url: thumb) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable().scaledToFit().blur(radius: 20).opacity(0.4)
                                    }
                                }
                            }

                            VStack(spacing: 16) {
                                ProgressView()
                                    .controlSize(.regular)
                                    .tint(.white)

                                Text("Загрузка видеозаписи...")
                                    .font(VKTypography.subhead)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    } else if let err = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.6))

                            Text(err)
                                .font(VKTypography.headline)
                                .foregroundColor(.white)

                            if let web = resolvedWebURL ?? item.playerWebURL {
                                Button(action: {
                                    PlatformURLOpener.open(web)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "safari")
                                        Text("Открыть в браузере")
                                    }
                                    .font(VKTypography.subhead)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(VKColors.accent)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 2. Overlay Header (Title, Playlist Counter, Close)
                    VStack {
                        if showHeader {
                            HStack(alignment: .center, spacing: 14) {
                                Button(action: {
                                    cleanupAndClose()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                                .help("Закрыть (Esc)")

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resolvedTitle.isEmpty ? item.title : resolvedTitle)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }

                                Spacer()

                                // Previous / Next Video navigation if multiple items
                                if service.items.count > 1 {
                                    HStack(spacing: 8) {
                                        Button(action: {
                                            service.previous()
                                            loadCurrentItem()
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(service.currentIndex > 0 ? .white : .white.opacity(0.3))
                                                .frame(width: 28, height: 28)
                                                .background(Color.white.opacity(0.12))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(service.currentIndex == 0)

                                        Text("\(service.currentIndex + 1) / \(service.items.count)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))

                                        Button(action: {
                                            service.next()
                                            loadCurrentItem()
                                        }) {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(service.currentIndex < service.items.count - 1 ? .white : .white.opacity(0.3))
                                                .frame(width: 28, height: 28)
                                                .background(Color.white.opacity(0.12))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(service.currentIndex >= service.items.count - 1)
                                    }
                                }

                                // Open in browser button
                                if let openURL = resolvedWebURL ?? item.playerWebURL ?? resolvedDirectURL ?? item.videoURL {
                                    Button(action: {
                                        PlatformURLOpener.open(openURL)
                                    }) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white.opacity(0.8))
                                            .frame(width: 28, height: 28)
                                            .background(Color.white.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Открыть во внешнем браузере")
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                            .background(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .transition(.opacity)
                        }

                        Spacer()
                    }
                }
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showHeader = isHovered
                    }
                }
            } else {
                Text("Видеозапись не найдена")
                    .font(VKTypography.subhead)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .onAppear {
            setupKeyMonitor()
            loadCurrentItem()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func loadCurrentItem() {
        guard let item = service.currentItem else { return }

        // Clean previous player
        avPlayer?.pause()
        avPlayer = nil
        resolvedDirectURL = nil
        resolvedWebURL = nil
        errorMessage = nil
        resolvedTitle = item.title

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("VideoPlayerWindowView AVAudioSession error: \(error)")
        }
        #endif

        // 1. If direct video stream is already supplied
        if let direct = item.videoURL {
            let player = AVPlayer(url: direct)
            self.avPlayer = player
            player.play()
            return
        }

        // 2. If web player embed URL is directly supplied
        if let web = item.playerWebURL {
            self.resolvedWebURL = web
            return
        }

        // 3. Otherwise resolve via API (video.get)
        guard let oid = item.ownerId, let vid = item.videoId else {
            // No IDs to query, fallback to generic openvk web link
            if let webURL = item.playerWebURL {
                self.resolvedWebURL = webURL
            } else {
                self.errorMessage = "Не указан адрес видеозаписи"
            }
            return
        }

        isResolving = true
        Task {
            do {
                if let detail = try await OpenVKAPIService.shared.getVideoDetails(ownerId: oid, videoId: vid, accessKey: item.accessKey) {
                    await MainActor.run {
                        self.isResolving = false
                        self.resolvedTitle = detail.title

                        if let direct = detail.bestDirectURL {
                            self.resolvedDirectURL = direct
                            let p = AVPlayer(url: direct)
                            self.avPlayer = p
                            p.play()
                        } else if let web = detail.playerURL {
                            self.resolvedWebURL = web
                        } else {
                            self.errorMessage = "Не удалось найти источник видеозаписи"
                        }
                    }
                } else {
                    await MainActor.run {
                        self.isResolving = false
                        self.errorMessage = "Видеозапись недоступна"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isResolving = false
                    // Fallback to web player link
                    let base = OpenVKAPIService.shared.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    if let fallback = URL(string: "\(base)/video_ext.php?oid=\(oid)&id=\(vid)") {
                        self.resolvedWebURL = fallback
                    } else {
                        self.errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func setupKeyMonitor() {
        #if os(macOS)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                cleanupAndClose()
                return nil
            }
            if event.keyCode == 49 { // Spacebar
                if let p = avPlayer {
                    if p.timeControlStatus == .playing {
                        p.pause()
                    } else {
                        p.play()
                    }
                    return nil
                }
            }
            if event.keyCode == 123 { // Left arrow: -5s
                if let p = avPlayer {
                    let cur = p.currentTime()
                    let target = CMTimeSubtract(cur, CMTime(seconds: 5, preferredTimescale: 600))
                    p.seek(to: max(target, .zero))
                    return nil
                }
            }
            if event.keyCode == 124 { // Right arrow: +5s
                if let p = avPlayer {
                    let cur = p.currentTime()
                    let target = CMTimeAdd(cur, CMTime(seconds: 5, preferredTimescale: 600))
                    p.seek(to: target)
                    return nil
                }
            }
            return event
        }
        #endif
    }

    private func cleanup() {
        #if os(macOS)
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        #endif
        avPlayer?.pause()
        avPlayer = nil
    }

    private func cleanupAndClose() {
        cleanup()
        onClose()
    }
}
