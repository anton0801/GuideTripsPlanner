import Foundation
import UIKit
import UserNotifications
import Network
import AppsFlyerLib
import FirebaseDatabase
import FirebaseCore
import FirebaseMessaging
import WebKit

@MainActor
final class LaunchHandler {

    private weak var bus: EventBus?
    private var timeoutTask: Task<Void, Never>?

    init(bus: EventBus) {
        self.bus = bus
    }

    func handle(_ event: AppEvent) {
        switch event {
        case .appLaunched:
            scheduleTimeout()
        default:
            break
        }
    }

    private func scheduleTimeout() {
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            await bus?.publish(.appTimedOut)
        }
    }

    func cancelTimeout() {
        timeoutTask?.cancel()
    }
}

@MainActor
final class ValidationHandler {

    private weak var bus: EventBus?
    private let repo: Repository

    init(bus: EventBus, repo: Repository) {
        self.bus = bus
        self.repo = repo
    }

    func handle(_ event: AppEvent, projection: Projection) {
        switch event {
        case .attributionReceived:
            Task { await performValidation() }
        default:
            break
        }
    }

    private func performValidation() async {
        await bus?.publish(.validationTriggered)

        do {
            let ok = try await repo.checkFirebase()
            if ok {
                await bus?.publish(.validationSucceeded)
            } else {
                await bus?.publish(.validationFailed(reason: "firebase_check_failed"))
            }
        } catch {
            await bus?.publish(.validationFailed(reason: error.localizedDescription))
        }
    }
}

@MainActor
final class FlowHandler {

    private weak var bus: EventBus?
    private let repo: Repository
    private weak var launchHandler: LaunchHandler?

    init(bus: EventBus, repo: Repository, launchHandler: LaunchHandler) {
        self.bus = bus
        self.repo = repo
        self.launchHandler = launchHandler
    }

    func handle(_ event: AppEvent, projection: Projection) {
        switch event {
        case .validationSucceeded:
            Task { await runFlow(projection: projection) }
        case .attributionFetchSucceeded:
            Task { await fetchDestination(projection: projection) }
        default:
            break
        }
    }

    private func runFlow(projection: Projection) async {
        guard !projection.attribution.isEmpty else {
            if let saved = projection.config.savedURL {
                launchHandler?.cancelTimeout()
                await bus?.publish(.destinationFetchSucceeded(url: saved))
            } else {
                await bus?.publish(.navigateToHome)
            }
            return
        }

        if let temp = UserDefaults.standard.string(forKey: "temp_url") {
            launchHandler?.cancelTimeout()
            await bus?.publish(.destinationFetchSucceeded(url: temp))
            return
        }

        let isOrganic = projection.attribution["af_status"] == "Organic"
        if projection.config.isNewInstall && isOrganic {
            await bus?.publish(.attributionFetchTriggered)
            await fetchAttribution(projection: projection)
            return
        }

        await fetchDestination(projection: projection)
    }

    private func fetchAttribution(projection: Projection) async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)

        do {
            let deviceID = AppsFlyerLib.shared().getAppsFlyerUID()
            var fetched = try await repo.pullAttribution(deviceID: deviceID)

            for (key, value) in projection.deeplink {
                if fetched[key] == nil { fetched[key] = value }
            }

            await bus?.publish(.attributionFetchSucceeded(payload: fetched))
        } catch {
            await bus?.publish(.attributionFetchFailed)
        }
    }

    private func fetchDestination(projection: Projection) async {
        await bus?.publish(.destinationFetchTriggered)

        do {
            let anyDict: [String: Any] = projection.attribution.mapValues { $0 as Any }
            let url = try await repo.pullDestination(attribution: anyDict)
            launchHandler?.cancelTimeout()
            await bus?.publish(.destinationFetchSucceeded(url: url))
        } catch {
            await bus?.publish(.destinationFetchFailed)
        }
    }
}

@MainActor
final class PermissionHandler {

    private weak var bus: EventBus?
    private let repo: Repository

    init(bus: EventBus, repo: Repository) {
        self.bus = bus
        self.repo = repo
    }

