import Foundation

// MARK: - SimulatorService

/// xcrun simctl list --json을 실행하여 시뮬레이터 목록을 관리하는 서비스.
@MainActor
final class SimulatorService: ObservableObject {

    @Published var bootedSimulators: [SimulatorDevice] = []
    @Published var shutdownSimulators: [SimulatorDevice] = []
    @Published var isLoading = false

    init() {
        Task { await refreshSimulators() }
    }

    // MARK: - Public

    /// 시뮬레이터 목록을 새로고침한다.
    func refreshSimulators() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await runSimctlList()
            let simulators = parseSimulators(from: data)
            bootedSimulators = simulators.filter(\.isBooted)
            shutdownSimulators = simulators.filter { !$0.isBooted }
        } catch {
            print("[SimulatorService] 시뮬레이터 목록 조회 실패: \(error.localizedDescription)")
            bootedSimulators = []
            shutdownSimulators = []
        }
    }

    // MARK: - Parsing (테스트 가능하도록 분리)

    /// JSON Data를 파싱하여 사용 가능한 SimulatorDevice 배열을 반환한다.
    nonisolated func parseSimulators(from data: Data) -> [SimulatorDevice] {
        let decoder = JSONDecoder()

        guard let response = try? decoder.decode(SimctlListResponse.self, from: data) else {
            print("[SimulatorService] JSON 디코딩 실패")
            return []
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        var result: [SimulatorDevice] = []

        for (runtimeKey, devices) in response.devices {
            for device in devices {
                guard device.isAvailable else { continue }

                var lastBootedDate: Date?
                if let dateString = device.lastBootedAt {
                    lastBootedDate = isoFormatter.date(from: dateString)
                        ?? fallbackFormatter.date(from: dateString)
                }

                let simulatorDevice = SimulatorDevice(
                    udid: device.udid,
                    name: device.name,
                    state: device.state,
                    deviceTypeIdentifier: device.deviceTypeIdentifier,
                    runtimeIdentifier: runtimeKey,
                    lastBootedAt: lastBootedDate,
                    dataPath: device.dataPath
                )

                result.append(simulatorDevice)
            }
        }

        result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return result
    }

    // MARK: - Private

    /// xcrun simctl list devices --json을 실행하고 stdout Data를 반환한다.
    private nonisolated func runSimctlList() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "list", "devices", "--json"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                continuation.resume(
                    throwing: SimulatorServiceError.processFailure(
                        exitCode: process.terminationStatus
                    )
                )
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            continuation.resume(returning: data)
        }
    }
}

// MARK: - Errors

enum SimulatorServiceError: LocalizedError {
    case processFailure(exitCode: Int32)

    var errorDescription: String? {
        switch self {
        case .processFailure(let exitCode):
            "xcrun simctl이 종료 코드 \(exitCode)(으)로 실패했습니다."
        }
    }
}
