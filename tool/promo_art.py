"""Promo pictures in the UntrustedTech family look (after OpenWear's
brand/make_promo.py): the app's near-black, a soft accent glow, real screens
in phones with a soft shadow, and one plain title per picture.

App screens come from the screenshot tests (sample data only):

  cd test_screenshots && flutter test screens_test.dart --update-goldens
  python3 tool/promo_art.py

Writes docs/images/promo/: banner.jpg (README top), glance.jpg, train.jpg,
more.jpg, light-and-dark.jpg (README), social-preview.png (1280 x 640;
upload it in the repo's Settings > General > Social preview) and
og-health.jpg (1200 x 630, the website's link preview). The store set uses
the same drawing (Health-Store: tool/make_store_shots.py).
"""
import pathlib
import textwrap

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONTS = ROOT / 'assets/fonts'
SHOTS = ROOT / 'test_screenshots/shots'
ICON = ROOT / 'docs/images/icon.png'
OUT = ROOT / 'docs/images/promo'

BACKGROUND = (13, 14, 18)
TEXT = (242, 242, 247)
MUTED = (160, 163, 176)
ACCENT = (142, 136, 255)

TAGLINE = 'Your health, without the cloud.'
BULLETS = ('Your data stays on your phone, encrypted',
           'Activity, heart, sleep, food and workouts',
           'Readiness against your own normal')
META = 'NO ACCOUNT  ·  NO SERVERS  ·  ANDROID'

ROWS = [
    ('glance', ['v19_summary', 'v19_readiness', 'heart_trends_dark'], 'Everything at a glance',
     'Your day, your readiness and every heart rate reading'),
    ('train', ['workout_detail', 'gym_live', 'v19_fitness'], 'Train your way',
     'GPS runs, strength sessions with a rest timer, and workouts that suit today'),
    ('more', ['food_diary', 'sleep_stages', 'habits_dark'], 'Food, sleep and habits',
     'A calorie budget that grows when you move, sleep stages and daily streaks'),
    ('light-and-dark', ['summary_light', 'summary_dark', 'heart_trends_light'], 'Light and dark',
     'Follows your phone, or pick one in Appearance'),
]


def font(name, size):
    return ImageFont.truetype(str(FONTS / f'{name}.ttf'), round(size))


def shot(name):
    return Image.open(SHOTS / f'{name}.png')


