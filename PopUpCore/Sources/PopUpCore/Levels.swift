import Foundation

/// The rooms of the treehouse, in order.
///
/// Each illusion is built the same way. The far half of the path is laid out
/// as if it simply carried on, then slid along the camera's line of sight
/// (`CameraRig.alongSight`) and shrunk to match. From the click angle the two
/// halves meet perfectly; from anywhere else they come apart.
public enum Levels {
    public static let all: [Blueprint] = [bedroom(), staircase(), attic()]

    static let mapping = CameraMapping()
    /// Height of a rug's top above the floor it lies on.
    static let rugTop = 0.03
    /// Half the traveller's width at normal size.
    static let halfWidth = 0.22

    // MARK: - 1. The bedroom

    /// Get from the bed to the door. The door's ledge is nearer the camera and
    /// higher up than it looks: the floor only reaches it at about 90°.
    static func bedroom() -> Blueprint {
        let rig = CameraRig(pivot: [-0.2, 1.2, -0.8], yaw: 8, frame: [12.5, 8.5])
        let alignHinge = 90.0
        let tilt = mapping.tilt(forHinge: alignHinge)
        let s = 0.9
        func near(_ p: SIMD3<Double>) -> SIMD3<Double> { rig.alongSight(p, tilt: tilt, scale: s) }

        let pathZ = -1.0
        let edgeX = 0.5
        let rugDepth = 0.75
        let rugStart = -3.1
        let doorX = 4.4
        var b = RoomBuilder(seed: 11)

        b.on(.page) { b in
            b.plankFloor(x: -5.4 ... edgeX, z: -2.7 ... 0.3, top: 0,
                         keep: (pathZ - rugDepth / 2) ... (pathZ + rugDepth / 2))
            for x in [-4.6, -2.6, -0.6] {
                b.box([0.22, 0.3, 3.2], at: [x, -0.31, -1.2], .darkWood)
            }
            b.box([edgeX - rugStart, rugTop, rugDepth], at: [(edgeX + rugStart) / 2, rugTop / 2, pathZ], .rug)

            // The ledge with the door: on screen it carries the floor on to the right.
            let ledge: SIMD3<Double> = [(edgeX + 5.3) / 2, -0.08, pathZ - 0.15]
            b.box([5.3 - edgeX, 0.16, 1.9] * s, at: near(ledge), .mossyWood, chamfer: 0.02 * s)
            let rugEnd = 4.9
            b.box([rugEnd - edgeX, rugTop, rugDepth] * s, at: near([(edgeX + rugEnd) / 2, rugTop / 2, pathZ]), .rug)
            for x in [1.2, 3.1, 5.0] {
                for dz in [-0.85, 0.6] {
                    b.cylinder(radius: 0.1 * s, height: 6 * s, at: near([x, -3.16, pathZ - 0.15 + dz]), .bark)
                }
            }
        }

        b.on(.backdrop) { b in
            b.boardWall(x: -5.4 ... 0.7, z: -2.78, bottom: -0.3) { _ in 3.9 }
            b.cylinder(radius: 0.16, height: 4.6, at: [-5.45, 1.7, -2.78], .bark)
            b.cylinder(radius: 0.16, height: 4.6, at: [0.75, 1.7, -2.78], .bark)
            b.box([6.5, 0.3, 0.32], at: [-2.35, 3.75, -2.6], .mossyWood)
            b.roundWindow(at: [-1.6, 2.2, -2.68], radius: 0.6)
            b.moss(from: [-5.3, 3.9, -2.6], to: [0.8, 3.9, -2.6], count: 9)
            b.hangingMoss(from: [-5.0, 3.6, -2.5], to: [0.5, 3.6, -2.5], count: 10)
        }

        // The side wall runs toward the camera, so it springs up rather than folding back.
        for i in 0..<6 {
            let material: Material = b.random.next() < 0.5 ? .mossyWood : .wood
            b.box([0.12, 3.0, 0.48], at: [-5.46, 1.2, -2.5 + Double(i) * 0.5], material, chamfer: 0.02)
        }

        // The bed, a teddy, a candle on a stool, books.
        b.box([1.75, 0.34, 1.45], at: [-4.35, 0.24, -1.9], .darkWood, chamfer: 0.04)
        b.box([0.14, 0.95, 1.45], at: [-5.18, 0.55, -1.9], .darkWood, chamfer: 0.03)
        b.box([0.12, 0.6, 1.45], at: [-3.5, 0.38, -1.9], .darkWood, chamfer: 0.03)
        b.box([1.6, 0.2, 1.36], at: [-4.35, 0.5, -1.9], .linen, chamfer: 0.08)
        b.box([1.15, 0.08, 1.42], at: [-4.0, 0.62, -1.9], .quilt, chamfer: 0.04)
        b.box([0.38, 0.16, 0.95], at: [-4.85, 0.68, -1.9], .linen, chamfer: 0.07)
        teddy(&b, at: [-3.15, 0, -2.4])
        b.box([0.45, 0.42, 0.45], at: [-2.45, 0.21, -2.35], .wood, chamfer: 0.03)
        b.candle(at: [-2.45, 0.42, -2.35], lit: true)
        books(&b, at: [-0.9, 0, -2.35])
        b.hangingLantern(at: [-2.0, 2.65, -1.3], ceiling: 3.75, aimAt: [-1.8, 0, -1.0])

        // Moss and mushrooms where the floor has rotted away, clear of the rug.
        b.moss(from: [edgeX - 0.3, 0, 0.2], to: [edgeX - 0.3, 0, -0.5], count: 3)
        b.moss(from: [edgeX - 0.3, 0, -1.5], to: [edgeX - 0.3, 0, -2.6], count: 4)
        b.mushrooms(at: [edgeX - 0.35, 0, -2.2], count: 6, lit: true)

        // The ledge's side of the room, shrunk to match.
        b.moss(from: near([1.0, 0, pathZ - 0.95]), to: near([5.1, 0, pathZ - 0.95]), count: 6, size: 0.1...0.2)
        b.moss(from: near([1.0, 0, pathZ + 0.65]), to: near([5.1, 0, pathZ + 0.65]), count: 5, size: 0.1...0.2)
        b.mushrooms(at: near([5.0, 0, pathZ + 0.55]), count: 4, spread: 0.25)
        b.door(at: near([doorX, 0, pathZ - 0.75]), scale: s)

        b.light(.directional, color: [0.55, 0.66, 1.0], intensity: 280, at: [-8, 12, 10], target: [0, 0, 0])
        b.light(.directional, color: [0.45, 0.55, 0.85], intensity: 140, at: [3, 6, -10], target: [0, 1, 0])
        b.emit(.fireflies, at: [2.2, 0.2, -0.8], extent: [4, 2.5, 3.5])
        b.emit(.leaves, at: [0, 7.5, -1], extent: [16, 0.5, 9])
        b.forest(below: 0)

        let gap: SIMD3<Double> = [edgeX - halfWidth, rugTop, pathZ]
        return Blueprint(
            id: "bedroom", title: "The Bedroom",
            intro: "Open the book slowly until the floor reaches the door",
            rig: rig,
            lock: LockSettings(target: alignHinge, tolerance: 4, releaseTolerance: 8),
            atmosphere: Atmosphere(fogColor: [0.07, 0.10, 0.13], fogStart: 26, fogEnd: 60, skyLight: 0.35),
            pieces: b.pieces, lights: b.lights, emitters: b.emitters,
            backdropHinge: [0, 0, -2.78],
            start: [-2.85, rugTop, pathZ],
            crossing: [.walk(to: gap), .jump(to: near(gap), scale: s), .walk(to: near([doorX, rugTop, pathZ]), scale: s)],
            stuck: [.walk(to: gap)],
            trap: nil,
            exit: near([doorX, rugTop, pathZ - 0.95]), exitScale: s)
    }

