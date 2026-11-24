import SwiftUI
import Observation

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    /// Nil follows the phone's setting.
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The look the user picked in Settings: light or dark, and an accent color.
/// Views that read `Theme.accent` redraw when this changes, because it is observable.
@Observable
final class Appearance: @unchecked Sendable {
    static let shared = Appearance()

    private static let modeKey = "appearance.mode"
    private static let accentKey = "appearance.accent"

    var mode: AppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }
    /// Nil keeps the built-in accent (cream in dark mode, orange in light).
    var accentHex: UInt32? {
        didSet {
            if let accentHex { UserDefaults.standard.set(Int(accentHex), forKey: Self.accentKey) }
            else { UserDefaults.standard.removeObject(forKey: Self.accentKey) }
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        mode = defaults.string(forKey: Self.modeKey).flatMap(AppearanceMode.init(rawValue:)) ?? .system
        accentHex = defaults.object(forKey: Self.accentKey) == nil ? nil : UInt32(defaults.integer(forKey: Self.accentKey))
    }

    /// Ready-made choices; the picker below them allows any color.
    static let swatches: [(name: String, hex: UInt32)] = [
        ("Orange", 0xFF7A4D), ("Red", 0xFF5A52), ("Amber", 0xF5B14D), ("Green", 0x5BD27D),
        ("Teal", 0x2EC4B6), ("Blue", 0x4C9AFF), ("Purple", 0x9B7BFF), ("Pink", 0xFF6FAE),
    ]
}
