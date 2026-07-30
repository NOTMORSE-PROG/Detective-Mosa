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
  grep guards : trace · token · trust · audio
  asset sizes : tools/check_asset_sizes.py (DM-008) - the 4096px mobile ceiling
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

# `godot --check-only --script <file>` checks a script in isolation, outside the normal
# autoload-instantiation sequence — so it cannot resolve another autoload's name and
# raises a false "Identifier not found" for any script that references one. Confirmed a
# long-standing upstream engine limitation (godotengine/godot#78587, #9810, #111515,
# #3156), not a bug in the script: the same file compiles and runs with zero errors in
# the real, fully-booted project (verified at DM-049 — `--quit-after 1` exits clean).
# From here on almost every script under src/ references GameState by name, so this
# false positive would otherwise block nearly every future push.
_IDENTIFIER_NOT_FOUND_RE = re.compile(r"Identifier not found: (\S+)")

# data/ is where DM-007 will put the palette resource; hex there is the
# source of truth, not a violation. Confirm this path when DM-007 lands.
TOKEN_GUARD_EXCLUDES = {"data/palette.tres"}
HEX_COLOR_RE = re.compile(r"#[0-9A-Fa-f]{6}\b")

# GameState.gd (DM-049) is the only file allowed to write `trust`.
TRUST_GUARD_EXCLUDES = {"src/autoload/GameState.gd"}
TRUST_WRITE_RE = re.compile(r"\btrust\s*=[^=]")

# AudioDirector (DM-011) is the only thing allowed to own an AudioStreamPlayer - every
# other scene/script goes through AudioDirector.set_mood()/play_sfx() instead
# (CODING.md's "scenes never touch an AudioStreamPlayer directly").
AUDIO_GUARD_EXCLUDES = {"src/autoload/AudioDirector.gd", "src/autoload/AudioDirector.tscn"}
AUDIO_PLAYER_TSCN_RE = re.compile(r'type="AudioStreamPlayer[23]?D?"')
AUDIO_PLAYER_GD_RE = re.compile(r"\bAudioStreamPlayer[23]?D?\.new\(")


def known_autoloads() -> set[str]:
    # Parsed straight from project.godot's own [autoload] section, so this never drifts
    # out of sync with what's actually registered — no separate list to maintain.
    project_file = REPO_ROOT / "project.godot"
    if not project_file.exists():
        return set()
    names: set[str] = set()
    in_autoload_section = False
    for line in project_file.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_autoload_section = stripped == "[autoload]"
            continue
        if in_autoload_section and "=" in stripped:
            names.add(stripped.split("=", 1)[0].strip())
    return names


def _autoload_check_only_false_positive(output: str, autoloads: set[str]) -> bool:
    found = _IDENTIFIER_NOT_FOUND_RE.findall(output)
    if not found or any(name not in autoloads for name in found):
        return False
    # Every remaining SCRIPT ERROR / ERROR line must be explained by that same cause, so
    # a real second bug can never hide behind the known false positive.
    for line in output.splitlines():
        text = line.strip()
        if not (text.startswith("SCRIPT ERROR:") or text.startswith("ERROR:")):
            continue
        if "Identifier not found:" in text:
            continue
        if "Failed to load script" in text and "Compilation failed" in text:
            continue
        # Cascade line emitted when the checked script DEPENDS on another script that
        # hit the autoload false positive (e.g. SalaBackdrop -> Juice -> AudioDirector).
        # Purely a symptom: every "Identifier not found" above has already been
        # validated as a real autoload, so this line carries no independent signal.
        if "Failed to compile depended scripts" in text:
            continue
        return False
    return True


def gd_files() -> list[Path]:
    # src/ (our code) and tests/ (our tests) are in scope. addons/ (GUT, vendored
    # third-party) is deliberately excluded — we don't own its style, and reformatting
    # it would fight every future upstream update.
    files: list[Path] = []
    for root in (SRC, TESTS):
        if root.exists():
            files += root.rglob("*.gd")
    return sorted(files)


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
    autoloads = known_autoloads()
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
            continue
        output = result.stdout + result.stderr
        if _autoload_check_only_false_positive(output, autoloads):
            sys.stderr.write("ok (known --check-only/autoload false positive, godot#78587)\n")
            continue
        sys.stderr.write("FAILED\n")
        tail = output.strip().splitlines()[-15:]
        sys.stderr.write("\n".join(f"      {line}" for line in tail) + "\n")
        failures.append(f"parse {rel}")
    return failures


