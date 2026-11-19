#!/usr/bin/env python3
"""Platzhalter-Icon: zwei Sprechblasen auf warmem Grund."""
import pathlib
import struct
import zlib

SIZE = 1024


def blend(dst, src, alpha):
    a = alpha / 255
    return tuple(int(d * (1 - a) + s * a) for d, s in zip(dst, src))


def rounded_rect(px, x, y, w, h, r, color):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            dx = 0
            if xx < x + r:
                dx = x + r - xx
            elif xx >= x + w - r:
                dx = xx - (x + w - r - 1)
            dy = 0
            if yy < y + r:
                dy = y + r - yy
            elif yy >= y + h - r:
                dy = yy - (y + h - r - 1)
            if dx * dx + dy * dy <= r * r:
                px[yy * SIZE + xx] = color


def circle(px, cx, cy, radius, color):
    r2 = radius * radius
    for yy in range(cy - radius, cy + radius):
        for xx in range(cx - radius, cx + radius):
            if 0 <= xx < SIZE and 0 <= yy < SIZE:
                if (xx - cx) ** 2 + (yy - cy) ** 2 <= r2:
                    px[yy * SIZE + xx] = color


def main():
    coral = (214, 96, 70)
    cream = (255, 246, 236)
    mango = (236, 164, 72)
    leaf = (46, 133, 102)
    px = [cream] * (SIZE * SIZE)
    rounded_rect(px, 0, 0, SIZE, SIZE, 0, (255, 236, 220))
    circle(px, 390, 470, 250, coral)
    circle(px, 660, 560, 230, mango)
    circle(px, 430, 500, 36, cream)
    circle(px, 530, 500, 36, cream)
    circle(px, 700, 560, 28, cream)
    circle(px, 790, 560, 28, cream)
    circle(px, 512, 250, 70, leaf)
    out = pathlib.Path(__file__).resolve().parents[1] / "Sprachduett/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for y in range(SIZE):
        row = bytearray([0])
        for x in range(SIZE):
            row.extend(px[y * SIZE + x])
        rows.append(bytes(row))
    compressed = zlib.compress(b"".join(rows), 9)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", compressed)
    png += chunk(b"IEND", b"")
    out.write_bytes(png)
    print(out, len(png))


if __name__ == "__main__":
    main()
