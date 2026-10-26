import XCTest
@testable import PopUpCore

final class LevelTests: XCTestCase {
    private let mapping = CameraMapping()

    func testCameraMappingMatchesTheThreeViews() {
        XCTAssertEqual(mapping.tilt(forHinge: 60), 8)
        XCTAssertEqual(mapping.tilt(forHinge: 120), 49)
        XCTAssertEqual(mapping.tilt(forHinge: 180), 90)
        XCTAssertEqual(mapping.tilt(forHinge: 20), 8, "nearly shut stays on the side view")
    }

    func testCameraLooksAtThePivot() throws {
        let rig = CameraRig(pivot: [1, 2, 3], yaw: 15)
        for tilt in [8.0, 49, 90] {
            let center = try XCTUnwrap(rig.project(rig.pivot, tilt: tilt))
            XCTAssertEqual(center.x, 0, accuracy: 1e-9)
            XCTAssertEqual(center.y, 0, accuracy: 1e-9)
            XCTAssertEqual(length(of: rig.position(tilt: tilt) - rig.pivot), rig.distance, accuracy: 1e-9)
        }
        // Higher on screen means higher in the world, seen from the side.
        let above = try XCTUnwrap(rig.project(rig.pivot + [0, 1, 0], tilt: 8))
        XCTAssertGreaterThan(above.y, 0)
    }

    func testSlidingAlongTheSightLineKeepsTheScreenSpot() throws {
        let rig = CameraRig(pivot: [0, 1, 0], yaw: -12)
        let point: SIMD3<Double> = [2, 0.3, -1]
        let moved = rig.alongSight(point, tilt: 40, scale: 0.8)
        let a = try XCTUnwrap(rig.project(point, tilt: 40))
        let b = try XCTUnwrap(rig.project(moved, tilt: 40))
        XCTAssertEqual(a.x, b.x, accuracy: 1e-9)
        XCTAssertEqual(a.y, b.y, accuracy: 1e-9)
        XCTAssertGreaterThan(moved.y, point.y, "nearer the camera means higher, with the camera above")
    }

    /// The jump in each crossing joins two spots that look identical at the
    /// click angle, and visibly don't from a few degrees away.
    func testIllusionsLineUpOnlyAtTheClickAngle() throws {
        for level in Levels.all where level.trap == nil {
            let jump = try XCTUnwrap(level.crossing.firstIndex { $0.isJump }, level.id)
            let from = level.crossing[jump - 1].position
            let to = level.crossing[jump].position
            func gap(atHinge hinge: Double) throws -> Double {
                let tilt = mapping.tilt(forHinge: hinge)
                let a = try XCTUnwrap(level.rig.project(from, tilt: tilt))
                let b = try XCTUnwrap(level.rig.project(to, tilt: tilt))
                return ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
            }
            let target = level.lock.target
            XCTAssertEqual(try gap(atHinge: target), 0, accuracy: 1e-9, level.id)
            // In half-heights of the screen: 0.02 is a few points on a phone.
            XCTAssertGreaterThan(try gap(atHinge: target - 12), 0.02, level.id)
            XCTAssertGreaterThan(try gap(atHinge: target + 12), 0.02, level.id)
            XCTAssertGreaterThan(try gap(atHinge: 60), 0.05, level.id)
            XCTAssertGreaterThan(try gap(atHinge: 180), 0.05, level.id)
            // He shrinks at the jump by exactly as much as the spot is nearer.
            let camera = level.rig.position(tilt: mapping.tilt(forHinge: target))
            XCTAssertEqual(level.crossing[jump].scale, length(of: to - camera) / length(of: from - camera),
                           accuracy: 1e-9, level.id)
        }
    }

    func testAtticShowsTheHoleOnlyFromAboveAndTheDoorOnlyFromTheSide() throws {
        let attic = try XCTUnwrap(Levels.all.first { $0.id == "attic" })
        let trap = try XCTUnwrap(attic.trap)
        XCTAssertFalse(attic.canSee(trap.point, tilt: mapping.tilt(forHinge: 60)), "hole hidden from the side")
        XCTAssertTrue(attic.canSee(trap.exitPoint, tilt: mapping.tilt(forHinge: 60)), "door shows from the side")
        XCTAssertTrue(attic.canSee(trap.point, tilt: mapping.tilt(forHinge: 180)), "hole shows from above")
        XCTAssertFalse(attic.canSee(trap.exitPoint, tilt: mapping.tilt(forHinge: 180)), "door hidden from above")

        let band = try XCTUnwrap(attic.bandShowingTrapAndExit())
        XCTAssertGreaterThan(band.upperBound - band.lowerBound, 12, "wide enough to find by hand")
        XCTAssertEqual(band.lowerBound, 104, accuracy: 2)
        XCTAssertEqual(band.upperBound, 124, accuracy: 2)
        let lock = attic.lock
        XCTAssertTrue(band.contains(lock.target - lock.tolerance) && band.contains(lock.target + lock.tolerance))
    }

    func testEveryRouteFinishes() throws {
        for level in Levels.all {
            for route in [level.crossing, level.stuck] + (level.trap.map { [$0.fall] } ?? []) {
                var walker = PathWalker(from: level.start, through: route, speed: 1.4)
                for _ in 0..<3000 { walker.advance(by: 1.0 / 60) }
                XCTAssertTrue(walker.isFinished, level.id)
                XCTAssertEqual(walker.position, try XCTUnwrap(route.last).position, level.id)
            }
        }
    }

    func testPiecesAreSane() {
        for level in Levels.all {
            XCTAssertFalse(level.pieces.isEmpty)
            for piece in level.pieces {
                XCTAssertTrue(piece.position.x.isFinite && piece.position.y.isFinite && piece.position.z.isFinite, level.id)
                XCTAssertGreaterThan(piece.size.x, 0, "\(level.id) \(piece.shape) \(piece.material)")
            }
            XCTAssertEqual(level.pieces.filter { $0.tag == "door" }.count, 1, "\(level.id) has one door")
            XCTAssertEqual(level.lights.filter(\.castsShadow).count, 1, "\(level.id) has one shadow light")
            XCTAssertLessThanOrEqual(level.lights.count, 7, "\(level.id) keeps lights cheap for the simulator")
        }
    }

    func testBlueprintsSurviveJSON() throws {
        let data = try JSONEncoder().encode(Levels.all)
        let decoded = try JSONDecoder().decode([Blueprint].self, from: data)
        XCTAssertEqual(decoded.map(\.id), ["bedroom", "staircase", "attic"])
        XCTAssertEqual(decoded[0].pieces.count, Levels.all[0].pieces.count)
    }
}
