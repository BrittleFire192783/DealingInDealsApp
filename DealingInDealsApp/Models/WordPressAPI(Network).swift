import Foundation

enum WordPressAPI {
    // Build the “latest posts” URL
    static func latestPostsURL(search: String? = nil) -> URL? {
        var comps = URLComponents(string: AppConfig.basePosts)!
        var items: [URLQueryItem] = [
            .init(name: "per_page", value: String(AppConfig.perPage)),
            .init(name: "after", value: AppConfig.afterISO8601),
            .init(name: "_fields", value: "id,date,link,title,content,_embedded"),
            .init(name: "_embed", value: "1")
        ]
        if let q = search?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
            items.append(.init(name: "search", value: q))
        }
        comps.queryItems = items
        return comps.url
    }

    // Shared URLSession (respects AppConfig.requestTimeout)
    static func session() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = AppConfig.requestTimeout
        return URLSession(configuration: cfg)
    }

    // Fetch & decode posts
    static func latestPosts(search: String? = nil) async throws -> [WPPost] {
        guard let url = latestPostsURL(search: search) else {
            throw URLError(.badURL)
        }
        let (data, resp) = try await session().data(from: url)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        // Default decoding for our custom init in WPPost
        let posts = try decoder.decode([WPPost].self, from: data)
        return posts
    }
}
