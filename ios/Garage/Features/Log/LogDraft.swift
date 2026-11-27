import SwiftUI
import PhotosUI
import GarageCore

/// What the log screens start with. Opening them from a maintenance item fills in the vehicle and type.
struct LogPrefill: Identifiable {
    let id = UUID()
    var vehicleID: UUID?
    var typeID: UUID?
}

/// Everything typed into a new entry, shared by the step-by-step flow and Quick log,
/// so switching between them keeps what you've entered. Saving rules match the web app's /log page.
@MainActor
@Observable
final class LogDraft {
    struct Photo: Identifiable {
        let id = UUID()
        let jpeg: Data
        let thumbnail: UIImage
    }

    let prefill: LogPrefill
    private(set) var vehicleID: UUID?
    var typeID: UUID?
    var isMileageOnly = false
    var mileage = ""
    var date = Date()
    var cost = ""
    var notes = ""
    var photos: [Photo] = []
    private(set) var isSaving = false
    var errorMessage: String?
    private(set) var isSaved = false
    private var isSetUp = false

    init(prefill: LogPrefill) { self.prefill = prefill }

    var mileageValue: Int? { Int(mileage.filter(\.isNumber)) }
    var costValue: Double? { Double(cost.replacingOccurrences(of: ",", with: ".")) }

    func vehicle(in store: GarageStore) -> Vehicle? { store.vehicles.first { $0.id == vehicleID } }
    func types(in store: GarageStore) -> [MaintenanceType] { vehicle(in: store).map(store.types(for:)) ?? [] }
    func type(in store: GarageStore) -> MaintenanceType? { types(in: store).first { $0.id == typeID } }

    func title(in store: GarageStore) -> String {
        isMileageOnly ? "Mileage only" : type(in: store)?.name ?? "Maintenance"
    }

    var canContinue: Bool { vehicleID != nil && mileageValue != nil }

    func canSave(in store: GarageStore) -> Bool {
        guard canContinue, !isSaving else { return false }
        if isMileageOnly { return true }
        // A typed cost has to be a number; an empty one is fine.
        guard cost.trimmingCharacters(in: .whitespaces).isEmpty || costValue != nil else { return false }
        return type(in: store) != nil || types(in: store).isEmpty
    }

    func setUp(store: GarageStore) {
        guard !isSetUp else { return }
        isSetUp = true
        select(vehicle: store.vehicles.first { $0.id == prefill.vehicleID }?.id ?? store.vehicles.first?.id, store: store)
    }

    func select(vehicle id: UUID?, store: GarageStore) {
        vehicleID = id
        guard let vehicle = vehicle(in: store) else { return }
        let available = types(in: store)
        if !available.contains(where: { $0.id == typeID }) {
            // Start on the most urgent item, which is the one most likely being logged.
            let urgent = store.status(for: vehicle).first?.type.id
            typeID = available.first { $0.id == prefill.typeID }?.id ?? urgent ?? available.first?.id
        }
        // Backlogging a specific item should ask for the mileage it was done at,
        // not default to today's estimate. Same rule as the web form.
        mileage = prefill.typeID == nil ? String(projectedMileage(vehicle)) : ""
    }

    func addPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                guard
                    let data = try? await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data),
                    let prepared = image.preparedForUpload()
                else { continue }
                photos.append(Photo(jpeg: prepared.jpeg, thumbnail: prepared.thumbnail))
            }
        }
    }

    func save(store: GarageStore) {
        guard canSave(in: store), let vehicle = vehicle(in: store), let mileageValue else { return }
        isSaving = true
        errorMessage = nil
        // Noon on the chosen day, like the web form, so the date can't slip across midnight in another time zone.
        let performedAt = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let type = type(in: store)

        Task {
            do {
                if isMileageOnly {
                    try await store.logMileage(MileageDraft(
                        vehicleID: vehicle.id, mileage: mileageValue, note: notes, recordedAt: performedAt
                    ))
                } else {
                    let draft = MaintenanceDraft(
                        vehicleID: vehicle.id, typeID: type?.id, title: type?.name ?? "Maintenance",
                        notes: notes, cost: costValue, mileage: mileageValue, performedAt: performedAt
                    )
                    let failed = try await store.logMaintenance(draft, photos: photos.map(\.jpeg))
                    if failed > 0 {
                        // The entry itself is saved, so Save must not run again and duplicate it.
                        photos = []
                        errorMessage = "Entry saved, but \(failed) photo\(failed == 1 ? "" : "s") failed to upload. Close this screen; the entry is in History."
                        return
                    }
                }
                isSaving = false
                isSaved = true
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
