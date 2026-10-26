import Foundation

// Small vector helpers. PopUpCore avoids the `simd` module so it builds on Linux too.

func dotProduct(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    (a * b).sum()
}

func length(of v: SIMD3<Double>) -> Double {
    dotProduct(v, v).squareRoot()
}

func radians(_ degrees: Double) -> Double {
    degrees * .pi / 180
}

/// A rotation stored as its three columns.
public struct Rotation: Equatable {
    public var x: SIMD3<Double>
    public var y: SIMD3<Double>
    public var z: SIMD3<Double>

    public static let identity = Rotation(x: [1, 0, 0], y: [0, 1, 0], z: [0, 0, 1])

    /// The rotation for a piece's `rotation` angles, in degrees: roll about z
    /// first, then pitch about x, then yaw about y (so yaw is outermost).
    /// The app and the Blender preview both build rotations this way.
    public init(degrees angles: SIMD3<Double>) {
        let (px, py, pz) = (radians(angles.x), radians(angles.y), radians(angles.z))
        let rx = Rotation(x: [1, 0, 0], y: [0, cos(px), sin(px)], z: [0, -sin(px), cos(px)])
        let ry = Rotation(x: [cos(py), 0, -sin(py)], y: [0, 1, 0], z: [sin(py), 0, cos(py)])
        let rz = Rotation(x: [cos(pz), sin(pz), 0], y: [-sin(pz), cos(pz), 0], z: [0, 0, 1])
        self = ry * rx * rz
    }

    init(x: SIMD3<Double>, y: SIMD3<Double>, z: SIMD3<Double>) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static func * (a: Rotation, v: SIMD3<Double>) -> SIMD3<Double> {
        a.x * v.x + a.y * v.y + a.z * v.z
    }

    public static func * (a: Rotation, b: Rotation) -> Rotation {
        Rotation(x: a * b.x, y: a * b.y, z: a * b.z)
    }

    /// The inverse, which for a rotation is its transpose.
    public var inverse: Rotation {
        Rotation(x: [x.x, y.x, z.x], y: [x.y, y.y, z.y], z: [x.z, y.z, z.z])
    }
}

/// Whether the straight segment from `a` to `b` passes through a box of size
/// `size` centred on `center` and turned by `rotation`. The ends themselves
/// don't count, so a point resting on a surface isn't hidden by it.
func segmentHitsBox(from a: SIMD3<Double>, to b: SIMD3<Double>,
                    center: SIMD3<Double>, size: SIMD3<Double>, rotation: Rotation) -> Bool {
    let toLocal = rotation.inverse
    let start = toLocal * (a - center)
    let delta = toLocal * (b - a)
    let half = size / 2
    var enter = 1e-6
    var leave = 1 - 1e-6
    for axis in 0..<3 {
        if abs(delta[axis]) < 1e-12 {
            if abs(start[axis]) > half[axis] { return false }
            continue
        }
        var t0 = (-half[axis] - start[axis]) / delta[axis]
        var t1 = (half[axis] - start[axis]) / delta[axis]
        if t0 > t1 { swap(&t0, &t1) }
        enter = max(enter, t0)
        leave = min(leave, t1)
        if enter > leave { return false }
    }
    return true
}

/// Reproducible scatter for moss, planks and props, so a level looks the same
/// every time and in the preview renders. SplitMix64.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }

    mutating func next(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * next()
    }
}
