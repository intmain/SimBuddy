import Foundation
import SwiftUI

@MainActor
final class MenuBarViewModel: ObservableObject {

    // MARK: - Published State

    @Published var bootedSimulators: [SimulatorDevice] = []
    @Published var shutdownSimulators: [SimulatorDevice] = []
    @Published var isLoading = false
    @Published var appsBySimulator: [String: [SimulatorApp]] = [:]
    @Published var isLoadingApps: [String: Bool] = [:]
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let sandboxService = SandboxService()

    // MARK: - Actions

    func refresh(from service: SimulatorService) {
        bootedSimulators = service.bootedSimulators
        shutdownSimulators = service.shutdownSimulators
        isLoading = service.isLoading
    }

    func loadApps(for simulator: SimulatorDevice, forceReload: Bool = false) {
        guard forceReload || appsBySimulator[simulator.udid] == nil else { return }
        isLoadingApps[simulator.udid] = true

        let apps = sandboxService.getInstalledApps(for: simulator)
        appsBySimulator[simulator.udid] = apps
        isLoadingApps[simulator.udid] = false
    }

    func invalidateAppCache() {
        appsBySimulator.removeAll()
        isLoadingApps.removeAll()
    }

    func handleAppClick(app: SimulatorApp) {
        if NSEvent.modifierFlags.contains(.option) {
            sandboxService.copyToClipboard(path: app.sandboxPath)
        } else {
            sandboxService.openInFinder(path: app.sandboxPath)
        }
    }

    func openProvisioningProfiles() {
        let path = NSHomeDirectory() + "/Library/MobileDevice/Provisioning Profiles"
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
