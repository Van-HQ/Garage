import SwiftUI
import GarageCore

struct HomeView: View {
    @Environment(GarageStore.self) private var store
    @State private var selectedVehicleID: UUID?
    @State private var logPrefill: LogPrefill?
    @State private var detailItem: MaintenanceStatusItem?
    @State private var openedLog: MaintenanceLog?
    @State private var showSettings = false

    private var vehicle: Vehicle? {
        store.vehicles.first { $0.id == selectedVehicleID } ?? store.vehicles.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    pager
                    if let vehicle {
                        maintenanceSection(vehicle)
                        StatsCard(vehicle: vehicle, points: store.trend(for: vehicle))
                        recentSection(vehicle)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle("My Garage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .refreshable { await store.refresh() }
            .sheet(isPresented: $showSettings) { SettingsView().appliesAppearance() }
            .sheet(item: $logPrefill) { LogEntryView(prefill: $0).appliesAppearance() }
            .sheet(item: $detailItem) { item in
                if let vehicle {
                    CareItemDetailView(item: item, vehicle: vehicle) { logPrefill = $0 }
                }
            }
            .sheet(item: $openedLog) { LogDetailView(log: $0).appliesAppearance() }
        }
    }

    @ViewBuilder
    private var pager: some View {
        if store.vehicles.count > 1 {
            VStack(spacing: 14) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(store.vehicles) { vehicle in
                            VehicleHero(vehicle: vehicle)
                                .containerRelativeFrame(.horizontal)
                                .id(vehicle.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $selectedVehicleID)

                HStack(spacing: 8) {
                    ForEach(store.vehicles) { item in
                        let isCurrent = item.id == vehicle?.id
                        Capsule()
                            .fill(isCurrent ? Theme.accent : Theme.muted.opacity(0.35))
                            .frame(width: isCurrent ? 20 : 6, height: 6)
                    }
                }
                .animation(.snappy, value: selectedVehicleID)
                .accessibilityHidden(true)
            }
        } else if let vehicle {
            VehicleHero(vehicle: vehicle)
        }
    }

    private func maintenanceSection(_ vehicle: Vehicle) -> some View {
        let status = Array(store.status(for: vehicle).prefix(4))
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Maintenance")
            if status.isEmpty {
                EmptyPanel(message: "No maintenance items yet. Add some in the web app's Settings.")
            } else {
                ListPanel(items: status) { item in
                    Button { detailItem = item } label: { StatusRow(item: item) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func recentSection(_ vehicle: Vehicle) -> some View {
        let recent = Array(store.logs(for: vehicle).prefix(3))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Recent Activity")
                ListPanel(items: recent) { log in
                    Button { openedLog = log } label: { LogRow(log: log, showYear: false) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}
