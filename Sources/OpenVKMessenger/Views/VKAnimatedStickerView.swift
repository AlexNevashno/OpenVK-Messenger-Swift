import SwiftUI
import Lottie

/// A reusable view for rendering OpenVK animated stickers with Lottie,
/// with caching and smooth fallback to static PNG/AsyncImage if the sticker has no animation or fails to load.
public struct VKAnimatedStickerView: View {
    public let url: URL?
    public let animationURL: URL?
    public let size: CGFloat
    public var loop: Bool = true

    @State private var animation: LottieAnimation? = nil
    @State private var isLoadingAnimation = false
    @State private var failedAnimation = false

    private static let animationCache = NSCache<NSURL, LottieAnimation>()

    public init(url: URL?, animationURL: URL?, size: CGFloat = 140, loop: Bool = true) {
        self.url = url
        self.animationURL = animationURL
        self.size = size
        self.loop = loop
        if let a = animationURL, let cached = VKStickerCache.shared.cachedAnimation(from: a) {
            _animation = State(initialValue: cached)
        }
    }

    public var body: some View {
        Group {
            if let animation = animation {
                LottieView(animation: animation)
                    .playbackMode(loop ? .playing(.toProgress(1, loopMode: .loop)) : .playing(.toProgress(1, loopMode: .playOnce)))
                    .frame(width: size, height: size)
            } else if let animURL = animationURL, !failedAnimation {
                ZStack {
                    staticImageView
                    if isLoadingAnimation {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .task(id: animURL) {
                    await loadAnimation(from: animURL)
                }
            } else {
                staticImageView
            }
        }
    }

    private var staticImageView: some View {
        Group {
            if let url = url {
                VKCachedAsyncImage(url: url) { img in
                    img
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                } placeholder: {
                    ProgressView()
                        .frame(width: size, height: size)
                }
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: size * 0.45))
                    .foregroundColor(VKColors.textSecondary)
                    .frame(width: size, height: size)
            }
        }
    }

    private func loadAnimation(from animURL: URL) async {
        isLoadingAnimation = true
        if let anim = await VKStickerCache.shared.loadAnimation(from: animURL) {
            await MainActor.run {
                self.animation = anim
                self.isLoadingAnimation = false
            }
        } else {
            await MainActor.run {
                self.failedAnimation = true
                self.isLoadingAnimation = false
            }
        }
    }
}
