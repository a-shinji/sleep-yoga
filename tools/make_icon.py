#!/usr/bin/env python3
"""アプリアイコン生成: 夜空グラデーション + 三日月 + 星"""
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 1024
img = Image.new("RGB", (S, S))
px = img.load()

# 縦グラデーション (深い藍 -> 濃紫)
top = (20, 24, 62)
bottom = (10, 7, 28)
for y in range(S):
    t = y / (S - 1)
    r = int(top[0] + (bottom[0] - top[0]) * t)
    g = int(top[1] + (bottom[1] - top[1]) * t)
    b = int(top[2] + (bottom[2] - top[2]) * t)
    for x in range(S):
        px[x, y] = (r, g, b)

draw = ImageDraw.Draw(img)

# 星 (固定シードの擬似ランダム配置)
seed = 12345


def rnd():
    global seed
    seed = (seed * 1103515245 + 12345) % (2**31)
    return seed / (2**31)


for _ in range(70):
    x, y = rnd() * S, rnd() * S
    r = 1.5 + rnd() * 3.0
    a = int(110 + rnd() * 130)
    draw.ellipse([x - r, y - r, x + r, y + r], fill=(a, a, min(255, a + 25)))

# 月の温かいグロー
cx, cy, mr = S * 0.50, S * 0.47, S * 0.24
glow = Image.new("RGB", (S, S), (0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([cx - mr * 1.4, cy - mr * 1.4, cx + mr * 1.4, cy + mr * 1.4],
           fill=(85, 62, 30))
glow = glow.filter(ImageFilter.GaussianBlur(80))
img = ImageChops.add(img, glow)

# 三日月: 満月を描いてから、ずらした円の内側を「月を描く前の背景」で埋め戻す
bg_before_moon = img.copy()
draw = ImageDraw.Draw(img)
draw.ellipse([cx - mr, cy - mr, cx + mr, cy + mr], fill=(252, 243, 205))

off_x, off_y = mr * 0.42, -mr * 0.22
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).ellipse(
    [cx - mr + off_x, cy - mr + off_y, cx + mr + off_x, cy + mr + off_y],
    fill=255,
)
mask = mask.filter(ImageFilter.GaussianBlur(2))
img.paste(bg_before_moon, (0, 0), mask)

img.save("AppIcon.png")
print("wrote AppIcon.png")
