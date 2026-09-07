#!/usr/bin/env python3
"""Generate the app's original, dependency-free PCM slate sounds."""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 48_000
OUTPUT = Path(__file__).resolve().parents[1] / "Slate" / "Sounds"


def write(name: str, samples: list[float]) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    pcm = b"".join(struct.pack("<h", round(max(-1, min(1, sample)) * 32767)) for sample in samples)
    with wave.open(str(OUTPUT / name), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(pcm)


def beep() -> list[float]:
    duration = 0.18
    values = []
    for index in range(round(RATE * duration)):
        t = index / RATE
        attack = min(1, t / 0.004)
        release = min(1, (duration - t) / 0.025)
        envelope = attack * release
        tone = math.sin(2 * math.pi * 1_000 * t) + 0.18 * math.sin(2 * math.pi * 2_000 * t)
        values.append(0.58 * envelope * tone)
    return values


def clap() -> list[float]:
    random.seed(20260907)
    duration = 0.34
    bursts = (0.0, 0.017, 0.034, 0.061)
    values = []
    previous_noise = 0.0
    for index in range(round(RATE * duration)):
        t = index / RATE
        noise = random.uniform(-1, 1)
        high_pass = noise - 0.82 * previous_noise
        previous_noise = noise
        envelope = sum(math.exp(-(t - start) * 44) for start in bursts if t >= start)
        body = 0.12 * math.sin(2 * math.pi * 185 * t) * math.exp(-t * 22)
        sample = 0.34 * envelope * high_pass + body
        values.append(math.tanh(sample * 1.35) * 0.9)
    return values


write("beep.wav", beep())
write("clap.wav", clap())
