import XCTest
@testable import PopUpCore

final class AngleLockTests: XCTestCase {
    private let frame = 1.0 / 60

    private func hold(_ lock: inout AngleLock, at angle: Double, speed: Double = 0, seconds: Double) -> [AngleLock.Event] {
        var events: [AngleLock.Event] = []
        for _ in 0..<Int((seconds / frame).rounded()) {
            if let event = lock.update(angle: angle, speed: speed, dt: frame) { events.append(event) }
        }
        return events
    }

    func testClicksAfterHoldingStill() {
        var lock = AngleLock(target: 90)
        XCTAssertEqual(hold(&lock, at: 92, seconds: 0.3), [])
        guard case .holding(let progress) = lock.phase else { return XCTFail("should be holding") }
        XCTAssertGreaterThan(progress, 0.5)
        XCTAssertEqual(hold(&lock, at: 92, seconds: 0.3), [.locked])
        XCTAssertTrue(lock.isLocked)
    }

    func testFastFoldingNeverClicks() {
        var lock = AngleLock(target: 90)
        XCTAssertEqual(hold(&lock, at: 90, speed: 120, seconds: 2), [])
        XCTAssertEqual(lock.phase, .searching)
    }

    func testOffTargetNeverClicks() {
        var lock = AngleLock(target: 90)
        XCTAssertEqual(hold(&lock, at: 100, seconds: 2), [])
    }

    func testWobbleStaysLockedButDriftReleases() {
        var lock = AngleLock(target: 90)
        _ = hold(&lock, at: 90, seconds: 0.6)
        XCTAssertEqual(hold(&lock, at: 96, seconds: 1), [])
        XCTAssertTrue(lock.isLocked)
        XCTAssertEqual(hold(&lock, at: 99, seconds: 0.1), [.released])
        XCTAssertFalse(lock.isLocked)
    }

    func testLeavingResetsTheHold() {
        var lock = AngleLock(target: 90)
        _ = hold(&lock, at: 90, seconds: 0.4)
        _ = hold(&lock, at: 110, seconds: 0.1)
        XCTAssertEqual(hold(&lock, at: 90, seconds: 0.4), [])
        XCTAssertFalse(lock.isLocked)
    }
}
