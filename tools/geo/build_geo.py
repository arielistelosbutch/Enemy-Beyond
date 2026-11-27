#!/usr/bin/env python3
"""Builds the globe's geography for Projekt X (2026-11-27, Ari: „místa misí a biomy podle místa“).

 assets/textures/earth_country.png  1440x720 (0,25°), L: index+1 into COUNTRIES (0 = none)
 assets/textures/earth_climate.png  1440x720, L: 1 temperate, 2 dry (steppe/savanna), 3 desert, 4 tropic, 5 ice
 scripts/geo_data.gd                COUNTRIES, REGIONS, CITIES (czech names, real coordinates)

Countries: nearest of GeoNames' 144 000 places (reverse_geocoder's rg_cities1000.csv, CC BY 4.0),
merged to the 1990 states (SSSR, Jugoslávie, Československo, two Germanies).
Usage: python3 tools/geo/build_geo.py <rg_cities1000.csv>
"""
import csv, sys, os
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree
sys.path.insert(0, os.path.dirname(__file__))
from names_cs import NAMES, GDR
from places_cs import REGIONS, CITIES

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
W, H = 1440, 720

rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8")))
lat = np.array([float(r["lat"]) for r in rows]); lon = np.array([float(r["lon"]) for r in rows])
cc = [r["cc"] for r in rows]
# the 1990 Germanies
key = []
for r in rows:
    c = r["cc"]
    if c == "DE":
        key.append("DDR" if r["admin1"] in GDR else "DE")
    else:
        key.append(c)
names = dict(NAMES); names["DDR"] = "NDR"; names["DE"] = "NSR"

def xyz(la, lo):
    la = np.radians(la); lo = np.radians(lo)
    return np.stack([np.cos(la) * np.cos(lo), np.cos(la) * np.sin(lo), np.sin(la)], -1)

tree = cKDTree(xyz(lat, lon))
gy, gx = np.mgrid[0:H, 0:W]
plat = 90.0 - (gy + 0.5) * 180.0 / H
plon = (gx + 0.5) * 360.0 / W - 180.0
d, idx = tree.query(xyz(plat.ravel(), plon.ravel()))
idx = idx.reshape(H, W)
far = (d.reshape(H, W) > 0.12)          # ~7° from any place: open sea / ice

codes = sorted(set(key))
order = [c for c in codes]
cidx = {c: i for i, c in enumerate(order)}
keyarr = np.array([cidx[k] for k in key])
country = keyarr[idx] + 1
country[far] = 0
code_at = np.array(order + [""], dtype=object)

# ---- climate ---------------------------------------------------------------------------------
TEMP, DRY, DESERT, TROPIC, ICE = 1, 2, 3, 4, 5
cl = np.full((H, W), TEMP, np.uint8)
C = np.where(country > 0, np.array([""] + order, dtype=object)[country], "")
la, lo = plat, plon
def isin(*cs):
    m = np.zeros((H, W), bool)
    for c in cs:
        m |= (C == c)
    return m
def box(a0, a1, o0, o1):
    return (la >= a0) & (la <= a1) & (lo >= o0) & (lo <= o1)
S = lambda m, v: cl.__setitem__(m, v)

