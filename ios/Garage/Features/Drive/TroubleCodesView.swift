import SwiftUI
import GarageCore

/// Stored trouble codes with plain-English explanations, and a way to clear them.
struct TroubleCodesView: View {
    @Environment(OBDSession.self) private var obd
    @Environment(TripController.self) private var trips
    @Environment(GarageStore.self) private var store

    private enum Phase: Equatable {
        case loading
        case loaded([TroubleCodeInfo])
        case failed(String)
    }

    @State private var phase: Phase = .loading
    @State private var confirmingClear = false
    @State private var isClearing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch phase {
                case .loading:
                    ProgressView("Reading codes…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't read codes", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try again") { Task { await load() } }
                    }
                case .loaded(let codes) where codes.isEmpty:
                    ContentUnavailableView(
                        "No stored codes",
                        systemImage: "checkmark.seal",
                        description: Text("The vehicle isn't reporting any trouble codes.")
                    )
                    .padding(.top, 30)
                case .loaded(let codes):
                    ForEach(codes) { info in
                        Panel {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(info.code)
                                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(Theme.statusSoon)
                                Text(info.title)
                                    .font(.headline)
                                    .foregroundStyle(Theme.foreground)
                                Text(info.explanation)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }

                    Button(role: .destructive) {
                        confirmingClear = true
                    } label: {
                        HStack(spacing: 8) {
                            if isClearing { ProgressView() }
                            Text("Clear codes")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isClearing)

                    Text("Clearing turns off the check-engine light and resets the emissions readiness monitors, which take a few days of driving to complete again. If the fault isn't fixed, the code comes back.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background)
        .navigationTitle("Trouble Codes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog("Clear all stored codes?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear codes", role: .destructive) { Task { await clear() } }
        } message: {
            Text("Do this with the engine off and the ignition on. This can't be undone.")
        }
    }

    private func load() async {
        do {
            let codes = try await obd.source.readTroubleCodes()
            phase = .loaded(codes.map(TroubleCodes.info(for:)))
            // Keeping a history is a bonus: if the tables aren't set up yet, showing the codes still works.
            if let vehicle = trips.vehicle {
                try? await store.backend.recordTroubleCodes(vehicleID: vehicle.id, codes: codes)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func clear() async {
        isClearing = true
        defer { isClearing = false }
        do {
            try await obd.source.clearTroubleCodes()
            if let vehicle = trips.vehicle {
                try? await store.backend.markTroubleCodesCleared(vehicleID: vehicle.id)
            }
            await load()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
