#!/usr/bin/env python3
"""WCAG contrast check for the DESIGN.md §1 token set (DM-007).

Runs the real formula (WCAG 2.x relative luminance + contrast ratio), not eyeballed —
ClientHub's own token freeze found two real failures only because it ran the formula in
a script (see this ticket's Edge cases). Every text/icon-on-background pair that could
plausibly appear in the shipped UI is listed explicitly in PAIRS below; nothing is
inferred or guessed.

Usage: python3 tools/check_contrast.py
"""

from __future__ import annotations

import sys

# Verbatim from DESIGN.md §1 at freeze time. If a value here disagrees with that file,
# that file is stale — fix it there, not here.
#
# gold-ink, and the trust-*/lives-spent values, were corrected during this freeze
# (mosa-ui-designer consult, 2026-07-29) — see DESIGN.md §5's change log for the full
# reasoning. Two structural findings from that pass, worth keeping in this comment
# because they explain why some pairs below use a 3.0 target instead of 4.5:
#   1. No single hex can satisfy 4.5:1 against both `surface` and `bg-deep` at once -
#      surface:bg-deep is only 15.10:1, and bridging both at 4.5:1 would require ~20.25:1.
#      Proven, not assumed: L(surface)=0.78820, L(bg-deep)=0.00551; passing bg-deep at
#      4.5:1 needs fg L >= 0.19980, passing surface at 4.5:1 needs fg L <= 0.13627 -
#      disjoint ranges.
#   2. Trust/Lives states are bare icon glyphs (cracked/half/filled bubble shapes,
#      DESIGN.md §0.7), not running text - WCAG's own applicability puts icon-only state
#      indicators under 1.4.11 (Non-text Contrast, 3:1), not 1.4.3 (Text, 4.5:1). Their
#      on-surface reading still uses 4.5:1 deliberately (a plate context reads closer to
#      text), but their bare on-bg-deep reading uses the correct 3:1 bar.
PALETTE: dict[str, str] = {
    "bg-deep": "#14100E",
    "bg-base": "#241C18",
    "surface": "#F2E4CE",
    "surface-alt": "#E3D0B4",
    "border": "#2B3A4A",
    "ink": "#1E1712",
    "ink-soft": "#5A4B3E",
    "gold": "#E8A33D",
    "gold-ink": "#895910",
    "sky": "#8FB8D6",
    "chip-fill": "#CFE4F2",
    "chip-border": "#2B3A4A",
    "chip-ink": "#16222E",
    "trust-trusted": "#3E6D41",
    "trust-uncertain": "#895910",
    "trust-doubted": "#A34734",
    "lives-full": "#F2E4CE",
    "lives-spent": "#A6917E",
}

# (foreground, background, context, required ratio). Required ratio follows WCAG AA:
# 4.5:1 for normal text/icons, 3:1 for large text (dialogue heading-scale, >=18pt
# equivalent) per DESIGN.md §1's size table, and 3:1 for the bare-icon-on-scene rows per
# WCAG 1.4.11 (see the PALETTE comment above). Every pair a token could realistically sit
# on is listed, even ones DESIGN.md doesn't pin down yet (e.g. which backdrop the HUD
# sits on) - the result is what tells DM-027/DM-021 which backing is safe to use, not
# the other way around.
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


def _hex_to_rgb01(hex_color: str) -> tuple[float, float, float]:
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    return r, g, b


def _rgb01_to_hex(rgb: tuple[float, float, float]) -> str:
    return "#" + "".join(f"{round(c * 255):02X}" for c in rgb)


def composite_over(fg_hex: str, alpha: float, bg_hex: str) -> str:
    # Standard "over" alpha compositing in sRGB space - Color(r, g, b, alpha) drawn
    # straight onto bg_hex, which is how DESIGN.md's "40% opacity" outline actually
    # renders. Composited *then* measured, never the solid fg colour alone - the whole
    # point of testing lives-spent is that opacity lowers effective contrast.
    fg = _hex_to_rgb01(fg_hex)
    bg = _hex_to_rgb01(bg_hex)
    blended = tuple(alpha * f + (1 - alpha) * b for f, b in zip(fg, bg))
    return _rgb01_to_hex(blended)


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
    # Derived, not a DESIGN.md token in its own right: the actual pixels the "spent"
    # bubble puts on screen once its 65% opacity is composited over the frame behind it.
    # Opacity moved from the original 40% during this freeze - see the change log;
    # neither the hex nor the opacity alone could reach 3:1, only both together.
    PALETTE["lives-spent-65"] = composite_over(PALETTE["lives-spent"], 0.65, PALETTE["bg-deep"])

    failures: list[tuple[str, str, str, float, float]] = []
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
