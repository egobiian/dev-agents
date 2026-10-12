#!/usr/bin/env python3
"""Turn a text grid into a pixel-art PNG, and a PNG back into a text grid."""

import argparse
import os
import sys

sys.dont_write_bytecode = True  # leave no __pycache__ in the skill's folder

import pixelkit  # noqa: E402

KEY_CHARACTERS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
EXTRA_CHARACTERS = "!?*+=%&$~^"
TRANSPARENT = "."

EPILOG = """\
Commands:
  render   text grid -> PNG, one frame after another on a sheet
  dump     PNG -> text grid, to read or edit existing art as text
  preview  PNG -> enlarged PNG, for looking at

The text grid format:

  // A comment. Comments are allowed before the first frame only.
  @palette ../palette.hex
  @key
  . transparent
  1 #1a1c2c
  2 #f4b41b
  @frame idle
  ..1111..
  .122221.
  .122221.
  ..1111..
  @frame blink
  ...

  @palette  optional. A palette file, relative to the grid file. Every colour
            in the key must then be in it.
  @key      one line per character: the character, a space, then a colour as
            #rrggbb, or the word transparent.
  @frame    starts a frame; the name is optional. Each line that follows is one
            row of pixels, one character per pixel. All frames share one size.

Exit codes:
  0  done
  1  the grid or the image has a problem, and nothing was written
  2  bad arguments, or a file that cannot be read

Examples:
  sprite_grid.py render coin.grid.txt --out assets/coin.png --preview /tmp/coin_preview.png
  sprite_grid.py dump assets/hero.png --frame 16x16 --palette art/palette.hex --out hero.grid.txt
  sprite_grid.py preview assets/hero.png --out /tmp/hero_preview.png --background 3b5dc9
"""


class GridError(Exception):
    """A problem in the content of a grid or an image, with where it is."""


def parse_size(text):
    parts = text.lower().split("x")
    try:
        numbers = [int(part) for part in parts]
    except ValueError:
        numbers = []
    if len(numbers) != 2 or min(numbers) < 1:
        raise argparse.ArgumentTypeError("expected a size such as 16x16, and got %r" % text)
    return tuple(numbers)


