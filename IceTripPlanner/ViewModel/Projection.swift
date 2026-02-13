import Foundation
import Combine

@MainActor
final class Projection: ObservableObject {

    // MARK: - Published state (derived from events)
    @Published private(set) var stage: Stage = .idle
    @Published private(set) var destination: String?
    @Published private(set) var locked: Bool = false

    // UNIQUE: UI flags derived from events
    @Published var showPermissionSheet: Bool = false
    @Published var showNoConnectionView: Bool = false
    @Published var goToHome: Bool = false
    @Published var goToDestination: Bool = false

    enum Stage {
        case idle
        case launching
        case validating
        case validated
        case ready(String)
        case suspended
        case noConnection
    }

    // MARK: - Internal data
    private(set) var attribution: [String: String] = [:]
    private(set) var deeplink: [String: String] = [:]
    private(set) var config: Config = .initial

    struct Config {
        var savedURL: String?
        var mode: String?
        var isNewInstall: Bool

        static var initial: Config {
            Config(savedURL: nil, mode: nil, isNewInstall: true)
        }
    }

    private(set) var permission: Permission = .initial

    struct Permission {
        var given: Bool
        var blocked: Bool
        var lastAsked: Date?

        var eligible: Bool {
            guard !given && !blocked else { return false }
            if let date = lastAsked {
                return Date().timeIntervalSince(date) / 86400 >= 3
            }
            return true
        }

        static var initial: Permission {
            Permission(given: false, blocked: false, lastAsked: nil)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Apply event (projection logic)
    func apply(event: AppEvent) {
        switch event {
        case .appLaunched:
            stage = .launching

        case .appTimedOut:
            if !locked {
                stage = .suspended
                goToHome = true
            }

        case .attributionReceived(let payload):
            attribution = payload

        case .deeplinkReceived(let payload):
            deeplink = payload

        case .connectionLost:
            if !locked {
                stage = .noConnection
                showNoConnectionView = true
            }

        case .connectionRestored:
            if !locked, case .noConnection = stage {
                stage = .suspended
                showNoConnectionView = false
            }

        case .validationTriggered:
            stage = .validating

        case .validationSucceeded:
            stage = .validated

        case .validationFailed:
            stage = .suspended
            goToHome = true

        case .attributionFetchSucceeded(let payload):
            attribution = payload

        case .attributionFetchFailed:
            stage = .suspended
            goToHome = true

        case .destinationFetchSucceeded(let url):
            destination = url
            config.savedURL = url
            config.mode = "Active"
            config.isNewInstall = false
            stage = .ready(url)
            locked = true

            if permission.eligible {
                showPermissionSheet = true
            } else {
                goToDestination = true
            }

        case .destinationFetchFailed:
            if let saved = config.savedURL {
                destination = saved
                stage = .ready(saved)
                locked = true

                if permission.eligible {
                    showPermissionSheet = true
                } else {
                    goToDestination = true
                }
            } else {
                stage = .suspended
                goToHome = true
            }

        case .permissionGranted:
            permission.given = true
            permission.lastAsked = Date()
            showPermissionSheet = false
            goToDestination = true

        case .permissionDenied:
            permission.blocked = true
            permission.lastAsked = Date()
            showPermissionSheet = false
            goToDestination = true

        case .permissionDeferred:
            permission.lastAsked = Date()
            showPermissionSheet = false

        case .navigateToHome:
            goToHome = true

        case .navigateToDestination:
            goToDestination = true

        default:
            break
        }
    }

    // MARK: - Subscribe to EventBus
    func connect(to bus: EventBus) {
        bus.subscribe { [weak self] event in
            self?.apply(event: event)
        }
        .store(in: &cancellables)
    }

    // MARK: - Seed from persistence
    func seed(from data: PersistedData) {
        config.savedURL = data.url
        config.mode = data.mode
        config.isNewInstall = data.isNewInstall
        attribution = data.attribution
        deeplink = data.deeplink
        permission = Permission(
            given: data.permGiven,
            blocked: data.permBlocked,
            lastAsked: data.permDate
        )
    }
}

struct PersistedData {
    var url: String?
    var mode: String?
    var isNewInstall: Bool
    var attribution: [String: String]
    var deeplink: [String: String]
    var permGiven: Bool
    var permBlocked: Bool
    var permDate: Date?
}
