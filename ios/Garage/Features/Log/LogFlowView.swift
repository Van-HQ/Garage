import SwiftUI
import PhotosUI
import GarageCore

/// The step-by-step entry: what you did, the odometer and date, then cost and photos.
struct LogFlowView: View {
    @Environment(GarageStore.self) private var store
    @Bindable var draft: LogDraft
    let onQuickLog: () -> Void
    let onClose: () -> Void

    @State private var step = 1
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var dragStart: Int?
    @State private var didSkipFirstStep = false
    @FocusState private var typing: Bool

    private var lastStep: Int { draft.isMileageOnly ? 2 : 3 }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                Group {
                    switch step {
                    case 1: whatStep
                    case 2: whenStep
                    default: detailStep
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            pickedItems = []
            draft.addPhotos(items)
        }
        .onAppear {
            // Opened from a maintenance item, so "what" is already answered.
            if draft.prefill.typeID != nil, !didSkipFirstStep {
                didSkipFirstStep = true
                step = 2
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { step > 1 ? (step -= 1) : onClose() } label: {
                    Image(systemName: step > 1 ? "chevron.left" : "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                        .frame(width: 44, height: 44)
                        .background(Theme.elevated, in: Circle())
                }
                .accessibilityLabel(step > 1 ? "Back" : "Close")
                HStack(spacing: 6) {
                    ForEach(1...lastStep, id: \.self) { index in
                        Capsule().fill(index <= step ? Theme.accent : Theme.hairline).frame(height: 4)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Step \(step) of \(lastStep)")
                VehicleMenu(draft: draft)
            }
            if step == 1 {
                HStack {
                    Spacer()
                    Button("Quick log", action: onQuickLog)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 32)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: Step 1

    private var whatStep: some View {
        let status = draft.vehicle(in: store).map { store.status(for: $0) } ?? []
        return VStack(alignment: .leading, spacing: 28) {
            Text("What did\nyou do?")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.foreground)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: 3), spacing: 24) {
                ForEach(draft.types(in: store)) { type in
                    let item = status.first { $0.type.id == type.id }
                    circleButton(title: type.name, symbol: maintenanceSymbol(for: type.icon),
                                 selected: !draft.isMileageOnly && draft.typeID == type.id,
                                 ring: item.map(ring)) {
                        draft.isMileageOnly = false
                        draft.typeID = type.id
                    }
                }
                circleButton(title: "Mileage only", symbol: "gauge.with.dots.needle.67percent",
                             selected: draft.isMileageOnly, ring: nil) {
                    draft.isMileageOnly = true
                }
            }
        }
    }

    /// How much of the service interval is left, and the color for how urgent it is.
    private func ring(_ item: MaintenanceStatusItem) -> (fraction: Double, color: Color) {
        var fractions: [Double] = []
        if let left = item.milesRemaining, let every = item.type.intervalMiles, every > 0 { fractions.append(Double(left) / Double(every)) }
        if let left = item.daysRemaining, let every = item.type.intervalDays, every > 0 { fractions.append(Double(left) / Double(every)) }
        let color = item.status == .overdue ? Theme.statusOverdue : item.status == .dueSoon ? Theme.statusSoon : Theme.statusOK
        return (min(1, max(0.04, fractions.min() ?? 1)), color)
    }

    private func circleButton(title: String, symbol: String, selected: Bool, ring: (fraction: Double, color: Color)?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(selected ? Theme.hairline : Theme.elevated)
                    Circle().strokeBorder(Theme.hairline, lineWidth: 5)
                    if let ring {
                        Circle()
                            .inset(by: 2.5)
                            .trim(from: 0, to: ring.fraction)
                            .stroke(ring.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    Image(systemName: symbol)
                        .font(.system(size: 28))
                        .foregroundStyle(selected ? Theme.accent : Theme.foreground)
                }
                .frame(width: 88, height: 88)
                .overlay { if selected { Circle().inset(by: -4).stroke(Theme.accent, lineWidth: 2) } }
                Text(title)
                    .font(.system(size: 13, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? Theme.foreground : Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Step 2

    private var whenStep: some View {
        VStack(spacing: 28) {
            Text(draft.title(in: store))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.foreground)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(Theme.elevated, in: Capsule())

            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("Miles", text: $draft.mileage)
                        .keyboardType(.numberPad)
                        .focused($typing)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 62, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.foreground)
                        .fixedSize()
                    Text("mi").font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.muted)
                }
                ruler
                Text("Drag the ruler, or tap the number to type it")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }

            DayStrip(date: $draft.date)
        }
    }

    /// Dragging left or right nudges the odometer, one mile for every few points.
    private var ruler: some View {
        HStack(spacing: 8) {
            ForEach(0..<31, id: \.self) { index in
                Capsule()
                    .fill(index == 15 ? Theme.accent : Theme.muted.opacity(index % 5 == 0 ? 0.7 : 0.35))
                    .frame(width: index == 15 ? 3.5 : 2, height: index == 15 ? 44 : index % 5 == 0 ? 28 : 14)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    typing = false
                    let start = dragStart ?? draft.mileageValue ?? draft.vehicle(in: store).map { projectedMileage($0) } ?? 0
                    dragStart = start
                    draft.mileage = String(max(0, start - Int(value.translation.width / 4)))
                }
                .onEnded { _ in dragStart = nil }
        )
        .accessibilityLabel("Adjust the odometer")
        .accessibilityAdjustableAction { direction in
            let now = draft.mileageValue ?? 0
            draft.mileage = String(max(0, now + (direction == .increment ? 1 : -1)))
        }
    }

    // MARK: Step 3

    private var detailStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Panel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.title(in: store)).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.foreground)
                    Text("\((draft.mileageValue ?? 0).grouped) mi · \(draft.date.mediumDay)")
                        .font(.subheadline).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$").font(.system(size: 30, weight: .semibold)).foregroundStyle(Theme.muted)
                    TextField("0", text: $draft.cost)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 60, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.foreground)
                }
                HStack(spacing: 8) {
                    ForEach(["20", "40", "60", "100"], id: \.self) { amount in
                        ChoiceChip(title: "$\(amount)", selected: draft.cost == amount) { draft.cost = amount }
                    }
                }
            }
            PhotoRow(draft: draft, pickedItems: $pickedItems)
            TextField("Add a note", text: $draft.notes, axis: .vertical)
                .lineLimit(1...4)
                .padding(18)
                .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if let error = draft.errorMessage {
                Text(error).font(.footnote).foregroundStyle(Theme.statusOverdue)
            }
        }
    }

    // MARK: Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if step == lastStep {
            VStack(spacing: 8) {
                if step == 2, let error = draft.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Theme.statusOverdue)
                }
                PrimaryButton(title: "Save entry", isBusy: draft.isSaving, isEnabled: draft.canSave(in: store)) {
                    typing = false
                    draft.save(store: store)
                }
            }
        } else {
            let ready = step == 1 ? (draft.isMileageOnly || draft.typeID != nil || draft.types(in: store).isEmpty) : draft.canContinue
            Button {
                typing = false
                step += 1
            } label: {
                HStack {
                    Text(step == 1 ? draft.title(in: store) : "\(draft.mileageValue.map(\.grouped) ?? "—") mi")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.accentForeground)
                        .frame(width: 52, height: 52)
                        .background(Theme.accent, in: Circle())
                }
                .padding(.leading, 22)
                .padding(.trailing, 8)
                .frame(height: 68)
                .background(Theme.elevated, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
            }
            .buttonStyle(.plain)
            .disabled(!ready)
            .opacity(ready ? 1 : 0.5)
            .accessibilityLabel("Next")
        }
    }
}
