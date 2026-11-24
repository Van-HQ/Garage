import SwiftUI
import GarageCore

/// Live gauges from the OBD source: speed and RPM dials, then the slower values as tiles.
struct DriveView: View {
    @Environment(OBDSession.self) private var obd
    @Environment(TripController.self) private var trips
    @Environment(GarageStore.self) private var store

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    connectionRow

                    HStack(spacing: 14) {
                        DialGauge(
                            title: "MPH",
                            value: obd.value(.speed).map { $0 * 0.621371 },
                            range: 0...100,
                            format: { String(Int($0.rounded())) }
                        )
                        DialGauge(
                            title: "RPM × 1000",
                            value: obd.value(.rpm).map { $0 / 1000 },
                            range: 0...6,
                            format: { $0.formatted(.number.precision(.fractionLength(1))) }
                        )
                    }

                    actionsPanel

                    LazyVGrid(columns: columns, spacing: 10) {
                        tile("Coolant", obd.value(.coolantTemperature).map(fahrenheit), unit: "°F", symbol: "thermometer.medium")
                        tile("Intake air", obd.value(.intakeAirTemperature).map(fahrenheit), unit: "°F", symbol: "wind")
                        tile("Throttle", obd.value(.throttlePosition), unit: "%", symbol: "pedal.accelerator")
                        tile("Engine load", obd.value(.engineLoad), unit: "%", symbol: "engine.combustion")
                        tile("Short fuel trim", obd.value(.shortTermFuelTrim), unit: "%", symbol: "plusminus", decimals: 1, signed: true)
                        tile("Long fuel trim", obd.value(.longTermFuelTrim), unit: "%", symbol: "plusminus", decimals: 1, signed: true)
                        tile("Fuel level", obd.value(.fuelLevel), unit: "%", symbol: "fuelpump")
                        tile("Battery", obd.value(.controlModuleVoltage), unit: "V", symbol: "minus.plus.batteryblock", decimals: 1)
                        // Everything else the car answers for. Values it doesn't support never appear.
                        extraTiles
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Theme.background)
            .navigationTitle("Drive")
        }
    }

    @ViewBuilder
    private var extraTiles: some View {
        if let oil = obd.value(.engineOilTemperature) { tile("Oil temp", fahrenheit(oil), unit: "°F", symbol: "drop.degreesign") }
        if let ambient = obd.value(.ambientAirTemperature) { tile("Outside air", fahrenheit(ambient), unit: "°F", symbol: "thermometer.sun") }
        if let maf = obd.value(.massAirFlow) { tile("Air flow", maf, unit: "g/s", symbol: "wind", decimals: 1) }
        if let map = obd.value(.intakeManifoldPressure) { tile("Manifold pressure", map * 0.145038, unit: "psi", symbol: "gauge.medium", decimals: 1) }
        if let timing = obd.value(.timingAdvance) { tile("Timing advance", timing, unit: "°", symbol: "timer", decimals: 1, signed: true) }
        if let baro = obd.value(.barometricPressure) { tile("Barometric", baro * 0.145038, unit: "psi", symbol: "barometer", decimals: 1) }
        if let run = obd.value(.runTime) { tile("Engine run time", run / 60, unit: "min", symbol: "clock") }
    }

    private var connectionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(statusTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Theme.elevated, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
                Spacer()
                Button(obd.isActive ? "Stop" : "Start") {
                    obd.isActive ? obd.stop() : obd.start()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
                .padding(.horizontal, 6)
            }
            if !statusDetail.isEmpty {
                Text(statusDetail)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 4)
            }
            if store.vehicles.count > 1 {
                Picker("Vehicle", selection: Binding(
                    get: { trips.vehicle?.id },
                    set: { trips.vehicleID = $0 }
                )) {
                    ForEach(store.vehicles) { Text($0.name).tag(Optional($0.id)) }
                }
                .pickerStyle(.segmented)
                .disabled(trips.isRecording)
            }
        }
    }

    /// Trip recording, past trips and trouble codes in one grouped card.
    private var actionsPanel: some View {
        Panel(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Circle().fill(trips.isRecording ? Theme.statusOK : Theme.muted.opacity(0.5)).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trip recording")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.foreground)
                        Text(recordingDetail)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .monospacedDigit()
                    }
                    Spacer()
                    if trips.isRecording {
                        Button("End trip") { trips.finishCurrentTrip() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 20)
                .frame(minHeight: 64)

                Divider().overlay(Theme.hairline).padding(.leading, 20)
                NavigationLink { TripsView() } label: {
                    linkRow(title: "Trips",
                            detail: trips.pending.isEmpty ? "Recorded drives" : "\(trips.pending.count) waiting to upload",
                            warn: !trips.pending.isEmpty)
                }
                .buttonStyle(.plain)

                Divider().overlay(Theme.hairline).padding(.leading, 20)
                NavigationLink { TroubleCodesView() } label: {
                    linkRow(title: "Trouble codes", detail: "Read stored codes", warn: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recordingDetail: String {
        if let progress = trips.progress {
            return "\(progress.distanceMiles.oneDecimal) mi · \(progress.lastUpdate.timeIntervalSince(progress.startedAt).durationText) so far"
        }
        return obd.isActive ? "Starts when the vehicle moves" : "Start the connection to record trips"
    }

    private func linkRow(title: String, detail: String, warn: Bool) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(warn ? Theme.statusSoon : Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    private var statusTitle: String {
        switch obd.state {
        case .disconnected: "Not connected"
        case .connecting: "Connecting…"
        case .connected(let adapter): "Connected · \(adapter)"
        case .failed: "Connection failed"
        }
    }

    private var statusDetail: String {
        if case .failed(let message) = obd.state { return message }
        // Said plainly on screen so made-up numbers are never mistaken for the truck's.
        return obd.source is SimulatedOBDSource ? "Simulated drive, not real vehicle data" : ""
    }

    private var statusColor: Color {
        switch obd.state {
        case .disconnected: Theme.muted
        case .connecting: Theme.statusSoon
        case .connected: Theme.statusOK
        case .failed: Theme.statusOverdue
        }
    }

    private func fahrenheit(_ celsius: Double) -> Double { celsius * 9 / 5 + 32 }

    private func tile(_ title: String, _ value: Double?, unit: String, symbol: String, decimals: Int = 0, signed: Bool = false) -> some View {
        let text: String = value.map { value in
            let number = value.formatted(.number.precision(.fractionLength(decimals)).sign(strategy: signed ? .always(includingZero: false) : .automatic))
            return number
        } ?? "—"
        return VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(text)
                    .font(.system(size: 26, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.foreground)
                    .contentTransition(.numericText())
                if value != nil {
                    Text(unit)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
        .animation(.default, value: text)
    }
}

/// A 270-degree dial with the value in the middle.
private struct DialGauge: View {
    let title: String
    let value: Double?
    let range: ClosedRange<Double>
    let format: (Double) -> String

    private var fraction: Double {
        guard let value else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Theme.hairline, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(135))
                .animation(.linear(duration: 0.5), value: fraction)
            VStack(spacing: 2) {
                Text(value.map(format) ?? "—")
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.foreground)
                    .contentTransition(.numericText())
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(8)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value.map(format) ?? "No data")
    }
}
