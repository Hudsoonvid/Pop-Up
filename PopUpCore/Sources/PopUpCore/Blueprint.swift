import Foundation

/// Everything needed to build and play one room: what's in it, where the lights
/// and particles go, and the routes the traveller walks. The app turns it into
/// a SceneKit scene, the tests check its illusions, and the preview script
/// renders it.
public struct Blueprint: Codable {
    public var id: String
    public var title: String
    /// The hint shown when the room starts.
    public var intro: String
    public var rig: CameraRig
    public var lock: LockSettings
    public var atmosphere: Atmosphere
    public var pieces: [Piece]
    public var lights: [Light]
    public var emitters: [Emitter]
    /// A point on the line the backdrop folds down along, like the crease of a
    /// pop-up flap. The line runs along x.
    public var backdropHinge: SIMD3<Double>
    public var start: SIMD3<Double>
    /// The route once the path has clicked.
    public var crossing: [PathWalker.Waypoint]
    /// The route when tapped too early: up to the gap, where he stops.
    public var stuck: [PathWalker.Waypoint]
    /// Rooms where he only sets off safely when he can see the danger.
    public var trap: Trap?
    /// Where he steps through the door at the end, and his size there.
    public var exit: SIMD3<Double>
    public var exitScale: Double
}

public struct LockSettings: Codable, Equatable {
    /// The hinge angle that lines things up, in degrees.
    public var target: Double
    public var tolerance: Double
    public var releaseTolerance: Double
}

public struct Atmosphere: Codable {
    public var fogColor: SIMD3<Double>
    public var fogStart: Double
    public var fogEnd: Double
    /// How strongly the sky lights the room (the rest is lamps and candles).
    public var skyLight: Double
}

/// A trap that he walks straight into unless the camera can see it.
public struct Trap: Codable {
    /// The middle of the trap. He notices it only when this is in view.
    public var point: SIMD3<Double>
    /// The way out. He knows where to go only when this is in view.
    public var exitPoint: SIMD3<Double>
    /// The route straight into the trap.
    public var fall: [PathWalker.Waypoint]
}

public struct Piece: Codable {
    public enum Shape: String, Codable {
        /// size = width, height, depth.
        case box
        /// size = radius, height, unused. Upright along y.
        case cylinder
        /// size = radius, unused, unused.
        case sphere
        /// size = top radius, bottom radius, height. Upright along y.
        case cone
        /// size = ring radius, pipe radius, unused. Lies flat in x-z.
        case torus
    }

    /// How a piece moves when the book opens and closes.
    public enum Layer: String, Codable {
        /// Floors and the paths he walks on. The page itself: it never moves, so
        /// the illusions stay exact.
        case page
        /// Walls and windows. They fold back flat along `backdropHinge`.
        case backdrop
        /// Furniture, lamps, moss and mushrooms. They spring up from the floor.
        case props
        /// The forest around the book. It stays put.
        case scenery
    }

    public var shape: Shape
    public var size: SIMD3<Double>
    public var position: SIMD3<Double>
    /// Degrees; see `Rotation(degrees:)` for the order.
    public var rotation: SIMD3<Double>
    /// Stretch on top of `size`, mostly for squashed moss and mushroom caps.
    public var scale: SIMD3<Double>
    /// Rounded box edges.
    public var chamfer: Double
    public var material: Material
    public var layer: Layer
    /// Names a piece the app animates, such as "door".
    public var tag: String?
    /// Counts for line-of-sight checks, like the attic's fallen beam.
    public var occludes: Bool
}

public enum Material: String, Codable, CaseIterable {
    case wood, darkWood, mossyWood, moss, bark, leaves, forestFloor
    case rug, quilt, linen, plush, rope, iron, wax
    case bookRed, bookGreen, bookBlue
    /// Things that give off light.
    case flame, lanternGlass, moonGlass, mushroomGlow, doorGlow, jarGlow
    case mushroomStem, void

    public var glows: Bool {
        switch self {
        case .flame, .lanternGlass, .moonGlass, .mushroomGlow, .doorGlow, .jarGlow: return true
        default: return false
        }
    }
}

