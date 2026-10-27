import SwiftUI
import UIKit

/// Starts the game in a window whose root controller doesn't animate resizes.
///
/// On iPhone Duo, folding or unfolding reaches the app as a resize and trait
/// change. UIKit animates those, which smears the 3D view mid-fold. iOS gives
/// apps no way to turn off its own fold transition between the screens, but
/// the game can at least add nothing to it: its layout snaps straight to the
/// new size.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = StillHostingController(rootView: GameView())
        window.makeKeyAndVisible()
        self.window = window
    }
}

/// Hosts the game and applies size changes (folding, unfolding, rotating)
/// instantly instead of animating them.
final class StillHostingController<Content: View>: UIHostingController<Content> {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        UIView.setAnimationsEnabled(false)
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            UIView.setAnimationsEnabled(true)
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}
