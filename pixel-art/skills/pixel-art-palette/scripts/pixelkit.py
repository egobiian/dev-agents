"""Shared helpers for the pixel-art skills.

PNG reading and writing, palette files, colour distance and enlarged previews,
with the standard library only.

Every pixel-art skill that has scripts carries an identical copy of this file,
so that each skill still works when it is copied on its own.
"""

import math
import os
import struct
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


class PixelKitError(Exception):
    """A problem with an input file, worded for whoever has to fix it."""


# --- PNG ---------------------------------------------------------------------


def _unfilter(raw, height, stride, bpp):
    """Undo PNG scanline filtering. Returns the image bytes without filter bytes."""
    out = bytearray(height * stride)
    previous = bytearray(stride)
    position = 0
    for y in range(height):
        kind = raw[position]
        line = bytearray(raw[position + 1 : position + 1 + stride])
        position += 1 + stride
        if kind == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif kind == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif kind == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif kind == 4:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                up = previous[i]
                up_left = previous[i - bpp] if i >= bpp else 0
                estimate = left + up - up_left
                distance_left = abs(estimate - left)
                distance_up = abs(estimate - up)
                distance_up_left = abs(estimate - up_left)
                if distance_left <= distance_up and distance_left <= distance_up_left:
                    predictor = left
                elif distance_up <= distance_up_left:
                    predictor = up
                else:
                    predictor = up_left
                line[i] = (line[i] + predictor) & 0xFF
        elif kind != 0:
            raise PixelKitError("corrupt PNG: unknown filter type %d on row %d" % (kind, y))
        out[y * stride : (y + 1) * stride] = line
        previous = line
    return out


