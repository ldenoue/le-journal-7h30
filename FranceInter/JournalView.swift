import SwiftUI

struct JournalView: View {
    @StateObject private var store = FeedStore()
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var selectedID: String?

    private var startingEpisode: DailyEpisode? {
        store.episodes.first(where: \.isSevenThirtyJournal) ?? store.episodes.first
    }

    private var selectedEpisode: DailyEpisode? {
        if let selectedID,
           let selected = store.episodes.first(where: { $0.id == selectedID }) {
            return selected
        }
        return startingEpisode
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.06, blue: 0.07), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                if let selectedEpisode {
                    playerContent(selected: selectedEpisode)
                } else if let error = store.errorMessage {
                    errorView(error)
                } else {
                    loadingView
                }
            }
        }
        .task {
            await store.load()
            selectStartingEpisodeIfNeeded()
        }
        .onChange(of: store.episodes) { _, _ in
            selectStartingEpisodeIfNeeded()
        }
    }

    private func playerContent(selected: DailyEpisode) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.bottom, 12)

                artworkCarousel

                VStack(spacing: 12) {
                    pagePosition(for: selected)
                    broadcastBadge(selected.episode)

                    VStack(spacing: 5) {
                        Text(selected.displayTitle)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        if selected.episode.title != selected.displayTitle {
                            Text(selected.episode.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }

                        Text(selected.episode.formattedDate.capitalized(with: Locale(identifier: "fr_FR")))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    metadata(selected.episode)
                    controls(entry: selected)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await store.load()
        }
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("FRANCE INTER")
                    .font(.caption2.weight(.black))
                    .tracking(2.2)
                    .foregroundStyle(Color(red: 1, green: 0.30, blue: 0.35))
                Text("Aujourd’hui sur Inter")
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
            .accessibilityLabel("Actualiser les émissions")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var artworkCarousel: some View {
        TabView(
            selection: Binding(
                get: { selectedID ?? startingEpisode?.id ?? "" },
                set: { selectedID = $0 }
            )
        ) {
            ForEach(store.episodes) { entry in
                artwork(url: entry.artworkURL)
                    .frame(width: 220, height: 220)
                    .padding(.horizontal, 40)
                    .tag(entry.id)
                    .accessibilityLabel("\(entry.displayTitle), \(entry.episode.formattedTime)")
            }
        }
        .frame(height: 220)
        .tabViewStyle(.page(indexDisplayMode: .never))
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
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.red.opacity(0.17), radius: 24, y: 14)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.12, blue: 0.20), Color(red: 0.28, green: 0.03, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 50, weight: .bold))
                Text("FRANCE INTER")
                    .font(.caption.weight(.black))
                    .tracking(3)
            }
            .foregroundStyle(.white)
        }
    }

    private func pagePosition(for selected: DailyEpisode) -> some View {
        let index = store.episodes.firstIndex(where: { $0.id == selected.id }) ?? 0
        return HStack(spacing: 8) {
            Image(systemName: "chevron.left")
            Text("\(index + 1) / \(store.episodes.count)")
                .monospacedDigit()
            Image(systemName: "chevron.right")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.38))
        .accessibilityLabel("Émission \(index + 1) sur \(store.episodes.count)")
    }

    private func broadcastBadge(_ episode: Episode) -> some View {
        Label("AUJOURD’HUI · \(episode.formattedTime)", systemImage: "waveform")
            .font(.caption2.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(Color(red: 1, green: 0.38, blue: 0.42))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.red.opacity(0.13), in: Capsule())
    }

    private func metadata(_ episode: Episode) -> some View {
        HStack(spacing: 14) {
            if !episode.author.isEmpty {
                metaPill(icon: "person.fill", text: episode.author)
            }
            if let duration = episode.formattedDuration {
                metaPill(icon: "clock.fill", text: duration)
            }
            metaPill(icon: "headphones", text: "Replay")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func metaPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.68))
    }

    private func controls(entry: DailyEpisode) -> some View {
        let episode = entry.episode
        let isLoaded = audioPlayer.isLoaded(episode)
        let isPlaying = audioPlayer.isActivelyPlaying(episode)
        let isBuffering = audioPlayer.isBuffering(episode)
        let elapsed = isLoaded ? audioPlayer.currentTime : 0
        let total = isLoaded && audioPlayer.duration > 0
            ? audioPlayer.duration
            : episode.duration ?? 0

        return VStack(spacing: 14) {
            HStack(spacing: 34) {
                Button { audioPlayer.skip(by: -15) } label: {
                    Image(systemName: "gobackward.15")
                }
                .disabled(!isLoaded)
                .opacity(isLoaded ? 1 : 0.35)

                Button {
                    audioPlayer.toggle(
                        episode: episode,
                        feedTitle: entry.displayTitle,
                        artworkURL: entry.artworkURL
                    )
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.98, green: 0.15, blue: 0.22))
                            .frame(width: 70, height: 70)
                            .shadow(color: Color.red.opacity(0.35), radius: 16, y: 8)
                        if isBuffering {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .bold))
                                .offset(x: isPlaying ? 0 : 2)
                        }
                    }
                }
                .accessibilityLabel(isPlaying ? "Mettre en pause" : "Lire \(entry.displayTitle)")

                Button { audioPlayer.skip(by: 15) } label: {
                    Image(systemName: "goforward.15")
                }
                .disabled(!isLoaded)
                .opacity(isLoaded ? 1 : 0.35)
            }
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .buttonStyle(.plain)

            VStack(spacing: 3) {
                Slider(
                    value: Binding(
                        get: { elapsed },
                        set: { audioPlayer.seek(to: $0) }
                    ),
                    in: 0...max(total, 1)
                )
                .disabled(!isLoaded)
                .tint(Color(red: 1, green: 0.24, blue: 0.30))

                HStack {
                    Text(time(elapsed))
                    Spacer()
                    Text("−\(time(max(total - elapsed, 0)))")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large).tint(.white)
            Text("Préparation des émissions du jour…")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Émissions indisponibles", systemImage: "antenna.radiowaves.left.and.right.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Réessayer") {
                Task {
                    await store.load()
                    selectStartingEpisodeIfNeeded()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .foregroundStyle(.white)
    }

    private func selectStartingEpisodeIfNeeded() {
        if let selectedID,
           store.episodes.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = startingEpisode?.id
    }

    private func time(_ interval: TimeInterval) -> String {
        guard interval.isFinite else { return "0:00" }
        let total = max(Int(interval), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
