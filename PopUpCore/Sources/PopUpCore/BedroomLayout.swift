import Foundation

/// Where everything goes in the bedroom, worked out from the hinge angle the
/// door should line up at.
///
/// The paper guy walks left to right, from the bed to the door. The first half
/// of his path is a rug on the floor. The second half is a rug on a stack of
/// books: higher up, and nearer the camera. With an orthographic camera, two
/// points look like one when the line between them points straight at the
/// camera, so the books are exactly as tall as it takes for that to happen at
/// `alignHinge`. At any other angle the two rugs show a step and he can't cross.
///
/// Change `alignHinge` and the books resize themselves, so the illusion stays
/// exact for whatever angle playtesting settles on.
public struct BedroomLayout {
    /// The hinge angle where the rugs meet, in degrees.
    public let alignHinge: Double
    /// Camera tilt at `alignHinge`, in degrees down from level.
    public let alignTilt: Double
    /// Height of the book stack's top, derived from `alignTilt`.
    public let ledgeHeight: Double

    /// Depth of the floor rug (z grows toward the camera).
    public let floorZ = -1.0
    /// How much nearer the camera the book rug is than the floor rug.
    public let forwardShift = 2.2
    /// Depth of the book rug.
    public var ledgeZ: Double { floorZ + forwardShift }

    /// Where the floor rug begins, next to the bed.
    public let rugStartX = -2.7
    /// Where the floor rug ends and the top book begins.
    public let edgeX = 0.4
    /// Right-hand end of the books.
    public let ledgeEndX = 3.9
    public let doorX = 3.2
    /// Front-to-back size of both rugs. They match so they join cleanly on screen.
    public let pathDepth = 0.6
    public let rugThickness = 0.02
    public let guyHalfWidth = 0.25

    public init(alignHinge: Double, mapping: CameraMapping = CameraMapping()) {
        self.alignHinge = alignHinge
        alignTilt = mapping.tilt(forHinge: alignHinge)
        // Rising by `forwardShift * tan(tilt)` while moving `forwardShift`
        // toward the camera keeps a point on the same line of sight.
        ledgeHeight = forwardShift * tan(alignTilt * .pi / 180)
    }

    /// Beside the bed.
    public var start: SIMD3<Double> { [-2.4, rugThickness, floorZ] }

    /// Last spot on the floor rug: his front edge touches the books on screen.
    public var floorEnd: SIMD3<Double> { [edgeX - guyHalfWidth, rugThickness, floorZ] }

    /// The spot on the book rug that sits exactly over `floorEnd` on screen at
    /// the click angle. He jumps here from `floorEnd`.
    public var ledgeStart: SIMD3<Double> { [edgeX - guyHalfWidth, ledgeHeight + rugThickness, ledgeZ] }

    /// In front of the door.
    public var doorStep: SIMD3<Double> { [doorX, ledgeHeight + rugThickness, ledgeZ] }

    /// The walk from the gap to the door, once the path has clicked.
    public var crossingRoute: [PathWalker.Waypoint] {
        [.walk(to: floorEnd), .jump(to: ledgeStart), .walk(to: doorStep)]
    }
}
