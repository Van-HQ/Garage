import SwiftUI

struct MainTabView: View {
    @Environment(GarageStore.self) private var store
    @Environment(TripController.self) private var trips
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !store.hasLoaded {
                loadingOrError
            } else {
                TabView {
                    HomeView().tabItem { Label("Home", systemImage: "house") }
                    DriveView().tabItem { Label("Drive", systemImage: "gauge.with.dots.needle.67percent") }
                    CareView().tabItem { Label("Care", systemImage: "wrench.adjustable") }
                    ManualsView().tabItem { Label("Manuals", systemImage: "book.closed") }
                    SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
                }
            }
        }
        .task {
            await store.refresh()
            await trips.syncPending()
        }
        // Retry waiting trips each time the app comes back to the front.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await trips.syncPending() } }
        }
    }

    /// First load only. After that, screens keep showing what they have and offer pull to refresh.
    private var loadingOrError: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let error = store.loadError {
                ContentUnavailableView {
                    Label("Couldn't load your garage", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try again") { Task { await store.refresh() } }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView()
            }
        }
    }
}
