import XCTest
@testable import PopUpCore

final class AngleSmootherTests: XCTestCase {
    func testCatchesUpWithoutOvershooting() {
        var smoother = AngleSmoother(initial: 60)
        var highest = 0.0
        for _ in 0..<120 {
            highest = max(highest, smoother.step(toward: 120, dt: 1.0 / 60))
        }
        XCTAssertEqual(smoother.value, 120, accuracy: 0.1)
        XCTAssertLessThanOrEqual(highest, 120)
    }

    func testIgnoresJitterInsideDeadband() {
        var smoother = AngleSmoother(initial: 90)
        for frame in 0..<120 {
            smoother.step(toward: frame.isMultiple(of: 2) ? 90.2 : 89.8, dt: 1.0 / 60)
        }
        XCTAssertEqual(smoother.value, 90)
        XCTAssertEqual(smoother.velocity, 0)
    }

    func testSameMotionAtAnyFrameRate() {
        var slow = AngleSmoother(initial: 60)
        var fast = AngleSmoother(initial: 60)
        for _ in 0..<6 { slow.step(toward: 150, dt: 1.0 / 30) }
        for _ in 0..<24 { fast.step(toward: 150, dt: 1.0 / 120) }
        XCTAssertEqual(slow.value, fast.value, accuracy: 1)
    }

    func testGlidesThroughSteppyReadings() {
        // Readings arriving only 10 times a second, 3° apart: the camera
        // should still move in small even steps rather than jumps.
        var smoother = AngleSmoother(initial: 60)
        var previous = smoother.value
        var biggestStep = 0.0
        for frame in 0..<240 {
            let reading = 60 + Double(frame / 6) * 3
            let value = smoother.step(toward: min(reading, 150), dt: 1.0 / 60)
            biggestStep = max(biggestStep, abs(value - previous))
            previous = value
        }
        XCTAssertLessThan(biggestStep, 1.0)
    }

    func testApproachHalvesEachHalfLifeAndLands() {
        XCTAssertEqual(approach(0, to: 1, dt: 0.1, halfLife: 0.1), 0.5, accuracy: 1e-9)
        var value = 0.0
        for _ in 0..<100 { value = approach(value, to: 1, dt: 1.0 / 60, halfLife: 0.06) }
        XCTAssertEqual(value, 1)
    }
}
