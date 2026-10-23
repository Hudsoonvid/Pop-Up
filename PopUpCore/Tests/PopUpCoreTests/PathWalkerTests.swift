import XCTest
@testable import PopUpCore

final class PathWalkerTests: XCTestCase {
    func testWalksAtSteadySpeed() {
        var walker = PathWalker(from: [0, 0, 0], through: [.walk(to: [3, 0, 0])], speed: 1)
        walker.advance(by: 1)
        XCTAssertEqual(walker.position.x, 1, accuracy: 1e-9)
        XCTAssertFalse(walker.isFinished)
    }

    func testJumpIsInstantAndCostsNoDistance() {
        var walker = PathWalker(
            from: [0, 0, 0],
            through: [.walk(to: [1, 0, 0]), .jump(to: [1, 5, 5]), .walk(to: [3, 5, 5])],
            speed: 1)
        walker.advance(by: 1.5)
        XCTAssertEqual(walker.position, [1.5, 5, 5])
        XCTAssertEqual(walker.distanceWalked, 1.5, accuracy: 1e-9)
    }

    func testFinishesExactlyOnTheLastWaypoint() {
        var walker = PathWalker(from: [0, 0, 0], through: [.walk(to: [1, 0, 0]), .walk(to: [1, 0, 2])], speed: 1)
        walker.advance(by: 10)
        XCTAssertTrue(walker.isFinished)
        XCTAssertEqual(walker.position, [1, 0, 2])
        XCTAssertEqual(walker.distanceWalked, 3, accuracy: 1e-9)
    }

    func testCrossingRouteEndsAtTheDoor() {
        let layout = BedroomLayout(alignHinge: 90)
        var walker = PathWalker(from: layout.start, through: layout.crossingRoute, speed: 1.4)
        for _ in 0..<600 { walker.advance(by: 1.0 / 60) }
        XCTAssertTrue(walker.isFinished)
        XCTAssertEqual(walker.position, layout.doorStep)
    }
}
