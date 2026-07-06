#!/usr/bin/env python3
"""ヒーリングBGMの合成スクリプト。

サイン波ベースのソフトなパッド音で、ゆっくり移り変わるコード進行を
シームレスにループする96秒のステレオWAVとして書き出す。
著作権フリー(自作)素材としてアプリに同梱する。
"""
import wave

import numpy as np

SR = 44100
CHORD_SEC = 24.0          # 1コードの長さ
XFADE_SEC = 8.0           # コード間のクロスフェード
RNG = np.random.default_rng(42)

# 癒し系の4コード進行 (Cmaj7 -> Am9 -> Fmaj9 -> G6) を低めの音域で
CHORDS = [
    [130.81, 164.81, 196.00, 246.94, 329.63],   # C3 E3 G3 B3 E4
    [110.00, 164.81, 196.00, 246.94, 261.63],   # A2 E3 G3 B3 C4
    [174.61, 220.00, 261.63, 329.63, 392.00],   # F3 A3 C4 E4 G4
    [98.00, 196.00, 246.94, 293.66, 329.63],    # G2 G3 B3 D4 E4
]


def pad_note(freq: float, n: int) -> np.ndarray:
    """1音ぶんのステレオパッド。倍音・デチューン・ゆらぎ入り。"""
    t = np.arange(n) / SR
    # ゆっくりした音量のゆらぎ (0.05〜0.12Hz)
    lfo_rate = RNG.uniform(0.05, 0.12)
    lfo_phase = RNG.uniform(0, 2 * np.pi)
    lfo = 0.75 + 0.25 * np.sin(2 * np.pi * lfo_rate * t + lfo_phase)

    def tone(f: float) -> np.ndarray:
        ph = RNG.uniform(0, 2 * np.pi)
        y = np.sin(2 * np.pi * f * t + ph)
        y += 0.30 * np.sin(2 * np.pi * f * 2 * t + ph * 1.7)   # オクターブ上を薄く
        y += 0.10 * np.sin(2 * np.pi * f * 3 * t + ph * 2.3)   # 3倍音をさらに薄く
        return y

    detune = freq * 0.0012
    left = tone(freq - detune)
    right = tone(freq + detune)
    stereo = np.stack([left, right], axis=1)
    return stereo * lfo[:, None]


def chord_pad(freqs: list[float], n: int) -> np.ndarray:
    out = np.zeros((n, 2))
    for f in freqs:
        out += pad_note(f, n)
    # 低音のドローン (ルートの1オクターブ下) を薄く敷く
    root = min(freqs)
    t = np.arange(n) / SR
    drone = 0.5 * np.sin(2 * np.pi * (root / 2) * t)
    out += np.stack([drone, drone], axis=1)
    return out / (len(freqs) + 1)


def main() -> None:
    n_chord = int(CHORD_SEC * SR)
    n_fade = int(XFADE_SEC * SR)
    n_total = n_chord * len(CHORDS)

    mix = np.zeros((n_total + n_fade, 2))
    # 等パワークロスフェードで連結。最後のコードのフェード尻は先頭に回してループを閉じる
    fade_in = np.sin(np.linspace(0, np.pi / 2, n_fade)) ** 2
    env = np.ones(n_chord + n_fade)
    env[:n_fade] = fade_in
    env[-n_fade:] = 1 - fade_in

    for i, freqs in enumerate(CHORDS):
        seg = chord_pad(freqs, n_chord + n_fade) * env[:, None]
        start = i * n_chord
        mix[start:start + n_chord + n_fade] += seg
    # はみ出したフェード尻を先頭に加算 → シームレスループ
    mix[:n_fade] += mix[n_total:n_total + n_fade]
    mix = mix[:n_total]

    # ごく薄いピンクノイズ風の空気感 (1次ローパスをかけた白色雑音)
    noise = RNG.standard_normal((n_total, 2))
    alpha = 0.995
    for ch in range(2):
        acc = 0.0
        col = noise[:, ch]
        filtered = np.empty_like(col)
        for j in range(len(col)):
            acc = alpha * acc + (1 - alpha) * col[j]
            filtered[j] = acc
        noise[:, ch] = filtered
    noise /= np.max(np.abs(noise))
    mix += 0.02 * noise

    # -14dBFS程度に正規化
    mix = mix / np.max(np.abs(mix)) * 10 ** (-14 / 20)

    pcm = (mix * 32767).astype(np.int16)
    with wave.open("bgm.wav", "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"wrote bgm.wav: {n_total / SR:.1f}s")


if __name__ == "__main__":
    main()
