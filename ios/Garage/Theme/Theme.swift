import SwiftUI
import UIKit

/// The web app's palette (src/app/globals.css): warm charcoal with a cream
/// accent in dark mode, light gray with an orange accent in light mode.
enum Theme {
    static let background = dynamic(light: 0xF2F2F5, dark: 0x1A1B1E)
    static let elevated = dynamic(light: 0xFFFFFF, dark: 0x2B2927)
    static let foreground = dynamic(light: 0x15161A, dark: 0xF5F4F2)
    static let muted = dynamic(light: 0x6B6D76, dark: 0x9C9791)
    static let accent = dynamic(light: 0xFF6A3D, dark: 0xE6D3C1)
    static let accentForeground = dynamic(light: 0xFFFFFF, dark: 0x1A1B1E)
    static let hairline = dynamic(light: 0xE2E2E7, dark: 0x3B3835)
    static let statusOK = dynamic(light: 0x34C759, dark: 0x5BD27D)
    static let statusSoon = dynamic(light: 0xFF9F0A, dark: 0xF5B14D)
    static let statusOverdue = dynamic(light: 0xFF453A, dark: 0xFF5A52)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
