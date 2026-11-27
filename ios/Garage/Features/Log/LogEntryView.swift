import SwiftUI
import GarageCore

/// A new entry: the step-by-step flow, or Quick log on one screen. Both end on the same "Logged" screen.
struct LogEntryView: View {
    @Environment(GarageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LogDraft
    @AppStorage("log.prefersQuick") private var prefersQuick = false

    init(prefill: LogPrefill) {
        _draft = State(initialValue: LogDraft(prefill: prefill))
    }

    var body: some View {
        Group {
            if draft.isSaved {
                LoggedView(draft: draft) { dismiss() }
            } else if prefersQuick {
                QuickLogView(draft: draft, isQuick: $prefersQuick, onClose: { dismiss() })
            } else {
                LogFlowView(draft: draft, isQuick: $prefersQuick, onClose: { dismiss() })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { draft.setUp(store: store) }
        .interactiveDismissDisabled(draft.isSaving)
    }
}

/// The confirmation, kept to what matters: it saved, and when this is due next.
struct LoggedView: View {
    @Environment(GarageStore.self) private var store
    let draft: LogDraft
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.background)
                .frame(width: 104, height: 104)
                .background(Theme.statusOK, in: Circle())
                .accessibilityLabel("Saved")
            Text("Logged")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.foreground)
            if let next = nextDue {
                Text(next)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            PrimaryButton(title: "Done", action: onDone)
        }
        .padding(20)
    }

    private var nextDue: String? {
        guard !draft.isMileageOnly, let vehicle = draft.vehicle(in: store),
              let item = store.status(for: vehicle).first(where: { $0.type.id == draft.typeID })
        else { return nil }
        var parts: [String] = []
        if let miles = item.dueMileage { parts.append("\(miles.grouped) mi") }
        if let date = item.dueDate { parts.append(date.mediumDay) }
        return parts.isEmpty ? nil : "Next \(item.type.name): \(parts.joined(separator: " or "))"
    }
}

/// The wide accent button at the bottom of the log screens.
struct PrimaryButton: View {
    let title: String
    var isBusy = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy { ProgressView() } else { Text(title).font(.system(size: 17, weight: .bold)) }
            }
            .foregroundStyle(Theme.accentForeground)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Theme.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isBusy)
        .opacity(isEnabled ? 1 : 0.45)
    }
}
