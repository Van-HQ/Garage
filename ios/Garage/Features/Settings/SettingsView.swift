import SwiftUI

struct SettingsView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(GarageStore.self) private var store
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if case .signedIn(let user) = auth.state {
                        LabeledContent("Signed in as", value: user.email ?? "Unknown")
                    }
                    Button("Sign out", role: .destructive) { confirmingSignOut = true }
                }

                Section {
                    LabeledContent("Vehicles", value: "\(store.vehicles.count)")
                    LabeledContent("Maintenance types", value: "\(store.snapshot.types.count)")
                } header: {
                    Text("Garage")
                } footer: {
                    Text("Add or edit vehicles, maintenance types and manuals in the web app. Changes show up here after a pull to refresh.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Sign out of Garage on this iPhone?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }
        }
    }
}
