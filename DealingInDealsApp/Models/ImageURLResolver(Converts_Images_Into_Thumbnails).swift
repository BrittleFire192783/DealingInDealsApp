//
//  ImageURLResolver.swift
//  DealingInDealsApp
//
//  Created by Ishan Bansal on 9/10/25.
//

import Foundation

/// Fallback that fetches the post HTML and reads `<meta property="og:image">` or `twitter:image`.
actor ImageURLResolver {
    static let shared = ImageURLResolver()

    // In-memory cache: pageURL -> imageURL
    private var cache: [URL: URL] = [:]

    // Disk cache (TTL-based) stored in Caches directory
    private struct Entry: Codable { let image: String; let ts: Date }
    private var disk: [String: Entry] = [:] // key: pageURL.absoluteString
    private let ttl: TimeInterval = 60 * 60 * 24 * 7 // 7 days
    private let storeURL: URL = {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImageURLResolverCache.json")
    }()

    init() {
        // Load disk cache; prune expired; hydrate in-memory cache
        if let data = try? Data(contentsOf: storeURL),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            let now = Date()
            var kept: [String: Entry] = [:]
            for (k, v) in decoded {
                if now.timeIntervalSince(v.ts) < ttl, let page = URL(string: k), let img = URL(string: v.image) {
                    kept[k] = v
                    cache[page] = img
                }
            }
            disk = kept
        }
    }

    private func saveDisk() {
        if let data = try? JSONEncoder().encode(disk) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    func resolve(from pageURL: URL, timeout: TimeInterval = 15) async -> URL? {
        // 1) In-memory cache
        if let cached = cache[pageURL] { return cached }

        // 2) Disk cache
        if let entry = disk[pageURL.absoluteString] {
            if Date().timeIntervalSince(entry.ts) < ttl, let u = URL(string: entry.image) {
                cache[pageURL] = u
                return u
            } else {
                // expired; drop it
                disk.removeValue(forKey: pageURL.absoluteString)
            }
        }

        // 3) Fetch HTML and parse
        var req = URLRequest(url: pageURL)
        req.timeoutInterval = timeout
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            // Try candidates in order of preference
            if let u = firstMetaImage(in: html, base: pageURL) ?? firstSrcsetImage(in: html, base: pageURL) {
                cache[pageURL] = u
                disk[pageURL.absoluteString] = .init(image: u.absoluteString, ts: Date())
                saveDisk()
                return u
            }
        } catch {
            // ignore; fallback stays nil
        }
        return nil
    }

    // MARK: - Parsing helpers

    // Prefer secure OG image; then OG; then Twitter variants; then link rel image_src
    private func firstMetaImage(in html: String, base: URL) -> URL? {
        // 1) og:image:secure_url
        if let s = Self.capture(#"(?i)<meta\s+property=[\"']og:image:secure_url[\"']\s+content=[\"']([^\"']+)[\"']"#, in: html),
           let u = Self.normalize(s, base: base) { return u }

        // 2) og:image
        if let s = Self.capture(#"(?i)<meta\s+property=[\"']og:image[\"']\s+content=[\"']([^\"']+)[\"']"#, in: html),
           let u = Self.normalize(s, base: base) { return u }

        // 3) twitter:image:src
        if let s = Self.capture(#"(?i)<meta\s+name=[\"']twitter:image:src[\"']\s+content=[\"']([^\"']+)[\"']"#, in: html),
           let u = Self.normalize(s, base: base) { return u }

        // 4) twitter:image
        if let s = Self.capture(#"(?i)<meta\s+name=[\"']twitter:image[\"']\s+content=[\"']([^\"']+)[\"']"#, in: html),
           let u = Self.normalize(s, base: base) { return u }

        // 5) link rel="image_src"
        if let s = Self.capture(#"(?i)<link\s+rel=[\"']image_src[\"']\s+href=[\"']([^\"']+)[\"']"#, in: html),
           let u = Self.normalize(s, base: base) { return u }

        return nil
    }

    private func firstSrcsetImage(in html: String, base: URL) -> URL? {
        // Find first srcset attribute anywhere; then pick the best candidate
        if let srcset = Self.capture(#"(?is)\bsrcset\s*=\s*[\"']([^\"']+)[\"']"#, in: html) {
            return Self.bestURLFromSrcset(srcset, base: base)
        }
        return nil
    }

    private static func bestURLFromSrcset(_ srcset: String, base: URL) -> URL? {
        // Split on commas; choose the largest width (or, if no widths, highest density)
        let items = srcset.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var bestURLString: String?
        var bestWidth: Int = -1
        var bestDensity: Double = -1
        for item in items {
            // Each item: "url [width|density]"
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
                bestURLString = urlString // fallback to first
            }
        }
        guard let s = bestURLString else { return nil }
        return normalize(s, base: base)
    }

    // MARK: - Utilities

    private static func capture(_ pattern: String, in html: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let rng = NSRange(html.startIndex..., in: html)
        guard let m = r.firstMatch(in: html, options: [], range: rng),
              let r1 = Range(m.range(at: 1), in: html) else { return nil }
        return String(html[r1])
    }

    private static func normalize(_ s: String, base: URL) -> URL? {
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
}
