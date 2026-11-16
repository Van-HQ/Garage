import SwiftUI
import GarageCore

/// Miles since tracking started, plus month-over-month change. Port of the web app's StatsCard.
struct StatsCard: View {
    let vehicle: Vehicle
    let points: [TrendPoint]

    var body: some View {
        if let first = points.first, let last = points.last, points.count >= 2 {
            let months = computeMonthlyStats(points)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Stats · \(vehicle.name)")
                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Since you started tracking")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                                Text("\((last.mileage - first.mileage).grouped) mi")
                                    .font(.system(size: 28, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.foreground)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(first.date.shortDay) → \(last.date.shortDay)")
                                Text("\(first.mileage.grouped) → \(last.mileage.grouped)")
                            }
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Theme.muted)
                        }

                        if !months.isEmpty {
                            monthTable(months)
                        }
                    }
                }
            }
        }
    }

    private func monthTable(_ months: [MonthlyStat]) -> some View {
        let average = jsStyleAverage(months.map(\.month.miles))
        return VStack(spacing: 0) {
            HStack {
                Text("MONTH").frame(width: 52, alignment: .leading)
                Text("MILES").frame(maxWidth: .infinity, alignment: .trailing)
                Text("VS. PRIOR").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.4)
            .foregroundStyle(Theme.muted)
            .padding(.bottom, 6)

            ForEach(months, id: \.self) { stat in
                Divider().overlay(Theme.hairline)
                HStack(alignment: .firstTextBaseline) {
                    Text(stat.month.shortLabel)
                        .foregroundStyle(Theme.muted)
                        .frame(width: 52, alignment: .leading)
                    Text(stat.month.miles.grouped)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.foreground)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    changeText(stat)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.subheadline)
                .monospacedDigit()
                .padding(.vertical, 7)
            }

            Divider().overlay(Theme.hairline)
            Text("Average \(average.grouped) mi/mo")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
    }

    private func changeText(_ stat: MonthlyStat) -> Text {
        guard let change = stat.changeMiles else { return Text("—").foregroundStyle(Theme.muted) }
        let color = change == 0 ? Theme.muted : change > 0 ? Theme.statusOK : Theme.statusOverdue
        let percent: String
        if let pct = stat.changePercent {
            let arrow = pct > 0 ? "▲ " : pct < 0 ? "▼ " : ""
            percent = "\(arrow)\(pct.signedGrouped)%"
        } else {
            percent = "—"
        }
        return Text(percent).foregroundStyle(color)
            + Text(" (\(change.signedGrouped))").font(.caption).foregroundStyle(Theme.muted)
    }

    /// Mean rounded the way the web app's Math.round does (the values are never negative here).
    private func jsStyleAverage(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count) + 0.5).rounded(.down))
    }
}