def _samples(data, width, height, stride, channels, depth):
    """Yield one tuple of raw sample values per pixel, row by row."""
    if depth == 8:
        for y in range(height):
            row = data[y * stride : y * stride + width * channels]
            for x in range(width):
                yield tuple(row[x * channels : (x + 1) * channels])
    elif depth == 16:
        for y in range(height):
            row = data[y * stride : y * stride + width * channels * 2]
            for x in range(width):
                yield struct.unpack(
                    ">%dH" % channels, bytes(row[x * channels * 2 : (x + 1) * channels * 2])
                )
    else:
        mask = (1 << depth) - 1
        for y in range(height):
            row = data[y * stride : (y + 1) * stride]
            for x in range(width):
                bit = x * depth
                shift = 8 - depth - (bit % 8)
                yield ((row[bit // 8] >> shift) & mask,)


def read_png(path):
    """Read a PNG file. Returns (width, height, pixels).

    `pixels` is a flat, row-by-row list of (r, g, b, a) tuples with 8-bit values.
    """
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except OSError as error:
        raise PixelKitError("cannot read %s: %s" % (path, error.strerror))
    if data[:8] != PNG_SIGNATURE:
        raise PixelKitError("%s is not a PNG file. Export the art as PNG first." % path)

    header = None
    palette = None
    transparency = None
    compressed = bytearray()
    position = 8
    while position + 8 <= len(data):
        length, tag = struct.unpack(">I4s", data[position : position + 8])
        body = data[position + 8 : position + 8 + length]
        position += 12 + length
        if tag == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif tag == b"PLTE":
            palette = [tuple(body[i : i + 3]) for i in range(0, len(body) - 2, 3)]
        elif tag == b"tRNS":
            transparency = body
        elif tag == b"IDAT":
            compressed.extend(body)
        elif tag == b"IEND":
            break
    if header is None or not compressed:
        raise PixelKitError("%s is not a complete PNG file." % path)

    width, height, depth, colour_type, _compression, _filter, interlace = header
    if interlace:
        raise PixelKitError(
            "%s is an interlaced PNG, which is not supported. Export it again without interlacing."
            % path
        )
    if colour_type not in CHANNELS:
        raise PixelKitError("%s has an unknown PNG colour type (%d)." % (path, colour_type))
    channels = CHANNELS[colour_type]
    stride = (width * channels * depth + 7) // 8
    bpp = max(1, channels * depth // 8)
    try:
        raw = zlib.decompress(bytes(compressed))
    except zlib.error:
        raise PixelKitError("%s is corrupt: its image data cannot be decompressed." % path)
    if len(raw) < height * (stride + 1):
        raise PixelKitError("%s is corrupt: its image data is shorter than its size says." % path)
    image = _unfilter(raw, height, stride, bpp)

    maximum = (1 << depth) - 1
    transparent_sample = None
    if transparency is not None and colour_type == 0 and len(transparency) >= 2:
        transparent_sample = struct.unpack(">H", transparency[:2])
    elif transparency is not None and colour_type == 2 and len(transparency) >= 6:
        transparent_sample = struct.unpack(">HHH", transparency[:6])

    def to_byte(value):
        return value if depth == 8 else value * 255 // maximum

    pixels = []
    for sample in _samples(image, width, height, stride, channels, depth):
        if colour_type == 3:
            index = sample[0]
            if palette is None or index >= len(palette):
                raise PixelKitError("%s is corrupt: a pixel uses a palette entry that does not exist." % path)
            red, green, blue = palette[index]
            alpha = transparency[index] if transparency is not None and index < len(transparency) else 255
        elif colour_type == 0:
            red = green = blue = to_byte(sample[0])
            alpha = 0 if sample == transparent_sample else 255
        elif colour_type == 2:
            red, green, blue = (to_byte(value) for value in sample)
            alpha = 0 if sample == transparent_sample else 255
        elif colour_type == 4:
            red = green = blue = to_byte(sample[0])
            alpha = to_byte(sample[1])
        else:
            red, green, blue, alpha = (to_byte(value) for value in sample)
        pixels.append((red, green, blue, alpha))
    return width, height, pixels


def write_png(path, width, height, pixels):
    """Write a flat list of (r, g, b, a) tuples as an 8-bit RGBA PNG."""
    if len(pixels) != width * height:
        raise PixelKitError("internal error: %d pixels for a %dx%d image" % (len(pixels), width, height))
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for pixel in pixels[y * width : (y + 1) * width]:
            raw.extend(pixel)

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    directory = os.path.dirname(path)
    if directory and not os.path.isdir(directory):
        raise PixelKitError("the directory %s does not exist. Create it first." % directory)
    with open(path, "wb") as handle:
        handle.write(PNG_SIGNATURE)
        handle.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        handle.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        handle.write(chunk(b"IEND", b""))


# --- colours and palettes ----------------------------------------------------


def parse_colour(text):
    """Parse 'rrggbb' or '#rrggbb'. Returns (r, g, b)."""
    value = text.strip().lstrip("#")
    if len(value) != 6:
        raise ValueError("expected six hex digits, such as 1a1c2c or #1a1c2c, and got %r" % text)
    try:
        return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))
    except ValueError:
        raise ValueError("expected six hex digits, such as 1a1c2c or #1a1c2c, and got %r" % text)


def to_hex(colour):
    return "#%02x%02x%02x" % tuple(colour[:3])


def read_palette(path):
    """Read a palette file. Returns the colours in file order, duplicates included.

    Formats: .hex (one colour per line), .gpl (GIMP), .pal (JASC), .txt (Paint.NET)
    and .png (every opaque colour of the image, in reading order).
    """
    extension = os.path.splitext(path)[1].lower()
    if extension == ".png":
        _width, _height, pixels = read_png(path)
        colours = []
        seen = set()
        for red, green, blue, alpha in pixels:
            if alpha and (red, green, blue) not in seen:
                seen.add((red, green, blue))
                colours.append((red, green, blue))
        if not colours:
            raise PixelKitError("%s has no opaque pixels, so it holds no palette." % path)
        return colours
    try:
        with open(path, "r", encoding="utf-8-sig") as handle:
            lines = handle.read().splitlines()
    except UnicodeDecodeError:
        raise PixelKitError(
            "%s is not a text palette. Supported formats: .hex, .gpl, .pal (JASC), .txt (Paint.NET), .png." % path
        )
    except OSError as error:
        raise PixelKitError("cannot read %s: %s" % (path, error.strerror))

    colours = []
    first = lines[0].strip() if lines else ""
    if first == "GIMP Palette" or first == "JASC-PAL":
        # Both list colours as three decimal numbers per line.
        for number, line in enumerate(lines[1:], start=2):
            fields = line.split()
            if len(fields) >= 3 and all(field.isdigit() for field in fields[:3]):
                red, green, blue = (int(field) for field in fields[:3])
                if max(red, green, blue) > 255:
                    raise PixelKitError("%s line %d: a colour value above 255." % (path, number))
                colours.append((red, green, blue))
    else:
        for number, line in enumerate(lines, start=1):
            token = line.strip()
            if not token or token.startswith(";") or token.startswith("//"):
                continue
            token = token.split()[0].lstrip("#")
            if extension == ".txt" and len(token) == 8:
                token = token[2:]  # Paint.NET writes AARRGGBB.
            try:
                colours.append(parse_colour(token))
            except ValueError as error:
                raise PixelKitError("%s line %d: %s" % (path, number, error))
    if not colours:
        raise PixelKitError("%s holds no colours." % path)
    return colours


def _linear(channel):
    value = channel / 255.0
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def oklab(colour):
    """Convert an sRGB colour to OKLab. Lightness runs from 0 to 1."""
    red, green, blue = (_linear(channel) for channel in colour[:3])
    long = (0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue) ** (1 / 3)
    medium = (0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue) ** (1 / 3)
    short = (0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue) ** (1 / 3)
    return (
        0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short,
        1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short,
        0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short,
    )


def lch(colour):
    """Lightness (0-100), chroma (0 to about 40) and hue (degrees) of an sRGB colour."""
    lightness, a, b = oklab(colour)
    return lightness * 100, math.hypot(a, b) * 100, math.degrees(math.atan2(b, a)) % 360


def distance(first, second):
    """Perceptual distance between two sRGB colours. About 2 is just noticeable."""
    one = oklab(first)
    two = oklab(second)
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(one, two))) * 100


def nearest(colour, palette):
    """The palette colour closest to `colour`, and its distance."""
    best = min(palette, key=lambda candidate: distance(colour, candidate))
    return best, distance(colour, best)


# --- previews ----------------------------------------------------------------


def default_scale(width, height):
    """A whole factor that brings the longer side to roughly 768 pixels."""
    return max(1, min(32, 768 // max(width, height, 1)))


def write_preview(path, width, height, pixels, scale=None, background=None):
    """Write an enlarged copy for looking at, with hard edges. Returns the scale used.

    Transparent pixels show a grey checkerboard with one check per art pixel,
    or `background` when a colour is given.
    """
    if scale is None:
        scale = default_scale(width, height)
    out = []
    for y in range(height):
        row = []
        for x in range(width):
            red, green, blue, alpha = pixels[y * width + x]
            if background is not None:
                behind = background
            else:
                behind = (0x99, 0x99, 0x99) if (x + y) % 2 == 0 else (0x77, 0x77, 0x77)
            if alpha == 255:
                shown = (red, green, blue, 255)
            else:
                shown = tuple((c * alpha + b * (255 - alpha)) // 255 for c, b in zip((red, green, blue), behind)) + (255,)
            row.extend([shown] * scale)
        for _ in range(scale):
            out.extend(row)
    write_png(path, width * scale, height * scale, out)
    return scale
