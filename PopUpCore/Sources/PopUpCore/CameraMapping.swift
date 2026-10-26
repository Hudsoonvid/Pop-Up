import Foundation

/// Turns the hinge angle into how far the camera tilts down.
///
/// Barely open (60°) peeks in from the side like a dollhouse. Flat (180°)
/// looks straight down like a map. In between it blends evenly, so the hinge
/// feels like a dial. Below 60° the view stays at the side view.
public struct CameraMapping {
    public var sideHinge = 60.0
    public var flatHinge = 180.0
    /// Tilt at the side view: a little above level so you can see the floor.
    public var sideTilt = 8.0
    /// Tilt when flat: straight down.
    public var topTilt = 90.0

    public init() {}

    /// Camera tilt in degrees down from level (0 is level, 90 is straight down).
    public func tilt(forHinge hinge: Double) -> Double {
        let t = min(max((hinge - sideHinge) / (flatHinge - sideHinge), 0), 1)
        return sideTilt + (topTilt - sideTilt) * t
    }
}

/// The perspective camera for a room. It swings on an arc around `pivot`:
/// tilting raises it from the side view to straight overhead. It never moves
/// sideways, so the paths that line up at one tilt always line up at that tilt.
public struct CameraRig: Codable, Equatable {
    /// The point the camera looks at, in the middle of the room.
    public var pivot: SIMD3<Double>
    /// How far the camera sits from `pivot`.
    public var distance: Double
    /// How far the camera swings round to the right of straight-on, in degrees.
    public var yaw: Double
    /// The width and height around `pivot` that should stay on screen.
    public var frame: SIMD2<Double>

    public init(pivot: SIMD3<Double>, distance: Double = 22, yaw: Double = 0, frame: SIMD2<Double> = [14.5, 10]) {
        self.pivot = pivot
        self.distance = distance
        self.yaw = yaw
        self.frame = frame
    }

    public func position(tilt: Double) -> SIMD3<Double> {
        let t = radians(tilt)
        let y = radians(yaw)
        return pivot + SIMD3(cos(t) * sin(y), sin(t), cos(t) * cos(y)) * distance
    }

    public struct Basis {
        public var right: SIMD3<Double>
        public var up: SIMD3<Double>
        /// The way the camera looks.
        public var forward: SIMD3<Double>
    }

    public func basis(tilt: Double) -> Basis {
        let t = radians(tilt)
        let y = radians(yaw)
        return Basis(
            right: [cos(y), 0, -sin(y)],
            up: [-sin(t) * sin(y), cos(t), -sin(t) * cos(y)],
            forward: [-cos(t) * sin(y), -sin(t), -cos(t) * cos(y)])
    }

    /// Vertical field of view, in degrees, that keeps `frame` on a screen of this
    /// width-to-height `aspect`. Changing it never changes what lines up.
    public func fieldOfView(aspect: Double) -> Double {
        let height = max(frame.y, frame.x / max(aspect, 0.1))
        return 2 * atan(height / 2 / distance) * 180 / .pi
    }

    /// Where `point` lands on screen, with y up and both axes measured in
    /// half-heights of the view (so the top edge is y = 1). Nil if it's behind
    /// the camera.
    public func project(_ point: SIMD3<Double>, tilt: Double, fieldOfView: Double = 30) -> SIMD2<Double>? {
        let basis = basis(tilt: tilt)
        let offset = point - position(tilt: tilt)
        let depth = dotProduct(offset, basis.forward)
        guard depth > 0 else { return nil }
        let scale = 1 / (depth * tan(radians(fieldOfView) / 2))
        return [dotProduct(offset, basis.right) * scale, dotProduct(offset, basis.up) * scale]
    }

    /// Slides `point` along its line of sight by `scale` of its distance from
    /// the camera. Below 1 brings it nearer (and, with the camera above, higher).
    /// From `tilt` the moved point lands exactly where `point` does on screen,
    /// and something shrunk by the same `scale` looks exactly the same size.
    public func alongSight(_ point: SIMD3<Double>, tilt: Double, scale: Double) -> SIMD3<Double> {
        let camera = position(tilt: tilt)
        return camera + (point - camera) * scale
    }
}
