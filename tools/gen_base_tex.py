"""Base textures (own designs, 32x32 like the rest): python3 tools/gen_base_tex.py"""
import random
from PIL import Image
random.seed(7)
def save(im, n): im.save('assets/textures/%s.png' % n)
def noise(c, a):
    return tuple(max(0, min(255, int(v + random.uniform(-a, a)))) for v in c)

# floor: light beige tiles, darker seams, a diamond inlay in each
im = Image.new('RGB', (32, 32))
for y in range(32):
    for x in range(32):
        lx, ly = x % 16, y % 16
        c = (196, 182, 168)
        if lx == 0 or ly == 0: c = (120, 108, 100)
        elif lx == 15 or ly == 15: c = (215, 204, 192)
        elif abs(lx - 8) + abs(ly - 8) == 5: c = (176, 160, 148)
        im.putpixel((x, y), noise(c, 5))
save(im, 'base_floor')

# wall: beige panels with a raised technical relief and tiny violet lamps
im = Image.new('RGB', (32, 32))
for y in range(32):
    for x in range(32):
        c = (172, 156, 144)
        if y in (0, 31) or x in (0, 16): c = (110, 98, 92)
        elif y in (1,) or x in (1, 17): c = (200, 188, 176)
        elif 6 <= y <= 25 and (x % 16 in (4, 12)): c = (140, 126, 118)
        elif y in (6, 25) and 4 <= x % 16 <= 12: c = (140, 126, 118)
        elif 10 <= y <= 21 and 6 <= x % 16 <= 10: c = (158, 143, 132)
        if (x % 16, y) in ((8, 3), (8, 28)): c = (190, 120, 255)
        im.putpixel((x, y), noise(c, 4))
save(im, 'base_wall')

# hangar floor: dark grey plates
im = Image.new('RGB', (32, 32))
for y in range(32):
    for x in range(32):
        c = (92, 96, 102)
        if x == 0 or y == 0: c = (66, 70, 76)
        im.putpixel((x, y), noise(c, 6))
save(im, 'hangar_floor')

# raw earth around the base: brown, lumpy, dark specks
im = Image.new('RGB', (32, 32))
for y in range(32):
    for x in range(32):
        c = noise((104, 66, 42), 18)
        if random.random() < 0.08: c = (58, 34, 22)
        im.putpixel((x, y), c)
save(im, 'earth')
print('ok')
