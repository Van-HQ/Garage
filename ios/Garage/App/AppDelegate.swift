import UIKit
import CarPlay

/// Routes the CarPlay scene to its own delegate. The phone scene is left to SwiftUI.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .carTemplateApplication {
            config.delegateClass = CarPlaySceneDelegate.self
        }
        return config
    }
}