def phone(screen, width, corner=1 / 7):
    """[screen] in a rounded body with a soft shadow, [width] px wide. A
    tablet passes a smaller [corner]."""
    s = screen.convert('RGB')
    height = round(s.height * width / s.width)
    s = s.resize((width, height), Image.LANCZOS)
    bezel = max(6, width // 40)
    radius = round(width * corner)
    w, h = width + 2 * bezel, height + 2 * bezel
    pad = width // 10
    out = Image.new('RGBA', (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    shadow = Image.new('RGBA', out.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((pad, pad + pad // 3, pad + w, pad + h + pad // 3),
                                             radius + bezel, fill=(0, 0, 0, 170))
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(pad // 2)))
    body = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, w - 1, h - 1), radius + bezel, fill=(30, 31, 38, 255),
                                           outline=(70, 71, 80, 255), width=2)
    mask = Image.new('L', s.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s.width - 1, s.height - 1), radius, fill=255)
    body.paste(s, (bezel, bezel), mask)
    out.alpha_composite(body, (pad, pad))
    return out


def glow(img, center, radius, alpha, color=ACCENT):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    x, y = center
    ImageDraw.Draw(layer).ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*color, alpha))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius // 2)))


def centred(d, y, text, face, fill, width):
    d.text(((width - d.textlength(text, font=face)) / 2, y), text, font=face, fill=fill)


def wrap(d, text, face, width):
    """Lines no wider than [width], never leaving one word on the last line."""
    avg = d.textlength('abcdefghijklmnopqrstuvwxyz', font=face) / 26
    n = max(6, int(width / avg))
    out = textwrap.wrap(text, n)
    while len(out) > 1 and ' ' not in out[-1] and n > 6:
        n -= 1
        out = textwrap.wrap(text, n)
    return out


def banner(size, name, screens):
    """Logo, name, tagline, three points and a footer line on the left; three
    phones fanned on the right. Drawn 2400 wide, then scaled to [size]."""
    W = 2400
    H = round(W * size[1] / size[0])
    k = H / 1260
    img = Image.new('RGBA', (W, H), (*BACKGROUND, 255))
    glow(img, (1700, round(700 * k)), round(520 * k), 60)
    logo = Image.open(ICON).convert('RGBA').resize((round(150 * k),) * 2, Image.LANCZOS)
    m = Image.new('L', logo.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, logo.width - 1, logo.height - 1), round(logo.width * 0.22), fill=255)
    img.paste(logo, (150, round(300 * k)), m)
    d = ImageDraw.Draw(img)
    d.text((146, round(480 * k)), name, font=font('InterDisplay-Bold', 132 * k), fill=TEXT)
    d.text((152, round(650 * k)), TAGLINE, font=font('Inter-Regular', 54 * k), fill=MUTED)
    y = round(780 * k)
    for line in BULLETS:
        r = 9 * k
        d.ellipse((158, y + 31 * k - r, 158 + 2 * r, y + 31 * k + r), fill=ACCENT)
        d.text((200, y), line, font=font('Inter-Medium', 40 * k), fill=TEXT)
        y += round(70 * k)
    d.text((154, round(1080 * k)), META, font=font('Inter-SemiBold', 30 * k), fill=MUTED)
    for screen, x, top, w in ((screens[1], 1180, 170, 470), (screens[2], 1840, 170, 470), (screens[0], 1460, 80, 540)):
        img.alpha_composite(phone(screen, round(w * k)), (x - round(w * (k - 1) / 2), round(top * k)))
    return img.convert('RGB').resize(size, Image.LANCZOS)


def row(screens, title, caption, size=(2400, 1500)):
    """A centred title and caption over three phones that run off the bottom."""
    W, H = size
    img = Image.new('RGBA', size, (*BACKGROUND, 255))
    glow(img, (W // 2, 900), 700, 38)
    d = ImageDraw.Draw(img)
    centred(d, 70, title, font('InterDisplay-Bold', 76), TEXT, W)
    centred(d, 175, caption, font('Inter-Regular', 40), MUTED, W)
    shots = [phone(s, 520) for s in screens]
    gap = 10
    x = (W - sum(s.width for s in shots) - gap * (len(shots) - 1)) // 2
    for s in shots:
        img.alpha_composite(s, (x, 250))
        x += s.width + gap
    return img.convert('RGB')


def card(size, headline, screen, corner=1 / 7):
    """Portrait store slide: a centred headline over one phone that runs off
    the bottom edge."""
    w, h = size
    img = Image.new('RGBA', size, (*BACKGROUND, 255))
    glow(img, (w // 2, round(h * 0.62)), round(w * 0.55), 46)
    d = ImageDraw.Draw(img)
    face = font('InterDisplay-Bold', w * 0.075)
    y = round(h * 0.06)
    for ln in wrap(d, headline, face, w * 0.84):
        centred(d, y, ln, face, TEXT, w)
        y += round(w * 0.075 * 1.15)
    body = phone(screen, round(w * 0.74), corner)
    img.alpha_composite(body, ((w - body.width) // 2, y + round(w * 0.01)))
    return img.convert('RGB')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    fan = [shot('v19_summary'), shot('heart_trends_dark'), shot('sleep_stages')]
    banner((2400, 1260), 'Open Health', fan).save(OUT / 'banner.jpg', quality=90)
    banner((1280, 640), 'Open Health', fan).save(OUT / 'social-preview.png', optimize=True)
    banner((1200, 630), 'Health', fan).save(OUT / 'og-health.jpg', quality=88)
    for name, screens, title, caption in ROWS:
        row([shot(s) for s in screens], title, caption).save(OUT / f'{name}.jpg', quality=90)
    print('promo images written to', OUT)


if __name__ == '__main__':
    main()
