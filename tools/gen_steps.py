"""Enemy Beyond - footsteps by surface (own synthesis). Each step: a heel strike (a soft
low thump) and then the sole rolling off (the surface texture), a few variants each.
Writes assets/sounds/step_<surface><n>.wav (22.05 kHz mono)."""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(1999)

def wav(name, x):
    x = np.asarray(x, dtype=np.float64)
    x = x / max(1e-6, np.max(np.abs(x))) * 0.8
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())

def t_(sec):
    return np.arange(int(SR * sec)) / SR

def lowpass(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.zeros_like(x); s = 0.0
    for i, v in enumerate(x):
        s = (1 - a) * v + a * s
        y[i] = s
    return y

def highpass(x, fc):
    return x - lowpass(x, fc)

def band(x, lo, hi):
    return lowpass(highpass(x, lo), hi)

def env(n, att, dec):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(att, 1e-4)) * np.exp(-np.maximum(0, t - att) / dec)
    return e

def place(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]

def thump(freq, dec, amp):
    t = t_(dec * 5)
    f = freq * (1 + 0.6 * np.exp(-t / 0.01))          # pitch drops as the heel lands
    ph = np.cumsum(2 * np.pi * f / SR)
    return np.sin(ph) * env(len(t), 0.002, dec) * amp

def crackles(sec, density, lo, hi, amp):
    n = int(SR * sec)
    x = np.zeros(n)
    k = int(density * sec)
    for _ in range(k):
        p = rng.integers(0, max(1, n - 200))
        L = rng.integers(20, 120)
        x[p:p + L] += rng.normal(0, 1, L) * np.exp(-np.arange(L) / (L / 4)) * rng.uniform(0.3, 1.0)
    x *= np.exp(-np.arange(n) / (n * 0.45))
    return band(x, lo, hi) * amp

def noise(sec, lo, hi, att, dec, amp):
    n = int(SR * sec)
    return band(rng.normal(0, 1, n), lo, hi) * env(n, att, dec) * amp

def step(surface):
    buf = np.zeros(int(SR * 0.45))
    heel = rng.uniform(0.0, 0.01)
    toe = heel + rng.uniform(0.05, 0.09)
    if surface == "grass":
        place(buf, thump(rng.uniform(70, 95), 0.025, 0.5), heel)
        place(buf, noise(0.18, 1500, 6500, 0.01, 0.05, 0.6), heel + 0.005)      # blades brushing
        place(buf, crackles(0.15, 160, 2000, 7000, 0.5), toe)
    elif surface == "dirt":
        place(buf, thump(rng.uniform(80, 110), 0.03, 0.8), heel)
        place(buf, crackles(0.2, 260, 900, 5000, 0.9), heel + 0.01)              # grit under the sole
        place(buf, noise(0.08, 600, 3000, 0.005, 0.03, 0.4), toe)
    elif surface == "hard":
        place(buf, thump(rng.uniform(110, 140), 0.018, 0.7), heel)
        place(buf, noise(0.03, 1200, 6000, 0.0005, 0.008, 1.0), heel)           # sharp heel click
        place(buf, noise(0.1, 800, 4000, 0.01, 0.03, 0.45), toe)                 # sole scuff
    elif surface == "wood":
        place(buf, thump(rng.uniform(95, 130), 0.05, 0.9), heel)
        t = t_(0.25)
        modes = sum(np.sin(2 * np.pi * f * t) * np.exp(-t / d) for f, d in ((rng.uniform(210, 260), 0.06), (rng.uniform(430, 520), 0.04), (rng.uniform(900, 1100), 0.02)))
        place(buf, modes * 0.35, heel)                                            # hollow boards
        place(buf, noise(0.06, 1500, 5000, 0.001, 0.012, 0.5), heel)
        place(buf, thump(rng.uniform(120, 150), 0.03, 0.4), toe)
        if rng.random() < 0.35:                                                   # a creak now and then
            ct = t_(0.18)
            f = 380 + 120 * np.sin(2 * np.pi * 3 * ct)
            place(buf, np.sign(np.sin(np.cumsum(2 * np.pi * f / SR))) * np.exp(-ct / 0.08) * 0.08, toe + 0.02)
    elif surface == "metal":
        t = t_(0.4)
        ring = sum(a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t / d)
                   for f, d, a in ((rng.uniform(560, 640), 0.18, 0.5), (rng.uniform(1350, 1500), 0.12, 0.35), (rng.uniform(2400, 2700), 0.07, 0.25), (rng.uniform(3900, 4300), 0.04, 0.15)))
        place(buf, thump(rng.uniform(90, 120), 0.03, 0.8), heel)
        place(buf, ring * 0.5, heel)
        place(buf, noise(0.03, 2000, 8000, 0.0005, 0.006, 0.6), heel)
        place(buf, ring * 0.25, toe)
    elif surface == "snow":
        place(buf, thump(rng.uniform(60, 80), 0.04, 0.4), heel)
        place(buf, crackles(0.28, 420, 400, 3500, 1.0), heel + 0.01)            # crunch, packed
        place(buf, noise(0.25, 300, 1800, 0.03, 0.08, 0.4), heel)
    elif surface == "sand":
        place(buf, thump(rng.uniform(65, 85), 0.035, 0.45), heel)
        place(buf, noise(0.25, 1000, 7000, 0.02, 0.07, 0.6), heel)               # soft hiss
        place(buf, crackles(0.2, 120, 3000, 8000, 0.25), toe)
    buf += rng.normal(0, 1, len(buf)) * 1e-4
    fade = np.ones(len(buf)); fade[-400:] = np.linspace(1, 0, 400)
    return buf * fade

if __name__ == "__main__":
    for s in ("grass", "dirt", "hard", "wood", "metal", "snow", "sand"):
        for i in range(4):
            wav("step_%s%d" % (s, i), step(s))
    print("ok")
