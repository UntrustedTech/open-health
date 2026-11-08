"""Writes the app icon's SVG masters to assets/branding/src.

One champagne line on a graphite tile: it runs round an open ring, then
in through the middle as a pulse. Render each SVG to a 1024 px PNG of the
same name in assets/branding (any SVG renderer, e.g.
`rsvg-convert -w 1024 -h 1024`), then run
`dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`,
then tool/make_app_icons.py again (the first resets the iOS icon list).

The other icons people can switch to are written by tool/make_app_icons.py.
"""
import math
import pathlib

C = 512
R = 262  # ring radius
W = 66  # line width, the same for the ring and the pulse
OUT = pathlib.Path(__file__).resolve().parent.parent / 'assets/branding/src'


def point(deg):
    a = math.radians(deg)
    return f'{C + R * math.cos(a):.1f},{C + R * math.sin(a):.1f}'


def line_path():
    # Clockwise from the open end (about 11 o'clock) round to 9 o'clock,
    # then in along the middle as a heartbeat.
    pulse = [(-120, 0), (-62, -118), (12, 130), (70, -40), (104, 0), (170, 0)]
    beats = ' '.join(f'L{C + x},{C + y}' for x, y in pulse)
    return f'M{point(-118)} A{R},{R} 0 1 1 {point(180)} {beats}'


TOP, BOTTOM = '#3A3B41', '#1C1D21'  # graphite, lit from above
GOLD = ('#F4E2BE', '#C9A66B')  # champagne, top to bottom
DEFS = (
    f'<linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">'
    f'<stop offset="0" stop-color="{TOP}"/>'
    f'<stop offset="1" stop-color="{BOTTOM}"/></linearGradient>'
    '<radialGradient id="glow" cx=".5" cy="0" r=".9">'
    '<stop offset="0" stop-color="#fff" stop-opacity=".1"/>'
    '<stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>'
    '<linearGradient id="gold" gradientUnits="userSpaceOnUse" '
    'x1="0" y1="250" x2="0" y2="780">'
    f'<stop offset="0" stop-color="{GOLD[0]}"/>'
    f'<stop offset="1" stop-color="{GOLD[1]}"/></linearGradient>'
)


def svg(body, tile=False, scale=1.0, stroke='url(#gold)'):
    # Adaptive icons and the splash crop to the middle, so the line is
    # smaller there (scale), keeping it inside Android's safe zone.
    move = f'translate({C * (1 - scale):.1f} {C * (1 - scale):.1f}) scale({scale})'
    line = (
        f'<path d="{line_path()}" transform="{move}" fill="none" '
        f'stroke="{stroke}" stroke-width="{W}" stroke-linecap="round" '
        'stroke-linejoin="round"/>'
    ) if body else ''
    rect = (
        '<rect width="1024" height="1024" fill="url(#tile)"/>'
        '<rect width="1024" height="1024" fill="url(#glow)"/>'
    ) if tile else ''
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" '
        f'width="1024" height="1024"><defs>{DEFS}</defs>{rect}{line}</svg>\n'
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        'icon': svg(True, tile=True),
        'icon_background': svg(False, tile=True),
        'icon_foreground': svg(True, scale=0.72),
        'icon_monochrome': svg(True, scale=0.72, stroke='#fff'),
        'splash': svg(True, scale=0.72),
    }
    for name, text in files.items():
        (OUT / f'{name}.svg').write_text(text)


if __name__ == '__main__':
    main()