public struct Light: Codable {
    public enum Kind: String, Codable { case directional, omni, spot }

    public var kind: Kind
    public var color: SIMD3<Double>
    /// Lumens, as SceneKit uses for physically based lighting.
    public var intensity: Double
    public var position: SIMD3<Double>
    /// What a directional or spot light points at.
    public var target: SIMD3<Double>
    /// Where the light fades out completely.
    public var range: Double
    public var spotAngle: Double
    public var castsShadow: Bool
    /// Flickers like a flame.
    public var flickers: Bool
}

public struct Emitter: Codable {
    public enum Kind: String, Codable {
        /// Specks drifting in lamplight.
        case dust
        /// Blinking green-gold lights.
        case fireflies
        /// Leaves tumbling down.
        case leaves
        /// Glowing specks rising off mushrooms.
        case spores
    }

    public var kind: Kind
    public var center: SIMD3<Double>
    public var extent: SIMD3<Double>
}

extension Blueprint {
    /// Whether `point` is in view from the camera at `tilt`: nothing that
    /// `occludes` sits between them.
    public func canSee(_ point: SIMD3<Double>, tilt: Double) -> Bool {
        let camera = rig.position(tilt: tilt)
        return !pieces.contains { piece in
            piece.occludes && piece.shape == .box && segmentHitsBox(
                from: point, to: camera, center: piece.position, size: piece.size * piece.scale,
                rotation: Rotation(degrees: piece.rotation))
        }
    }
}

// MARK: - Building rooms

/// Collects pieces, lights and emitters while a room is laid out.
struct RoomBuilder {
    var pieces: [Piece] = []
    var lights: [Light] = []
    var emitters: [Emitter] = []
    var random: SeededRandom
    /// The layer new pieces go on.
    var layer = Piece.Layer.props

    init(seed: UInt64) {
        random = SeededRandom(seed: seed)
    }

    mutating func on(_ layer: Piece.Layer, _ build: (inout RoomBuilder) -> Void) {
        let previous = self.layer
        self.layer = layer
        build(&self)
        self.layer = previous
    }

    mutating func box(_ size: SIMD3<Double>, at position: SIMD3<Double>, _ material: Material,
                      rotation: SIMD3<Double> = .zero, chamfer: Double = 0,
                      tag: String? = nil, occludes: Bool = false) {
        add(.box, size, position, material, rotation: rotation, chamfer: chamfer, tag: tag, occludes: occludes)
    }

    mutating func cylinder(radius: Double, height: Double, at position: SIMD3<Double>, _ material: Material,
                           rotation: SIMD3<Double> = .zero) {
        add(.cylinder, [radius, height, 0], position, material, rotation: rotation)
    }

    mutating func sphere(radius: Double, at position: SIMD3<Double>, _ material: Material,
                         scale: SIMD3<Double> = [1, 1, 1], rotation: SIMD3<Double> = .zero) {
        add(.sphere, [radius, 0, 0], position, material, rotation: rotation, scale: scale)
    }

    mutating func cone(top: Double, bottom: Double, height: Double, at position: SIMD3<Double>,
                       _ material: Material, rotation: SIMD3<Double> = .zero) {
        add(.cone, [top, bottom, height], position, material, rotation: rotation)
    }

    mutating func torus(ring: Double, pipe: Double, at position: SIMD3<Double>, _ material: Material,
                        rotation: SIMD3<Double> = .zero) {
        add(.torus, [ring, pipe, 0], position, material, rotation: rotation)
    }

    private mutating func add(_ shape: Piece.Shape, _ size: SIMD3<Double>, _ position: SIMD3<Double>,
                              _ material: Material, rotation: SIMD3<Double> = .zero,
                              scale: SIMD3<Double> = [1, 1, 1], chamfer: Double = 0,
                              tag: String? = nil, occludes: Bool = false) {
        pieces.append(Piece(shape: shape, size: size, position: position, rotation: rotation, scale: scale,
                            chamfer: chamfer, material: material, layer: layer, tag: tag, occludes: occludes))
    }

