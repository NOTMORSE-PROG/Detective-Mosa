#!/usr/bin/env python3
"""WCAG contrast check for the DESIGN.md §1 token set (DM-007).

Runs the real formula (WCAG 2.x relative luminance + contrast ratio), not eyeballed —
ClientHub's own token freeze found two real failures only because it ran the formula in
a script (see this ticket's Edge cases). Every text/icon-on-background pair that could
plausibly appear in the shipped UI is listed explicitly in PAIRS below; nothing is
inferred or guessed.

Token values are never copied into this file. This script's ONLY source of truth is
`data/palette.tres` itself — parsed directly below. An earlier version hardcoded a
snapshot of the palette and kept measuring it after the real tokens were retoned; it
printed "All 17 pairs pass" against values that no longer existed anywhere in the
project (DM-066). A copy of the truth cannot be kept in sync by discipline, so there is
deliberately no copy here to fall out of sync.

Usage: python3 tools/check_contrast.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PALETTE_TRES = REPO_ROOT / "data" / "palette.tres"

# Matches a Godot Resource field assignment of the form `field_name = Color(r, g, b[, a])`
# — this is exactly how palette.tres serializes every token (never as `#RRGGBB`), and it
# is the same constructor form the token guard in check_quality.py had to learn to see.
_NUM = r"[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?"
_COLOR_FIELD_RE = re.compile(
    rf"^(\w+)\s*=\s*Color\(\s*({_NUM})\s*,\s*({_NUM})\s*,\s*({_NUM})\s*(?:,\s*({_NUM})\s*)?\)"
)


def _rgb01_to_hex(r: float, g: float, b: float, a: float = 1.0) -> str:
    hex_code = "#" + "".join(f"{round(c * 255):02X}" for c in (r, g, b))
    if a < 1.0:
        hex_code += f"{round(a * 255):02X}"
    return hex_code


def load_palette(path: Path = PALETTE_TRES) -> dict[str, str]:
    """Parse every `field = Color(...)` line out of palette.tres's [resource] block.

    Field names are snake_case (Godot @export vars); tokens elsewhere in this project
    (DESIGN.md, PAIRS below) are kebab-case, so `bg_deep` becomes `bg-deep` — a
    mechanical rename, not a second naming scheme to maintain.

    Fails loudly and refuses to run rather than falling back to any default table: a
    guard that reports green on an unreadable palette is the exact defect this file
    exists to close (DM-066's edge case note).
    """
    if not path.exists():
        raise FileNotFoundError(f"palette source not found: {path}")
    text = path.read_text(encoding="utf-8")
    if "[resource]" not in text:
        raise ValueError(f"{path}: no [resource] section — not a valid Palette .tres")
    resource_body = text.split("[resource]", 1)[1]

    palette: dict[str, str] = {}
    for line in resource_body.splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            break  # end of [resource] — a later sub-resource section isn't ours
        match = _COLOR_FIELD_RE.match(stripped)
        if match is None:
            continue
        field, r, g, b, a = match.groups()
        token = field.replace("_", "-")
        palette[token] = _rgb01_to_hex(
            float(r), float(g), float(b), float(a) if a is not None else 1.0
        )

    if not palette:
        raise ValueError(
            f"{path}: parsed zero Color(...) fields — the parser or the file is broken"
        )
    return palette


def composite_over(fg_hex: str, alpha: float, bg_hex: str) -> str:
    # Standard "over" alpha compositing in sRGB space - Color(r, g, b, alpha) drawn
    # straight onto bg_hex, which is how DESIGN.md's "40% opacity" outline actually
    # renders. Composited *then* measured, never the solid fg colour alone - the whole
    # point of testing lives-spent is that opacity lowers effective contrast.
    fg = _hex_to_rgb01(fg_hex)
    bg = _hex_to_rgb01(bg_hex)
    blended = tuple(alpha * f + (1 - alpha) * b for f, b in zip(fg, bg))
    return _rgb01_to_hex(*blended)


def _hex_to_rgb01(hex_color: str) -> tuple[float, float, float]:
    hex_color = hex_color.lstrip("#")[:6]
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    return r, g, b


# Loaded at import time, deliberately: tools/check_colorblind.py imports PALETTE and
# composite_over from this module and expects a populated, real palette to already be
# there. If palette.tres cannot be parsed, importing this module fails loudly instead of
# silently handing out an empty or stale table.
PALETTE: dict[str, str] = load_palette()

# Derived, not a DESIGN.md token in its own right: the actual pixels the "spent" bubble
# puts on screen once its 65% opacity is composited over the frame behind it. Neither the
# hex nor the opacity alone could reach 3:1, only both together.
PALETTE["lives-spent-65"] = composite_over(PALETTE["lives-spent"], 0.65, PALETTE["bg-deep"])

# (foreground, background, context, required ratio). Required ratio follows WCAG AA:
# 4.5:1 for normal text/icons, 3:1 for large text (dialogue heading-scale, >=18pt
# equivalent) per DESIGN.md §1's size table, and 3:1 for the bare-icon-on-scene rows per
# WCAG 1.4.11 — icon-only state indicators (Trust/Lives bubble glyphs, DESIGN.md §0.7)
# fall under 1.4.11 (Non-text Contrast), not 1.4.3 (Text, 4.5:1). Every pair a token
# could realistically sit on is listed, even ones DESIGN.md doesn't pin down yet (e.g.
# which backdrop the HUD sits on) - the result is what tells DM-027/DM-021 which backing
# is safe to use, not the other way around.
PAIRS: list[tuple[str, str, str, float]] = [
    ("ink", "surface", "dialogue/body text on the plate", 4.5),
    ("ink-soft", "surface", "secondary/meta text on the plate", 4.5),
    ("ink", "surface-alt", "body text on the pressed-state plate", 4.5),
    ("chip-ink", "chip-fill", "nameplate/dialogue/choice family (Reference B)", 4.5),
    ("gold-ink", "surface", "gold accent text/icon on the cream plate", 4.5),
    ("gold", "bg-deep", "gold accent (heading/focal) on the deep frame", 3.0),
    ("gold", "bg-base", "gold accent on the scene-void background", 3.0),
    ("surface", "bg-deep", "cream heading text directly on the deep frame", 3.0),
    ("surface", "bg-base", "cream heading text on the scene-void background", 3.0),
    ("trust-trusted", "surface", "Trust \"Trusted\" icon/text on a plate", 4.5),
    ("trust-uncertain", "surface", "Trust \"Uncertain\" icon/text on a plate", 4.5),
    ("trust-doubted", "surface", "Trust \"Doubted\" icon/text on a plate", 4.5),
    ("trust-trusted", "bg-deep", "Trust \"Trusted\" bare icon on the deep HUD frame (WCAG 1.4.11)", 3.0),
    ("trust-uncertain", "bg-deep", "Trust \"Uncertain\" bare icon on the deep HUD frame (WCAG 1.4.11)", 3.0),
    ("trust-doubted", "bg-deep", "Trust \"Doubted\" bare icon on the deep HUD frame (WCAG 1.4.11)", 3.0),
    ("lives-full", "bg-deep", "Lives full-bubble on the deep HUD frame", 4.5),
    ("lives-spent-65", "bg-deep", "Lives spent-bubble (65% opacity, composited, WCAG 1.4.11)", 3.0),
]


def _linearize(channel: float) -> float:
    # WCAG 2.x's own normative threshold (0.03928), not the more precise 0.04045 IEC
    # value - the spec itself notes the difference is insignificant at 8-bit precision,
    # and this project wants a number it can cite against the WCAG text directly.
    if channel <= 0.03928:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_color: str) -> float:
    r, g, b = (_linearize(c) for c in _hex_to_rgb01(hex_color))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(hex_a: str, hex_b: str) -> float:
    l_a = relative_luminance(hex_a)
    l_b = relative_luminance(hex_b)
    lighter, darker = max(l_a, l_b), min(l_a, l_b)
    return (lighter + 0.05) / (darker + 0.05)


def main() -> int:
    missing = [name for fg, bg, _, _ in PAIRS for name in (fg, bg) if name not in PALETTE]
    if missing:
        print(
            f"FATAL: {sorted(set(missing))} referenced in PAIRS but not found in "
            f"{PALETTE_TRES.relative_to(REPO_ROOT)} — a token was renamed/removed and this "
            "script's PAIRS table wasn't updated, or the parser missed a field.",
            file=sys.stderr,
        )
        return 2

    failures: list[tuple[str, str, str, float, float]] = []
    print(f"Tokens read live from {PALETTE_TRES.relative_to(REPO_ROOT)}\n")
    print(f"{'Foreground':<18}{'Background':<14}{'Ratio':>8}{'Target':>8}  Context")
    print("-" * 90)
    for fg_name, bg_name, context, required in PAIRS:
        ratio = contrast_ratio(PALETTE[fg_name], PALETTE[bg_name])
        status = "PASS" if ratio >= required else "FAIL"
        print(
            f"{fg_name:<18}{bg_name:<14}{ratio:>7.2f}:1{required:>6.1f}:1  {context}  [{status}]"
        )
        if ratio < required:
            failures.append((fg_name, bg_name, context, ratio, required))

    print()
    if failures:
        print(f"{len(failures)} pair(s) FAILED WCAG AA:")
        for fg_name, bg_name, context, ratio, required in failures:
            print(f"  - {fg_name} on {bg_name} ({context}): {ratio:.2f}:1, needs {required:.1f}:1")
        return 1
    print(f"All {len(PAIRS)} pairs pass their WCAG AA target.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
