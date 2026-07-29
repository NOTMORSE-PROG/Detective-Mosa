#!/usr/bin/env python3
"""Colourblind distinguishability check for DESIGN.md §1's state tokens (DM-007).

DESIGN.md §0.7 requires shape/icon on top of colour for every state pair (Trust,
Lives) — this script is the "verify with a simulator, not by eye" half of that rule.
`context/DESIGN.md` names Color Oracle (a free desktop app) as the reference tool; this
is not that tool, but the same class of approximation it and most browser-based
simulators (e.g. Coblis) use — a linear RGB transform applied directly in sRGB space,
not the more rigorous Brettel/Machado LMS model. Good enough to catch a real confusion,
which is the actual bar: DESIGN.md's own rule is "no state pair becomes
indistinguishable", not "publication-grade simulation".

Usage: python3 tools/check_colorblind.py
Writes: tickets/M1-design-system/evidence/dm007-colourblind-trust.png
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_contrast import PALETTE, composite_over  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
EVIDENCE_PATH = REPO_ROOT / "tickets" / "M1-design-system" / "evidence" / "dm007-colourblind-trust.png"

# Widely-used approximation matrices (Coblis-derived; see this file's docstring for the
# accuracy caveat). Applied directly to sRGB 0-1 values, matching how the reference
# class of tool actually works in practice.
MATRICES: dict[str, tuple[tuple[float, float, float], ...]] = {
    "protanopia": ((0.567, 0.433, 0.000), (0.558, 0.442, 0.000), (0.000, 0.242, 0.758)),
    "deuteranopia": ((0.625, 0.375, 0.000), (0.700, 0.300, 0.000), (0.000, 0.300, 0.700)),
    "tritanopia": ((0.950, 0.050, 0.000), (0.000, 0.433, 0.567), (0.000, 0.475, 0.525)),
}

# The state groups DESIGN.md §0.7 actually requires to stay distinguishable from each
# other (never across unrelated groups - Trust vs Lives are never compared side by side
# in the UI, so confusability between them isn't the risk being tested here).
STATE_GROUPS: dict[str, dict[str, str]] = {
    "Trust": {
        "Trusted": PALETTE["trust-trusted"],
        "Uncertain": PALETTE["trust-uncertain"],
        "Doubted": PALETTE["trust-doubted"],
    },
    "Lives": {
        "Full": PALETTE["lives-full"],
        "Spent (on bg-deep)": composite_over(PALETTE["lives-spent"], 0.65, PALETTE["bg-deep"]),
    },
}

DISTANCE_WARN_THRESHOLD = 40.0  # Euclidean, 0-255 per channel - see docstring


def _hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    hex_color = hex_color.lstrip("#")
    return int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)


def simulate(rgb: tuple[int, int, int], matrix: tuple[tuple[float, float, float], ...]) -> tuple[int, int, int]:
    r, g, b = (c / 255.0 for c in rgb)
    out = []
    for row in matrix:
        val = row[0] * r + row[1] * g + row[2] * b
        out.append(round(max(0.0, min(1.0, val)) * 255))
    return tuple(out)  # type: ignore[return-value]


def euclidean(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def render_swatch_sheet(groups: dict[str, dict[str, tuple[int, int, int]]]) -> None:
    views = ["normal", "protanopia", "deuteranopia", "tritanopia"]
    cell_w, cell_h = 220, 90
    label_col_w = 180
    header_h = 40
    rows = sum(len(states) for states in STATE_GROUPS.values()) + len(STATE_GROUPS)

    img = Image.new("RGB", (label_col_w + cell_w * len(views), header_h + cell_h * rows), "white")
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()

    for col, view in enumerate(views):
        draw.text((label_col_w + col * cell_w + 10, 10), view, fill="black", font=font)

    y = header_h
    for group_name, states in STATE_GROUPS.items():
        draw.text((10, y + 30), f"[{group_name}]", fill="black", font=font)
        y += cell_h
        for state_name, base_hex in states.items():
            base_rgb = _hex_to_rgb(base_hex)
            draw.text((10, y + 35), state_name, fill="black", font=font)
            for col, view in enumerate(views):
                rgb = base_rgb if view == "normal" else simulate(base_rgb, MATRICES[view])
                x0 = label_col_w + col * cell_w
                draw.rectangle([x0, y, x0 + cell_w - 4, y + cell_h - 4], fill=rgb, outline="black")
            y += cell_h

    EVIDENCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    img.save(EVIDENCE_PATH)
    print(f"Swatch sheet written to {EVIDENCE_PATH.relative_to(REPO_ROOT)}")


def main() -> int:
    problems: list[str] = []
    rendered: dict[str, dict[str, tuple[int, int, int]]] = {}

    for group_name, states in STATE_GROUPS.items():
        rendered[group_name] = {name: _hex_to_rgb(h) for name, h in states.items()}
        for view_name, matrix in MATRICES.items():
            simulated = {name: simulate(_hex_to_rgb(h), matrix) for name, h in states.items()}
            names = list(simulated.keys())
            print(f"-- {group_name} under {view_name} --")
            for name in names:
                print(f"    {name:<24}{states[name]} -> {simulated[name]}")
            for i in range(len(names)):
                for j in range(i + 1, len(names)):
                    dist = euclidean(simulated[names[i]], simulated[names[j]])
                    flag = "" if dist >= DISTANCE_WARN_THRESHOLD else "  <-- TOO CLOSE"
                    print(f"    distance({names[i]}, {names[j]}) = {dist:.1f}{flag}")
                    if dist < DISTANCE_WARN_THRESHOLD:
                        problems.append(
                            f"{group_name}/{view_name}: {names[i]} vs {names[j]} = {dist:.1f} "
                            f"(< {DISTANCE_WARN_THRESHOLD})"
                        )

    render_swatch_sheet(rendered)

    print()
    if problems:
        print(f"{len(problems)} potentially indistinguishable pair(s) under simulation:")
        for p in problems:
            print(f"  - {p}")
        print(
            "\nDESIGN.md §0.7 requires shape/icon differentiation for exactly this "
            "reason - colour alone is not enough for these pairs. Confirm the shape/icon "
            "pairing in DESIGN.md §1's state tables covers every flagged pair."
        )
        return 1
    print("All state pairs remain distinguishable by colour alone under every simulation.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
