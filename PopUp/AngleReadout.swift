import PopUpCore
import SwiftUI

/// The fold angle, small in a corner. Tap it for the full readout: smoothed
/// angle, camera tilt, hinge status, updates per second and a graph of the
/// last few seconds, to see how smooth the real hinge reading is.
struct AngleReadout: View {
    let game: GameController
    @State private var expanded = false

    var body: some View {
        Button {
            expanded.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(game.hinge.degrees, specifier: "%.1f")°")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text(game.hinge.hasHinge ? "hinge" : "no hinge")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if expanded {
                    details
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("smoothed \(game.smoothedDegrees, specifier: "%.1f")° · camera tilt \(game.cameraTilt, specifier: "%.1f")°")
            if game.hinge.hasHinge {
                Text("\(game.hinge.statusName) · \(game.updatesPerSecond) updates/s")
            } else {
                Text("no hinge reported")
            }
            Text("click at \(game.blueprint.lock.target, specifier: "%.0f")°")
            AngleHistoryChart(samples: game.history, target: game.blueprint.lock.target)
                .frame(width: 240, height: 60)
        }
        .font(.caption.monospacedDigit())
    }
}

/// Raw angle (thin grey) and smoothed angle (thick), with the click angle
/// dashed. Zooms to the recent range so small jitter is visible.
struct AngleHistoryChart: View {
    let samples: [GameController.AngleSample]
    let target: Double

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }
            let values = samples.flatMap { [$0.raw, $0.smoothed] }
            let low = values.min() ?? 0
            let high = values.max() ?? 0
            let middle = (low + high) / 2
            let span = max(high - low + 4, 8)

            func y(_ degrees: Double) -> CGFloat {
                size.height * CGFloat(0.5 - (degrees - middle) / span)
            }
            func line(_ value: (GameController.AngleSample) -> Double) -> Path {
                var path = Path()
                let step = size.width / CGFloat(samples.count - 1)
                for (index, sample) in samples.enumerated() {
                    let point = CGPoint(x: CGFloat(index) * step, y: y(value(sample)))
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                return path
            }

            if abs(target - middle) < span / 2 {
                var targetLine = Path()
                targetLine.move(to: CGPoint(x: 0, y: y(target)))
                targetLine.addLine(to: CGPoint(x: size.width, y: y(target)))
                context.stroke(targetLine, with: .color(.orange), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            context.stroke(line { $0.raw }, with: .color(.gray), lineWidth: 1)
            context.stroke(line { $0.smoothed }, with: .color(.primary), lineWidth: 2)
        }
    }
}
