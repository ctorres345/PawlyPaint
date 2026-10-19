"""Draws PawlyPaint's app icon: a faceted pink jewel on a soft blush tile.

Pure Python (no image libraries). Writes a 1024x1024 PNG plus a version
without the background tile for Android's adaptive icon foreground.
Run: python3 tool/make_icon.py assets/icon
"""
import math
import struct
import sys
import zlib

N = 1024
SS = 2  # supersampling per axis


def write_png(path, pixels, n=N):
    raw = b''.join(b'\x00' + bytes(v for px in pixels[y * n:(y + 1) * n] for v in px) for y in range(n))

    def chunk(t, b):
        return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)

    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', n, n, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    open(path, 'wb').write(png)


def inside(poly, x, y):
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            c = not c
        j = i
    return c


def hexc(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


# Jewel geometry in 0..1 units: a brilliant cut seen from the front.
TOP, GIRDLE, BOTTOM = 0.27, 0.43, 0.82
L, R = 0.16, 0.84
TL, TR = 0.30, 0.70
MID = 0.5
facets = [
    # (polygon, colour)
    ([(TL, TOP), (TR, TOP), (0.62, GIRDLE), (0.38, GIRDLE)], 0xFFB3C6),  # table
    ([(L, GIRDLE), (TL, TOP), (0.38, GIRDLE)], 0xFF8FAB),  # left crown
    ([(TR, TOP), (R, GIRDLE), (0.62, GIRDLE)], 0xE85A86),  # right crown
    ([(L, GIRDLE), (0.38, GIRDLE), (MID, BOTTOM)], 0xF2709A),  # left pavilion
    ([(0.38, GIRDLE), (0.62, GIRDLE), (MID, BOTTOM)], 0xE04A7A),  # centre pavilion
    ([(0.62, GIRDLE), (R, GIRDLE), (MID, BOTTOM)], 0xB8285A),  # right pavilion
]
outline = [(L, GIRDLE), (TL, TOP), (TR, TOP), (R, GIRDLE), (MID, BOTTOM)]


def jewel_pixel(u, v):
    """Colour of the jewel at (u, v), or None outside it."""
    if not inside(outline, u, v):
        return None
    for poly, col in facets:
        if inside(poly, u, v):
            r, g, b = hexc(col)
            # Soft vertical light falloff.
            k = 1.08 - 0.25 * (v - TOP) / (BOTTOM - TOP)
            return (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)))
    return hexc(0xE04A7A)


def sparkle(u, v, cx, cy, size):
    dx, dy = abs(u - cx), abs(v - cy)
    if dx < 0.006 and dy < size or dy < 0.006 and dx < size:
        return 1 - max(dx, dy) / size
    return 0


def render(with_tile):
    out = []
    for y in range(N):
        for x in range(N):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    u = (x + (sx + 0.5) / SS) / N
                    v = (y + (sy + 0.5) / SS) / N
                    if with_tile:
                        t = (u + v) / 2
                        bg = (int(255 - 6 * t), int(236 - 40 * t), int(242 - 26 * t), 255)
                    else:
                        bg = (0, 0, 0, 0)
                    px = jewel_pixel(u, v)
                    col = (*px, 255) if px else bg
                    s = max(sparkle(u, v, 0.37, 0.31, 0.07), sparkle(u, v, 0.74, 0.2, 0.05))
                    if s > 0:
                        a = min(1.0, s * 1.4)
                        col = tuple(int(c * (1 - a) + 255 * a) for c in col[:3]) + (max(col[3], int(255 * a)),)
                    for i in range(4):
                        acc[i] += col[i]
            out.append(tuple(int(a / (SS * SS)) for a in acc))
    return out


if __name__ == '__main__':
    out = sys.argv[1]
    write_png(f'{out}/icon.png', render(True))
    write_png(f'{out}/icon_foreground.png', render(False))
    print('done')
