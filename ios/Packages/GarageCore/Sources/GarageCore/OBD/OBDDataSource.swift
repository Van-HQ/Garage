import Foundation

public enum OBDConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    /// Connected and reading. `adapter` is a name to show, such as "OBDLink CX".
    case connected(adapter: String)
    case failed(String)
}

public enum OBDEvent: Sendable {
    case state(OBDConnectionState)
    case readings([OBDReading])
}

/// Where live vehicle data comes from. The simulator implements this today; the
/// Bluetooth LE adapter will implement the same protocol, so screens, trip
/// logging and CarPlay never know which one they are talking to.
public protocol OBDDataSource: Sendable {
    /// A name for the source itself, shown before it connects.
    var displayName: String { get }

    /// Connects and streams events. Reading starts when the stream is iterated
    /// and stops (and disconnects) when the consumer stops iterating.
    func events() -> AsyncStream<OBDEvent>

    /// Stored trouble codes, such as ["P0456"]. Empty when the car has none.
    func readTroubleCodes() async throws -> [String]

    /// Clears stored codes and turns off the check-engine light.
    func clearTroubleCodes() async throws
}
