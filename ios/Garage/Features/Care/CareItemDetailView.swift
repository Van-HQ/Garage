import SwiftUI
import GarageCore

/// Everything about one maintenance item: where it stands, your real interval
/// against the target, what it has cost, and its history.
struct CareItemDetailView: View {
    @Environment(GarageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: MaintenanceStatusItem
    let vehicle: Vehicle
    /// Called with a prefilled log form after this sheet closes.
    let onLog: (LogPrefill) -> Void

    @State private var openedLog: MaintenanceLog?

    var body: some View {
        let type = item.type
        let history = historyForType(logs: store.snapshot.logs, vehicle: vehicle, type: type)
        let average = computeIntervalAverage(history: history, type: type)
        let cost = totalCost(history)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 6) {
                        Circle().fill(item.status.color).frame(width: 6, height: 6)
                        Text(item.statusLine)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(item.status.color)
                    }

                    HStack(spacing: 10) {
                        tile("Target", type.intervalMiles.map { "\($0.grouped) mi" } ?? (type.intervalDays == nil ? "Not set" : "—"),
                             note: type.intervalDays.map { "or \($0) days" })
                        tile("Your average", average.avgMiles.map { "\($0.grouped) mi" } ?? "—",
                             note: average.percentAheadMiles.map { $0 >= 0 ? "\($0)% ahead" : "\(abs($0))% behind" },
                             noteColor: (average.percentAheadMiles ?? 0) >= 0 ? Theme.statusOK : Theme.statusSoon)
                        tile("Spent", cost > 0 ? cost.wholeDollars : "—",
                             note: "\(history.count) service\(history.count == 1 ? "" : "s")")
                    }

                    if history.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader("Starting point")
                            Panel(padding: 0) {
                                VStack(spacing: 0) {
                                    baselineRow("Baseline mileage", "\((type.baselineMileage ?? 0).grouped) mi")
                                    Divider().overlay(Theme.hairline)
                                    baselineRow("Baseline date", (type.baselineDate ?? vehicle.createdAt).mediumDay)
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader("History")
                            ListPanel(items: history) { log in
                                Button { openedLog = log } label: { LogRow(log: log) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        dismiss()
                        onLog(LogPrefill(vehicleID: vehicle.id, typeID: type.id))
                    } label: {
                        Text("Log this service")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Theme.accentForeground)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(type.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $openedLog) { LogDetailView(log: $0) }
        }
        .presentationDetents([.medium, .large])
    }

    private func tile(_ label: String, _ value: String, note: String?, noteColor: Color = Theme.muted) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.4)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(note ?? " ")
                .font(.system(size: 11))
                .foregroundStyle(noteColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
    }

    private func baselineRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.foreground)
            Spacer()
            Text(value).foregroundStyle(Theme.muted).monospacedDigit()
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