def parse_grid(path):
    """Read a grid file. Returns (palette path or None, key, frames)."""
    try:
        with open(path, "r", encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError as error:
        raise pixelkit.PixelKitError("cannot read %s: %s" % (path, error.strerror))

    palette_path = None
    key = {}
    frames = []
    section = None
    for number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        if line.startswith("@"):
            directive, _space, rest = line.partition(" ")
            rest = rest.strip()
            if directive == "@palette":
                if not rest:
                    raise GridError("line %d: @palette needs the path of a palette file." % number)
                palette_path = os.path.join(os.path.dirname(os.path.abspath(path)), rest)
            elif directive == "@key":
                section = "key"
            elif directive == "@frame":
                section = "frame"
                frames.append({"name": rest or str(len(frames)), "rows": [], "line": number})
            else:
                raise GridError("line %d: unknown directive %s. Known: @palette, @key, @frame." % (number, directive))
        elif section == "frame":
            frames[-1]["rows"].append((number, line.rstrip()))
        elif line.startswith("//"):
            continue
        elif section == "key":
            character = line[0]
            value = line[1:].split()
            if character in "@ \t" or len(line) < 3 or line[1] not in " \t" or not value:
                raise GridError(
                    "line %d: a key line is one character, a space, then #rrggbb or transparent, such as: 1 #1a1c2c"
                    % number
                )
            if character in key:
                raise GridError("line %d: the character %r is already in the key." % (number, character))
            if value[0] == "transparent":
                key[character] = None
            else:
                try:
                    key[character] = pixelkit.parse_colour(value[0])
                except ValueError as error:
                    raise GridError("line %d: %s" % (number, error))
        else:
            raise GridError("line %d: expected @palette, @key or @frame before any content." % number)

    if not key:
        raise GridError("the grid has no @key section.")
    if not frames:
        raise GridError("the grid has no @frame section.")
    return palette_path, key, frames


def render(arguments):
    palette_path, key, frames = parse_grid(arguments.grid)
    if arguments.palette:
        palette_path = arguments.palette
    if palette_path:
        allowed = set(pixelkit.read_palette(palette_path))
        strangers = [
            "%r %s" % (character, pixelkit.to_hex(colour))
            for character, colour in key.items()
            if colour is not None and colour not in allowed
        ]
        if strangers:
            raise GridError("the key holds colours that are not in the palette %s: %s" % (palette_path, ", ".join(strangers)))

    width = len(frames[0]["rows"][0][1]) if frames[0]["rows"] else 0
    height = len(frames[0]["rows"])
    if not width:
        raise GridError("line %d: the frame %s has no rows." % (frames[0]["line"], frames[0]["name"]))
    usage = dict.fromkeys(key, 0)
    for frame in frames:
        if len(frame["rows"]) != height:
            raise GridError(
                "line %d: the frame %s has %d rows, and the first frame has %d. All frames share one size."
                % (frame["line"], frame["name"], len(frame["rows"]), height)
            )
        for number, row in frame["rows"]:
            if len(row) != width:
                raise GridError("line %d: the row is %d characters wide, expected %d." % (number, len(row), width))
            for column, character in enumerate(row):
                if character not in key:
                    raise GridError(
                        "line %d, column %d: the character %r is not in the key." % (number, column + 1, character)
                    )
                usage[character] += 1

    columns = arguments.columns or len(frames)
    rows = (len(frames) + columns - 1) // columns
    sheet_width = width * columns
    sheet_height = height * rows
    pixels = [(0, 0, 0, 0)] * (sheet_width * sheet_height)
    for index, frame in enumerate(frames):
        left = (index % columns) * width
        top = (index // columns) * height
        for y, (_number, row) in enumerate(frame["rows"]):
            for x, character in enumerate(row):
                colour = key[character]
                if colour is not None:
                    pixels[(top + y) * sheet_width + left + x] = colour + (255,)

    pixelkit.write_png(arguments.out, sheet_width, sheet_height, pixels)
    print(
        "wrote %s: %d frame%s of %dx%d on a %dx%d sheet"
        % (arguments.out, len(frames), "" if len(frames) == 1 else "s", width, height, sheet_width, sheet_height)
    )
    for character, colour in key.items():
        name = "transparent" if colour is None else pixelkit.to_hex(colour)
        print("  %s %-11s %5d pixels%s" % (character, name, usage[character], "" if usage[character] else "  (never used)"))
    if arguments.preview:
        background = parse_background(arguments.background)
        scale = pixelkit.write_preview(arguments.preview, sheet_width, sheet_height, pixels, arguments.scale, background)
        print("wrote %s: the same sheet enlarged %dx, for looking at" % (arguments.preview, scale))


def dump(arguments):
    width, height, pixels = pixelkit.read_png(arguments.image)
    frame_width, frame_height = arguments.frame or (width, height)
    if width % frame_width or height % frame_height:
        raise GridError("the image is %dx%d, which is not a multiple of the %dx%d frame." % (width, height, frame_width, frame_height))
    partial = sum(1 for pixel in pixels if 0 < pixel[3] < 255)
    if partial:
        raise GridError(
            "the image has partly transparent pixels (%d). A text grid holds only opaque and fully transparent ones."
            % partial
        )

    palette = list(dict.fromkeys(pixelkit.read_palette(arguments.palette))) if arguments.palette else []
    used = list(dict.fromkeys(pixel[:3] for pixel in pixels if pixel[3]))
    strangers = [colour for colour in used if colour not in palette] if palette else []
    ordered = (palette if palette else used) + strangers
    if len(palette or used) > len(KEY_CHARACTERS) or len(strangers) > len(EXTRA_CHARACTERS):
        raise GridError(
            "too many colours for a text grid: %d in the image%s. This is not palette-limited pixel art."
            % (len(used), ", %d of them outside the palette" % len(strangers) if palette else "")
        )
    characters = {}
    for index, colour in enumerate(palette if palette else used):
        characters[colour] = KEY_CHARACTERS[index]
    for index, colour in enumerate(strangers):
        characters[colour] = EXTRA_CHARACTERS[index]

    lines = []
    if arguments.palette:
        lines.append("// Characters follow the order of the palette %s." % arguments.palette)
    lines.append("@key")
    lines.append("%s transparent" % TRANSPARENT)
    for colour in ordered:
        if colour in used:
            note = "  not in the palette" if colour in strangers else ""
            lines.append("%s %s%s" % (characters[colour], pixelkit.to_hex(colour), note))
    count = 0
    for top in range(0, height, frame_height):
        for left in range(0, width, frame_width):
            lines.append("@frame %d" % count)
            count += 1
            for y in range(top, top + frame_height):
                row = pixels[y * width + left : y * width + left + frame_width]
                lines.append("".join(characters[pixel[:3]] if pixel[3] else TRANSPARENT for pixel in row))
    text = "\n".join(lines) + "\n"

    if arguments.out:
        with open(arguments.out, "w", encoding="utf-8") as handle:
            handle.write(text)
        print("wrote %s: %d frame%s of %dx%d, %d colours" % (arguments.out, count, "" if count == 1 else "s", frame_width, frame_height, len(used)))
    else:
        sys.stdout.write(text)
    if strangers:
        print(
            "warning: %d colours are not in the palette: %s"
            % (len(strangers), " ".join(pixelkit.to_hex(colour) for colour in strangers)),
            file=sys.stderr,
        )


def preview(arguments):
    width, height, pixels = pixelkit.read_png(arguments.image)
    scale = pixelkit.write_preview(arguments.out, width, height, pixels, arguments.scale, parse_background(arguments.background))
    print("wrote %s: %s enlarged %dx (%dx%d art pixels)" % (arguments.out, arguments.image, scale, width, height))


def parse_background(text):
    if not text:
        return None
    try:
        return pixelkit.parse_colour(text)
    except ValueError as error:
        raise pixelkit.PixelKitError("--background: %s" % error)


def add_preview_options(parser):
    parser.add_argument("--scale", type=int, metavar="N", help="enlargement (default: fit about 768 pixels)")
    parser.add_argument("--background", metavar="HEX", help="colour behind transparent pixels (default: checkerboard)")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, epilog=EPILOG, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    commands = parser.add_subparsers(dest="command", metavar="COMMAND")

    render_parser = commands.add_parser("render", help="text grid -> PNG")
    render_parser.add_argument("grid", metavar="GRID", help="the text grid file")
    render_parser.add_argument("--out", required=True, metavar="PNG", help="the PNG to write, at 1x")
    render_parser.add_argument("--columns", type=int, metavar="N", help="frames per row of the sheet (default: all in one row)")
    render_parser.add_argument("--palette", metavar="FILE", help="palette the key must stay inside (overrides @palette)")
    render_parser.add_argument("--preview", metavar="PNG", help="also write an enlarged copy, for looking at")
    add_preview_options(render_parser)

    dump_parser = commands.add_parser("dump", help="PNG -> text grid")
    dump_parser.add_argument("image", metavar="PNG", help="the image to read")
    dump_parser.add_argument("--frame", type=parse_size, metavar="WxH", help="split a sheet into frames of this size")
    dump_parser.add_argument("--palette", metavar="FILE", help="name the characters after this palette's order")
    dump_parser.add_argument("--out", metavar="FILE", help="write the grid to FILE (default: standard output)")

    preview_parser = commands.add_parser("preview", help="PNG -> enlarged PNG")
    preview_parser.add_argument("image", metavar="PNG", help="the image to enlarge")
    preview_parser.add_argument("--out", required=True, metavar="PNG", help="the enlarged PNG to write")
    add_preview_options(preview_parser)

    arguments = parser.parse_args()
    if not arguments.command:
        parser.print_usage(sys.stderr)
        print("Error: give a command: render, dump or preview.", file=sys.stderr)
        return 2
    if getattr(arguments, "scale", None) is not None and arguments.scale < 1:
        print("Error: --scale must be 1 or more.", file=sys.stderr)
        return 2
    if getattr(arguments, "columns", None) is not None and arguments.columns < 1:
        print("Error: --columns must be 1 or more.", file=sys.stderr)
        return 2

    try:
        {"render": render, "dump": dump, "preview": preview}[arguments.command](arguments)
    except GridError as error:
        print("Error: %s" % error, file=sys.stderr)
        return 1
    except pixelkit.PixelKitError as error:
        print("Error: %s" % error, file=sys.stderr)
        return 2
    except OSError as error:
        print("Error: %s: %s" % (error.filename, error.strerror), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
