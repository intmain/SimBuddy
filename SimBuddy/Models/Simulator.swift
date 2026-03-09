import Foundation

// MARK: - App Models

struct SimulatorDevice: Identifiable, Codable, Sendable, Equatable {
    let udid: String
    let name: String
    let state: String
    let deviceTypeIdentifier: String
    let runtimeIdentifier: String
    let lastBootedAt: Date?
    let dataPath: String

    var id: String { udid }

    var isBooted: Bool { state == "Booted" }

    /// runtimeIdentifier에서 "iOS 18.2" 같은 사람이 읽을 수 있는 문자열을 추출한다.
    /// 예: "com.apple.CoreSimulator.SimRuntime.iOS-18-2" -> "iOS 18.2"
    var runtimeVersion: String {
        guard let lastPart = runtimeIdentifier.split(separator: ".").last else {
            return runtimeIdentifier
        }

        let segments = lastPart.split(separator: "-")
        guard segments.count >= 2 else {
            return String(lastPart)
        }

        let platform = String(segments[0])
        let versionParts = segments.dropFirst().map(String.init)
        let version = versionParts.joined(separator: ".")

        return "\(platform) \(version)"
    }
}

// MARK: - xcrun simctl list --json 응답 구조

struct SimctlListResponse: Codable, Sendable {
    let devices: [String: [SimctlDevice]]
}

struct SimctlDevice: Codable, Sendable {
    let udid: String
    let name: String
    let state: String
    let deviceTypeIdentifier: String
    let dataPath: String
    let lastBootedAt: String?
    let isAvailable: Bool
}
