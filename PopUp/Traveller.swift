import SceneKit
import UIKit

/// The little traveller: a child in a yellow raincoat with a lantern, built
/// from simple shapes and animated in code. `node` sits at his feet.
@MainActor
final class Traveller {
    /// How bright his lantern is (1000 is SceneKit's full strength).
    static let lanternIntensity: CGFloat = 150

    let node = SCNNode()

    /// Hops when he can't go on. Kept apart from `body` so the walk doesn't fight it.
    private let bounce = SCNNode()
    /// Bobs and sways while he walks.
    private let body = SCNNode()
    private let leftLeg = SCNNode()
    private let rightLeg = SCNNode()
    private let lanternArm = SCNNode()
    private let lantern = SCNNode()
    private let lanternLight = SCNLight()
    /// Which way he faces, in radians about y (0 faces the camera's side of the room).
    private var facing: Float = 0.4
    private var legSwing: Float = 0

    init() {
        let coat = material(red: 0.95, green: 0.68, blue: 0.12, roughness: 0.45)
        let boots = material(red: 0.2, green: 0.13, blue: 0.08, roughness: 0.7)
        let shadowFace = material(red: 0.025, green: 0.025, blue: 0.03, roughness: 0.9)

        node.addChildNode(bounce)
        bounce.addChildNode(body)
        body.addChildNode(shape(SCNCone(topRadius: 0.11, bottomRadius: 0.26, height: 0.52), coat, at: [0, 0.3, 0]))
        let hood = shape(SCNSphere(radius: 0.2), coat, at: [0, 0.68, 0])
        hood.simdScale = [1, 1.05, 1.05]
        body.addChildNode(hood)
        let tip = shape(SCNCone(topRadius: 0, bottomRadius: 0.07, height: 0.16), coat, at: [0, 0.8, -0.15])
        tip.simdEulerAngles = [-1.0, 0, 0]
        body.addChildNode(tip)
        body.addChildNode(shape(SCNSphere(radius: 0.15), shadowFace, at: [0, 0.665, 0.085]))
        for side: Float in [-1, 1] {
            body.addChildNode(shape(SCNSphere(radius: 0.024), glow(), at: [0.055 * side, 0.68, 0.222]))
        }
        // Left arm hangs down; the right one carries the lantern.
        let sleeve = shape(SCNCapsule(capRadius: 0.045, height: 0.22), coat, at: [-0.19, 0.4, 0.02])
        sleeve.simdEulerAngles = [0, 0, -0.35]
        body.addChildNode(sleeve)

        // Legs swing from the hip.
        for (leg, side) in [(leftLeg, Float(-1)), (rightLeg, Float(1))] {
            leg.simdPosition = [0.085 * side, 0.17, 0]
            leg.addChildNode(shape(SCNCapsule(capRadius: 0.055, height: 0.2), boots, at: [0, -0.08, 0.02]))
            bounce.addChildNode(leg)
        }

        // Right arm held out with the lantern swinging from it.
        lanternArm.simdPosition = [0.17, 0.46, 0.04]
        let arm = shape(SCNCapsule(capRadius: 0.045, height: 0.22), coat, at: [0.03, -0.08, 0.04])
        arm.simdEulerAngles = [-0.6, 0, 0.3]
        lanternArm.addChildNode(arm)
        lantern.simdPosition = [0.07, -0.2, 0.12]
        lantern.addChildNode(shape(SCNBox(width: 0.09, height: 0.12, length: 0.09, chamferRadius: 0.01), glowWarm(),
                                   at: [0, -0.06, 0]))
        lantern.addChildNode(shape(SCNCone(topRadius: 0.012, bottomRadius: 0.06, height: 0.05), boots, at: [0, 0.02, 0]))
        lanternLight.type = .omni
        lanternLight.color = UIColor(red: 1, green: 0.7, blue: 0.42, alpha: 1)
        lanternLight.intensity = Self.lanternIntensity
        lanternLight.attenuationStartDistance = 0
        lanternLight.attenuationEndDistance = 2.6
        lanternLight.attenuationFalloffExponent = 2
        let lightNode = SCNNode()
        lightNode.light = lanternLight
        lightNode.simdPosition = [0, -0.06, 0.08]
        lantern.addChildNode(lightNode)
        lanternArm.addChildNode(lantern)
        body.addChildNode(lanternArm)
    }

