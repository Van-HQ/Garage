import CarPlay
import UIKit
import GarageCore

/// The CarPlay screen: a tab bar with the care list and live drive data.
/// It reads the same `AppServices` the phone UI uses, so both always agree.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var driveTemplate: CPInformationTemplate?
    private var codesTemplate: CPListTemplate?
    /// Drive alerts already queued this session, so each problem interrupts the driver once.
    private var presentedAlerts: Set<String> = []
    /// Everything that wants a full-screen pop-up (alerts, trip summary, reminders) waits here,
    /// so two arriving together can't collide: CarPlay shows one at a time.
    private struct Modal { let title: String; let message: String }
    private var modalQueue: [Modal] = []
    private var isShowingModal = false
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
        modalQueue = []
        isShowingModal = false
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
        collectModals(services)
        presentNextModal()

        // CarPlay templates don't observe anything, so refresh the drive screen on a timer.
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDrive(services)
                self?.refreshCodes(services)
                self?.collectModals(services)
                self?.presentNextModal()
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
            let codeRows: [CPListItem] = services.store.openCodes(for: vehicle).map { code in
                let row = CPListItem(text: "Check engine: \(code)", detailText: TroubleCodes.info(for: code).title)
                row.setImage(UIImage(systemName: "exclamationmark.triangle.fill")?
                    .withTintColor(UIColor(Theme.statusOverdue), renderingMode: .alwaysOriginal))
                return row
            }
            let statuses = services.store.status(for: vehicle)
                .sorted { Self.rank($0.status) < Self.rank($1.status) }
            items = codeRows + statuses.prefix(12).map { status in
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

    // MARK: Pop-ups

    /// Gathers everything new that deserves a pop-up: drive alerts, the last trip's
    /// summary, and maintenance items that just turned overdue.
    @MainActor
    private func collectModals(_ services: AppServices) {
        // Drive problems. Once one clears, forget it, so it can alert again if it returns.
        let current = services.obd.alerts
        presentedAlerts.formIntersection(current.map(\.id))
        for alert in current where !presentedAlerts.contains(alert.id) {
            presentedAlerts.insert(alert.id)
            modalQueue.append(Modal(title: alert.title, message: alert.message))
        }

        // The last trip, once. The drive usually ends after CarPlay has gone, so this shows next connect.
        if let summary = CarPlayMemory.summaryToShow() {
            CarPlayMemory.markShown(summary)
            modalQueue.append(Modal(title: summary.title, message: summary.message))
        }

        // Maintenance that has just become overdue, not everything that is overdue.
        guard services.store.hasLoaded else { return }
        for vehicle in services.store.vehicles {
            let statuses = services.store.status(for: vehicle)
            let previous = CarPlayMemory.reminderMemory(for: vehicle.id)
            let names = ReminderAlerts.newlyOverdue(statuses, previous: previous)
            let memory = ReminderAlerts.memory(of: statuses)
            if memory != previous { CarPlayMemory.saveReminderMemory(memory, for: vehicle.id) }
            if !names.isEmpty {
                modalQueue.append(Modal(title: "Maintenance overdue", message: "\(vehicle.name): \(ReminderAlerts.message(for: names))"))
            }
        }
    }

    /// Shows the next waiting pop-up, if none is on screen. Dismissing one shows the next.
    @MainActor
    private func presentNextModal() {
        guard !isShowingModal, !modalQueue.isEmpty, let controller = interfaceController else { return }
        let next = modalQueue.removeFirst()
        isShowingModal = true

        let ok = CPAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true) { _, _ in
                Task { @MainActor in
                    self?.isShowingModal = false
                    self?.presentNextModal()
                }
            }
        }
        // CPAlertTemplate has no separate body text, so the message rides in the title variants (longest first).
        let alert = CPAlertTemplate(titleVariants: ["\(next.title). \(next.message)", next.title], actions: [ok])
        controller.presentTemplate(alert, animated: true) { [weak self] success, _ in
            guard !success else { return }
            Task { @MainActor in
                self?.isShowingModal = false
            }
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
