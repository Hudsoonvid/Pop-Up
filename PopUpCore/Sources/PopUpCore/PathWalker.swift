/// Moves the traveller along a list of waypoints at a steady pace.
///
/// A jump waypoint is reached instantly. That's how he crosses an illusion: the
/// two spots look like the same place on screen at the click angle, so the jump
/// is invisible. Each waypoint also carries his size, because a spot nearer the
/// camera needs a smaller traveller to look the same on screen.
public struct PathWalker {
    public struct Waypoint: Codable, Equatable {
        public var position: SIMD3<Double>
        public var isJump: Bool
        /// His size at this spot (1 is normal).
        public var scale: Double

        public static func walk(to position: SIMD3<Double>, scale: Double = 1) -> Waypoint {
            Waypoint(position: position, isJump: false, scale: scale)
        }

        public static func jump(to position: SIMD3<Double>, scale: Double = 1) -> Waypoint {
            Waypoint(position: position, isJump: true, scale: scale)
        }
    }

    /// World units per second at normal size. He covers ground in proportion to
    /// his size, so he crosses the screen at the same pace either way.
    public var speed: Double
    public private(set) var position: SIMD3<Double>
    public private(set) var scale: Double
    /// Distance covered on foot so far, in his own strides (jumps don't count).
    public private(set) var distanceWalked: Double = 0
    /// Which way he's walking (unit length), or nil once he's arrived.
    public private(set) var heading: SIMD3<Double>?
    private var remaining: [Waypoint]
    private var legStartScale: Double
    private var legStartPosition: SIMD3<Double>

    public var isFinished: Bool { remaining.isEmpty }

    public init(from start: SIMD3<Double>, scale: Double = 1, through waypoints: [Waypoint], speed: Double) {
        position = start
        self.scale = scale
        remaining = waypoints
        self.speed = speed
        legStartScale = scale
        legStartPosition = start
        updateHeading()
    }

    public mutating func advance(by dt: Double) {
        var budget = speed * dt
        while let next = remaining.first {
            if next.isJump {
                position = next.position
                scale = next.scale
                arrive()
                continue
            }
            guard budget > 0 else { return }
            let toGo = next.position - position
            let distance = length(of: toGo)
            let stride = budget * scale
            if distance <= stride {
                let used = distance / max(scale, 0.01)
                distanceWalked += used
                budget -= used
                position = next.position
                scale = next.scale
                arrive()
            } else {
                position += toGo * (stride / distance)
                distanceWalked += budget
                budget = 0
                // Ease his size across the leg, for legs that change it.
                let leg = length(of: next.position - legStartPosition)
                let done = leg > 0 ? 1 - length(of: next.position - position) / leg : 1
                scale = legStartScale + (next.scale - legStartScale) * done
                return
            }
        }
    }

    private mutating func arrive() {
        remaining.removeFirst()
        legStartScale = scale
        legStartPosition = position
        updateHeading()
    }

    private mutating func updateHeading() {
        guard let next = remaining.first(where: { !$0.isJump }) else {
            heading = nil
            return
        }
        let start = remaining.first?.isJump == true ? remaining[0].position : position
        let toGo = next.position - start
        let distance = length(of: toGo)
        heading = distance > 1e-9 ? toGo / distance : heading
    }
}

extension PathWalker {
    /// What's left of `route` (which begins at `start`) for someone standing
    /// at `position`: the waypoints from the leg he's nearest to onward. A
    /// walk picks up where he stopped instead of going back to the beginning.
    public static func remaining(of route: [Waypoint], from start: SIMD3<Double>,
                                 at position: SIMD3<Double>) -> [Waypoint] {
        var nearest = (index: 0, distance: Double.infinity)
        var previous = start
        for (index, waypoint) in route.enumerated() {
            defer { previous = waypoint.position }
            guard !waypoint.isJump else { continue }
            let distance = distanceToSegment(position, previous, waypoint.position)
            if distance < nearest.distance - 1e-9 { nearest = (index, distance) }
        }
        var index = nearest.index
        // Standing right on the end of that leg means it's already walked.
        if index < route.count, length(of: route[index].position - position) < 1e-6 { index += 1 }
        return Array(route[index...])
    }
}

private func distanceToSegment(_ p: SIMD3<Double>, _ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    let ab = b - a
    let lengthSquared = dotProduct(ab, ab)
    let t = lengthSquared > 0 ? min(max(dotProduct(p - a, ab) / lengthSquared, 0), 1) : 0
    return length(of: p - (a + ab * t))
}
