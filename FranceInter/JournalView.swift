import SwiftUI

struct JournalView: View {
    @StateObject private var store = FeedStore()
    @StateObject private var audioPlayer = AudioPlayer()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.06, blue: 0.07), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                if let feed = store.feed, let episode = feed.latestEpisode {
                    playerContent(feed: feed, episode: episode)
                } else if let error = store.errorMessage {
                    errorView(error)
                } else {
                    loadingView
                }
            }
        }
        .task { await store.load() }
    }

    private func playerContent(feed: PodcastFeed, episode: Episode) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                header(feed: feed)
                    .padding(.bottom, 16)

                artwork(url: feed.artworkURL ?? episode.artworkURL)
                    .frame(maxWidth: 240)
                    .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    latestBadge

                    Text(episode.formattedDate.capitalized(with: Locale(identifier: "fr_FR")))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)

                    metadata(episode)
                    controls(feed: feed, episode: episode)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await store.load() }
        .alert(
            "Lecture impossible",
            isPresented: Binding(
                get: { audioPlayer.errorMessage != nil },
                set: { if !$0 { audioPlayer.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(audioPlayer.errorMessage ?? "Une erreur est survenue.")
        }
    }

    private func header(feed: PodcastFeed) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("FRANCE INTER")
                    .font(.caption2.weight(.black))
                    .tracking(2.2)
                    .foregroundStyle(Color(red: 1, green: 0.30, blue: 0.35))
                Text(feed.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                Task { await store.load() }
            } label: {
                Image(systemName: store.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.09), in: Circle())
            }
            .disabled(store.isLoading)
            .accessibilityLabel("Actualiser le journal")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private func artwork(url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                artworkPlaceholder
            default:
                ZStack {
                    artworkPlaceholder
                    ProgressView().tint(.white)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.red.opacity(0.17), radius: 30, y: 18)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.12, blue: 0.20), Color(red: 0.28, green: 0.03, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Text("7:30")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                Text("LE JOURNAL")
                    .font(.caption.weight(.black))
                    .tracking(4)
            }
            .foregroundStyle(.white)
        }
    }

    private var latestBadge: some View {
        Label("DERNIÈRE ÉDITION", systemImage: "waveform")
            .font(.caption2.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(Color(red: 1, green: 0.38, blue: 0.42))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.red.opacity(0.13), in: Capsule())
    }

    private func metadata(_ episode: Episode) -> some View {
        HStack(spacing: 14) {
            metaPill(icon: "person.fill", text: episode.author)
            if let duration = episode.formattedDuration {
                metaPill(icon: "clock.fill", text: duration)
            }
            if !episode.category.isEmpty {
                metaPill(icon: "newspaper.fill", text: "Actualités")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private func metaPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
    }

    private func controls(feed: PodcastFeed, episode: Episode) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 34) {
                Button { audioPlayer.skip(by: -15) } label: {
                    Image(systemName: "gobackward.15")
                }

                Button {
                    audioPlayer.toggle(
                        episode: episode,
                        feedTitle: feed.title,
                        artworkURL: feed.artworkURL ?? episode.artworkURL
                    )
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.98, green: 0.15, blue: 0.22))
                            .frame(width: 76, height: 76)
                            .shadow(color: Color.red.opacity(0.35), radius: 16, y: 8)
                        if audioPlayer.isBuffering {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 28, weight: .bold))
                                .offset(x: audioPlayer.isPlaying ? 0 : 2)
                        }
                    }
                }
                .accessibilityLabel(audioPlayer.isPlaying ? "Mettre en pause" : "Lire le dernier journal")

                Button { audioPlayer.skip(by: 15) } label: {
                    Image(systemName: "goforward.15")
                }
            }
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { audioPlayer.currentTime },
                        set: { audioPlayer.seek(to: $0) }
                    ),
                    in: 0...max(audioPlayer.duration, episode.duration ?? 1, 1)
                )
                .tint(Color(red: 1, green: 0.24, blue: 0.30))

                HStack {
                    Text(time(audioPlayer.currentTime))
                    Spacer()
                    Text("−\(time(max((audioPlayer.duration > 0 ? audioPlayer.duration : episode.duration ?? 0) - audioPlayer.currentTime, 0)))")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large).tint(.white)
            Text("Recherche du dernier journal…")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Journal indisponible", systemImage: "antenna.radiowaves.left.and.right.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Réessayer") { Task { await store.load() } }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .foregroundStyle(.white)
    }

    private func time(_ interval: TimeInterval) -> String {
        guard interval.isFinite else { return "0:00" }
        let total = max(Int(interval), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}


