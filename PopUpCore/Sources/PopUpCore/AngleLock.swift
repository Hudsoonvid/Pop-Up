/// Decides when the player has found the click angle and held it there.
///
/// The path clicks into place only after the angle has stayed near the target,
/// and nearly still, for `holdTime`. Folding fast never helps: moving quickly
/// resets the hold. Once locked it stays locked until the angle drifts past the
/// wider `releaseTolerance`, so a small wobble doesn't break the click.
public struct AngleLock {
    public enum Phase: Equatable {
        case searching
        /// Near the target and still; `progress` runs from 0 to 1 over `holdTime`.
        case holding(progress: Double)
        case locked
    }

    public enum Event: Equatable {
        case locked
        case released
    }

    /// The hinge angle that lines the path up, in degrees.
    public var target: Double
    /// How close counts as "on it", in degrees.
    public var tolerance: Double
    /// How far it can drift once locked before it lets go, in degrees.
    public var releaseTolerance: Double
    /// How long to hold still before it clicks, in seconds.
    public var holdTime: Double
    /// Faster than this (degrees per second) doesn't count as holding still.
    public var maxStillSpeed: Double

    public private(set) var phase: Phase = .searching
    private var heldFor: Double = 0

    public var isLocked: Bool { phase == .locked }

    public init(
        target: Double,
        tolerance: Double = 4,
        releaseTolerance: Double = 8,
        holdTime: Double = 0.5,
        maxStillSpeed: Double = 20
    ) {
        self.target = target
        self.tolerance = tolerance
        self.releaseTolerance = releaseTolerance
        self.holdTime = holdTime
        self.maxStillSpeed = maxStillSpeed
    }

    /// Feeds in the smoothed angle and its speed for this frame.
    /// Returns an event on the frame it locks or lets go.
    @discardableResult
    public mutating func update(angle: Double, speed: Double, dt: Double) -> Event? {
        let offset = abs(angle - target)

        if phase == .locked {
            guard offset > releaseTolerance else { return nil }
            reset()
            return .released
        }

        guard offset <= tolerance, abs(speed) <= maxStillSpeed else {
            reset()
            return nil
        }
        heldFor += dt
        if heldFor >= holdTime {
            phase = .locked
            return .locked
        }
        phase = .holding(progress: heldFor / holdTime)
        return nil
    }

    public mutating func reset() {
        phase = .searching
        heldFor = 0
    }
}
