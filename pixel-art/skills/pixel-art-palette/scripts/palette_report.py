#!/usr/bin/env python3
"""Measure a pixel-art palette: its colours, duplicates, lightness spread and ramps."""

import argparse
import json
import os
import sys

sys.dont_write_bytecode = True  # leave no __pycache__ in the skill's folder

import pixelkit  # noqa: E402

# Upper bounds of each family on the OKLCH hue wheel, in degrees.
HUE_NAMES = (
    (8, "pink"),
    (35, "red"),
    (75, "orange"),
    (120, "yellow"),
    (170, "green"),
    (225, "cyan"),
    (285, "blue"),
    (335, "purple"),
    (360, "pink"),
)
NEUTRAL_CHROMA = 2.0
SWATCH_CELL = 24
SWATCH_COLUMNS = 8
SWATCH_MARGIN = 8
SWATCH_BACKGROUND = (128, 128, 128, 255)

EPILOG = """\
SOURCE is one palette file (.hex, .gpl, .pal, .txt or a palette .png), or any
number of PNG images and directories, whose colours are pooled into a palette.

Columns: L is lightness from 0 (black) to 100 (white), C is chroma (0 is grey),
h is the hue angle in degrees. Distances are perceptual: about 2 is the smallest
difference an eye notices side by side.

Exit codes:
  0  no problem found
  1  duplicates, near-duplicates or a ramp problem were found
  2  bad arguments, or a file that cannot be read

Examples:
  palette_report.py art/palette.hex
  palette_report.py art/palette.hex --ramp 1a1c2c,5d275d,b13e53,ef7d57,ffcd75
  palette_report.py assets/sprites --write-hex art/palette.hex
  palette_report.py art/palette.hex --swatch /tmp/palette.png
"""


def hue_name(chroma, hue):
    if chroma < NEUTRAL_CHROMA:
        return "neutral"
    for limit, name in HUE_NAMES:
        if hue < limit:
            return name
    return "pink"


def collect(sources):
    """Return (colours in order, pixel counts or None)."""
    images = []
    for source in sources:
        if os.path.isdir(source):
            for root, directories, files in os.walk(source):
                directories[:] = sorted(d for d in directories if not d.startswith("."))
                images.extend(os.path.join(root, name) for name in sorted(files) if name.lower().endswith(".png"))
        elif not os.path.exists(source):
            raise pixelkit.PixelKitError("%s does not exist." % source)
        elif len(sources) == 1:
            return pixelkit.read_palette(source), None
        elif source.lower().endswith(".png"):
            images.append(source)
        else:
            raise pixelkit.PixelKitError(
                "%s: give one palette file, or PNG images and directories to pool, not both." % source
            )
    if not images:
        raise pixelkit.PixelKitError("no PNG images found in %s." % ", ".join(sources))
    counts = {}
    for image in images:
        _width, _height, pixels = pixelkit.read_png(image)
        for red, green, blue, alpha in pixels:
            if alpha:
                counts[(red, green, blue)] = counts.get((red, green, blue), 0) + 1
    if not counts:
        raise pixelkit.PixelKitError("the images hold no opaque pixels.")
    colours = sorted(counts, key=lambda colour: pixelkit.lch(colour)[0])
    return colours, counts


def analyse_ramp(text, palette, min_step):
    try:
        colours = [pixelkit.parse_colour(part) for part in text.split(",") if part.strip()]
    except ValueError as error:
        raise pixelkit.PixelKitError("--ramp %s: %s" % (text, error))
    if len(colours) < 2:
        raise pixelkit.PixelKitError("--ramp %s: a ramp needs at least two colours, dark to light." % text)
    problems = []
    notes = []
    for colour in colours:
        if colour not in palette:
            problems.append("%s is not in the palette" % pixelkit.to_hex(colour))
    steps = []
    hue_travel = 0.0
    for first, second in zip(colours, colours[1:]):
        l1, c1, h1 = pixelkit.lch(first)
        l2, c2, h2 = pixelkit.lch(second)
        turn = (h2 - h1 + 180) % 360 - 180 if min(c1, c2) >= NEUTRAL_CHROMA else 0.0
        hue_travel += turn
        steps.append(
            {
                "from": pixelkit.to_hex(first),
                "to": pixelkit.to_hex(second),
                "lightness": round(l2 - l1, 1),
                "chroma": round(c2 - c1, 1),
                "hue": round(turn, 1),
                "distance": round(pixelkit.distance(first, second), 1),
            }
        )
        if l2 - l1 <= 0:
            problems.append("lightness does not rise from %s to %s" % (pixelkit.to_hex(first), pixelkit.to_hex(second)))
        elif l2 - l1 < min_step:
            problems.append(
                "%s and %s are %.1f apart in lightness, under the minimum step of %.1f"
                % (pixelkit.to_hex(first), pixelkit.to_hex(second), l2 - l1, min_step)
            )
    rises = [step["lightness"] for step in steps if step["lightness"] > 0]
    if len(rises) > 1 and max(rises) > 3 * min(rises):
        notes.append("uneven steps: the largest lightness step is %.1f times the smallest" % (max(rises) / min(rises)))
    chromatic = [colour for colour in colours if pixelkit.lch(colour)[1] >= NEUTRAL_CHROMA]
    if len(chromatic) >= 3 and abs(hue_travel) < 5:
        notes.append("straight ramp: the hue barely moves from dark to light")
    return {
        "colours": [pixelkit.to_hex(colour) for colour in colours],
        "steps": steps,
        "hue_travel": round(hue_travel, 1),
        "problems": problems,
        "notes": notes,
    }


