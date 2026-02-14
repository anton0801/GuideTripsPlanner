import Foundation
import Combine

@MainActor
final class EventEngine: ObservableObject {

    // MARK: - Core
    var bus: EventBus
    var projection: Projection
    
    @Published var goToHome: Bool = false
    @Published var goToDestination: Bool = false
    @Published var showPermissionSheet: Bool = false
    @Published var showNoConnectionView: Bool = false

    // MARK: - Handlers
    private let launchHandler: LaunchHandler
    private let validationHandler: ValidationHandler
    private let flowHandler: FlowHandler
    private let permissionHandler: PermissionHandler
    private let persistenceHandler: PersistenceHandler
    private let networkHandler: NetworkHandler

    private var cancellables = Set<AnyCancellable>()

    init() {
        let repo = DataRepository()
        let bus  = EventBus()
        let proj = Projection()

        self.bus        = bus
        self.projection = proj

        let launch = LaunchHandler(bus: bus)
        self.launchHandler      = launch
        self.validationHandler  = ValidationHandler(bus: bus, repo: repo)
        self.flowHandler        = FlowHandler(bus: bus, repo: repo, launchHandler: launch)
        self.permissionHandler  = PermissionHandler(bus: bus, repo: repo)
        self.persistenceHandler = PersistenceHandler(repo: repo)
        self.networkHandler     = NetworkHandler(bus: bus)

        // Connect projection to bus
        proj.connect(to: bus)

        // Seed projection from disk
        let persisted = repo.load()
        proj.seed(from: persisted)

        // Wire handlers to bus
        wireHandlers()
        
        setupProjectionSync()
    }
    
    private func setupProjectionSync() {
        // Синхронизируем изменения из projection в engine
        projection.objectWillChange.sink { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.goToHome = self.projection.goToHome
                self.goToDestination = self.projection.goToDestination
                self.showPermissionSheet = self.projection.showPermissionSheet
                self.showNoConnectionView = self.projection.showNoConnectionView
            }
        }
        .store(in: &cancellables)
    }

    func emit(_ event: AppEvent) {
        bus.publish(event)
    }

    func requestPermission() {
        permissionHandler.requestPermission()
    }

    private func wireHandlers() {
        bus.subscribe { [weak self] event in
            guard let self = self else { return }

            // Each handler reacts to events independently
            self.launchHandler.handle(event)
            self.validationHandler.handle(event, projection: self.projection)
            self.flowHandler.handle(event, projection: self.projection)
            self.permissionHandler.handle(event, projection: self.projection)
            self.persistenceHandler.handle(event)
        }
        .store(in: &cancellables)
    }
}
