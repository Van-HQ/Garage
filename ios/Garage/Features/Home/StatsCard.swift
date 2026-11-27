import SwiftUI
import Charts
import GarageCore

/// Miles driven each month as bars, the average, and how the latest month compares. Port of the web app's StatsCard.
struct StatsCard: View {
    let vehicle: Vehicle
    let points: [TrendPoint]
    /// The bar the user tapped. Nil shows the latest month.
    @State private var selectedLabel: String?

    var body: some View {
        if let first = points.first, let last = points.last, points.count >= 2 {
            let months = computeMonthlyStats(points)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Stats · \(vehicle.name)")
                Panel(padding: 20) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\((last.mileage - first.mileage).grouped) mi")
                                    .font(.system(size: 30, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.foreground)
                                Text("since you started tracking")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if !months.isEmpty {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(average(months).grouped)")
                                        .font(.system(size: 22, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.foreground)
                                    Text("mi / month")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                        }

                        if !months.isEmpty {
                            chart(months)
                            if let active = months.first(where: { $0.month.shortLabel == selectedLabel }) ?? months.first {
                                monthLine(active)
                            }
                        }
                    }
                }
            }
        }
    }

    private func chart(_ months: [MonthlyStat]) -> some View {
        let ordered = Array(months.reversed())
        let latestLabel = selectedLabel ?? months.first?.month.shortLabel
        return Chart(ordered, id: \.self) { stat in
            BarMark(x: .value("Month", stat.month.shortLabel), y: .value("Miles", stat.month.miles))
                .cornerRadius(6)
                .foregroundStyle(stat.month.shortLabel == latestLabel ? Theme.accent : Theme.muted.opacity(0.35))
                .annotation(position: .top, spacing: 4) {
                    Text(stat.month.miles.grouped)
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(stat.month.shortLabel == latestLabel ? Theme.foreground : Theme.muted)
                }
        }
        // A plain tap on a column picks that month and keeps it picked.
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plot = proxy.plotFrame else { return }
                        if let label: String = proxy.value(atX: location.x - geometry[plot].origin.x) {
                            selectedLabel = label
                        }
                    }
            }
        }
        .animation(.snappy, value: selectedLabel)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.system(size: 11)).foregroundStyle(Theme.muted) }
        }
        .frame(height: 150)
    }

    /// The month tapped in the chart (or the latest one): its miles and how it compares with the month before.
    private func monthLine(_ stat: MonthlyStat) -> some View {
        HStack(spacing: 6) {
            Text("\(stat.month.shortLabel) · \(stat.month.miles.grouped) mi")
                .fontWeight(.semibold)
                .foregroundStyle(Theme.foreground)
            Spacer()
            if let change = stat.changeMiles {
                let color = change == 0 ? Theme.muted : change > 0 ? Theme.statusOK : Theme.statusOverdue
                let arrow = change > 0 ? "▲" : change < 0 ? "▼" : ""
                Text("\(arrow) \(stat.changePercent.map { "\($0.signedGrouped)%" } ?? "—")")
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                Text("vs. last month (\(change.signedGrouped) mi)").foregroundStyle(Theme.muted)
            } else {
                Text("—").foregroundStyle(Theme.muted)
            }
        }
        .font(.footnote)
        .monospacedDigit()
    }

    /// Mean rounded the way the web app's Math.round does (the values are never negative here).
    private func average(_ months: [MonthlyStat]) -> Int {
        let values = months.map(\.month.miles)
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count) + 0.5).rounded(.down))
    }
}
