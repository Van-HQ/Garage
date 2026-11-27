import SwiftUI
import Charts
import GarageCore

/// The Home hero chart: odometer over time, services marked on the line. Drag across it to read a point.
struct HeroChart: View {
    let points: [TrendPoint]
    /// The symbol for a service, looked up from its title.
    let symbol: (String?) -> String

    @State private var selectedDate: Date?

    /// Only services far enough apart get an icon, so they never pile on top of each other.
    private var markers: [TrendPoint] { spacedServiceMarkers(points) }

    private var selected: TrendPoint? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        let low = points.map(\.mileage).min() ?? 0
        let high = max(points.map(\.mileage).max() ?? 1, low + 1)
        let room = Double(high - low) * 0.22

        VStack(spacing: 6) {
            Text(caption)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(selected == nil ? Theme.muted : Theme.foreground)
                .lineLimit(1)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    AreaMark(x: .value("Date", point.date), yStart: .value("Floor", Double(low) - room), yEnd: .value("Miles", Double(point.mileage)))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.34), Theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                }
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Date", point.date), y: .value("Miles", Double(point.mileage)))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                ForEach(Array(markers.enumerated()), id: \.offset) { _, point in
                    PointMark(x: .value("Date", point.date), y: .value("Miles", Double(point.mileage)))
                        .symbol {
                            Image(systemName: symbol(point.label))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.foreground)
                                .frame(width: 22, height: 22)
                                .background(Theme.elevated, in: Circle())
                                .overlay(Circle().strokeBorder(Theme.hairline))
                        }
                }
                if let selected {
                    RuleMark(x: .value("Selected", selected.date))
                        .foregroundStyle(Theme.foreground.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    PointMark(x: .value("Date", selected.date), y: .value("Miles", Double(selected.mileage)))
                        .symbol {
                            Circle().fill(Theme.background).frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 3))
                        }
                }
            }
            .chartYScale(domain: (Double(low) - room)...(Double(high) + room))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(range: .plotDimension(startPadding: 0, endPadding: 16))
            .chartXSelection(value: $selectedDate)
            .frame(height: 170)
            .accessibilityLabel("Mileage over time with services marked")
        }
    }

    private var caption: String {
        guard let selected else { return "Drag across the chart to look back" }
        let what = selected.kind == .maintenance ? (selected.label ?? "Service") : "Odometer check-in"
        return "\(selected.date.shortDay) · \(selected.mileage.grouped) mi · \(what)"
    }
}
