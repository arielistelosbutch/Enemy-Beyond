"""Sounds for the alien roster and civilians (own synthesis, numpy)."""
import os, sys, wave
import numpy as np

OUT = os.path.join(sys.argv[1] if len(sys.argv) > 1 else ".", "assets", "sounds")
SR = 22050
rng = np.random.default_rng(11)

def wav(name, data):
    data = np.clip(data, -1, 1)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((data * 32000).astype(np.int16).tobytes())

def t(sec): return np.arange(int(SR * sec)) / SR
def env(n, a=0.005, d=0.3):
    x = np.arange(n) / SR
    return np.minimum(1, x / a) * np.exp(-x / d)
def noise(n): return rng.uniform(-1, 1, n)
def lp(a, k): return np.convolve(a, np.ones(k) / k, "same")
def hp(a, k): return a - lp(a, k)

# skitter: fast chitinous clicks, irregular
n = int(SR * 0.9); s = np.zeros(n)
pos = 0
while pos < n - 400:
    k = int(rng.uniform(250, 900))
    click = hp(noise(160), 3) * np.exp(-np.arange(160) / 25)
    s[pos:pos + 160] += click * rng.uniform(0.4, 1.0)
    pos += k
wav("skitter", s * 0.9)
# lunge: hiss + rising shriek
x = t(0.45)
shriek = np.sin(2 * np.pi * (700 + 1600 * x) * x + 3 * np.sin(2 * np.pi * 40 * x)) * 0.35
wav("lunge", (hp(noise(len(x)), 4) * 0.5 + shriek) * env(len(x), 0.01, 0.2))
# slash: wet tearing hit
x = t(0.35)
wav("slash", (lp(noise(len(x)), 3) * 0.9 + np.sin(2 * np.pi * 90 * x) * 0.6) * env(len(x), 0.002, 0.09))
# burst: something tearing out of a body
x = t(1.3)
tear = lp(noise(len(x)), 6) * (0.4 + 0.6 * (np.sin(2 * np.pi * 7 * x) > 0)) * env(len(x), 0.05, 0.5) * 1.4
squelch = np.sin(2 * np.pi * (60 + 40 * np.sin(2 * np.pi * 3 * x)) * x) * env(len(x), 0.1, 0.6) * 0.6
wav("burst", tear + squelch + np.sin(2 * np.pi * (500 + 900 * x) * x) * 0.2 * env(len(x), 0.6, 0.3))
# groan: low voice, vowel-ish
x = t(1.6)
f0 = 85 + 10 * np.sin(2 * np.pi * 0.7 * x)
v = np.sign(np.sin(2 * np.pi * np.cumsum(f0) / SR)) * 0.3
v = lp(v, 9) + lp(noise(len(x)), 20) * 0.3
wav("groan", v * np.sin(np.pi * x / 1.6) * 1.4)
# growl: rough low rumble
x = t(1.2)
g = np.sin(2 * np.pi * 55 * x) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 23 * x))) + lp(noise(len(x)), 12) * 0.8
wav("growl", g * np.sin(np.pi * x / 1.2) * 0.9)
# sniff: three quick inhales
n = int(SR * 0.9); s = np.zeros(n)
for i in range(3):
    a = int(i * 0.22 * SR); m = int(0.14 * SR)
    s[a:a + m] += hp(noise(m), 2) * np.sin(np.pi * np.arange(m) / m) * 0.6
wav("sniff", s)
# hum: machine drone, loopable 2 s
x = t(2.0)
wav("hum", (np.sin(2 * np.pi * 110 * x) * 0.3 + np.sin(2 * np.pi * 220.5 * x) * 0.15 + np.sign(np.sin(2 * np.pi * 55 * x)) * 0.08) * 0.8)
# psi: a voice-like chord sliding, with whisper
x = t(2.2)
ch = sum(np.sin(2 * np.pi * f * (1 + 0.03 * np.sin(2 * np.pi * 0.5 * x)) * x) for f in (180, 227, 269, 361)) * 0.15
wh = hp(noise(len(x)), 3) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.3 * x)) * 0.25
wav("psi", (ch + wh) * np.sin(np.pi * x / 2.2) ** 0.5 * 1.1)
# scream: human, short
x = t(1.0)
f = 520 + 180 * np.sin(2 * np.pi * 5 * x) - 120 * x
sc = np.sin(2 * np.pi * np.cumsum(f) / SR)
sc = lp(np.sign(sc) * 0.3 + sc * 0.4, 4) + hp(noise(len(x)), 3) * 0.12
wav("scream", sc * env(len(x), 0.04, 0.5))
# whimper: quiet sob
x = t(1.4)
f = 300 + 60 * np.sin(2 * np.pi * 2.0 * x)
wm = np.sin(2 * np.pi * np.cumsum(f) / SR) * (np.sin(2 * np.pi * 1.5 * x) > 0.2)
wav("whimper", lp(wm, 6) * 0.35 * np.sin(np.pi * x / 1.4) + lp(noise(len(x)), 30) * 0.1)
print("alien sounds written")
