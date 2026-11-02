"""Generates the globe textures (equirectangular) from the public-domain
GLOBE land mask (pip package global-land-mask): day colours and night lights."""
import sys, os
import numpy as np
from PIL import Image
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
# land: green in the tropics / temperate, dry belts, tundra, ice
green = np.array([0.20, 0.36, 0.16])
dry = np.array([0.55, 0.48, 0.30])
tundra = np.array([0.45, 0.47, 0.40])
ice = np.array([0.88, 0.9, 0.93])
dryness = np.clip(1 - np.abs(a - 25) / 12, 0, 1) * (0.5 + smooth)
col = green[None, None, :] * (1 - dryness[..., None]) + dry[None, None, :] * dryness[..., None]
col = np.where((a > 58)[..., None], tundra[None, None, :], col)
col = np.where((a > 70)[..., None], ice[None, None, :], col)
col = col * (0.8 + 0.35 * smooth[..., None])
ocean = np.array([0.03, 0.09, 0.22]) * (0.8 + 0.3 * smooth[..., None])
ocean = np.where((a > 72)[..., None], ice * 0.85, ocean)
from PIL import ImageFilter
coast = np.asarray(Image.fromarray((land * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))) / 255.0
ocean = ocean + np.array([0.03, 0.08, 0.10])[None, None, :] * np.clip(coast * 2.0, 0, 1)[..., None]
img = np.where(land[..., None], col, ocean)
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((2048, 1024), Image.LANCZOS).save(os.path.join(out, "earth_day.png"))
# night: scattered warm lights on land, denser in temperate latitudes
lights = (rng.random((H, W)) > 0.9985) & land & (a < 62)
lights |= (rng.random((H, W)) > 0.993) & land & (a > 25) & (a < 55) & (smooth > 0.5)
n = np.zeros((H, W, 3))
n[lights] = [1.0, 0.75, 0.4]
ni = Image.fromarray((n * 255).astype(np.uint8))
glow = ni.filter(ImageFilter.GaussianBlur(4))
n2 = np.clip(np.asarray(ni, dtype=float) + np.asarray(glow, dtype=float) * 6.0, 0, 255).astype(np.uint8)
Image.fromarray(n2).resize((2048, 1024), Image.LANCZOS).save(os.path.join(out, "earth_night.png"))
# land mask for mission placement (1 = land), small is enough
Image.fromarray((land * 255).astype(np.uint8)).resize((1024, 512), Image.NEAREST).save(os.path.join(out, "earth_land.png"))
print("globe textures written")
