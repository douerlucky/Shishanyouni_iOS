import SwiftUI

extension Color
{
    static func adaptive(light: Color, dark: Color) -> Color
    {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    static func adaptive(hue: Double, saturation: Double, brightness: Double, darkBrightness: Double = 0.0) -> Color
    {
        Color(uiColor: UIColor { trait in
            let b = trait.userInterfaceStyle == .dark ? darkBrightness : brightness
            return UIColor(hue: hue, saturation: saturation, brightness: b, alpha: 1)
        })
    }
}

enum AdaptiveColors
{
    static let glassStroke = Color.adaptive(
        light: .white.opacity(0.3),
        dark: .white.opacity(0.12)
    )
    static let glassStrokeBottom = Color.adaptive(
        light: .white.opacity(0.1),
        dark: .white.opacity(0.05)
    )

    static let statGreen = Color.adaptive(
        light: Color(red: 0.26, green: 0.69, blue: 0.31),
        dark: Color(red: 0.35, green: 0.75, blue: 0.40)
    )
    static let statOrange = Color.adaptive(
        light: Color(red: 0.94, green: 0.46, blue: 0.22),
        dark: Color(red: 0.95, green: 0.55, blue: 0.32)
    )
    static let statBlue = Color.adaptive(
        light: Color(red: 0.07, green: 0.47, blue: 0.84),
        dark: Color(red: 0.20, green: 0.60, blue: 0.90)
    )
    static let libraryGreen1 = Color.adaptive(
        light: Color(red: 0.26, green: 0.69, blue: 0.31),
        dark: Color(red: 0.35, green: 0.75, blue: 0.40)
    )
    static let libraryGreen2 = Color.adaptive(
        light: Color(red: 0.15, green: 0.55, blue: 0.35),
        dark: Color(red: 0.10, green: 0.40, blue: 0.25)
    )
    static let libraryStatGreen = Color.adaptive(
        light: Color(red: 0.49, green: 0.78, blue: 0.54),
        dark: Color(red: 0.55, green: 0.82, blue: 0.60)
    )

    static let cropButtonBg = Color.adaptive(
        light: .white,
        dark: Color(.systemGray5)
    )
    static let cropGridOverlay = Color.adaptive(
        light: .white.opacity(0.3),
        dark: .black.opacity(0.3)
    )

    static func adaptiveCourseColors() -> [Color]
    {
        let lightColors: [Color] = [
            .brown,
            Color(red: 0.5, green: 0.2, blue: 0.8),
            Color(red: 0.9, green: 0.3, blue: 0.5),
            Color(red: 0.2, green: 0.6, blue: 0.4),
            Color(red: 0.4, green: 0.7, blue: 0.9),
            Color(red: 0.7, green: 0.5, blue: 0.9),
            Color(red: 0.9, green: 0.6, blue: 0.4),
            Color(red: 0.5, green: 0.8, blue: 0.6),
            Color(red: 0.9, green: 0.5, blue: 0.6),
            Color(red: 0.6, green: 0.4, blue: 0.7),
            Color(red: 0.3, green: 0.5, blue: 0.7),
            Color(red: 0.8, green: 0.6, blue: 0.3),
            Color(red: 0.2, green: 0.3, blue: 0.5),
            Color(red: 0.3, green: 0.5, blue: 0.3),
            Color(red: 0.6, green: 0.3, blue: 0.2),
            Color(red: 0.5, green: 0.2, blue: 0.4),
            Color(red: 0.2, green: 0.5, blue: 0.5),
            Color(red: 0.5, green: 0.4, blue: 0.2),
            Color(red: 0.4, green: 0.2, blue: 0.5),
            Color(red: 0.6, green: 0.2, blue: 0.3),
        ]
        return lightColors.map { color in
            Color.adaptive(
                light: color,
                dark: color.opacity(0.7)
            )
        }
    }

    static func adaptiveMenuColors() -> [(key: String, color: Color)]
    {
        let lightMap: [(String, Color)] = [
            ("red1", Color(red: 0.89, green: 0.24, blue: 0.22)),
            ("red2", Color(red: 0.80, green: 0.18, blue: 0.30)),
            ("orange1", Color(red: 0.95, green: 0.47, blue: 0.18)),
            ("orange2", Color(red: 0.90, green: 0.58, blue: 0.16)),
            ("yellow1", Color(red: 0.86, green: 0.73, blue: 0.16)),
            ("yellow2", Color(red: 0.72, green: 0.76, blue: 0.18)),
            ("green1", Color(red: 0.26, green: 0.69, blue: 0.31)),
            ("green2", Color(red: 0.15, green: 0.71, blue: 0.47)),
            ("cyan1", Color(red: 0.12, green: 0.70, blue: 0.74)),
            ("cyan2", Color(red: 0.13, green: 0.63, blue: 0.86)),
            ("blue1", Color(red: 0.20, green: 0.49, blue: 0.92)),
            ("blue2", Color(red: 0.30, green: 0.40, blue: 0.88)),
            ("purple1", Color(red: 0.50, green: 0.34, blue: 0.86)),
            ("purple2", Color(red: 0.69, green: 0.34, blue: 0.78)),
        ]
        return lightMap.map { (key, light) in
            (key, Color.adaptive(light: light, dark: light.opacity(0.7)))
        }
    }
}
