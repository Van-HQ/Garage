import SwiftUI
import Charts
import GarageCore

/// One card: what was spent (this year or all time), a ring split by maintenance type, and the amounts.
struct CostBreakdownView: View {
    let data: CostBreakdown
    @State private var range: Range = .year

    private enum Range: String, CaseIterable, Identifiable {
        case year = "This year", all = "All time"
        var id: String { rawValue }
    }

    private var total: Double { range == .year ? data.thisYearTotal : data.total }
    private var entries: [CostBreakdown.CategoryAmount] { range == .year ? data.thisYearByCategory : data.byCategory }

    /// Shades of the accent, brightest for the biggest slice, so the chart matches the app but each slice still stands apart.
    private func color(_ index: Int) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(Theme.accent).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return Theme.accent }
        let steps = max(entries.count - 1, 1)
        let t = CGFloat(index) / CGFloat(steps)
        // Light and strong first, then darker and deeper.
        return Color(hue: Double(hue),
                     saturation: Double(min(1, saturation * (1.0 + 0.1 * t))),
                     brightness: Double(brightness * (1.0 - 0.5 * t)))
    }

    var body: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(range == .year ? "Spent this year" : "Spent in total")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                        Text(total.wholeDollars)
                            .font(.system(size: 34, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.foreground)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Picker("Range", selection: $range.animation()) {
                        ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }

                if entries.isEmpty {
                    Text("Nothing logged with a cost in this period.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                } else {
                    ring
                    VStack(spacing: 12) {
                        ForEach(Array(entries.enumerated()), id: \.element.category) { index, entry in
                            HStack(spacing: 10) {
                                Circle().fill(color(index)).frame(width: 10, height: 10)
                                Text(entry.category.label)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.foreground)
                                Spacer()
                                Text(entry.amount.wholeDollars)
                                    .font(.subheadline.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.foreground)
                                Text(percent(entry.amount))
                                    .font(.footnote)
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.muted)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private var ring: some View {
        Chart(Array(entries.enumerated()), id: \.element.category) { index, entry in
            SectorMark(angle: .value("Spent", entry.amount), innerRadius: .ratio(0.64), angularInset: 2)
                .cornerRadius(4)
                .foregroundStyle(color(index))
        }
        .frame(height: 170)
        .chartLegend(.hidden)
        .accessibilityLabel("Spending by type")
    }

    private func percent(_ amount: Double) -> String {
        guard total > 0 else { return "" }
        return "\(Int((amount / total * 100).rounded()))%"
    }
}
