#!/usr/bin/env python3
"""Write a page to listen to candidate sounds side by side in the browser.

    python3 scripts/review_page.py <page.html> --group "Door knock (pick one)" <file> <file> --group "Footstep" <file> ...

Each row shows the file's name, length, seed and prompt, read from the sidecar
JSON the generator writes beside each file (<file>.json, or <name>.wav.json
for a track encoded from a WAV) when there is one. Keep the page next to the
files, outside the repository: it links them by relative path.
"""

import html
import json
import os
import sys

import soundfile as sf

STYLE = ("body{background:#18181b;color:#d4d4d8;font-family:system-ui;margin:24px}h1,h2{color:#fafafa}"
         "td{padding:8px 12px;border-bottom:1px solid #3f3f46;vertical-align:middle}audio{width:320px}")


def sidecar(path: str) -> dict:
    stem, _ = os.path.splitext(path)
    for candidate in (path + ".json", stem + ".wav.json"):
        if os.path.exists(candidate):
            with open(candidate, encoding="utf-8") as file:
                return json.load(file)
    return {}


def main() -> None:
    if len(sys.argv) < 4 or sys.argv[2] != "--group":
        sys.exit(__doc__)
    page = sys.argv[1]
    base = os.path.dirname(os.path.abspath(page))
    body = []
    rows_open = False
    args = iter(sys.argv[2:])
    for arg in args:
        if arg == "--group":
            if rows_open:
                body.append("</table>")
            body.append(f"<h2>{html.escape(next(args))}</h2><table>")
            rows_open = True
            continue
        meta = sidecar(arg)
        seconds = sf.info(arg).duration
        seed = f", seed {meta['seed']}" if "seed" in meta else ""
        source = os.path.relpath(os.path.abspath(arg), base)
        name = os.path.splitext(os.path.basename(arg))[0]
        body.append(f"<tr><td><b>{html.escape(name)}</b><br><small>{seconds:.2f} s{seed}</small></td>"
                    f"<td><audio controls preload='none' src='{html.escape(source)}'></audio></td>"
                    f"<td><small>{html.escape(meta.get('prompt', ''))}</small></td></tr>")
    if rows_open:
        body.append("</table>")
    with open(page, "w", encoding="utf-8") as file:
        file.write(f"<!doctype html><html lang='en'><head><meta charset='utf-8'><title>Sound review</title>"
                   f"<style>{STYLE}</style></head><body><h1>Sound review</h1>{''.join(body)}</body></html>")
    print(page)


if __name__ == "__main__":
    main()
