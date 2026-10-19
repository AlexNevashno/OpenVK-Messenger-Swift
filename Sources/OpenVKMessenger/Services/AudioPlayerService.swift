import Foundation
import AVFoundation
import Combine

public struct AudioTrackItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let duration: Double
    public let url: URL

    public init(id: String, title: String, artist: String, duration: Double, url: URL) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.url = url
    }
}

@MainActor
public final class AudioPlayerService: ObservableObject {
    public static let shared = AudioPlayerService()

    @Published public var activeId: String? = nil
    @Published public var currentTitle: String = ""
    @Published public var currentArtist: String = ""
    @Published public var isPlaying: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var playlist: [AudioTrackItem] = []
    @Published public var currentTrackIndex: Int = 0

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var endObserverToken: Any?

    private init() {}

    public func playTrack(item: AudioTrackItem, in playlist: [AudioTrackItem] = []) {
        if !playlist.isEmpty {
            self.playlist = playlist
            self.currentTrackIndex = playlist.firstIndex(where: { $0.id == item.id }) ?? 0
        } else if self.playlist.isEmpty {
            self.playlist = [item]
            self.currentTrackIndex = 0
        }

        self.currentTitle = item.title
        self.currentArtist = item.artist
        play(id: item.id, url: item.url, initialDuration: item.duration)
    }

    public func togglePlay(id: String, url: URL, initialDuration: Double = 0, title: String = "", artist: String = "") {
        if activeId == id {
            if isPlaying {
                pause()
            } else {
                resume()
            }
        } else {
            let item = AudioTrackItem(id: id, title: title.isEmpty ? "Аудиозапись" : title, artist: artist, duration: initialDuration, url: url)
            playTrack(item: item)
        }
    }

    public func play(id: String, url: URL, initialDuration: Double) {
        stopPlaybackOnly()

        activeId = id
        duration = initialDuration > 0 ? initialDuration : 0
        currentTime = 0
        isLoading = true
        isPlaying = false

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioPlayerService AVAudioSession error: \(error)")
        }
        #endif

        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer

        // Observe playback end -> auto-advance to next track in playlist
        endObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.hasNextTrack {
                    self.nextTrack()
                } else {
                    self.isPlaying = false
                    self.currentTime = 0
                    self.player?.seek(to: .zero)
                }
            }
        }

        // Periodic time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let secs = CMTimeGetSeconds(time)
                if !secs.isNaN && secs >= 0 {
                    self.currentTime = secs
                    if self.isLoading && secs > 0 {
                        self.isLoading = false
                        self.isPlaying = true
                    }
                }

                if let itemDuration = self.player?.currentItem?.duration {
                    let durSecs = CMTimeGetSeconds(itemDuration)
                    if !durSecs.isNaN && durSecs > 0 {
                        self.duration = durSecs
                    }
                }
            }
        }

        newPlayer.play()
        isPlaying = true
        isLoading = false
    }

    public var hasNextTrack: Bool {
        !playlist.isEmpty && currentTrackIndex < playlist.count - 1
    }

    public var hasPreviousTrack: Bool {
        !playlist.isEmpty && (currentTrackIndex > 0 || currentTime > 3)
    }

    public func nextTrack() {
        guard hasNextTrack else { return }
        currentTrackIndex += 1
        let nextItem = playlist[currentTrackIndex]
        playTrack(item: nextItem, in: playlist)
    }

    public func previousTrack() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard currentTrackIndex > 0 else {
            seek(to: 0)
            return
        }
        currentTrackIndex -= 1
        let prevItem = playlist[currentTrackIndex]
        playTrack(item: prevItem, in: playlist)
    }

    public func toggleCurrentPlayback() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    public func pause() {
        player?.pause()
        isPlaying = false
    }

    public func resume() {
        player?.play()
        isPlaying = true
    }

    public func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
        currentTime = seconds
    }

    private func stopPlaybackOnly() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let token = endObserverToken {
            NotificationCenter.default.removeObserver(token)
            endObserverToken = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        isLoading = false
        currentTime = 0
    }

    public func stop() {
        stopPlaybackOnly()
        activeId = nil
        currentTitle = ""
        currentArtist = ""
        duration = 0
        playlist = []
        currentTrackIndex = 0
    }
}
