import Foundation

final class PodcastFeedParser: NSObject, XMLParserDelegate {
    private struct DraftEpisode {
        var id = ""
        var title = ""
        var author = ""
        var summary = ""
        var publicationDate: Date?
        var duration: TimeInterval?
        var audioURL: URL?
        var artworkURL: URL?
        var category = ""
    }

    private var feedTitle = ""
    private var feedAuthor = ""
    private var feedSummary = ""
    private var feedArtworkURL: URL?
    private var episodes: [Episode] = []
    private var currentEpisode: DraftEpisode?
    private var currentText = ""
    private var elementPath: [String] = []
    private var parseError: Error?

    func parse(data: Data) throws -> PodcastFeed {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError ?? parseError ?? FeedError.invalidXML
        }

        return PodcastFeed(
            title: feedTitle.nonEmpty ?? "Journal de 07h30",
            author: feedAuthor.nonEmpty ?? "France Inter",
            summary: clean(feedSummary),
            artworkURL: feedArtworkURL,
            episodes: episodes
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = normalized(qName ?? elementName)
        elementPath.append(name)
        currentText = ""

        if name == "item" {
            currentEpisode = DraftEpisode()
        } else if name == "enclosure", currentEpisode != nil {
            currentEpisode?.audioURL = attributeDict["url"].flatMap(URL.init(string:))
        } else if name == "image", currentEpisode != nil,
                  let href = attributeDict["href"] {
            currentEpisode?.artworkURL = URL(string: href)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = normalized(qName ?? elementName)
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if var draft = currentEpisode {
            switch name {
            case "title" where !value.isEmpty: draft.title = value
            case "author" where !value.isEmpty: draft.author = value
            case "description" where !value.isEmpty: draft.summary = value
            case "summary" where !value.isEmpty: draft.summary = value
            case "guid" where !value.isEmpty: draft.id = value
            case "pubdate": draft.publicationDate = Self.parseRSSDate(value)
            case "duration": draft.duration = Self.parseDuration(value)
            case "category" where !value.isEmpty: draft.category = value
            default: break
            }
            currentEpisode = draft
        } else if elementPath.contains("channel") {
            switch name {
            case "title" where feedTitle.isEmpty && !elementPath.contains("image"):
                feedTitle = value
            case "author" where feedAuthor.isEmpty:
                feedAuthor = value
            case "description" where feedSummary.isEmpty:
                feedSummary = value
            case "summary" where feedSummary.isEmpty:
                feedSummary = value
            case "url" where elementPath.contains("image"):
                feedArtworkURL = URL(string: value)
            default: break
            }
        }

        if name == "item", let draft = currentEpisode {
            episodes.append(
                Episode(
                    id: draft.id.nonEmpty ?? draft.audioURL?.absoluteString ?? UUID().uuidString,
                    title: draft.title,
                    author: draft.author.nonEmpty ?? feedAuthor,
                    summary: clean(draft.summary),
                    publicationDate: draft.publicationDate,
                    duration: draft.duration,
                    audioURL: draft.audioURL,
                    artworkURL: draft.artworkURL,
                    category: draft.category
                )
            )
            currentEpisode = nil
        }

        _ = elementPath.popLast()
        currentText = ""
    }

    private func reset() {
        feedTitle = ""
        feedAuthor = ""
        feedSummary = ""
        feedArtworkURL = nil
        episodes = []
        currentEpisode = nil
        currentText = ""
        elementPath = []
        parseError = nil
    }

    private func normalized(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init)?.lowercased() ?? name.lowercased()
    }

    private func clean(_ source: String) -> String {
        let decoded = source
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
        return decoded
            .components(separatedBy: "Vous aimez ce podcast").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? decoded
    }

    static func parseRSSDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: value)
    }

    static func parseDuration(_ value: String) -> TimeInterval? {
        let pieces = value.split(separator: ":").compactMap { Double($0) }
        switch pieces.count {
        case 3: return pieces[0] * 3_600 + pieces[1] * 60 + pieces[2]
        case 2: return pieces[0] * 60 + pieces[1]
        case 1: return pieces[0]
        default: return nil
        }
    }
}

enum FeedError: LocalizedError {
    case invalidXML
    case noEpisodes

    var errorDescription: String? {
        switch self {
        case .invalidXML: "Le flux reçu n’est pas un document XML valide."
        case .noEpisodes: "Aucun journal n’a été trouvé dans le flux."
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

