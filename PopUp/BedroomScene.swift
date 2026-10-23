import SceneKit
import UIKit
import PopUpCore

/// The bedroom diorama: paper-coloured props, the paper guy, and a camera rig
/// that the hinge tilts. Positions come from `BedroomLayout`, so the floor rug
/// and the book rug always meet on screen at the level's click angle.
///
/// SceneKit is deprecated in favour of RealityKit but still ships, and it's the
/// quickest way to prove the mechanic. Everything SceneKit-specific is in this
/// file and `SceneContainer.swift`.
@MainActor
final class BedroomScene {
    /// Smallest half-height and half-width of the view, in world units. The
    /// view widens or narrows to fit the screen shape (see `FittingSceneView`).
    static let minHalfHeight = 2.7
    static let minHalfWidth = 4.8

    let scene = SCNScene()
    let cameraNode = SCNNode()

    private let layout: BedroomLayout
    /// Pivot at the middle of the room; tilting it swings the camera from side view to top-down.
    private let rig = SCNNode()
    /// Sits at his feet.
    private let guy = SCNNode()
    /// His paper cut-out, which bobs while he walks.
    private let figure = SCNNode()
    /// Hinged on the door's left edge.
    private let doorPivot = SCNNode()

    init(layout: BedroomLayout) {
        self.layout = layout
        scene.background.contents = Palette.backdrop
        buildCamera()
        buildLights()
        buildRoom()
        buildBooksAndDoor()
        buildGuy()
        reset(guyAt: layout.start)
    }

    func tiltCamera(degrees: Double) {
        rig.simdEulerAngles = SIMD3<Float>(Float(-degrees * .pi / 180), 0, 0)
    }

    /// Puts him at `position`. Pass `walked` (distance so far) while walking to make him bob.
    func placeGuy(at position: SIMD3<Double>, walked: Double?) {
        guy.simdPosition = asFloat(position + [0, 0.01, 0])
        let bob = walked.map { 0.06 * abs(sin($0 * .pi / 0.35)) } ?? 0
        figure.simdPosition = SIMD3<Float>(0, Float(bob), 0)
    }

    /// He reaches the gap and can't cross: a little hop.
    func bump() {
        figure.runAction(.sequence([
            .moveBy(x: 0, y: 0.18, z: 0, duration: 0.12),
            .moveBy(x: 0, y: -0.18, z: 0, duration: 0.12),
        ]))
    }

    /// The door swings open and he steps through.
    func exitThroughDoor() {
        doorPivot.runAction(.rotateTo(x: 0, y: 1.8, z: 0, duration: 0.5, usesShortestUnitArc: true))
        guy.runAction(.sequence([
            .wait(duration: 0.35),
            .group([.moveBy(x: 0, y: 0, z: -0.4, duration: 0.45), .fadeOut(duration: 0.45)]),
        ]))
    }

    func reset(guyAt start: SIMD3<Double>) {
        guy.removeAllActions()
        figure.removeAllActions()
        doorPivot.removeAllActions()
        guy.opacity = 1
        doorPivot.simdEulerAngles = .zero
        placeGuy(at: start, walked: nil)
    }

    // MARK: - Building the room

    private func buildCamera() {
        let camera = SCNCamera()
        // Orthographic, so the rugs line up exactly at one angle (and only one).
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Self.minHalfHeight
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.simdPosition = [0, 0, 30]
        rig.simdPosition = [0, 0.9, 0]
        rig.addChildNode(cameraNode)
        scene.rootNode.addChildNode(rig)
    }

    private func buildLights() {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 450
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // No shadows: a shadow would give away which rug is really nearer.
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 650
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.simdEulerAngles = [-1.0, -0.6, 0]
        scene.rootNode.addChildNode(sunNode)
    }

    private func buildRoom() {
        let root = scene.rootNode
        // The open page the room stands on, and the wall behind it.
        root.addChildNode(box(9, 0.06, 5, Palette.page, at: [0, -0.03, 0]))
        root.addChildNode(box(9, 3.2, 0.06, Palette.wall, at: [0, 1.6, -2.53]))
        root.addChildNode(box(1.5, 1.1, 0.02, Palette.window, at: [-0.6, 2.0, -2.49]))

        // Bed against the wall, where he starts.
        root.addChildNode(box(1.4, 0.4, 1.8, Palette.wood, at: [-3.5, 0.2, -1.5]))
        root.addChildNode(box(1.3, 0.16, 1.7, Palette.sheet, at: [-3.5, 0.48, -1.5]))
        root.addChildNode(box(1.34, 0.06, 1.0, Palette.blanket, at: [-3.5, 0.59, -1.05]))
        root.addChildNode(box(1.0, 0.14, 0.4, Palette.sheet, at: [-3.5, 0.63, -2.1]))

        // First half of the path: a rug from the bed to the edge of the books.
        let length = layout.edgeX - layout.rugStartX
        root.addChildNode(box(length, layout.rugThickness, layout.pathDepth, Palette.rug,
                              at: [layout.rugStartX + length / 2, layout.rugThickness / 2, layout.floorZ]))
    }

