import CarPlay
import UIKit
import GarageCore

/// The CarPlay screen: a tab bar with the care list and live drive data.
/// It reads the same `AppServices` the phone UI uses, so both always agree.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var driveTemplate: CPInformationTemplate?
    private var codesTemplate: CPListTemplate?
    /// Alerts already shown this session, so each problem interrupts the driver once.
    private var presentedAlerts: Set<String> = []
    private var isShowingAlert = false
    private var refreshTimer: Timer?

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        Task { @MainActor in
            await self.start()
        }
    }

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        refreshTimer?.invalidate()
        refreshTimer = nil
        self.interfaceController = nil
        driveTemplate = nil
        codesTemplate = nil
        presentedAlerts = []
        isShowingAlert = false
    }

    // MARK: Building the screens

    @MainActor
    private func start() async {
        guard let services = AppServices.shared else {
            show([messageTemplate("Open Garage on your iPhone to finish setup.")])
            return
        }
        if !services.store.hasLoaded { await services.store.refresh() }

        let care = careTemplate(services)
        let drive = makeDriveTemplate(services)
        driveTemplate = drive
        let codes = makeCodesTemplate(services)
        codesTemplate = codes
        show([care, drive, codes])

        // CarPlay templates don't observe anything, so refresh the drive screen on a timer.
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDrive(services)
                self?.refreshCodes(services)
                self?.presentNewAlert(services)
            }
        }
    }

    private func show(_ templates: [CPTemplate]) {
        let root: CPTemplate = templates.count == 1 ? templates[0] : CPTabBarTemplate(templates: templates)
        interfaceController?.setRootTemplate(root, animated: false, completion: nil)
    }

    private func messageTemplate(_ text: String) -> CPInformationTemplate {
        CPInformationTemplate(title: "Garage", layout: .leading, items: [CPInformationItem(title: nil, detail: text)], actions: [])
    }

    @MainActor
    private func careTemplate(_ services: AppServices) -> CPListTemplate {
        let items: [CPListItem]
        if let vehicle = services.trips.vehicle {
            let statuses = services.store.status(for: vehicle)
                .sorted { Self.rank($0.status) < Self.rank($1.status) }
            items = statuses.prefix(12).map { status in
                // Overdue rows already say "Overdue by …", so don't repeat the label.
                let detail = status.status == .overdue ? status.detailText : "\(status.status.label) · \(status.detailText)"
                let row = CPListItem(text: status.type.name, detailText: detail)
                row.setImage(UIImage(systemName: status.type.symbolName)?
                    .withTintColor(UIColor(status.status.color), renderingMode: .alwaysOriginal))
                return row
            }
        } else {
            items = []
        }
        let list = CPListTemplate(title: "Care", sections: [CPListSection(items: items)])
        list.tabTitle = "Care"
        list.tabImage = UIImage(systemName: "wrench.adjustable")
        list.emptyViewTitleVariants = ["No vehicle yet"]
        list.emptyViewSubtitleVariants = ["Add one in the Garage app."]
        return list
    }

    private static func rank(_ status: DueStatus) -> Int {
        switch status {
        case .overdue: 0
        case .dueSoon: 1
        case .unscheduled: 2
        case .ok: 3
        }
    }

    @MainActor
    private func makeDriveTemplate(_ services: AppServices) -> CPInformationTemplate {
        let template = CPInformationTemplate(
            title: services.trips.vehicle?.name ?? "Drive",
            layout: .twoColumn,
            items: driveItems(services),
            actions: []
        )
        template.tabTitle = "Drive"
        template.tabImage = UIImage(systemName: "gauge.with.dots.needle.67percent")
        return template
    }

    @MainActor
    private func refreshDrive(_ services: AppServices) {
        driveTemplate?.items = driveItems(services)
    }

    // MARK: Trouble codes

    @MainActor
    private func makeCodesTemplate(_ services: AppServices) -> CPListTemplate {
        let template = CPListTemplate(title: "Codes", sections: codeSections(services))
        template.tabTitle = "Codes"
        template.tabImage = UIImage(systemName: "exclamationmark.triangle")
        template.emptyViewTitleVariants = ["No trouble codes"]
        template.emptyViewSubtitleVariants = ["The car isn't reporting any."]
        return template
    }

    @MainActor
    private func refreshCodes(_ services: AppServices) {
        codesTemplate?.updateSections(codeSections(services))
    }

    @MainActor
    private func codeSections(_ services: AppServices) -> [CPListSection] {
        guard case .connected = services.obd.state else {
            let row = CPListItem(text: "Adapter not connected", detailText: "Start a drive on your iPhone to read codes.")
            return [CPListSection(items: [row])]
        }
        guard services.obd.hasReadCodes else {
            return [CPListSection(items: [CPListItem(text: "Reading codes…", detailText: nil)])]
        }
        let rows = services.obd.troubleCodes.map { code -> CPListItem in
            let info = TroubleCodes.info(for: code)
            let row = CPListItem(text: code, detailText: info.title)
            row.handler = { [weak self] _, completion in
                self?.showCodeDetail(info)
                completion()
            }
            return row
        }
        return [CPListSection(items: rows)]
    }

    private func showCodeDetail(_ info: TroubleCodeInfo) {
        let detail = CPInformationTemplate(
            title: info.code,
            layout: .leading,
            items: [
                CPInformationItem(title: info.title, detail: info.explanation),
            ],
            actions: []
        )
        interfaceController?.pushTemplate(detail, animated: true, completion: nil)
    }

    // MARK: Alerts

    /// Pops a full-screen alert for a problem that just started: hot coolant or a new check-engine code.
    @MainActor
    private func presentNewAlert(_ services: AppServices) {
        let current = services.obd.alerts
        // Once a problem clears, forget it, so it can alert again if it comes back.
        presentedAlerts.formIntersection(current.map(\.id))
        guard !isShowingAlert, let next = current.first(where: { !presentedAlerts.contains($0.id) }) else { return }
        presentedAlerts.insert(next.id)
        isShowingAlert = true

        let ok = CPAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true) { _, _ in
                self?.isShowingAlert = false
            }
        }
        // CPAlertTemplate has no separate body text, so the message rides in the title variants (longest first).
        let alert = CPAlertTemplate(titleVariants: ["\(next.title): \(next.message)", next.title], actions: [ok])
        interfaceController?.presentTemplate(alert, animated: true) { [weak self] success, _ in
            if !success { self?.isShowingAlert = false }
        }
    }

    @MainActor
    private func driveItems(_ services: AppServices) -> [CPInformationItem] {
        let obd = services.obd
        guard case .connected = obd.state else {
            return [CPInformationItem(title: "Adapter", detail: "Not connected")]
        }
        func number(_ value: Double?, _ format: String) -> String {
            value.map { String(format: format, $0) } ?? "–"
        }
        let mph = obd.value(.speed).map { $0 * 0.621371 }
        let coolantF = obd.value(.coolantTemperature).map { $0 * 9 / 5 + 32 }
        return [
            CPInformationItem(title: "Speed", detail: number(mph, "%.0f mph")),
            CPInformationItem(title: "RPM", detail: number(obd.value(.rpm), "%.0f")),
            CPInformationItem(title: "Coolant", detail: number(coolantF, "%.0f °F")),
            CPInformationItem(title: "Fuel", detail: number(obd.value(.fuelLevel), "%.0f%%")),
            CPInformationItem(title: "Battery", detail: number(obd.value(.controlModuleVoltage), "%.1f V")),
        ]
    }
}
