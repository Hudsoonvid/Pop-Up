import PopUpCore
import SceneKit
import UIKit

/// The little lives in each room: dust in lamplight, fireflies, falling leaves
/// and mushroom spores. Kept sparse: `density` scales how many are alive.
@MainActor
enum Particles {
    static func system(for emitter: Emitter, density: Double) -> SCNParticleSystem {
        let system = SCNParticleSystem()
        let extent = emitter.extent
        system.emitterShape = SCNBox(width: extent.x, height: extent.y, length: extent.z, chamferRadius: 0)
        system.birthLocation = .volume
        system.birthDirection = .random
        system.particleImage = UIImage(named: "particle_dot.png")
        system.blendMode = .additive
        system.isLightingEnabled = false
        system.sortingMode = .none
        system.loops = true

        switch emitter.kind {
        case .dust:
            system.birthRate = 6 * density
            system.particleLifeSpan = 7
            system.particleLifeSpanVariation = 2
            system.particleSize = 0.018
            system.particleSizeVariation = 0.008
            system.particleColor = UIColor(red: 1, green: 0.86, blue: 0.6, alpha: 0.45)
            system.particleVelocity = 0.04
            system.particleVelocityVariation = 0.03
            system.propertyControllers = [.opacity: fade(values: [0, 1, 1, 0], at: [0, 0.2, 0.8, 1])]
        case .fireflies:
            system.birthRate = 2.4 * density
            system.particleLifeSpan = 5
            system.particleLifeSpanVariation = 1.5
            system.particleSize = 0.07
            system.particleSizeVariation = 0.02
            system.particleColor = UIColor(red: 0.85, green: 1, blue: 0.45, alpha: 1)
            system.particleVelocity = 0.15
            system.particleVelocityVariation = 0.1
            system.acceleration = SCNVector3(0, 0.02, 0)
            // Blink on and off a couple of times as they drift.
            system.propertyControllers = [.opacity: fade(values: [0, 1, 0.15, 1, 0], at: [0, 0.2, 0.45, 0.7, 1])]
        case .leaves:
            system.particleImage = UIImage(named: "particle_leaf.png")
            system.blendMode = .alpha
            system.birthRate = 0.8 * density
            system.particleLifeSpan = 12
            system.particleSize = 0.12
            system.particleSizeVariation = 0.04
            system.particleColor = UIColor(white: 0.75, alpha: 1)
            system.birthDirection = .constant
            system.emittingDirection = SCNVector3(0, -1, 0)
            system.spreadingAngle = 25
            system.particleVelocity = 0.35
            system.particleVelocityVariation = 0.1
            system.particleAngle = 0
            system.particleAngleVariation = 180
            system.particleAngularVelocity = 60
            system.particleAngularVelocityVariation = 60
            system.propertyControllers = [.opacity: fade(values: [0, 1, 1, 0], at: [0, 0.1, 0.85, 1])]
        case .spores:
            system.birthRate = 3 * density
            system.particleLifeSpan = 3
            system.particleLifeSpanVariation = 1
            system.particleSize = 0.02
            system.particleSizeVariation = 0.01
            system.particleColor = UIColor(red: 0.4, green: 1, blue: 0.9, alpha: 1)
            system.birthDirection = .constant
            system.emittingDirection = SCNVector3(0, 1, 0)
            system.spreadingAngle = 30
            system.particleVelocity = 0.12
            system.particleVelocityVariation = 0.05
            system.propertyControllers = [.opacity: fade(values: [0, 1, 0], at: [0, 0.3, 1])]
        }
        return system
    }

    private static func fade(values: [Double], at times: [Double]) -> SCNParticlePropertyController {
        let animation = CAKeyframeAnimation()
        animation.values = values.map { NSNumber(value: $0) }
        animation.keyTimes = times.map { NSNumber(value: $0) }
        return SCNParticlePropertyController(animation: animation)
    }
}