    func handle(_ event: AppEvent, projection: Projection) {
        switch event {
        case .permissionGranted:
            repo.savePermission(given: true, blocked: false)
            UIApplication.shared.registerForRemoteNotifications()
        case .permissionDenied:
            repo.savePermission(given: false, blocked: true)
        case .permissionDeferred:
            repo.savePermission(given: false, blocked: false)
        default:
            break
        }
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { [weak self] granted, _ in
            Task { @MainActor [weak self] in
                if granted {
                    self?.bus?.publish(.permissionGranted)
                } else {
                    self?.bus?.publish(.permissionDenied)
                }
            }
        }
    }
}

@MainActor
final class PersistenceHandler {

    private let repo: Repository

    init(repo: Repository) {
        self.repo = repo
    }

    func handle(_ event: AppEvent) {
        switch event {
        case .attributionReceived(let payload):
            repo.saveAttribution(payload)
        case .deeplinkReceived(let payload):
            repo.saveDeeplink(payload)
        case .attributionFetchSucceeded(let payload):
            repo.saveAttribution(payload)
        case .destinationFetchSucceeded(let url):
            repo.saveURL(url)
            repo.saveMode("Active")
            repo.markInstalled()
        default:
            break
        }
    }
}

@MainActor
final class NetworkHandler {

    private weak var bus: EventBus?
    private let monitor = NWPathMonitor()

    init(bus: EventBus) {
        self.bus = bus
        start()
    }

    private func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                if path.status == .satisfied {
                    self?.bus?.publish(.connectionRestored)
                } else {
                    self?.bus?.publish(.connectionLost)
                }
            }
        }
        monitor.start(queue: .global(qos: .background))
    }
}

protocol Repository {
    func checkFirebase() async throws -> Bool
    func pullAttribution(deviceID: String) async throws -> [String: String]
    func pullDestination(attribution: [String: Any]) async throws -> String
    func saveAttribution(_ data: [String: String])
    func saveDeeplink(_ data: [String: String])
    func saveURL(_ url: String)
    func saveMode(_ mode: String)
    func markInstalled()
    func savePermission(given: Bool, blocked: Bool)
    func load() -> PersistedData
}

final class DataRepository: Repository {

    private let vault = UserDefaults(suiteName: "group.guide.cache")!
    private let backup = UserDefaults.standard
    private var hot: [String: Any] = [:]

    // UNIQUE: gt_ prefix
    private enum K {
        static let attribution = "gt_attribution_data"
        static let deeplink    = "gt_deeplink_data"
        static let url         = "gt_target_url"
        static let mode        = "gt_mode_value"
        static let installed   = "gt_installed_flag"
        static let permGiven   = "gt_perm_given"
        static let permBlocked = "gt_perm_blocked"
        static let permDate    = "gt_perm_date"
    }

    init() { preheat() }

