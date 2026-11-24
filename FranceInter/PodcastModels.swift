import Foundation

struct PodcastFeed: Equatable {
    let title: String
    let author: String
    let summary: String
    let artworkURL: URL?
    let episodes: [Episode]

    var latestEpisode: Episode? {
        episodes.max { first, second in
            (first.publicationDate ?? .distantPast) < (second.publicationDate ?? .distantPast)
        }
    }
}

struct Episode: Identifiable, Equatable {
    let id: String
    let title: String
    let author: String
    let summary: String
    let publicationDate: Date?
    let duration: TimeInterval?
    let audioURL: URL?
    let artworkURL: URL?
    let category: String

    var formattedDate: String {
        guard let publicationDate else { return "Date inconnue" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter.string(from: publicationDate)
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let total = Int(duration.rounded())
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

