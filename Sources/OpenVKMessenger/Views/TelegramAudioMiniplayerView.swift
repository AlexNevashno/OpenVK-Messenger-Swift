import SwiftUI

public struct TelegramAudioMiniplayerView: View {
    @ObservedObject private var player = AudioPlayerService.shared

    public init() {}

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Play / Pause Circle Button
                Button(action: {
                    player.toggleCurrentPlayback()
                }) {
                    ZStack {
                        Circle()
                            .fill(VKColors.accent)
                            .frame(width: 28, height: 28)

                        if player.isLoading {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: player.isPlaying ? 0 : 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(player.isPlaying ? "Пауза" : "Воспроизвести")

                // Prev Track Button
                Button(action: {
                    player.previousTrack()
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 11))
                        .foregroundColor(player.hasPreviousTrack ? VKColors.textPrimary : VKColors.textSecondary.opacity(0.4))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(!player.hasPreviousTrack)
                .help("Предыдущий трек")

                // Next Track Button
                Button(action: {
                    player.nextTrack()
                }) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 11))
                        .foregroundColor(player.hasNextTrack ? VKColors.textPrimary : VKColors.textSecondary.opacity(0.4))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(!player.hasNextTrack)
                .help("Следующий трек")

                // Track Title & Artist
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(player.currentTitle.isEmpty ? "Аудиозапись" : player.currentTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(VKColors.textPrimary)
                            .lineLimit(1)

                        if !player.currentArtist.isEmpty {
                            Text("—")
                                .font(.system(size: 11))
                                .foregroundColor(VKColors.textSecondary)

                            Text(player.currentArtist)
                                .font(.system(size: 11.5))
                                .foregroundColor(VKColors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    // Progress Scrubber
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(VKColors.separator)
                                .frame(height: 3)

                            Capsule()
                                .fill(VKColors.accent)
                                .frame(width: max(geo.size.width * CGFloat(progress), 0), height: 3)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    guard player.duration > 0 else { return }
                                    let pct = min(max(Double(val.location.x / geo.size.width), 0), 1)
                                    player.seek(to: pct * player.duration)
                                }
                        )
                    }
                    .frame(height: 5)
                }

                // Time Display: current / total
                Text(timeString)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(VKColors.textSecondary)
                    .frame(minWidth: 68, alignment: .trailing)

                // Close Button (✕)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        player.stop()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(VKColors.textSecondary)
                        .padding(6)
                        .background(VKColors.secondarySurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Закрыть плеер")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.85))
            .background(VKColors.surface.opacity(0.78))

            Divider()
                .background(VKColors.separator.opacity(0.6))
        }
    }

    private var timeString: String {
        let cur = formatSeconds(Int(player.currentTime))
        let dur = formatSeconds(Int(player.duration))
        return "\(cur) / \(dur)"
    }

    private func formatSeconds(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
}