# dry: steppes and savannas
S(isin("KZ", "MN") , DRY)
S(isin("SN", "GM", "BF", "ML", "NE", "TD", "SD", "SS", "ER", "ET", "SO", "DJ", "KE", "TZ", "UG", "ZM", "ZW", "BW", "NA", "MZ", "AO", "MW", "MG", "ZA", "LS", "SZ"), DRY)
S(isin("NG", "CM", "CF", "GH", "CI", "TG", "BJ", "GN") & (la > 9.0), DRY)
S(isin("SA", "YE", "OM", "AE", "QA", "KW", "BH", "IQ", "SY", "JO", "IR", "AF", "PK", "TM", "UZ", "TJ", "KG"), DRY)
S(isin("TR") & box(37.5, 40.5, 31, 41), DRY)
S(isin("IN") & ~box(8, 13.5, 74, 78) & ~box(21, 28.5, 86, 98) & ~(lo > 89), DRY)
S(isin("AU"), DRY)
S(isin("US") & box(30, 49, -105, -97.5), DRY)
S(isin("US") & box(31, 49, -121, -104) , DRY)
S(isin("MX") & (la > 18.5), DRY)
S(isin("BR") & box(-21, -3, -56, -36), DRY)
S(isin("AR") & ((la < -38) | box(-35, -22, -70, -64)), DRY)
S(isin("CN") & (box(35, 50, 73, 125) & ~box(39, 50, 120, 135)), DRY)
S(isin("CN") & box(28, 37, 78, 103), DRY)          # Tibet / Qinghai
S(isin("RU") & box(44, 53, 40, 55) , DRY)            # Volga steppe
S(isin("UA") & (la < 47.5), DRY)
S(isin("ES") & box(37.5, 42, -5.5, -1), DRY)
S(isin("VE") & (la > 6) & (lo > -72), DRY)
S(isin("CO") & (la > 10), DRY)
S(isin("CU", "HT", "DO", "JM", "BS", "PR"), TEMP)
# desert
S(isin("EG", "LY", "MR", "EH", "SA", "AE", "QA", "KW", "BH", "DJ"), DESERT)
S(isin("DZ") & (la < 33.5), DESERT)
S(isin("TN") & (la < 33.8), DESERT)
S(isin("MA") & (la < 30.5), DESERT)
S(isin("ML", "NE", "TD") & (la > 15.5), DESERT)
S(isin("SD") & (la > 15.8), DESERT)
S(isin("ER") & (lo > 39.0), DESERT)
S(isin("SO") & (la > 8.0) , DESERT)
S(isin("YE") & ((la > 15.5) | (lo > 48)), DESERT)
S(isin("OM") & ~box(22.5, 24.5, 56.5, 60), DESERT)
S(isin("IQ") & ~((la > 35.0) & (lo > 42.5)), DESERT)
S(isin("JO") & (lo > 35.9), DESERT)
S(isin("SY") & (lo > 38.6) & (la < 36.2), DESERT)
S(isin("IL") & (la < 31.2), DESERT)
S(isin("IR") & box(27, 36, 51.5, 61.5), DESERT)
S(isin("AF") & (la < 32) & (lo < 66.5), DESERT)
S(isin("PK") & ((la < 29.5) & (lo < 70.5) | box(24, 28.5, 68.5, 71.2)), DESERT)
S(isin("IN") & box(24.5, 30, 69, 73.6), DESERT)
S(isin("TM") & (la < 41.5), DESERT)
S(isin("UZ") & (lo < 66) , DESERT)
S(isin("KZ") & box(43, 46, 59, 70) , DESERT)
S(isin("CN") & box(36.5, 42.5, 76, 92), DESERT)       # Taklamakan
S(isin("CN", "MN") & box(40, 45.5, 94, 112), DESERT)   # Gobi
S(isin("US") & box(31, 37.5, -118.5, -110) , DESERT)  # Mojave, Sonoran
S(isin("US") & box(37.5, 41.5, -119.5, -114) , DESERT)  # Great Basin
S(isin("US") & box(31, 35, -110, -104.5) , DESERT)    # Chihuahuan
S(isin("MX") & ((box(26, 33, -116, -104)) | box(22.5, 30, -116, -109)), DESERT)
S(isin("PE") & (lo < -76.5) & (la < -5) , DESERT)       # the coast
S(isin("CL") & box(-29, -17, -72, -67), DESERT)        # Atacama
S(isin("NA") & ((lo < 17.5) | (la < -25)), DESERT)
S(isin("BW") & (la < -21) & (lo < 25), DESERT)        # Kalahari
S(isin("ZA") & (lo < 21.5) & (la > -32.5), DESERT)
S(isin("AU") & box(-31.5, -19.5, 118, 141.5), DESERT)
S(isin("ET") & box(11, 15, 39.5, 43), DESERT)          # Danakil
S(isin("AR") & box(-50, -42, -71, -66), DESERT)
# tropic: rain forest and the wet tropics
S(isin("BR") & ((la > -10) & (lo < -47)), TROPIC)
S(isin("BR") & (lo > -45) & (la > -25) & (la < -12) & (lo > -42.5 + 0 * la), TROPIC)
S(isin("BR") & box(-25, -12, -44, -34), TROPIC)
S(isin("CO", "EC", "GY", "SR", "GF", "PA", "CR", "NI", "HN", "GT", "BZ", "SV"), TROPIC)
S(isin("CO") & (la > 10), DRY)
S(isin("EC") & (lo < -80.3), DRY)
S(isin("VE") & ((la <= 6) | (lo <= -72)), TROPIC)
S(isin("PE") & (lo > -76.5), TROPIC)
S(isin("BO") & (la > -17), TROPIC)
S(isin("MX") & (la < 18.5) & (lo > -98), TROPIC)
S(isin("CD", "CG", "GA", "GQ", "LR", "SL", "RW", "BI", "UG", "ST"), TROPIC)
S(isin("NG", "CM", "CF", "GH", "CI", "TG", "BJ", "GN", "GW") & (la <= 9.0), TROPIC)
S(isin("MG") & (lo > 47.5), TROPIC)
S(isin("TH", "VN", "LA", "KH", "MM", "MY", "SG", "BN", "ID", "TL", "PH", "PG", "SB", "LK", "BD", "VU", "FJ"), TROPIC)
S(isin("MM") & (la > 24), TEMP)
S(isin("IN") & (box(8, 13.5, 74, 78) | box(21, 28.5, 86, 98) | (lo > 89)), TROPIC)
S(isin("CN") & (la < 24.5) & (lo > 97), TROPIC)
S(isin("AU") & box(-20, -10, 142, 147), TROPIC)
S(isin("AU") & (la > -15) & (lo < 137), TROPIC)
S(isin("US") & (lo < -154) & (la < 23), TROPIC)       # Hawaii
S(isin("US") & box(24.5, 27.5, -82, -80), TROPIC)     # south Florida
S(isin("CU", "HT", "DO", "JM", "BS", "PR", "TT", "KN", "AG", "DM", "LC", "VC", "GD", "BB", "GP", "MQ", "VI", "VG", "AW", "CW", "BQ", "SX", "KY", "TC"), TROPIC)
S(isin("KE", "TZ", "MZ") & (lo > 39.0) & (la < -0.5) , TROPIC)     # the coast
# ice
S(isin("GL") & ~(la < 62.5), ICE)
S(isin("AQ") | (la < -60), ICE)
S((la > 75), ICE)
S(isin("SJ"), ICE)
cl[country == 0] = 0

