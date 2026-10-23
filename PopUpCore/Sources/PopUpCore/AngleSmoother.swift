import Foundation

/// Glides toward the latest hinge reading so the camera never jitters.
///
/// Apple doesn't promise how often hinge readings arrive or how precise they
/// are, so the camera never follows them directly. Every frame the smoothed
/// angle moves toward the newest reading on a critically damped spring: it
/// doesn't overshoot, and its speed changes gradually even when readings
/// arrive in steps.
public struct AngleSmoother {
    /// Roughly how long it takes to catch up with a new reading, in seconds.
    public var smoothTime: Double
    /// Changes smaller than this, in degrees, are treated as sensor noise.
    public var deadband: Double

    public private(set) var value: Double
    /// How fast the smoothed angle is moving, in degrees per second.
    public private(set) var velocity: Double = 0
    private var target: Double

    public init(initial: Double, smoothTime: Double = 0.15, deadband: Double = 0.3) {
        self.smoothTime = smoothTime
        self.deadband = deadband
        value = initial
        target = initial
    }

    /// Advances by `dt` seconds toward `reading` and returns the new smoothed angle.
    @discardableResult
    public mutating func step(toward reading: Double, dt: Double) -> Double {
        if abs(reading - target) > deadband {
            target = reading
        }
        guard dt > 0 else { return value }

        // Critically damped spring, from Game Programming Gems 4 ("Critically
        // Damped Ease-In/Ease-Out Smoothing"). Stable for any frame time.
        let omega = 2 / max(smoothTime, 0.0001)
        let x = omega * dt
        let decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
        let offset = value - target
        let push = (velocity + omega * offset) * dt
        velocity = (velocity - omega * push) * decay
        value = target + (offset + push) * decay
        return value
    }

    public mutating func reset(to angle: Double) {
        value = angle
        target = angle
        velocity = 0
    }
}

/// Moves `value` toward `target`, covering half the remaining distance every
/// `halfLife` seconds, and lands exactly on `target` once it's close.
public func approach(_ value: Double, to target: Double, dt: Double, halfLife: Double) -> Double {
    let next = target + (value - target) * pow(2, -dt / halfLife)
    return abs(next - target) < 0.0005 ? target : next
}
