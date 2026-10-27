# POP-UP

A cozy puzzle game for iPhone Duo where the hinge is the camera. Open the phone
like a pop-up book: the room inside pops up off the page, and the angle of the
fold tilts the camera, from a side view when barely open to straight down when
flat. Paths that look broken join up at exactly one angle. Find it, hold still,
and tap to send the little traveller across.

## The rooms

A mossy old treehouse at dusk, lit by lanterns, candles and glowing mushrooms.

| Room | The puzzle |
|---|---|
| 1. The Bedroom | The floor reaches the door's ledge at about 90° |
| 2. The Staircase | The two flights of stairs join at about 120° |
| 3. The Attic | A hole only shows from above and the way out only from the side. Find a view that shows both, or he walks straight into the hole |

Through the door, tap to turn the page: the room folds flat and the next one
pops up.

## Playing it in the simulator

In Xcode's Device Hub, hold **Option** to get the iPhone Duo simulator's hinge
slider, then drag it to fold the phone to any angle.

- Fold slowly until the path lines up and the hint says *Hold still*.
- Hold for half a second until it clicks (on a phone you'll feel a tap).
- Tap the scene to walk.

Tap the angle in the top-left corner for the full readout: raw and smoothed
angle, hinge status, updates per second and a graph of the last few seconds.
On a phone without a hinge, the angle stays at 120°.

## Running it

You need a Mac with Xcode and the iOS 27.1 SDK.

1. Open `PopUp.xcodeproj`.
2. Under **Signing & Capabilities**, pick your team. You may also need to change
   the bundle ID from `com.example.popup`.
3. Run it on the iPhone Duo simulator or a device.

To run the logic tests: `cd PopUpCore && swift test`.

The Xcode project is generated from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding files, run
`xcodegen` in this folder.

## Performance

Rendering is set up to stay smooth on an M1 Mac running the simulator. Each room
has:

- one shadow-casting light, at most seven lights in all, and sparse particles
- static geometry merged into a few draw calls
- no ambient occlusion and no depth of field

`RenderQuality` in `PopUp/Materials.swift` sets all of this. Change
`RenderQuality.current` to `.rich` to try the heavier look on a real iPhone Duo.

Two knobs in `PopUp/LevelScene.swift` set the overall look:

- `exposure`, in stops: +1 doubles the brightness, -1 halves it.
- `saturation`: 1 is unchanged, lower is more muted.

## Folding and the system animation

When iPhone Duo moves an app between its outer and inner screens, iOS plays its
own transition: it holds a snapshot of the screen, frosts it over and slides it
across.

I couldn't find any way for an app to turn that off. I looked through Apple's
iPhone Duo developer guide, design guidelines, tech talks and developer-forum
Q&A for an API or Info.plist key, and there isn't one. Apple's guidance is that
a fold reaches the app as a resize and trait change.

What the game does about it:

- **It adds no animation of its own.** `StillHostingController` (in
  `PopUpApp.swift`) applies fold, unfold and rotate resizes instantly. UIKit
  would otherwise animate them, which smears the 3D view.
- **It never needs the phone shut.** All the puzzles happen between 60° and
  180°, so play stays on the inner screen.
- **The book still behaves like a pop-up.** With the book shut, the cover
  shows. As it opens, the room springs up off the page, driven by the angle.
  Changing rooms folds one down and pops the next one up.

It may be worth trying **Settings > Accessibility > Motion > Reduce Motion**,
in the simulator or on the phone. Across iOS it swaps many zoom and slide
transitions for a plain dissolve. Whether it changes the iPhone Duo fold isn't
documented.

## How it's built

| Where | What |
|---|---|
| `PopUpCore/` | The game's logic, with no UIKit in it, so it runs and tests anywhere. |
| `PopUpCore/.../Levels.swift` | Each room as a **blueprint**: every piece, light, particle emitter and walking route. |
| `PopUpCore/.../CameraMapping.swift` | The hinge-to-camera tilt, and the perspective camera maths. |
| `PopUp/HingeAngleSource.swift` | **The only file that reads the hinge** (`UIHingeInteraction`). |
| `PopUp/GameController.swift` | The frame loop: smoothing, the hold-to-click lock, the pop-up spring, walking, rooms. |
| `PopUp/LevelScene.swift` | Builds a blueprint into a SceneKit scene, with fog, bloom, lights and the pop-up layers. |
| `PopUp/Traveller.swift` | The traveller in the yellow raincoat and his walk. |
| `PopUp/Materials.swift`, `Particles.swift` | Mossy-wood materials; dust, fireflies, falling leaves and spores. |
| `Tools/make_textures.py` | Generates every texture in `PopUp/Textures/` with no outside assets. Run it with Python 3, numpy and Pillow. |

### How the paths line up

In each room the far half of the path is laid out as if it simply continued,
then slid along the camera's line of sight toward the camera and shrunk to
match. From the click angle the two halves land on exactly the same spot on
screen. From anywhere else they come apart. When the traveller reaches the gap
he jumps to the matching spot and shrinks by the same amount, so on screen he
just keeps walking. The tests check that every room lines up at its angle and
comes apart a few degrees either side.

The attic works differently. A fallen beam hides the hole from low angles, and a
deep shelf hides the little door from high ones. The beam and shelf are sized so
that both show between about 104° and 124°, and the game works out the click
angle from that band.

## Tuning

| What | Where | Now |
|---|---|---|
| Click angles | `Levels.swift` | 90°, 120°, and about 114° (attic, worked out from its band) |
| How close counts, and how long to hold | `Levels.swift` → `LockSettings`, `AngleLock` | ±4° for half a second |
| Smoothing | `AngleSmoother` | 0.15 s glide, ignores changes under 0.3° |
| Hinge to camera tilt | `CameraMapping` | 60° = side view, 180° = straight down |
| When the room pops up | `GameController.foldedBelow`, `poppedAbove` | flat below 15°, standing above 50° |
| Brightness and colour | `LevelScene.exposure`, `saturation` | -0.3 stops, 0.85 |

## Not verified yet

- **The latest iOS changes haven't been compiled.** The 3D version built and ran
  in the simulator. The newest changes (the still hosting controller, removing
  the fake fold, the toned-down lighting) were written without Xcode and only
  got a Swift syntax check.
- **What does work:** `PopUpCore` builds and its 25 tests pass, run with Swift
  6.1 on Linux.
- **Brightness is a guess.** It was turned down after the first simulator run
  came out very bright and oversaturated, but it hasn't been seen since. Tune
  it with `LevelScene.exposure` and `saturation`.
- **No real hinge yet.** The fold's feel hasn't been tried on a real iPhone Duo.
