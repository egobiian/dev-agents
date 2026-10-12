#!/usr/bin/env python3
"""Check pixel-art PNG files against a palette and the rules of the medium."""

import argparse
import json
import os
import sys

sys.dont_write_bytecode = True  # leave no __pycache__ in the skill's folder

import pixelkit  # noqa: E402

MAX_LISTED_COLOURS = 8
MAX_LISTED_UNUSED = 16

EPILOG = """\
PATH is a PNG file, or a directory that is searched for PNG files.

Checks, per image:
  palette   every opaque pixel uses a colour of the palette (needs --palette)
  alpha     no pixel is partly transparent (turn off with --allow-alpha)
  scale     the image was not exported enlarged, as blocks of 2x2 or more
            (turn off with --allow-enlarged)
  grid      width and height are multiples of the cell size (needs --grid)
  colours   no more than a number of colours in one image (needs --max-colours)

The last line printed always starts with `audit_sprites:`.

Exit codes:
  0  every image passed
  1  at least one image failed a check
  2  bad arguments, or a file that cannot be read

Examples:
  audit_sprites.py --palette art/palette.hex assets/sprites
  audit_sprites.py --palette art/palette.hex --grid 16 assets/tiles/ground.png
  audit_sprites.py --palette art/palette.hex --preview /tmp/previews assets/sprites/hero.png
"""


def plural(count, noun):
    return "%d %s%s" % (count, noun, "" if count == 1 else "s")


def find_images(paths):
    images = []
    for path in paths:
        if os.path.isdir(path):
            for root, directories, files in os.walk(path):
                directories[:] = sorted(d for d in directories if not d.startswith("."))
                images.extend(os.path.join(root, name) for name in sorted(files) if name.lower().endswith(".png"))
        elif os.path.exists(path):
            images.append(path)
        else:
            raise pixelkit.PixelKitError("%s does not exist." % path)
    if not images:
        raise pixelkit.PixelKitError("no PNG files found in %s." % ", ".join(paths))
    return images


def parse_grid(text):
    parts = text.lower().split("x")
    try:
        numbers = [int(part) for part in parts]
    except ValueError:
        numbers = []
    if len(numbers) not in (1, 2) or min(numbers) < 1:
        raise argparse.ArgumentTypeError("expected a cell size such as 16 or 16x24, and got %r" % text)
    return (numbers[0], numbers[-1])


def export_scale(width, height, pixels):
    """The largest factor k for which the image is made only of uniform k-by-k blocks."""
    for factor in range(min(width, height), 1, -1):
        if width % factor or height % factor:
            continue
        uniform = True
        for block_y in range(0, height, factor):
            for block_x in range(0, width, factor):
                first = pixels[block_y * width + block_x]
                for y in range(block_y, block_y + factor):
                    row = pixels[y * width + block_x : y * width + block_x + factor]
                    if row.count(first) != factor:
                        uniform = False
                        break
                if not uniform:
                    break
            if not uniform:
                break
        if uniform:
            return factor
    return 1


