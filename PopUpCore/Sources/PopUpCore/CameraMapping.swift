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

/// Screen maths for the orthographic camera. It only tilts; it never turns
/// left or right, so a point's screen x is just its world x.
public enum OrthoCamera {
    /// Height on screen of a world point (y up, z toward the camera) when the
    /// camera is tilted `tilt` degrees down.
    public static func screenY(of point: SIMD3<Double>, tilt: Double) -> Double {
        let radians = tilt * .pi / 180
        return point.y * cos(radians) - point.z * sin(radians)
    }
}
