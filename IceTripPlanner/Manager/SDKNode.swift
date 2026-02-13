import AppsFlyerLib
import Foundation
import AppTrackingTransparency

class SDKNode: NSObject, AppsFlyerLibDelegate, DeepLinkDelegate {
    private var node: ConversionNode

    init(node: ConversionNode) { self.node = node }

    func configure() {
        let sdk = AppsFlyerLib.shared()
        sdk.appsFlyerDevKey = AppVars.devKey
        sdk.appleAppID      = AppVars.appID
        sdk.delegate        = self
        sdk.deepLinkDelegate = self
        sdk.isDebug         = false
    }

    func launch() {
        if #available(iOS 14, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                    UserDefaults.standard.set(status.rawValue, forKey: "att_status")
                }
            }
        } else {
            AppsFlyerLib.shared().start()
        }
    }

    func onConversionDataSuccess(_ data: [AnyHashable: Any]) { node.receiveConversion(data) }
    func onConversionDataFail(_ error: Error) {
        node.receiveConversion(["error": true, "error_desc": error.localizedDescription])
    }
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status, let dl = result.deepLink else { return }
        node.receiveDeeplink(dl.clickEvent)
    }
}
