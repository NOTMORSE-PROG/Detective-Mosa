#!/usr/bin/env python3
"""Pre-push quality gate: run CI's own checks BEFORE the push leaves the machine.

Why this exists: a sibling project's `ruff format --check` failed on eight
consecutive pushes to main. Because it ran before the tests in that workflow,
the test step was SKIPPED every time — nine commits landed with the test
suite never having executed in CI, while ticket after ticket recorded
"CI green" from local runs only.

The lesson, ported here: local-only verification is not verification. This
hook runs the same checks CI runs (context/TESTING.md §3), so a push that
would go red never leaves the machine.

Wire it up once per clone:
    cp tools/pre-push .git/hooks/pre-push     (POSIX)
    copy tools\\pre-push .git\\hooks\\pre-push  (Windows)

Checks (mirrors .github/workflows/ci.yml):
  lint/format : gdformat --check · gdlint
  parse       : godot --headless --check-only, per script, over src/ + tests/
  grep guards : trace · token · trust
  GUT tests   : only once the GUT addon is actually installed (DM-047)

Escape hatch: MOSA_SKIP_QUALITY=1 git push — for genuine emergencies only,
and it must be confessed in context/STATE.md.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import os
import re
from pathlib import Path

# Windows consoles default to the legacy codepage, which mangles the
# non-ASCII characters used in this project's message formatting.
sys.stderr.reconfigure(encoding="utf-8")

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC = REPO_ROOT / "src"
TESTS = REPO_ROOT / "tests"
GUT_ADDON = REPO_ROOT / "addons" / "gut" / "gut_cmdln.gd"
SELF = Path(__file__).resolve()

# Built from parts, never written as one literal word — this file is
# committed, and spelling the trace word out would trip the very guard
# it implements every time this file is checked out.
_TRACE_WORD = "".join(["c", "l", "a", "u", "d", "e"])

# data/ is where DM-007 will put the palette resource; hex there is the
# source of truth, not a violation. Confirm this path when DM-007 lands.
TOKEN_GUARD_EXCLUDES = {"data/palette.tres"}
HEX_COLOR_RE = re.compile(r"#[0-9A-Fa-f]{6}\b")

# GameState.gd (DM-049) is the only file allowed to write `trust`.
TRUST_GUARD_EXCLUDES = {"src/autoload/GameState.gd"}
TRUST_WRITE_RE = re.compile(r"\btrust\s*=[^=]")


def gd_files() -> list[Path]:
    # src/ (our code) and tests/ (our tests) are in scope. addons/ (GUT, vendored
    # third-party) is deliberately excluded — we don't own its style, and reformatting
    # it would fight every future upstream update.
    files: list[Path] = []
    for root in (SRC, TESTS):
        if root.exists():
            files += root.rglob("*.gd")
    return sorted(files)


def tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files"], capture_output=True, text=True, cwd=REPO_ROOT, check=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def run_tool(label: str, cmd: list[str]) -> bool:
    exe = shutil.which(cmd[0])
    if exe is None:
        sys.stderr.write(f"  ? {label}: '{cmd[0]}' not found on PATH — cannot verify\n")
        return False
    sys.stderr.write(f"  · {label} ... ")
    sys.stderr.flush()
    result = subprocess.run([exe, *cmd[1:]], cwd=REPO_ROOT, capture_output=True, text=True)
    if result.returncode == 0:
        sys.stderr.write("ok\n")
        return True
    sys.stderr.write("FAILED\n")
    tail = (result.stdout + result.stderr).strip().splitlines()[-25:]
    sys.stderr.write("\n".join(f"      {line}" for line in tail) + "\n")
    return False


def check_format_and_lint() -> list[str]:
    files = gd_files()
    if not files:
        return []
    failures = []
    rel = [str(f.relative_to(REPO_ROOT)) for f in files]
    if not run_tool("gdformat --check", ["gdformat", "--check", *rel]):
        failures.append("gdformat --check")
    if not run_tool("gdlint", ["gdlint", *rel]):
        failures.append("gdlint")
    return failures


def check_parse() -> list[str]:
    godot = shutil.which("godot")
    files = gd_files()
    if godot is None:
        sys.stderr.write("  ? godot --check-only: 'godot' not found on PATH — cannot verify\n")
        return []
    if not files:
        return []
    failures = []
    for f in files:
        rel = str(f.relative_to(REPO_ROOT))
        sys.stderr.write(f"  · parse {rel} ... ")
        sys.stderr.flush()
        result = subprocess.run(
            [godot, "--headless", "--path", str(REPO_ROOT), "--check-only", "--script", rel],
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            sys.stderr.write("ok\n")
        else:
            sys.stderr.write("FAILED\n")
            tail = (result.stdout + result.stderr).strip().splitlines()[-15:]
            sys.stderr.write("\n".join(f"      {line}" for line in tail) + "\n")
            failures.append(f"parse {rel}")
    return failures


def check_trace_guard() -> list[str]:
    result = subprocess.run(
        ["git", "grep", "-il", _TRACE_WORD, "--"] + tracked_files(),
        capture_output=True, text=True, cwd=REPO_ROOT,
    )
    hits = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if hits:
        sys.stderr.write("  ! trace guard: FAILED\n")
        sys.stderr.write("".join(f"      {h}\n" for h in hits))
        return ["trace guard"]
    sys.stderr.write("  · trace guard ... ok\n")
    return []


def token_guard_scope() -> list[Path]:
    # Same scope philosophy as gd_files(): our code and our scenes/resources,
    # never addons/ (vendored, not ours to police).
    files: list[Path] = []
    for root in (SRC, TESTS):
        if root.exists():
            files += root.rglob("*.gd")
            files += root.rglob("*.tscn")
            files += root.rglob("*.tres")
    return sorted(files)


def check_token_guard() -> list[str]:
    hits = []
    for full in token_guard_scope():
        norm = str(full.relative_to(REPO_ROOT)).replace("\\", "/")
        if norm in TOKEN_GUARD_EXCLUDES:
            continue
        text = full.read_text(encoding="utf-8", errors="replace")
        if HEX_COLOR_RE.search(text):
            hits.append(norm)
    if hits:
        sys.stderr.write("  ! token guard: FAILED (raw hex outside the palette resource)\n")
        sys.stderr.write("".join(f"      {h}\n" for h in hits))
        return ["token guard"]
    sys.stderr.write("  · token guard ... ok\n")
    return []


def check_trust_guard() -> list[str]:
    hits = []
    for f in gd_files():
        rel = str(f.relative_to(REPO_ROOT)).replace("\\", "/")
        if rel in TRUST_GUARD_EXCLUDES:
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        if TRUST_WRITE_RE.search(text):
            hits.append(rel)
    if hits:
        sys.stderr.write("  ! trust guard: FAILED (trust written outside GameState)\n")
        sys.stderr.write("".join(f"      {h}\n" for h in hits))
        return ["trust guard"]
    sys.stderr.write("  · trust guard ... ok\n")
    return []


def check_gut() -> list[str]:
    if not GUT_ADDON.exists():
        sys.stderr.write("  ? GUT tests: addon not installed yet (DM-047) — cannot verify\n")
        return []
    godot = shutil.which("godot")
    if godot is None:
        sys.stderr.write("  ? GUT tests: 'godot' not found on PATH — cannot verify\n")
        return []
    cmd = [
        godot, "--headless", "--path", str(REPO_ROOT),
        "-s", "res://addons/gut/gut_cmdln.gd",
        "-gdir=res://tests", "-ginclude_subdirs",
        "-gexit", "-gconfig=.gutconfig.json",
    ]
    sys.stderr.write("  · GUT tests ... ")
    sys.stderr.flush()
    env = os.environ.copy()
    env["GODOT_DISABLE_LEAK_CHECKS"] = "1"
    result = subprocess.run(cmd, cwd=REPO_ROOT, capture_output=True, text=True, env=env)
    if result.returncode == 0:
        sys.stderr.write("ok\n")
        return []
    sys.stderr.write("FAILED\n")
    tail = (result.stdout + result.stderr).strip().splitlines()[-25:]
    sys.stderr.write("\n".join(f"      {line}" for line in tail) + "\n")
    return ["GUT tests"]


def main() -> int:
    if os.environ.get("MOSA_SKIP_QUALITY") == "1":
        sys.stderr.write(
            "\nWARNING: quality gate skipped (MOSA_SKIP_QUALITY=1).\n"
            "Record why in context/STATE.md.\n\n"
        )
        return 0

    # CI runs each of these as its own workflow step (so `if: always()` means what it
    # says — one red check must never hide another). `--only` lets it call the exact
    # same functions this hook uses locally instead of re-implementing the checks in
    # workflow YAML. No argument (the pre-push hook's case): run everything in one pass.
    checks = {
        "format-lint": check_format_and_lint,
        "parse": check_parse,
        "trace": check_trace_guard,
        "token": check_token_guard,
        "trust": check_trust_guard,
        "gut": check_gut,
    }
    only = sys.argv[1] if len(sys.argv) > 1 else None
    if only is not None and only not in checks:
        sys.stderr.write(f"unknown --only target '{only}'; choices: {', '.join(checks)}\n")
        return 2
    selected = {only: checks[only]} if only else checks

    sys.stderr.write("\nQuality gate (same checks CI runs):\n")
    failures: list[str] = []
    for fn in selected.values():
        failures += fn()

    if failures:
        sys.stderr.write(
            "\nPUSH BLOCKED — these would fail CI:\n"
            + "".join(f"  - {name}\n" for name in failures)
            + "\nFix them, then push again.\n"
            "Emergency override (confess in context/STATE.md):\n"
            "  MOSA_SKIP_QUALITY=1 git push\n\n"
        )
        return 1

    sys.stderr.write("Quality gate passed.\n\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
