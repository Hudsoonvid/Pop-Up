import PopUpCore
import SceneKit
import UIKit

/// One room of the treehouse: its `Blueprint` built as a SceneKit scene, the
/// camera rig the hinge tilts, and the pop-up layers the book folds.
///
/// SceneKit is deprecated in favour of RealityKit but still ships, and it has
/// everything this needs built in (fog, bloom, particles, shadows).
@MainActor
final class LevelScene {
    /// Brightness of the whole picture, in stops: +1 doubles it, -1 halves it.
    static let exposure: CGFloat = -0.3
    /// Colour strength: 1 is unchanged, lower is more muted.
    static let saturation: CGFloat = 0.85

    let blueprint: Blueprint
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let traveller = Traveller()

    private let quality: RenderQuality
    private let yawNode = SCNNode()
    private let pitchNode = SCNNode()
    /// Walls and windows, hinged along `blueprint.backdropHinge`.
    private let backdrop = SCNNode()
    /// Furniture, moss, lamps, the door and the traveller: they spring up.
    private let props = SCNNode()
    private var doorPivot: SCNNode?
    private var lights: [(light: SCNLight, base: CGFloat, flickers: Bool, seed: Double)] = []
    private var emitters: [(system: SCNParticleSystem, birthRate: CGFloat)] = []
    /// How lit the room is, following the pop-up (dark when folded).
    private var lightLevel = 1.0

    init(blueprint: Blueprint, quality: RenderQuality = .current) {
        self.blueprint = blueprint
        self.quality = quality
        buildAtmosphere()
        buildCamera()
        buildPieces()
        buildLights()
        buildParticles()
    }

    // MARK: - Driving it

    func tiltCamera(degrees: Double) {
        pitchNode.simdEulerAngles = [Float(-degrees * .pi / 180), 0, 0]
    }

    /// Keeps the room in frame on a screen of this width-to-height ratio.
    func fit(aspect: Double) {
        guard let camera = cameraNode.camera else { return }
        camera.projectionDirection = .vertical
        camera.fieldOfView = CGFloat(blueprint.rig.fieldOfView(aspect: aspect))
    }

    /// 0 is folded flat inside the closed book, 1 is fully popped up. Walls
    /// swing up first, then everything else springs up with a little bounce.
    /// At 1 every piece is exactly where the blueprint puts it.
    func setPop(_ amount: Double) {
        let wall = easeOut(clamp(amount * 1.3))
        backdrop.simdEulerAngles = [Float(-(1 - wall) * .pi / 2), 0, 0]
        let rise = easeOutBack(clamp((amount - 0.2) / 0.8))
        props.simdScale = [1, Float(max(rise, 0.001)), 1]
        lightLevel = clamp(amount)
        for emitter in emitters {
            emitter.system.birthRate = emitter.birthRate * CGFloat(lightLevel)
        }
    }

    /// Flickers the flames. Call every frame.
    func update(time: Double) {
        for entry in lights {
            var level = lightLevel
            if entry.flickers {
                level *= 0.9 + 0.07 * sin(time * 11 + entry.seed) + 0.03 * sin(time * 23.7 + entry.seed * 2)
            }
            entry.light.intensity = entry.base * CGFloat(level)
        }
        traveller.setLanternBrightness(lightLevel)
    }

    /// The door swings open, away from the camera.
    func openDoor() {
        doorPivot?.runAction(.rotateTo(x: 0, y: 1.9, z: 0, duration: 0.6, usesShortestUnitArc: true))
    }

    // MARK: - Building it

    private func buildAtmosphere() {
        let atmosphere = blueprint.atmosphere
        let fog = UIColor(atmosphere.fogColor)
        scene.background.contents = fog
        scene.fogColor = fog
        scene.fogStartDistance = CGFloat(atmosphere.fogStart)
        scene.fogEndDistance = CGFloat(atmosphere.fogEnd)
        scene.fogDensityExponent = 1.3
        scene.lightingEnvironment.contents = UIImage(named: "sky.jpg")
        scene.lightingEnvironment.intensity = CGFloat(atmosphere.skyLight)
    }