def write_swatch(path, colours, ramps):
    """Draw the palette as blocks on mid grey: eight per row, then one row per ramp."""
    rows = [colours[i : i + SWATCH_COLUMNS] for i in range(0, len(colours), SWATCH_COLUMNS)]
    rows.extend([pixelkit.parse_colour(text) for text in ramp["colours"]] for ramp in ramps)
    width = max(len(row) for row in rows) * SWATCH_CELL + 2 * SWATCH_MARGIN
    height = len(rows) * SWATCH_CELL + (len(ramps) + 2) * SWATCH_MARGIN
    pixels = [SWATCH_BACKGROUND] * (width * height)
    top = SWATCH_MARGIN
    for number, row in enumerate(rows):
        if number >= len(rows) - len(ramps):
            top += SWATCH_MARGIN  # ramps stand apart from the palette and from each other
        for column, colour in enumerate(row):
            left = SWATCH_MARGIN + column * SWATCH_CELL
            for y in range(top, top + SWATCH_CELL):
                start = y * width + left
                pixels[start : start + SWATCH_CELL] = [tuple(colour) + (255,)] * SWATCH_CELL
        top += SWATCH_CELL
    pixelkit.write_png(path, width, height, pixels)


def build_report(colours, counts, ramps, near, min_step):
    entries = []
    for index, colour in enumerate(colours):
        lightness, chroma, hue = pixelkit.lch(colour)
        entry = {
            "index": index,
            "hex": pixelkit.to_hex(colour),
            "lightness": round(lightness, 1),
            "chroma": round(chroma, 1),
            "hue": round(hue) if chroma >= NEUTRAL_CHROMA else None,
            "family": hue_name(chroma, hue),
        }
        if counts is not None:
            entry["pixels"] = counts[colour]
        entries.append(entry)

    duplicates = []
    first_seen = {}
    for index, colour in enumerate(colours):
        if colour in first_seen:
            duplicates.append({"hex": pixelkit.to_hex(colour), "entries": [first_seen[colour], index]})
        else:
            first_seen[colour] = index
    unique = list(first_seen)

    close = []
    for i, first in enumerate(unique):
        for second in unique[i + 1 :]:
            apart = pixelkit.distance(first, second)
            if apart < near:
                close.append({"first": pixelkit.to_hex(first), "second": pixelkit.to_hex(second), "distance": round(apart, 1)})
    close.sort(key=lambda pair: pair["distance"])

    by_lightness = sorted(unique, key=lambda colour: pixelkit.lch(colour)[0])
    gap = {"size": 0.0, "from": None, "to": None}
    for first, second in zip(by_lightness, by_lightness[1:]):
        size = pixelkit.lch(second)[0] - pixelkit.lch(first)[0]
        if size > gap["size"]:
            gap = {"size": round(size, 1), "from": pixelkit.to_hex(first), "to": pixelkit.to_hex(second)}

    families = {}
    for entry in entries:
        families[entry["family"]] = families.get(entry["family"], 0) + 1

    ramp_reports = [analyse_ramp(text, set(unique), min_step) for text in ramps]
    return {
        "count": len(unique),
        "colours": entries,
        "duplicates": duplicates,
        "near_duplicates": close,
        "near_threshold": near,
        "lightness": {
            "darkest": pixelkit.to_hex(by_lightness[0]),
            "darkest_value": round(pixelkit.lch(by_lightness[0])[0], 1),
            "lightest": pixelkit.to_hex(by_lightness[-1]),
            "lightest_value": round(pixelkit.lch(by_lightness[-1])[0], 1),
            "largest_gap": gap,
        },
        "families": families,
        "ramps": ramp_reports,
        "problems": len(duplicates) + len(close) + sum(len(ramp["problems"]) for ramp in ramp_reports),
    }


