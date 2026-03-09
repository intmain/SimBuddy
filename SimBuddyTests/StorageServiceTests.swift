import XCTest
@testable import SimBuddy

final class StorageServiceTests: XCTestCase {

    // MARK: - Properties

    private var service: StorageService!
    private var tempDir: URL!
    private let fm = FileManager.default

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        service = StorageService()
        tempDir = fm.temporaryDirectory
            .appendingPathComponent("StorageServiceTests-\(UUID().uuidString)")
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

    /// 지정된 크기의 임시 파일을 생성한다.
    @discardableResult
    private func createFile(name: String, size: Int, in directory: URL? = nil) throws -> URL {
        let dir = directory ?? tempDir!
        let fileURL = dir.appendingPathComponent(name)
        let data = Data(repeating: 0x41, count: size)
        try data.write(to: fileURL)
        return fileURL
    }

    private func makeSimulator(
        udid: String = "TEST-0000-0000-0000-000000000000",
        name: String = "Test iPhone",
        state: String = "Shutdown",
        lastBootedAt: Date? = nil,
        dataPath: String? = nil
    ) -> SimulatorDevice {
        SimulatorDevice(
            udid: udid,
            name: name,
            state: state,
            deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2",
            lastBootedAt: lastBootedAt,
            dataPath: dataPath ?? tempDir.path
        )
    }

    // MARK: - calculateDirectorySize Tests

    func test_calculateDirectorySize_singleFile() throws {
        let fileSize = 1024
        try createFile(name: "test.bin", size: fileSize)

        let calculatedSize = service.calculateDirectorySize(at: tempDir)

        XCTAssertEqual(calculatedSize, Int64(fileSize), "단일 파일의 크기를 정확히 계산해야 한다")
    }

    func test_calculateDirectorySize_multipleFiles() throws {
        try createFile(name: "file1.bin", size: 512)
        try createFile(name: "file2.bin", size: 256)
        try createFile(name: "file3.bin", size: 128)

        let calculatedSize = service.calculateDirectorySize(at: tempDir)

        XCTAssertEqual(calculatedSize, 512 + 256 + 128, "여러 파일의 총 크기를 정확히 계산해야 한다")
    }

    func test_calculateDirectorySize_nestedDirectories() throws {
        let subDir = tempDir.appendingPathComponent("subdir")
        try fm.createDirectory(at: subDir, withIntermediateDirectories: true)

        try createFile(name: "root.bin", size: 100)
        try createFile(name: "nested.bin", size: 200, in: subDir)

        let calculatedSize = service.calculateDirectorySize(at: tempDir)

        XCTAssertEqual(calculatedSize, 300, "하위 디렉토리 포함 크기를 계산해야 한다")
    }

    func test_calculateDirectorySize_emptyDirectory() {
        let calculatedSize = service.calculateDirectorySize(at: tempDir)

        XCTAssertEqual(calculatedSize, 0, "빈 디렉토리의 크기는 0이어야 한다")
    }

    func test_calculateDirectorySize_nonexistentDirectory() {
        let nonexistent = tempDir.appendingPathComponent("does-not-exist")
        let calculatedSize = service.calculateDirectorySize(at: nonexistent)

        XCTAssertEqual(calculatedSize, 0, "존재하지 않는 디렉토리는 0을 반환해야 한다")
    }

    // MARK: - moveToTrash Tests

    func test_moveToTrash_fileDisappears() throws {
        let fileURL = try createFile(name: "to-trash.bin", size: 64)

        XCTAssertTrue(fm.fileExists(atPath: fileURL.path), "파일이 존재해야 한다")

        try service.moveToTrash(at: fileURL)

        XCTAssertFalse(fm.fileExists(atPath: fileURL.path), "휴지통으로 이동 후 원래 경로에 파일이 없어야 한다")
    }

    func test_moveToTrash_directoryDisappears() throws {
        let dirURL = tempDir.appendingPathComponent("folder-to-trash")
        try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
        try createFile(name: "inside.bin", size: 32, in: dirURL)

        try service.moveToTrash(at: dirURL)

        XCTAssertFalse(fm.fileExists(atPath: dirURL.path), "휴지통으로 이동 후 디렉토리가 없어야 한다")
    }

