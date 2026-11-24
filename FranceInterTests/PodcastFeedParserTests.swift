import XCTest
@testable import FranceInter

final class PodcastFeedParserTests: XCTestCase {
    func testParsesNewestEpisodeAndChannelMetadata() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" version="2.0">
          <channel>
            <title>Journal de 07h30</title>
            <image><url>https://example.com/cover.jpg</url></image>
            <itunes:author>France Inter</itunes:author>
            <item>
              <title>Le journal du lundi</title>
              <guid>older</guid>
              <pubDate>Mon, 23 Nov 2026 07:29:30 +0100</pubDate>
              <enclosure url="https://example.com/older.m4a" type="audio/x-m4a"/>
              <itunes:duration>00:19:47</itunes:duration>
            </item>
            <item>
              <title>Le journal du mardi</title>
              <guid>newer</guid>
              <pubDate>Tue, 24 Nov 2026 07:29:30 +0100</pubDate>
              <enclosure url="https://example.com/newer.m4a" type="audio/x-m4a"/>
              <itunes:duration>00:11:29</itunes:duration>
            </item>
          </channel>
        </rss>
        """

        let feed = try PodcastFeedParser().parse(data: Data(xml.utf8))

        XCTAssertEqual(feed.title, "Journal de 07h30")
        XCTAssertEqual(feed.author, "France Inter")
        XCTAssertEqual(feed.artworkURL?.absoluteString, "https://example.com/cover.jpg")
        XCTAssertEqual(feed.episodes.count, 2)
        XCTAssertEqual(feed.latestEpisode?.id, "newer")
        XCTAssertEqual(feed.latestEpisode?.duration, 689)
        XCTAssertEqual(feed.latestEpisode?.audioURL?.absoluteString, "https://example.com/newer.m4a")
    }

    func testDurationFormats() {
        XCTAssertEqual(PodcastFeedParser.parseDuration("11:29"), 689)
        XCTAssertEqual(PodcastFeedParser.parseDuration("01:02:03"), 3_723)
    }
}

