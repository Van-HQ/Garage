import SwiftUI
import GarageCore

@main
struct GarageApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let services = AppServices.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if let services {
                    RootView()
                        .environment(services.auth)
                        .environment(services.store)
                        .environment(services.obd)
                        .environment(services.trips)
                } else {
                    MissingConfigView()
                }
            }
            .tint(Theme.accent)
        }
    }
}

/// The long-lived objects the app runs on, built once at launch.
@MainActor
struct AppServices {
    let auth: AuthModel
    let store: GarageStore
    /// Live vehicle data. The simulator for now; the Bluetooth adapter slots in here later.
    let obd: OBDSession
    let trips: TripController

    init(auth: AuthModel, store: GarageStore) {
        self.auth = auth
        self.store = store
        let obd = OBDSession(source: Self.makeSource(simulated: Self.wantsSimulator))
        self.obd = obd
        self.trips = TripController(obd: obd, store: store)
    }

    static let simulatorKey = "obd.useSimulator"

    /// Demo mode always simulates. Otherwise the Settings switch decides; it starts off, meaning a real adapter.
    static var wantsSimulator: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") { return true }
        #endif
        return UserDefaults.standard.bool(forKey: simulatorKey)
    }

    static func makeSource(simulated: Bool) -> OBDDataSource {
        simulated
            ? SimulatedOBDSource()
            : ELM327Source(displayName: "Bluetooth adapter") { try await BLEAdapterTransport.open() }
    }

    /// One shared set, so the phone and CarPlay scenes use the same data and OBD session.
    static let shared: AppServices? = make()

    /// Nil when the Supabase settings are missing from the build.
    static func make() -> AppServices? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            return AppServices(auth: AuthModel(service: DemoAuthService()), store: GarageStore(backend: DemoBackend()))
        }
        #endif
        guard let config = AppConfig.load() else { return nil }
        let client = makeSupabaseClient(config: config)
        return AppServices(auth: AuthModel(service: SupabaseAuthService(client: client)), store: GarageStore(backend: SupabaseBackend(client: client)))
    }
}
