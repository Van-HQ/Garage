import SwiftUI
import GarageCore

/// One page of the Home pager: name, the big projected odometer, status badges and the mileage chart.
struct VehicleHero: View {
    @Environment(GarageStore.self) private var store
    let vehicle: Vehicle

    var body: some View {
        let status = store.status(for: vehicle)
        let overdue = status.filter { $0.status == .overdue }.count
        let soon = status.filter { $0.status == .dueSoon }.count
        let trend = store.trend(for: vehicle)

        VStack(spacing: 4) {
            Text(vehicle.headline)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)

            Text(projectedMileage(vehicle).grouped)
                .font(.system(size: 46, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.foreground)
                .padding(.top, 6)
            Text("MILES")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(Theme.muted)

            HStack(spacing: 8) {
                if overdue > 0 { badge("\(overdue) overdue", Theme.statusOverdue) }
                if soon > 0 { badge("\(soon) due soon", Theme.statusSoon) }
                if overdue == 0 && soon == 0 { badge("All caught up", Theme.statusOK) }
            }
            .padding(.top, 12)

            if trend.count >= 2 {
                MileageChart(points: trend)
                    .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
    }
}
