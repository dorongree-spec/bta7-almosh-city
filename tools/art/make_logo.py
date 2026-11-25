"""Writes logo.html and icon.html: the "BTA 7 Almosh City" mark as a neon shop sign.

Original artwork. The name is drawn the way a Beer Sheva kiosk would put it
over the door: pink tubes for BTA, a yellow 7, "Almosh City" in blue script,
and the opening hours underneath.

    python3 tools/art/make_logo.py
    node tools/art/render.js tools/art/logo.html assets/art/logo.png 2000 1000 transparent
    node tools/art/render.js tools/art/icon.html assets/art/icon.png 256 256 transparent
    node tools/art/render.js tools/art/banner.html assets/art/banner.jpg 1640 720

Fonts (all SIL Open Font Licence): Monoton and Pacifico in tools/art/fonts,
Secular One in assets/fonts. See assets/CREDITS.md.
"""
from pathlib import Path

HERE = Path(__file__).parent

FONT_FACES = """
@font-face{font-family:Monoton;src:url('fonts/Monoton-Regular.ttf')}
@font-face{font-family:Pacifico;src:url('fonts/Pacifico-Regular.ttf')}
@font-face{font-family:Secular;src:url('../../assets/fonts/SecularOne-Regular.ttf')}
"""


def glow(core: str, near: str, far: str, reach: float = 1.0) -> str:
    """The text-shadow of a lit tube: a white core, then two halos of its colour."""
    return (f"0 0 {6 * reach:.0f}px {core},0 0 {20 * reach:.0f}px {near},"
            f"0 0 {50 * reach:.0f}px {near},0 0 {110 * reach:.0f}px {far}")


PINK = glow("#fff", "#ff3fa4", "#ff2e7e")
YELLOW = glow("#fff", "#ffc93c", "#ff7a1a")
BLUE = glow("#fff", "#31e6ff", "#1290ff", 0.9)

LOGO = f"""<!doctype html><html><head><meta charset="utf-8"><style>
{FONT_FACES}
html,body{{margin:0;width:2000px;height:1000px;background:transparent;overflow:hidden}}
.sign{{position:absolute;left:230px;top:170px;transform:rotate(-4deg)}}
.bta{{font-family:Monoton;font-size:440px;line-height:1;color:#fff;letter-spacing:10px;white-space:nowrap;text-shadow:{PINK}}}
.bta i{{font-style:normal;color:#fffbe0;text-shadow:{YELLOW}}}
.city{{font-family:Pacifico;font-size:186px;line-height:1;color:#e9ffff;margin:-70px 0 0 430px;white-space:nowrap;text-shadow:{BLUE}}}
.hours{{font-family:Secular;font-size:74px;color:#fff;direction:rtl;text-align:left;margin:44px 0 0 250px;white-space:nowrap;
  text-shadow:{glow("#fff", "#ff3fa4", "#ff2e7e", 0.7)}}}
</style></head><body>
<div class="sign">
  <div class="bta">BTA<i> 7</i></div>
  <div class="city">Almosh City</div>
  <div class="hours">פתוח 24/7 · חוץ משבת, חגים ואזעקות</div>
</div>
</body></html>
"""

# The window and taskbar icon: the same tubes, B and 7, on the night-purple of the title screen.
ICON = f"""<!doctype html><html><head><meta charset="utf-8"><style>
{FONT_FACES}
html,body{{margin:0;width:256px;height:256px;background:transparent;overflow:hidden}}
.tile{{position:absolute;inset:6px;border-radius:44px;background:radial-gradient(circle at 50% 40%,#2a0f4a,#0d0420 75%);
  box-shadow:inset 0 0 0 4px #ff3fa4, inset 0 0 26px #ff2e7e}}
.b7{{position:absolute;left:0;right:0;top:50px;text-align:center;font-family:Monoton;font-size:128px;line-height:1;color:#fff;
  letter-spacing:2px;text-shadow:{glow("#fff", "#ff3fa4", "#ff2e7e", 0.45)}}}
.b7 i{{font-style:normal;color:#fffbe0;text-shadow:{glow("#fff", "#ffc93c", "#ff7a1a", 0.45)}}}
</style></head><body><div class="tile"></div><div class="b7">B<i>7</i></div></body></html>
"""

# The banner for the README: the sign over the kiosk poster, since neon needs the dark.
BANNER = """<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;width:1640px;height:720px;overflow:hidden;background:#0d0420}
.bg{position:absolute;inset:0;background:url('../../assets/art/poster_chairs.jpg') center 62%/cover;filter:brightness(.75)}
.shade{position:absolute;inset:0;background:linear-gradient(180deg,rgba(8,4,24,.8) 0%,rgba(8,4,24,.2) 55%,rgba(8,4,24,.75) 100%)}
img{position:absolute;left:330px;top:40px;width:1080px}
</style></head><body><div class="bg"></div><div class="shade"></div><img src="../../assets/art/logo.png"></body></html>
"""

(HERE / "logo.html").write_text(LOGO, encoding="utf-8")
(HERE / "banner.html").write_text(BANNER, encoding="utf-8")
(HERE / "icon.html").write_text(ICON, encoding="utf-8")
print("wrote logo.html, icon.html and banner.html in", HERE)
