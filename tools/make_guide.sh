#!/bin/sh
# guide_script.txt から NemuriYoga/Resources/guide.m4a を再生成する。
#
# 注意:
# - say は長尺(10分級)のファイル書き出しに失敗することがあるため、
#   2分割して生成してから WAV レベルで連結する
# - afconvert は 22.05kHz モノラル入力にビットレート指定(-b)をすると
#   '!dat' エラーになるため -q(品質)指定にする
set -e
cd "$(dirname "$0")"

VOICE=Kyoko
RATE=150

total=$(wc -l < guide_script.txt | tr -d ' ')
half=$(( (total + 1) / 2 ))
head -n "$half" guide_script.txt > .part1.txt
tail -n +"$((half + 1))" guide_script.txt > .part2.txt

say -v "$VOICE" -r "$RATE" -f .part1.txt -o .part1.wav --file-format=WAVE --data-format=LEI16@22050
say -v "$VOICE" -r "$RATE" -f .part2.txt -o .part2.wav --file-format=WAVE --data-format=LEI16@22050

python3 - <<'EOF'
import wave
out = wave.open(".guide_full.wav", "wb")
for i, name in enumerate([".part1.wav", ".part2.wav"]):
    w = wave.open(name, "rb")
    if i == 0:
        out.setparams(w.getparams())
    out.writeframes(w.readframes(w.getnframes()))
    w.close()
out.close()
EOF

afconvert -f m4af -d aac -q 127 .guide_full.wav ../NemuriYoga/Resources/guide.m4a
rm -f .part1.txt .part2.txt .part1.wav .part2.wav .guide_full.wav
afinfo ../NemuriYoga/Resources/guide.m4a | grep duration
echo "done: NemuriYoga/Resources/guide.m4a"
