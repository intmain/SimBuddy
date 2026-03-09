import XCTest
@testable import SimBuddy

final class SandboxServiceTests: XCTestCase {

    // MARK: - Properties

    private var service: SandboxService!
    private var tempDir: URL!
    private let fm = FileManager.default

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        service = SandboxService()
        tempDir = fm.temporaryDirectory
            .appendingPathComponent("SandboxServiceTests-\(UUID().uuidString)")
        try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir, fm.fileExists(atPath: tempDir.path) {
            try? fm.removeItem(at: tempDir)
        }
        service = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// 테스트용 SimulatorDevice를 생성한다. dataPath는 tempDir의 부모로 설정.
    /// SandboxService는 dataPath + "/data/Containers/..." 경로를 탐색한다.
    private func makeSimulator(dataPath: String? = nil) -> SimulatorDevice {
        SimulatorDevice(
            udid: "TEST-UDID-0000-0000-000000000000",
            name: "Test iPhone",
            state: "Booted",
            deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2",
            lastBootedAt: nil,
            dataPath: dataPath ?? tempDir.path
        )
    }

    /// 가짜 앱 번들 구조를 생성한다.
    /// Returns: (bundleContainerUUID, dataContainerUUID)
    @discardableResult
    private func createFakeApp(
        bundleIdentifier: String = "com.test.app",
        displayName: String = "TestApp",
        appName: String = "TestApp.app",
        includeInfoPlist: Bool = true,
        includeMetadataPlist: Bool = true
    ) throws -> (String, String) {
        let bundleUUID = UUID().uuidString
        let dataUUID = UUID().uuidString

        // Bundle 컨테이너: data/Containers/Bundle/Application/{UUID}/{AppName}.app/Info.plist
        let bundleContainerDir = tempDir
            .appendingPathComponent("data/Containers/Bundle/Application")
            .appendingPathComponent(bundleUUID)
        let appBundleDir = bundleContainerDir.appendingPathComponent(appName)
        try fm.createDirectory(at: appBundleDir, withIntermediateDirectories: true)

        if includeInfoPlist {
            let infoPlist: [String: Any] = [
                "CFBundleIdentifier": bundleIdentifier,
                "CFBundleDisplayName": displayName,
            ]
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: infoPlist, format: .xml, options: 0
            )
            try plistData.write(to: appBundleDir.appendingPathComponent("Info.plist"))
        }

        // Data 컨테이너: data/Containers/Data/Application/{UUID}/.com.apple.mobile_container_manager.metadata.plist
        let dataContainerDir = tempDir
            .appendingPathComponent("data/Containers/Data/Application")
            .appendingPathComponent(dataUUID)
        try fm.createDirectory(at: dataContainerDir, withIntermediateDirectories: true)

        if includeMetadataPlist {
            let metadataPlist: [String: Any] = [
                "MCMMetadataIdentifier": bundleIdentifier
            ]
            let metadataData = try PropertyListSerialization.data(
                fromPropertyList: metadataPlist, format: .xml, options: 0
            )
            try metadataData.write(
                to: dataContainerDir.appendingPathComponent(
                    ".com.apple.mobile_container_manager.metadata.plist"
                )
            )
        }

        return (bundleUUID, dataUUID)
    }

    // MARK: - Tests

    func test_getInstalledApps_returnsApps() throws {
        try createFakeApp(
            bundleIdentifier: "com.example.myapp",
            displayName: "My App",
            appName: "MyApp.app"
        )

        let simulator = makeSimulator()
        let apps = service.getInstalledApps(for: simulator)

        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.bundleIdentifier, "com.example.myapp")
        XCTAssertEqual(apps.first?.displayName, "My App")
        XCTAssertFalse(apps.first?.bundlePath.isEmpty ?? true, "bundlePath가 비어있지 않아야 한다")
        XCTAssertFalse(apps.first?.sandboxPath.isEmpty ?? true, "sandboxPath가 비어있지 않아야 한다")
    }

    func test_getInstalledApps_multipleApps() throws {
        try createFakeApp(
            bundleIdentifier: "com.example.alpha",
            displayName: "Alpha",
            appName: "Alpha.app"
        )
        try createFakeApp(
            bundleIdentifier: "com.example.beta",
            displayName: "Beta",
            appName: "Beta.app"
        )

        let simulator = makeSimulator()
        let apps = service.getInstalledApps(for: simulator)

        XCTAssertEqual(apps.count, 2)

        // 이름 순 정렬 확인
        XCTAssertEqual(apps[0].displayName, "Alpha")
        XCTAssertEqual(apps[1].displayName, "Beta")
    }

    func test_getInstalledApps_emptySimulator() {
        // 컨테이너 디렉토리가 없는 시뮬레이터
        let simulator = makeSimulator()
        let apps = service.getInstalledApps(for: simulator)

        XCTAssertTrue(apps.isEmpty, "앱이 없는 시뮬레이터는 빈 배열을 반환해야 한다")
    }

    func test_getInstalledApps_missingInfoPlist() throws {
        // Info.plist 없이 .app 번들만 생성
        try createFakeApp(
            bundleIdentifier: "com.example.noplist",
            displayName: "NoPlist",
            appName: "NoPlist.app",
            includeInfoPlist: false
        )

        let simulator = makeSimulator()
        let apps = service.getInstalledApps(for: simulator)

        // Info.plist가 없으면 해당 앱을 스킵해야 한다
        XCTAssertTrue(apps.isEmpty, "Info.plist 없는 앱은 결과에 포함되지 않아야 한다")
    }

    @MainActor
    func test_copyToClipboard() {
        let testPath = "/Users/test/some/path"
        service.copyToClipboard(path: testPath)

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, testPath, "클립보드에 복사된 경로가 일치해야 한다")
    }
}
