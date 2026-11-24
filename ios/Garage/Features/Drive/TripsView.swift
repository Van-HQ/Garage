import SwiftUI
import GarageCore

/// Recorded drives, newest first, with any that are still waiting to upload on top.
struct TripsView: View {
    @Environment(GarageStore.self) private var store
    @Environment(TripController.self) private var trips

    private enum Phase {
        case loading
        case loaded([Trip])
        case failed(String)
    }

    @State private var phase: Phase = .loading
    @State private var confirmingDiscard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !trips.pending.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Waiting to upload") {
                            HStack(spacing: 16) {
                                Button("Discard", role: .destructive) { confirmingDiscard = true }
                                Button("Retry") { Task { await trips.syncPending(); await load() } }
                                    .disabled(trips.isSyncing)
                            }
                        }
                        ListPanel(items: trips.pending) { item in
                            row(item.trip.summary, pending: true)
                        }
                        if let problem = trips.syncProblem {
                            Text(problem)
                                .font(.footnote)
                                .foregroundStyle(Theme.statusSoon)
                                .padding(.horizontal, 4)
                        }
                    }
                }

                switch phase {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                case .failed(let message):
                    EmptyPanel(message: TripController.friendly(MessageError(message)))
                case .loaded(let list) where list.isEmpty && trips.pending.isEmpty:
                    EmptyPanel(message: "No trips yet. A trip is recorded automatically when the vehicle starts moving while the Drive tab is connected.")
                case .loaded(let list) where !list.isEmpty:
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Trips")
                        ListPanel(items: list) { row($0, pending: false) }
                    }
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background)
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Throw away the trips waiting to upload?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard trips", role: .destructive) { trips.discardPending() }
        } message: {
            Text("They are deleted from this iPhone and never uploaded.")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            phase = .loaded(try await store.backend.loadTrips(limit: 50))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func row(_ trip: Trip, pending: Bool) -> some View {
        let name = store.vehicles.first { $0.id == trip.vehicleID }?.name ?? "Vehicle"
        return HStack(spacing: 10) {
            IconTile(systemName: pending ? "icloud.and.arrow.up" : "road.lanes", color: pending ? Theme.statusSoon : Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(trip.distanceMiles.oneDecimal) mi · \(trip.duration.durationText)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                Text(detail(trip, vehicleName: name))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func detail(_ trip: Trip, vehicleName: String) -> String {
        var parts = [trip.startedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()), vehicleName]
        if let avg = trip.avgSpeedMph { parts.append("avg \(Int(avg.rounded())) mph") }
        if let top = trip.maxSpeedMph { parts.append("max \(Int(top.rounded()))") }
        return parts.joined(separator: " · ")
    }
}

private struct MessageError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
