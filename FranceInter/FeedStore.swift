import Foundation

struct PodcastSource: Sendable {
    let name: String
    let url: URL

    init(_ name: String, _ url: String) {
        self.name = name
        self.url = URL(string: url)!
    }
}

enum PodcastCatalog {
    static let sources: [PodcastSource] = [
        // This aggregate feed supplies every France Inter news bulletin.
        PodcastSource("Les journaux de France Inter", "https://radiofrance-podcast.net/podcast09/rss_21003.xml"),

        // Useful standalone segments from the morning schedule.
        PodcastSource("L’invité de 6h20", "https://radiofrance-podcast.net/podcast09/podcast_80dc2ff5-fe0e-11e3-907f-782bcb6744eb.xml"),
        PodcastSource("L’invité de 7h50", "https://radiofrance-podcast.net/podcast09/podcast_dfd6c1c6-0c9c-11e3-9f7b-782bcb6744eb.xml"),
        PodcastSource("L’invité de 8h20", "https://radiofrance-podcast.net/podcast09/podcast_ab4b2678-edce-11e1-a7b7-782bcb76618d.xml"),

        // Major daily programs, ordered broadly by their usual broadcast time.
        PodcastSource("Le 5/7", "https://radiofrance-podcast.net/podcast09/podcast_268e46fa-2500-4892-b424-9c79aed89b4e.xml"),
        PodcastSource("Grand bien vous fasse", "https://radiofrance-podcast.net/podcast09/podcast_194ca105-7251-497d-b77e-857503381f5c.xml"),
        PodcastSource("Carnets de campagne", "https://radiofrance-podcast.net/podcast09/podcast_b35bc37b-9bec-479c-a516-95e06f619cb2.xml"),
        PodcastSource("Le Jeu des 1000 euros", "https://radiofrance-podcast.net/podcast09/podcast_48f74c6a-eb98-11e1-a7b7-782bcb76618d.xml"),
        PodcastSource("Le 13/14", "https://radiofrance-podcast.net/podcast09/podcast_87471127-6882-446b-a907-96124b3ec9d7.xml"),
        PodcastSource("La Terre au carré", "https://radiofrance-podcast.net/podcast09/podcast_5e238698-941a-4afc-8883-dbecfda89821.xml"),
        PodcastSource("Affaires sensibles", "https://radiofrance-podcast.net/podcast09/podcast_0b91efaf-26e6-11e4-907f-782bcb6744eb.xml"),
        PodcastSource("Zoom Zoom Zen", "https://radiofrance-podcast.net/podcast09/podcast_9c7ba162-d528-46e6-be4e-9140d60fc2c1.xml"),
        PodcastSource("Un jour dans le monde", "https://radiofrance-podcast.net/podcast09/podcast_2980a1db-3393-4b68-ba22-07523b7e87e0.xml"),
        PodcastSource("Le téléphone sonne", "https://radiofrance-podcast.net/podcast09/podcast_d195f7c2-c97e-4539-a2dc-d001c324f832.xml"),
        PodcastSource("Very Good Trip", "https://radiofrance-podcast.net/podcast09/podcast_2878dd21-967f-45d9-be44-269ec276df92.xml")
    ]
}

@MainActor
final class FeedStore: ObservableObject {
    @Published private(set) var episodes: [DailyEpisode] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let feeds = await withTaskGroup(of: PodcastFeed?.self, returning: [PodcastFeed].self) { group in
            for source in PodcastCatalog.sources {
                group.addTask {
                    await Self.fetch(source)
                }
            }

            var loaded: [PodcastFeed] = []
            for await feed in group {
                if let feed { loaded.append(feed) }
            }
            return loaded
        }

        let now = Date()
        var parisCalendar = Calendar(identifier: .gregorian)
        parisCalendar.locale = Locale(identifier: "fr_FR")
        parisCalendar.timeZone = TimeZone(identifier: "Europe/Paris")!

        let candidates = feeds.flatMap { feed in
            feed.episodes.compactMap { episode -> DailyEpisode? in
                guard let date = episode.publicationDate,
                      date <= now.addingTimeInterval(5 * 60),
                      parisCalendar.isDate(date, inSameDayAs: now),
                      episode.audioURL != nil else { return nil }

                return DailyEpisode(
                    feedTitle: feed.title,
                    feedAuthor: feed.author,
                    feedArtworkURL: feed.artworkURL,
                    episode: episode
                )
            }
        }

        var unique: [String: DailyEpisode] = [:]
        for candidate in candidates {
            unique[candidate.id] = candidate
        }

        episodes = unique.values.sorted {
            ($0.episode.publicationDate ?? .distantPast) < ($1.episode.publicationDate ?? .distantPast)
        }

        if episodes.isEmpty {
            errorMessage = feeds.isEmpty
                ? "Impossible de joindre les flux de France Inter."
                : "Aucune émission avec replay n’est encore disponible aujourd’hui."
        }

        isLoading = false
    }

    nonisolated private static func fetch(_ source: PodcastSource) async -> PodcastFeed? {
        do {
            var request = URLRequest(url: source.url)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                return nil
            }

            return try PodcastFeedParser().parse(data: data)
        } catch {
            return nil
        }
    }
}