    private func buildCamera() {
        let rig = blueprint.rig
        let camera = SCNCamera()
        camera.automaticallyAdjustsZRange = false
        camera.zNear = 0.3
        camera.zFar = 220
        camera.fieldOfView = CGFloat(rig.fieldOfView(aspect: 4.0 / 3.0))
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = Self.exposure
        // A soft glow around flames and lanterns only, not the whole room.
        camera.bloomIntensity = 0.35
        camera.bloomThreshold = 1.1
        camera.bloomBlurRadius = 6
        camera.vignettingIntensity = 0.7
        camera.vignettingPower = 0.9
        camera.saturation = Self.saturation
        camera.contrast = 0.06
        if quality.ambientOcclusion {
            camera.screenSpaceAmbientOcclusionIntensity = 0.9
            camera.screenSpaceAmbientOcclusionRadius = 0.35
        }
        if quality.depthOfField {
            camera.wantsDepthOfField = true
            camera.focusDistance = CGFloat(rig.distance)
            camera.fStop = 1.4
        }
        cameraNode.camera = camera
        // Swing round by `yaw`, tilt down by the hinge, then step back by
        // `distance`: the same arc as `CameraRig.position(tilt:)`.
        cameraNode.simdPosition = [0, 0, Float(rig.distance)]
        pitchNode.addChildNode(cameraNode)
        yawNode.addChildNode(pitchNode)
        yawNode.simdPosition = vector(rig.pivot)
        yawNode.simdEulerAngles = [0, Float(rig.yaw * .pi / 180), 0]
        scene.rootNode.addChildNode(yawNode)
    }

    private func buildPieces() {
        let page = SCNNode()
        let scenery = SCNNode()
        let backdropPieces = SCNNode()
        let propPieces = SCNNode()
        let hinge = vector(blueprint.backdropHinge)

        for piece in blueprint.pieces {
            let node = makeNode(piece)
            if piece.tag == "door" {
                // Hinged on its left edge so it can swing open.
                let pivot = SCNNode()
                let halfWidth = Float(piece.size.x * piece.scale.x / 2)
                pivot.simdPosition = node.simdPosition - [halfWidth, 0, 0]
                node.simdPosition = [halfWidth, 0, 0]
                pivot.addChildNode(node)
                props.addChildNode(pivot)
                doorPivot = pivot
                continue
            }
            switch piece.layer {
            case .page: page.addChildNode(node)
            case .scenery: scenery.addChildNode(node)
            case .props: propPieces.addChildNode(node)
            case .backdrop:
                node.simdPosition -= hinge
                backdropPieces.addChildNode(node)
            }
        }

        // Merge each layer into one node: far fewer draw calls for the simulator.
        scene.rootNode.addChildNode(page.flattenedClone())
        let flatScenery = scenery.flattenedClone()
        flatScenery.castsShadow = false
        scene.rootNode.addChildNode(flatScenery)
        backdrop.simdPosition = hinge
        backdrop.addChildNode(backdropPieces.flattenedClone())
        scene.rootNode.addChildNode(backdrop)
        props.addChildNode(propPieces.flattenedClone())
        props.addChildNode(traveller.node)
        scene.rootNode.addChildNode(props)
    }

