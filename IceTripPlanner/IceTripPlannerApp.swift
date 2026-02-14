import SwiftUI
import Firebase

@main
struct IceTripPlannerApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
    }
    
}

struct AppVars {
    static let appID  = "6758891568"
    static let devKey = "F8AUQnr7wRJGxjgpWe7t7T"
}