os.makedirs(os.path.join(ROOT, "assets/textures"), exist_ok=True)
Image.fromarray(country.astype(np.uint8), "L").save(os.path.join(ROOT, "assets/textures/earth_country.png"), optimize=True)
Image.fromarray(cl, "L").save(os.path.join(ROOT, "assets/textures/earth_climate.png"), optimize=True)

# ---- the cities: coordinates from GeoNames ----------------------------------------------------
by = {}
for r in rows:
    by.setdefault((r["name"].lower(), r["cc"]), []).append(r)
out_c = []
miss = []
for cz, en, iso in CITIES:
    m = by.get((en.lower(), iso))
    if not m:
        miss.append((cz, en, iso)); continue
    r = m[0]
    k = "DDR" if iso == "DE" and r["admin1"] in GDR else iso
    out_c.append((cz, names[k], round(float(r["lat"]), 3), round(float(r["lon"]), 3)))
if miss:
    print("MISSING cities:", miss)

def gstr(s): return '"' + s.replace('"', '\\"') + '"'
with open(os.path.join(ROOT, "scripts/geo_data.gd"), "w", encoding="utf-8") as f:
    f.write("## Generated by tools/geo/build_geo.py - do not edit by hand (edit names_cs.py / places_cs.py).\n")
    f.write("## The world as in spring 1990: countries (index+1 = the value in earth_country.png),\n")
    f.write("## regions inside the big countries and real cities for the terror missions.\n")
    f.write("extends RefCounted\n\n")
    f.write("## [czech name, iso code of today]\nconst COUNTRIES := [\n")
    for c in order:
        f.write("\t[%s, %s],\n" % (gstr(names.get(c, c)), gstr(c)))
    f.write("]\n\n## [name, iso, lat, lon]\nconst REGIONS := [\n")
    for n, c, a, o in REGIONS:
        f.write("\t[%s, %s, %s, %s],\n" % (gstr(n), gstr(c), a, o))
    f.write("]\n\n## [city, country, lat, lon]\nconst CITIES := [\n")
    for cz, cn, a, o in out_c:
        f.write("\t[%s, %s, %s, %s],\n" % (gstr(cz), gstr(cn), a, o))
    f.write("]\n")
print("countries", len(order), "cities", len(out_c), "regions", len(REGIONS))
