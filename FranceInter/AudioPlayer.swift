import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var errorMessage: String?

    private var player: AVPlayer?
    nonisolated(unsafe) private var timeObserver: Any?
    private var loadedURL: URL?
    nonisolated(unsafe) private var endObserver: NSObjectProtocol?

    deinit {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func toggle(episode: Episode, feedTitle: String, artworkURL: URL?) {
        guard let audioURL = episode.audioURL else {
            errorMessage = "L’adresse audio de cet épisode est introuvable."
            return
        }

        if loadedURL != audioURL {
            load(audioURL, episode: episode, feedTitle: feedTitle, artworkURL: artworkURL)
            return
        }

        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
        updateNowPlayingRate()
    }

    func seek(to value: TimeInterval) {
        guard value.isFinite else { return }
        player?.seek(to: CMTime(seconds: value, preferredTimescale: 600))
        currentTime = value
    }

    func skip(by seconds: TimeInterval) {
        let target = min(max(currentTime + seconds, 0), duration)
        seek(to: target)
    }

    func clearError() {
        errorMessage = nil
    }

    func isLoaded(_ episode: Episode) -> Bool {
        loadedURL == episode.audioURL
    }

    func isActivelyPlaying(_ episode: Episode) -> Bool {
        isLoaded(episode) && isPlaying
    }

    func isBuffering(_ episode: Episode) -> Bool {
        isLoaded(episode) && isBuffering
    }

    private func load(_ url: URL, episode: Episode, feedTitle: String, artworkURL: URL?) {
        errorMessage = nil
        isBuffering = true
        currentTime = 0
        duration = episode.duration ?? 0
        loadedURL = url

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        } catch {
            errorMessage = "La sortie audio n’a pas pu être préparée."
        }

        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer

        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { @Sendable [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = max(time.seconds, 0)
                if let itemDuration = self.player?.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                self.isBuffering = self.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = false
                self?.currentTime = 0
                self?.player?.seek(to: .zero)
                self?.updateNowPlayingRate()
            }
        }

        configureRemoteCommands()
        updateNowPlaying(episode: episode, feedTitle: feedTitle, artworkURL: artworkURL)
        newPlayer.play()
        isPlaying = true
        updateNowPlayingRate()
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.removeTarget(nil)
        commands.pauseCommand.removeTarget(nil)
        commands.skipForwardCommand.removeTarget(nil)
        commands.skipBackwardCommand.removeTarget(nil)
        commands.skipForwardCommand.preferredIntervals = [15]
        commands.skipBackwardCommand.preferredIntervals = [15]

        commands.playCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.play()
                self?.isPlaying = true
                self?.updateNowPlayingRate()
            }
            return .success
        }
        commands.pauseCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.pause()
                self?.isPlaying = false
                self?.updateNowPlayingRate()
            }
            return .success
        }
        commands.skipForwardCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in self?.skip(by: 15) }
            return .success
        }
        commands.skipBackwardCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in self?.skip(by: -15) }
            return .success
        }
    }

    private func updateNowPlaying(episode: Episode, feedTitle: String, artworkURL: URL?) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: episode.author,
            MPMediaItemPropertyAlbumTitle: feedTitle,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        guard let artworkURL else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                  let image = UIImage(data: data) else { return }
            let artwork = Self.makeArtwork(from: image)
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    /// MediaPlayer invokes artwork request handlers on a private background queue.
    /// Build the handler outside MainActor isolation so Swift's queue checks do not trap.
    nonisolated private static func makeArtwork(from image: UIImage) -> MPMediaItemArtwork {
        let handler: @Sendable (CGSize) -> UIImage = { _ in image }
        return MPMediaItemArtwork(boundsSize: image.size, requestHandler: handler)
    }

    private func updateNowPlayingRate() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