    mutating func light(_ kind: Light.Kind, color: SIMD3<Double>, intensity: Double, at position: SIMD3<Double>,
                        target: SIMD3<Double> = .zero, range: Double = 10, spotAngle: Double = 90,
                        shadow: Bool = false, flickers: Bool = false) {
        lights.append(Light(kind: kind, color: color, intensity: intensity, position: position, target: target,
                            range: range, spotAngle: spotAngle, castsShadow: shadow, flickers: flickers))
    }

    mutating func emit(_ kind: Emitter.Kind, at center: SIMD3<Double>, extent: SIMD3<Double>) {
        emitters.append(Emitter(kind: kind, center: center, extent: extent))
    }

    // MARK: Floors and walls

    /// A floor of planks running along x, top at `top`. Planks crossing the
    /// `keep` depths reach exactly to `x.upperBound`; the rest end raggedly,
    /// like boards that have rotted away, unless `ragged` is false. Planks
    /// crossing `hole` stop short of it and start again after it.
    mutating func plankFloor(x: ClosedRange<Double>, z: ClosedRange<Double>, top: Double,
                             keep: ClosedRange<Double>? = nil, ragged: Bool = true,
                             hole: (x: ClosedRange<Double>, z: ClosedRange<Double>)? = nil) {
        let width = 0.42
        let count = Int(((z.upperBound - z.lowerBound) / width).rounded(.up))
        for lane in 0..<count {
            let zc = min(z.lowerBound + (Double(lane) + 0.5) * width, z.upperBound - width / 2)
            let laneRange = (zc - width / 2)...(zc + width / 2)
            let mustReach = keep.map { $0.overlaps(laneRange) } ?? false
            var end = x.upperBound
            if ragged && !mustReach { end += random.next(-0.7 ... 0.25) }
            var start = x.lowerBound
            if let hole, hole.z.overlaps(laneRange) {
                // Broken ends only ever widen the hole, never cover it.
                plank(from: start, to: hole.x.lowerBound - random.next(0 ... 0.15), z: zc, top: top, width: width)
                start = hole.x.upperBound + random.next(0 ... 0.15)
            }
            plank(from: start, to: end, z: zc, top: top, width: width)
        }
    }

    private mutating func plank(from x0: Double, to x1: Double, z: Double, top: Double, width: Double) {
        guard x1 - x0 > 0.05 else { return }
        let thickness = 0.16
        let material: Material = random.next() < 0.4 ? .mossyWood : .wood
        box([x1 - x0, thickness, width - 0.025], at: [(x0 + x1) / 2, top - thickness / 2, z], material, chamfer: 0.015)
    }

    /// A wall of upright boards along x at depth `z`, with heights from `height`.
    mutating func boardWall(x: ClosedRange<Double>, z: Double, bottom: Double, height: (Double) -> Double) {
        let width = 0.5
        var x0 = x.lowerBound
        while x0 < x.upperBound - 0.01 {
            let x1 = min(x0 + width, x.upperBound)
            let h = height((x0 + x1) / 2) + random.next(-0.12 ... 0.12)
            let material: Material = random.next() < 0.45 ? .mossyWood : .wood
            box([x1 - x0 - 0.02, h, 0.12], at: [(x0 + x1) / 2, bottom + h / 2, z], material,
                rotation: [0, 0, random.next(-0.8 ... 0.8)], chamfer: 0.02)
            x0 = x1
        }
    }

    // MARK: Props

    /// Soft lumps of moss scattered along a line.
    mutating func moss(from a: SIMD3<Double>, to b: SIMD3<Double>, count: Int, size: ClosedRange<Double> = 0.12...0.26) {
        for i in 0..<count {
            let t = (Double(i) + random.next(0.2 ... 0.8)) / Double(count)
            let r = random.next(size)
            let p = a + (b - a) * t
            sphere(radius: r, at: p + [0, r * 0.15, 0], .moss,
                   scale: [random.next(1 ... 1.6), random.next(0.3 ... 0.5), random.next(1 ... 1.4)],
                   rotation: [0, random.next(0 ... 180), 0])
        }
    }

