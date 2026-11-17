"""Návrhy nových tetování jako pixel art (znaky: . kůže, X inkoust, R červený inkoust).
Kreslí se ve vyšším rozlišení (tvary), pak se převzorkuje na mřížku."""
import math
from PIL import Image, ImageDraw

SS = 8  # nadvzorkování

# ---------- malé písmo (výška 5, akcent o řádek výš) ----------
F = {
 "A": ["XXX", "X.X", "XXX", "X.X", "X.X"], "B": ["XX.", "X.X", "XX.", "X.X", "XX."],
 "D": ["XX.", "X.X", "X.X", "X.X", "XX."], "E": ["XXX", "X..", "XX.", "X..", "XXX"],
 "I": ["X", "X", "X", "X", "X"], "J": ["..X", "..X", "..X", "X.X", "XXX"],
 "L": ["X..", "X..", "X..", "X..", "XXX"], "M": ["X...X", "XX.XX", "X.X.X", "X...X", "X...X"],
 "N": ["X..X", "XX.X", "X.XX", "X..X", "X..X"], "O": ["XXX", "X.X", "X.X", "X.X", "XXX"],
 "P": ["XXX", "X.X", "XXX", "X..", "X.."], "R": ["XX.", "X.X", "XX.", "X.X", "X.X"],
 "S": ["XXX", "X..", "XXX", "..X", "XXX"], "T": ["XXX", ".X.", ".X.", ".X.", ".X."],
 "U": ["X.X", "X.X", "X.X", "X.X", "XXX"], "V": ["X.X", "X.X", "X.X", "X.X", ".X."],
 "G": ["XXX", "X..", "X.X", "X.X", "XXX"], "K": ["X.X", "X.X", "XX.", "X.X", "X.X"],
 "Y": ["X.X", "X.X", ".X.", ".X.", ".X."], "Z": ["XXX", "..X", ".X.", "X..", "XXX"],
 " ": ["..", "..", "..", "..", ".."],
}
ACC = {"Á": ("A", "acute"), "É": ("E", "acute"), "Í": ("I", "acute"), "Ě": ("E", "caron"),
       "Ř": ("R", "caron"), "Ž": ("Z", "caron")}

def text(s):
    """Řádky pixel textu (7 řádků: akcent, mezera, 5 písmo)."""
    cols = []
    acc_row = []
    for i, ch in enumerate(s):
        base, acc = ACC.get(ch, (ch, None))
        g = F[base]
        w = len(g[0])
        a = "." * w
        if acc == "acute":
            a = "." * (w - 1) + "X" if w > 1 else "X"
        elif acc == "caron":
            a = ("X" + "." * (w - 2) + "X") if w > 2 else "X"
        glyph = [a, "." * w] + g
        if cols:
            glyph = ["." + r for r in glyph]
        cols.append(glyph)
    rows = ["".join(c[r] for c in cols) for r in range(7)]
    if not any(ch in ACC for ch in s):
        rows = rows[2:]
    return rows

def paste(grid, rows, x0, y0, ch="X"):
    for r, line in enumerate(rows):
        for c, v in enumerate(line):
            if v == "X" and 0 <= y0 + r < len(grid) and 0 <= x0 + c < len(grid[0]):
                grid[y0 + r][x0 + c] = ch

def raster(w, h, draw_fn):
    """draw_fn(d, s) kreslí do L obrázku (s = měřítko na pixel mřížky). 1 = X, 2 = R."""
    imgs = {}
    for key in ("X", "R"):
        im = Image.new("L", (w * SS, h * SS), 0)
        draw_fn(ImageDraw.Draw(im), SS, key)
        imgs[key] = im.resize((w, h), Image.BOX)
    grid = [["."] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if imgs["R"].getpixel((x, y)) > 110:
                grid[y][x] = "R"
            elif imgs["X"].getpixel((x, y)) > 110:
                grid[y][x] = "X"
    return grid

def poly(d, pts, s):
    d.polygon([(x * s, y * s) for x, y in pts], fill=255)

def rot(pts, cx, cy, a):
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]

