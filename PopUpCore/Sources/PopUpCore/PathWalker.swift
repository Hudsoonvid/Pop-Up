/// Moves the paper guy along a list of waypoints at a steady pace.
///
/// A jump waypoint is reached instantly. That's how he crosses from the floor
/// to the books: the two spots look like the same place on screen at the click
/// angle, so the jump is invisible.
public struct PathWalker {
    public struct Waypoint: Equatable {
        public var position: SIMD3<Double>
        public var isJump: Bool

        public static func walk(to position: SIMD3<Double>) -> Waypoint {
            Waypoint(position: position, isJump: false)
        }

        public static func jump(to position: SIMD3<Double>) -> Waypoint {
            Waypoint(position: position, isJump: true)
        }
    }

    /// World units per second.
    public var speed: Double
    public private(set) var position: SIMD3<Double>
    /// Distance covered on foot so far (jumps don't count).
    public private(set) var distanceWalked: Double = 0
    private var remaining: [Waypoint]

    public var isFinished: Bool { remaining.isEmpty }

    public init(from start: SIMD3<Double>, through waypoints: [Waypoint], speed: Double) {
        position = start
        remaining = waypoints
        self.speed = speed
    }

    public mutating func advance(by dt: Double) {
        var budget = speed * dt
        while let next = remaining.first {
            if next.isJump {
                position = next.position
                remaining.removeFirst()
                continue
            }
            guard budget > 0 else { return }
            let toGo = next.position - position
            let distance = (toGo * toGo).sum().squareRoot()
            if distance <= budget {
                position = next.position
                distanceWalked += distance
                budget -= distance
                remaining.removeFirst()
            } else {
                position += toGo * (budget / distance)
                distanceWalked += budget
                return
            }
        }
    }
}
