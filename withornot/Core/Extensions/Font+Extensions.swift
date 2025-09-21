import SwiftUI

extension Font {
    // Google Sans Code 폰트 정의
    static func googleSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName = "GoogleSansCode-VariableFont_wght"

        // Weight에 따른 폰트 반환
        switch weight {
        case .ultraLight:
            return .custom(fontName, size: size).weight(.ultraLight)
        case .thin:
            return .custom(fontName, size: size).weight(.thin)
        case .light:
            return .custom(fontName, size: size).weight(.light)
        case .regular:
            return .custom(fontName, size: size).weight(.regular)
        case .medium:
            return .custom(fontName, size: size).weight(.medium)
        case .semibold:
            return .custom(fontName, size: size).weight(.semibold)
        case .bold:
            return .custom(fontName, size: size).weight(.bold)
        case .heavy:
            return .custom(fontName, size: size).weight(.heavy)
        case .black:
            return .custom(fontName, size: size).weight(.black)
        default:
            return .custom(fontName, size: size).weight(.regular)
        }
    }

    // 앱 전체에서 사용할 텍스트 스타일
    static let largeTitle = googleSans(size: 34, weight: .bold)
    static let title = googleSans(size: 28, weight: .bold)
    static let title2 = googleSans(size: 22, weight: .semibold)
    static let title3 = googleSans(size: 20, weight: .semibold)
    static let headline = googleSans(size: 17, weight: .semibold)
    static let body = googleSans(size: 17, weight: .regular)
    static let callout = googleSans(size: 16, weight: .regular)
    static let subheadline = googleSans(size: 15, weight: .regular)
    static let footnote = googleSans(size: 13, weight: .regular)
    static let caption = googleSans(size: 12, weight: .regular)
    static let caption2 = googleSans(size: 11, weight: .regular)
}