# ---------- 1. Žoldnéři: tři meče hroty do středu v uzavřeném kruhu ----------
# Ostré tvary (ne pixely): obdélníky (střed x, y, šířka, výška, úhel°) v jednotkách, 1 j. = ZU m.
ZU = 0.0025
def zoldneri_shapes():
    out = []
    def sword(a_deg):
        a = math.radians(a_deg)
        def put(r, side, w, h, extra=0.0):
            # r = vzdálenost od středu podél meče, side = do strany; w podél meče, h napříč
            x = r * math.cos(a) - side * math.sin(a)
            y = r * math.sin(a) + side * math.cos(a)
            out.append((x, y, w, h, a_deg + extra))
        put(6.0, 0, 9.0, 2.4)            # čepel
        put(1.55, 0, 1.6, 1.6, 45)       # hrot (kosočtverec)
        put(11.25, 0, 1.3, 9.6)          # záštita
        put(11.25, 4.55, 2.0, 1.3)       # konce záštity (zahnuté k hrotu)
        put(11.25, -4.55, 2.0, 1.3)
        put(13.0, 0, 2.6, 1.5)           # rukojeť
        put(14.95, 0, 1.75, 1.75, 45)    # hlavice
    for k in range(3):
        sword(-90 + k * 120)             # první rukojetí nahoru
    R, T, n = 17.6, 1.7, 72              # kruh
    for i in range(n):
        a = i * 360 / n
        out.append((R * math.cos(math.radians(a)), R * math.sin(math.radians(a)), T, 2 * math.pi * R / n * 1.08, a))
    return out

def draw_shapes(d, shapes, cx, cy, sc, fill):
    for x, y, w, h, ang in shapes:
        a = math.radians(ang)
        ca, sa = math.cos(a), math.sin(a)
        pts = []
        for px_, py_ in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
            pts.append((cx + (x + px_ * ca - py_ * sa) * sc, cy + (y + px_ * sa + py_ * ca) * sc))
        d.polygon(pts, fill=fill)

# ---------- 2. Máma v srdci ----------
def heart_pts(cx, cy, k):
    pts = []
    for i in range(240):
        t = i / 240 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * k, cy - y * k))
    return pts

def mama(d, s, key):
    if key == "R":
        poly(d, heart_pts(14.5, 10.2, 0.68), s)
    else:
        poly(d, heart_pts(14.5, 10.2, 0.78), s)
        d.polygon([(x * s, y * s) for x, y in heart_pts(14.5, 10.2, 0.68)], fill=0)

def mama_grid():
    g = raster(29, 24, mama)
    y0, y1 = 9, 17                     # stuha přes srdce, konce s vykrojením
    for y in range(y0, y1 + 1):
        for x in range(2, 27):
            g[y][x] = "X" if y in (y0, y1) or x in (2, 26) else "."
    for y in range(y0 + 2, y1 + 3):
        g[y][0] = g[y][1] = "X"; g[y][27] = g[y][28] = "X"
    g[y0 + 6][0] = "."; g[y0 + 6][28] = "."
    paste(g, text("MÁMA"), 5, y0 + 2)
    return g

# ---------- 3. Invaders must die (dva řádky podél paže + UFO v kříži) ----------
def invaders_grid():
    l1, l2 = text("INVADERS"), text("MUST DIE")
    W = max(len(l1[0]), len(l2[0])) + 15
    H = 13
    g = [["."] * W for _ in range(H)]
    # UFO v zaměřovači vlevo
    ufo = ["....XXX....", "...X...X...", ".XXXXXXXXX.", "XX.X.X.X.XX", ".XXXXXXXXX."]
    cross = raster(13, 13, lambda d, s, k: (k == "X") and (
        d.ellipse([0.4 * s, 0.4 * s, 12.6 * s, 12.6 * s], fill=255),
        d.ellipse([1.6 * s, 1.6 * s, 11.4 * s, 11.4 * s], fill=0)))
    for y in range(13):
        for x in range(13):
            if cross[y][x] == "X":
                g[y][x] = "X"
    for i in range(13):
        if i < 3 or i > 9:
            g[6][i] = "X"
            g[i][6] = "X"
    paste(g, ufo, 1, 4, "R")
    paste(g, l1, 15, 0)
    paste(g, l2, 15, 7)
    return g

