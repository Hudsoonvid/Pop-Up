import PopUpCore
import SwiftUI

/// The game screen: the room, with a few storybook touches on top.
///
/// Nothing here moves or resizes when the phone folds, so the only transition
/// you see is the system's own. When the book shuts, the cover shows; when it
/// opens, the room pops up out of the page.
struct GameView: View {
    @State private var game = GameController()

    var body: some View {
        ZStack {
            SceneContainer(game: game, room: game.room)
                .ignoresSafeArea()
                .onTapGesture { game.tap() }

            if game.isClosed {
                BookCover()
            }

            VStack(spacing: 12) {
                if !game.isClosed {
                    HStack(alignment: .top) {
                        AngleReadout(game: game)
                        Spacer()
                        if game.hinge.hasHinge {
                            InputToggle(hinge: game.hinge)
                        }
                    }
                    if game.showsTitle {
                        TitleCard(chapter: game.levelIndex + 1, title: game.blueprint.title)
                            .transition(.opacity)
                    }
                }
                Spacer()
                if !game.isClosed, !hint.isEmpty {
                    HintBar(text: hint)
                }
                if game.hinge.isUsingFakeFold {
                    FakeFoldSlider(hinge: game.hinge)
                }
            }
            .padding()
            .animation(.easeInOut(duration: 0.6), value: game.showsTitle)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sensoryFeedback(.impact(weight: .medium), trigger: game.lock.isLocked) { _, locked in locked }
        .sensoryFeedback(.success, trigger: game.phase == .won) { _, won in won }
        .onAppear { game.start() }
        .onDisappear { game.stop() }
    }

    private var hint: String {
        if let note = game.note { return note }
        switch game.phase {
        case .exploring:
            switch game.lock.phase {
            case .searching: return game.blueprint.intro
            case .holding: return "Hold still…"
            case .locked: return "Click! Tap to walk"
            }
        case .walkingToEdge:
            return game.lock.isLocked ? "Keep holding…" : "Line it up before he reaches the edge"
        case .crossing: return "Across!"
        case .falling: return "Oh no…"
        case .won: return "Tap to turn the page"
        case .turningPage: return ""
        }
    }
}

/// What to do next, on a strip of warm paper.
private struct HintBar: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.headline, design: .serif))
            .foregroundStyle(Color(red: 0.25, green: 0.17, blue: 0.1))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Paper.color, in: Capsule())
            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
    }
}

/// "Chapter 1 · The Bedroom", shown as each room pops up.
private struct TitleCard: View {
    let chapter: Int
    let title: String

    var body: some View {
        VStack(spacing: 2) {
            Text("Chapter \(chapter)")
                .font(.system(.subheadline, design: .serif).italic())
            Text(title)
                .font(.system(size: 34, weight: .semibold, design: .serif))
        }
        .foregroundStyle(Paper.color)
        .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
        .allowsHitTesting(false)
    }
}

/// Shown while the book is shut.
private struct BookCover: View {
    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.2, blue: 0.15)
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Paper.gold, lineWidth: 3)
                .padding(22)
            VStack(spacing: 10) {
                Text("POP-UP")
                    .font(.system(size: 54, weight: .bold, design: .serif))
                Text("a treehouse story")
                    .font(.system(.title3, design: .serif).italic())
                Text("Open the book to begin")
                    .font(.system(.footnote, design: .serif))
                    .padding(.top, 24)
                    .opacity(0.8)
            }
            .foregroundStyle(Paper.gold)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Switches between the real hinge and the fake fold on a real iPhone Duo.
private struct InputToggle: View {
    let hinge: HingeAngleSource

    var body: some View {
        Button {
            hinge.toggleFakeFold()
        } label: {
            Label(hinge.prefersFakeFold ? "Fake fold" : "Hinge",
                  systemImage: hinge.prefersFakeFold ? "slider.horizontal.3" : "book")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Stands in for the hinge: the simulator only offers three fixed angles.
private struct FakeFoldSlider: View {
    @Bindable var hinge: HingeAngleSource

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Fake fold")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(hinge.fakeFoldDegrees, specifier: "%.0f")°")
                    .font(.caption.monospacedDigit())
            }
            Slider(value: $hinge.fakeFoldDegrees, in: 0...180)
            HStack {
                Text("shut")
                Spacer()
                Text("side")
                Spacer()
                Text("tilted")
                Spacer()
                Text("flat")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: 520)
    }
}

enum Paper {
    static let color = Color(red: 0.96, green: 0.9, blue: 0.78)
    static let gold = Color(red: 0.86, green: 0.72, blue: 0.42)
}
