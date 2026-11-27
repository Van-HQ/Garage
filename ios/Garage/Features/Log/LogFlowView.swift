import SwiftUI
import PhotosUI
import GarageCore

/// The step-by-step entry: what you did, the odometer and date, then cost and photos.
struct LogFlowView: View {
    @Environment(GarageStore.self) private var store
    @Bindable var draft: LogDraft
    @Binding var isQuick: Bool
    let onClose: () -> Void

    @State private var step = 1
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var dragStart: Int?
    /// The exact position while dragging, so the ticks glide instead of jumping a mile at a time.
    @State private var dragValue: Double?
    private static let pointsPerMile = 5.0
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
            if step == 1 { LogModeSwitch(isQuick: $isQuick) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: Step 1

    private var whatStep: some View {
        let status = draft.vehicle(in: store).map { store.status(for: $0) } ?? []
        return VStack(alignment: .leading, spacing: 28) {
            Text("What did you do?")
                .font(.system(size: 32, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
                circleButton(title: "Mileage", symbol: "gauge.with.dots.needle.67percent",
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

    /// The ticks slide under a fixed needle as you drag, one tick for every two miles.
    private var ruler: some View {
        let miles = dragValue ?? Double(draft.mileageValue ?? 0)
        return Canvas { context, size in
            let center = size.width / 2
            let reach = Int(center / Self.pointsPerMile) + 2
            let base = Int(miles.rounded(.down))
            for mile in (base - reach)...(base + reach) where mile >= 0 && mile % 2 == 0 {
                let x = center + (Double(mile) - miles) * Self.pointsPerMile
                let major = mile % 10 == 0
                let height: CGFloat = major ? 28 : 14
                let tick = CGRect(x: x - 1, y: (size.height - height) / 2, width: 2, height: height)
                context.fill(Path(roundedRect: tick, cornerRadius: 1), with: .color(Theme.muted.opacity(major ? 0.75 : 0.4)))
            }
        }
        .mask(LinearGradient(stops: [
            .init(color: .clear, location: 0), .init(color: .black, location: 0.22),
            .init(color: .black, location: 0.78), .init(color: .clear, location: 1),
        ], startPoint: .leading, endPoint: .trailing))
        .overlay { Capsule().fill(Theme.accent).frame(width: 3.5, height: 44) }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .contentShape(Rectangle())
        // High priority, so the scrolling page can't take the drag away.
        .highPriorityGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    typing = false
                    let start = dragStart ?? draft.mileageValue ?? draft.vehicle(in: store).map { projectedMileage($0) } ?? 0
                    dragStart = start
                    let now = max(0, Double(start) - Double(value.translation.width) / Self.pointsPerMile)
                    dragValue = now
                    draft.mileage = String(Int(now.rounded()))
                }
                .onEnded { _ in
                    dragStart = nil
                    dragValue = nil
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Adjust the odometer")
        .accessibilityValue("\(draft.mileageValue ?? 0) miles")
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
