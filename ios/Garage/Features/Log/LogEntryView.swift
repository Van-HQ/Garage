import SwiftUI
import PhotosUI
import GarageCore

/// What the log form starts with. Opening it from a maintenance item fills in the vehicle and type.
struct LogPrefill: Identifiable {
    let id = UUID()
    var vehicleID: UUID?
    var typeID: UUID?
}

/// Log a service (with optional photos) or a plain odometer reading.
/// Port of the web app's /log page.
struct LogEntryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case maintenance = "Maintenance"
        case mileage = "Mileage only"
        var id: String { rawValue }
    }

    @Environment(GarageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let prefill: LogPrefill

    @State private var mode: Mode = .maintenance
    @State private var vehicleID: UUID?
    @State private var typeID: UUID?
    @State private var mileage = ""
    @State private var date = Date()
    @State private var cost = ""
    @State private var notes = ""
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var photos: [PickedPhoto] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSetUp = false

    private struct PickedPhoto: Identifiable {
        let id = UUID()
        let jpeg: Data
        let thumbnail: UIImage
    }

    private var vehicle: Vehicle? { store.vehicles.first { $0.id == vehicleID } }
    private var vehicleTypes: [MaintenanceType] { vehicle.map(store.types(for:)) ?? [] }
    private var mileageValue: Int? { Int(mileage.filter(\.isNumber)) }
    private var costValue: Double? { Double(cost.replacingOccurrences(of: ",", with: ".")) }

    private var canSave: Bool {
        guard vehicle != nil, mileageValue != nil, !isSaving else { return false }
        // A typed cost has to be a number; an empty one is fine.
        return cost.trimmingCharacters(in: .whitespaces).isEmpty || costValue != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.vehicles.count > 1 {
                        Picker("Vehicle", selection: $vehicleID) {
                            ForEach(store.vehicles) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                    Picker("Entry", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                }

                Section {
                    if mode == .maintenance {
                        if vehicleTypes.isEmpty {
                            Text("No maintenance types yet. Add some in the web app's Settings.")
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                        } else {
                            Picker("Type", selection: $typeID) {
                                ForEach(vehicleTypes) { Text($0.name).tag(Optional($0.id)) }
                            }
                        }
                    }
                    LabeledContent("Odometer") {
                        TextField(prefill.typeID != nil ? "Miles when it was done" : "Miles", text: $mileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    if mode == .maintenance {
                        LabeledContent("Cost") {
                            TextField("Optional", text: $cost)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Notes") {
                    TextField(mode == .maintenance ? "Synthetic 0W-20, rotated tires too…" : "Optional", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if mode == .maintenance {
                    Section("Photos") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(photos) { photo in
                                    Image(uiImage: photo.thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                photos.removeAll { $0.id == photo.id }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .symbolRenderingMode(.palette)
                                                    .foregroundStyle(.white, .black.opacity(0.7))
                                            }
                                            .buttonStyle(.plain)
                                            .offset(x: 6, y: -6)
                                            .accessibilityLabel("Remove photo")
                                        }
                                }
                                PhotosPicker(selection: $pickedItems, maxSelectionCount: 8, matching: .images) {
                                    Image(systemName: "camera")
                                        .font(.title3)
                                        .foregroundStyle(Theme.muted)
                                        .frame(width: 64, height: 64)
                                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .accessibilityLabel("Add photos")
                            }
                            .padding(.vertical, 6)
                            .padding(.trailing, 6)
                        }
                        .scrollIndicators(.hidden)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.statusOverdue)
                    }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save).disabled(!canSave)
                    }
                }
            }
            .onAppear(perform: setUp)
            .onChange(of: vehicleID) { _, _ in vehicleChanged() }
            .onChange(of: pickedItems) { _, items in loadPhotos(items) }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func setUp() {
        guard !didSetUp else { return }
        didSetUp = true
        vehicleID = store.vehicles.first { $0.id == prefill.vehicleID }?.id ?? store.vehicles.first?.id
        vehicleChanged()
    }

    private func vehicleChanged() {
        guard let vehicle else { return }
        if !vehicleTypes.contains(where: { $0.id == typeID }) {
            typeID = vehicleTypes.first { $0.id == prefill.typeID }?.id ?? vehicleTypes.first?.id
        }
        // Backlogging a specific item should ask for the mileage it was done at,
        // not default to today's estimate. Same rule as the web form.
        if prefill.typeID == nil {
            mileage = String(projectedMileage(vehicle))
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        pickedItems = []
        Task {
            for item in items {
                guard
                    let data = try? await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data),
                    let prepared = image.preparedForUpload()
                else { continue }
                photos.append(PickedPhoto(jpeg: prepared.jpeg, thumbnail: prepared.thumbnail))
            }
        }
    }

    private func save() {
        guard let vehicle, let mileageValue else { return }
        isSaving = true
        errorMessage = nil
        // Noon on the chosen day, like the web form, so the date can't slip across midnight in another time zone.
        let performedAt = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date

        Task {
            do {
                switch mode {
                case .maintenance:
                    let type = vehicleTypes.first { $0.id == typeID }
                    let draft = MaintenanceDraft(
                        vehicleID: vehicle.id, typeID: type?.id, title: type?.name ?? "Maintenance",
                        notes: notes, cost: costValue, mileage: mileageValue, performedAt: performedAt
                    )
                    let failed = try await store.logMaintenance(draft, photos: photos.map(\.jpeg))
                    if failed > 0 {
                        // The entry itself is saved, so don't let Save run again and duplicate it.
                        photos = []
                        errorMessage = "Entry saved, but \(failed) photo\(failed == 1 ? "" : "s") failed to upload. Close this form; the entry is in History."
                        isSaving = false
                        return
                    }
                case .mileage:
                    try await store.logMileage(MileageDraft(
                        vehicleID: vehicle.id, mileage: mileageValue, note: notes, recordedAt: performedAt
                    ))
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private extension UIImage {
    /// A JPEG no larger than 2000 px on its long side, plus a small thumbnail for the form.
    func preparedForUpload() -> (jpeg: Data, thumbnail: UIImage)? {
        func resized(maxSide: CGFloat) -> UIImage {
            let scale = min(1, maxSide / max(size.width, size.height))
            let target = CGSize(width: size.width * scale, height: size.height * scale)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return UIGraphicsImageRenderer(size: target, format: format).image { _ in
                draw(in: CGRect(origin: .zero, size: target))
            }
        }
        guard let jpeg = resized(maxSide: 2000).jpegData(compressionQuality: 0.8) else { return nil }
        return (jpeg, resized(maxSide: 200))
    }
}
