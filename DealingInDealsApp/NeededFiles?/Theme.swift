import SwiftUI

enum AppTheme {
    // Accent color inspired by bold deal highlights
    static let accent = Color(hex: "#EF4444") // red-500

    // App background gradient (dark slate tones)
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "#0F172A"), Color(hex: "#111827")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Card styling on dark background
    static let cardBackground = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.08)
    static let cardPlaceholder = Color.white.opacity(0.06)
}

extension Color {
    /// Initialize Color from hex strings like "#RRGGBB" or "#RRGGBBAA"
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((rgb & 0xFF00_0000) >> 24) / 255
            g = Double((rgb & 0x00FF_0000) >> 16) / 255
            b = Double((rgb & 0x0000_FF00) >> 8) / 255
            a = Double(rgb & 0x0000_00FF) / 255
        } else {
            r = Double((rgb & 0xFF0000) >> 16) / 255
            g = Double((rgb & 0x00FF00) >> 8) / 255
            b = Double(rgb & 0x0000FF) / 255
            a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
