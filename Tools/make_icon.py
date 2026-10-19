"""Generates the app icon of «Зал»: a glowing lime gauge around a barbell on a frosted glass disc,
dark navy canvas with a blue rim light. Run: python3 Tools/make_icon.py"""
import math

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 4096  # supersampled, downscaled to 1024 for anti-aliasing
U = S / 1024
LIME = (204, 250, 61)
OLIVE = (84, 128, 13)
BLUE = (92, 140, 255)
ICE = (226, 234, 247)
OUT = "Zalizo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"


def u(v):
    return v * U


def radial(size, center, radius, color, alpha):
    """Soft radial glow layer (RGBA)."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.45))


def canvas():
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    top, bottom = (22, 31, 52), (3, 4, 8)
    for y in range(S):
        t = (y / (S - 1)) ** 0.9
        d.line([(0, y), (S, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    img = img.convert("RGBA")
    img.alpha_composite(radial(img.size, (u(930), u(40)), u(520), BLUE, 120))
    img.alpha_composite(radial(img.size, (u(40), u(1040)), u(380), OLIVE, 105))
    img.alpha_composite(radial(img.size, (u(512), u(560)), u(300), LIME, 46))
    return img


def glass_disc(img, center, r):
    """Frosted disc: blurred backdrop, white sheen, light rim."""
    cx, cy = center
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    blurred = img.filter(ImageFilter.GaussianBlur(u(40)))
    img.paste(blurred, (0, 0), mask)

    sheen = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    steps = 120
    for i in range(steps):  # top-left brighter, bottom-right darker
        t = i / (steps - 1)
        a = round(34 * (1 - t) + 6 * t)
        y0 = cy - r + 2 * r * t
        sd.rectangle([cx - r, y0, cx + r, y0 + 2 * r / steps + 2], fill=(255, 255, 255, a))
    sheen.putalpha(ImageChops.multiply(sheen.getchannel("A"), mask))
    img.alpha_composite(sheen)

    rim = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(rim).ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 90), width=round(u(5)))
    fade = Image.new("L", img.size, 0)
    fd = ImageDraw.Draw(fade)
    for i in range(64):  # rim fades towards the bottom-right
        t = i / 63
        fd.rectangle([0, cy - r + 2 * r * t, S, cy - r + 2 * r * (t + 1 / 63) + 2], fill=round(255 * (1 - t) + 40 * t))
    rim.putalpha(ImageChops.multiply(rim.getchannel("A"), fade))
    img.alpha_composite(rim)


def gauge(img, center, r, width, sweep):
    """Lime 270° gauge with round caps and a glow, start at bottom-left."""
    cx, cy = center
    start = 135
    end = start + 270 * sweep
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    track = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(track).arc([cx - r, cy - r, cx + r, cy + r], start, start + 270, fill=(255, 255, 255, 30), width=round(width))
    for angle in (start, start + 270):  # round caps on the centre line of the stroke
        rc = width / 2
        xm = cx + (r - width / 2) * math.cos(math.radians(angle))
        ym = cy + (r - width / 2) * math.sin(math.radians(angle))
        ImageDraw.Draw(track).ellipse([xm - rc, ym - rc, xm + rc, ym + rc], fill=(255, 255, 255, 30))
    img.alpha_composite(track)

    d.arc([cx - r, cy - r, cx + r, cy + r], start, end, fill=LIME + (255,), width=round(width))
    rc = width / 2
    for angle in (start, end):
        xm = cx + (r - width / 2) * math.cos(math.radians(angle))
        ym = cy + (r - width / 2) * math.sin(math.radians(angle))
        d.ellipse([xm - rc, ym - rc, xm + rc, ym + rc], fill=LIME + (255,))
    glow = layer.filter(ImageFilter.GaussianBlur(u(26)))
    img.alpha_composite(glow)
    img.alpha_composite(glow)
    img.alpha_composite(layer)

    # bright head of the progress
    xm = cx + (r - width / 2) * math.cos(math.radians(end))
    ym = cy + (r - width / 2) * math.sin(math.radians(end))
    head = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hr = width * 0.28
    ImageDraw.Draw(head).ellipse([xm - hr, ym - hr, xm + hr, ym + hr], fill=(255, 255, 255, 230))
    img.alpha_composite(head.filter(ImageFilter.GaussianBlur(u(3))))


def barbell(img, center):
    cx, cy = center
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def rr(x0, y0, x1, y1, radius, color):
        d.rounded_rectangle([u(x0), u(y0), u(x1), u(y1)], radius=u(radius), fill=color)

    ink = ICE + (255,)
    rr(cx / U - 250, cy / U - 11, cx / U + 250, cy / U + 11, 11, ink)  # bar
    for dx0, dx1, h in [(-212, -174, 236), (-164, -132, 168), (132, 164, 168), (174, 212, 236)]:
        rr(cx / U + dx0, cy / U - h / 2, cx / U + dx1, cy / U + h / 2, 17, ink)  # plates
    rr(cx / U - 120, cy / U - 28, cx / U - 109, cy / U + 28, 5, ink)  # collars
    rr(cx / U + 109, cy / U - 28, cx / U + 120, cy / U + 28, 5, ink)

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.putalpha(layer.getchannel("A").point(lambda a: a * 0.55))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(u(14))), (0, round(u(10))))
    img.alpha_composite(layer)


def main():
    img = canvas()
    center = (S / 2, u(520))
    glass_disc(img, center, u(372))
    gauge(img, center, u(318), u(50), 0.72)
    barbell(img, center)
    img.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(OUT, optimize=True)


if __name__ == "__main__":
    main()
