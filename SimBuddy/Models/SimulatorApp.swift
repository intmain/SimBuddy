import Foundation

struct SimulatorApp: Identifiable, Sendable {
    let bundleIdentifier: String
    let displayName: String
    let sandboxPath: String
    let bundlePath: String

    var id: String { bundleIdentifier }
}
