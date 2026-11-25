"""Writes logo.html: the "BTA 7 Almosh City" mark as one SVG.

Original artwork: a desert sunset over a shikun skyline with a camel and a
Keter plastic chair, the letters BTA, and the 7 on a roundabout sign
(Beer Sheva is "the city of roundabouts", and sheva is seven).

    python3 tools/art/make_logo.py
    node tools/art/render.js tools/art/logo.html assets/art/logo.png 2000 1000 transparent
    node tools/art/render.js tools/art/icon.html assets/art/icon.png 256 256 transparent
"""
import math
from pathlib import Path

HERE = Path(__file__).parent
FONTS = "../../assets/fonts"
INK = "#12061f"

SIGN = (1490, 410, 250)          # centre x, centre y, radius of the roundabout sign


def arrows(cx, cy, radius, count=3, sweep=78, width=38):
    """The arrows of a roundabout sign: `count` arcs chasing each other anticlockwise."""
    parts = []
    for n in range(count):
        start = math.radians(n * 360 / count + 20)
        end = start - math.radians(sweep)          # SVG y is down: decreasing angle turns anticlockwise
        x0, y0 = cx + radius * math.cos(start), cy + radius * math.sin(start)
        x1, y1 = cx + radius * math.cos(end), cy + radius * math.sin(end)
        parts.append(f'<path d="M{x0:.1f} {y0:.1f} A{radius} {radius} 0 0 0 {x1:.1f} {y1:.1f}" '
                     f'fill="none" stroke="#fff" stroke-width="{width}"/>')
        # Arrow head: a triangle at the end of the arc, pointing along the tangent.
        tx, ty = math.sin(end), -math.cos(end)       # tangent in the direction of travel
        nx, ny = math.cos(end), math.sin(end)        # outwards
        tip = (x1 + tx * width * 1.5, y1 + ty * width * 1.5)
        left = (x1 + nx * width * 1.05, y1 + ny * width * 1.05)
        right = (x1 - nx * width * 1.05, y1 - ny * width * 1.05)
        parts.append('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#fff"/>' % (*tip, *left, *right))
    return "\n".join(parts)


