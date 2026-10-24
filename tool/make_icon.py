"""Draws PawlyPaint's app icon: a paw made of jewels (four round gem toes
over a faceted pink jewel pad) on a soft blush tile.

Pure Python (no image libraries). Writes into the first directory:
  icon.png             1024x1024, tile + paw (launcher icon)
  icon_foreground.png  1024x1024, paw only, shrunk into Android's adaptive safe zone
and, when a second directory is given, the iOS launch images (paw only,
200/400/600 px) as LaunchImage.png, LaunchImage@2x.png, LaunchImage@3x.png.

Run: python3 tool/make_icon.py assets/icon ios/Runner/Assets.xcassets/LaunchImage.imageset
"""
import struct
import sys
import zlib

SS = 2  # supersampling per axis


def write_png(path, pixels, n):
    raw = b''.join(b'\x00' + bytes(v for px in pixels[y * n:(y + 1) * n] for v in px) for y in range(n))

    def chunk(t, b):
        return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)

    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', n, n, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    open(path, 'wb').write(png)


def hexc(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


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


# Geometry in 0..1 units of the 1024 px artwork.
def P(*pts):
    return [(x / 1024, y / 1024) for x, y in pts]


TOP, BOTTOM = 492.8 / 1024, 844.8 / 1024
JEWEL = P((255.2, 595.2), (361, 492.8), (663, 492.8), (768.8, 595.2), (512, 844.8))
FACETS = [
    (P((361, 492.8), (663, 492.8), (602.6, 595.2), (421.4, 595.2)), 0xFFB3C6),  # table
    (P((255.2, 595.2), (361, 492.8), (421.4, 595.2)), 0xFF8FAB),  # left crown
    (P((663, 492.8), (768.8, 595.2), (602.6, 595.2)), 0xE85A86),  # right crown
    (P((255.2, 595.2), (421.4, 595.2), (512, 844.8)), 0xF2709A),  # left pavilion
    (P((421.4, 595.2), (602.6, 595.2), (512, 844.8)), 0xE04A7A),  # centre pavilion
    (P((602.6, 595.2), (768.8, 595.2), (512, 844.8)), 0xB8285A),  # right pavilion
]
# Round gem toes: centre, radius, (rim, body, light) colours.
GEMS = [
    ((262, 452), 92, (0x7E57C2, 0xD1C4E9, 0xB39DDB)),
    ((418, 356), 98, (0x26A69A, 0xB2DFDB, 0x80CBC4)),
    ((606, 356), 98, (0xFB8C00, 0xFFE0B2, 0xFFCC80)),
    ((762, 452), 92, (0xD81B60, 0xF8BBD0, 0xF48FB1)),
]
SPARKLES = [((430, 560), 42, 5.5), ((690, 540), 30, 4.5)]  # centre, arm length, arm half-width


def over(dst, col, a):
    return tuple(int(d * (1 - a) + c * a) for d, c in zip(dst, col))


def gem_pixel(u, v, cx, cy, r, cols):
    cx, cy, r = cx / 1024, cy / 1024, r / 1024
    dx, dy = u - cx, v - cy
    if dx * dx + dy * dy > r * r:
        return None
    rim, body, light = (hexc(c) for c in cols)
    col = rim
    bx, by, br = cx - 0.04 * r, cy - 0.04 * r, 0.92 * r
    if (u - bx) ** 2 + (v - by) ** 2 <= br * br:
        col = body
    lx, ly, lr = cx + 0.03 * r, cy + 0.03 * r, 0.78 * r
    if (u - lx) ** 2 + (v - ly) ** 2 <= lr * lr:
        col = light
    hx, hy = cx - 0.3 * r, cy - 0.35 * r
    if ((u - hx) / (0.28 * r)) ** 2 + ((v - hy) / (0.16 * r)) ** 2 <= 1:
        col = over(col, (255, 255, 255), 0.7)
    return col


def paw_pixel(u, v):
    """Colour of the paw at (u, v), or None outside it."""
    col = None
    if inside(JEWEL, u, v):
        col = hexc(0xE04A7A)
        for poly, c in FACETS:
            if inside(poly, u, v):
                col = hexc(c)
                break
        k = 1.08 - 0.25 * (v - TOP) / (BOTTOM - TOP)  # soft vertical light falloff
        col = tuple(min(255, int(c * k)) for c in col)
        if abs(v - 595.2 / 1024) < 2.5 / 1024:
            col = over(col, (255, 255, 255), 0.35)
    for (cx, cy), r, cols in GEMS:
        g = gem_pixel(u, v, cx, cy, r, cols)
        if g:
            col = g
    for (cx, cy), arm, hw in SPARKLES:
        dx, dy = abs(u - cx / 1024), abs(v - cy / 1024)
        if (dx < hw / 1024 and dy < arm / 1024) or (dy < hw / 1024 and dx < arm / 1024):
            col = (255, 255, 255)
    return col


def render(n, with_tile, scale=1.0):
    out = []
    for y in range(n):
        for x in range(n):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    u = (x + (sx + 0.5) / SS) / n
                    v = (y + (sy + 0.5) / SS) / n
                    if with_tile:
                        t = (u + v) / 2
                        col = (int(255 - 6 * t), int(236 - 40 * t), int(242 - 26 * t), 255)
                    else:
                        col = (0, 0, 0, 0)
                    px = paw_pixel((u - 0.5) / scale + 0.5, (v - 0.5) / scale + 0.5)
                    if px:
                        col = (*px, 255)
                    for i in range(4):
                        acc[i] += col[i]
            out.append(tuple(int(a / (SS * SS)) for a in acc))
    return out


if __name__ == '__main__':
    out = sys.argv[1]
    write_png(f'{out}/icon.png', render(1024, True), 1024)
    write_png(f'{out}/icon_foreground.png', render(1024, False, 0.8), 1024)
    if len(sys.argv) > 2:
        launch = sys.argv[2]
        for suffix, n in (('', 200), ('@2x', 400), ('@3x', 600)):
            write_png(f'{launch}/LaunchImage{suffix}.png', render(n, False), n)
    print('done')
