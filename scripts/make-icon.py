# Usage: python3 scripts/make-icon.py Resources   (needs Pillow)
# Draws the Style Check app icon: a paper page with text lines and a
# check-mark badge, on a macOS-style rounded square. Writes PNG + ICNS.
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024
def rr(draw, box, r, fill):
    draw.rounded_rectangle(box, radius=r, fill=fill)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# Background tile (Apple grid: 824px square, ~185px radius, centered)
tile = Image.new("RGBA", (S, S), (0, 0, 0, 0))
m = 100
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
top, bot = (38, 70, 120), (20, 40, 78)  # deep ink blue
for y in range(S):
    t = y / (S - 1)
    gd.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((m, m, S - m, S - m), radius=185, fill=255)
# soft shadow
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle((m, m + 14, S - m, S - m + 14), radius=185, fill=(0, 0, 0, 90))
shadow = shadow.filter(ImageFilter.GaussianBlur(18))
img.alpha_composite(shadow)
img.paste(grad, (0, 0), mask)

d = ImageDraw.Draw(img)
# Paper page
px0, py0, px1, py1 = 290, 215, 700, 790
page_shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(page_shadow).rounded_rectangle((px0 + 8, py0 + 16, px1 + 8, py1 + 16), radius=34, fill=(0, 0, 0, 110))
page_shadow = page_shadow.filter(ImageFilter.GaussianBlur(14))
img.alpha_composite(page_shadow)
d = ImageDraw.Draw(img)
d.rounded_rectangle((px0, py0, px1, py1), radius=34, fill=(250, 247, 240, 255))

# Text lines
ink = (60, 72, 95, 255)
y = 300
widths = [300, 330, 250, 320, 190]
for w in widths:
    d.rounded_rectangle((px0 + 52, y, px0 + 52 + w, y + 26), radius=13, fill=ink)
    y += 72
# Line 3: a highlighted word (the correction) followed by the rest of the line
d.rectangle((px0 + 40, 432, px0 + 400, 484), fill=(250, 247, 240, 255))  # clear default line
d.rounded_rectangle((px0 + 40, 430, px0 + 196, 484), radius=14, fill=(255, 196, 61, 255))
d.rounded_rectangle((px0 + 58, 444, px0 + 178, 470), radius=13, fill=ink)
d.rounded_rectangle((px0 + 214, 444, px0 + 302, 470), radius=13, fill=ink)

# Check-mark badge
cx, cy, r = 690, 720, 150
badge_shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(badge_shadow).ellipse((cx - r + 6, cy - r + 14, cx + r + 6, cy + r + 14), fill=(0, 0, 0, 120))
badge_shadow = badge_shadow.filter(ImageFilter.GaussianBlur(14))
img.alpha_composite(badge_shadow)
d = ImageDraw.Draw(img)
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(52, 168, 110, 255))
d.ellipse((cx - r + 10, cy - r + 10, cx + r - 10, cy + r - 10), outline=(255, 255, 255, 60), width=6)
d.line([(cx - 70, cy + 4), (cx - 18, cy + 58), (cx + 76, cy - 52)], fill=(255, 255, 255, 255), width=40, joint="curve")
for p in [(cx - 70, cy + 4), (cx - 18, cy + 58), (cx + 76, cy - 52)]:
    d.ellipse((p[0] - 20, p[1] - 20, p[0] + 20, p[1] + 20), fill=(255, 255, 255, 255))

out = sys.argv[1]
img.save(out + "/AppIcon-1024.png")
img.save(out + "/AppIcon.icns", sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
print("ok")
