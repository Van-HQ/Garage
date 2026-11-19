import Foundation

// Rows of the existing Supabase tables (supabase/schema.sql). Field names map
// to the snake_case columns through CodingKeys.

public struct Vehicle: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var userID: UUID
    public var name: String
    public var make: String
    public var model: String
    public var year: Int
    public var color: String?
    public var icon: String?
    public var currentMileage: Int
    public var manualUploadedAt: Date?
    public var mileageUpdatedAt: Date
    public var avgDailyMiles: Double
    public var sortOrder: Int
    public var createdAt: Date

    public init(
        id: UUID, userID: UUID, name: String, make: String, model: String, year: Int,
        color: String? = nil, icon: String? = "truck", currentMileage: Int,
        manualUploadedAt: Date? = nil, mileageUpdatedAt: Date, avgDailyMiles: Double,
        sortOrder: Int = 0, createdAt: Date
    ) {
        self.id = id; self.userID = userID; self.name = name; self.make = make
        self.model = model; self.year = year; self.color = color; self.icon = icon
        self.currentMileage = currentMileage; self.manualUploadedAt = manualUploadedAt
        self.mileageUpdatedAt = mileageUpdatedAt; self.avgDailyMiles = avgDailyMiles
        self.sortOrder = sortOrder; self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, make, model, year, color, icon
        case userID = "user_id"
        case currentMileage = "current_mileage"
        case manualUploadedAt = "manual_uploaded_at"
        case mileageUpdatedAt = "mileage_updated_at"
        case avgDailyMiles = "avg_daily_miles"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

public enum MaintenanceCategory: String, Codable, CaseIterable, Sendable {
    case oil, tires, wash, upgrade, inspection, custom

    /// Unknown values decode as `.custom` so a category added on the web later can't break the app.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MaintenanceCategory(rawValue: raw) ?? .custom
    }

    /// Same labels as MAINTENANCE_CATEGORIES in the web app's types.ts.
    public var label: String {
        switch self {
        case .oil: "Oil Change"
        case .tires: "Tires"
        case .wash: "Car Wash"
        case .upgrade: "Upgrade / Mod"
        case .inspection: "Inspection"
        case .custom: "Custom"
        }
    }
}

public struct MaintenanceType: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var userID: UUID
    /// Nil means the type applies to all of the user's vehicles.
    public var vehicleID: UUID?
    public var name: String
    public var category: MaintenanceCategory
    public var icon: String?
    public var intervalMiles: Int?
    public var intervalDays: Int?
    public var baselineMileage: Int?
    public var baselineDate: Date?
    public var createdAt: Date

    public init(
        id: UUID, userID: UUID, vehicleID: UUID? = nil, name: String,
        category: MaintenanceCategory = .custom, icon: String? = "wrench",
        intervalMiles: Int? = nil, intervalDays: Int? = nil,
        baselineMileage: Int? = nil, baselineDate: Date? = nil, createdAt: Date
    ) {
        self.id = id; self.userID = userID; self.vehicleID = vehicleID; self.name = name
        self.category = category; self.icon = icon; self.intervalMiles = intervalMiles
        self.intervalDays = intervalDays; self.baselineMileage = baselineMileage
        self.baselineDate = baselineDate; self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, icon
        case userID = "user_id"
        case vehicleID = "vehicle_id"
        case intervalMiles = "interval_miles"
        case intervalDays = "interval_days"
        case baselineMileage = "baseline_mileage"
        case baselineDate = "baseline_date"
        case createdAt = "created_at"
    }
}

