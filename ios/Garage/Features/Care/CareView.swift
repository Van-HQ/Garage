import SwiftUI
import GarageCore

/// Status of every maintenance item, spending, and the service history for one vehicle.
struct CareView: View {
    @Environment(GarageStore.self) private var store
    @State private var selectedVehicleID: UUID?
    @State private var detailItem: MaintenanceStatusItem?
    @State private var openedLog: MaintenanceLog?
    @State private var logPrefill: LogPrefill?

    private var vehicle: Vehicle? {
        store.vehicles.first { $0.id == selectedVehicleID } ?? store.vehicles.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if store.vehicles.count > 1 {
                        Picker("Vehicle", selection: Binding(
                            get: { vehicle?.id },
                            set: { selectedVehicleID = $0 }
                        )) {
                            ForEach(store.vehicles) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if let vehicle {
                        openCodesSection(vehicle)
                        statusSection(vehicle)
                        spendingSection(vehicle)
                        historySection(vehicle)
                    } else {
                        EmptyPanel(message: "Add a vehicle in the web app's Settings to see maintenance status.")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Theme.background)
            .navigationTitle("Maintenance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        logPrefill = LogPrefill(vehicleID: vehicle?.id)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Log entry")
                    .disabled(store.vehicles.isEmpty)
                }
            }
            .refreshable { await store.refresh() }
            .sheet(item: $detailItem) { item in
                if let vehicle {
                    CareItemDetailView(item: item, vehicle: vehicle) { logPrefill = $0 }
                }
            }
            .sheet(item: $openedLog) { LogDetailView(log: $0).appliesAppearance() }
            .sheet(item: $logPrefill) { LogEntryView(prefill: $0).appliesAppearance() }
        }
    }

    @ViewBuilder
    private func openCodesSection(_ vehicle: Vehicle) -> some View {
        let codes = store.openCodes(for: vehicle)
        if !codes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Check engine")
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(codes, id: \.self) { code in
                            let info = TroubleCodes.info(for: code)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(code)
                                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(Theme.statusSoon)
                                Text(info.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.foreground)
                                Text(info.explanation)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func statusSection(_ vehicle: Vehicle) -> some View {
        let status = store.status(for: vehicle)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Status")
            if status.isEmpty {
                EmptyPanel(message: "No maintenance types set up yet. Add some in the web app's Settings.")
            } else {
                ListPanel(items: status) { item in
                    Button { detailItem = item } label: { StatusRow(item: item) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func spendingSection(_ vehicle: Vehicle) -> some View {
        let cost = computeCostBreakdown(vehicleID: vehicle.id, logs: store.snapshot.logs, types: store.snapshot.types)
        if cost.total > 0 {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Spending")
                CostBreakdownView(data: cost)
            }
        }
    }

    private func historySection(_ vehicle: Vehicle) -> some View {
        let history = store.logs(for: vehicle)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("History")
            if history.isEmpty {
                EmptyPanel(message: "No entries logged yet.")
            } else {
                ListPanel(items: history) { log in
                    Button { openedLog = log } label: { LogRow(log: log) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}
