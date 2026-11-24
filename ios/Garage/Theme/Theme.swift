import SwiftUI
import UIKit

/// Neutral charcoal and light gray surfaces with an orange accent in both modes.
enum Theme {
    static let background = dynamic(light: 0xF2F2F5, dark: 0x1A1B1E)
    static let elevated = dynamic(light: 0xFFFFFF, dark: 0x242527)
    static let foreground = dynamic(light: 0x15161A, dark: 0xF5F5F7)
    static let muted = dynamic(light: 0x6B6D76, dark: 0x9A9CA3)
    /// The user's pick from Settings, or the built-in accent.
    static var accent: Color {
        if let hex = Appearance.shared.accentHex { return Color(UIColor(hex: hex)) }
        return dynamic(light: 0xFF6A3D, dark: 0xFF7A4D)
    }
    /// Text on top of the accent: dark on light colors, white on dark ones.
    static var accentForeground: Color {
        if let hex = Appearance.shared.accentHex {
            let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
            return (0.299 * r + 0.587 * g + 0.114 * b) > 160 ? Color(UIColor(hex: 0x1A1B1E)) : .white
        }
        return .white
    }
    static let hairline = dynamic(light: 0xE2E2E7, dark: 0x34353A)
    static let statusOK = dynamic(light: 0x34C759, dark: 0x5BD27D)
    static let statusSoon = dynamic(light: 0xFF9F0A, dark: 0xF5B14D)
    static let statusOverdue = dynamic(light: 0xFF453A, dark: 0xFF5A52)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
