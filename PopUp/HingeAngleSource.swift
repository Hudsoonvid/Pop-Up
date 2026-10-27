import Observation
import UIKit
import os

/// The one place POP-UP reads the hinge. Everything else only reads `degrees`,
/// so changing how the angle is read means changing only this file.
///
/// On iPhone Duo the angle comes from `UIHingeInteraction` (iOS 27.1 SDK). Its
/// update handler hands over `update.hinge`, a `UIHinge` whose `angle` is in
/// radians (0 when folded shut). A device without a hinge gets an update with
/// `hinge == nil`, and the angle stays at `openingDegrees`.
///
/// In the iPhone Duo simulator, hold Option in Device Hub for a hinge slider
/// that sets any angle.
///
/// Apple says the rate and precision of hinge updates are up to the system and
/// can change, so nothing here assumes either. `GameController` smooths the
/// angle every frame instead.
@MainActor
@Observable
final class HingeAngleSource {
    /// The angle assumed until a reading arrives, and on phones without a hinge.
    static let openingDegrees = 120.0

    /// Whether a real hinge is reporting. False until the first hinge update.
    private(set) var hasHinge = false
    private(set) var status: UIHinge.Status = .unknown
    /// The angle the game uses, in degrees: 0 is folded shut, 180 is flat.
    private(set) var degrees = HingeAngleSource.openingDegrees
    /// Hinge updates received so far, so the readout can show how often they come.
    private(set) var updateCount = 0

    var statusName: String {
        switch status {
        case .closed: return "closed"
        case .partiallyOpen: return "partly open"
        case .fullyOpen: return "fully open"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    @ObservationIgnored private var interaction: UIHingeInteraction?
    private let log = Logger(subsystem: "PopUp", category: "hinge")

    /// Starts listening for hinge updates from `view`'s hierarchy.
    func attach(to view: UIView) {
        guard interaction == nil else { return }
        let interaction = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            // UIKit calls this on the main thread; say so to the compiler
            // whatever isolation the SDK declares for the handler.
            MainActor.assumeIsolated {
                self.receive(update.hinge)
            }
        }
        view.addInteraction(interaction)
        self.interaction = interaction
    }

    private func receive(_ hinge: UIHinge?) {
        guard let hinge else {
            hasHinge = false
            status = .unknown
            log.info("No hinge reported")
            return
        }
        let reading = Double(hinge.angle) * 180 / .pi
        hasHinge = true
        status = hinge.status
        degrees = min(max(reading, 0), 180)
        updateCount += 1
        log.debug("hinge \(reading, format: .fixed(precision: 2))° \(self.statusName, privacy: .public)")
    }
}
