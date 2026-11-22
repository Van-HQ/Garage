import CarPlay
import UIKit
import GarageCore

/// The CarPlay screen: a tab bar with the care list and live drive data.
/// It reads the same `AppServices` the phone UI uses, so both always agree.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var driveTemplate: CPInformationTemplate?
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
        show([care, drive])

        // CarPlay templates don't observe anything, so refresh the drive screen on a timer.
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshDrive(services) }
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
