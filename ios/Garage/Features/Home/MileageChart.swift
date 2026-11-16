import SwiftUI
import Charts
import GarageCore

/// The mileage chart with its Care / Monthly switch. Drag across it to read a point:
/// Care shows each odometer reading (services marked), Monthly shows miles driven per month.
struct MileageChart: View {
    enum Mode: String, CaseIterable, Identifiable {
        case care = "Care"
        case monthly = "Monthly"
        var id: String { rawValue }
    }

    let points: [TrendPoint]
    var height: CGFloat = 150

    @State private var mode: Mode = .care
    @State private var selectedDate: Date?
    @State private var selectedMonth: String?

    private var months: [MonthlyMiles] { computeMonthlyMiles(points) }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(caption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.numericText())
                Spacer()
                Picker("Chart", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            Group {
                switch mode {
                case .care: careChart
                case .monthly: monthlyChart
                }
            }
            .frame(height: height)
        }
    }

    /// What the line above the chart says: the scrubbed point when dragging, a summary otherwise.
    private var caption: String {
        switch mode {
        case .care:
            if let point = selectedPoint {
                let what = point.kind == .maintenance ? (point.label ?? "Service") : "Odometer check-in"
                return "\(point.date.shortDay) · \(point.mileage.grouped) mi · \(what)"
            }
            let services = points.filter { $0.kind == .maintenance }.count
            return "\(services) service\(services == 1 ? "" : "s") · drag to inspect"
        case .monthly:
            if let month = months.first(where: { $0.shortLabel == selectedMonth }) {
                return "\(month.fullLabel) · \(month.miles.grouped) mi driven"
            }
            return months.isEmpty ? "" : "Miles driven per month"
        }
    }

    private var selectedPoint: TrendPoint? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private var careChart: some View {
        let mileages = points.map(\.mileage)
        let low = mileages.min() ?? 0
        let high = max(mileages.max() ?? 1, low + 1)

        return Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Floor", low),
                    yEnd: .value("Miles", point.mileage)
                )
                .foregroundStyle(LinearGradient(
                    colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                ))
            }
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Date", point.date), y: .value("Miles", point.mileage))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                PointMark(x: .value("Date", point.date), y: .value("Miles", point.mileage))
                    .foregroundStyle(point.kind == .maintenance ? Theme.statusSoon : Theme.accent)
                    .symbolSize(point.kind == .maintenance ? 46 : 18)
            }
            if let point = selectedPoint {
                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(Theme.muted.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                PointMark(x: .value("Date", point.date), y: .value("Miles", point.mileage))
                    .foregroundStyle(point.kind == .maintenance ? Theme.statusSoon : Theme.accent)
                    .symbolSize(110)
            }
        }
        .chartYScale(domain: low...high)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: false)
                    .foregroundStyle(Theme.muted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let miles = value.as(Int.self) {
                        Text(miles.formatted(.number.notation(.compactName)))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var monthlyChart: some View {
        if months.count < 2 {
            Text("Not enough months of data yet")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(months, id: \.self) { month in
                    AreaMark(x: .value("Month", month.shortLabel), y: .value("Miles", month.miles))
                        .foregroundStyle(LinearGradient(
                            colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        ))
                    LineMark(x: .value("Month", month.shortLabel), y: .value("Miles", month.miles))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("Month", month.shortLabel), y: .value("Miles", month.miles))
                        .foregroundStyle(Theme.accent)
                        .symbolSize(month.shortLabel == selectedMonth ? 110 : 24)
                }
                if let selectedMonth {
                    RuleMark(x: .value("Selected", selectedMonth))
                        .foregroundStyle(Theme.muted.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
            }
            .chartXSelection(value: $selectedMonth)
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.muted) }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel {
                        if let miles = value.as(Int.self) {
                            Text(miles.formatted(.number.notation(.compactName)))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
    }
}
