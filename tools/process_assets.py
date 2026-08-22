"""Convert generated Imagine images into engine-ready PNGs."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(
    r"C:\Users\Monster\.grok\sessions"
    r"\C%3A%5CUsers%5CMonster%5Ccode%5Cblackbox"
    r"\01a02610-3f20-7cb1-9f4a-8a0986ad188e\images"
)
ASSETS = ROOT / "assets"


def make_seamless(im: Image.Image, size: int = 512, blend: int = 10) -> Image.Image:
    im = im.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    out = np.asarray(im).astype(np.float32)
    # Match only the outermost pixels so tiling does not flash a 1px edge.
    # Heavy wrap-blends created striped frames on rocky ground; keep this tiny.
    for axis in (0, 1):
        a = 0.5 * (np.take(out, 0, axis=axis) + np.take(out, size - 1, axis=axis))
        for idx in (0, size - 1):
            sl = [slice(None)] * out.ndim
            sl[axis] = idx
            out[tuple(sl)] = a
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def chroma_key(im: Image.Image, size: int = 256) -> Image.Image:
    im = im.convert("RGBA")
    a = np.array(im)
    h, w = a.shape[:2]
    rgb = a[:, :, :3].astype(np.float32)
    corners = np.stack(
        [rgb[1, 1], rgb[1, w - 2], rgb[h - 2, 1], rgb[h - 2, w - 2], rgb[3, w // 2], rgb[h // 2, 3]]
    )
    key = corners.mean(axis=0)
    dist = np.sqrt(((rgb - key) ** 2).sum(axis=2))
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    pinkish = (r > g + 20) & (b > g + 5) & (r > 130)
    # Punch keyed magenta everywhere (catches holes inside berry clusters)
    # then also flood remaining similar pixels from the frame.
    alpha = np.full((h, w), 255, dtype=np.uint8)
    alpha[dist < 46] = 0
    alpha[(dist < 70) & pinkish] = 0

    from collections import deque

    vis = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.append((0, x))
        q.append((h - 1, x))
    for y in range(h):
        q.append((y, 0))
        q.append((y, w - 1))
    while q:
        y, x = q.popleft()
        if vis[y, x]:
            continue
        vis[y, x] = True
        if dist[y, x] > 78 and not ((dist[y, x] < 110) & pinkish[y, x]):
            continue
        alpha[y, x] = 0
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not vis[ny, nx]:
                q.append((ny, nx))

    a[:, :, 3] = alpha
    img = Image.fromarray(a)
    arr = np.array(img)
    mask = arr[:, :, 3] > 20
    if not mask.any():
        return img.resize((size, size), Image.Resampling.LANCZOS)
    ys, xs = np.where(mask)
    pad = 10
    x0, x1 = max(int(xs.min()) - pad, 0), min(int(xs.max()) + pad, w - 1)
    y0, y1 = max(int(ys.min()) - pad, 0), min(int(ys.max()) + pad, h - 1)
    cropped = img.crop((x0, y0, x1 + 1, y1 + 1))
    side = max(cropped.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - cropped.size[0]) // 2
    oy = (side - cropped.size[1]) // 2
    canvas.paste(cropped, (ox, oy), cropped)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def paint_activity(kind: str, path: Path) -> None:
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # muted warm palette
    amber = (212, 160, 80, 255)
    rust = (170, 90, 70, 255)
    olive = (130, 140, 90, 255)
    wood = (140, 110, 70, 255)
    stone = (130, 120, 110, 255)
    cx, cy = 64, 64
    if kind == "forage":
        d.ellipse((40, 44, 88, 92), fill=(110, 50, 80, 255), outline=amber, width=3)
        d.ellipse((52, 36, 70, 54), fill=olive)
    elif kind == "hunt":
        d.polygon([(20, 96), (108, 32), (100, 24), (12, 88)], fill=wood)
        d.polygon([(96, 20), (116, 36), (88, 40)], fill=stone)
    elif kind == "wood":
        d.rectangle((54, 20, 74, 108), fill=wood, outline=amber, width=2)
        d.polygon([(74, 36), (104, 24), (74, 52)], fill=olive)
    elif kind == "stone":
        d.polygon([(30, 88), (50, 40), (90, 36), (108, 84), (64, 108)], fill=stone, outline=amber, width=2)
    elif kind == "craft":
        d.rectangle((36, 70, 92, 100), fill=wood, outline=amber, width=2)
        d.polygon([(48, 70), (64, 28), (80, 70)], fill=rust)
    img.save(path)


def save_tile(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(src)
    make_seamless(im).save(dst)


def save_sprite(src: Path, dst: Path, size: int = 256) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(src)
    chroma_key(im, size=size).save(dst)


def main() -> None:
    mapping_tiles = {
        "1.jpg": ASSETS / "terrain" / "meadow.png",
        "3.jpg": ASSETS / "terrain" / "forest_floor.png",
        "2.jpg": ASSETS / "terrain" / "rocky.png",
    }
    sprites = {
        "14.jpg": (ASSETS / "people" / "man.png", 256),
        "15.jpg": (ASSETS / "people" / "woman.png", 256),
        "16.jpg": (ASSETS / "people" / "elder_man.png", 256),
        "18.jpg": (ASSETS / "people" / "elder_woman.png", 256),
        "17.jpg": (ASSETS / "people" / "child.png", 256),
        "5.jpg": (ASSETS / "structures" / "hut_01.png", 256),
        "8.jpg": (ASSETS / "structures" / "hut_02.png", 256),
        "7.jpg": (ASSETS / "structures" / "hut_03.png", 256),
        "4.jpg": (ASSETS / "icons" / "good_berries.png", 256),
        "6.jpg": (ASSETS / "icons" / "good_meat.png", 256),
        "11.jpg": (ASSETS / "icons" / "good_wood.png", 256),
        "9.jpg": (ASSETS / "icons" / "good_stone.png", 256),
        "10.jpg": (ASSETS / "icons" / "good_spear.png", 256),
        "12.jpg": (ASSETS / "resources" / "game.png", 256),
    }
    for name, dst in mapping_tiles.items():
        save_tile(SRC / name, dst)
        print("tile", dst)
    for name, (dst, size) in sprites.items():
        save_sprite(SRC / name, dst, size=size)
        print("sprite", dst)
    # Resource map markers reuse goods where appropriate.
    for src, dst in [
        (ASSETS / "icons" / "good_berries.png", ASSETS / "resources" / "berries.png"),
        (ASSETS / "icons" / "good_wood.png", ASSETS / "resources" / "wood.png"),
        (ASSETS / "icons" / "good_stone.png", ASSETS / "resources" / "stone.png"),
    ]:
        Image.open(src).save(dst)
        print("copy", dst)
    act = ASSETS / "icons"
    act.mkdir(parents=True, exist_ok=True)
    for kind, name in [
        ("forage", "activity_forage.png"),
        ("hunt", "activity_hunt.png"),
        ("wood", "activity_wood.png"),
        ("stone", "activity_stone.png"),
        ("craft", "activity_craft.png"),
    ]:
        paint_activity(kind, act / name)
        print("activity", act / name)


if __name__ == "__main__":
    main()
