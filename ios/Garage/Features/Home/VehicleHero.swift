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

        VStack(alignment: .leading, spacing: 6) {
            Group {
                Text(vehicle.headline)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.muted)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(projectedMileage(vehicle).grouped)
                        .font(.system(size: 60, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.foreground)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("mi")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }

                HStack(spacing: 16) {
                    if overdue > 0 { badge("\(overdue) overdue", Theme.statusOverdue) }
                    if soon > 0 { badge("\(soon) due soon", Theme.statusSoon) }
                    if overdue == 0 && soon == 0 { badge("All caught up", Theme.statusOK) }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)

            if trend.count >= 2 {
                HeroChart(points: trend) { title in
                    maintenanceSymbol(for: store.snapshot.types.first { $0.name == title }?.icon)
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
        }
    }
}