    /// Strands of moss hanging down from a beam.
    mutating func hangingMoss(from a: SIMD3<Double>, to b: SIMD3<Double>, count: Int) {
        for i in 0..<count {
            let t = (Double(i) + random.next(0.2 ... 0.8)) / Double(count)
            let drop = random.next(0.3 ... 0.9)
            let p = a + (b - a) * t
            cylinder(radius: random.next(0.025 ... 0.045), height: drop, at: p - [0, drop / 2, 0], .moss)
        }
    }

    /// Glowing mushrooms with rising spores. Only give a cluster or two a light
    /// of its own: every light costs a lot on the simulator.
    mutating func mushrooms(at base: SIMD3<Double>, count: Int, spread: Double = 0.35, lit: Bool = false) {
        for _ in 0..<count {
            let p = base + [random.next(-spread ... spread), 0, random.next(-spread ... spread)]
            let h = random.next(0.08 ... 0.24)
            let r = random.next(0.05 ... 0.11)
            cylinder(radius: r * 0.28, height: h, at: p + [0, h / 2, 0], .mushroomStem)
            sphere(radius: r, at: p + [0, h, 0], .mushroomGlow, scale: [1, 0.55, 1])
        }
        if lit {
            light(.omni, color: [0.35, 0.95, 0.85], intensity: 260, at: base + [0, 0.35, 0], range: 2.4)
        }
        emit(.spores, at: base + [0, 0.35, 0], extent: [spread * 2, 0.3, spread * 2])
    }

    /// A candle, with a flickering light if `lit`.
    mutating func candle(at base: SIMD3<Double>, height: Double = 0.22, lit: Bool = false) {
        cylinder(radius: 0.055, height: height, at: base + [0, height / 2, 0], .wax)
        sphere(radius: 0.032, at: base + [0, height + 0.05, 0], .flame, scale: [1, 1.7, 1])
        if lit {
            light(.omni, color: [1.0, 0.62, 0.3], intensity: 420, at: base + [0, height + 0.12, 0],
                  range: 3.2, flickers: true)
        }
    }

    /// A lantern hanging on a rope from `ceiling`, lighting the floor below.
    /// It's the room's one shadow-casting light.
    mutating func hangingLantern(at position: SIMD3<Double>, ceiling: Double, aimAt target: SIMD3<Double>) {
        let rope = ceiling - position.y - 0.18
        cylinder(radius: 0.015, height: rope, at: [position.x, position.y + 0.18 + rope / 2, position.z], .rope)
        cone(top: 0.03, bottom: 0.15, height: 0.1, at: position + [0, 0.15, 0], .iron)
        box([0.2, 0.24, 0.2], at: position, .lanternGlass, chamfer: 0.02)
        box([0.24, 0.03, 0.24], at: position - [0, 0.13, 0], .iron)
        light(.spot, color: [1.0, 0.66, 0.36], intensity: 2800, at: position - [0, 0.1, 0], target: target,
              range: 11, spotAngle: 120, shadow: true, flickers: true)
        emit(.dust, at: (position + target) / 2, extent: [2.6, max(position.y - target.y, 1), 2.2])
    }

    /// A lantern on a short mossy post, lighting the faces the moon misses.
    mutating func lanternPost(at base: SIMD3<Double>) {
        cylinder(radius: 0.06, height: 1.1, at: base + [0, 0.55, 0], .darkWood)
        box([0.3, 0.05, 0.05], at: base + [0.12, 1.08, 0], .iron)
        let lantern = base + [0.24, 0.92, 0]
        box([0.15, 0.2, 0.15], at: lantern, .lanternGlass, chamfer: 0.015)
        cone(top: 0.02, bottom: 0.11, height: 0.07, at: lantern + [0, 0.13, 0], .iron)
        moss(from: base + [-0.1, 0, 0], to: base + [0.1, 0, 0], count: 2, size: 0.1...0.16)
        light(.omni, color: [1.0, 0.68, 0.38], intensity: 700, at: lantern + [0, 0, 0.2], range: 4.5, flickers: true)
    }

