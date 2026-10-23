import XCTest
@testable import PopUpCore

final class BedroomLayoutTests: XCTestCase {
    func testCameraMappingMatchesTheThreeViews() {
        let mapping = CameraMapping()
        XCTAssertEqual(mapping.tilt(forHinge: 60), 8)
        XCTAssertEqual(mapping.tilt(forHinge: 120), 49)
        XCTAssertEqual(mapping.tilt(forHinge: 180), 90)
        XCTAssertEqual(mapping.tilt(forHinge: 20), 8, "nearly shut stays on the side view")
    }

    func testRugsMeetOnScreenOnlyAtTheClickAngle() {
        let layout = BedroomLayout(alignHinge: 90)
        func gap(atTilt tilt: Double) -> Double {
            abs(OrthoCamera.screenY(of: layout.floorEnd, tilt: tilt)
                - OrthoCamera.screenY(of: layout.ledgeStart, tilt: tilt))
        }
        XCTAssertEqual(gap(atTilt: layout.alignTilt), 0, accuracy: 1e-9)

        // A few degrees of hinge either way opens a visible step (in world
        // units; the rug itself is 0.6 deep).
        let mapping = CameraMapping()
        XCTAssertGreaterThan(gap(atTilt: mapping.tilt(forHinge: 80)), 0.1)
        XCTAssertGreaterThan(gap(atTilt: mapping.tilt(forHinge: 100)), 0.1)
        // Seen from the side or from the top, it obviously doesn't connect.
        XCTAssertGreaterThan(gap(atTilt: mapping.tilt(forHinge: 60)), 0.5)
        XCTAssertGreaterThan(gap(atTilt: mapping.tilt(forHinge: 180)), 0.5)
    }

    func testIllusionHoldsForAnyTunedAngle() {
        for hinge in stride(from: 70.0, through: 150.0, by: 10) {
            let layout = BedroomLayout(alignHinge: hinge)
            XCTAssertEqual(
                OrthoCamera.screenY(of: layout.floorEnd, tilt: layout.alignTilt),
                OrthoCamera.screenY(of: layout.ledgeStart, tilt: layout.alignTilt),
                accuracy: 1e-9, "hinge \(hinge)")
            XCTAssertGreaterThan(layout.ledgeHeight, 0)
        }
    }

    func testBooksFitOnThePage() {
        let layout = BedroomLayout(alignHinge: 90)
        XCTAssertLessThanOrEqual(layout.ledgeZ + layout.pathDepth / 2, 2.5)
        XCTAssertEqual(layout.ledgeHeight, 1.19, accuracy: 0.01)
    }
}