# ---------- 4. Pomstím tě (kráva v paprsku UFO) ----------
def krava_grid():
    W = 29
    art = [
        "........XXXXXXXXXXX..........",
        ".....XXXX.........XXXX.......",
        "..XXXXXXXXXXXXXXXXXXXXXXX....",
        ".XX.XX..XX..XX..XX..XX.XXX...",
        "..XXXXXXXXXXXXXXXXXXXXXXX....",
        "......R.............R........",
        ".....R...............R.......",
        "....R..X.X.............R.....",
        "....R..XXXXXXXXXXXXX.X.R.....",
        "...R...XXXX..XXX..XXXX..R....",
        "...R....XXXXXXX..XXXXX..R....",
        "..R.......XXXXXXXXXXX....R...",
        "..R.......X.X.....X.X....R...",
        ".R........X.X.....X.X.....R..",
        ".R.........................R.",
        ".............................",
    ]
    g = [list(r) for r in art]
    for line in ("POMSTÍM", "TĚ"):
        t = text(line)
        w = len(t[0])
        for r in t:
            g.append(list(("." * ((W - w) // 2) + r).ljust(W, ".")))
        g.append(list("." * W))
    return g[:-1]

# ---------- 5. Mrtvý vetřelec ----------
def vetrelec_grid():
    art = [
        ".....XXXXXXX.....",
        "...XX.......XX...",
        "..X...........X..",
        ".X.............X.",
        "X...............X",
        "X.X...X...X...X.X",
        "X..X.X.....X.X..X",
        "X...X.......X...X",
        "X..X.X.....X.X..X",
        ".XX...X...X...XX.",
        "..X...........X..",
        "...X..XXXXX..X...",
        "....X.......X....",
        ".....X.....X.....",
        "......XXXXX......",
        ".................",
    ]
    g = [list(r) for r in art]
    for r in text("RIP"):
        g.append(list(("." * 6 + r).ljust(17, ".")))
    return g

# ---------- 6. Pivo ----------
def pivo_grid():
    art = [
        "..XX..XXX..XX....",
        ".X..XX...XX..X...",
        "X.............X..",
        "XXXXXXXXXXXXXXXXX",
        "X.X..........XX.X",
        "X.X..X....X..XX.X",
        "X.X......X...XX.X",
        "X.X...X......XX.X",
        "X.X.....X....XX.X",
        "X.X..X.......XXXX",
        "X.X..........X...",
        "XXXXXXXXXXXXXX...",
        "XXXXXXXXXXXXXX...",
        ".................",
    ]
    g = [list(r) for r in art]
    for r in text("PIVO"):
        g.append(list(("." * 0 + r).ljust(17, ".")))
    return g

# ---------- 7. Bojím se tmy (jen text, dva řádky) ----------
def tmy_grid():
    l1, l2 = text("BOJÍM"), text("SE TMY")
    W = max(len(l1[0]), len(l2[0]))
    g = [["."] * W for _ in range(len(l1) + 1 + len(l2))]
    paste(g, l1, (W - len(l1[0])) // 2, 0)
    paste(g, l2, (W - len(l2[0])) // 2, len(l1) + 1)
    return g


# ---------- 8. Krull (orčí hlava) ----------
def krull_grid():
    art = [
        "..........XXX..........",
        "........XXXXXXX........",
        "XX....XXX.....XXX....XX",
        "X.XX.X...........X.XX.X",
        ".X..XX...........XX..X.",
        "..X.X.XXXX...XXXX.X.X..",
        "...XX..XXX...XXX..XX...",
        "....X..X.X...X.X..X....",
        "....X.............X....",
        "....X......X......X....",
        "....X..X..XXX..X..X....",
        "....XX.X.......X.XX....",
        ".....X.XXXXXXXXX.X.....",
        ".....XX.X.X.X.X.XX.....",
        "......X.........X......",
        ".......XX.....XX.......",
        ".........XXXXX.........",
        ".......................",
    ]
    g = [list(r) for r in art]
    t = text("KRULL")
    w = len(t[0])
    for r in t:
        g.append(list(("." * ((23 - w) // 2) + r).ljust(23, ".")))
    return g

# ---------- 9. Ignorbris (had, který si kouše do ocasu) ----------
def ouro(d, s, key):
    if key != "X":
        return
    s = s * OK_
    c, R = 17.5, 12.0
    def P(phi, r):
        return (c + r * math.cos(math.radians(phi)), c + r * math.sin(math.radians(phi)))
    ph_head, ph_tail = -118.0, -94.0 - 360.0
    n = 120
    outer, inner = [], []
    for i in range(n + 1):
        t = i / n                       # 0 = krk, 1 = špička ocasu
        phi = ph_head + (ph_tail - ph_head) * t
        w = 2.5 * (1 - t) + 0.85 * t
        outer.append(P(phi, R + w)); inner.append(P(phi, R - w))
    poly(d, outer + inner[::-1], s)
    # šupiny: příčné proužky kůže
    for k in range(1, 20):
        t = k / 21
        phi = ph_head + (ph_tail - ph_head) * t
        w = (2.5 * (1 - t) + 0.5 * t) * 0.6
        a1, a2 = P(phi - 4, R - w), P(phi + 4, R + w)
        d.line([(a1[0] * s, a1[1] * s), (P(phi, R)[0] * s, P(phi, R)[1] * s), (a2[0] * s, a2[1] * s)], fill=0, width=max(1, int(0.5 * s)))
    # hlava: protáhlá, natočená po směru kruhu (k ocasu), otevřená tlama kolem špičky ocasu
    hc = P(ph_head + 9, R)
    ang = math.radians(ph_head + 9 + 90)          # tečna (směr k ocasu)
    head = [(-4.2, -3.6), (1.2, -4.3), (5.2, -2.0), (5.8, 0.0), (5.2, 2.0), (1.2, 4.3), (-4.2, 3.6), (-5.4, 0)]
    poly(d, rot(head, hc[0], hc[1], ang), s)
    mouth = [(6.2, -2.0), (1.2, 0.0), (6.2, 2.0)]
    d.polygon([(x * s, y * s) for x, y in rot(mouth, hc[0], hc[1], ang)], fill=0)
    for ex in (-1.8,):
        for ey in (-2.0, 2.0):
            e = rot([(ex, ey)], hc[0], hc[1], ang)[0]
            d.ellipse([(e[0] - 0.7) * s, (e[1] - 0.7) * s, (e[0] + 0.7) * s, (e[1] + 0.7) * s], fill=0)

OK_ = 50 / 35
def ouro_grid():
    W = 66
    ring = raster(50, 50, ouro)
    g = [list("." * 8 + "".join(r) + "." * 8) for r in ring]
    g += [list("." * W) for _ in range(3)]
    t = text("IGNORBRIS")
    t2 = []
    for r in t:                         # písmo dvakrát větší
        rr = "".join(ch * 2 for ch in r)
        t2 += [rr, rr]
    w = len(t2[0])
    for r in t2:
        g.append(list(("." * ((W - w) // 2) + r).ljust(W, ".")))
    return g

# ---------- 10. Lovec UFO (přeškrtnuté UFO v kruhu + čárky) ----------
def noufo(d, s, key):
    c = 12.5
    if key == "R":
        d.ellipse([0.6 * s, 0.6 * s, 24.4 * s, 24.4 * s], fill=255)
        d.ellipse([2.6 * s, 2.6 * s, 22.4 * s, 22.4 * s], fill=0)
        poly(d, rot([(-10, -1.0), (10, -1.0), (10, 1.0), (-10, 1.0)], c, c, math.radians(45)), s)

def noufo_grid():
    g = raster(25, 25, noufo)
    ufo = ["......XXXXX......", "....XX.....XX....", ".XXXXXXXXXXXXXXX.", "XX..X..X..X..X.XX", ".XXXXXXXXXXXXXXX.", "...X.........X..."]
    for r, line in enumerate(ufo):
        for cc, v in enumerate(line):
            if v == "X" and g[9 + r][4 + cc] == ".":
                g[9 + r][4 + cc] = "X"
    g.append(list("." * 25))
    for r in range(5):        # čárky: kolik už jich bylo
        g.append(list("...X.X.X.X....X.X.X.X....".replace("X", "X") if r < 5 else ""))
    for x in range(2, 11):
        g[26 + 2][x] = "X"
    return g

def rows(g):
    return ["".join(r) for r in g]

# název, id, mřížka, velikost pixelu (m), podél paže (otočit o 90°), místo
DESIGNS = [
    ("Máma", "mama", mama_grid(), 0.0031, False),
    ("Invaders must die", "invaders", invaders_grid(), 0.0042, True),
    ("Pomstím tě", "krava", krava_grid(), 0.0031, False),
    ("Mrtvý vetřelec", "vetrelec", vetrelec_grid(), 0.0045, False),
    ("Pivo", "pivo", pivo_grid(), 0.0045, False),
    ("Bojím se tmy", "tmy", tmy_grid(), 0.0042, True),
    ("Krull", "krull", krull_grid(), 0.0032, False),
    ("Ignorbris", "ignorbris", ouro_grid(), 0.00113, False),
    ("Lovec UFO", "lovec", noufo_grid(), 0.0029, False),
]

if __name__ == "__main__":
    for name, id_, g, px, along in DESIGNS:
        print(name, len(g[0]), "x", len(g), "=", "%.1f x %.1f cm" % (len(g[0]) * px * 100, len(g) * px * 100))
        print("\n".join(rows(g)))
        print()
