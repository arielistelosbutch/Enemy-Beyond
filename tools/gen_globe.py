"""Generates the globe textures (equirectangular) from the public-domain
GLOBE land mask (pip package global-land-mask): day colours and night lights.
(2026-11-27) The land colours come from assets/textures/earth_climate.png (tools/geo/build_geo.py),
so the globe shows the same deserts, savannas and jungles the missions are built on; the night
lights sit on real towns when the GeoNames csv is given: gen_globe.py <root> [rg_cities1000.csv]."""
import sys, os
import numpy as np
from PIL import Image, ImageFilter
from global_land_mask import globe

out = os.path.join(sys.argv[1] if len(sys.argv) > 1 else ".", "assets", "textures")
W, H = 4096, 2048   # rendered big, then downscaled (smooth coasts)
lat = np.linspace(89.9, -89.9, H)
lon = np.linspace(-179.9, 179.9, W)
LON, LAT = np.meshgrid(lon, lat)
land = globe.is_land(LAT, LON)
rng = np.random.default_rng(3)
noise = rng.normal(0, 1, (H, W))
# a little smooth noise for terrain variation
from numpy.fft import fft2, ifft2
k = np.exp(-((np.fft.fftfreq(H)[:, None] ** 2 + np.fft.fftfreq(W)[None, :] ** 2) * 3000))
smooth = np.real(ifft2(fft2(noise) * k))
smooth = (smooth - smooth.min()) / (smooth.max() - smooth.min())
img = np.zeros((H, W, 3))
a = np.abs(LAT)
# land: the colours of the climate map (the same one the missions use)
clim0 = np.asarray(Image.open(os.path.join(out, "earth_climate.png")).resize((W, H), Image.NEAREST))
# ragged edges instead of the boxes of the climate map (only the picture; the missions read the map itself)
n2 = rng.normal(0, 1, (H, W))
k2 = np.exp(-((np.fft.fftfreq(H)[:, None] ** 2 + np.fft.fftfreq(W)[None, :] ** 2) * 60000))
wx = np.real(ifft2(fft2(n2) * k2)); wx = wx / np.abs(wx).max()
wy = np.real(ifft2(fft2(np.roll(n2, 777, 1)) * k2)); wy = wy / np.abs(wy).max()
yy, xx = np.mgrid[0:H, 0:W]
clim = clim0[np.clip(yy + (wy * 40).astype(int), 0, H - 1), (xx + (wx * 40).astype(int)) % W]
clim = np.where((clim == 0) & (a > 60), 5, clim)
PAL = {0: [0.20, 0.36, 0.16], 1: [0.20, 0.36, 0.16], 2: [0.46, 0.44, 0.24], 3: [0.62, 0.52, 0.32], 4: [0.10, 0.27, 0.10], 5: [0.88, 0.9, 0.93]}
col = np.zeros((H, W, 3))
for k, c in PAL.items():
    col[clim == k] = c
col = np.stack([np.asarray(Image.fromarray((col[..., i] * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9)), dtype=float) / 255.0 for i in range(3)], -1)
tundra = np.array([0.45, 0.47, 0.40])
ice = np.array([0.88, 0.9, 0.93])
col = np.where(((a > 62) & (clim != 5))[..., None], col * 0.5 + tundra * 0.5, col)
col = np.where((clim == 5)[..., None], ice[None, None, :], col)
col = col * (0.8 + 0.35 * smooth[..., None])
ocean = np.array([0.03, 0.09, 0.22]) * (0.8 + 0.3 * smooth[..., None])
ocean = np.where((a > 72)[..., None], ice * 0.85, ocean)
from PIL import ImageFilter
coast = np.asarray(Image.fromarray((land * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))) / 255.0
ocean = ocean + np.array([0.03, 0.08, 0.10])[None, None, :] * np.clip(coast * 2.0, 0, 1)[..., None]
img = np.where(land[..., None], col, ocean)
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((2048, 1024), Image.LANCZOS).save(os.path.join(out, "earth_day.png"))
# night: scattered warm lights on land, denser in temperate latitudes
if len(sys.argv) > 2:
    import csv
    lights = np.zeros((H, W), bool)
    for r in csv.DictReader(open(sys.argv[2], encoding="utf-8")):
        if rng.random() < 0.07:
            y = int((90.0 - float(r["lat"])) / 180.0 * H); x = int((float(r["lon"]) + 180.0) / 360.0 * W)
            if 0 <= y < H and 0 <= x < W and land[y, x]:
                lights[y, x] = True
else:
    lights = (rng.random((H, W)) > 0.9985) & land & (a < 62)
    lights |= (rng.random((H, W)) > 0.993) & land & (a > 25) & (a < 55) & (smooth > 0.5)
n = np.zeros((H, W, 3))
n[lights] = [1.0, 0.75, 0.4]
ni = Image.fromarray((n * 255).astype(np.uint8))
glow = ni.filter(ImageFilter.GaussianBlur(4))
n2 = np.clip(np.asarray(ni, dtype=float) + np.asarray(glow, dtype=float) * 6.0, 0, 255).astype(np.uint8)
Image.fromarray(n2).resize((2048, 1024), Image.LANCZOS).save(os.path.join(out, "earth_night.png"))
# land mask for mission placement (1 = land), small is enough
if not os.path.exists(os.path.join(out, "earth_land.png")):
    Image.fromarray((land * 255).astype(np.uint8)).resize((1024, 512), Image.NEAREST).save(os.path.join(out, "earth_land.png"))
print("globe textures written")
