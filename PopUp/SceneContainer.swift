import SceneKit
import SwiftUI

/// Hosts the SceneKit view, and gives the hinge reader a view to watch from.
struct SceneContainer: UIViewRepresentable {
    let game: GameController

    func makeUIView(context: Context) -> FittingSceneView {
        let view = FittingSceneView(frame: .zero)
        view.scene = game.room.scene
        view.pointOfView = game.room.cameraNode
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        game.hinge.attach(to: view)
        return view
    }

    func updateUIView(_ view: FittingSceneView, context: Context) {}
}

/// Keeps the whole room in frame whatever shape the screen is: folded,
/// open, or turned on its side.
final class FittingSceneView: SCNView {
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, let camera = pointOfView?.camera else { return }
        let aspect = Double(bounds.width / bounds.height)
        camera.orthographicScale = max(BedroomScene.minHalfHeight, BedroomScene.minHalfWidth / aspect)
    }
}