    // MARK: - 2. The staircase

    /// Climb inside the great tree. The upper flight hangs nearer the camera
    /// than it looks, and only meets the lower one at about 120°.
    static func staircase() -> Blueprint {
        let rig = CameraRig(pivot: [0.6, 3.0, -0.6], yaw: -10, frame: [13, 9.5])
        let alignHinge = 120.0
        let tilt = mapping.tilt(forHinge: alignHinge)
        let s = 0.86
        func near(_ p: SIMD3<Double>) -> SIMD3<Double> { rig.alongSight(p, tilt: tilt, scale: s) }

        let pathZ = -0.9
        let width = 1.0
        let rise = 0.2
        let run = 0.42
        let firstX = -3.0
        func top(_ step: Int) -> Double { rise * Double(step + 1) }
        func centerX(_ step: Int) -> Double { firstX + run * (Double(step) + 0.5) }
        let lowerSteps = 0..<8
        let upperSteps = 8..<14
        let landingTop = top(13)
        let landingX = firstX + run * 14
        let doorX = landingX + 1.7
        var b = RoomBuilder(seed: 23)

        b.on(.page) { b in
            b.plankFloor(x: -5.6 ... 0.6, z: -2.5 ... 0.4, top: 0)
            for step in lowerSteps {
                let h = top(step)
                b.box([run, h - 0.05, width], at: [centerX(step), (h - 0.05) / 2, pathZ], .wood)
                let material: Material = step % 3 == 1 ? .mossyWood : .wood
                b.box([run + 0.04, 0.05, width + 0.04], at: [centerX(step), h - 0.025, pathZ], material, chamfer: 0.01)
            }
            // The upper flight and its landing, as if they carried straight on...
            for step in upperSteps {
                let material: Material = step % 3 == 1 ? .mossyWood : .wood
                b.box([run + 0.04, 0.07, width + 0.04] * s, at: near([centerX(step), top(step) - 0.035, pathZ]),
                      material, chamfer: 0.01 * s)
            }
            let flight = length(of: [run * 6, rise * 6, 0])
            let slope = atan2(rise, run) * 180 / .pi
            for dz in [-0.45, 0.45] {
                b.box([flight, 0.14, 0.08] * s, at: near([firstX + run * 11, rise * 11 - 0.12, pathZ + dz]),
                      .darkWood, rotation: [0, 0, slope])
            }
            b.box([2.8, 0.16, 1.7] * s, at: near([landingX + 1.4, landingTop - 0.08, pathZ - 0.3]), .mossyWood,
                  chamfer: 0.02 * s)
            // ...hanging on ropes from the branches above.
            let ropes: [(x: Double, foot: Double)] = [(centerX(9), top(9)), (centerX(13), top(13)), (landingX + 2.6, landingTop)]
            for rope in ropes {
                for dz in [-0.45, 0.45] {
                    b.cylinder(radius: 0.018 * s, height: (9 - rope.foot) * s,
                               at: near([rope.x, (9 + rope.foot) / 2, pathZ + dz]), .rope)
                }
            }
        }

        b.on(.backdrop) { b in
            // The inside of the trunk: a wall of mossy logs.
            var x = -5.8
            while x < 5.8 {
                let r = b.random.next(0.24 ... 0.32)
                b.cylinder(radius: r, height: 8.5, at: [x + r, 3.0, -2.75 + b.random.next(-0.08 ... 0.08)], .bark)
                x += r * 2 - 0.02
            }
            b.box([2.4, 0.08, 0.38], at: [-1.4, 2.6, -2.36], .wood, chamfer: 0.01)
            b.box([2.0, 0.08, 0.38], at: [-3.8, 4.1, -2.36], .wood, chamfer: 0.01)
            b.roundWindow(at: [2.4, 4.6, -2.38], radius: 0.55)
            b.box([11.5, 0.3, 0.3], at: [0, 5.6, -2.2], .mossyWood)
            b.moss(from: [-5.6, 5.75, -2.2], to: [5.6, 5.75, -2.2], count: 12)
            b.hangingMoss(from: [-5.4, 5.45, -2.15], to: [5.4, 5.45, -2.15], count: 12)
        }

        // Firefly jars on the shelf, books, a lantern, mushrooms by the stairs.
        for (i, dx) in [-0.7, -0.25, 0.25].enumerated() {
            b.cylinder(radius: 0.09, height: 0.22, at: [-1.4 + dx, 2.75, -2.36], .jarGlow)
            b.cylinder(radius: 0.06, height: 0.04, at: [-1.4 + dx, 2.88, -2.36], i == 1 ? .iron : .wood)
        }
        b.light(.omni, color: [0.85, 1.0, 0.45], intensity: 220, at: [-1.4, 2.9, -2.1], range: 3.2)
        books(&b, at: [-3.9, 4.14, -2.36])
        b.hangingLantern(at: [-4.2, 2.5, -1.4], ceiling: 5.45, aimAt: [-3.4, 0, -0.9])
        b.mushrooms(at: [-3.5, 0, -0.1], count: 5)
        b.lanternPost(at: [firstX - 0.55, 0, pathZ + 0.75])
        b.moss(from: [firstX, 0, 0.1], to: [-5.4, 0, 0.1], count: 5)
        for step in [1, 4, 6] {
            b.moss(from: [centerX(step) - 0.15, top(step), pathZ - 0.48], to: [centerX(step) + 0.15, top(step), pathZ - 0.48],
                   count: 1, size: 0.08...0.13)
        }
        b.moss(from: near([landingX + 0.4, landingTop, pathZ - 1.05]), to: near([landingX + 2.6, landingTop, pathZ - 1.05]),
               count: 4, size: 0.1...0.18)
        b.door(at: near([doorX, landingTop, pathZ - 0.85]), scale: s)

        b.light(.directional, color: [0.55, 0.66, 1.0], intensity: 280, at: [-9, 12, 9], target: [0, 0, 0])
        b.light(.directional, color: [0.5, 0.5, 0.8], intensity: 130, at: [-3, 6, -10], target: [0, 2, 0])
        b.emit(.fireflies, at: [-1.4, 3.2, -1.8], extent: [3, 1.5, 1.2])
        b.emit(.leaves, at: [0, 8.5, -1], extent: [15, 0.5, 8])
        b.forest(below: 0)

        var route: [PathWalker.Waypoint] = [.walk(to: [firstX - 0.2, 0, pathZ])]
        route += lowerSteps.map { .walk(to: [centerX($0), top($0), pathZ]) }
        let gap: SIMD3<Double> = [firstX + run * 8 - halfWidth, top(7), pathZ]
        var crossing = route + [.walk(to: gap), .jump(to: near(gap), scale: s)]
        crossing += upperSteps.map { .walk(to: near([centerX($0), top($0), pathZ]), scale: s) }
        crossing.append(.walk(to: near([doorX, landingTop, pathZ - 0.3]), scale: s))

        return Blueprint(
            id: "staircase", title: "The Staircase",
            intro: "Find the angle where the stairs join up",
            rig: rig,
            lock: LockSettings(target: alignHinge, tolerance: 4, releaseTolerance: 8),
            atmosphere: Atmosphere(fogColor: [0.12, 0.09, 0.07], fogStart: 26, fogEnd: 62, skyLight: 0.35),
            pieces: b.pieces, lights: b.lights, emitters: b.emitters,
            backdropHinge: [0, 0, -2.75],
            start: [-4.4, 0, pathZ],
            crossing: crossing,
            stuck: route + [.walk(to: gap)],
            trap: nil,
            exit: near([doorX, landingTop, pathZ - 1.05]), exitScale: s)
    }

