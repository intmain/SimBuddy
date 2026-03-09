import AppKit
import Foundation

// MARK: - SandboxService

/// 시뮬레이터의 앱 목록과 샌드박스 경로를 탐색하는 서비스.
final class SandboxService: @unchecked Sendable {

    private let fileManager = FileManager.default

    // MARK: - 시뮬레이터 기본 경로

    private var coreSimulatorDevicesURL: URL {
        fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices")
    }

    // MARK: - Public

    /// 특정 시뮬레이터에 설치된 앱 목록을 반환한다.
    func getInstalledApps(for simulator: SimulatorDevice) -> [SimulatorApp] {
        let deviceURL = URL(fileURLWithPath: simulator.dataPath)
        let bundleContainerURL = deviceURL
            .appendingPathComponent("Containers/Bundle/Application")
        let dataContainerURL = deviceURL
            .appendingPathComponent("Containers/Data/Application")

        // 1) Bundle 컨테이너에서 bundleID -> (displayName, bundlePath) 매핑 구축
        let bundleMap = buildBundleMap(from: bundleContainerURL)

        // 2) Data 컨테이너에서 bundleID -> sandboxPath 매핑 구축
        let dataMap = buildDataContainerMap(from: dataContainerURL)

        // 3) bundleID 기준으로 매칭
        var apps: [SimulatorApp] = []
        for (bundleID, bundleInfo) in bundleMap {
            let sandboxPath = dataMap[bundleID] ?? ""
            let app = SimulatorApp(
                bundleIdentifier: bundleID,
                displayName: bundleInfo.displayName,
                sandboxPath: sandboxPath,
                bundlePath: bundleInfo.bundlePath
            )
            apps.append(app)
        }

        return apps.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    /// Finder에서 경로를 선택하여 보여준다.
    @MainActor
    func openInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    /// 경로를 클립보드에 복사한다.
    @MainActor
    func copyToClipboard(path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }

    // MARK: - Private

    private struct BundleInfo {
        let displayName: String
        let bundlePath: String
    }

    /// Bundle/Application 디렉토리를 탐색하여 bundleID -> BundleInfo 딕셔너리를 구축한다.
    private func buildBundleMap(from bundleContainerURL: URL) -> [String: BundleInfo] {
        var map: [String: BundleInfo] = [:]

        guard let appUUIDDirs = try? fileManager.contentsOfDirectory(
            at: bundleContainerURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return map
        }

        for appUUIDDir in appUUIDDirs {
            // {AppUUID}/ 아래에 .app 디렉토리 찾기
            guard let contents = try? fileManager.contentsOfDirectory(
                at: appUUIDDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ) else {
                continue
            }

            guard let dotApp = contents.first(where: { $0.pathExtension == "app" }) else {
                continue
            }

            let infoPlistURL = dotApp.appendingPathComponent("Info.plist")
            guard let plistData = try? Data(contentsOf: infoPlistURL),
                  let plist = try? PropertyListSerialization.propertyList(
                      from: plistData, format: nil
                  ) as? [String: Any],
                  let bundleID = plist["CFBundleIdentifier"] as? String
            else {
                continue
            }

            let displayName = (plist["CFBundleDisplayName"] as? String)
                ?? (plist["CFBundleName"] as? String)
                ?? dotApp.deletingPathExtension().lastPathComponent

            map[bundleID] = BundleInfo(
                displayName: displayName,
                bundlePath: dotApp.path
            )
        }

        return map
    }

    /// Data/Application 디렉토리를 탐색하여 bundleID -> sandboxPath 딕셔너리를 구축한다.
    /// .com.apple.mobile_container_manager.metadata.plist의 MCMMetadataIdentifier로 번들 ID를 읽는다.
    private func buildDataContainerMap(from dataContainerURL: URL) -> [String: String] {
        var map: [String: String] = [:]

        guard let dataDirs = try? fileManager.contentsOfDirectory(
            at: dataContainerURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return map
        }

        for dataDir in dataDirs {
            let metadataPlistURL = dataDir
                .appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")

            guard let plistData = try? Data(contentsOf: metadataPlistURL),
                  let plist = try? PropertyListSerialization.propertyList(
                      from: plistData, format: nil
                  ) as? [String: Any],
                  let bundleID = plist["MCMMetadataIdentifier"] as? String
            else {
                continue
            }

            map[bundleID] = dataDir.path
        }

        return map
    }
}
