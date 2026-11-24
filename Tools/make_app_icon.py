#!/usr/bin/env python3
"""Draw the placeholder 1024x1024 app icon (opaque PNG, as App Store requires).
Usage: python3 -I Tools/make_app_icon.py PlanetKeyboard/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"""
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024
img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
top, bottom = (36, 24, 92), (12, 10, 36)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)))
for x, y, r in [(150, 170, 5), (860, 140, 4), (780, 300, 3), (120, 520, 3), (900, 620, 5), (220, 880, 4), (700, 900, 3)]:
    d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255))

cx, cy, R = 512, 470, 250
ring_box = [cx - 420, cy - 110, cx + 420, cy + 110]
back = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(back).ellipse(ring_box, outline=(255, 196, 120, 255), width=34)
img.paste(back, (0, 0), back)
planet = Image.new("RGBA", (S, S), (0, 0, 0, 0))
pd = ImageDraw.Draw(planet)
for i in range(R, 0, -2):
    t = i / R
    pd.ellipse([cx - i - (1 - t) * 60, cy - i - (1 - t) * 60, cx + i - (1 - t) * 60, cy + i - (1 - t) * 60],
               fill=(int(90 + 120 * (1 - t)), int(120 + 110 * (1 - t)), 255, 255))
img.paste(planet, (0, 0), planet)
front = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(front).arc(ring_box, start=0, end=180, fill=(255, 196, 120, 255), width=34)
img.paste(front, (0, 0), front)

# keyboard keys under the planet
kw, kh, gap, y0 = 120, 92, 22, 800
x0 = (S - (4 * kw + 3 * gap)) // 2
for i in range(4):
    x = x0 + i * (kw + gap)
    d.rounded_rectangle([x, y0, x + kw, y0 + kh], radius=22, fill=(240, 240, 255))
img.save(sys.argv[1], "PNG")
print("wrote", sys.argv[1])