    // MARK: - 3. The attic

    /// A hole in the floor shows only from above (a fallen beam hides it from
    /// the side). The way out shows only from the side (a deep shelf hides it
    /// from above). He goes safely only when the camera shows both.
    static func attic() -> Blueprint {
        let rig = CameraRig(pivot: [0, 1.0, -0.3], yaw: 0, frame: [12, 8.5])
        let hole: SIMD3<Double> = [0.4, 0, -0.1]
        let exitDoor: SIMD3<Double> = [3.0, 0.45, -2.3]
        let pathZ = hole.z
        // Size the beam and the shelf so the band where both show runs from
        // roughly 104° to 124°.
        let low = rig.position(tilt: mapping.tilt(forHinge: 104))
        let high = rig.position(tilt: mapping.tilt(forHinge: 124))
        let beamBack = 0.75
        let beamTop = hole.y + (low.y - hole.y) * (beamBack - hole.z) / (low.z - hole.z)
        let shelfBottom = 1.7
        let shelfFront = exitDoor.z + (high.z - exitDoor.z) * (shelfBottom - exitDoor.y) / (high.y - exitDoor.y)
        var b = RoomBuilder(seed: 37)

        b.on(.page) { b in
            b.plankFloor(x: -4.8 ... 4.8, z: -2.4 ... 1.8, top: 0, ragged: false,
                         hole: (x: -0.2 ... 1.0, z: -0.7 ... 0.5))
            b.box([3.6, beamTop, 0.5], at: [0.4, beamTop / 2, beamBack + 0.25], .mossyWood, chamfer: 0.03, occludes: true)
            b.box([2.8, 0.25, shelfFront + 2.39], at: [3.0, shelfBottom + 0.125, (shelfFront - 2.39) / 2], .wood,
                  chamfer: 0.02, occludes: true)
            // Broken boards dangling into the hole.
            b.box([0.5, 0.05, 0.38], at: [-0.12, -0.28, 0.25], .wood, rotation: [0, 0, -38])
            b.box([0.45, 0.05, 0.38], at: [1.05, -0.24, -0.5], .mossyWood, rotation: [0, 0, 42])
            b.box([3.3, rugTop, 0.6], at: [0.65, rugTop / 2, -1.55], .rug)
        }

        b.on(.backdrop) { b in
            func gable(_ x: Double) -> Double { 4.1 - abs(x) * 0.38 }
            b.boardWall(x: -4.8 ... 2.68, z: -2.45, bottom: -0.2, height: gable)
            b.boardWall(x: 3.32 ... 4.8, z: -2.45, bottom: -0.2, height: gable)
            // Boards above the little door.
            let lintel = 1.05
            let wallTop = -0.2 + gable(exitDoor.x)
            b.box([0.66, wallTop - lintel, 0.12], at: [exitDoor.x, (wallTop + lintel) / 2, -2.45], .wood)
            let rafter = length(of: [4.9, 2.1, 0])
            let pitch = atan2(2.1, 4.9) * 180 / .pi
            b.box([rafter, 0.24, 0.24], at: [-2.45, 3.05, -2.25], .darkWood, rotation: [0, 0, pitch])
            b.box([rafter, 0.24, 0.24], at: [2.45, 3.05, -2.25], .darkWood, rotation: [0, 0, -pitch])
            b.roundWindow(at: [0, 3.0, -2.36], radius: 0.42)
            b.hangingMoss(from: [-4.3, 2.0, -2.15], to: [-0.6, 3.6, -2.15], count: 6)
            b.hangingMoss(from: [0.6, 3.6, -2.15], to: [4.3, 2.0, -2.15], count: 6)
        }

        // The deep shelf's quilts and jars, a chest with candles, crates, a lantern.
        b.box([1.0, 0.22, 0.75], at: [2.3, shelfBottom + 0.36, -1.9], .quilt, chamfer: 0.06)
        b.box([0.9, 0.18, 0.7], at: [2.35, shelfBottom + 0.56, -1.95], .linen, chamfer: 0.06)
        books(&b, at: [3.6, shelfBottom + 0.25, -2.0])
        b.box([0.08, 0.5, 0.08], at: [1.75, shelfBottom - 0.2, shelfFront + 0.08], .darkWood, rotation: [-40, 0, 0])
        b.box([0.08, 0.5, 0.08], at: [4.25, shelfBottom - 0.2, shelfFront + 0.08], .darkWood, rotation: [-40, 0, 0])
        b.box([1.1, 0.6, 0.7], at: [-3.6, 0.3, -1.95], .darkWood, chamfer: 0.04)
        b.box([1.14, 0.12, 0.74], at: [-3.6, 0.66, -1.95], .mossyWood, chamfer: 0.04)
        b.candle(at: [-3.85, 0.72, -1.95], lit: true)
        b.candle(at: [-3.5, 0.72, -1.85], height: 0.15)
        b.box([0.6, 0.6, 0.6], at: [-2.55, 0.3, -2.0], .wood, rotation: [0, 12, 0], chamfer: 0.02)
        b.box([0.45, 0.45, 0.45], at: [-2.6, 0.83, -2.0], .wood, rotation: [0, -8, 0], chamfer: 0.02)
        b.hangingLantern(at: [-1.6, 2.5, -1.3], ceiling: 3.3, aimAt: [-0.8, 0, -0.6])
        b.mushrooms(at: [1.35, 0, -0.95], count: 5, lit: true)
        b.mushrooms(at: [-0.6, 0, 0.62], count: 3, spread: 0.2)
        b.moss(from: [-1.0, beamTop, 1.12], to: [1.9, beamTop, 1.12], count: 5, size: 0.08...0.16)
        b.moss(from: [-4.6, 0, 1.6], to: [4.6, 0, 1.6], count: 9)
        b.door(at: [exitDoor.x, 0, -2.36], scale: 0.68)

        b.light(.directional, color: [0.6, 0.66, 1.0], intensity: 280, at: [-7, 12, 10], target: [0, 0, 0])
        b.light(.directional, color: [0.5, 0.5, 0.85], intensity: 130, at: [4, 6, -10], target: [0, 1, 0])
        b.emit(.dust, at: [0, 2.2, -1.6], extent: [2, 1.6, 1.4])
        b.forest(below: 0)

        var blueprint = Blueprint(
            id: "attic", title: "The Attic",
            intro: "Find a view that shows both the hole and the way out",
            rig: rig,
            lock: LockSettings(target: 114, tolerance: 6, releaseTolerance: 9),
            atmosphere: Atmosphere(fogColor: [0.08, 0.08, 0.12], fogStart: 26, fogEnd: 60, skyLight: 0.35),
            pieces: b.pieces, lights: b.lights, emitters: b.emitters,
            backdropHinge: [0, 0, -2.45],
            start: [-3.8, 0, pathZ],
            crossing: [
                .walk(to: [-1.0, 0, pathZ]), .walk(to: [-0.7, rugTop, -1.55]), .walk(to: [1.9, rugTop, -1.55]),
                .walk(to: [2.7, 0, -1.85]), .walk(to: [exitDoor.x, 0, -2.05]),
            ],
            stuck: [.walk(to: [-0.55, 0, pathZ])],
            trap: Trap(point: hole, exitPoint: exitDoor,
                       fall: [.walk(to: [-0.55, 0, pathZ]), .walk(to: [hole.x, 0, pathZ])]),
            exit: [exitDoor.x, 0, -2.6], exitScale: 1)

        // Lock onto the middle of the band where both really show.
        if let band = blueprint.bandShowingTrapAndExit() {
            let half = (band.upperBound - band.lowerBound) / 2
            blueprint.lock = LockSettings(target: (band.lowerBound + band.upperBound) / 2,
                                          tolerance: max(3, half - 2), releaseTolerance: max(6, half + 1))
        }
        return blueprint
    }

