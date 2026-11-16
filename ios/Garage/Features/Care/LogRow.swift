import SwiftUI
import GarageCore

/// One logged service in a list: title, then date · mileage · cost.
struct LogRow: View {
    @Environment(GarageStore.self) private var store
    let log: MaintenanceLog
    var showYear = true

    var body: some View {
        HStack(spacing: 10) {
            IconTile(systemName: maintenanceSymbol(for: store.type(for: log)?.icon), color: Theme.statusOK)
            VStack(alignment: .leading, spacing: 1) {
                Text(log.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !store.photos(for: log).isEmpty {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .contentShape(Rectangle())
    }

    private var summary: String {
        var parts = [showYear ? log.performedAt.mediumDay : log.performedAt.shortDay, "\(log.mileageAt.grouped) mi"]
        if let cost = log.cost, cost > 0 { parts.append(cost.wholeDollars) }
        return parts.joined(separator: " · ")
    }
}
