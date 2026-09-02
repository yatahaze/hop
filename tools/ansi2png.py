#!/usr/bin/env python3
"""Render a captured terminal screen (with ANSI colour) to a PNG.

Reads the output of `tmux capture-pane -pe` on stdin or from a file, so what
lands in the image is what the terminal actually drew, not an approximation.

    tmux capture-pane -pet <session> | tools/ansi2png.py out.png

Needs Pillow. Any DejaVu Sans Mono on the system will do; see FONT_CANDIDATES.
"""
import re
import subprocess
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("ansi2png: needs Pillow (pip install pillow)")

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono{}.ttf",       # Debian, Ubuntu
    "/usr/share/fonts/dejavu/DejaVuSansMono{}.ttf",                # Fedora, openSUSE
    "/usr/share/fonts/TTF/DejaVuSansMono{}.ttf",                   # Arch
    "/usr/share/fonts/texlive-dejavu/DejaVuSansMono{}.ttf",        # texlive
    "/Library/Fonts/DejaVuSansMono{}.ttf",                         # macOS
]
SIZE, PAD, LEAD = 15, 18, 4
BG, FG = (24, 24, 27), (212, 212, 216)

# Raw xterm blue is (0,0,238), which is unreadable on a dark ground, so the
# base 16 use a conventional dark-terminal palette instead.
BASE16 = [
    (60, 60, 66), (224, 108, 117), (152, 195, 121), (229, 192, 123),
    (97, 175, 239), (198, 120, 221), (86, 182, 194), (200, 200, 205),
    (110, 110, 118), (240, 140, 148), (180, 215, 155), (240, 215, 160),
    (140, 200, 245), (220, 160, 235), (130, 205, 215), (245, 245, 248),
]
ANSI = re.compile(r"\033\[([0-9;]*)m")


def find_font(bold=False):
    suffix = "-Bold" if bold else ""
    for pattern in FONT_CANDIDATES:
        path = pattern.format(suffix)
        try:
            return ImageFont.truetype(path, SIZE)
        except OSError:
            continue
    try:  # last resort: ask fontconfig for anything monospace
        path = subprocess.check_output(
            ["fc-match", "-f", "%{file}", "DejaVu Sans Mono:bold" if bold else "DejaVu Sans Mono"],
            stderr=subprocess.DEVNULL,
        ).decode().strip()
        return ImageFont.truetype(path, SIZE)
    except Exception:
        sys.exit("ansi2png: no DejaVu Sans Mono found; install fonts-dejavu or edit FONT_CANDIDATES")


def xterm(n):
    if n < 16:
        return BASE16[n]
    if n < 232:
        n -= 16
        steps = [0, 95, 135, 175, 215, 255]
        return (steps[n // 36], steps[(n // 6) % 6], steps[n % 6])
    v = 8 + (n - 232) * 10
    return (v, v, v)


def cells(line):
    """[(char, fg, bold, bg)] for one line, honouring its SGR codes."""
    out, i = [], 0
    fg, bold, dim, bg = FG, False, False, None

    def emit(text):
        colour = tuple(int(c * 0.55) for c in fg) if dim else fg
        out.extend((ch, colour, bold, bg) for ch in text)

    for m in ANSI.finditer(line):
        emit(line[i:m.start()])
        i = m.end()
        parts = [p for p in m.group(1).split(";") if p != ""] or ["0"]
        k = 0
        while k < len(parts):
            p = int(parts[k])
            if p == 0:
                fg, bold, dim, bg = FG, False, False, None
            elif p == 1:
                bold = True
            elif p == 2:
                dim = True
            elif p == 22:
                bold = dim = False
            elif p == 39:
                fg = FG
            elif p == 49:
                bg = None
            elif 30 <= p <= 37:
                fg = xterm(p - 30)
            elif 90 <= p <= 97:
                fg = xterm(p - 90 + 8)
            elif 40 <= p <= 47:
                bg = xterm(p - 40)
            elif p in (38, 48) and k + 2 < len(parts) and parts[k + 1] == "5":
                colour = xterm(int(parts[k + 2]))
                fg, bg = (colour, bg) if p == 38 else (fg, colour)
                k += 2
            k += 1
    emit(line[i:])
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: ansi2png.py <out.png> [capture.ansi]")
    out_path = sys.argv[1]
    src = open(sys.argv[2], encoding="utf-8") if len(sys.argv) > 2 else sys.stdin

    raw = [l.rstrip("\n") for l in src]
    while raw and not ANSI.sub("", raw[-1]).strip():   # drop trailing blank rows
        raw.pop()
    if not raw:
        sys.exit("ansi2png: nothing captured")
    rows = [cells(l) for l in raw]

    font, font_bold = find_font(), find_font(bold=True)
    cw = font.getbbox("M")[2] - font.getbbox("M")[0]
    ch = SIZE + LEAD
    cols = max(len(r) for r in rows)

    img = Image.new("RGB", (cols * cw + PAD * 2, len(rows) * ch + PAD * 2), BG)
    draw = ImageDraw.Draw(img)
    for y, row in enumerate(rows):
        for x, (c, colour, bold, bg) in enumerate(row):
            px, py = PAD + x * cw, PAD + y * ch
            if bg:
                draw.rectangle([px, py, px + cw, py + ch], fill=bg)
            if c != " ":
                draw.text((px, py), c, font=(font_bold if bold else font), fill=colour)
    img.save(out_path)
    print("%s  %dx%d  %d cols x %d rows" % (out_path, img.width, img.height, cols, len(rows)))


if __name__ == "__main__":
    main()
