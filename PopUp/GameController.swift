import Foundation
import Observation
import PopUpCore
import QuartzCore

/// Runs the bedroom level. Every frame it smooths the hinge angle, checks
/// whether the path has clicked, tilts the camera, and moves the paper guy.
@MainActor
@Observable
final class GameController {
    enum Phase {
        /// Free to look around. Tap to walk.
        case exploring
        /// Walking to the gap. He crosses if the path clicks by the time he gets there.
        case walkingToEdge
        /// The path clicked; he's crossing to the door. The camera holds still.
        case crossing
        case won
    }

    struct AngleSample {
        var raw: Double
        var smoothed: Double
    }

    /// Walking pace, in world units per second.
    static let walkSpeed = 1.4
    /// Frames of angle history kept for the readout's graph (3 s at 60 fps).
    static let historyLength = 180

    let hinge = HingeAngleSource()
    let layout: BedroomLayout
    let room: BedroomScene

    private(set) var phase = Phase.exploring
    private(set) var lock: AngleLock
    private(set) var smoothedDegrees: Double
    /// How far the camera tilts down from level, in degrees.
    private(set) var cameraTilt = 0.0
    private(set) var updatesPerSecond = 0
    private(set) var history: [AngleSample] = []

    private let mapping = CameraMapping()
    @ObservationIgnored private var smoother: AngleSmoother
    @ObservationIgnored private var walker: PathWalker?
    @ObservationIgnored private var guyPosition: SIMD3<Double>
    /// 0 follows the hinge; 1 sits exactly on the click angle.
    @ObservationIgnored private var snap = 0.0
    @ObservationIgnored private var ticker: FrameTicker?
    @ObservationIgnored private var lastFrameTime: CFTimeInterval?
    @ObservationIgnored private var rateWindowStart: CFTimeInterval = 0
    @ObservationIgnored private var rateWindowCount = 0

    init() {
        // The spec's bedroom door lines up at about 90°. Placeholder until
        // it's tuned on a real iPhone Duo.
        let layout = BedroomLayout(alignHinge: 90)
        self.layout = layout
        room = BedroomScene(layout: layout)
        lock = AngleLock(target: layout.alignHinge)
        smoother = AngleSmoother(initial: HingeAngleSource.openingDegrees)
        smoothedDegrees = HingeAngleSource.openingDegrees
        guyPosition = layout.start
    }

    func start() {
        guard ticker == nil else { return }
        ticker = FrameTicker { [weak self] link in
            self?.frame(at: link.timestamp)
        }
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        lastFrameTime = nil
    }

    func tap() {
        switch phase {
        case .exploring:
            if lock.isLocked {
                cross()
            } else {
                phase = .walkingToEdge
                walker = PathWalker(from: guyPosition, through: [.walk(to: layout.floorEnd)], speed: Self.walkSpeed)
            }
        case .walkingToEdge, .crossing:
            break
        case .won:
            restart()
        }
    }

    // MARK: - Frame loop

    private func frame(at time: CFTimeInterval) {
        // Cap the step so coming back from the background doesn't lurch.
        let dt = lastFrameTime.map { min(time - $0, 0.1) } ?? 0
        lastFrameTime = time
        step(dt: dt)
        measureUpdateRate(at: time)
    }

    private func step(dt: Double) {
        let raw = hinge.degrees
        let smoothed = smoother.step(toward: raw, dt: dt)
        smoothedDegrees = smoothed

        // Once he's crossing, the click can't be lost mid-walk.
        if phase == .exploring || phase == .walkingToEdge {
            lock.update(angle: smoothed, speed: smoother.velocity, dt: dt)
        }

        // When it clicks, ease the camera onto the exact click angle so the
        // rugs meet perfectly, and keep it there while he crosses.
        let holdCamera = lock.isLocked || phase == .crossing || phase == .won
        snap = approach(snap, to: holdCamera ? 1 : 0, dt: dt, halfLife: 0.06)
        let cameraHinge = smoothed + (layout.alignHinge - smoothed) * snap
        cameraTilt = mapping.tilt(forHinge: cameraHinge)
        room.tiltCamera(degrees: cameraTilt)

        if var walk = walker {
            walk.advance(by: dt)
            walker = walk
            guyPosition = walk.position
            room.placeGuy(at: walk.position, walked: walk.isFinished ? nil : walk.distanceWalked)
            if walk.isFinished { finishWalk() }
        }

        history.append(AngleSample(raw: raw, smoothed: smoothed))
        if history.count > Self.historyLength {
            history.removeFirst(history.count - Self.historyLength)
        }
    }

    private func measureUpdateRate(at time: CFTimeInterval) {
        guard time - rateWindowStart >= 1 else { return }
        updatesPerSecond = hinge.updateCount - rateWindowCount
        rateWindowCount = hinge.updateCount
        rateWindowStart = time
    }

    // MARK: - Walking

    private func cross() {
        phase = .crossing
        walker = PathWalker(from: guyPosition, through: layout.crossingRoute, speed: Self.walkSpeed)
    }

    private func finishWalk() {
        walker = nil
        switch phase {
        case .walkingToEdge:
            if lock.isLocked {
                cross()
            } else {
                phase = .exploring
                room.bump()
            }
        case .crossing:
            phase = .won
            room.exitThroughDoor()
        case .exploring, .won:
            break
        }
    }

    private func restart() {
        phase = .exploring
        lock.reset()
        walker = nil
        guyPosition = layout.start
        room.reset(guyAt: layout.start)
    }
}

/// Calls back once per screen refresh on the main thread.
@MainActor
private final class FrameTicker: NSObject {
    private let onFrame: @MainActor (CADisplayLink) -> Void
    private var link: CADisplayLink?

    init(onFrame: @escaping @MainActor (CADisplayLink) -> Void) {
        self.onFrame = onFrame
        super.init()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func invalidate() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        onFrame(link)
    }
}
