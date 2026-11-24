import SwiftUI

/// Settings, opened from the gear on Home. Each row shows only its name; the details are one tap in.
struct SettingsView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingSignOut = false

    private var email: String {
        if case .signedIn(let user) = auth.state { return user.email ?? "" }
        return ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NavigationLink { AccountSettingsView() } label: { profileCard }
                        .buttonStyle(.plain)

                    group("Garage") {
                        SettingsLink(title: "Vehicles and maintenance", symbol: "car") { GarageSettingsView() }
                    }
                    group("Drive") {
                        SettingsLink(title: "Drive data", symbol: "gauge.with.dots.needle.67percent") { DriveDataSettingsView() }
                    }
                    group("Look") {
                        SettingsLink(title: "Appearance", symbol: "circle.lefthalf.filled") { AppearanceSettingsView() }
                        Divider().overlay(Theme.hairline).padding(.leading, 56)
                        SettingsLink(title: "Accent color", symbol: "paintpalette") { AccentColorSettingsView() }
                    }

                    Button { confirmingSignOut = true } label: {
                        Panel(padding: 16) {
                            Text("Sign out")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.statusOverdue)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)

                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
            .appliesAppearance()
            .confirmationDialog("Sign out of Garage on this iPhone?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    dismiss()
                    Task { await auth.signOut() }
                }
            }
        }
    }

    private var profileCard: some View {
        Panel(padding: 16) {
            HStack(spacing: 14) {
                Text(String(email.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(width: 52, height: 52)
                    .background(Theme.hairline.opacity(0.6), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Account").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.foreground)
                    Text(email).font(.footnote).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title)
            Panel(padding: 0) { VStack(spacing: 0, content: content) }
        }
    }
}

/// One tappable row: an icon, a name and a chevron. Nothing else until you open it.
private struct SettingsLink<Destination: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Detail screens

private struct AccountSettingsView: View {
    @Environment(AuthModel.self) private var auth

    var body: some View {
        Form {
            if case .signedIn(let user) = auth.state {
                LabeledContent("Signed in as", value: user.email ?? "Unknown")
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GarageSettingsView: View {
    @Environment(GarageStore.self) private var store

    var body: some View {
        Form {
            Section {
                LabeledContent("Vehicles", value: "\(store.vehicles.count)")
                LabeledContent("Maintenance types", value: "\(store.snapshot.types.count)")
            } footer: {
                Text("Add or edit vehicles, maintenance types and manuals in the web app. Changes show up here after a pull to refresh.")
            }
        }
        .navigationTitle("Vehicles and maintenance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DriveDataSettingsView: View {
    @Environment(OBDSession.self) private var obd
    @AppStorage(AppServices.simulatorKey) private var useSimulator = false

    var body: some View {
        Form {
            Section {
                Toggle("Simulated drive", isOn: $useSimulator)
            } footer: {
                Text("Off reads a real Bluetooth OBD-II adapter plugged into the car. On plays a made-up drive, for trying the app without one.")
            }
        }
        .onChange(of: useSimulator) { _, simulated in
            obd.use(AppServices.makeSource(simulated: simulated))
        }
        .navigationTitle("Drive data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppearanceSettingsView: View {
    var body: some View {
        @Bindable var appearance = Appearance.shared
        Form {
            Picker("Appearance", selection: $appearance.mode) {
                ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AccentColorSettingsView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    var body: some View {
        @Bindable var appearance = Appearance.shared
        let custom = Binding<Color>(
            get: { appearance.accentHex.map { Color(UIColor(hex: $0)) } ?? Theme.accent },
            set: { appearance.accentHex = $0.hexValue }
        )
        Form {
            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Appearance.swatches, id: \.hex) { swatch in
                        Button { appearance.accentHex = swatch.hex } label: {
                            Circle()
                                .fill(Color(UIColor(hex: swatch.hex)))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if appearance.accentHex == swatch.hex {
                                        Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(swatch.name)
                    }
                }
                .padding(.vertical, 6)
                ColorPicker("Custom color", selection: custom, supportsOpacity: false)
            }
            Section {
                Button("Use the default") { appearance.accentHex = nil }
                    .disabled(appearance.accentHex == nil)
            }
        }
        .navigationTitle("Accent color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Color {
    /// 0xRRGGBB for the color, in sRGB.
    var hexValue: UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt32((r * 255).rounded()) << 16) | (UInt32((g * 255).rounded()) << 8) | UInt32((b * 255).rounded())
    }
}
