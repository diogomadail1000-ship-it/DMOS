"""Gera a banda sonora do vídeo: um ambiente calmo, original, sem direitos de terceiros.

Uso: python3 video/music.py SEGUNDOS saida.wav [SEGUNDOS_POR_ACORDE]
"""
import sys
import wave

import numpy as np

SR = 44100
DUR = float(sys.argv[1])
OUT = sys.argv[2]
# Segundos por acorde: 4.0 é calmo (60 bpm); 2.4 dá 100 bpm, para vídeos curtos e rápidos.
BAR = float(sys.argv[3]) if len(sys.argv) > 3 else 4.0

rng = np.random.default_rng(7)
n = int(DUR * SR)
t = np.arange(n) / SR
left = np.zeros(n)
right = np.zeros(n)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# Lá menor, Fá, Dó, Sol (em MIDI). Cada acorde tem baixo, pad e arpejo.
CHORDS = [
    (45, [57, 60, 64, 69]),  # Am
    (41, [57, 60, 65, 69]),  # F
    (48, [55, 60, 64, 67]),  # C
    (43, [55, 59, 62, 67]),  # G
]


def add(sig, start, pan=0.0):
    i = int(start * SR)
    if i < 0:
        sig, i = sig[-i:], 0
    if i >= n:
        return
    sig = sig[: n - i]
    left[i : i + len(sig)] += sig * (1 - pan) * 0.5 * 2 ** 0.5
    right[i : i + len(sig)] += sig * (1 + pan) * 0.5 * 2 ** 0.5


def pad(freq, length):
    m = int(length * SR)
    x = np.arange(m) / SR
    sig = np.zeros(m)
    for d in (-0.12, 0.0, 0.11):
        f = freq * 2 ** (d / 12)
        sig += np.sin(2 * np.pi * f * x + rng.uniform(0, 6.28))
        sig += 0.18 * np.sin(2 * np.pi * 2 * f * x)
    env = np.minimum(1, x / 1.4) * np.minimum(1, (length - x) / 1.6)
    return sig * np.clip(env, 0, 1) / 3


def pluck(freq, length=1.6):
    m = int(length * SR)
    x = np.arange(m) / SR
    sig = np.sin(2 * np.pi * freq * x) + 0.3 * np.sin(2 * np.pi * 2 * freq * x) + 0.08 * np.sin(2 * np.pi * 3 * freq * x)
    env = np.exp(-x * 3.2) * np.minimum(1, x / 0.004)
    return sig * env


bars = int(np.ceil(DUR / BAR)) + 1
for b in range(bars):
    root, notes = CHORDS[b % 4]
    start = b * BAR
    # O pad começa um pouco antes e acaba um pouco depois, para os acordes se ligarem.
    for k, m in enumerate(notes):
        add(0.055 * pad(hz(m), BAR + 1.6), start - 0.4, pan=(-0.5, -0.15, 0.2, 0.5)[k])
    bass = pad(hz(root), BAR + 1.0)
    add(0.11 * bass, start - 0.2)
    # Arpejo em colcheias a partir do 2.º compasso, mais denso a meio do vídeo.
    if b >= 1 and start < DUR - min(6, BAR * 1.5):
        pattern = [0, 2, 1, 3, 2, 1, 3, 2]
        for s in range(8):
            if b == 1 and s < 4:
                continue
            m = notes[pattern[s]] + 12
            vel = 0.06 * (0.8 + 0.2 * rng.random()) * (1.0 if s % 2 == 0 else 0.7)
            add(vel * pluck(hz(m)), start + s * BAR / 8, pan=0.35 if s % 2 else -0.35)
    # Uma batida suave (bombo) a partir do 3.º compasso.
    if 2 <= b and start < DUR - min(6, BAR * 1.5):
        for s in range(4):
            m = int(0.35 * SR)
            x = np.arange(m) / SR
            kick = np.sin(2 * np.pi * (55 + 70 * np.exp(-x * 30)) * x) * np.exp(-x * 9)
            add(0.16 * kick, start + s * BAR / 4)

# Eco estéreo simples, para dar espaço.
for delay, gain in ((0.375, 0.28), (0.75, 0.16), (1.125, 0.09)):
    d = int(delay * SR)
    l2, r2 = left.copy(), right.copy()
    left[d:] += gain * r2[:-d]
    right[d:] += gain * l2[:-d]

mix = np.stack([left, right], axis=1)
fade_in = np.minimum(1, t / 1.5)
fade_out = np.clip((DUR - t) / 4.0, 0, 1)
mix *= (fade_in * fade_out)[:, None]
mix *= 0.89 / np.max(np.abs(mix))  # cerca de -1 dBFS
pcm = (mix * 32767).astype("<i2")

with wave.open(OUT, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("ok", OUT, DUR)
