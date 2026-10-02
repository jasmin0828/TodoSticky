import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginController {
    enum Status: Equatable, Sendable {
        case notRegistered
        case enabled
        case requiresApproval
        case notFound
        case unknown

        init(_ serviceStatus: SMAppService.Status) {
            switch serviceStatus {
            case .notRegistered:
                self = .notRegistered
            case .enabled:
                self = .enabled
            case .requiresApproval:
                self = .requiresApproval
            case .notFound:
                self = .notFound
            @unknown default:
                self = .unknown
            }
        }
    }

    enum Feedback: Equatable, Sendable {
        case approvalRequired
        case unavailable
        case updateFailed

        var localizationKey: String {
            switch self {
            case .approvalRequired:
                "settings.loginItem.approvalRequired"
            case .unavailable:
                "settings.loginItem.unavailable"
            case .updateFailed:
                "settings.loginItem.updateFailed"
            }
        }
    }

    @MainActor
    protocol Service {
        var status: SMAppService.Status { get }
        func register() throws
        func unregister() throws
    }

    @MainActor
    final class SystemService: Service {
        private let service: SMAppService

        init(service: SMAppService = .mainApp) {
            self.service = service
        }

        var status: SMAppService.Status {
            service.status
        }

        func register() throws {
            try service.register()
        }

        func unregister() throws {
            try service.unregister()
        }
    }

    @ObservationIgnored private let service: any Service

    private(set) var status: Status = .notFound
    private(set) var feedback: Feedback?

    var isEnabled: Bool {
        get { status == .enabled }
        set { updateRegistration(enabled: newValue) }
    }

    var isToggleDisabled: Bool {
        status == .unknown
    }

    init(service: any Service = SystemService()) {
        self.service = service
        refresh()
    }

    func refresh() {
        status = Status(service.status)
        feedback = feedback(for: status)
    }

    private func updateRegistration(enabled: Bool) {
        if enabled {
            guard status != .enabled else {
                refresh()
                return
            }

            guard status != .requiresApproval else {
                refresh()
                feedback = .approvalRequired
                return
            }

            guard status != .unknown else {
                refresh()
                feedback = .unavailable
                return
            }

            do {
                try service.register()
            } catch {
                refresh()
                feedback = .updateFailed
                return
            }

            refresh()
            if status != .enabled {
                feedback = feedback(for: status) ?? .updateFailed
            }
        } else {
            guard status != .notRegistered else {
                refresh()
                return
            }

            guard status != .notFound, status != .unknown else {
                refresh()
                return
            }

            do {
                try service.unregister()
            } catch {
                refresh()
                feedback = .updateFailed
                return
            }

            refresh()
            if status != .notRegistered {
                feedback = feedback(for: status) ?? .updateFailed
            }
        }
    }

    private func feedback(for status: Status) -> Feedback? {
        switch status {
        case .requiresApproval:
            .approvalRequired
        case .notFound:
            nil
        case .notRegistered, .enabled:
            nil
        case .unknown:
            .unavailable
        }
    }
}
