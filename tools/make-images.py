#!/usr/bin/env python3
"""Generate the channel icons and splash screens as plain PNGs.

Green-on-black block lettering in a 5x7 pixel font, so no image library is
needed. Run from the repo root:  python3 tools/make-images.py
"""

import os
import struct
import zlib

GREEN = (0x33, 0xFF, 0x33)
BLACK = (0x00, 0x00, 0x00)

FONT = {
    "D": ["1110.", "1..1.", "1...1", "1...1", "1...1", "1..1.", "1110."],
    "X": ["1...1", "1...1", ".1.1.", "..1..", ".1.1.", "1...1", "1...1"],
    "C": [".111.", "1...1", "1....", "1....", "1....", "1...1", ".111."],
    "L": ["1....", "1....", "1....", "1....", "1....", "1....", "11111"],
    "U": ["1...1", "1...1", "1...1", "1...1", "1...1", "1...1", ".111."],
    "S": [".1111", "1....", "1....", ".111.", "....1", "....1", "1111."],
    "T": ["11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.."],
    "E": ["11111", "1....", "1....", "1111.", "1....", "1....", "11111"],
    "R": ["1111.", "1...1", "1...1", "1111.", "1.1..", "1..1.", "1...1"],
    "_": [".....", ".....", ".....", ".....", ".....", ".....", "11111"],
    " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}


def write_png(path, width, height, pixels):
    """pixels: list of rows, each a bytearray of RGB triples."""
    raw = b"".join(b"\x00" + bytes(row) for row in pixels)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def render(width, height, lines):
    """Draw text lines centred on a black canvas. lines: [(text, scale)]."""
    canvas = [bytearray(BLACK * width) for _ in range(height)]
    gap = [scale * 4 for _, scale in lines]
    total_h = sum(7 * s for _, s in lines) + sum(gap[:-1])
    y = (height - total_h) // 2
    for i, (text, scale) in enumerate(lines):
        text_w = (len(text) * 6 - 1) * scale
        x0 = (width - text_w) // 2
        for ci, ch in enumerate(text):
            glyph = FONT[ch]
            for gy, row in enumerate(glyph):
                for gx, bit in enumerate(row):
                    if bit != "1":
                        continue
                    for dy in range(scale):
                        line = canvas[y + gy * scale + dy]
                        px = x0 + (ci * 6 + gx) * scale
                        line[px * 3:(px + scale) * 3] = bytes(GREEN * scale)
        y += 7 * scale + gap[i]
    return canvas


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "app", "images")
    os.makedirs(out, exist_ok=True)
    images = {
        # name: (width, height, [(text, scale)])
        "icon_hd.png": (290, 218, [("DX", 12), ("CLUSTER_", 4)]),
        "icon_fhd.png": (540, 405, [("DX", 22), ("CLUSTER_", 8)]),
        "splash_sd.png": (720, 480, [("DX CLUSTER_", 8)]),
        "splash_hd.png": (1280, 720, [("DX CLUSTER_", 14)]),
        "splash_fhd.png": (1920, 1080, [("DX CLUSTER_", 20)]),
    }
    for name, (w, h, lines) in images.items():
        write_png(os.path.join(out, name), w, h, render(w, h, lines))
        print(f"wrote app/images/{name} ({w}x{h})")


if __name__ == "__main__":
    main()