def print_report(report, has_counts):
    print("%d colours" % report["count"])
    header = "  #   hex       L      C     h   family"
    print(header + ("    pixels" if has_counts else ""))
    for entry in report["colours"]:
        hue = "%3d" % entry["hue"] if entry["hue"] is not None else "  -"
        line = "%3d  %s  %5.1f  %5.1f  %s   %-7s" % (
            entry["index"],
            entry["hex"],
            entry["lightness"],
            entry["chroma"],
            hue,
            entry["family"],
        )
        if has_counts:
            line += "  %7d" % entry["pixels"]
        print(line.rstrip())

    for duplicate in report["duplicates"]:
        print("DUPLICATE %s is listed twice, at entries %d and %d" % (duplicate["hex"], *duplicate["entries"]))
    for pair in report["near_duplicates"]:
        print(
            "NEAR %s and %s are %.1f apart, under %.1f: on screen they read as one colour"
            % (pair["first"], pair["second"], pair["distance"], report["near_threshold"])
        )

    light = report["lightness"]
    print(
        "lightness: %s at %.1f to %s at %.1f; largest gap %.1f, between %s and %s"
        % (
            light["darkest"],
            light["darkest_value"],
            light["lightest"],
            light["lightest_value"],
            light["largest_gap"]["size"],
            light["largest_gap"]["from"],
            light["largest_gap"]["to"],
        )
    )
    print("families: " + ", ".join("%s %d" % item for item in sorted(report["families"].items(), key=lambda item: -item[1])))

    for number, ramp in enumerate(report["ramps"], start=1):
        print("ramp %d: %s (hue travels %+.1f degrees)" % (number, " > ".join(ramp["colours"]), ramp["hue_travel"]))
        for step in ramp["steps"]:
            print(
                "  %s > %s  lightness %+5.1f  chroma %+5.1f  hue %+6.1f  distance %5.1f"
                % (step["from"], step["to"], step["lightness"], step["chroma"], step["hue"], step["distance"])
            )
        for problem in ramp["problems"]:
            print("  PROBLEM %s" % problem)
        for note in ramp["notes"]:
            print("  note: %s" % note)

    print(
        "palette_report: %d colours, %d duplicates, %d near-duplicate pairs, %d ramp problems"
        % (
            report["count"],
            len(report["duplicates"]),
            len(report["near_duplicates"]),
            sum(len(ramp["problems"]) for ramp in report["ramps"]),
        )
    )


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, epilog=EPILOG, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("source", nargs="+", metavar="SOURCE", help="a palette file, or PNG images and directories")
    parser.add_argument(
        "--ramp",
        action="append",
        default=[],
        metavar="COLOURS",
        help="a ramp to measure: hex colours from dark to light, separated by commas. Repeatable",
    )
    parser.add_argument(
        "--near",
        type=float,
        default=3.0,
        metavar="N",
        help="report two colours closer than this as near-duplicates (default: 3.0)",
    )
    parser.add_argument(
        "--min-step",
        type=float,
        default=4.0,
        metavar="N",
        help="smallest lightness step allowed between neighbours in a ramp (default: 4.0)",
    )
    parser.add_argument("--write-hex", metavar="FILE", help="also write the colours to FILE, one hex value per line")
    parser.add_argument(
        "--swatch", metavar="PNG", help="also draw the palette to PNG, for looking at: the colours, then each ramp"
    )
    parser.add_argument("--json", action="store_true", help="print the report as JSON")
    arguments = parser.parse_args()

    try:
        colours, counts = collect(arguments.source)
        report = build_report(colours, counts, arguments.ramp, arguments.near, arguments.min_step)
        unique = list(dict.fromkeys(colours))
        if arguments.write_hex:
            with open(arguments.write_hex, "w", encoding="utf-8") as handle:
                handle.write("".join(pixelkit.to_hex(colour)[1:] + "\n" for colour in unique))
        if arguments.swatch:
            write_swatch(arguments.swatch, unique, report["ramps"])
    except pixelkit.PixelKitError as error:
        print("Error: %s" % error, file=sys.stderr)
        return 2
    except OSError as error:
        print("Error: cannot write %s: %s" % (error.filename, error.strerror), file=sys.stderr)
        return 2

    if arguments.json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report, counts is not None)
    return 1 if report["problems"] else 0


if __name__ == "__main__":
    sys.exit(main())