    func checkFirebase() async throws -> Bool {
        try await withCheckedThrowingContinuation { cont in
            Database.database().reference().child("users/log/data")
                .observeSingleEvent(of: .value) { snap in
                    if let s = snap.value as? String, !s.isEmpty, URL(string: s) != nil {
                        cont.resume(returning: true)
                    } else {
                        cont.resume(returning: false)
                    }
                } withCancel: { cont.resume(throwing: $0) }
        }
    }

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest  = 30
        cfg.timeoutIntervalForResource = 90
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        cfg.urlCache = nil
        return URLSession(configuration: cfg)
    }()

    func pullAttribution(deviceID: String) async throws -> [String: String] {
        var comps = URLComponents(string: "https://gcdsdk.appsflyer.com/install_data/v4.0/id\(AppVars.appID)")
        comps?.queryItems = [
            .init(name: "devkey",    value: AppVars.devKey),
            .init(name: "device_id", value: deviceID)
        ]
        guard let url = comps?.url else { throw RepoError.badURL }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw RepoError.failed
        }
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RepoError.decode
        }
        return dict.mapValues { "\($0)" }
    }

    private var ua: String = WKWebView().value(forKey: "userAgent") as? String ?? ""

    func pullDestination(attribution: [String: Any]) async throws -> String {
        guard let url = URL(string: "https://guidetripsplanner.com/config.php") else {
            throw RepoError.badURL
        }

        var body = attribution
        body["os"]                   = "iOS"
        body["af_id"]                = AppsFlyerLib.shared().getAppsFlyerUID()
        body["bundle_id"]            = Bundle.main.bundleIdentifier ?? ""
        body["firebase_project_id"]  = FirebaseApp.app()?.options.gcmSenderID
        body["store_id"]             = "id\(AppVars.appID)"
        body["push_token"]           = UserDefaults.standard.string(forKey: "push_token") ?? Messaging.messaging().fcmToken
        body["locale"]               = Locale.preferredLanguages.first.map { String($0.prefix(2)).uppercased() } ?? "EN"

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let delays: [Double] = [9.0, 18.0, 36.0]
        var last: Error?

        for (i, delay) in delays.enumerated() {
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw RepoError.failed }

                if (200...299).contains(http.statusCode) {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          json["ok"] as? Bool == true,
                          let dest = json["url"] as? String else { throw RepoError.decode }
                    return dest
                } else if http.statusCode == 429 {
                    try await Task.sleep(nanoseconds: UInt64(delay * Double(i + 1) * 1_000_000_000))
                    continue
                } else {
                    throw RepoError.failed
                }
            } catch {
                last = error
                if i < delays.count - 1 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw last ?? RepoError.failed
    }

    func saveAttribution(_ data: [String: String]) {
        if let j = json(data) { vault.set(j, forKey: K.attribution); hot[K.attribution] = j }
    }

    func saveDeeplink(_ data: [String: String]) {
        if let j = json(data) { vault.set(mask(j), forKey: K.deeplink) }
    }

    func saveURL(_ url: String) {
        vault.set(url, forKey: K.url); backup.set(url, forKey: K.url); hot[K.url] = url
    }

    func saveMode(_ mode: String) { vault.set(mode, forKey: K.mode) }
    func markInstalled()          { vault.set(true,  forKey: K.installed) }

    func savePermission(given: Bool, blocked: Bool) {
        vault.set(given,   forKey: K.permGiven)
        vault.set(blocked, forKey: K.permBlocked)
        vault.set(Date().timeIntervalSince1970 * 1000, forKey: K.permDate)
    }

    func load() -> PersistedData {
        var attr: [String: String] = [:]
        if let j = hot[K.attribution] as? String ?? vault.string(forKey: K.attribution),
           let d = parse(j) { attr = d }

        var dl: [String: String] = [:]
        if let m = vault.string(forKey: K.deeplink),
           let j = unmask(m), let d = parse(j) { dl = d }

        let url    = hot[K.url] as? String ?? vault.string(forKey: K.url) ?? backup.string(forKey: K.url)
        let ts     = vault.double(forKey: K.permDate)
        let date   = ts > 0 ? Date(timeIntervalSince1970: ts / 1000) : nil

        return PersistedData(
            url:          url,
            mode:         vault.string(forKey: K.mode),
            isNewInstall: !vault.bool(forKey: K.installed),
            attribution:  attr,
            deeplink:     dl,
            permGiven:    vault.bool(forKey: K.permGiven),
            permBlocked:  vault.bool(forKey: K.permBlocked),
            permDate:     date
        )
    }

    private func preheat() {
        if let v = vault.string(forKey: K.url)         { hot[K.url] = v }
        if let v = vault.string(forKey: K.attribution) { hot[K.attribution] = v }
    }

    private func json(_ d: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: d.mapValues { $0 as Any }),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    private func parse(_ s: String) -> [String: String]? {
        guard let data = s.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return dict.mapValues { "\($0)" }
    }

    private func mask(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "^")
            .replacingOccurrences(of: "+", with: "$")
    }

    private func unmask(_ s: String) -> String? {
        let b64 = s.replacingOccurrences(of: "^", with: "=")
                   .replacingOccurrences(of: "$", with: "+")
        guard let d = Data(base64Encoded: b64) else { return nil }
        return String(data: d, encoding: .utf8)
    }
}

enum RepoError: Error { case badURL, failed, decode }