def audit(path, palette, arguments):
    width, height, pixels = pixelkit.read_png(path)
    problems = []
    counts = {}
    first_at = {}
    partial = 0
    for index, (red, green, blue, alpha) in enumerate(pixels):
        if alpha == 0:
            continue
        if alpha < 255:
            partial += 1
        colour = (red, green, blue)
        if colour not in counts:
            counts[colour] = 0
            first_at[colour] = (index % width, index // width)
        counts[colour] += 1

    off_palette = []
    if palette is not None:
        allowed = set(palette)
        strangers = sorted((colour for colour in counts if colour not in allowed), key=lambda colour: -counts[colour])
        for colour in strangers:
            closest, apart = pixelkit.nearest(colour, palette)
            off_palette.append(
                {
                    "hex": pixelkit.to_hex(colour),
                    "pixels": counts[colour],
                    "first_at": list(first_at[colour]),
                    "nearest": pixelkit.to_hex(closest),
                    "distance": round(apart, 1),
                }
            )
        if off_palette:
            problems.append(
                "palette: %s not in the palette, on %s"
                % (plural(len(off_palette), "colour"), plural(sum(entry["pixels"] for entry in off_palette), "pixel"))
            )
    if partial and not arguments.allow_alpha:
        problems.append("alpha: %s partly transparent" % plural(partial, "pixel"))
    factor = 1 if arguments.allow_enlarged or len(counts) < 2 else export_scale(width, height, pixels)
    if factor > 1:
        problems.append(
            "scale: exported enlarged, every art pixel is a %dx%d block. Export at 1x (%dx%d)"
            % (factor, factor, width // factor, height // factor)
        )
    if arguments.grid and (width % arguments.grid[0] or height % arguments.grid[1]):
        problems.append("grid: %dx%d is not a multiple of the %dx%d cell" % (width, height, *arguments.grid))
    if arguments.max_colours is not None and len(counts) > arguments.max_colours:
        problems.append("colours: %s, over the limit of %d" % (plural(len(counts), "colour"), arguments.max_colours))

    return {
        "path": path,
        "width": width,
        "height": height,
        "colours": len(counts),
        "used": set(counts),
        "problems": problems,
        "off_palette": off_palette,
        "pixels": pixels,
    }


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, epilog=EPILOG, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("paths", nargs="+", metavar="PATH", help="PNG files, or directories to search")
    parser.add_argument("--palette", metavar="FILE", help="the palette: .hex, .gpl, .pal, .txt or a palette .png")
    parser.add_argument("--grid", type=parse_grid, metavar="N[xM]", help="cell size the image sizes must be multiples of")
    parser.add_argument("--max-colours", type=int, metavar="N", help="most colours allowed in one image")
    parser.add_argument("--allow-alpha", action="store_true", help="accept partly transparent pixels")
    parser.add_argument("--allow-enlarged", action="store_true", help="skip the scale check, for art made of large flat blocks")
    parser.add_argument("--preview", metavar="DIR", help="also write an enlarged copy of each image to DIR, for looking at")
    parser.add_argument("--scale", type=int, metavar="N", help="enlargement of the previews (default: fit about 768 pixels)")
    parser.add_argument("--background", metavar="HEX", help="colour behind transparent pixels in previews (default: checkerboard)")
    parser.add_argument("--json", action="store_true", help="print the result as JSON")
    arguments = parser.parse_args()

    try:
        palette = None
        if arguments.palette:
            palette = list(dict.fromkeys(pixelkit.read_palette(arguments.palette)))
        background = None
        if arguments.background:
            try:
                background = pixelkit.parse_colour(arguments.background)
            except ValueError as error:
                raise pixelkit.PixelKitError("--background: %s" % error)
        if arguments.scale is not None and arguments.scale < 1:
            raise pixelkit.PixelKitError("--scale must be 1 or more.")
        if arguments.preview and not os.path.isdir(arguments.preview):
            raise pixelkit.PixelKitError("the preview directory %s does not exist. Create it first." % arguments.preview)
        results = [audit(path, palette, arguments) for path in find_images(arguments.paths)]
        previews = []
        if arguments.preview:
            for number, result in enumerate(results):
                name = "%03d_%s" % (number, os.path.basename(result["path"]))
                target = os.path.join(arguments.preview, name)
                used = pixelkit.write_preview(
                    target, result["width"], result["height"], result["pixels"], arguments.scale, background
                )
                previews.append({"path": target, "source": result["path"], "scale": used})
    except pixelkit.PixelKitError as error:
        print("Error: %s" % error, file=sys.stderr)
        return 2

    failed = [result for result in results if result["problems"]]
    unused = []
    if palette is not None:
        used = set().union(*(result["used"] for result in results))
        unused = [pixelkit.to_hex(colour) for colour in palette if colour not in used]

    if arguments.json:
        print(
            json.dumps(
                {
                    "checked": len(results),
                    "failed": len(failed),
                    "images": [
                        {key: result[key] for key in ("path", "width", "height", "colours", "problems", "off_palette")}
                        for result in results
                    ],
                    "unused_palette_colours": unused,
                    "previews": previews,
                },
                indent=2,
            )
        )
    else:
        for result in failed:
            print(
                "FAIL %s (%dx%d, %s)"
                % (result["path"], result["width"], result["height"], plural(result["colours"], "colour"))
            )
            for problem in result["problems"]:
                print("  %s" % problem)
                if not problem.startswith("palette:"):
                    continue
                for entry in result["off_palette"][:MAX_LISTED_COLOURS]:
                    print(
                        "    %s on %s, first at (%d, %d); nearest palette colour %s, %.1f away"
                        % (entry["hex"], plural(entry["pixels"], "pixel"), *entry["first_at"], entry["nearest"], entry["distance"])
                    )
                if len(result["off_palette"]) > MAX_LISTED_COLOURS:
                    print("    ... and %d more colours" % (len(result["off_palette"]) - MAX_LISTED_COLOURS))
        for preview in previews:
            print("preview %s (%dx) of %s" % (preview["path"], preview["scale"], preview["source"]))
        if unused:
            more = "" if len(unused) <= MAX_LISTED_UNUSED else " ... and %d more" % (len(unused) - MAX_LISTED_UNUSED)
            print("%s not used by these images: %s%s" % (plural(len(unused), "palette colour"), " ".join(unused[:MAX_LISTED_UNUSED]), more))
        print("audit_sprites: %s checked, %d failed" % (plural(len(results), "image"), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
