import SwiftUI
import PhotosUI
import GarageCore

/// The whole entry on one screen, for when you know exactly what you're logging.
struct QuickLogView: View {
    @Environment(GarageStore.self) private var store
    @Bindable var draft: LogDraft
    let onStepByStep: () -> Void
    let onClose: () -> Void

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var showNote = false
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onClose).foregroundStyle(Theme.muted).frame(minHeight: 44)
                Spacer()
                Text("Quick log").font(.headline).foregroundStyle(Theme.foreground)
                Spacer()
                VehicleMenu(draft: draft)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 6) {
                        Text("Odometer").font(.footnote.weight(.medium)).foregroundStyle(Theme.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("Miles", text: $draft.mileage)
                                .keyboardType(.numberPad)
                                .focused($typing)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 58, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.foreground)
                                .fixedSize()
                            Text("mi").foregroundStyle(Theme.muted)
                        }
                        Text("Tap to change").font(.footnote).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Service")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                            ForEach(draft.types(in: store)) { type in
                                ChoiceChip(title: type.name, selected: !draft.isMileageOnly && draft.typeID == type.id, fills: true) {
                                    draft.isMileageOnly = false
                                    draft.typeID = type.id
                                }
                            }
                            ChoiceChip(title: "Mileage only", selected: draft.isMileageOnly, fills: true) { draft.isMileageOnly = true }
                        }
                    }

                    HStack(spacing: 12) {
                        if !draft.isMileageOnly {
                            box("Cost") {
                                HStack(spacing: 4) {
                                    Text("$").foregroundStyle(Theme.muted)
                                    TextField("0", text: $draft.cost).keyboardType(.decimalPad).focused($typing)
                                }
                                .font(.system(size: 20, weight: .semibold))
                            }
                        }
                        box("Date") {
                            DatePicker("Date", selection: $draft.date, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                        }
                    }

                    if showNote || !draft.notes.isEmpty {
                        TextField("Add a note", text: $draft.notes, axis: .vertical)
                            .lineLimit(1...4)
                            .focused($typing)
                            .padding(16)
                            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        ChoiceChip(title: "Add note", selected: false, fills: true) { showNote = true }
                    }
                    if !draft.isMileageOnly { PhotoRow(draft: draft, pickedItems: $pickedItems) }

                    Button("Step by step instead", action: onStepByStep)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: 44)

                    if let error = draft.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(Theme.statusOverdue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(title: "Save entry", isBusy: draft.isSaving, isEnabled: draft.canSave(in: store)) {
                typing = false
                draft.save(store: store)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            pickedItems = []
            draft.addPhotos(items)
        }
    }

    private func box<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote).foregroundStyle(Theme.muted)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
