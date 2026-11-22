import Foundation

/// A trouble code the car reported that hasn't been cleared yet.
public struct OpenTroubleCode: Hashable, Sendable {
    public let vehicleID: UUID
    public let code: String

    public init(vehicleID: UUID, code: String) {
        self.vehicleID = vehicleID
        self.code = code
    }
}
