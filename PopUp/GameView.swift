import PopUpCore
import SwiftUI

/// The game screen: the room, with a few storybook touches on top.
///
/// When the book shuts, the cover shows; when it opens, the room pops up out of
/// the page. `StillHostingController` keeps all of this from animating when
/// the phone changes pose.
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

enum Paper {
    static let color = Color(red: 0.96, green: 0.9, blue: 0.78)
    static let gold = Color(red: 0.86, green: 0.72, blue: 0.42)
}