    // MARK: - Shared props

    static func teddy(_ b: inout RoomBuilder, at base: SIMD3<Double>) {
        b.sphere(radius: 0.17, at: base + [0, 0.17, 0], .plush, scale: [1, 1.05, 0.9])
        b.sphere(radius: 0.13, at: base + [0, 0.4, 0.02], .plush)
        for side in [-1.0, 1.0] {
            b.sphere(radius: 0.05, at: base + [0.09 * side, 0.51, 0], .plush)
            b.sphere(radius: 0.06, at: base + [0.15 * side, 0.08, 0.1], .plush)
        }
        b.sphere(radius: 0.05, at: base + [0, 0.38, 0.12], .linen)
    }

    static func books(_ b: inout RoomBuilder, at base: SIMD3<Double>) {
        let colors: [Material] = [.bookRed, .bookGreen, .bookBlue, .bookRed]
        var y = base.y
        for (i, color) in colors.enumerated() {
            let h = 0.07 + 0.02 * Double(i % 2)
            b.box([0.5 - 0.05 * Double(i), h, 0.34], at: [base.x, y + h / 2, base.z], color,
                  rotation: [0, b.random.next(-20 ... 20), 0], chamfer: 0.01)
            y += h
        }
    }
}

extension Blueprint {
    /// The widest run of hinge angles where the camera can see both the trap
    /// and the way out, or nil if there isn't one.
    public func bandShowingTrapAndExit(step: Double = 0.5) -> ClosedRange<Double>? {
        guard let trap else { return nil }
        let mapping = CameraMapping()
        var best: ClosedRange<Double>?
        var run: ClosedRange<Double>?
        func keep(_ run: ClosedRange<Double>) {
            if best.map({ run.upperBound - run.lowerBound > $0.upperBound - $0.lowerBound }) ?? true { best = run }
        }
        for hinge in stride(from: mapping.sideHinge, through: mapping.flatHinge, by: step) {
            let tilt = mapping.tilt(forHinge: hinge)
            if canSee(trap.point, tilt: tilt) && canSee(trap.exitPoint, tilt: tilt) {
                run = (run?.lowerBound ?? hinge) ... hinge
            } else if let finished = run {
                keep(finished)
                run = nil
            }
        }
        if let run { keep(run) }
        return best
    }
}
