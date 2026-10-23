import SwiftUI
import PopUpCore

/// The bedroom level, with the hinge readout and hints on top.
struct GameView: View {
    @State private var game = GameController()

    var body: some View {
        ZStack {
            SceneContainer(game: game)
                .ignoresSafeArea()
                .onTapGesture { game.tap() }

            VStack(alignment: .leading) {
                AngleReadout(game: game)
                Spacer()
                HintBar(game: game)
                if !game.hinge.hasHinge {
                    AngleSlider(hinge: game.hinge)
                }
            }
            .padding()
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sensoryFeedback(.impact(weight: .medium), trigger: game.lock.isLocked) { _, locked in locked }
        .sensoryFeedback(.success, trigger: game.phase == .won) { _, won in won }
        .onAppear { game.start() }
        .onDisappear { game.stop() }
    }
}

/// What to do next, plus a ring that fills while you hold still.
private struct HintBar: View {
    let game: GameController

    var body: some View {
        HStack(spacing: 10) {
            if case .holding(let progress) = game.lock.phase, game.phase == .exploring {
                ProgressRing(progress: progress)
            }
            Text(message)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    private var message: String {
        switch game.phase {
        case .exploring:
            switch game.lock.phase {
            case .searching: return "Open slowly until the rug lines up"
            case .holding: return "Hold still…"
            case .locked: return "Click! Tap to walk"
            }
        case .walkingToEdge:
            return game.lock.isLocked ? "Keep holding…" : "Line up the rug before he reaches the gap"
        case .crossing:
            return "Across!"
        case .won:
            return "Out the door! Tap to play again"
        }
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }
}

/// Stands in for the hinge on devices that don't have one.
private struct AngleSlider: View {
    @Bindable var hinge: HingeAngleSource

    var body: some View {
        VStack(spacing: 4) {
            Slider(value: $hinge.sliderDegrees, in: 60...180)
            HStack {
                Text("side")
                Spacer()
                Text("tilted")
                Spacer()
                Text("flat")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            Text("No hinge on this device. Drag to open the book.")
                .font(.caption)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
