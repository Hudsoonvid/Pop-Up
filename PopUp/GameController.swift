import Foundation
import Observation
import PopUpCore
import QuartzCore

/// Runs the game. Every frame it smooths the fold angle, checks whether the
/// path has clicked, tilts the camera, pops the room up or folds it down, and
/// moves the traveller.
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
        /// He didn't see the hole.
        case falling
        /// Through the door. Tap to turn the page.
        case won
        /// The room folds down and the next one pops up.
        case turningPage
    }

    struct AngleSample {
        var raw: Double
        var smoothed: Double
    }

    /// Walking pace, in world units per second at normal size.
    static let walkSpeed = 1.3
    /// Frames of angle history kept for the readout's graph (3 s at 60 fps).
    static let historyLength = 180
    /// Below this fold angle the room lies flat in the closed book.
    static let foldedBelow = 15.0
    /// Above this it has fully popped up.
    static let poppedAbove = 50.0

    let hinge = HingeAngleSource()
    private(set) var levelIndex = 0
    private(set) var room: LevelScene
    private(set) var phase = Phase.exploring
    private(set) var lock: AngleLock
    private(set) var smoothedDegrees: Double
    /// How far the camera tilts down from level, in degrees.
    private(set) var cameraTilt = 0.0
    private(set) var updatesPerSecond = 0
    private(set) var history: [AngleSample] = []
    /// A short note after something goes wrong, shown instead of the usual hint.
    private(set) var note: String?
    /// Whether the room's title card is showing.
    private(set) var showsTitle = false

    var blueprint: Blueprint { room.blueprint }
    /// The book is shut: show the cover.
    var isClosed: Bool { hinge.degrees < Self.foldedBelow - 5 }

    private let mapping = CameraMapping()
    @ObservationIgnored private var smoother: AngleSmoother
    @ObservationIgnored private var walker: PathWalker?
    @ObservationIgnored private var position: SIMD3<Double>
    @ObservationIgnored private var scale = 1.0
    /// He's playing a canned move (falling, stepping through the door), so
    /// the frame loop leaves him alone.
    @ObservationIgnored private var travellerScripted = false
    /// 0 follows the fold; 1 sits exactly on the click angle.
    @ObservationIgnored private var snap = 0.0
    /// How popped up the room is (0 flat, 1 standing), and how fast it's moving.
    @ObservationIgnored private var pop = 0.0
    @ObservationIgnored private var popVelocity = 0.0
    /// Seconds left until something scheduled happens (respawn, title fades).
    @ObservationIgnored private var respawnIn: Double?
    @ObservationIgnored private var titleFor = 0.0
    @ObservationIgnored private var noteFor = 0.0
    @ObservationIgnored private var time = 0.0
    @ObservationIgnored private var ticker: FrameTicker?
    @ObservationIgnored private var lastFrameTime: CFTimeInterval?
    @ObservationIgnored private var rateWindowStart: CFTimeInterval = 0
    @ObservationIgnored private var rateWindowCount = 0

    init() {
        let first = Levels.all[0]
        room = LevelScene(blueprint: first)
        lock = Self.makeLock(first)
        smoother = AngleSmoother(initial: HingeAngleSource.openingDegrees)
        smoothedDegrees = HingeAngleSource.openingDegrees
        position = first.start
        // The book opens on the first room: it pops up from flat.
        room.setPop(0)
        showsTitle = true
        titleFor = 3.5
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
        guard !isClosed, pop > 0.9 else { return }
        switch phase {
        case .exploring:
            if lock.isLocked {
                walk(.crossing, blueprint.crossing)
            } else if let trap = blueprint.trap, !blueprint.canSee(trap.point, tilt: cameraTilt) {
                // He can't see the hole, so he walks straight into it.
                walk(.falling, trap.fall)
            } else {
                walk(.walkingToEdge, blueprint.stuck)
                if let trap = blueprint.trap {
                    say(blueprint.canSee(trap.exitPoint, tilt: cameraTilt)
                        ? "He sees the hole and the door. Hold still to set off"
                        : "He can see the hole, but not the way out")
                }
            }
        case .won:
            phase = .turningPage
        case .walkingToEdge, .crossing, .falling, .turningPage:
            break
        }
    }

    // MARK: - Frame loop

    private func frame(at time: CFTimeInterval) {
        // Cap the step so coming back from the background doesn't lurch.
        let dt = lastFrameTime.map { min(time - $0, 0.1) } ?? 0
        lastFrameTime = time
        self.time += dt
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
        // path meets perfectly, and keep it there while he crosses.
        let holdCamera = lock.isLocked || phase == .crossing || phase == .won
        snap = approach(snap, to: holdCamera ? 1 : 0, dt: dt, halfLife: 0.06)
        let cameraHinge = smoothed + (blueprint.lock.target - smoothed) * snap
        cameraTilt = mapping.tilt(forHinge: cameraHinge)
        room.tiltCamera(degrees: cameraTilt)

        stepPopUp(dt: dt, smoothed: smoothed)
        stepWalk(dt: dt)
        stepTimers(dt: dt)
        room.update(time: time)

        history.append(AngleSample(raw: raw, smoothed: smoothed))
        if history.count > Self.historyLength {
            history.removeFirst(history.count - Self.historyLength)
        }
    }

    /// The room stands up as the book opens and lies down as it closes, and
    /// folds away between rooms. A spring makes it feel like paper.
    private func stepPopUp(dt: Double, smoothed: Double) {
        let open = min(max((smoothed - Self.foldedBelow) / (Self.poppedAbove - Self.foldedBelow), 0), 1)
        let target = phase == .turningPage ? 0 : open
        // Underdamped spring toward the target: fast, with a little settle.
        let stiffness = 90.0
        let damping = 15.0
        popVelocity += ((target - pop) * stiffness - popVelocity * damping) * dt
        pop += popVelocity * dt
        if abs(target - pop) < 0.0005 && abs(popVelocity) < 0.001 {
            pop = target
            popVelocity = 0
        }
        room.setPop(pop)

        if phase == .turningPage && pop < 0.02 {
            loadLevel((levelIndex + 1) % Levels.all.count)
        }
    }

    private func stepWalk(dt: Double) {
        guard var walk = walker else {
            if !travellerScripted {
                room.traveller.update(position: position, scale: scale, heading: nil, walked: nil, time: time, dt: dt)
            }
            return
        }
        walk.advance(by: dt)
        walker = walk
        position = walk.position
        scale = walk.scale
        room.traveller.update(position: walk.position, scale: walk.scale, heading: walk.heading,
                              walked: walk.isFinished ? nil : walk.distanceWalked, time: time, dt: dt)
        if walk.isFinished { finishWalk() }
    }

    private func stepTimers(dt: Double) {
        if titleFor > 0 {
            titleFor -= dt
            if titleFor <= 0 { showsTitle = false }
        }
        if noteFor > 0 {
            noteFor -= dt
            if noteFor <= 0 { note = nil }
        }
        if let wait = respawnIn {
            if wait - dt <= 0 {
                respawnIn = nil
                respawn()
            } else {
                respawnIn = wait - dt
            }
        }
    }

    private func measureUpdateRate(at time: CFTimeInterval) {
        guard time - rateWindowStart >= 1 else { return }
        updatesPerSecond = hinge.updateCount - rateWindowCount
        rateWindowCount = hinge.updateCount
        rateWindowStart = time
    }

    // MARK: - Walking

    private func walk(_ newPhase: Phase, _ route: [PathWalker.Waypoint]) {
        phase = newPhase
        let rest = PathWalker.remaining(of: route, from: blueprint.start, at: position)
        walker = PathWalker(from: position, scale: scale, through: rest, speed: Self.walkSpeed)
    }

    private func finishWalk() {
        walker = nil
        switch phase {
        case .walkingToEdge:
            if lock.isLocked {
                walk(.crossing, blueprint.crossing)
            } else {
                phase = .exploring
                room.traveller.hop()
            }
        case .crossing:
            phase = .won
            travellerScripted = true
            room.openDoor()
            room.traveller.walkThroughDoor(to: blueprint.exit)
        case .falling:
            travellerScripted = true
            room.traveller.fall()
            say("He didn't see the hole. Try a view from higher up")
            respawnIn = 1.3
        case .exploring, .won, .turningPage:
            break
        }
    }

    private func respawn() {
        phase = .exploring
        lock.reset()
        position = blueprint.start
        scale = 1
        travellerScripted = false
        room.traveller.reset()
    }

    private func say(_ text: String) {
        note = text
        noteFor = 4
    }

    // MARK: - Rooms

    private func loadLevel(_ index: Int) {
        levelIndex = index
        let blueprint = Levels.all[index]
        room = LevelScene(blueprint: blueprint)
        room.setPop(0)
        pop = 0
        popVelocity = 0
        lock = Self.makeLock(blueprint)
        snap = 0
        walker = nil
        position = blueprint.start
        scale = 1
        travellerScripted = false
        note = nil
        phase = .exploring
        showsTitle = true
        titleFor = 3.5
    }

    private static func makeLock(_ blueprint: Blueprint) -> AngleLock {
        AngleLock(target: blueprint.lock.target, tolerance: blueprint.lock.tolerance,
                  releaseTolerance: blueprint.lock.releaseTolerance)
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
