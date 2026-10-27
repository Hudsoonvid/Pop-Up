import PopUpCore
import SceneKit
import UIKit

/// How much rendering work to do. `.light` keeps the simulator smooth on an
/// M1 Mac; `.rich` adds the expensive extras for a real iPhone Duo.
enum RenderQuality {
    case light
    case rich

    /// Light everywhere for now. Try `.rich` once it's running on a real Duo.
    static let current = RenderQuality.light

    var shadowMapSize: CGFloat { self == .light ? 1024 : 2048 }
    var shadowSamples: Int { self == .light ? 4 : 12 }
    /// Scales how many particles are alive at once.
    var particleDensity: Double { self == .light ? 0.5 : 1 }
    var antialiasing: SCNAntialiasingMode { self == .light ? .multisampling2X : .multisampling4X }
    var ambientOcclusion: Bool { self == .rich }
    var depthOfField: Bool { self == .rich }
}

/// SceneKit materials for the blueprint's `Material`s, physically based and
/// textured with the procedural maps in `Textures/` (see Tools/make_textures.py).
/// Made once per texture tiling and shared.
@MainActor
enum MaterialLibrary {
    private static var cache: [String: SCNMaterial] = [:]

    /// The material for a piece whose longest side is `length` world units.
    /// `upright` turns the wood grain to run up and down.
    static func material(_ kind: Material, length: Double = 1, upright: Bool = false) -> SCNMaterial {
        // Repeat textures about every 1.6 units, rounded so similar pieces share.
        let repeats = max(1, (length / 1.6 * 2).rounded() / 2)
        let key = "\(kind.rawValue)-\(repeats)-\(upright)"
        if let cached = cache[key] { return cached }
        let material = make(kind)
        let transform = upright
            ? SCNMatrix4Mult(SCNMatrix4MakeScale(Float(repeats), 1, 1), SCNMatrix4MakeRotation(.pi / 2, 0, 0, 1))
            : SCNMatrix4MakeScale(Float(repeats), 1, 1)
        for property in [material.diffuse, material.normal, material.roughness] {
            property.wrapS = .repeat
            property.wrapT = .repeat
            property.contentsTransform = transform
        }
        cache[key] = material
        return material
    }

    private static func make(_ kind: Material) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.roughness.contents = 0.85
        m.metalness.contents = 0.0
        switch kind {
        case .wood:
            textured(m, "wood_albedo.jpg", normal: "wood_normal.png", roughness: "wood_roughness.jpg")
        case .darkWood:
            textured(m, "wood_albedo.jpg", normal: "wood_normal.png", roughness: "wood_roughness.jpg")
            m.multiply.contents = UIColor(red: 0.55, green: 0.45, blue: 0.4, alpha: 1)
        case .mossyWood:
            textured(m, "mossywood_albedo.jpg", normal: "mossywood_normal.png", roughness: "mossywood_roughness.jpg")
        case .moss:
            textured(m, "moss_albedo.jpg", normal: "moss_normal.png")
            m.roughness.contents = 1.0
        case .bark:
            textured(m, "bark_albedo.jpg", normal: "bark_normal.png")
            m.roughness.contents = 0.95
        case .leaves:
            textured(m, "leaves_albedo.jpg")
        case .forestFloor:
            textured(m, "forest_albedo.jpg")
            m.roughness.contents = 1.0
        case .rug:
            textured(m, "rug_albedo.jpg")
            m.roughness.contents = 0.95
        case .quilt:
            textured(m, "quilt_albedo.jpg")
            m.roughness.contents = 0.95
        case .linen:
            textured(m, "linen_albedo.jpg")
            m.roughness.contents = 0.9
        case .plush:
            textured(m, "plush_albedo.jpg")
            m.roughness.contents = 1.0
        case .rope:
            m.diffuse.contents = UIColor(red: 0.45, green: 0.36, blue: 0.22, alpha: 1)
        case .iron:
            m.diffuse.contents = UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
            m.metalness.contents = 0.85
            m.roughness.contents = 0.45
        case .wax:
            m.diffuse.contents = UIColor(red: 0.92, green: 0.86, blue: 0.72, alpha: 1)
            m.roughness.contents = 0.5
        case .bookRed:
            m.diffuse.contents = UIColor(red: 0.45, green: 0.1, blue: 0.08, alpha: 1)
        case .bookGreen:
            m.diffuse.contents = UIColor(red: 0.12, green: 0.3, blue: 0.16, alpha: 1)
        case .bookBlue:
            m.diffuse.contents = UIColor(red: 0.1, green: 0.18, blue: 0.38, alpha: 1)
        case .mushroomStem:
            m.diffuse.contents = UIColor(red: 0.85, green: 0.82, blue: 0.72, alpha: 1)
            m.roughness.contents = 0.6
        case .flame:
            glow(m, red: 1.0, green: 0.55, blue: 0.18, strength: 2.5)
        case .lanternGlass:
            glow(m, red: 1.0, green: 0.62, blue: 0.3, strength: 1.3)
        case .moonGlass:
            glow(m, red: 0.55, green: 0.68, blue: 1.0, strength: 0.7)
        case .mushroomGlow:
            glow(m, red: 0.3, green: 0.95, blue: 0.8, strength: 1.1)
        case .doorGlow:
            glow(m, red: 1.0, green: 0.66, blue: 0.32, strength: 1.1)
        case .jarGlow:
            glow(m, red: 0.75, green: 1.0, blue: 0.35, strength: 1.3)
        case .void:
            m.lightingModel = .constant
            m.diffuse.contents = UIColor.black
        }
        return m
    }

    private static func textured(_ m: SCNMaterial, _ albedo: String, normal: String? = nil, roughness: String? = nil) {
        m.diffuse.contents = UIImage(named: albedo)
        if let normal {
            m.normal.contents = UIImage(named: normal)
            m.normal.intensity = 0.8
        }
        if let roughness {
            m.roughness.contents = UIImage(named: roughness)
        }
    }

    /// Lit from within; the brightest of these get a soft bloom.
    private static func glow(_ m: SCNMaterial, red: CGFloat, green: CGFloat, blue: CGFloat, strength: CGFloat) {
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1)
        m.diffuse.contents = color.withAlphaComponent(1).multiplied(by: 0.3)
        m.emission.contents = color
        m.emission.intensity = strength
    }
}

extension UIColor {
    convenience init(_ rgb: SIMD3<Double>) {
        self.init(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: 1)
    }

    fileprivate func multiplied(by factor: CGFloat) -> UIColor {
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * factor, green: g * factor, blue: b * factor, alpha: a)
    }
}
