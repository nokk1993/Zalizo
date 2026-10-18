"""Generates the app icon (simple barbell on a warm gradient). Run: python3 Tools/make_icon.py"""
from PIL import Image, ImageDraw

S = 4096  # supersampled, downscaled to 1024 for anti-aliasing
img = Image.new("RGB", (S, S))
top, bottom = (255, 122, 61), (196, 52, 18)
draw = ImageDraw.Draw(img)
for y in range(S):
    t = y / (S - 1)
    draw.line([(0, y), (S, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

white = (255, 255, 255)
cy = S // 2
u = S / 1024
def rr(x0, y0, x1, y1, r):
    draw.rounded_rectangle([x0 * u, y0 * u, x1 * u, y1 * u], radius=r * u, fill=white)

rr(170, 492, 854, 532, 20)           # bar
for x0, x1, h in [(250, 320, 360), (330, 380, 260), (644, 694, 260), (704, 774, 360)]:
    rr(x0, 512 - h / 2, x1, 512 + h / 2, 22)  # plates
rr(392, 482, 410, 542, 6)            # collars
rr(614, 482, 632, 542, 6)

img.resize((1024, 1024), Image.LANCZOS).save(
    "Zalizo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png", optimize=True)
