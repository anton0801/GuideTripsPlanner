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

    // UNIQUE: Event subject
    private let pipe = PassthroughSubject<AppEvent, Never>()

    // UNIQUE: Event stream for handlers
    var stream: AnyPublisher<AppEvent, Never> {
        pipe.eraseToAnyPublisher()
    }

    // UNIQUE: Publish event
    func publish(_ event: AppEvent) {
        print("📡 [Event] \(event)")
        pipe.send(event)
    }

    // UNIQUE: Subscribe to specific event types
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
