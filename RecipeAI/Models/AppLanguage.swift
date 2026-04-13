import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, es, zh, hi, ja, fr, th, ko, vi, tr, hy, el, ar, it

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        case .zh: return "中文"
        case .hi: return "हिन्दी"
        case .ja: return "日本語"
        case .fr: return "Français"
        case .th: return "ไทย"
        case .ko: return "한국어"
        case .vi: return "Tiếng Việt"
        case .tr: return "Türkçe"
        case .hy: return "Հայերեն"
        case .el: return "Ελληνικά"
        case .ar: return "العربية"
        case .it: return "Italiano"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func fromLocale(_ locale: Locale) -> AppLanguage {
        let code = locale.language.languageCode?.identifier ?? "en"
        return AppLanguage(rawValue: code) ?? .en
    }
}
