import SwiftUI

@main
struct GarageApp: App {
    @State private var services = AppServices.make()

    var body: some Scene {
        WindowGroup {
            Group {
                if let services {
                    RootView()
                        .environment(services.auth)
                        .environment(services.store)
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

    /// Nil when the Supabase settings are missing from the build.
    static func make() -> AppServices? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            return AppServices(
                auth: AuthModel(service: DemoAuthService()),
                store: GarageStore(backend: DemoBackend())
            )
        }
        #endif
        guard let config = AppConfig.load() else { return nil }
        let client = makeSupabaseClient(config: config)
        return AppServices(
            auth: AuthModel(service: SupabaseAuthService(client: client)),
            store: GarageStore(backend: SupabaseBackend(client: client))
        )
    }
}
