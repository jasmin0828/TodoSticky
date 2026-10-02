import ServiceManagement
import XCTest
@testable import TodoSticky

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    func testInitialEnabledStatusMapsToOn() {
        let service = FakeService(status: .enabled)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertEqual(controller.status, .enabled)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertNil(controller.feedback)
    }

    func testInitialNotRegisteredStatusMapsToOff() {
        let service = FakeService(status: .notRegistered)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertEqual(controller.status, .notRegistered)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertNil(controller.feedback)
    }

    func testRegisterSuccessUsesRefreshedEnabledStatus() {
        let service = FakeService(status: .notRegistered)
        let controller = LaunchAtLoginController(service: service)

        controller.isEnabled = true

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertNil(controller.feedback)
    }

    func testNotFoundInitialStateIsInteractiveAndAttemptsRegister() {
        let service = FakeService(status: .notFound)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertEqual(controller.status, .notFound)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(controller.isToggleDisabled)
        XCTAssertNil(controller.feedback)

        controller.isEnabled = true

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertNil(controller.feedback)
    }

    func testNotFoundRegisterCanReachApprovalRequired() {
        let service = FakeService(
            status: .notFound,
            registerResultStatus: .requiresApproval
        )
        let controller = LaunchAtLoginController(service: service)

        controller.isEnabled = true

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(controller.status, .requiresApproval)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.feedback, .approvalRequired)
    }

    func testRegisterErrorPreservesActualStatusAndSurfacesFeedback() {
        let service = FakeService(status: .notRegistered, registerError: TestError.operationFailed)
        let controller = LaunchAtLoginController(service: service)

        controller.isEnabled = true

        XCTAssertEqual(controller.status, .notRegistered)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.feedback, .updateFailed)
    }

    func testUnregisterSuccessUsesRefreshedNotRegisteredStatus() {
        let service = FakeService(status: .enabled)
        let controller = LaunchAtLoginController(service: service)

        controller.isEnabled = false

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(controller.status, .notRegistered)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertNil(controller.feedback)
    }

    func testUnregisterErrorPreservesActualStatusAndSurfacesFeedback() {
        let service = FakeService(status: .enabled, unregisterError: TestError.operationFailed)
        let controller = LaunchAtLoginController(service: service)

        controller.isEnabled = false

        XCTAssertEqual(controller.status, .enabled)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertEqual(controller.feedback, .updateFailed)
    }

    func testApprovalRequiredIsNotReportedAsEnabled() {
        let service = FakeService(status: .requiresApproval)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertEqual(controller.status, .requiresApproval)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.feedback, .approvalRequired)
    }

    func testNotFoundRegisterErrorPreservesActualStatusAndSurfacesFeedback() {
        let service = FakeService(status: .notFound, registerError: TestError.operationFailed)
        let controller = LaunchAtLoginController(service: service)

        controller.isEnabled = true

        XCTAssertEqual(controller.status, .notFound)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(controller.isToggleDisabled)
        XCTAssertEqual(controller.feedback, .updateFailed)
    }

    private final class FakeService: LaunchAtLoginController.Service {
        var status: SMAppService.Status
        var registerError: Error?
        var unregisterError: Error?
        var registerResultStatus: SMAppService.Status
        var registerCallCount = 0
        var unregisterCallCount = 0

        init(
            status: SMAppService.Status,
            registerError: Error? = nil,
            unregisterError: Error? = nil,
            registerResultStatus: SMAppService.Status = .enabled
        ) {
            self.status = status
            self.registerError = registerError
            self.unregisterError = unregisterError
            self.registerResultStatus = registerResultStatus
        }

        func register() throws {
            registerCallCount += 1
            if let registerError {
                throw registerError
            }
            status = registerResultStatus
        }

        func unregister() throws {
            unregisterCallCount += 1
            if let unregisterError {
                throw unregisterError
            }
            status = .notRegistered
        }
    }
}

private enum TestError: Error {
    case operationFailed
}
