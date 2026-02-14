import Foundation
import Combine

enum AppEvent: Sendable {
    // Lifecycle events
    case appLaunched
    case appTimedOut

    // Data events
    case attributionReceived(payload: [String: String])
    case deeplinkReceived(payload: [String: String])

    // Network events
    case connectionRestored
    case connectionLost

    // Validation events
    case validationTriggered
    case validationSucceeded
    case validationFailed(reason: String)

    // Attribution fetch events
    case attributionFetchTriggered
    case attributionFetchSucceeded(payload: [String: String])
    case attributionFetchFailed

    // Destination events
    case destinationFetchTriggered
    case destinationFetchSucceeded(url: String)
    case destinationFetchFailed

    // Permission events
    case permissionDialogRequested
    case permissionGranted
    case permissionDenied
    case permissionDeferred

    // Navigation events
    case navigateToHome
    case navigateToDestination
}

@MainActor
final class EventBus: ObservableObject {

    private let pipe = PassthroughSubject<AppEvent, Never>()

    var stream: AnyPublisher<AppEvent, Never> {
        pipe.eraseToAnyPublisher()
    }

    func publish(_ event: AppEvent) {
        pipe.send(event)
    }

    func on<T>(_ eventType: T.Type, handler: @escaping (AppEvent) -> Void) -> AnyCancellable {
        pipe
            .receive(on: RunLoop.main)
            .sink { event in
                handler(event)
            }
    }
}

extension EventBus {
    func subscribe(_ handler: @escaping (AppEvent) -> Void) -> AnyCancellable {
        pipe
            .receive(on: RunLoop.main)
            .sink(receiveValue: handler)
    }
}