def check_trace_guard() -> list[str]:
    """Two scopes, because file contents alone are NOT enough.

    The original version checked only tracked file contents, leaving commit
    *messages* unchecked entirely. An attribution trailer went into 10 of the
    first 19 commits and reached the public remote while this guard reported
    green every time - GIT.md's first bullet names that exact trailer, and the
    check implementing the rule could not see it. Both scopes now.
    """
    hits: list[str] = []

    # Scope 1 - tracked file contents (the original check). No explicit file-list argument:
    # `git grep` with no pathspec already searches every tracked file by default, and this
    # project passed 1534 tracked files (DM-012's vendored Dialogic addon), well past
    # Windows' ~32K command-line length limit - the explicit list crashed the subprocess
    # call outright (FileNotFoundError: "The filename or extension is too long") rather than
    # giving a false pass, but a guard that can't run at all is still a guard nobody can
    # trust once the file count crosses whatever threshold trips it next.
    result = subprocess.run(
        ["git", "grep", "-il", _TRACE_WORD],
        capture_output=True, text=True, cwd=REPO_ROOT,
    )
    hits += [f"file: {ln.strip()}" for ln in result.stdout.splitlines() if ln.strip()]

    # Scope 2 - commit messages on THIS branch's history, bodies and trailers
    # included. Deliberately HEAD and not --all: --all pulls in refs/remotes/*,
    # which are a snapshot of someone else's (or a pre-rewrite) history that we
    # are not responsible for and often cannot fix. Scanning --all makes it
    # impossible to push a cleaned-up history while the old traced remote ref is
    # still fetched locally - the guard blocks the very fix it should allow.
    log = subprocess.run(
        ["git", "log", "HEAD", "--format=%H%x00%an <%ae>%x00%B%x00---"],
        capture_output=True, text=True, cwd=REPO_ROOT,
    )
    if log.returncode == 0:
        needles = (_TRACE_WORD, "co-authored-by", "anthropic", "generated with")
        for record in log.stdout.split("\0---"):
            if not record.strip():
                continue
            sha = record.split("\0")[0].strip()[:9]
            blob = record.lower()
            for needle in needles:
                if needle in blob:
                    hits.append(f"commit {sha}: message contains '{needle}'")
                    break

    if hits:
        sys.stderr.write("  ! trace guard: FAILED\n")
        sys.stderr.write("".join(f"      {h}\n" for h in hits))
        return ["trace guard"]
    sys.stderr.write("  · trace guard ... ok (files + commit messages)\n")
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


def check_audio_guard() -> list[str]:
    hits = []
    for full in token_guard_scope():
        norm = str(full.relative_to(REPO_ROOT)).replace("\\", "/")
        if norm in AUDIO_GUARD_EXCLUDES:
            continue
        text = full.read_text(encoding="utf-8", errors="replace")
        if AUDIO_PLAYER_TSCN_RE.search(text) or AUDIO_PLAYER_GD_RE.search(text):
            hits.append(norm)
    if hits:
        sys.stderr.write("  ! audio guard: FAILED (AudioStreamPlayer owned outside AudioDirector)\n")
        sys.stderr.write("".join(f"      {h}\n" for h in hits))
        return ["audio guard"]
    sys.stderr.write("  · audio guard ... ok\n")
    return []


def check_asset_sizes() -> list[str]:
    # tools/check_asset_sizes.py (DM-008) is a standalone script with its own PNG-header
    # parser (no PIL dependency at push-time) - called here, not reimplemented, so there
    # is exactly one place this logic lives.
    result = subprocess.run(
        [sys.executable, str(REPO_ROOT / "tools" / "check_asset_sizes.py")],
        cwd=REPO_ROOT, capture_output=True, text=True,
    )
    if result.returncode == 0:
        sys.stderr.write("  · asset sizes ... ok\n")
        return []
    sys.stderr.write("  ! asset sizes: FAILED\n")
    tail = (result.stdout + result.stderr).strip().splitlines()[-20:]
    sys.stderr.write("\n".join(f"      {line}" for line in tail) + "\n")
    return ["asset sizes"]


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
        "audio": check_audio_guard,
        "assets": check_asset_sizes,
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
