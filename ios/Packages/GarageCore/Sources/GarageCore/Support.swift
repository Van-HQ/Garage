import Foundation

let secondsPerDay: TimeInterval = 60 * 60 * 24

/// JavaScript's Math.round: halves round toward positive infinity (-2.5 → -2).
/// Swift's default rounds halves away from zero, which would differ from the
/// web app on negative values such as "days remaining" for overdue items.
func jsRound(_ value: Double) -> Int {
    Int((value + 0.5).rounded(.down))
}

extension Sequence {
    /// A stable sort, like JavaScript's Array.prototype.sort. Swift's `sorted`
    /// does not promise to keep equal elements in their original order.
    func stableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        enumerated()
            .sorted { a, b in
                if areInIncreasingOrder(a.element, b.element) { return true }
                if areInIncreasingOrder(b.element, a.element) { return false }
                return a.offset < b.offset
            }
            .map(\.element)
    }
}
