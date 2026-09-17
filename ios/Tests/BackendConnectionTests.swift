import XCTest
@testable import AIDetector

final class BackendConnectionTests: XCTestCase {
    func testAWSConnectionFromInstalledApp() async throws {
        let previous = AppConfig.backendBaseURL
        defer { AppConfig.backendBaseURL = previous }
        AppConfig.backendBaseURL = URL(string: "https://kukjinman.com/aidetector/")!
        XCTAssertEqual(AppConfig.backendBaseURL.appendingPathComponent("v1/config").path, "/aidetector/v1/config")
        let report = try await AIDetectorAPI.checkConnection()
        XCTAssertEqual(report.healthStatus, 200)
        XCTAssertTrue([200, 404].contains(report.configurationStatus))
        print("AWS_APP_CONNECTION health=\(report.healthStatus) config=\(report.configurationStatus) message=\(report.message)")
        // This test checks transport and detects a legacy backend. It does not prove feature readiness.
    }
}
