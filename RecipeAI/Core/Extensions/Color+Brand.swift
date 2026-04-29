import SwiftUI

extension Color {
    // MARK: - Brand Colors

    /// Light brand green - #E2EFDD
    static let brandGreenLight = Color(hex: "E2EFDD")

    /// Dark brand green - #008557
    static let brandGreenDark = Color(hex: "008557")

    // MARK: - Recipe Image Placeholder

    /// Cool mint white — top of the placeholder gradient
    static let placeholderBgTop = Color(hex: "F4FAF7")
    /// Brand-green light — bottom of the placeholder gradient (matches `brandGreenLight`)
    static let placeholderBgBottom = Color(hex: "E2EFDD")

    // MARK: - Status Colors

    /// Success green - #4CAF50
    static let statusGreen = Color(hex: "4CAF50")

    /// Warning orange - #FF9800
    static let statusOrange = Color(hex: "FF9800")

    /// Error red - #F44336
    static let statusRed = Color(hex: "F44336")

    // MARK: - UI Colors

    /// Primary accent - #FF6200EE
    static let primaryAccent = Color(hex: "FF6200EE")

    /// Background color
    static let backgroundPrimary = Color(UIColor.systemBackground)

    /// Secondary background
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)

    /// Card background
    static let cardBackground = Color(UIColor.tertiarySystemBackground)

    // MARK: - Text Colors

    /// Primary text
    static let textPrimary = Color(UIColor.label)

    /// Secondary text
    static let textSecondary = Color(UIColor.secondaryLabel)

    /// Tertiary text
    static let textTertiary = Color(UIColor.tertiaryLabel)

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
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
