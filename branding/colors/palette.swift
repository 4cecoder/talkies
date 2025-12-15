/**
 * Talkies Brand Color Palette
 * Swift/SwiftUI Color Extensions
 */

import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let brandPurple = Color(hex: "a855f7")
    static let brandPink = Color(hex: "ec4899")

    // MARK: - Supporting Colors
    static let brandBlue = Color(hex: "3b82f6")
    static let brandCyan = Color(hex: "06b6d4")
    static let brandOrange = Color(hex: "f97316")

    // MARK: - Background Colors
    static let bgPrimary = Color(hex: "0a0a0f")
    static let bgCard = Color.white.opacity(0.05)
    static let bgCardHover = Color.white.opacity(0.08)
    static let bgInput = Color.white.opacity(0.05)

    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    static let textMuted = Color.white.opacity(0.4)

    // MARK: - Border Colors
    static let borderDefault = Color.white.opacity(0.1)
    static let borderHover = Color.white.opacity(0.2)
    static let borderFocus = Color.brandPurple.opacity(0.5)

    // MARK: - Gradients
    static let gradientPrimary = LinearGradient(
        colors: [.brandPurple, .brandPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientGlow = LinearGradient(
        colors: [.brandPurple.opacity(0.3), .brandPink.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