    /// A round window with a wooden frame, glowing with moonlight.
    mutating func roundWindow(at center: SIMD3<Double>, radius: Double) {
        cylinder(radius: radius, height: 0.04, at: center, .moonGlass, rotation: [90, 0, 0])
        torus(ring: radius, pipe: 0.07, at: center + [0, 0, 0.03], .darkWood, rotation: [90, 0, 0])
        box([radius * 2, 0.05, 0.05], at: center + [0, 0, 0.04], .darkWood)
        box([0.05, radius * 2, 0.05], at: center + [0, 0, 0.04], .darkWood)
    }

    /// A door standing with its bottom middle at `base`, facing the camera,
    /// with warm light glowing round it from the next room. `scale` shrinks
    /// it for doors on the near side of an illusion.
    mutating func door(at base: SIMD3<Double>, scale s: Double) {
        let (w, h) = (0.82 * s, 1.4 * s)
        box([w, h, 0.02 * s], at: base + [0, h / 2, -0.07 * s], .doorGlow)
        box([w, h, 0.06 * s], at: base + [0, h / 2, 0], .darkWood, chamfer: 0.01 * s, tag: "door")
        let frame = 0.1 * s
        box([frame, h + frame, 0.12 * s], at: base + [-(w + frame) / 2, (h + frame) / 2, 0], .mossyWood)
        box([frame, h + frame, 0.12 * s], at: base + [(w + frame) / 2, (h + frame) / 2, 0], .mossyWood)
        box([w + frame * 2.4, frame, 0.14 * s], at: base + [0, h + frame / 2, 0], .mossyWood)
        moss(from: base + [-(w / 2 + frame), h + frame, 0], to: base + [w / 2 + frame, h + frame, 0], count: 4,
             size: (0.06 * s)...(0.13 * s))
        // A little lantern on the frame, so the way out always glows.
        let lantern = base + [w / 2 + frame * 1.6, h * 0.82, 0.1 * s]
        box([0.13, 0.17, 0.13] * s, at: lantern, .lanternGlass, chamfer: 0.015 * s)
        cone(top: 0.02 * s, bottom: 0.1 * s, height: 0.07 * s, at: lantern + [0, 0.12 * s, 0], .iron)
        box([0.04, 0.04, 0.16] * s, at: lantern + [0, 0.17 * s, -0.08 * s], .iron)
        light(.omni, color: [1.0, 0.7, 0.4], intensity: 900, at: lantern + [0, 0, 0.25 * s], range: 4.5, flickers: true)
    }

    /// The forest far below and the trunks of the great tree, lost in fog.
    mutating func forest(below floor: Double) {
        on(.scenery) { b in
            let ground = floor - 16
            b.box([90, 1, 90], at: [0, ground - 0.5, -10], .forestFloor)
            // The great tree right behind the room, the rest far back in the fog.
            let trunks: [(SIMD3<Double>, Double)] = [
                ([-1.5, 0, -5.4], 1.7), ([9.5, 0, -12], 1.3), ([-11, 0, -11], 1.5), ([5, 0, -19], 1.1),
                ([-6, 0, -21], 1.2), ([16, 0, -9], 1.0), ([-17, 0, -13], 1.1),
            ]
            for (p, r) in trunks {
                b.cylinder(radius: r, height: 50, at: [p.x, ground + 25, p.z], .bark)
            }
            // Canopy well off to the sides, so it never blocks the view from above.
            let canopy: [SIMD3<Double>] = [[-12, 8, -9], [11, 9, -10], [-4, 10, -16], [15, 6, -4], [-16, 7, -1]]
            for p in canopy {
                b.sphere(radius: b.random.next(3 ... 4.5), at: p, .leaves, scale: [1.3, 0.8, 1.2])
            }
        }
    }
}
