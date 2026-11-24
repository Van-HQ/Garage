import SwiftUI

struct MainTabView: View {
    @Environment(GarageStore.self) private var store
    @Environment(TripController.self) private var trips
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .home
    @State private var logPrefill: LogPrefill?

    private enum AppTab: Hashable { case home, drive, care, manuals, log }

    var body: some View {
        Group {
            if !store.hasLoaded {
                loadingOrError
            } else {
                TabView(selection: $selection) {
                    Tab("Home", systemImage: "house", value: AppTab.home) { HomeView() }
                    Tab("Drive", systemImage: "gauge.with.dots.needle.67percent", value: AppTab.drive) { DriveView() }
                    Tab("Care", systemImage: "wrench.adjustable", value: AppTab.care) { CareView() }
                    Tab("Manuals", systemImage: "book.closed", value: AppTab.manuals) { ManualsView() }
                    // Shows as its own round button beside the tab bar. It never opens a screen: it opens the log sheet.
                    Tab("Log", systemImage: "plus", value: AppTab.log, role: .search) { Color.clear }
                }
                .onChange(of: selection) { previous, new in
                    guard new == .log else { return }
                    selection = previous
                    logPrefill = LogPrefill(vehicleID: nil)
                }
                .sheet(item: $logPrefill) { LogEntryView(prefill: $0).appliesAppearance() }
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
