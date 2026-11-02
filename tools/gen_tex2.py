"""Enemy Beyond - extra 32x32 textures for the new map tiles (own pixel art)."""
import os, random
from PIL import Image
T = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
R = random.Random(23)
def n(a): return R.uniform(-a, a)
def tex(name, fn, size=32):
    im = Image.new("RGB", (size, size)); px = im.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = tuple(max(0, min(255, int(c))) for c in fn(x, y))
    im.save(os.path.join(T, name + ".png"))
tex("concrete", lambda x, y: [118 + n(9) - (22 if x % 16 == 0 or y % 16 == 0 else 0) - (10 if R.random() < .04 else 0)] * 3)
tex("asphalt", lambda x, y: (52 + n(10) + (25 if R.random() < .03 else 0), 52 + n(10), 56 + n(10)))
def brick(x, y):
    row = y // 4; off = 4 if row % 2 else 0
    mortar = y % 4 == 0 or (x + off) % 8 == 0
    return (150, 145, 135) if mortar else (128 + n(14), 58 + n(8), 44 + n(8))
tex("brick", brick)
tex("rock", lambda x, y: (96 + n(18) - (20 if (x * 7 + y * 3) % 13 == 0 else 0), 92 + n(16), 86 + n(14)))
tex("water", lambda x, y: (28 + n(5), 52 + n(8) + (18 if (x + y * 2) % 11 == 0 else 0), 62 + n(8) + (22 if (x + y * 2) % 11 == 0 else 0)))
tex("corrugated", lambda x, y: (112 + n(6) - (34 if x % 4 == 0 else (14 if x % 4 == 1 else 0)), 116 + n(6) - (34 if x % 4 == 0 else (14 if x % 4 == 1 else 0)), 120 + n(6) - (30 if x % 4 == 0 else (12 if x % 4 == 1 else 0))))
for name, c in (("container_red", (140, 46, 36)), ("container_blue", (40, 72, 120)), ("container_green", (52, 96, 60))):
    tex(name, lambda x, y, c=c: tuple(v + n(7) - (30 if x % 5 == 0 else 0) - (15 if R.random() < .03 else 0) for v in c))
tex("tiles", lambda x, y: (175 + n(6) - (40 if x % 8 == 0 or y % 8 == 0 else 0), 170 + n(6) - (40 if x % 8 == 0 or y % 8 == 0 else 0), 160 + n(6) - (40 if x % 8 == 0 or y % 8 == 0 else 0)))
tex("wallpaper", lambda x, y: (120 + n(5) + (16 if x % 6 == 3 and y % 6 < 3 else 0), 104 + n(5), 84 + n(5) + (10 if x % 6 == 3 and y % 6 < 3 else 0)))
print("ok")
