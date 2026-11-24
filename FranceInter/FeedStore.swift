import Foundation

@MainActor
final class FeedStore: ObservableObject {
    static let feedURL = URL(
        string: "https://radiofrance-podcast.net/podcast09/podcast_4adfb4af-685b-4006-aeb4-99eeb557a521.xml"
    )!

    @Published private(set) var feed: PodcastFeed?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            var request = URLRequest(url: Self.feedURL)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }

            let parsed = try PodcastFeedParser().parse(data: data)
            guard parsed.latestEpisode != nil else { throw FeedError.noEpisodes }
            feed = parsed
        } catch {
            errorMessage = "Impossible de charger le dernier journal. \(error.localizedDescription)"
        }

        isLoading = false
    }
}

