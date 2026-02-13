import UIKit
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib

final class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    private let conversionNode = ConversionNode()
    private let pushNode       = PushNode()
    private var sdkNode: SDKNode?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        conversionNode.onConversion = { [weak self] in self?.relay(conversion: $0) }
        conversionNode.onDeeplink   = { [weak self] in self?.relay(deeplink: $0) }
        sdkNode = SDKNode(node: conversionNode)

        configureFirebase()
        configurePush()
        configureSDK()

        if let push = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            pushNode.ingest(push)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(didActivate), name: UIApplication.didBecomeActiveNotification, object: nil)
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    private func configureFirebase() { FirebaseApp.configure() }

    private func configurePush() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func configureSDK() { sdkNode?.configure() }

    @objc private func didActivate() { sdkNode?.launch() }

    private func relay(conversion data: [AnyHashable: Any]) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            NotificationCenter.default.post(name: .init("ConversionDataReceived"), object: nil, userInfo: ["conversionData": data])
        }
    }

    private func relay(deeplink data: [AnyHashable: Any]) {
        NotificationCenter.default.post(name: .init("deeplink_values"), object: nil, userInfo: ["deeplinksData": data])
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { token, error in
            guard error == nil, let token else { return }
            UserDefaults.standard.set(token, forKey: "fcm_token")
            UserDefaults.standard.set(token, forKey: "push_token")
            UserDefaults(suiteName: "group.guide.cache")?.set(token, forKey: "shared_fcm")
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        pushNode.ingest(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        pushNode.ingest(response.notification.request.content.userInfo)
        completionHandler()
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        pushNode.ingest(userInfo)
        completionHandler(.newData)
    }
}

final class ConversionNode: NSObject {
    var onConversion: (([AnyHashable: Any]) -> Void)?
    var onDeeplink:   (([AnyHashable: Any]) -> Void)?

    private var convBuf: [AnyHashable: Any] = [:]
    private var dlBuf:   [AnyHashable: Any] = [:]
    private var timer:   Timer?

    func receiveConversion(_ data: [AnyHashable: Any]) {
        convBuf = data
        startTimer()
        if !dlBuf.isEmpty { merge() }
    }

    func receiveDeeplink(_ data: [AnyHashable: Any]) {
        guard !UserDefaults.standard.bool(forKey: "gt_installed_flag") else { return }
        dlBuf = data
        onDeeplink?(data)
        timer?.invalidate()
        if !convBuf.isEmpty { merge() }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in self?.merge() }
    }

    private func merge() {
        var result = convBuf
        dlBuf.forEach { k, v in
            let key = "deep_\(k)"
            if result[key] == nil { result[key] = v }
        }
        onConversion?(result)
    }
}