def skyline():
    """Shikun blocks, a tower block and a water tower along the horizon, as one dark shape."""
    blocks = [(640, 150, 70), (800, 190, 95), (1000, 120, 60), (1130, 60, 190), (1200, 170, 80), (1380, 130, 64)]
    shapes = []
    for x, width, height in blocks:
        shapes.append(f'<rect x="{x}" y="{600 - height}" width="{width}" height="{height}"/>')
        for k in range(int(width // 40)):            # solar water heaters on every roof
            shapes.append(f'<rect x="{x + 10 + k * 40}" y="{600 - height - 12}" width="16" height="12"/>')
    # Water tower: a stem and a flared tank.
    shapes.append('<path d="M930 600 L938 500 L920 470 L990 470 L972 500 L980 600 Z"/>')
    return "\n".join(shapes)


CAMEL = ('<path d="M0 0 l6 -58 l-10 -34 c-2 -30 22 -44 46 -40 c14 -34 44 -34 58 0 c22 -6 40 4 46 24 '
         'l22 -62 c2 -16 18 -22 34 -18 l18 8 l-4 12 l-20 2 l-24 84 c-4 22 -22 34 -44 34 l8 48 l-12 0 l-14 -46 '
         'l-70 0 l-10 46 l-12 0 l4 -48 Z"/>')

CHAIR = ('<path d="M0 0 l4 -64 l8 0 l2 34 l40 0 l6 30 l-9 0 l-4 -20 l-33 0 l-3 20 Z"/>')

SVG = f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{{font-family:K;src:url('{FONTS}/Karantina-Bold.ttf')}}
@font-face{{font-family:Sec;src:url('{FONTS}/SecularOne-Regular.ttf')}}
html,body{{margin:0;background:transparent}}
svg{{display:block}}
</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="2000" height="1000" viewBox="0 0 2000 1000">
<defs>
  <linearGradient id="sun" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFE9A0"/><stop offset=".5" stop-color="#FF9B3D"/><stop offset="1" stop-color="#D9432F"/>
  </linearGradient>
  <linearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFF6C9"/><stop offset=".4" stop-color="#FFD35A"/><stop offset=".68" stop-color="#FF8A3A"/><stop offset="1" stop-color="#E23B6E"/>
  </linearGradient>
  <linearGradient id="city" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#BFF3F0"/>
  </linearGradient>
  <clipPath id="disc"><circle cx="1000" cy="400" r="350"/></clipPath>
  <filter id="drop" x="-10%" y="-10%" width="120%" height="130%">
    <feDropShadow dx="0" dy="14" stdDeviation="0" flood-color="{INK}" flood-opacity="1"/>
    <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000" flood-opacity=".55"/>
  </filter>
</defs>

<!-- the sun going down over the shikunim -->
<circle cx="1000" cy="400" r="350" fill="url(#sun)"/>
<g clip-path="url(#disc)" fill="{INK}">
  <rect x="600" y="600" width="800" height="200"/>
  {skyline()}
  <g transform="translate(1012 541) scale(0.5)">{CAMEL}</g>
</g>

<!-- BTA -->
<g filter="url(#drop)" transform="translate(1000 0) skewX(-7) translate(-1000 0)">
  <text x="720" y="640" text-anchor="middle" font-family="K" font-size="520" letter-spacing="18"
        fill="url(#fill)" stroke="{INK}" stroke-width="34" stroke-linejoin="round" paint-order="stroke">BTA</text>
  <text x="720" y="640" text-anchor="middle" font-family="K" font-size="520" letter-spacing="18"
        fill="none" stroke="#fff" stroke-width="5" stroke-linejoin="round" opacity=".9">BTA</text>
</g>

<!-- the 7 on a roundabout sign -->
<g filter="url(#drop)">
  <circle cx="{SIGN[0]}" cy="{SIGN[1]}" r="{SIGN[2]}" fill="#1F5FC4" stroke="{INK}" stroke-width="26"/>
  <circle cx="{SIGN[0]}" cy="{SIGN[1]}" r="{SIGN[2] - 22}" fill="none" stroke="#fff" stroke-width="10"/>
  {arrows(SIGN[0], SIGN[1], SIGN[2] - 62, width=30)}
  <text x="{SIGN[0] + 6}" y="{SIGN[1] + 138}" text-anchor="middle" font-family="K" font-size="400"
        fill="url(#fill)" stroke="{INK}" stroke-width="26" stroke-linejoin="round" paint-order="stroke">7</text>
</g>

<!-- a camel and a Keter plastic chair on the kerb (the camel walks the skyline) -->
<g transform="translate(150 654) scale(2.3)" fill="#fff" stroke="{INK}" stroke-width="6" stroke-linejoin="round"
   paint-order="stroke">{CHAIR}</g>

<!-- ALMOSH CITY -->
<g filter="url(#drop)" transform="translate(1000 0) skewX(-7) translate(-1000 0)">
  <rect x="610" y="640" width="900" height="150" rx="10" fill="#E23B6E" stroke="{INK}" stroke-width="16"/>
  <text x="1060" y="762" text-anchor="middle" font-family="K" font-size="170" letter-spacing="22" fill="url(#city)">ALMOSH CITY</text>
</g>
<text x="1000" y="905" text-anchor="middle" font-family="Sec" font-size="74" fill="#fff" stroke="{INK}" stroke-width="16"
      stroke-linejoin="round" paint-order="stroke" direction="rtl">אלמוש סיטי  ·  עיר הכיכרות</text>
</svg></body></html>
"""

# The window and taskbar icon: the roundabout sign with the 7, alone.
ICON = f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{{font-family:K;src:url('{FONTS}/Karantina-Bold.ttf')}}
html,body{{margin:0;background:transparent}}
svg{{display:block}}
</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 560 560">
<defs>
  <linearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFF6C9"/><stop offset=".4" stop-color="#FFD35A"/><stop offset=".68" stop-color="#FF8A3A"/><stop offset="1" stop-color="#E23B6E"/>
  </linearGradient>
</defs>
<circle cx="280" cy="280" r="250" fill="#1F5FC4" stroke="{INK}" stroke-width="26"/>
<circle cx="280" cy="280" r="228" fill="none" stroke="#fff" stroke-width="10"/>
{arrows(280, 280, 188, width=30)}
<text x="286" y="418" text-anchor="middle" font-family="K" font-size="400"
      fill="url(#fill)" stroke="{INK}" stroke-width="26" stroke-linejoin="round" paint-order="stroke">7</text>
</svg></body></html>
"""

(HERE / "logo.html").write_text(SVG, encoding="utf-8")
(HERE / "icon.html").write_text(ICON, encoding="utf-8")
print("wrote logo.html and icon.html in", HERE)
