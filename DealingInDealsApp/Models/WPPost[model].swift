import Foundation

struct WPPost: Identifiable, Decodable, Hashable {
    let id: Int
    let date: String
    let link: URL
    let title: Rendered
    let content: Rendered
    let featuredMediaURL: URL?

    struct Rendered: Decodable, Hashable {
        let rendered: String
    }

    // WordPress may embed media in `_embedded["wp:featuredmedia"][0].source_url`.
    // We prefer that if present, else fall back to top-level `featuredMediaURL` (if any).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        date = try c.decode(String.self, forKey: .date)
        link = try c.decode(URL.self, forKey: .link)
        title = try c.decode(Rendered.self, forKey: .title)
        content = try c.decode(Rendered.self, forKey: .content)

        // Default to top-level if present
        var mediaURL: URL? = try c.decodeIfPresent(URL.self, forKey: .featuredMediaURL)

        // Try _embedded.wp:featuredmedia[0].source_url
        if let embedded = try? c.nestedContainer(keyedBy: EmbeddedKeys.self, forKey: ._embedded),
           var mediaArr = try? embedded.nestedUnkeyedContainer(forKey: .featuredMedia),
           let media = try? mediaArr.nestedContainer(keyedBy: MediaKeys.self),
           let url = try? media.decode(URL.self, forKey: .sourceURL) {
            mediaURL = url
        }
        featuredMediaURL = mediaURL
    }

    var fallbackImageURL: URL? { nil }

    private enum CodingKeys: String, CodingKey { case id, date, link, title, content, featuredMediaURL = "featuredMediaURL", _embedded }
    private enum EmbeddedKeys: String, CodingKey { case featuredMedia = "wp:featuredmedia" }
    private enum MediaKeys: String, CodingKey { case sourceURL = "source_url" }
}
