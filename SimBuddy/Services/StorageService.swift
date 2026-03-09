import Foundation

// MARK: - Storage Models

struct DeadFolder: Identifiable, Sendable {
    let id = UUID()
    let path: URL
    let size: Int64
    var isSelected: Bool = false
}

struct SimulatorStorageInfo: Identifiable, Sendable {
    let simulator: SimulatorDevice
    let totalSize: Int64
    let lastBootedAt: Date?
    let isRecommendedForCleanup: Bool

    var id: String { simulator.udid }
}

struct AppStorageInfo: Identifiable, Sendable {
    let id = UUID()
    let simulatorName: String
    let appName: String
    let bundleIdentifier: String
    let sandboxPath: URL
    let size: Int64
}

// MARK: - StorageService

/// 시뮬레이터 스토리지 분석 및 정리를 위한 서비스.
final class StorageService: @unchecked Sendable {

    private let fileManager = FileManager.default

    /// 미사용 판별 기준 (기본 30일)
    private let unusedThresholdDays: Int = 30

    // MARK: - 기본 경로

    private var coreSimulatorDevicesURL: URL {
        fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices")
    }

    private var coreSimulatorCachesURL: URL {
        fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Caches")
    }

    // MARK: - Dead Folder 스캔

    /// CoreSimulator/Caches 내의 불필요한 폴더를 스캔한다.
    /// 현재 등록된 시뮬레이터 UDID와 매칭되지 않는 폴더를 dead folder로 판별한다.
    func scanDeadFolders() async -> [DeadFolder] {
        let cachesURL = coreSimulatorCachesURL

        guard let cacheContents = try? fileManager.contentsOfDirectory(
            at: cachesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        // 현재 존재하는 시뮬레이터 디바이스 UDID 목록
        let existingUDIDs = getExistingDeviceUDIDs()

        var deadFolders: [DeadFolder] = []

        for folder in cacheContents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDir),
                  isDir.boolValue else {
                continue
            }

            let folderName = folder.lastPathComponent

            // UUID 형식의 폴더명이 현재 시뮬레이터에 없으면 dead folder
            if isUUIDFormat(folderName), !existingUDIDs.contains(folderName) {
                let size = calculateDirectorySize(at: folder)
                deadFolders.append(DeadFolder(path: folder, size: size))
            }
        }

        return deadFolders.sorted { $0.size > $1.size }
    }

    // MARK: - 시뮬레이터 스토리지

    /// simctl을 실행하여 전체 시뮬레이터의 스토리지 정보를 반환한다.
    @MainActor
    func getSimulatorStorageInfo() async -> [SimulatorStorageInfo] {
        let service = SimulatorService()
        await service.refreshSimulators()
        let all = service.bootedSimulators + service.shutdownSimulators
        return await getSimulatorStorageInfo(simulators: all)
    }

    /// 모든 시뮬레이터의 스토리지 정보를 반환한다.
    func getSimulatorStorageInfo(simulators: [SimulatorDevice]) async -> [SimulatorStorageInfo] {
        var infos: [SimulatorStorageInfo] = []

        for simulator in simulators {
            let deviceURL = URL(fileURLWithPath: simulator.dataPath)
            let totalSize = calculateDirectorySize(at: deviceURL)

            let isRecommended: Bool
            if let lastBooted = simulator.lastBootedAt {
                let daysSinceLastBoot = Calendar.current.dateComponents(
                    [.day], from: lastBooted, to: Date()
                ).day ?? 0
                isRecommended = daysSinceLastBoot >= unusedThresholdDays && !simulator.isBooted
            } else {
                // 한 번도 부팅되지 않은 시뮬레이터는 정리 추천
                isRecommended = !simulator.isBooted
            }

            let info = SimulatorStorageInfo(
                simulator: simulator,
                totalSize: totalSize,
                lastBootedAt: simulator.lastBootedAt,
                isRecommendedForCleanup: isRecommended
            )
            infos.append(info)
        }

        return infos.sorted { $0.totalSize > $1.totalSize }
    }

    // MARK: - 앱 스토리지

    /// 모든 시뮬레이터의 앱별 스토리지 정보를 반환한다.
    @MainActor
    func getAppStorageInfo() async -> [AppStorageInfo] {
        let simService = SimulatorService()
        await simService.refreshSimulators()
        let allSimulators = simService.bootedSimulators + simService.shutdownSimulators
        let sandboxService = SandboxService()
        var allInfos: [AppStorageInfo] = []
        for simulator in allSimulators {
            let apps = sandboxService.getInstalledApps(for: simulator)
            let infos = await getAppStorageInfo(for: simulator, apps: apps)
            allInfos.append(contentsOf: infos)
        }
        return allInfos.sorted { $0.size > $1.size }
    }

    /// 특정 시뮬레이터의 앱별 스토리지 정보를 반환한다.
    func getAppStorageInfo(
        for simulator: SimulatorDevice,
        apps: [SimulatorApp]
    ) async -> [AppStorageInfo] {
        var infos: [AppStorageInfo] = []

        for app in apps {
            guard !app.sandboxPath.isEmpty else { continue }

            let sandboxURL = URL(fileURLWithPath: app.sandboxPath)
            let size = calculateDirectorySize(at: sandboxURL)

            let info = AppStorageInfo(
                simulatorName: simulator.name,
                appName: app.displayName,
                bundleIdentifier: app.bundleIdentifier,
                sandboxPath: sandboxURL,
                size: size
            )
            infos.append(info)
        }

        return infos.sorted { $0.size > $1.size }
    }

    // MARK: - 디렉토리 크기 계산

    /// 디렉토리의 총 용량(바이트)을 재귀적으로 계산한다.
    func calculateDirectorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey]
            ),
                  resourceValues.isRegularFile == true,
                  let fileSize = resourceValues.fileSize
            else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    // MARK: - 삭제 (휴지통 이동)

    /// 파일/디렉토리를 휴지통으로 이동한다.
    func moveToTrash(at url: URL) throws {
        try fileManager.trashItem(at: url, resultingItemURL: nil)
    }

    // MARK: - Private Helpers

    /// 현재 CoreSimulator/Devices에 존재하는 UDID 목록을 반환한다.
    private func getExistingDeviceUDIDs() -> Set<String> {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: coreSimulatorDevicesURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return Set(contents.map(\.lastPathComponent).filter { isUUIDFormat($0) })
    }

    /// 문자열이 UUID 형식인지 검사한다.
    private func isUUIDFormat(_ string: String) -> Bool {
        UUID(uuidString: string) != nil
    }
}
