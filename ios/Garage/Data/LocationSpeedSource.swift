import CoreLocation
import Foundation
import GarageCore

/// GPS speed, used when the car doesn't report its own. Runs only while an OBD
/// connection is up, so it never tracks you when you aren't driving.
@MainActor
final class LocationSpeedSource: NSObject, CLLocationManagerDelegate {
    /// Called with each usable fix, as a speed reading in km/h (the unit OBD speed uses).
    var onSpeed: ((OBDReading) -> Void)?

    private let manager = CLLocationManager()
    private var isRunning = false

    /// Ignore fixes less accurate than this, in metres. Speed from a poor fix is noise.
    private static let maxAccuracy = 50.0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            begin()
        default:
            break // denied: trips just rely on the car's speed
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopUpdatingLocation()
    }

    private func begin() {
        // The "location" background mode lets this keep running with the phone locked.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if self.isRunning, status == .authorizedWhenInUse || status == .authorizedAlways { self.begin() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let readings: [OBDReading] = locations.compactMap { location in
            // A negative speed means "unknown".
            guard location.speed >= 0, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= Self.maxAccuracy else { return nil }
            return OBDReading(pid: .speed, value: location.speed * 3.6, timestamp: location.timestamp)
        }
        guard !readings.isEmpty else { return }
        Task { @MainActor in
            for reading in readings { self.onSpeed?(reading) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Nothing to do: a missing fix just means no GPS speed this second.
    }
}
