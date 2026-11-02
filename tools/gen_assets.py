"""Generates the placeholder pixel-art textures and retro synth audio of Enemy Beyond."""
import os, sys, math, random
import numpy as np
from PIL import Image
OUT = sys.argv[1]
T = os.path.join(OUT, "assets", "textures"); S = os.path.join(OUT, "assets", "sounds")
os.makedirs(T, exist_ok=True); os.makedirs(S, exist_ok=True)
R = random.Random(7)

def tex(name, size, fn):
    im = Image.new("RGB", (size, size))
    px = im.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = tuple(max(0, min(255, int(c))) for c in fn(x, y))
    im.save(os.path.join(T, name + ".png"))

def noise(a=20):
    return R.uniform(-a, a)

tex("grass", 32, lambda x, y: (44 + noise(10), 58 + noise(16) + (10 if R.random() < .1 else 0), 34 + noise(8)))
tex("dirt", 32, lambda x, y: (78 + noise(14), 58 + noise(10), 38 + noise(8)))
tex("wheat", 32, lambda x, y: (150 + noise(25) - (30 if x % 4 == 0 else 0), 125 + noise(20) - (25 if x % 4 == 0 else 0), 55 + noise(10)))
tex("planks", 32, lambda x, y: ((110 if (y // 8) % 2 else 100) + noise(8) - (40 if y % 8 == 0 else 0) - (25 if (x + (y // 8) * 11) % 16 == 0 else 0),
                                 (78 if (y // 8) % 2 else 70) + noise(6) - (30 if y % 8 == 0 else 0), 50 + noise(5) - (20 if y % 8 == 0 else 0)))
tex("barn", 32, lambda x, y: (120 + noise(10) - (45 if x % 8 == 0 else 0), 30 + noise(6) - (10 if x % 8 == 0 else 0), 28 + noise(6)))
tex("plaster", 32, lambda x, y: (150 + noise(10), 145 + noise(10), 130 + noise(10)))
tex("roof", 32, lambda x, y: (70 + noise(8) - (25 if y % 6 == 0 else 0), 45 + noise(6) - (15 if y % 6 == 0 else 0), 40 + noise(6)))
tex("bark", 32, lambda x, y: (60 + noise(10) - (20 if x % 5 == 0 else 0), 42 + noise(8), 28 + noise(6)))
tex("leaves", 32, lambda x, y: (25 + noise(10), 55 + noise(22), 25 + noise(8)))
tex("hay", 32, lambda x, y: (170 + noise(25), 140 + noise(20), 60 + noise(15)))
tex("metal", 32, lambda x, y: (95 + noise(6) - (30 if x % 16 == 0 or y % 16 == 0 else 0), 98 + noise(6) - (30 if x % 16 == 0 or y % 16 == 0 else 0), 105 + noise(6) - (25 if x % 16 == 0 or y % 16 == 0 else 0)))
tex("ufo_hull", 32, lambda x, y: (70 + noise(8) - (25 if y % 8 == 0 else 0), 80 + noise(8) - (25 if y % 8 == 0 else 0), 92 + noise(8) - (20 if y % 8 == 0 else 0)))
tex("ufo_floor", 32, lambda x, y: (50 + noise(5) + (35 if (x % 8 in (3, 4)) and (y % 8 in (3, 4)) else 0), 40 + noise(5), 70 + noise(6) + (60 if (x % 8 in (3, 4)) and (y % 8 in (3, 4)) else 0)))
tex("ufo_wall", 32, lambda x, y: (60 + noise(6), 48 + noise(6) + (40 if y % 10 == 5 else 0), 85 + noise(8) + (70 if y % 10 == 5 else 0)))
tex("alien_skin", 16, lambda x, y: (120 + noise(10), 125 + noise(10), 118 + noise(10)))
tex("alien_suit", 16, lambda x, y: (40 + noise(6), 60 + noise(8), 50 + noise(6) - (15 if y % 4 == 0 else 0)))
tex("scorch", 32, lambda x, y: (25 + noise(10), 22 + noise(8), 20 + noise(6)))
tex("gun", 16, lambda x, y: (45 + noise(6), 45 + noise(6), 48 + noise(6)))
tex("skyranger", 32, lambda x, y: (80 + noise(6) - (25 if y % 16 == 0 else 0), 82 + noise(6) - (25 if y % 16 == 0 else 0), 70 + noise(6)))
tex("fence", 32, lambda x, y: (100 + noise(12), 80 + noise(10), 55 + noise(8)))

# ---- audio ---------------------------------------------------------------------
SR = 22050
def wav(name, data):
    import wave
    d = np.clip(data, -1, 1)
    with wave.open(os.path.join(S, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((d * 32000).astype(np.int16).tobytes())

def t(sec): return np.arange(int(SR * sec)) / SR
def env(n, a=0.005, d=0.3):
    x = np.arange(n) / SR
    return np.minimum(1, x / a) * np.exp(-x / d)
def noise_s(n): return np.random.default_rng(1).uniform(-1, 1, n)

n = int(SR * .35); wav("rifle", noise_s(n) * env(n, .001, .06) * .9 + np.sin(2 * np.pi * 90 * t(.35)) * env(n, .001, .08) * .6)
n = int(SR * .25); wav("pistol", noise_s(n) * env(n, .001, .04) * .7 + np.sin(2 * np.pi * 140 * t(.25)) * env(n, .001, .05) * .5)
x = t(.45); wav("plasma", (np.sign(np.sin(2 * np.pi * (900 - 1400 * x) * x)) * .35 + np.sin(2 * np.pi * (400 - 300 * x) * x) * .4) * env(len(x), .005, .15))
n = int(SR * 1.6); low = np.convolve(noise_s(n), np.ones(40) / 40, "same"); wav("explosion", low * env(n, .002, .45) * 2.2)
x = t(.09); wav("scanner", np.sign(np.sin(2 * np.pi * 1400 * x)) * .25 * env(len(x), .002, .05))
x = t(.6); wav("alien", (np.sin(2 * np.pi * (300 + 120 * np.sin(2 * np.pi * 18 * x)) * x) * .5 + noise_s(len(x)) * .08) * env(len(x), .02, .25))
n = int(SR * .12); wav("step", np.convolve(noise_s(n), np.ones(12) / 12, "same") * env(n, .002, .03) * 1.5)
x = t(.35); wav("hit", (np.sin(2 * np.pi * 120 * x) * .7 + noise_s(len(x)) * .2) * env(len(x), .002, .08))
x = t(.9); hb = np.zeros_like(x)
for st in (0.0, 0.25):
    m = (x >= st) & (x < st + .15); hb[m] += np.sin(2 * np.pi * 55 * (x[m] - st)) * np.exp(-(x[m] - st) / .05)
wav("heartbeat", hb * .9)
n = int(SR * .5); x = t(.5); wav("reload", (np.where((x > .05) & (x < .08), 1, 0) + np.where((x > .35) & (x < .38), 1, 0)) * noise_s(n) * .6)
x = t(1.2); wav("death", np.sin(2 * np.pi * (220 - 150 * x) * x) * env(len(x), .01, .5) * .6)

# retro synth music: dark minor arpeggios over a drone (loopable)
def note(f, dur, kind="saw"):
    x = t(dur)
    if kind == "saw": w = 2 * (x * f % 1) - 1
    elif kind == "sq": w = np.sign(np.sin(2 * np.pi * f * x))
    else: w = np.sin(2 * np.pi * f * x)
    return w
def midi(m): return 440 * 2 ** ((m - 69) / 12)

def music(name, bars, tempo, prog, arp=True, drone=True):
    beat = 60 / tempo
    total = bars * 4 * beat
    out = np.zeros(int(SR * total) + SR)
    for b in range(bars):
        root = prog[b % len(prog)]
        start = b * 4 * beat
        if drone:
            seg = note(midi(root - 12), 4 * beat, "saw") * .10 + note(midi(root - 24), 4 * beat, "sine") * .25
            i = int(start * SR); out[i:i + len(seg)] += seg * np.minimum(1, np.arange(len(seg)) / (SR * .3))
        if arp:
            chord = [root, root + 3, root + 7, root + 12, root + 7, root + 3, root, root + 10]
            for k in range(8):
                f = midi(chord[k] + 12)
                seg = note(f, beat / 2 * .9, "sq") * .07 * env(int(SR * beat / 2 * .9), .005, .2)
                i = int((start + k * beat / 2) * SR); out[i:i + len(seg)] += seg
    lp = np.convolve(out, np.ones(6) / 6, "same")
    # simple echo
    d = int(SR * beat * .75); ech = np.zeros_like(lp); ech[d:] = lp[:-d] * .35
    wav(name, (lp + ech)[:int(SR * total)] * .9)

music("music_menu", 16, 84, [57, 57, 53, 55, 57, 57, 52, 52])
music("music_mission", 16, 60, [45, 45, 46, 44], arp=False)

# ---- horror ambience ---------------------------------------------------------------
rng = np.random.default_rng(7)
def lowpass(a, k): return np.convolve(a, np.ones(k) / k, "same")
# wind: slow swelling filtered noise, loopable (fade ends together)
n = SR * 12; x = np.arange(n) / SR
w = lowpass(rng.uniform(-1, 1, n), 60) * (0.5 + 0.5 * np.sin(2 * np.pi * x / 12) ** 2) * (0.6 + 0.4 * np.sin(2 * np.pi * x / 4))
wav("wind", w * 2.2)
# rustle: something moving through wheat
n = int(SR * 1.4); r = rng.uniform(-1, 1, n) * (rng.uniform(0, 1, n) > .55)
wav("rustle", lowpass(r, 4) * np.convolve(np.abs(np.sin(np.arange(n) / SR * 2 * np.pi * 3.1)), np.ones(400) / 400, "same") * .7)
# cow: moo that gets cut off
x = t(1.8); f = 110 + 25 * np.sin(np.pi * x / 1.8)
moo = (2 * ((np.cumsum(f) / SR) % 1) - 1) * .3; moo = lowpass(moo, 18) * np.minimum(1, x / .15)
moo[int(SR * 1.15):] = 0
wav("cow", moo * 1.6)
# sting: dissonant synth hit for first contact
x = t(2.5); st = np.zeros_like(x)
for fr in (55, 58.3, 82.4, 116.5, 233):
    st += (2 * ((x * fr) % 1) - 1) * .12
st = lowpass(st, 5) * np.minimum(1, x / .01) * np.exp(-x / .9)
wav("sting", st * 1.4)
# distant: far alien call, muffled and slow
x = t(1.6); d = np.sin(2 * np.pi * (180 + 60 * np.sin(2 * np.pi * 6 * x)) * x) * np.minimum(1, x / .3) * np.exp(-x / .6)
wav("distant", lowpass(d, 25) * .9)
# creak: wood/metal groan
x = t(1.1); cr = np.sign(np.sin(2 * np.pi * (70 + 30 * np.sin(2 * np.pi * 1.3 * x)) * x)) * (rng.uniform(0, 1, len(x)) > .3)
wav("creak", lowpass(cr, 30) * np.sin(np.pi * x / 1.1) * .5)
# ping: motion tracker proximity beep (softer than the old scanner)
x = t(.12); wav("ping", np.sin(2 * np.pi * 1180 * x) * .35 * env(len(x), .002, .06))
# breath: heavy, ragged breathing (in + out)
x = t(1.3); b = lowpass(rng.uniform(-1, 1, len(x)), 9)
envb = np.where(x < .5, np.sin(np.pi * x / .5) * .6, np.where(x > .62, np.sin(np.pi * np.clip((x - .62) / .6, 0, 1)), 0))
wav("breath", b * envb * .5)
# static: radio hiss with crackles, loopable
n = SR * 4; st = rng.uniform(-1, 1, n) * .25
cr = (rng.uniform(0, 1, n) > .9993) * rng.uniform(-1, 1, n) * 3
st = st + lowpass(cr, 30) * 4
st = st - lowpass(st, 6)  # thin, tinny
wav("static", st * .8)
# radio: key-up click + burst of static (pilot transmission)
x = t(.6); rb = rng.uniform(-1, 1, len(x)) * .35 * np.minimum(1, x / .01) * np.exp(-x / .35)
rb[:200] += np.sign(np.sin(np.arange(200) / 3)) * .5
wav("radio", rb - lowpass(rb, 5))
# thunder: crack then long rolling rumble
n = SR * 6; x = np.arange(n) / SR
th = lowpass(rng.uniform(-1, 1, n), 140) * (np.exp(-x / 1.8) * (0.6 + 0.4 * np.sin(2 * np.pi * x * 0.9) ** 2))
th += lowpass(rng.uniform(-1, 1, n), 6) * np.exp(-x / .08) * .5
wav("thunder", th * 5.0)
# rain: steady soft noise, loopable
n = SR * 6; rn = lowpass(rng.uniform(-1, 1, n), 3) - lowpass(rng.uniform(-1, 1, n), 40) * .5
drops = (rng.uniform(0, 1, n) > .998) * rng.uniform(.3, 1, n)
wav("rain", (rn * .25 + lowpass(drops, 8) * 2) * .8)
# knock: three slow knocks on metal
x = t(2.4); kn = np.zeros_like(x)
for st0 in (0.0, 0.7, 1.4):
    m = (x >= st0) & (x < st0 + .5)
    xx = x[m] - st0
    kn[m] += (np.sin(2 * np.pi * 95 * xx) + .5 * np.sin(2 * np.pi * 233 * xx)) * np.exp(-xx / .09)
wav("knock", kn * .7)
# whisper: breathy formant noise, rising and falling
x = t(1.8); wh = rng.uniform(-1, 1, len(x))
wh = lowpass(wh, 2) - lowpass(wh, 7)
wh *= np.sin(np.pi * x / 1.8) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 3.3 * x))
wav("whisper", wh * 1.2)
# --- arsenal sounds ---
n = int(SR * .5); wav("shotgun", noise_s(n) * env(n, .001, .12) * 1.0 + np.sin(2 * np.pi * 70 * t(.5)) * env(n, .001, .15) * .8)
n = int(SR * .6); wav("magnum", noise_s(n) * env(n, .001, .1) * .9 + np.sin(2 * np.pi * 55 * t(.6)) * env(n, .001, .2) * .9)
n = int(SR * .5); wav("autocannon", lowpass(noise_s(n), 3) * env(n, .001, .14) * 1.2 + np.sin(2 * np.pi * 45 * t(.5)) * env(n, .001, .2))
n = int(SR * .09); wav("minigun", noise_s(n) * env(n, .001, .025) * .8 + np.sign(np.sin(2 * np.pi * 120 * t(.09))) * env(n, .001, .02) * .3)
n = int(SR * 1.0); x = t(1.0); wav("launch", lowpass(noise_s(n), 6) * np.minimum(1, x / .02) * np.exp(-x / .5) * 1.4)
x = t(.35); wav("zap", (np.sign(np.sin(2 * np.pi * 60 * x)) * .3 + rng.uniform(-1, 1, len(x)) * .4 * (rng.uniform(0, 1, len(x)) > .6)) * env(len(x), .002, .15))
x = t(.25); wav("swish", (lowpass(rng.uniform(-1, 1, len(x)), 3) - lowpass(rng.uniform(-1, 1, len(x)), 20)) * np.sin(np.pi * x / .25) * .9)
x = t(.3); wav("clink", (np.sin(2 * np.pi * 1300 * x) + .6 * np.sin(2 * np.pi * 2100 * x)) * env(len(x), .001, .05) * .4)
print("assets written")
