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
    // We prefer that if present; there is no standard top-level URL field, so the
    // `featuredMediaURL` property will typically be nil unless your API adds one.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        date = try c.decode(String.self, forKey: .date)
        link = try c.decode(URL.self, forKey: .link)
        title = try c.decode(Rendered.self, forKey: .title)
        content = try c.decode(Rendered.self, forKey: .content)

        // Default to nil or a custom top-level URL if your API provides it (non-standard).
        var mediaURL: URL? = try c.decodeIfPresent(URL.self, forKey: .featuredMediaURL)

        // Try _embedded.wp:featuredmedia[0].source_url (standard when using `_embed=1`)
        if let embedded = try? c.nestedContainer(keyedBy: EmbeddedKeys.self, forKey: ._embedded),
           var mediaArr = try? embedded.nestedUnkeyedContainer(forKey: .featuredMedia),
           let media = try? mediaArr.nestedContainer(keyedBy: MediaKeys.self),
           let url = try? media.decode(URL.self, forKey: .sourceURL) {
            mediaURL = url
        }
        featuredMediaURL = mediaURL
    }

    // Try to extract a first image URL from the HTML content as a lightweight fallback.
    // This helps DealCard show something when embedded media is absent.
    var fallbackImageURL: URL? {
        // Look for <img ... src="..."> first
        if let src = Self.firstCapture(#"(?is)<img[^>]+src=['"]([^'"]+)['"]"#, in: content.rendered),
           let u = URL(string: src) {
            return u
        }
        // Then try srcset and pick the best candidate
        if let srcset = Self.firstCapture(#"(?is)\bsrcset\s*=\s*['"]([^'"]+)['"]"#, in: content.rendered),
           let best = Self.bestURLFromSrcset(srcset, base: link) {
            return best
        }
        return nil
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = r.firstMatch(in: text, options: [], range: range),
              let R = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[R])
    }

    private static func bestURLFromSrcset(_ srcset: String, base: URL) -> URL? {
        let items = srcset.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var bestURLString: String?
        var bestWidth: Int = -1
        var bestDensity: Double = -1
        for item in items {
            let parts = item.split(whereSeparator: { $0.isWhitespace })
            guard let urlPart = parts.first else { continue }
            let urlString = String(urlPart)
            var width: Int?
            var density: Double?
            if parts.count > 1 {
                for i in 1..<parts.count {
                    let token = parts[i]
                    if token.hasSuffix("w"), let w = Int(token.dropLast()) { width = w }
                    if token.hasSuffix("x"), let d = Double(token.dropLast()) { density = d }
                }
            }
            if let w = width {
                if w > bestWidth { bestWidth = w; bestURLString = urlString }
            } else if let d = density {
                if d > bestDensity { bestDensity = d; bestURLString = urlString }
            } else if bestURLString == nil {
                bestURLString = urlString
            }
        }
        guard let s = bestURLString else { return nil }
        return normalizeURLString(s, base: base)
    }

    private static func normalizeURLString(_ s: String, base: URL) -> URL? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return URL(string: t) }
        if t.hasPrefix("//") { return URL(string: "https:" + t) }
        if t.hasPrefix("/") {
            var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
            comps?.path = t; comps?.query = nil; comps?.fragment = nil
            return comps?.url
        }
        return URL(string: t, relativeTo: base)?.absoluteURL
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, link, title, content
        // Non-standard; decodeIfPresent allows custom backends to provide a direct URL
        case featuredMediaURL = "featuredMediaURL"
        case _embedded
    }
    private enum EmbeddedKeys: String, CodingKey { case featuredMedia = "wp:featuredmedia" }
    private enum MediaKeys: String, CodingKey { case sourceURL = "source_url" }
}
