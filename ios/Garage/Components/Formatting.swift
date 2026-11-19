import Foundation
import GarageCore

extension Int {
    /// "11,400"
    var grouped: String { formatted(.number.grouping(.automatic)) }

    /// "+1,270", "−140", "0". Uses a real minus sign, like the web app.
    var signedGrouped: String {
        let prefix = self > 0 ? "+" : self < 0 ? "−" : ""
        return prefix + abs(self).grouped
    }
}

extension Double {
    /// "$82", rounded to whole dollars like the web app's cost displays.
    var wholeDollars: String {
        "$" + formatted(.number.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero))
    }
}

extension Date {
    /// "Aug 20"
    var shortDay: String { formatted(.dateTime.month(.abbreviated).day()) }

    /// "Aug 20, 2026"
    var mediumDay: String { formatted(.dateTime.month(.abbreviated).day().year()) }
}

extension MonthlyMiles {
    private var firstDay: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    /// "Aug"
    var shortLabel: String { firstDay.formatted(.dateTime.month(.abbreviated)) }

    /// "August 2026"
    var fullLabel: String { firstDay.formatted(.dateTime.month(.wide).year()) }
}

extension Vehicle {
    /// "Buddy · 2024 TRD Sport"
    var headline: String {
        let detail = [String(year), model].filter { !$0.isEmpty }.joined(separator: " ")
        return detail.isEmpty ? name : "\(name) · \(detail)"
    }
}

extension TimeInterval {
    /// "23 min", "1 h 12 min", "45 s"
    var durationText: String {
        let total = Int(self.rounded())
        if total < 60 { return "\(total) s" }
        let minutes = (total + 30) / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}

extension Double {
    /// "12.3"
    var oneDecimal: String { formatted(.number.precision(.fractionLength(1))) }
}
