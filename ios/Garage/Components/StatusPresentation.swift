import SwiftUI
import GarageCore

extension DueStatus {
    var color: Color {
        switch self {
        case .overdue: Theme.statusOverdue
        case .dueSoon: Theme.statusSoon
        case .ok: Theme.statusOK
        case .unscheduled: Theme.muted
        }
    }

    var label: String {
        switch self {
        case .overdue: "Overdue"
        case .dueSoon: "Due soon"
        case .ok: "On track"
        case .unscheduled: "Not logged"
        }
    }
}

extension MaintenanceType {
    /// SF Symbol standing in for the web app's lucide icon key.
    var symbolName: String { maintenanceSymbol(for: icon) }
}

func maintenanceSymbol(for iconKey: String?) -> String {
    switch iconKey {
    case "droplet": "drop"
    case "circle-dot": "smallcircle.filled.circle"
    case "sparkles": "sparkles"
    case "wand-2": "wand.and.stars"
    case "clipboard-check": "checklist"
    default: "wrench.adjustable"
    }
}

extension MaintenanceStatusItem {
    /// The one-line summary under the item's name. Same wording as the web app's StatusRow.
    var detailText: String {
        if let miles = milesRemaining, let days = daysRemaining {
            return miles <= 0 || days <= 0
                ? "Overdue by \(max(-miles, 0).grouped) mi"
                : "\(miles.grouped) mi or \(days) days"
        }
        if let miles = milesRemaining {
            return miles <= 0 ? "Overdue by \(abs(miles).grouped) mi" : "\(miles.grouped) mi left"
        }
        if let days = daysRemaining {
            return days <= 0 ? "Overdue by \(abs(days)) days" : "\(days) days left"
        }
        return lastLog != nil ? "Logged, no reminder set" : "No interval set"
    }

    /// The fuller sentence on the detail sheet. Same wording as the web app's CareItemDetailModal.
    var statusLine: String {
        if milesRemaining != nil || daysRemaining != nil {
            let overdueMiles = milesRemaining.map { $0 <= 0 } ?? false
            let overdueDays = daysRemaining.map { $0 <= 0 } ?? false
            if overdueMiles, let miles = milesRemaining { return "Overdue by \(abs(miles).grouped) mi" }
            if overdueDays, let days = daysRemaining { return "Overdue by \(abs(days)) days" }
            var parts: [String] = []
            if let dueMileage { parts.append("\(dueMileage.grouped) mi") }
            if let dueDate { parts.append(dueDate.mediumDay) }
            return parts.isEmpty ? "On track" : "Next due \(parts.joined(separator: " or "))"
        }
        return lastLog != nil ? "Logged, no reminder set" : "No reminder set for this item"
    }
}

struct StatusRow: View {
    let item: MaintenanceStatusItem

    var body: some View {
        HStack(spacing: 10) {
            IconTile(systemName: item.type.symbolName, color: item.status.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.type.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                Text(item.detailText)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(item.status.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(item.status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(item.status.color.opacity(0.14), in: Capsule())
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .contentShape(Rectangle())
    }
}