public struct MaintenanceLog: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var userID: UUID
    public var vehicleID: UUID
    public var maintenanceTypeID: UUID?
    public var title: String
    public var notes: String?
    public var cost: Double?
    public var mileageAt: Int
    public var performedAt: Date
    public var createdAt: Date

    public init(
        id: UUID, userID: UUID, vehicleID: UUID, maintenanceTypeID: UUID? = nil,
        title: String, notes: String? = "", cost: Double? = nil, mileageAt: Int,
        performedAt: Date, createdAt: Date? = nil
    ) {
        self.id = id; self.userID = userID; self.vehicleID = vehicleID
        self.maintenanceTypeID = maintenanceTypeID; self.title = title; self.notes = notes
        self.cost = cost; self.mileageAt = mileageAt; self.performedAt = performedAt
        self.createdAt = createdAt ?? performedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, cost
        case userID = "user_id"
        case vehicleID = "vehicle_id"
        case maintenanceTypeID = "maintenance_type_id"
        case mileageAt = "mileage_at"
        case performedAt = "performed_at"
        case createdAt = "created_at"
    }
}

public struct MaintenancePhoto: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var userID: UUID
    public var maintenanceLogID: UUID
    public var storagePath: String
    public var createdAt: Date

    public init(id: UUID, userID: UUID, maintenanceLogID: UUID, storagePath: String, createdAt: Date) {
        self.id = id; self.userID = userID; self.maintenanceLogID = maintenanceLogID
        self.storagePath = storagePath; self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case maintenanceLogID = "maintenance_log_id"
        case storagePath = "storage_path"
        case createdAt = "created_at"
    }
}

public struct MileageLog: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var userID: UUID
    public var vehicleID: UUID
    public var mileage: Int
    public var note: String?
    public var recordedAt: Date
    public var createdAt: Date

    public init(
        id: UUID, userID: UUID, vehicleID: UUID, mileage: Int, note: String? = "",
        recordedAt: Date, createdAt: Date? = nil
    ) {
        self.id = id; self.userID = userID; self.vehicleID = vehicleID; self.mileage = mileage
        self.note = note; self.recordedAt = recordedAt; self.createdAt = createdAt ?? recordedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, mileage, note
        case userID = "user_id"
        case vehicleID = "vehicle_id"
        case recordedAt = "recorded_at"
        case createdAt = "created_at"
    }
}

/// A saved drive (the `trips` table).
public struct Trip: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var vehicleID: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var distanceMiles: Double
    public var avgSpeedMph: Double?
    public var maxSpeedMph: Double?
    public var maxRPM: Double?
    public var maxCoolantC: Double?
    public var fuelUsedPercent: Double?
    public var distanceSource: String

    public init(
        id: UUID, vehicleID: UUID, startedAt: Date, endedAt: Date, distanceMiles: Double,
        avgSpeedMph: Double? = nil, maxSpeedMph: Double? = nil, maxRPM: Double? = nil,
        maxCoolantC: Double? = nil, fuelUsedPercent: Double? = nil, distanceSource: String = "obd"
    ) {
        self.id = id; self.vehicleID = vehicleID; self.startedAt = startedAt; self.endedAt = endedAt
        self.distanceMiles = distanceMiles; self.avgSpeedMph = avgSpeedMph; self.maxSpeedMph = maxSpeedMph
        self.maxRPM = maxRPM; self.maxCoolantC = maxCoolantC; self.fuelUsedPercent = fuelUsedPercent
        self.distanceSource = distanceSource
    }

    public var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleID = "vehicle_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case distanceMiles = "distance_miles"
        case avgSpeedMph = "avg_speed_mph"
        case maxSpeedMph = "max_speed_mph"
        case maxRPM = "max_rpm"
        case maxCoolantC = "max_coolant_c"
        case fuelUsedPercent = "fuel_used_pct"
        case distanceSource = "distance_source"
    }
}

public extension RecordedTrip {
    var summary: Trip {
        Trip(
            id: id, vehicleID: vehicleID, startedAt: startedAt, endedAt: endedAt, distanceMiles: distanceMiles,
            avgSpeedMph: avgSpeedMph, maxSpeedMph: maxSpeedMph, maxRPM: maxRPM, maxCoolantC: maxCoolantC,
            fuelUsedPercent: fuelUsedPercent, distanceSource: distanceSource
        )
    }
}