    func test_moveToTrash_nonexistentFile_throws() {
        let nonexistent = tempDir.appendingPathComponent("ghost.bin")

        XCTAssertThrowsError(try service.moveToTrash(at: nonexistent)) { error in
            // FileManager.trashItem은 존재하지 않는 파일에 대해 에러를 던져야 한다
            XCTAssertTrue(error is CocoaError || error is NSError)
        }
    }

    // MARK: - isRecommendedForCleanup Tests

    func test_isRecommendedForCleanup_oldShutdownSimulator() async {
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let simulator = makeSimulator(
            state: "Shutdown",
            lastBootedAt: oldDate
        )

        let infos = await service.getSimulatorStorageInfo(simulators: [simulator])

        XCTAssertEqual(infos.count, 1)
        XCTAssertTrue(
            infos.first?.isRecommendedForCleanup == true,
            "30일 이상 미사용 + Shutdown 상태는 정리 추천이어야 한다"
        )
    }

    func test_isRecommendedForCleanup_recentShutdownSimulator() async {
        let recentDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let simulator = makeSimulator(
            state: "Shutdown",
            lastBootedAt: recentDate
        )

        let infos = await service.getSimulatorStorageInfo(simulators: [simulator])

        XCTAssertEqual(infos.count, 1)
        XCTAssertFalse(
            infos.first?.isRecommendedForCleanup == true,
            "최근에 사용한 시뮬레이터는 정리 추천이 아니어야 한다"
        )
    }

    func test_isRecommendedForCleanup_bootedSimulator() async {
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let simulator = makeSimulator(
            state: "Booted",
            lastBootedAt: oldDate
        )

        let infos = await service.getSimulatorStorageInfo(simulators: [simulator])

        XCTAssertEqual(infos.count, 1)
        XCTAssertFalse(
            infos.first?.isRecommendedForCleanup == true,
            "Booted 상태는 오래되었더라도 정리 추천이 아니어야 한다"
        )
    }

    func test_isRecommendedForCleanup_neverBooted() async {
        let simulator = makeSimulator(
            state: "Shutdown",
            lastBootedAt: nil
        )

        let infos = await service.getSimulatorStorageInfo(simulators: [simulator])

        XCTAssertEqual(infos.count, 1)
        XCTAssertTrue(
            infos.first?.isRecommendedForCleanup == true,
            "한 번도 부팅되지 않은 Shutdown 시뮬레이터는 정리 추천이어야 한다"
        )
    }

    // MARK: - getSimulatorStorageInfo Tests

    func test_getSimulatorStorageInfo_calculatesSize() async throws {
        try createFile(name: "data.bin", size: 2048)

        let simulator = makeSimulator(dataPath: tempDir.path)
        let infos = await service.getSimulatorStorageInfo(simulators: [simulator])

        XCTAssertEqual(infos.count, 1)
        XCTAssertEqual(infos.first?.totalSize, 2048, "파일 크기가 정확히 반영되어야 한다")
        XCTAssertEqual(infos.first?.simulator.udid, simulator.udid)
    }

    // MARK: - getAppStorageInfo Tests

    func test_getAppStorageInfo_calculatesAppSize() async throws {
        let appSandboxDir = tempDir.appendingPathComponent("app-sandbox")
        try fm.createDirectory(at: appSandboxDir, withIntermediateDirectories: true)
        try createFile(name: "documents.db", size: 4096, in: appSandboxDir)

        let simulator = makeSimulator()
        let app = SimulatorApp(
            bundleIdentifier: "com.test.app",
            displayName: "Test App",
            sandboxPath: appSandboxDir.path,
            bundlePath: "/tmp/fake.app"
        )

        let infos = await service.getAppStorageInfo(for: simulator, apps: [app])

        XCTAssertEqual(infos.count, 1)
        XCTAssertEqual(infos.first?.size, 4096)
        XCTAssertEqual(infos.first?.appName, "Test App")
        XCTAssertEqual(infos.first?.bundleIdentifier, "com.test.app")
    }
}