    private func buildBooksAndDoor() {
        let root = scene.rootNode
        let height = layout.ledgeHeight
        let z = layout.ledgeZ
        let right = layout.ledgeEndX

        // Three books stacked to exactly the ledge height. Only the top one
        // starts right at the edge: its corner is what meets the floor rug on screen.
        let books: [(color: UIColor, inset: Double)] = [
            (Palette.bookBlue, 0.18), (Palette.bookGreen, 0.09), (Palette.bookMustard, 0),
        ]
        for (index, book) in books.enumerated() {
            let left = layout.edgeX + book.inset
            let width = right - left
            let y = height / 3 * (Double(index) + 0.5)
            root.addChildNode(box(width, height / 3, layout.pathDepth, book.color, at: [left + width / 2, y, z]))
        }

        // Second half of the path: a rug on top of the books.
        let length = right - layout.edgeX
        root.addChildNode(box(length, layout.rugThickness, layout.pathDepth, Palette.rug,
                              at: [layout.edgeX + length / 2, height + layout.rugThickness / 2, z]))

        // The door stands near the back edge of the books.
        let base = height + layout.rugThickness
        let doorZ = z - layout.pathDepth / 2 + 0.04
        let x = layout.doorX
        root.addChildNode(box(0.8, 1.3, 0.02, Palette.doorway, at: [x, base + 0.65, doorZ - 0.06]))
        root.addChildNode(box(0.1, 1.42, 0.08, Palette.wood, at: [x - 0.45, base + 0.71, doorZ]))
        root.addChildNode(box(0.1, 1.42, 0.08, Palette.wood, at: [x + 0.45, base + 0.71, doorZ]))
        root.addChildNode(box(1.0, 0.1, 0.08, Palette.wood, at: [x, base + 1.37, doorZ]))

        let panel = box(0.8, 1.3, 0.05, Palette.door, at: [0.4, 0.65, 0])
        panel.addChildNode(box(0.08, 0.08, 0.04, Palette.bookMustard, at: [0.28, 0, 0.04]))
        doorPivot.simdPosition = asFloat([x - 0.4, base, doorZ])
        doorPivot.addChildNode(panel)
        root.addChildNode(doorPivot)
    }

    private func buildGuy() {
        // A paper cut-out that always faces the camera, like a pop-up figure.
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .X
        figure.constraints = [billboard]

        figure.addChildNode(cutout(0.48, 0.6, corner: 0.17, Palette.ink, at: [0, 0.3, 0], order: 100))
        figure.addChildNode(cutout(0.4, 0.52, corner: 0.14, Palette.paper, at: [0, 0.3, 0], order: 101))
        figure.addChildNode(cutout(0.44, 0.44, corner: 0.22, Palette.ink, at: [0, 0.74, 0], order: 100))
        figure.addChildNode(cutout(0.36, 0.36, corner: 0.18, Palette.paper, at: [0, 0.74, 0], order: 101))
        for eyeX in [-0.07, 0.07] {
            figure.addChildNode(cutout(0.05, 0.07, corner: 0.025, Palette.ink, at: [eyeX, 0.76, 0], order: 102))
        }
        guy.addChildNode(figure)
        scene.rootNode.addChildNode(guy)
    }

    // MARK: - Pieces

    private func box(_ width: Double, _ height: Double, _ depth: Double, _ color: UIColor,
                     at center: SIMD3<Double>) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: depth, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .lambert
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        node.simdPosition = asFloat(center)
        return node
    }

    private func cutout(_ width: Double, _ height: Double, corner: Double, _ color: UIColor,
                        at center: SIMD3<Double>, order: Int) -> SCNNode {
        let plane = SCNPlane(width: width, height: height)
        plane.cornerRadius = corner
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .constant
        material.isDoubleSided = true
        // Drawn over everything, in `order`, so he never sinks into the rug
        // when the camera looks straight down. Nothing in this room should
        // hide him; later levels with walls in front will need real depth.
        material.readsFromDepthBuffer = false
        plane.firstMaterial = material
        let node = SCNNode(geometry: plane)
        node.simdPosition = asFloat(center)
        node.renderingOrder = order
        return node
    }
}

private func asFloat(_ v: SIMD3<Double>) -> SIMD3<Float> {
    SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z))
}

private enum Palette {
    static let backdrop = UIColor(hex: 0xE4D8C3)
    static let page = UIColor(hex: 0xF4ECDC)
    static let wall = UIColor(hex: 0xCFE3EC)
    static let window = UIColor(hex: 0xFFF6C9)
    static let wood = UIColor(hex: 0xC98B5E)
    static let sheet = UIColor(hex: 0xFAFAF7)
    static let blanket = UIColor(hex: 0xE9A3A3)
    static let rug = UIColor(hex: 0xE26D5A)
    static let bookBlue = UIColor(hex: 0x4E7FA8)
    static let bookGreen = UIColor(hex: 0x6FA36B)
    static let bookMustard = UIColor(hex: 0xE3B23C)
    static let door = UIColor(hex: 0x8C5A3C)
    static let doorway = UIColor(hex: 0xFFE9A8)
    static let paper = UIColor(hex: 0xFFFFFF)
    static let ink = UIColor(hex: 0x2E2A26)
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}
