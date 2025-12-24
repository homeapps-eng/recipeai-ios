import SwiftUI

extension Font {
    // MARK: - San Francisco System Fonts (Apple Native)
    // Using Apple's San Francisco font family for optimal iOS experience

    /// SF Pro Regular
    static func sfPro(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    /// SF Pro Medium
    static func sfProMedium(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    /// SF Pro Semibold
    static func sfProSemiBold(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// SF Pro Bold
    static func sfProBold(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    // For rounded variant (SF Pro Rounded)
    static func sfProRounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Semantic Fonts (Using Apple's Dynamic Type Scale)

    /// Large title - 34pt Bold
    static let appLargeTitle: Font = .largeTitle.bold()

    /// Title 1 - 28pt Bold
    static let appTitle1: Font = .title.bold()

    /// Title 2 - 22pt Semibold
    static let appTitle2: Font = .title2.weight(.semibold)

    /// Title 3 - 20pt Semibold
    static let appTitle3: Font = .title3.weight(.semibold)

    /// Headline - 17pt Semibold
    static let appHeadline: Font = .headline

    /// Body - 17pt Regular
    static let appBody: Font = .body

    /// Callout - 16pt Regular
    static let appCallout: Font = .callout

    /// Subheadline - 15pt Regular
    static let appSubheadline: Font = .subheadline

    /// Footnote - 13pt Regular
    static let appFootnote: Font = .footnote

    /// Caption 1 - 12pt Regular
    static let appCaption1: Font = .caption

    /// Caption 2 - 11pt Regular
    static let appCaption2: Font = .caption2

    /// Button text - 16pt Medium
    static let appButton: Font = .system(size: 16, weight: .medium)

    /// Small button text - 14pt Medium
    static let appButtonSmall: Font = .system(size: 14, weight: .medium)

    // MARK: - Legacy Aliases (for compatibility)
    // These map to SF Pro equivalents

    static func poppins(size: CGFloat) -> Font { sfPro(size: size) }
    static func poppinsMedium(size: CGFloat) -> Font { sfProMedium(size: size) }
    static func poppinsSemiBold(size: CGFloat) -> Font { sfProSemiBold(size: size) }
    static func poppinsBold(size: CGFloat) -> Font { sfProBold(size: size) }
}
