import SwiftUI
import Firebase

@main
struct IceTripPlannerApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView2()
        }
    }
}

struct AppVars {
    static let appID  = "6758891568"
    static let devKey = "F8AUQnr7wRJGxjgpWe7t7T"
}
