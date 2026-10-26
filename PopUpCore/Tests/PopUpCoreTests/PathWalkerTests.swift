import XCTest
@testable import PopUpCore

final class PathWalkerTests: XCTestCase {
    func testWalksAtSteadySpeed() {
        var walker = PathWalker(from: [0, 0, 0], through: [.walk(to: [3, 0, 0])], speed: 1)
        walker.advance(by: 1)
        XCTAssertEqual(walker.position.x, 1, accuracy: 1e-9)
        XCTAssertEqual(walker.heading, [1, 0, 0])
        XCTAssertFalse(walker.isFinished)
    }

    func testJumpIsInstantAndChangesSize() {
        var walker = PathWalker(
            from: [0, 0, 0],
            through: [.walk(to: [1, 0, 0]), .jump(to: [1, 5, 5], scale: 0.5), .walk(to: [3, 5, 5], scale: 0.5)],
            speed: 1)
        walker.advance(by: 1.5)
        // After the jump he's half size, so half a second covers a quarter unit.
        XCTAssertEqual(walker.position.x, 1.25, accuracy: 1e-9)
        XCTAssertEqual(walker.position.y, 5)
        XCTAssertEqual(walker.scale, 0.5)
        XCTAssertEqual(walker.distanceWalked, 1.5, accuracy: 1e-9)
    }

    func testFinishesExactlyOnTheLastWaypoint() {
        var walker = PathWalker(from: [0, 0, 0], through: [.walk(to: [1, 0, 0]), .walk(to: [1, 0, 2])], speed: 1)
        walker.advance(by: 10)
        XCTAssertTrue(walker.isFinished)
        XCTAssertEqual(walker.position, [1, 0, 2])
        XCTAssertNil(walker.heading)
        XCTAssertEqual(walker.distanceWalked, 3, accuracy: 1e-9)
    }

    func testHeadingFollowsTheCurrentLeg() {
        var walker = PathWalker(from: [0, 0, 0], through: [.walk(to: [1, 0, 0]), .walk(to: [1, 0, 2])], speed: 1)
        walker.advance(by: 1.5)
        XCTAssertEqual(walker.heading, [0, 0, 1])
    }
}

final class RouteResumeTests: XCTestCase {
    func testResumesAtTheGapInsteadOfStartingOver() throws {
        for level in Levels.all where level.trap == nil {
            let gap = try XCTUnwrap(level.stuck.last).position
            let rest = PathWalker.remaining(of: level.crossing, from: level.start, at: gap)
            XCTAssertEqual(rest.first?.isJump, true, level.id)
            XCTAssertEqual(rest.count, level.crossing.count - (level.crossing.firstIndex { $0.isJump } ?? 0), level.id)
        }
    }

    func testAtticDetourAndFallResumeFromTheHoleEdge() throws {
        let attic = try XCTUnwrap(Levels.all.first { $0.id == "attic" })
        let trap = try XCTUnwrap(attic.trap)
        let edge = try XCTUnwrap(attic.stuck.last).position
        let fall = PathWalker.remaining(of: trap.fall, from: attic.start, at: edge)
        XCTAssertEqual(fall.map(\.position), [trap.fall[1].position])
        let detour = PathWalker.remaining(of: attic.crossing, from: attic.start, at: edge)
        XCTAssertEqual(detour.last?.position, attic.crossing.last?.position)
        XCTAssertLessThan(detour.count, attic.crossing.count, "doesn't walk back to the start")
    }

    func testFromTheStartItsTheWholeRoute() {
        for level in Levels.all {
            XCTAssertEqual(PathWalker.remaining(of: level.crossing, from: level.start, at: level.start).count,
                           level.crossing.count, level.id)
        }
    }
}
