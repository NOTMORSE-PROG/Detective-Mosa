#!/usr/bin/env python3
"""Placeholder art generator (DM-008).

Draws flat, stylised silhouette placeholders in the frozen DESIGN.md §1 palette - never
grey boxes. Visual approach signed off by mosa-art-director (2026-07-29 consult):

  Characters  - a two-shape silhouette (circle head, tapered body), flat `border` fill,
                no outline, no internal detail. `border` (cool navy) was chosen
                deliberately over a warm tone: it reads as a placeholder shape against
                every location's warm gold/amber grade, rather than blending into the
                scene. One fixed canvas for every pose/direction (a placeholder doesn't
                need per-pose tight-cropping the way real art does).
  Backdrops   - content and the near-black foreground framing layer are SEPARATE files.
                This isn't placeholder convenience, it's the correct architecture for the
                real art too: Reference A's four depth layers are genuinely separate
                Parallax2D layers (REFERENCES.md's own Godot recipe), so the framing pass
                can land later as an add-on file instead of a repaint. Framing shapes are
                asymmetric left-to-right on purpose - nothing in Reference A is centred
                or mirrored.
  Evidence/UI - reuses the real chip family (chip-fill/chip-border/chip-radius) exactly,
                since DESIGN.md §1 already defines this component for a different role -
                zero new tokens needed.

One-shot content tool, not a CI-guarded check like check_asset_sizes.py.

Usage: python3 tools/generate_placeholders.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
ART_DIR = REPO_ROOT / "art"

# Verbatim from DESIGN.md §1 at freeze time (DM-007). If this disagrees with that file,
# that file is stale - fix it there, not here.
BORDER = (43, 58, 74)  # #2B3A4A
BG_DEEP = (20, 16, 14)  # #14100E
BG_BASE = (36, 28, 24)  # #241C18
GOLD_DEEP = (185, 118, 33)  # #B97621, the RGB part of gold-deep (used at low alpha below)
CHIP_FILL = (207, 228, 242)  # #CFE4F2
CHIP_BORDER = (43, 58, 74)  # #2B3A4A, same value as `border`
INK = (30, 23, 18)  # #1E1712

CHARACTER_CANVAS = (320, 820)
BACKDROP_CANVAS = (1600, 768)
EVIDENCE_CANVAS = (1024, 1024)

CHIP_RADIUS = 8
CHIP_BORDER_WIDTH = 2


def character_silhouette() -> Image.Image:
    w, h = CHARACTER_CANVAS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    head_r = int(h * 0.12) // 2 * 2  # keep it an even number, cosmetic only
    head_cx = w // 2
    head_top = int(h * 0.02)
    head_cy = head_top + head_r
    draw.ellipse(
        [head_cx - head_r, head_cy - head_r, head_cx + head_r, head_cy + head_r], fill=BORDER
    )

    # Rounded-taper trapezoid: shoulders wider than the base, anchored at the very
    # bottom edge (feet) - matches the bottom-center-of-bounding-box anchor every real
    # delivered sprite already uses (measured directly, not assumed).
    body_top = head_cy + head_r - int(h * 0.015)
    shoulder_w = int(w * 0.62)
    base_w = int(w * 0.46)
    draw.polygon(
        [
            (w // 2 - shoulder_w // 2, body_top),
            (w // 2 + shoulder_w // 2, body_top),
            (w // 2 + base_w // 2, h),
            (w // 2 - base_w // 2, h),
        ],
        fill=BORDER,
    )
    return img


def backdrop_content() -> Image.Image:
    w, h = BACKDROP_CANVAS
    img = Image.new("RGB", (w, h), BG_BASE)
    draw = ImageDraw.Draw(img)
    # A soft, low-opacity gold-deep band across the bottom third hints at a lit ground
    # plane without claiming to be finished art - deliberately understated.
    band_top = int(h * 0.62)
    band = Image.new("RGBA", (w, h - band_top), (0, 0, 0, 0))
    band_draw = ImageDraw.Draw(band)
    for y in range(band.height):
        t = y / band.height
        alpha = int(70 * t)
        band_draw.line([(0, y), (w, y)], fill=(*GOLD_DEEP, alpha))
    img.paste(band, (0, band_top), band)
    return img


def backdrop_framing() -> Image.Image:
    w, h = BACKDROP_CANVAS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Flat near-black shapes at the top and both side edges - the cheapest, highest-
    # impact element in Reference A. Asymmetric on purpose: different heights/widths
    # left vs right, jagged top edge rather than a straight band.
    draw.polygon(
        [(0, 0), (w, 0), (w, int(h * 0.10)), (int(w * 0.6), int(h * 0.16)), (0, int(h * 0.08))],
        fill=BG_DEEP,
    )
    left_w = int(w * 0.09)
    draw.polygon([(0, 0), (left_w, 0), (0, int(h * 0.55))], fill=BG_DEEP)
    right_w = int(w * 0.13)
    draw.polygon([(w, 0), (w - right_w, 0), (w, int(h * 0.75))], fill=BG_DEEP)
    return img


def evidence_placeholder() -> Image.Image:
    w, h = EVIDENCE_CANVAS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    margin = int(w * 0.08)
    draw.rounded_rectangle(
        [margin, margin, w - margin, h - margin],
        radius=CHIP_RADIUS * (w // 256),  # scaled up from the 8px UI-scale token
        fill=CHIP_FILL,
        outline=CHIP_BORDER,
        width=CHIP_BORDER_WIDTH * (w // 256),
    )
    # A generic centred glyph (a simple document/question mark shape) in `ink` - enough
    # to read as "evidence card", not enough to imply specific mini-game content.
    cx, cy = w // 2, h // 2
    r = int(w * 0.1)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK, width=CHIP_BORDER_WIDTH * (w // 256))
    return img


GENERATORS = {
    "character": character_silhouette,
    "backdrop_content": backdrop_content,
    "backdrop_framing": backdrop_framing,
    "evidence": evidence_placeholder,
}


def generate(rel_path: str, kind: str) -> None:
    if kind not in GENERATORS:
        raise ValueError(f"unknown placeholder kind '{kind}', choices: {list(GENERATORS)}")
    out_path = ART_DIR / rel_path
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img = GENERATORS[kind]()
    img.save(out_path)
    print(f"  {rel_path}  ({img.size[0]}x{img.size[1]}, {kind})")


if __name__ == "__main__":
    print(
        "This module is a library of placeholder generators (character/backdrop_content/"
        "backdrop_framing/evidence). The actual slot list - which files, at which paths -"
        " is driven by art/ASSET_SPEC.md and applied by tools/apply_placeholders.py, not "
        "hardcoded here."
    )
