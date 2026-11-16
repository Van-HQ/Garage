import SwiftUI
import GarageCore

/// Total spent, this year's total, and a bar per category. Port of the web app's CostBreakdown.
struct CostBreakdownView: View {
    let data: CostBreakdown

    var body: some View {
        let largest = max(data.byCategory.map(\.amount).max() ?? 1, 1)
        VStack(spacing: 12) {
            Panel(padding: 18) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        caption("Total spent")
                        Text(data.total.wholeDollars)
                            .font(.system(size: 30, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.foreground)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        caption("This year")
                        Text(data.thisYearTotal.wholeDollars)
                            .font(.system(size: 18, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.foreground)
                    }
                }
            }

            if !data.byCategory.isEmpty {
                Panel(padding: 18) {
                    VStack(spacing: 14) {
                        ForEach(data.byCategory, id: \.category) { entry in
                            VStack(spacing: 6) {
                                HStack {
                                    Text(entry.category.label)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Theme.foreground)
                                    Spacer()
                                    Text(entry.amount.wholeDollars)
                                        .font(.subheadline)
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.muted)
                                }
                                GeometryReader { proxy in
                                    Capsule().fill(Theme.muted.opacity(0.22))
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(Theme.accent)
                                                .frame(width: proxy.size.width * max(entry.amount / largest, 0.04))
                                        }
                                }
                                .frame(height: 10)
                            }
                        }
                    }
                }
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .kerning(0.4)
            .foregroundStyle(Theme.muted)
    }
}
