import XCTest
@testable import SimBuddy

@MainActor
final class SimulatorServiceTests: XCTestCase {

    // MARK: - Fixtures

    /// 유효한 simctl JSON 응답 (Booted 1개 + Shutdown 1개)
    private let validJSON = """
    {
      "devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-18-2": [
          {
            "udid": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "name": "iPhone 16 Pro",
            "state": "Booted",
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
            "dataPath": "/Users/test/Library/Developer/CoreSimulator/Devices/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE/data",
            "lastBootedAt": "2026-03-01T10:00:00Z",
            "isAvailable": true
          },
          {
            "udid": "11111111-2222-3333-4444-555555555555",
            "name": "iPhone 16",
            "state": "Shutdown",
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
            "dataPath": "/Users/test/Library/Developer/CoreSimulator/Devices/11111111-2222-3333-4444-555555555555/data",
            "lastBootedAt": null,
            "isAvailable": true
          }
        ]
      }
    }
    """.data(using: .utf8)!

    private let emptyDevicesJSON = """
    {
      "devices": {}
    }
    """.data(using: .utf8)!

    private let mixedStatesJSON = """
    {
      "devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-18-2": [
          {
            "udid": "AAAA0001-0000-0000-0000-000000000001",
            "name": "iPhone 16 Pro",
            "state": "Booted",
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
            "dataPath": "/tmp/dev1",
            "lastBootedAt": "2026-03-01T10:00:00Z",
            "isAvailable": true
          },
          {
            "udid": "AAAA0001-0000-0000-0000-000000000002",
            "name": "iPhone 16",
            "state": "Shutdown",
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
            "dataPath": "/tmp/dev2",
            "lastBootedAt": null,
            "isAvailable": true
          },
          {
            "udid": "AAAA0001-0000-0000-0000-000000000003",
            "name": "iPad Pro",
            "state": "Booted",
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro",
            "dataPath": "/tmp/dev3",
            "lastBootedAt": "2026-03-01T09:00:00Z",
            "isAvailable": true
          }
        ]
      }
    }
    """.data(using: .utf8)!

    private let unavailableDevicesJSON = """
    {
      "devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-18-2": [
          {
            "udid": "AAAA0002-0000-0000-0000-000000000001",
            "name": "iPhone 16 Pro",
            "state": "Shutdown",
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
            "dataPath": "/tmp/dev1",
            "lastBootedAt": null,
            "isAvailable": false
          },
          {
            "udid": "AAAA0002-0000-0000-0000-000000000002",
            "name": "iPhone 16",
            "state": "Booted",
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
            "dataPath": "/tmp/dev2",
            "lastBootedAt": "2026-03-01T10:00:00Z",
            "isAvailable": true
          },
          {
            "udid": "AAAA0002-0000-0000-0000-000000000003",
            "name": "iPad Air",
            "state": "Shutdown",
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Air",
            "dataPath": "/tmp/dev3",
            "lastBootedAt": null,
            "isAvailable": false
          }
        ]
      }
    }
    """.data(using: .utf8)!

    // MARK: - SUT

    /// SimulatorService는 @MainActor이지만 parseSimulators는 nonisolated이므로 직접 호출 가능
    private let service = SimulatorService()

    // MARK: - Tests

    func test_parseSimulators_validJSON() {
        let simulators = service.parseSimulators(from: validJSON)

        XCTAssertEqual(simulators.count, 2)

        let booted = simulators.first { $0.udid == "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" }
        XCTAssertNotNil(booted)
        XCTAssertEqual(booted?.name, "iPhone 16 Pro")
        XCTAssertEqual(booted?.state, "Booted")
        XCTAssertTrue(booted?.isBooted == true)
        XCTAssertEqual(booted?.runtimeIdentifier, "com.apple.CoreSimulator.SimRuntime.iOS-18-2")
        XCTAssertNotNil(booted?.lastBootedAt)

        let shutdown = simulators.first { $0.udid == "11111111-2222-3333-4444-555555555555" }
        XCTAssertNotNil(shutdown)
        XCTAssertEqual(shutdown?.name, "iPhone 16")
        XCTAssertEqual(shutdown?.state, "Shutdown")
        XCTAssertFalse(shutdown?.isBooted == true)
        XCTAssertNil(shutdown?.lastBootedAt)
    }

    func test_parseSimulators_emptyDevices() {
        let simulators = service.parseSimulators(from: emptyDevicesJSON)

        XCTAssertTrue(simulators.isEmpty)
    }

    func test_parseSimulators_mixedStates() {
        let simulators = service.parseSimulators(from: mixedStatesJSON)

        let booted = simulators.filter { $0.isBooted }
        let shutdown = simulators.filter { !$0.isBooted }

        XCTAssertEqual(booted.count, 2)
        XCTAssertEqual(shutdown.count, 1)
        XCTAssertEqual(shutdown.first?.name, "iPhone 16")
    }

    func test_parseSimulators_invalidJSON() {
        let invalidData = "this is not json".data(using: .utf8)!
        let simulators = service.parseSimulators(from: invalidData)

        XCTAssertTrue(simulators.isEmpty, "잘못된 JSON은 빈 배열을 반환해야 한다")
    }

    func test_runtimeVersion_parsing() {
        let simulators = service.parseSimulators(from: validJSON)
        let device = simulators.first { $0.udid == "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" }

        XCTAssertNotNil(device)
        XCTAssertEqual(device?.runtimeVersion, "iOS 18.2")
    }

    func test_runtimeVersion_parsing_xrOS() {
        let xrOSJSON = """
        {
          "devices": {
            "com.apple.CoreSimulator.SimRuntime.xrOS-2-0": [
              {
                "udid": "AAAA0003-0000-0000-0000-000000000001",
                "name": "Apple Vision Pro",
                "state": "Shutdown",
                "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro",
                "dataPath": "/tmp/xros",
                "lastBootedAt": null,
                "isAvailable": true
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let simulators = service.parseSimulators(from: xrOSJSON)

        XCTAssertEqual(simulators.count, 1)
        XCTAssertEqual(simulators.first?.runtimeVersion, "xrOS 2.0")
    }

    func test_filterUnavailableDevices() {
        let simulators = service.parseSimulators(from: unavailableDevicesJSON)

        // isAvailable == false인 디바이스 2개가 필터링되어 1개만 남아야 한다
        XCTAssertEqual(simulators.count, 1)
        XCTAssertEqual(simulators.first?.udid, "AAAA0002-0000-0000-0000-000000000002")
        XCTAssertEqual(simulators.first?.name, "iPhone 16")
    }
}
