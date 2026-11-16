import Foundation

/// A plain-English explanation of a diagnostic trouble code.
public struct TroubleCodeInfo: Hashable, Sendable, Identifiable {
    public let code: String
    /// Short name, such as "EVAP system: very small leak".
    public let title: String
    /// What it usually means and what to check first.
    public let explanation: String
    /// False when the app has no specific entry and is describing the code's family only.
    public let isKnown: Bool

    public var id: String { code }
}

public enum TroubleCodes {
    /// Looks a code up. Unknown codes still get an honest, general description
    /// built from the code's structure rather than a guess at the fault.
    public static func info(for rawCode: String) -> TroubleCodeInfo {
        let code = rawCode.uppercased()
        if let entry = known[code] {
            return TroubleCodeInfo(code: code, title: entry.0, explanation: entry.1, isKnown: true)
        }
        if let cylinder = misfireCylinder(code) {
            return TroubleCodeInfo(
                code: code,
                title: "Cylinder \(cylinder) misfire",
                explanation: "Cylinder \(cylinder) isn't firing reliably. Spark plug and ignition coil for that cylinder are the usual first checks. A flashing check-engine light means stop driving hard: raw fuel can damage the catalytic converter.",
                isKnown: true
            )
        }
        return TroubleCodeInfo(code: code, title: familyTitle(code), explanation: familyExplanation(code), isKnown: false)
    }

    private static func misfireCylinder(_ code: String) -> Int? {
        guard code.hasPrefix("P03"), let number = Int(code.dropFirst(3)), (1...12).contains(number) else { return nil }
        return number
    }

    private static func familyTitle(_ code: String) -> String {
        switch code.first {
        case "P": "Powertrain code"
        case "C": "Chassis code"
        case "B": "Body code"
        case "U": "Network communication code"
        default: "Unrecognized code"
        }
    }

    private static func familyExplanation(_ code: String) -> String {
        let digits = Array(code)
        // The second character says who defined the code: 0 is the shared standard, 1 is the car maker.
        let makerSpecific = digits.count > 1 && digits[1] == "1"
        return makerSpecific
            ? "This is a manufacturer-specific code, so its meaning depends on the vehicle. Look up \(code) for your Toyota, or have the dealer read it."
            : "The app doesn't have a description for this one. Look up \(code) before clearing it."
    }

    /// Common generic (SAE-defined) codes. Titles follow the standard definitions.
    private static let known: [String: (String, String)] = [
        "P0101": ("Mass air flow sensor: out of range", "The engine is measuring an unexpected amount of incoming air. A dirty air filter or MAF sensor, or an intake leak, are common causes."),
        "P0113": ("Intake air temperature sensor: signal high", "The intake air temperature reading is implausibly cold, usually from an unplugged or failed sensor or broken wiring."),
        "P0128": ("Coolant not reaching operating temperature", "The engine is taking too long to warm up. A thermostat stuck open is the usual cause."),
        "P0131": ("Oxygen sensor low voltage (bank 1, sensor 1)", "The upstream oxygen sensor is reading lean or has failed. Check for exhaust or vacuum leaks before replacing the sensor."),
        "P0133": ("Oxygen sensor slow response (bank 1, sensor 1)", "The upstream oxygen sensor is reacting slowly, typically from age. Exhaust leaks can also cause it."),
        "P0135": ("Oxygen sensor heater circuit (bank 1, sensor 1)", "The heater inside the upstream oxygen sensor isn't working. Usually the sensor itself or its fuse."),
        "P0141": ("Oxygen sensor heater circuit (bank 1, sensor 2)", "The heater inside the downstream oxygen sensor isn't working. Usually the sensor itself or its fuse."),
        "P0171": ("System too lean (bank 1)", "The engine is getting too much air or too little fuel. Vacuum leaks, a dirty MAF sensor and weak fuel delivery are the common causes."),
        "P0172": ("System too rich (bank 1)", "The engine is getting too much fuel or too little air. Leaking injectors, a faulty sensor or a clogged air filter are common causes."),
        "P0174": ("System too lean (bank 2)", "The engine is getting too much air or too little fuel on bank 2. Vacuum leaks and a dirty MAF sensor are the common causes."),
        "P0175": ("System too rich (bank 2)", "The engine is getting too much fuel or too little air on bank 2."),
        "P0300": ("Random or multiple cylinder misfire", "More than one cylinder is misfiring. Spark plugs, coils, vacuum leaks and fuel delivery are the usual suspects. A flashing check-engine light means ease off: raw fuel can damage the catalytic converter."),
        "P0325": ("Knock sensor 1 circuit", "The knock sensor or its wiring has a fault. The engine may pull timing and feel down on power."),
        "P0335": ("Crankshaft position sensor circuit", "The engine computer isn't getting a good crankshaft position signal. This can cause stalling or a no-start."),
        "P0340": ("Camshaft position sensor circuit", "The engine computer isn't getting a good camshaft position signal. This can cause hard starting or rough running."),
        "P0401": ("EGR flow insufficient", "Not enough exhaust gas is being recirculated, usually from a clogged EGR passage or a stuck valve."),
        "P0420": ("Catalytic converter efficiency below threshold (bank 1)", "The catalytic converter isn't cleaning the exhaust as well as it should. It may be worn out, but rule out exhaust leaks and oxygen sensor faults first."),
        "P0430": ("Catalytic converter efficiency below threshold (bank 2)", "The bank 2 catalytic converter isn't cleaning the exhaust as well as it should. Rule out exhaust leaks and oxygen sensor faults first."),
        "P0440": ("EVAP system fault", "The fuel vapor recovery system has a problem. Start with the gas cap: make sure it's tight and its seal isn't cracked."),
        "P0441": ("EVAP system: incorrect purge flow", "Fuel vapor isn't being drawn into the engine as expected, often a purge valve fault."),
        "P0442": ("EVAP system: small leak", "A small fuel vapor leak. A loose or worn gas cap is the most common cause."),
        "P0446": ("EVAP vent control circuit", "The vent valve for the fuel vapor system has a fault, often the valve or a blocked vent."),
        "P0455": ("EVAP system: large leak", "A large fuel vapor leak. Check that the gas cap is on and tight first."),
        "P0456": ("EVAP system: very small leak", "A very small fuel vapor leak. Tighten the gas cap and see if the code returns; a worn cap seal is the most common cause."),
        "P0500": ("Vehicle speed sensor", "The speed signal is missing or implausible. The speedometer and shifting may act up."),
        "P0505": ("Idle control system", "The engine can't hold its target idle speed. A dirty throttle body or a vacuum leak are common causes."),
        "P0562": ("System voltage low", "Battery or charging voltage is low. Check the battery, its terminals and the alternator."),
        "P0563": ("System voltage high", "Charging voltage is too high, usually a failing alternator or voltage regulator."),
        "P0700": ("Transmission control system fault", "The transmission computer has stored its own fault. It needs a scan of the transmission module for the specific code."),
        "U0100": ("Lost communication with the engine computer", "Other modules can't reach the engine computer. Check battery voltage and connections first."),
        "U0101": ("Lost communication with the transmission computer", "Other modules can't reach the transmission computer. Check battery voltage and wiring first."),
        "U0121": ("Lost communication with the ABS module", "Other modules can't reach the anti-lock brake computer. ABS and stability control may be off."),
    ]
}
