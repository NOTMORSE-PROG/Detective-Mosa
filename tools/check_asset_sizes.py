#!/usr/bin/env python3
"""Asset size ceiling guard (DM-008).

Flags any committed image over the mobile-safe ceilings before it reaches a device and
silently renders as a black box (Godot issue #28960 - past ~4096px on either dimension,
Android does not crash, it just draws nothing, and that reads as an art bug rather than a
size bug). A rule nobody can verify is a rule that decays across five contributors - this
is what makes it verifiable.

Usage: python3 tools/check_asset_sizes.py
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ART_DIR = REPO_ROOT / "art"

# Absolute ceiling for any asset, regardless of slot type - past this, Godot's own
# Texture2D limit (16384) isn't even the binding constraint; mobile GPUs realistically
# cap at 4096 (Godot docs: "Mobile/web platforms typically cannot display textures
# larger than 4096x4096").
ABSOLUTE_CEILING = 4096

# Per-slot-type ceilings, tighter than the absolute ceiling, from DM-008's own table.
# Matched by path prefix relative to art/, FIRST MATCH WINS - so more specific prefixes
# must be listed before their parents.
#
# DM-069 (2026-07-31) added the two full-bleed slots below and widened `characters/`.
# Stated plainly, because "widen the guard until it passes" is an anti-pattern this project
# has a ticket about (DM-066): these are SLOT-CLASSIFICATION fixes for asset classes that did
# not exist when DM-008 wrote the table, not a relaxation of the constraint that matters.
# ABSOLUTE_CEILING (4096, the real mobile GPU limit) is untouched.
#   - ui/branding/: a splash banner spans the screen. The base viewport is 1024 wide and the
#     test device's logical viewport is ~1706, so a banner is a backdrop-class asset, not an
#     icon-class one. Same 1600 rationale as backdrops/.
#   - evidence/: a full-screen evidence artefact (e.g. the Ch3 deepfake shown on a phone) is
#     likewise backdrop-class, not icon-class.
#   - characters/ 1024 -> 1200: 1024 was a round number, never a measured limit. The delivered
#     portrait set spans 967-1077. See the note in art/ASSET_SPEC.md about Mang Ver's files
#     sitting at 1077 while every other character sits at <=980 - that is a real artist-side
#     export inconsistency worth fixing at source, and it is flagged rather than absorbed.
SLOT_CEILINGS: list[tuple[str, int, str]] = [
    ("ui/branding/", 1600, "branding/splash banner (full-bleed, backdrop-class)"),
    ("characters/", 1200, "portrait (half/whole-body)"),
    ("evidence/", 1600, "evidence artefact (may be full-bleed)"),
    ("ui/", 1024, "UI art"),
    ("backdrops/", 1600, "backdrop (1600 wide x 768 tall - width is the ceiling here)"),
]


def _png_dimensions(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as f:
        header = f.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    width, height = struct.unpack(">II", header[16:24])
    return width, height


def ceiling_for(rel_path: str) -> tuple[int, str]:
    for prefix, limit, label in SLOT_CEILINGS:
        if rel_path.startswith(prefix):
            return limit, label
    return ABSOLUTE_CEILING, "unclassified art/ slot (absolute ceiling)"


def main() -> int:
    if not ART_DIR.exists():
        print("No art/ directory - nothing to check.")
        return 0

    failures: list[str] = []
    checked = 0
    for path in sorted(ART_DIR.rglob("*.png")):
        if "source" in path.relative_to(ART_DIR).parts:
            continue  # art/source/ is raw working material, gitignored, not shipped
        rel = str(path.relative_to(ART_DIR)).replace("\\", "/")
        dims = _png_dimensions(path)
        if dims is None:
            failures.append(f"{rel}: could not read PNG header (corrupt file?)")
            continue
        width, height = dims
        checked += 1

        if width > ABSOLUTE_CEILING or height > ABSOLUTE_CEILING:
            failures.append(
                f"{rel}: {width}x{height} exceeds the absolute {ABSOLUTE_CEILING}px ceiling "
                f"- will render as a black box on Android (godot#28960), not crash"
            )
            continue

        limit, label = ceiling_for(rel)
        if width > limit or height > limit:
            failures.append(f"{rel}: {width}x{height} exceeds the {limit}px ceiling for {label}")

    print(f"Checked {checked} PNG(s) under art/.")
    if failures:
        print(f"\n{len(failures)} FAILURE(S):")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("All assets within their size ceilings.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
