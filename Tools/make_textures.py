"""Generates POP-UP's textures: tileable mossy wood, moss, bark and fabrics,
particle sprites and the dusk sky. Everything is procedural, so there's
nothing to license.

    python3 Tools/make_textures.py            # writes PopUp/Textures/

Needs numpy and Pillow.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

SIZE = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "PopUp", "Textures")
rng = np.random.default_rng(7)


# --- Noise -------------------------------------------------------------------

def value_noise(cells_x, cells_y, size=SIZE):
    """Smooth noise that tiles: a random grid, wrapped, with smoothstep blending."""
    grid = rng.random((cells_y, cells_x))
    ys = np.linspace(0, cells_y, size, endpoint=False)
    xs = np.linspace(0, cells_x, size, endpoint=False)
    x0 = np.floor(xs).astype(int)
    y0 = np.floor(ys).astype(int)
    fx = xs - x0
    fy = ys - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x1 = (x0 + 1) % cells_x
    y1 = (y0 + 1) % cells_y
    a = grid[np.ix_(y0, x0)]
    b = grid[np.ix_(y0, x1)]
    c = grid[np.ix_(y1, x0)]
    d = grid[np.ix_(y1, x1)]
    top = a + (b - a) * fx[None, :]
    bottom = c + (d - c) * fx[None, :]
    return top + (bottom - top) * fy[:, None]


def fbm(cells_x, cells_y, octaves=5, falloff=0.5):
    total = np.zeros((SIZE, SIZE))
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        total += value_noise(cells_x * 2 ** o, cells_y * 2 ** o) * amp
        norm += amp
        amp *= falloff
    return total / norm


def normal_map(height, strength):
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    n = np.dstack([-dx, dy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return (n * 0.5 + 0.5)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return np.asarray(a) * (1 - t) + np.asarray(b) * t


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def save(name, data, mode="RGB"):
    data = np.clip(data, 0, 1)
    img = Image.fromarray((data * 255).astype(np.uint8), mode if data.ndim == 3 else "L")
    path = os.path.join(OUT, name)
    if name.endswith(".jpg"):
        img.convert("RGB").save(path, quality=88)
    else:
        img.save(path, optimize=True)
    print("wrote", name)


# --- Surfaces ----------------------------------------------------------------

def wood_height():
    # Grain runs along x (the long side of planks), with growth rings.
    grain = fbm(2, 16, octaves=5)
    rings = 0.5 + 0.5 * np.sin(grain * 38 + fbm(1, 4, octaves=3) * 9)
    knots = smoothstep(0.78, 0.9, fbm(3, 3, octaves=3))
    return grain * 0.6 + rings * 0.3 - knots * 0.4, rings, knots


def wood():
    h, rings, knots = wood_height()
    dark = np.array([0.27, 0.16, 0.09])
    light = np.array([0.52, 0.35, 0.2])
    color = mix(dark, light, np.clip(h * 0.9 + 0.15, 0, 1))
    color = mix(color, dark * 0.55, knots * 0.8)
    color *= (0.92 + 0.08 * rings)[..., None]
    return color, h, 0.62 + 0.25 * (1 - rings)


def moss_layer():
    fine = fbm(24, 24, octaves=4)
    tips = smoothstep(0.62, 0.8, fbm(48, 48, octaves=2))
    base = mix([0.12, 0.2, 0.06], [0.32, 0.45, 0.13], fine)
    color = mix(base, [0.55, 0.62, 0.22], tips * 0.6)
    height = fine * 0.7 + tips * 0.5
    return color, height


def make_wood():
    color, h, rough = wood()
    save("wood_albedo.jpg", color)
    save("wood_normal.png", normal_map(h, 2.2))
    save("wood_roughness.jpg", rough)
    return color, h, rough


def make_mossy_wood(wood_color, wood_h, wood_rough):
    mask = smoothstep(0.66, 0.76, fbm(3, 3, octaves=5) + fbm(1, 6, octaves=2) * 0.25)
    moss_color, moss_h = moss_layer()
    color = mix(wood_color, moss_color, mask)
    h = wood_h * (1 - mask) + (0.6 + moss_h * 0.8) * mask
    rough = wood_rough * (1 - mask) + 0.95 * mask
    save("mossywood_albedo.jpg", color)
    save("mossywood_normal.png", normal_map(h, 3.0))
    save("mossywood_roughness.jpg", rough)


def make_moss():
    color, h = moss_layer()
    save("moss_albedo.jpg", color)
    save("moss_normal.png", normal_map(h, 4.0))


def make_bark():
    ridges = fbm(10, 1, octaves=5)
    cracks = smoothstep(0.35, 0.5, np.abs(np.sin(ridges * 30)))
    h = ridges * 0.5 + cracks * 0.5
    color = mix([0.13, 0.09, 0.06], [0.36, 0.28, 0.2], h)
    lichen = smoothstep(0.66, 0.74, fbm(6, 6, octaves=4))
    color = mix(color, [0.36, 0.44, 0.2], lichen * 0.7)
    save("bark_albedo.jpg", color)
    save("bark_normal.png", normal_map(h, 3.5))


def weave(threads=96):
    y, x = np.mgrid[0:SIZE, 0:SIZE] / SIZE * threads
    return 0.5 + 0.25 * np.sin(x * 2 * math.pi) * np.sin(y * 2 * math.pi)


def make_quilt():
    palette = np.array([[0.62, 0.22, 0.18], [0.82, 0.62, 0.28], [0.22, 0.42, 0.42],
                        [0.88, 0.8, 0.66], [0.4, 0.3, 0.45], [0.5, 0.58, 0.32]])
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    patch = SIZE // 4
    pick = rng.integers(0, len(palette), (4, 4))
    color = palette[pick[y // patch, x // patch]]
    # Little flowers on some patches.
    dots = smoothstep(0.82, 0.86, fbm(20, 20, octaves=2)) * (pick[y // patch, x // patch] % 2)
    color = mix(color, [0.95, 0.9, 0.78], dots * 0.7)
    edge = np.minimum(x % patch, y % patch)
    stitch = ((edge == 4) & (((x + y) // 6) % 2 == 0))
    color = mix(color, [0.96, 0.92, 0.82], stitch.astype(float))
    seam = (edge < 2).astype(float)
    color *= (1 - 0.35 * seam)[..., None]
    color *= (0.85 + 0.3 * weave())[..., None]
    save("quilt_albedo.jpg", color)


def make_rug():
    stripes = np.array([[0.62, 0.25, 0.16], [0.9, 0.82, 0.62], [0.18, 0.38, 0.4],
                        [0.82, 0.6, 0.22], [0.9, 0.82, 0.62], [0.45, 0.18, 0.14]])
    y = np.arange(SIZE)
    band = (y * len(stripes) * 2 // SIZE) % len(stripes)
    color = np.repeat(stripes[band][:, None, :], SIZE, axis=1)
    color *= (0.8 + 0.4 * weave(128))[..., None]
    wear = fbm(4, 4, octaves=4)
    color = mix(color, color * 0.7 + 0.15, smoothstep(0.6, 0.8, wear) * 0.5)
    save("rug_albedo.jpg", color)


def make_linen():
    color = mix([0.8, 0.76, 0.68], [0.93, 0.9, 0.84], weave(160) * 0.6 + fbm(8, 8, 3) * 0.4)
    save("linen_albedo.jpg", color)


def make_plush():
    fuzz = fbm(64, 64, octaves=2)
    color = mix([0.36, 0.22, 0.12], [0.56, 0.38, 0.22], fuzz)
    save("plush_albedo.jpg", color)


def make_forest_floor():
    color, h = moss_layer()
    leaf_litter = smoothstep(0.55, 0.7, fbm(12, 12, octaves=3))
    color = mix(color * 0.5, [0.3, 0.18, 0.1], leaf_litter * 0.6)
    save("forest_albedo.jpg", color)


def make_leaves():
    blotch = fbm(10, 10, octaves=5)
    color = mix([0.06, 0.14, 0.06], [0.2, 0.34, 0.12], blotch)
    color = mix(color, [0.42, 0.4, 0.12], smoothstep(0.7, 0.8, blotch) * 0.5)
    save("leaves_albedo.jpg", color)


# --- Sprites and sky ---------------------------------------------------------

def make_sprites():
    s = 64
    y, x = np.mgrid[0:s, 0:s] / (s - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)
    glow = np.clip(1 - r, 0, 1) ** 2.2
    dot = np.dstack([np.ones((s, s))] * 3 + [glow])
    Image.fromarray((dot * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "particle_dot.png"))
    print("wrote particle_dot.png")

    # A leaf: an almond shape with a midrib, autumn colours.
    u = (x + 1) / 2
    width = 0.42 * np.sin(np.clip(u, 0, 1) * math.pi) ** 0.8
    inside = smoothstep(0.02, -0.02, np.abs(y) - width)
    rib = smoothstep(0.05, 0.0, np.abs(y)) * (u < 0.95)
    color = mix([0.72, 0.42, 0.14], [0.48, 0.5, 0.16], (y + 1) / 2)
    color = mix(color, [0.4, 0.22, 0.08], rib * 0.6)
    leaf = np.dstack([color, inside])
    Image.fromarray((np.clip(leaf, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "particle_leaf.png"))
    print("wrote particle_leaf.png")


def make_sky():
    w, h = 1024, 512
    v = np.linspace(0, 1, h)[:, None]  # 0 = straight up, 1 = straight down
    u = np.linspace(0, 1, w)[None, :]
    zenith = np.array([0.03, 0.05, 0.11])
    horizon = np.array([0.2, 0.27, 0.33])
    ground = np.array([0.03, 0.04, 0.04])
    up = smoothstep(0.0, 0.5, v)
    sky = mix(zenith, horizon, up * np.ones((1, w)))
    below = smoothstep(0.5, 0.62, v) * np.ones((1, w))
    sky = mix(sky, ground, below)
    # The moon's glow, up and to the left behind the rooms.
    du = np.minimum(np.abs(u - 0.62), 1 - np.abs(u - 0.62)) * 2
    dv = (v - 0.3) * 2
    moon = np.exp(-(du ** 2 + dv ** 2) * 18)
    sky = sky + moon[..., None] * np.array([0.45, 0.5, 0.6])
    # A last warm glow low on the opposite side.
    du2 = np.minimum(np.abs(u - 0.12), 1 - np.abs(u - 0.12)) * 2
    warm = np.exp(-(du2 ** 2 * 6 + ((v - 0.5) * 6) ** 2))
    sky = sky + warm[..., None] * np.array([0.35, 0.18, 0.07])
    img = Image.fromarray((np.clip(sky, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, "sky.jpg"), quality=90)
    print("wrote sky.jpg")


def main():
    os.makedirs(OUT, exist_ok=True)
    wood_parts = make_wood()
    make_mossy_wood(*wood_parts)
    make_moss()
    make_bark()
    make_quilt()
    make_rug()
    make_linen()
    make_plush()
    make_forest_floor()
    make_leaves()
    make_sprites()
    make_sky()


if __name__ == "__main__":
    sys.exit(main())
