import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var simulatorService: SimulatorService
    @StateObject private var viewModel = MenuBarViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Booted simulators
        if viewModel.bootedSimulators.isEmpty && viewModel.shutdownSimulators.isEmpty {
            if viewModel.isLoading {
                Text("로딩 중...")
                    .disabled(true)
            } else {
                Text("No Simulators Found")
                    .disabled(true)
            }
        } else {
            ForEach(viewModel.bootedSimulators) { simulator in
                simulatorMenu(simulator, booted: true)
            }

            if !viewModel.bootedSimulators.isEmpty && !viewModel.shutdownSimulators.isEmpty {
                Divider()
            }

            // Shutdown simulators as a submenu
            if !viewModel.shutdownSimulators.isEmpty {
                Menu("Shutdown Simulators (\(viewModel.shutdownSimulators.count))") {
                    ForEach(viewModel.shutdownSimulators) { simulator in
                        simulatorMenu(simulator, booted: false)
                    }
                }
            }
        }

        Divider()

        Button("Storage Manager") {
            openWindow(id: "storage-manager")
        }

        Button("Provisioning Profiles") {
            viewModel.openProvisioningProfiles()
        }

        Divider()

        Text("⌥ click to copy path")
            .disabled(true)

        Divider()

        Button("Quit SimBuddy") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
        .task {
            viewModel.refresh(from: simulatorService)
            viewModel.invalidateAppCache()
            await simulatorService.refreshSimulators()
        }
        .onChange(of: simulatorService.bootedSimulators) {
            viewModel.refresh(from: simulatorService)
            preloadApps()
        }
        .onChange(of: simulatorService.shutdownSimulators) {
            viewModel.refresh(from: simulatorService)
        }
        .onChange(of: simulatorService.isLoading) {
            viewModel.refresh(from: simulatorService)
        }
    }

    @ViewBuilder
    private func simulatorMenu(_ simulator: SimulatorDevice, booted: Bool) -> some View {
        let label = booted
            ? "● \(simulator.name) — \(simulator.runtimeVersion)"
            : "\(simulator.name) — \(simulator.runtimeVersion)"

        if let apps = viewModel.appsBySimulator[simulator.udid], !apps.isEmpty {
            Menu(label) {
                ForEach(apps) { app in
                    Button(app.displayName) {
                        viewModel.handleAppClick(app: app)
                    }
                }
            }
        } else {
            Menu(label) {
                Text("No Apps Installed")
                    .disabled(true)
            }
        }
    }

    private func preloadApps() {
        for simulator in viewModel.bootedSimulators {
            viewModel.loadApps(for: simulator, forceReload: true)
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(SimulatorService())
}
