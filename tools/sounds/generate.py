"""Synthesizes every game sound from scratch (no samples, no downloads) and writes .ogg files.

Usage: python3 tools/sounds/generate.py   (needs numpy and ffmpeg with libvorbis)
Output: assets/sounds/<Name>.ogg, one per Config.Sounds key. Upload them to Roblox and put the ids in Config.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sounds")
rng = np.random.default_rng(7)  # fixed seed: the same sounds every run


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return rng.uniform(-1, 1, int(seconds * RATE))


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be a number or an array (sweeps)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(seconds, attack=0.002, decay=0.1, curve=1.0):
    t = t_axis(seconds)
    a = np.clip(t / max(attack, 1e-6), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / decay) ** curve
    return a * d


def sweep(f0, f1, seconds, shape="sine", exp=True):
    t = t_axis(seconds)
    if exp:
        f = f0 * (f1 / f0) ** (t / seconds)
    else:
        f = f0 + (f1 - f0) * t / seconds
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return wave_shape(phase, shape)


def tone(freq, seconds, shape="sine", vibrato=0.0, vib_rate=6.0):
    t = t_axis(seconds)
    f = freq * (1 + vibrato * np.sin(2 * np.pi * vib_rate * t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return wave_shape(phase, shape)


def wave_shape(phase, shape):
    if shape == "sine":
        return np.sin(phase)
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    if shape == "tri":
        return 2 * np.abs(2 * ((phase / (2 * np.pi)) % 1) - 1) - 1
    raise ValueError(shape)


def mix(length, *parts):
    """parts: (start_seconds, signal) pairs."""
    out = np.zeros(int(length * RATE))
    for start, sig in parts:
        i = int(start * RATE)
        n = min(len(sig), len(out) - i)
        out[i : i + n] += sig[:n]
    return out


def drive(x, amount):
    return np.tanh(x * amount) / np.tanh(amount)


def finish(x, peak=0.9, fade=0.01):
    x = x - np.mean(x)
    n = int(fade * RATE)
    if n > 0 and len(x) > 2 * n:
        x[-n:] *= np.linspace(1, 0, n)
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def note(name):
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    return 440 * 2 ** ((names[name[:-1]] + 12 * (int(name[-1]) - 4)) / 12)


# ---------------------------------------------------------------------------- weapons

def gunshot(length, crack_cut, body_freq, decay, thump, tail):
    crack = highpass(noise(0.03), 1500) * env(0.03, 0.0005, 0.006)
    body = lowpass(noise(length), crack_cut) * env(length, 0.001, decay)
    boom = sweep(body_freq * 2, body_freq * 0.6, length) * env(length, 0.001, decay * 1.4) * thump
    rumble = lowpass(noise(length), 400) * env(length, 0.02, tail) * 0.5
    return drive(mix(length, (0, crack * 1.2), (0, body), (0, boom), (0, rumble)), 2.5)


def fire_pistol():
    return finish(gunshot(0.35, 5000, 140, 0.035, 0.9, 0.08))


def fire_shotgun():
    return finish(gunshot(0.8, 3000, 90, 0.08, 1.3, 0.25))


def fire_rifle():
    return finish(gunshot(0.22, 6500, 160, 0.022, 0.7, 0.05), peak=0.8)


def metal_click(freq):
    ping = (tone(freq, 0.08) + 0.5 * tone(freq * 2.7, 0.08)) * env(0.08, 0.0005, 0.012)
    tick = highpass(noise(0.02), 3000) * env(0.02, 0.0005, 0.004)
    return mix(0.08, (0, ping * 0.6), (0, tick))


def reload_sound():
    slide = lowpass(highpass(noise(0.25), 1500), 6000) * env(0.25, 0.08, 0.06) * 0.35
    return finish(mix(0.75, (0, metal_click(2300)), (0.12, slide), (0.42, metal_click(1800)), (0.5, metal_click(2600))))


def hit():
    return finish(mix(0.08, (0, tone(1900, 0.06) * env(0.06, 0.0005, 0.015)), (0, tone(2850, 0.04) * env(0.04, 0.0005, 0.01) * 0.5)), peak=0.7)


# ---------------------------------------------------------------------------- world

def grandma_poof():
    pop = sweep(280, 1100, 0.12) * env(0.12, 0.001, 0.05)
    puff = lowpass(noise(0.4), np.linspace(4000, 600, int(0.4 * RATE))) * env(0.4, 0.01, 0.1) * 0.6
    sparkle = tone(1568, 0.25, vibrato=0.02, vib_rate=30) * env(0.25, 0.01, 0.06) * 0.25
    return finish(mix(0.45, (0, pop), (0.02, puff), (0.05, sparkle)))


def explosion():
    n = int(2.2 * RATE)
    crack = highpass(noise(0.05), 1000) * env(0.05, 0.0005, 0.01)
    blast = lowpass(noise(2.2), np.geomspace(5000, 150, n)) * env(2.2, 0.003, 0.35)
    rumble = lowpass(lowpass(noise(2.2), 120), 120) * env(2.2, 0.05, 0.7) * 6
    boom = sweep(70, 30, 1.2) * env(1.2, 0.002, 0.3) * 0.9
    return finish(drive(mix(2.2, (0, crack), (0, blast), (0, rumble), (0, boom)), 2.0))


def stomp():
    thud = sweep(110, 38, 0.7) * env(0.7, 0.002, 0.15)
    dirt = lowpass(noise(0.7), np.geomspace(2500, 200, int(0.7 * RATE))) * env(0.7, 0.002, 0.08) * 0.6
    debris = lowpass(noise(0.9), 700) * env(0.9, 0.05, 0.25) * 0.5
    return finish(drive(mix(1.0, (0, thud), (0, dirt), (0.05, debris)), 2.2))


def thunder():
    n = int(3.5 * RATE)
    crack = highpass(noise(0.25), 800) * env(0.25, 0.001, 0.05)
    flutter = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * np.cumsum(rng.uniform(3, 11, n)) / RATE))
    rumble = lowpass(lowpass(noise(3.5), np.geomspace(1500, 90, n)), 300) * env(3.5, 0.08, 1.0) * flutter * 3
    return finish(drive(mix(3.5, (0, crack), (0.03, rumble)), 1.8), fade=0.2)


def rumble():
    n = int(2.5 * RATE)
    t = t_axis(2.5)
    swell = np.clip(t / 1.6, 0, 1) ** 1.5 * np.exp(-np.maximum(t - 2.0, 0) / 0.15)
    low = lowpass(lowpass(noise(2.5), 90), 90) * 8
    shake = 1 + 0.5 * np.sin(2 * np.pi * 9 * t) * rng.uniform(0.6, 1, n)
    grind = lowpass(noise(2.5), 500) * 0.3
    return finish(drive((low * shake + grind) * swell, 1.5), fade=0.1)


# ---------------------------------------------------------------------------- boss

def boss_roar():
    seconds = 2.4
    t = t_axis(seconds)
    pitch = 95 * (1 + 0.35 * np.sin(np.pi * np.clip(t / 1.8, 0, 1))) * (1 + 0.04 * np.sin(2 * np.pi * 23 * t))
    pitch *= 1 + 0.03 * lowpass(noise(seconds), 30) * 20
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    voice = wave_shape(phase, "saw") + 0.6 * wave_shape(phase * 0.5, "saw") + 0.4 * wave_shape(phase * 1.01, "square")
    breath = lowpass(highpass(noise(seconds), 300), 2500) * 0.8
    shape = np.clip(t / 0.25, 0, 1) * np.exp(-np.maximum(t - 1.4, 0) / 0.35)
    roar = lowpass((voice + breath) * shape, 1800)
    return finish(drive(roar, 2.2), peak=0.85, fade=0.15)


def boss_incoming():
    seconds = 2.4
    t = t_axis(seconds)
    f = 520 + 380 * (0.5 - 0.5 * np.cos(2 * np.pi * t / 1.2))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    siren = (wave_shape(phase, "square") + 0.5 * wave_shape(phase * 1.5, "tri")) * 0.6
    drum = sweep(90, 40, 0.5) * env(0.5, 0.002, 0.12)
    return finish(mix(seconds, (0, lowpass(siren, 3500)), (0, drum), (1.2, drum)), fade=0.1)


# ---------------------------------------------------------------------------- UI / jingles

def chime(freq, seconds, shape="tri", decay=0.25):
    return (tone(freq, seconds, shape) + 0.3 * tone(freq * 2, seconds, "sine")) * env(seconds, 0.005, decay)


def wave_start():
    horn = sum(tone(note(n), 0.9, "saw", vibrato=0.006) for n in ("A3", "E4", "A4"))
    horn = lowpass(horn, 2200) * env(0.9, 0.03, 0.5)
    return finish(mix(1.3, (0, horn * 0.6), (0.35, lowpass(horn, 1800) * 0.7)), fade=0.1)


def wave_complete():
    notes = ["C5", "E5", "G5", "C6"]
    parts = [(i * 0.09, chime(note(n), 0.6)) for i, n in enumerate(notes)]
    return finish(mix(1.0, *parts), fade=0.1)


def victory():
    seq = [("C5", 0.0), ("C5", 0.15), ("C5", 0.3), ("C5", 0.45), ("G#4", 0.6), ("A#4", 0.9), ("C5", 1.2)]
    parts = [(start, chime(note(n), 0.5 if i < 6 else 1.6, "square", 0.18 if i < 6 else 0.7) * 0.5) for i, (n, start) in enumerate(seq)]
    chord = sum(tone(note(n), 1.6, "saw") for n in ("C4", "E4", "G4")) * env(1.6, 0.02, 0.7) * 0.25
    parts.append((1.2, lowpass(chord, 2500)))
    return finish(mix(2.9, *parts), fade=0.2)


def error_buzz():
    buzz = lowpass(tone(150, 0.16, "square") + tone(157, 0.16, "saw") * 0.5, 2000) * env(0.16, 0.005, 0.2)
    return finish(mix(0.4, (0, buzz), (0.2, buzz)), peak=0.7)


# ---------------------------------------------------------------------------- music

def music():
    """Bouncy, slightly silly chiptune loop (16 bars at 150 BPM, loops seamlessly)."""
    bpm = 150
    beat = 60 / bpm
    bars = 16
    length = bars * 4 * beat
    out = np.zeros(int(length * RATE))

    def add(start, sig, gain):
        i = int(start * RATE)
        n = min(len(sig), len(out) - i)
        out[i : i + n] += sig[:n] * gain

    kick = sweep(150, 45, 0.25) * env(0.25, 0.001, 0.07)
    snare = (highpass(noise(0.2), 1200) * 0.8 + tone(190, 0.2) * 0.4) * env(0.2, 0.001, 0.05)
    hat = highpass(noise(0.05), 7000) * env(0.05, 0.0005, 0.012)

    chords = [("A2", ["A3", "C4", "E4"]), ("F2", ["F3", "A3", "C4"]), ("C3", ["G3", "C4", "E4"]), ("G2", ["G3", "B3", "D4"])]
    melody_a = ["A4", "C5", "E5", "D5", "C5", "D5", "E5", "-", "F5", "E5", "D5", "C5", "D5", "-", "B4", "-"]
    melody_b = ["E5", "-", "E5", "D5", "C5", "-", "A4", "-", "C5", "D5", "E5", "G5", "E5", "-", "D5", "-"]

    for bar in range(bars):
        t0 = bar * 4 * beat
        root, chord = chords[bar % 4]
        for b in range(4):
            add(t0 + b * beat, kick, 0.9 if b % 2 == 0 else 0.6)
            if b % 2 == 1:
                add(t0 + b * beat, snare, 0.45)
            for h in range(2):
                add(t0 + b * beat + h * beat / 2, hat, 0.18 if h else 0.1)
            # bass: root on the beat, octave on the off-beat
            for h, mult in ((0, 1), (0.5, 2)):
                sig = lowpass(tone(note(root) * mult, beat * 0.45, "square"), 900) * env(beat * 0.45, 0.003, 0.12)
                add(t0 + b * beat + h * beat, sig, 0.35)
            # chord stabs on the off-beats
            stab = sum(tone(note(n), beat * 0.3, "square") for n in chord)
            add(t0 + b * beat + beat / 2, lowpass(stab, 2400) * env(beat * 0.3, 0.003, 0.05), 0.08)
        if bar >= 4:  # melody joins after 4 bars of groove
            melody = melody_a if (bar // 2) % 2 == 0 else melody_b
            half = (bar % 2) * 8
            for step in range(8):
                n = melody[half + step]
                if n != "-":
                    sig = tone(note(n), beat * 0.48, "square", vibrato=0.004) * env(beat * 0.48, 0.004, 0.18)
                    add(t0 + step * beat / 2, lowpass(sig, 3500), 0.16)
    return finish(drive(out, 1.3), peak=0.8, fade=0.0)


SOUNDS = {
    "Fire_Pistol": fire_pistol,
    "Fire_Shotgun": fire_shotgun,
    "Fire_AssaultRifle": fire_rifle,
    "Reload": reload_sound,
    "Hit": hit,
    "GrandmaPoof": grandma_poof,
    "Explosion": explosion,
    "Stomp": stomp,
    "WaveStart": wave_start,
    "WaveComplete": wave_complete,
    "BossIncoming": boss_incoming,
    "BossRoar": boss_roar,
    "Thunder": thunder,
    "Rumble": rumble,
    "Victory": victory,
    "Error": error_buzz,
    "Music": music,
}


def write_ogg(name, samples):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(samples, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    target = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "6", target], check=True)
    os.remove(path)
    return target


if __name__ == "__main__":
    for name, make in SOUNDS.items():
        samples = make()
        print(f"{name:18s} {len(samples) / RATE:5.2f}s -> {write_ogg(name, samples)}")
