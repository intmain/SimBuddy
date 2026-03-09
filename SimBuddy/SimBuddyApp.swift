import SwiftUI

@main
struct SimBuddyApp: App {
    @StateObject private var simulatorService = SimulatorService()

    var body: some Scene {
        MenuBarExtra("SimBuddy", systemImage: "iphone") {
            MenuBarView()
                .environmentObject(simulatorService)
        }

        Window("Storage Manager", id: "storage-manager") {
            StorageManagerView()
        }
        .defaultSize(width: 600, height: 400)
    }
}
