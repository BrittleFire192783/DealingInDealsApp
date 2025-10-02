import Foundation

enum DealFormatting {
    // Remove HTML tags & common entities
    static func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
         .replacingOccurrences(of: "&amp;", with: "&")
         .replacingOccurrences(of: "&#8217;", with: "'")
         .replacingOccurrences(of: "&#8220;", with: "\"")
         .replacingOccurrences(of: "&#8221;", with: "\"")
         .replacingOccurrences(of: "&#8230;", with: "…")
    }

    // $12,345.67 or $30
    static func extractPrice(from text: String) -> String? {
        let pattern = #"\$\s*\d{1,3}(?:,\d{3})*(?:\.\d{2})?"#
        guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = r.firstMatch(in: text, options: [], range: range),
              let R = Range(m.range, in: text) else { return nil }
        return text[R].replacingOccurrences(of: " ", with: "")
    }

    // Prefer price in title; fallback to content
    static func price(titleHTML: String, contentHTML: String) -> String? {
        if let p = extractPrice(from: stripHTML(titleHTML)) { return p }
        return extractPrice(from: stripHTML(contentHTML))
    }

    // Friendly timestamp in New York time (“Today 3:41 PM”, “Yesterday 9:12 AM”, “9/8 7:05 PM”)
    static func displayTimestamp(iso: String, tzID: String = AppConfig.nyTimeZoneID) -> String {
        let tz = TimeZone(identifier: tzID) ?? .current

        // 1) Full ISO8601
        let isoFmt = ISO8601DateFormatter()
        if let d = isoFmt.date(from: iso) { return friendly(d, tz: tz) }

        // 2) WP `date` often has no timezone (yyyy-MM-dd'T'HH:mm:ss)
        let df = DateFormatter()
        df.locale = .init(identifier: "en_US_POSIX")
        df.timeZone = tz
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df.date(from: iso) { return friendly(d, tz: tz) }

        // 3) Fallback
        return iso
    }

    private static func friendly(_ date: Date, tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        let f = DateFormatter()
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = tz

        let now = Date()
        if cal.isDate(date, inSameDayAs: now) {
            f.dateFormat = "h:mm a"
            return "Today \(f.string(from: date))"
        }
        if let y = cal.date(byAdding: .day, value: -1, to: now),
           cal.isDate(date, inSameDayAs: y) {
            f.dateFormat = "h:mm a"
            return "Yesterday \(f.string(from: date))"
        }
        f.dateFormat = "M/d h:mm a"
        return f.string(from: date)
    }

    // —— Store parsing & title cleanup ——

    /// Try to infer a store name at the start of the title.
    /// Examples matched:
    /// - "Macys #Ad: …"
    /// - "[Amazon] …"
    /// - "Walmart – …", "Kohl's - …", "Target: …", "Best Buy | …"
    static func storeName(fromTitleHTML html: String) -> String? {
        let raw = stripHTML(html)

        // Pattern 1: “Store #Ad:”
        if let s = firstCapture(#"^([A-Za-z0-9&'’\.\- ]+)\s+#\s*Ad:?"#, in: raw, options: .caseInsensitive) {
            return s.trimmingCharacters(in: .whitespaces)
        }
        // Pattern 2: “[Store] …”
        if let s = firstCapture(#"^\s*\[\s*([A-Za-z0-9&'’\.\- ]+)\s*\]"#, in: raw, options: .caseInsensitive) {
            return s.trimmingCharacters(in: .whitespaces)
        }
        // Pattern 3: “Store –|:|-| | …”
        if let s = firstCapture(#"^\s*([A-Za-z0-9&'’\.\- ]+)\s*[-–:|]\s*"#, in: raw, options: .caseInsensitive) {
            return s.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// Remove "#Ad" and the leading store prefix if we know it.
    static func cleanTitle(titleHTML: String, store: String?) -> String {
        var t = stripHTML(titleHTML)

        // Remove various "#Ad" forms at the start
        t = t.replacingOccurrences(of: #"(?i)^\s*(?:#\s*ad)\s*:?[\s–-]*"#,
                                   with: "",
                                   options: .regularExpression)

        if let store, !store.isEmpty {
            let esc = NSRegularExpression.escapedPattern(for: store)
            // Match “[Store] ”  OR “Store – ” OR “Store - ” OR “Store : ” OR “Store | ”
            let pattern = #"(?i)^\s*(?:\[\s*\#(esc)\s*\]\s*|\#(esc)\s*[-–:|]\s*)"#
                .replacingOccurrences(of: "#(esc)", with: esc)
            t = t.replacingOccurrences(of: pattern,
                                       with: "",
                                       options: .regularExpression)
        }

        // Clean leftover separators at the very start
        t = t.replacingOccurrences(of: #"(?i)^\s*[-–:|]\s*"#,
                                   with: "",
                                   options: .regularExpression)

        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Small regex helper
    private static func firstCapture(_ pattern: String,
                                     in text: String,
                                     options: NSRegularExpression.Options = []) -> String? {
        guard let r = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = r.firstMatch(in: text, options: [], range: range) else { return nil }
        for i in 1..<m.numberOfRanges {
            if let R = Range(m.range(at: i), in: text), !R.isEmpty { return String(text[R]) }
        }
        return nil
    }
}
