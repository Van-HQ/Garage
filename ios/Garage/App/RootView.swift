import SwiftUI

struct RootView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(GarageStore.self) private var store

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ZStack {
                    Theme.background.ignoresSafeArea()
                    ProgressView()
                }
            case .signedOut:
                SignInView()
            case .signedIn(let user):
                // A different account gets a fresh tab view and a fresh load.
                MainTabView().id(user.id)
            }
        }
        .task { await auth.observe() }
        .onChange(of: auth.state) { _, state in
            if state == .signedOut { store.reset() }
        }
    }
}

/// Shown when Config.local.xcconfig is missing, instead of crashing at launch.
struct MissingConfigView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ContentUnavailableView(
                "Setup needed",
                systemImage: "gearshape.2",
                description: Text("Run ios/setup.sh on the Mac to create Config.local.xcconfig, then build again.")
            )
        }
    }
}
