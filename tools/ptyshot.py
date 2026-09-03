#!/usr/bin/env python3
"""Run a command in a pty and print what it drew, as ANSI text for ansi2png.

tools/screenshot uses tmux for this when it is installed. This is the
fallback for a box without it: a pty, a terminal emulator in Python, no root.

    tools/ptyshot.py <cols> <rows> [KEY...] -- <command> [args...]

Keys are sent once the command has had time to draw, with a pause after
each: Tab, Enter, Escape, Up, Down, or any other string typed as is.

Needs pyte (pip install pyte).
"""
import collections
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import termios
import time

try:
    import pyte
    from pyte import graphics as g
except ImportError:
    sys.exit("ptyshot: needs pyte (pip install pyte)")

SETTLE, PAUSE = 2.5, 1.3
KEYS = {"Tab": "\t", "Enter": "\r", "Escape": "\x1b", "Space": " ",
        "Up": "\x1b[A", "Down": "\x1b[B"}
NAMED = {"black": 0, "red": 1, "green": 2, "brown": 3,
         "blue": 4, "magenta": 5, "cyan": 6, "white": 7}

# pyte drops SGR 2 (dim), which hop uses for paths and descriptions. Give
# the cell a dim flag and track that one code ourselves.
BaseChar = pyte.screens.Char
Char = collections.namedtuple("Char", BaseChar._fields + ("dim",))
Char.__new__.__defaults__ = BaseChar.__new__.__defaults__ + (False,)
pyte.screens.Char = Char


class Screen(pyte.Screen):
    saved = None

    # pyte has no alternate screen, so a full-screen fzf would draw over
    # whatever was there. A real terminal starts it on a blank one.
    def set_mode(self, *modes, **kw):
        if kw.get("private") and 1049 in modes:
            self.saved = {y: dict(line) for y, line in self.buffer.items()}
            self.buffer.clear()
        super().set_mode(*modes, **kw)

    def reset_mode(self, *modes, **kw):
        super().reset_mode(*modes, **kw)
        if kw.get("private") and 1049 in modes and self.saved is not None:
            self.buffer.clear()
            for y, line in self.saved.items():
                self.buffer[y].update(line)
            self.saved = None

    def select_graphic_rendition(self, *attrs, **kw):
        super().select_graphic_rendition(*attrs, **kw)
        dim, codes, i = self.cursor.attrs.dim, list(attrs or (0,)), 0
        while i < len(codes):
            a = codes[i]
            if a in (38, 48) and i + 1 < len(codes):   # skip a colour's params
                i += 3 if codes[i + 1] == 5 else 5
                continue
            if a in (0, 22):
                dim = False
            elif a == 2:
                dim = True
            i += 1
        self.cursor.attrs = self.cursor.attrs._replace(dim=dim)


def colour(name, base):
    """SGR parameter for a pyte colour name; base is 30 for fg, 40 for bg."""
    if name == "default":
        return None
    if name in NAMED:
        return str(base + NAMED[name])
    if name.startswith("bright") and name[6:] in NAMED:
        return str(base + 60 + NAMED[name[6:]])
    try:                                   # hex from the 256-colour table
        return "%d;5;%d" % (base + 8, g.FG_BG_256.index(name))
    except ValueError:
        return None


def sgr(c):
    fg, bg = c.fg, c.bg
    if c.reverse:
        fg, bg = (bg if bg != "default" else "black"), (fg if fg != "default" else "white")
    parts = ["0"]
    if c.bold:
        parts.append("1")
    if c.dim:
        parts.append("2")
    for p in (colour(fg, 30), colour(bg, 40)):
        if p:
            parts.append(p)
    return "\033[%sm" % ";".join(parts)


def dump(screen):
    lines = []
    for y in range(screen.lines):
        row = [screen.buffer[y][x] for x in range(screen.columns)]
        end = 0
        for x, c in enumerate(row):
            if c.data.strip() or c.bg != "default" or c.reverse:
                end = x + 1
        out, state = [], None
        for c in row[:end]:
            s = sgr(c)
            if s != state:
                out.append(s)
                state = s
            out.append(c.data)
        if out:
            out.append("\033[0m")
        lines.append("".join(out))
    return "\n".join(lines) + "\n"


def main():
    argv = sys.argv[1:]
    if "--" not in argv or argv.index("--") < 2:
        sys.exit("usage: ptyshot.py <cols> <rows> [KEY...] -- <command> [args...]")
    sep = argv.index("--")
    cols, rows, keys, cmd = int(argv[0]), int(argv[1]), argv[2:sep], argv[sep + 1:]
    size = struct.pack("HHHH", rows, cols, 0, 0)

    pid, fd = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, size)
        os.environ.update(TERM="xterm-256color", LINES=str(rows), COLUMNS=str(cols))
        os.execvp(cmd[0], cmd)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, size)

    screen = Screen(cols, rows)
    stream = pyte.ByteStream(screen)

    def pump(seconds):
        end = time.time() + seconds
        while True:
            left = end - time.time()
            if left <= 0:
                return
            ready, _, _ = select.select([fd], [], [], left)
            if not ready:
                continue
            try:
                data = os.read(fd, 65536)
            except OSError:
                return
            if not data:
                return
            stream.feed(data)

    pump(SETTLE)
    for k in keys:
        os.write(fd, KEYS.get(k, k).encode())
        pump(PAUSE)

    sys.stdout.buffer.write(dump(screen).encode("utf-8"))
    os.close(fd)
    try:
        os.kill(pid, signal.SIGHUP)
        os.waitpid(pid, 0)
    except OSError:
        pass


if __name__ == "__main__":
    main()
