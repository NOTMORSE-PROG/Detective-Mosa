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
# Matched by path prefix relative to art/.
SLOT_CEILINGS: list[tuple[str, int, str]] = [
    ("characters/", 1024, "portrait (half/whole-body)"),
    ("evidence/", 1024, "evidence/UI art"),
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
