import SceneKit
import SwiftUI

/// Hosts the SceneKit view, swaps rooms when the page turns, and gives the
/// hinge reader a view to watch from.
struct SceneContainer: UIViewRepresentable {
    let game: GameController
    let room: LevelScene

    func makeUIView(context: Context) -> FittingSceneView {
        let view = FittingSceneView(frame: .zero)
        view.antialiasingMode = RenderQuality.current.antialiasing
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.backgroundColor = .black
        view.show(room)
        game.hinge.attach(to: view)
        return view
    }

    func updateUIView(_ view: FittingSceneView, context: Context) {
        if view.room !== room {
            view.show(room)
        }
    }
}

/// Keeps the whole room in frame whatever shape the screen is: the outer
/// screen, the open inner screen, or turned on its side.
final class FittingSceneView: SCNView {
    private(set) weak var room: LevelScene?

    func show(_ room: LevelScene) {
        self.room = room
        scene = room.scene
        pointOfView = room.cameraNode
        fitRoom()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fitRoom()
    }

    private func fitRoom() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        room?.fit(aspect: Double(bounds.width / bounds.height))
    }
}
