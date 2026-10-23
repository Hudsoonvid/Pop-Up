import SwiftUI
import PopUpCore

/// Step 1 of the plan: the live hinge angle, how often it updates, and a graph
/// of the last few seconds, so you can see how smooth the reading really is.
struct AngleReadout: View {
    let game: GameController

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(game.hinge.hasHinge ? "HINGE ANGLE" : "SLIDER ANGLE (NO HINGE)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(game.hinge.degrees, specifier: "%.1f")°")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Group {
                Text("smoothed \(game.smoothedDegrees, specifier: "%.1f")° · camera tilt \(game.cameraTilt, specifier: "%.1f")°")
                if game.hinge.hasHinge {
                    Text("\(game.hinge.statusName) · \(game.updatesPerSecond) updates/s")
                }
            }
            .font(.caption.monospacedDigit())
            AngleHistoryChart(samples: game.history, target: game.layout.alignHinge)
                .frame(width: 240, height: 60)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .allowsHitTesting(false)
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