    /// Places him for this frame. Pass `walked` (distance so far, in strides)
    /// while walking; nil when standing still.
    func update(position: SIMD3<Double>, scale: Double, heading: SIMD3<Double>?, walked: Double?,
                time: Double, dt: Double) {
        node.simdPosition = SIMD3<Float>(Float(position.x), Float(position.y), Float(position.z))
        node.simdScale = SIMD3<Float>(repeating: Float(scale))

        // Turn smoothly toward where he's going, or toward the camera when idle.
        let target: Float = heading.map { Float(atan2($0.x, $0.z)) } ?? 0.4
        var turn = target - facing
        while turn > .pi { turn -= 2 * .pi }
        while turn < -.pi { turn += 2 * .pi }
        facing += turn * Float(min(1, dt * 8))
        node.simdEulerAngles = [0, facing, 0]

        if let walked {
            let phase = Float(walked / 0.55 * 2 * .pi)
            legSwing = sin(phase) * 0.6
            body.simdPosition = [0, abs(sin(phase)) * 0.035, 0]
            body.simdEulerAngles = [0, 0, sin(phase) * 0.05]
            body.simdScale = [1, 1, 1]
            lantern.simdEulerAngles = [sin(phase) * 0.18, 0, 0]
        } else {
            legSwing *= Float(max(0, 1 - dt * 10))
            let breath = Float(sin(time * 2))
            body.simdPosition = [0, 0, 0]
            body.simdEulerAngles = [0, 0, 0]
            body.simdScale = [1, 1 + breath * 0.012, 1]
            lantern.simdEulerAngles = [Float(sin(time * 1.3)) * 0.08, 0, Float(sin(time * 0.9)) * 0.05]
        }
        leftLeg.simdEulerAngles = [legSwing, 0, 0]
        rightLeg.simdEulerAngles = [-legSwing, 0, 0]
    }

    /// A light that follows him around, dimmed with the room as the book folds.
    func setLanternBrightness(_ amount: Double) {
        lanternLight.intensity = Self.lanternIntensity * CGFloat(amount)
    }

    /// He reaches the gap and can't go on: a little hop.
    func hop() {
        bounce.runAction(.sequence([
            .moveBy(x: 0, y: 0.16, z: 0, duration: 0.12),
            .moveBy(x: 0, y: -0.16, z: 0, duration: 0.12),
        ]))
    }

    /// Steps through the door at `exit` and disappears.
    func walkThroughDoor(to exit: SIMD3<Double>) {
        let move = SCNAction.move(to: SCNVector3(Float(exit.x), Float(exit.y), Float(exit.z)), duration: 0.9)
        move.timingMode = .easeIn
        node.runAction(.sequence([.wait(duration: 0.3), .group([move, .sequence([.wait(duration: 0.5), .fadeOut(duration: 0.4)])])]))
    }

    /// Drops through the hole.
    func fall() {
        let drop = SCNAction.moveBy(x: 0, y: -3.5, z: 0, duration: 0.8)
        drop.timingMode = .easeIn
        node.runAction(.group([drop, .sequence([.wait(duration: 0.4), .fadeOut(duration: 0.4)])]))
    }

    func reset() {
        node.removeAllActions()
        bounce.removeAllActions()
        bounce.simdPosition = .zero
        node.opacity = 1
        facing = 0.4
        legSwing = 0
    }

    // MARK: - Pieces

    private func shape(_ geometry: SCNGeometry, _ material: SCNMaterial, at position: SIMD3<Float>) -> SCNNode {
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        node.simdPosition = position
        return node
    }

    private func material(red: CGFloat, green: CGFloat, blue: CGFloat, roughness: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(red: red, green: green, blue: blue, alpha: 1)
        m.roughness.contents = roughness
        return m
    }

    private func glow() -> SCNMaterial {
        let m = material(red: 0.3, green: 0.28, blue: 0.24, roughness: 0.5)
        m.emission.contents = UIColor(red: 1, green: 0.9, blue: 0.7, alpha: 1)
        m.emission.intensity = 1.4
        return m
    }

    private func glowWarm() -> SCNMaterial {
        let m = material(red: 0.3, green: 0.2, blue: 0.1, roughness: 0.4)
        m.emission.contents = UIColor(red: 1, green: 0.62, blue: 0.3, alpha: 1)
        m.emission.intensity = 1.4
        return m
    }
}
