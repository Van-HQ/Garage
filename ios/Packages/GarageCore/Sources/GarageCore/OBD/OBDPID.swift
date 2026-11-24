import Foundation

/// The live-data values the app reads (OBD-II service 01). Values are kept in
/// the units the standard defines (km/h, °C, %); the UI converts for display.
public enum OBDPID: UInt8, CaseIterable, Sendable, Codable {
    case engineLoad = 0x04
    case coolantTemperature = 0x05
    case shortTermFuelTrim = 0x06
    case longTermFuelTrim = 0x07
    case intakeManifoldPressure = 0x0B
    case rpm = 0x0C
    case speed = 0x0D
    case timingAdvance = 0x0E
    case intakeAirTemperature = 0x0F
    case massAirFlow = 0x10
    case throttlePosition = 0x11
    case runTime = 0x1F
    case fuelLevel = 0x2F
    case barometricPressure = 0x33
    case controlModuleVoltage = 0x42
    case ambientAirTemperature = 0x46
    case engineOilTemperature = 0x5C

    /// How many data bytes the reply carries.
    public var byteCount: Int {
        switch self {
        case .rpm, .controlModuleVoltage, .massAirFlow, .runTime: 2
        default: 1
        }
    }

    /// The request to send to an ELM327-style adapter, such as "010C".
    public var command: String { String(format: "01%02X", rawValue) }

    /// Turns the reply's data bytes into a value (SAE J1979 formulas). Nil if bytes are missing.
    public func decode(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= byteCount else { return nil }
        let a = Double(bytes[0])
        switch self {
        case .engineLoad, .throttlePosition, .fuelLevel:
            return a * 100 / 255
        case .coolantTemperature, .intakeAirTemperature, .ambientAirTemperature, .engineOilTemperature:
            return a - 40
        case .shortTermFuelTrim, .longTermFuelTrim:
            return (a - 128) * 100 / 128
        case .rpm:
            return (a * 256 + Double(bytes[1])) / 4
        case .speed, .intakeManifoldPressure, .barometricPressure:
            return a
        case .timingAdvance:
            return a / 2 - 64
        case .massAirFlow:
            return (a * 256 + Double(bytes[1])) / 100
        case .runTime:
            return a * 256 + Double(bytes[1])
        case .controlModuleVoltage:
            return (a * 256 + Double(bytes[1])) / 1000
        }
    }

    /// The reverse of `decode`, used by the simulator to produce real-looking replies.
    public func encode(_ value: Double) -> [UInt8] {
        func byte(_ x: Double) -> UInt8 { UInt8(max(0, min(255, x.rounded()))) }
        func word(_ x: Double) -> [UInt8] {
            let clamped = UInt16(max(0, min(65535, x.rounded())))
            return [UInt8(clamped >> 8), UInt8(clamped & 0xFF)]
        }
        switch self {
        case .engineLoad, .throttlePosition, .fuelLevel:
            return [byte(value * 255 / 100)]
        case .coolantTemperature, .intakeAirTemperature, .ambientAirTemperature, .engineOilTemperature:
            return [byte(value + 40)]
        case .shortTermFuelTrim, .longTermFuelTrim:
            return [byte(value * 128 / 100 + 128)]
        case .rpm:
            return word(value * 4)
        case .speed, .intakeManifoldPressure, .barometricPressure:
            return [byte(value)]
        case .timingAdvance:
            return [byte((value + 64) * 2)]
        case .massAirFlow:
            return word(value * 100)
        case .runTime:
            return word(value)
        case .controlModuleVoltage:
            return word(value * 1000)
        }
    }
}

public struct OBDReading: Hashable, Sendable {
    public let pid: OBDPID
    public let value: Double
    public let timestamp: Date

    public init(pid: OBDPID, value: Double, timestamp: Date) {
        self.pid = pid; self.value = value; self.timestamp = timestamp
    }
}

/// How often each value is asked for. Fast-changing values are polled quickly;
/// temperatures, trims, fuel and voltage barely move and are polled slowly.
public struct OBDSamplingPlan: Sendable {
    public var fastPIDs: [OBDPID]
    public var slowPIDs: [OBDPID]
    public var fastInterval: TimeInterval
    public var slowInterval: TimeInterval

    public init(fastPIDs: [OBDPID], slowPIDs: [OBDPID], fastInterval: TimeInterval, slowInterval: TimeInterval) {
        self.fastPIDs = fastPIDs; self.slowPIDs = slowPIDs
        self.fastInterval = fastInterval; self.slowInterval = slowInterval
    }

    public static let standard = OBDSamplingPlan(
        fastPIDs: [.rpm, .speed, .throttlePosition, .engineLoad],
        slowPIDs: [.coolantTemperature, .intakeAirTemperature, .shortTermFuelTrim, .longTermFuelTrim, .fuelLevel, .controlModuleVoltage,
         // Not every car answers these; a "NO DATA" reply is skipped, so only what the car supports shows up.
         .intakeManifoldPressure, .timingAdvance, .massAirFlow, .runTime, .barometricPressure, .ambientAirTemperature, .engineOilTemperature],
        fastInterval: 0.5,
        slowInterval: 5
    )
}
