import Foundation

enum WordPressAPI {
    // Build the “latest posts” URL
    static func latestPostsURL(search: String? = nil, page: Int? = nil) -> URL? {
        var comps = URLComponents(string: AppConfig.basePosts)!
        var items: [URLQueryItem] = [
            .init(name: "_fields", value: "id,date,link,title,content,_embedded"),
            .init(name: "_embed", value: "1"),
            .init(name: "orderby", value: "date"),
            .init(name: "order", value: "desc"),
            .init(name: "per_page", value: "100"),
        ]
        if let q = search?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
            items.append(.init(name: "search", value: q))
        }
        if let page = page {
            items.append(.init(name: "page", value: String(page)))
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
        var all: [WPPost] = []
        let decoder = JSONDecoder()

        var page = 1
        let perPage = 100
        while all.count < 7500 {
            guard let url = latestPostsURL(search: search, page: page) else {
                throw URLError(.badURL)
            }
            let (data, resp) = try await session().data(from: url)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let batch = try decoder.decode([WPPost].self, from: data)
            if batch.isEmpty { break }
            all.append(contentsOf: batch)

            // If the server returned fewer than requested, we've hit the end
            if batch.count < perPage { break }
            page += 1
        }

        // Cap at 7500 and preserve server-provided order
        return Array(all.prefix(7500))
    }
}
