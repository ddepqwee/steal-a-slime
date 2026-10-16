#!/usr/bin/env python3
"""Генератор звуков игры (свои, без чужих прав). Запуск: python3 tools/make_sfx.py → audio/*.ogg"""
import os, subprocess, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.0, s=1.0, r=0.1, total=None):
    total = total or n / SR
    tt = np.arange(n) / SR
    e = np.ones(n)
    e = np.where(tt < a, tt / max(a, 1e-6), e)
    if d > 0:
        dm = (tt >= a) & (tt < a + d)
        e = np.where(dm, 1 - (1 - s) * (tt - a) / d, e)
        e = np.where(tt >= a + d, s, e)
    rel = tt > total - r
    e = np.where(rel, e * np.clip((total - tt) / max(r, 1e-6), 0, 1), e)
    return e


def osc(freq, d, kind="sine"):
    tt = t(d)
    f = np.broadcast_to(freq, tt.shape) if np.ndim(freq) else np.full(tt.shape, freq)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.6
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1


def expdecay(n, k):
    return np.exp(-k * np.arange(n) / SR)


def note(f, d, kind="sine", k=8, a=0.004):
    s = osc(f, d, kind)
    return s * expdecay(len(s), k) * env(len(s), a=a, r=0.02)


def mix(*parts):
    n = max(int(off * SR) + len(p) for p, off in parts)
    out = np.zeros(n)
    for p, off in parts:
        o = int(off * SR)
        out[o:o + len(p)] += p
    return out


def reverb(x, amt=0.25):
    out = np.copy(x)
    for delay, g in [(0.031, 0.5), (0.047, 0.4), (0.071, 0.3), (0.113, 0.22)]:
        dd = int(delay * SR)
        y = np.zeros(len(x) + dd * 6)
        y[: len(x)] = x
        for i in range(1, 6):
            y[dd * i: dd * i + len(x)] += x * (g ** i)
        out = np.pad(out, (0, len(y) - len(out)))
        out += y * amt / 4
    return out


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        prev = (1 - a) * v + a * prev
        y[i] = prev
    return y


def save(name, x, peak=0.85):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = int(0.004 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg], check=True)
    os.remove(wav)
    print("✓", name, f"{len(x)/SR:.2f}s")


C5, E5, G5, A5, B5, C6, E6, G6 = 523.25, 659.25, 783.99, 880.0, 987.77, 1046.5, 1318.5, 1568.0

# 1. Click — мягкий «тык» интерфейса
d = 0.06
save("Click", note(np.linspace(1800, 1100, int(SR * d)), d, "sine", k=60) + 0.3 * note(3600, d, "sine", k=90))

# 2. Buy — монетка «дзынь-дзынь»
save("Buy", reverb(mix((note(B5 * 2, 0.12, "square", k=25) * 0.5, 0), (note(E6 * 1.5, 0.35, "square", k=10) * 0.5, 0.07)), 0.3))

# 3. Pop — бульк слайма (спавн/вылупление)
d = 0.18
f = np.concatenate([np.linspace(220, 900, int(SR * 0.07)), np.linspace(900, 700, int(SR * 0.11))])
save("Pop", reverb(osc(f, d, "sine") * env(int(SR * d), a=0.003, r=0.06) * expdecay(int(SR * d), 6), 0.2))

# 4. Steal — тревога-сирена (две ноты x3)
parts = []
for i in range(3):
    parts.append((note(880, 0.16, "square", k=4) * 0.5, i * 0.32))
    parts.append((note(660, 0.16, "square", k=4) * 0.5, i * 0.32 + 0.16))
save("Steal", lowpass(mix(*parts), 3500))

# 5. Bonk — мультяшный «бонк»: удар + падающий тон
d = 0.35
f = np.linspace(520, 90, int(SR * d)) ** 1
thud = osc(f, d, "tri") * expdecay(int(SR * d), 9)
noise = rng.normal(0, 1, int(SR * 0.05)) * expdecay(int(SR * 0.05), 60)
save("Bonk", mix((thud, 0), (lowpass(noise, 2500) * 0.8, 0)))

# 6. Legendary — фанфара-арпеджио + блеск
arp = [C5, E5, G5, C6, E6, G6]
parts = [(note(fq, 0.5, "square", k=5) * 0.35 + note(fq, 0.5, "tri", k=4) * 0.5, i * 0.075) for i, fq in enumerate(arp)]
chord = sum(note(fq, 1.2, "tri", k=2.5) for fq in [C6, E6, G6]) * 0.35
sparkle = sum((note(rng.uniform(2500, 4500), 0.15, "sine", k=25) * 0.25, 0) for _ in range(1)) if False else None
parts.append((chord, 0.45))
for i in range(10):
    parts.append((note(rng.uniform(2600, 5200), 0.12, "sine", k=30) * 0.18, 0.45 + i * 0.06))
save("Legendary", reverb(mix(*parts), 0.4))

# 7. Reward — светлый «клейм» (квест/календарь/подарок)
parts = [(note(fq, 0.6, "tri", k=6) * 0.6 + note(fq * 2, 0.6, "sine", k=10) * 0.2, i * 0.06) for i, fq in enumerate([G5, C6, E6])]
save("Reward", reverb(mix(*parts), 0.35))

# 8. Whoosh — открытие окна / ребёрт
d = 0.32
n = rng.normal(0, 1, int(SR * d))
sweep = np.zeros_like(n)
a_prev = 0.0
for i in range(len(n)):
    cut = 400 + 5000 * np.sin(np.pi * i / len(n))
    a = np.exp(-2 * np.pi * cut / SR)
    a_prev = (1 - a) * n[i] + a * a_prev
    sweep[i] = a_prev
save("Whoosh", sweep * np.sin(np.pi * np.arange(len(n)) / len(n)) ** 1.5, 0.7)

# 9. Error — «нельзя» (не хватает денег)
save("Error", lowpass(mix((note(311, 0.12, "square", k=10) * 0.5, 0), (note(233, 0.22, "square", k=8) * 0.5, 0.11)), 1800), 0.6)

# 10. Rebirth — восходящий свип + большой аккорд
d = 1.0
rise = osc(np.geomspace(200, 1600, int(SR * d)), d, "saw") * env(int(SR * d), a=0.3, r=0.2) * 0.25
rise = lowpass(rise, 2500)
chord = sum(note(fq, 1.4, "tri", k=2) for fq in [C5, E5, G5, C6]) * 0.4
save("Rebirth", reverb(mix((rise, 0), (chord, 0.85)), 0.45))
