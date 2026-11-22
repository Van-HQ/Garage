import Foundation

/// Something worth interrupting the driver for.
public struct DriveAlert: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case coolantHot
        case checkEngine
    }

    public let kind: Kind
    /// Stable per cause, so the same problem never alerts twice (a code's id includes the code).
    public let id: String
    public let title: String
    public let message: String

    public init(kind: Kind, id: String, title: String, message: String) {
        self.kind = kind
        self.id = id
        self.title = title
        self.message = message
    }
}

/// The rules behind drive alerts, kept free of UI so they can be tested.
public enum DriveAlerts {
    /// Coolant above this (°C, about 230 °F) is hotter than a healthy engine runs.
    public static let coolantHotCelsius = 110.0
    /// It has to fall below this before the warning can fire again, so a reading
    /// bouncing around the limit doesn't re-alert.
    public static let coolantRecoveredCelsius = 105.0

    /// Returns an alert when coolant crosses into "too hot". `wasHot` is whether
    /// the previous reading already was, so one overheat gives one alert.
    public static func coolant(celsius: Double, wasHot: Bool) -> (isHot: Bool, alert: DriveAlert?) {
        if wasHot {
            return (celsius >= coolantRecoveredCelsius, nil)
        }
        guard celsius >= coolantHotCelsius else { return (false, nil) }
        let fahrenheit = Int((celsius * 9 / 5 + 32).rounded())
        return (true, DriveAlert(
            kind: .coolantHot,
            id: "coolant-hot",
            title: "Engine running hot",
            message: "Coolant is \(fahrenheit) °F. Pull over somewhere safe and let the engine cool."
        ))
    }

    /// One alert for each code that wasn't in the previous read.
    public static func newCodes(previous: Set<String>, current: [String]) -> [DriveAlert] {
        current.filter { !previous.contains($0) }.map { code in
            let info = TroubleCodes.info(for: code)
            return DriveAlert(
                kind: .checkEngine,
                id: "code-\(code)",
                title: "Check engine light",
                message: "\(code): \(info.title)"
            )
        }
    }
}