    private func makeNode(_ piece: Piece) -> SCNNode {
        let size = piece.size
        let geometry: SCNGeometry
        var length = 1.0
        var upright = false
        switch piece.shape {
        case .box:
            geometry = SCNBox(width: size.x, height: size.y, length: size.z, chamferRadius: piece.chamfer)
            let dims = size * piece.scale
            length = max(dims.x, dims.y, dims.z)
            upright = dims.y > dims.x && dims.y > dims.z
        case .cylinder:
            let cylinder = SCNCylinder(radius: size.x, height: size.y)
            cylinder.radialSegmentCount = size.x > 0.5 ? 24 : 12
            geometry = cylinder
            length = 2 * .pi * size.x
        case .sphere:
            let sphere = SCNSphere(radius: size.x)
            sphere.segmentCount = size.x > 1 ? 24 : 12
            geometry = sphere
            length = 2 * .pi * size.x * max(piece.scale.x, piece.scale.z)
        case .cone:
            let cone = SCNCone(topRadius: size.x, bottomRadius: size.y, height: size.z)
            cone.radialSegmentCount = 12
            geometry = cone
        case .torus:
            let torus = SCNTorus(ringRadius: size.x, pipeRadius: size.y)
            torus.ringSegmentCount = 24
            torus.pipeSegmentCount = 8
            geometry = torus
        }
        geometry.firstMaterial = MaterialLibrary.material(piece.material, length: length, upright: upright)
        let node = SCNNode(geometry: geometry)
        node.simdPosition = vector(piece.position)
        node.simdOrientation = orientation(degrees: piece.rotation)
        node.simdScale = vector(piece.scale)
        return node
    }

    private func buildLights() {
        for (index, spec) in blueprint.lights.enumerated() {
            let light = SCNLight()
            switch spec.kind {
            case .directional:
                light.type = .directional
            case .omni:
                light.type = .omni
            case .spot:
                light.type = .spot
                light.spotInnerAngle = CGFloat(spec.spotAngle * 0.35)
                light.spotOuterAngle = CGFloat(spec.spotAngle)
            }
            if spec.kind != .directional {
                light.attenuationStartDistance = 0
                light.attenuationEndDistance = CGFloat(spec.range)
                light.attenuationFalloffExponent = 2
            }
            light.color = UIColor(spec.color)
            light.intensity = CGFloat(spec.intensity)
            if spec.castsShadow {
                light.castsShadow = true
                light.shadowMode = .forward
                light.shadowMapSize = CGSize(width: quality.shadowMapSize, height: quality.shadowMapSize)
                light.shadowSampleCount = quality.shadowSamples
                light.shadowRadius = 3
                light.shadowColor = UIColor(white: 0, alpha: 0.65)
                light.zNear = 0.1
                light.zFar = CGFloat(spec.range)
            }
            let node = SCNNode()
            node.light = light
            node.simdPosition = vector(spec.position)
            if spec.kind != .omni {
                node.simdLook(at: vector(spec.target))
            }
            scene.rootNode.addChildNode(node)
            lights.append((light, CGFloat(spec.intensity), spec.flickers, Double(index) * 1.7))
        }
    }

    private func buildParticles() {
        for emitter in blueprint.emitters {
            let system = Particles.system(for: emitter, density: quality.particleDensity)
            let node = SCNNode()
            node.simdPosition = vector(emitter.center)
            node.addParticleSystem(system)
            scene.rootNode.addChildNode(node)
            emitters.append((system, system.birthRate))
        }
    }
}

// MARK: - Helpers

private func vector(_ v: SIMD3<Double>) -> SIMD3<Float> {
    SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z))
}

/// The same rotation as `PopUpCore.Rotation(degrees:)`: roll, then pitch, then yaw.
private func orientation(degrees: SIMD3<Double>) -> simd_quatf {
    let r = degrees * .pi / 180
    let pitch = simd_quatf(angle: Float(r.x), axis: [1, 0, 0])
    let yaw = simd_quatf(angle: Float(r.y), axis: [0, 1, 0])
    let roll = simd_quatf(angle: Float(r.z), axis: [0, 0, 1])
    return yaw * pitch * roll
}

private func clamp(_ x: Double) -> Double {
    min(max(x, 0), 1)
}

private func easeOut(_ t: Double) -> Double {
    1 - (1 - t) * (1 - t) * (1 - t)
}

/// Overshoots a little and settles, like paper springing up.
private func easeOutBack(_ t: Double) -> Double {
    let c1 = 1.70158
    let c3 = c1 + 1
    return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
}
