# POP-UP

A puzzle game for iPhone Duo where the hinge is the camera. Open the phone like
a pop-up book and the camera tilts: barely open looks in from the side, flat
looks straight down.

This is steps 1 and 2 of the plan:

1. **Log the angle.** A live readout shows the hinge angle in degrees, the
   smoothed angle, the hinge status, how many updates arrive per second, and a
   graph of the last 3 seconds (raw in grey, smoothed in black). Every reading
   is also logged under the `PopUp` / `hinge` category, so you can watch it in
   Xcode's console.
2. **One room.** The bedroom level. The paper guy has to get from the bed to the
   door. The rug to the door sits on a stack of books, and it only lines up with
   the floor rug at about 90°. Open slowly. When it lines up, hold still for half
   a second until it clicks (you'll feel a tap), then tap the screen to walk.

## Running it

You need a Mac with Xcode and the iOS 27.1 SDK, which is where the hinge API lives.

1. Open `PopUp.xcodeproj`.
2. Under **Signing & Capabilities**, pick your team. You may also need to change
   the bundle ID from `com.example.popup`.
3. Run it on an iPhone Duo. On any other iPhone or in the simulator there's no
   hinge, so a slider appears instead and the game plays the same way.

To run the logic tests: `cd PopUpCore && swift test`.

The Xcode project is generated from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen). If you add files or change
settings, run `xcodegen` in this folder.

## What's where

| File | What it does |
|---|---|
| `PopUp/HingeAngleSource.swift` | **The only file that reads the hinge.** It uses `UIHingeInteraction` and falls back to the slider. Swap this file to change the input. |
| `PopUp/GameController.swift` | The frame loop: smooth the angle, check for the click, tilt the camera, walk the guy. |
| `PopUp/BedroomScene.swift` | The SceneKit diorama and the camera rig. |
| `PopUp/AngleReadout.swift` | The step 1 readout and graph. |
| `PopUp/GameView.swift` | The screen: scene, hints, slider, haptics. |
| `PopUpCore/` | The logic, with no UIKit in it, so it's unit tested: smoothing, the hold-to-click lock, the hinge-to-camera mapping, walking, and the bedroom layout. |

## How the "lines up" trick works

The camera is orthographic, the way Monument Valley's is. With an orthographic
camera, two points look like the same spot when the line between them points
straight at the camera. The book rug is 2.2 units nearer the camera than the
floor rug, and the books are exactly tall enough to put it on the same line of
sight at the click angle. At any other angle you can see a step.
`BedroomLayout` works out the book height from the click angle, so if you change
the angle, the books resize and the illusion stays exact.

When it clicks, the camera eases onto the exact click angle, so the rugs meet
perfectly even if your hand is a degree or two off. When the guy reaches the
gap, he jumps from the floor rug to the book rug, which looks like the same spot
on screen.

## Tuning

All of these are placeholders to tune on a real iPhone Duo.

| What | Where | Now |
|---|---|---|
| Click angle for the bedroom door | `GameController.init` | 90° |
| How close counts, and how long to hold | `AngleLock` | ±4°, 0.5 s. Releases past ±8°. Moving faster than 20°/s doesn't count as holding. |
| Smoothing | `AngleSmoother` | 0.15 s glide, ignores changes under 0.3° |
| Hinge angle to camera tilt | `CameraMapping` | 60° = side view (8° tilt), 120° = 49°, 180° = straight down |

The game never asks for fast or repeated folding. Moving quickly resets the
hold, and everything rewards opening slowly and holding still.

## The hinge API

I checked this against Apple's reference pages for `UIHingeInteraction`,
`UIHinge` and `UIHinge.Status` (iOS 27.1). It's a little different from the
pitch:

- You create `UIHingeInteraction { interaction, update in … }` and add it to a
  view. The hinge comes in on the update as `update.hinge`. It isn't a property
  of the interaction.
- `update.hinge` is `nil` when the hierarchy has no hinge. That's how a phone
  without a hinge shows up.
- `hinge.angle` is a `CGFloat` in radians. `hinge.status` is `.closed`,
  `.partiallyOpen`, `.fullyOpen` or `.unknown`.
- Apple doesn't document the angle's range. The code assumes 0 means shut and
  180° means flat, as the pitch says, and clamps to that range. The readout will
  show the real range on a device.
- Apple says the rate and precision of updates are up to the system and can
  change, so nothing here depends on either. That's why everything is smoothed.

## Not verified yet

- **The iOS app has never been compiled.** It was written in a Linux container
  with no Xcode, so the only check it got was a Swift syntax check. Expect a
  first build to turn up a few small errors.
- **What does work:** `PopUpCore` builds and its 18 tests pass, run with Swift
  6.1 on Linux.
- **Not checked at all:** how smooth the hinge reading is, and how the scene
  looks on a real iPhone Duo.

## Next

3. **Three levels.** Add the staircase (stairs connect at about 120°) and the
   attic (the trap shows from above, the exit from the side), then tune the
   click angles.
4. **Playtest.** Hand it to friends and watch where they get stuck.

Later:

- A laptop pose, with the scene on the top half and a tap pad on the bottom.
- Apple Pencil puzzles.
- Moving off SceneKit, which Apple has deprecated, to RealityKit.
