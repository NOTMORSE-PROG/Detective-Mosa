#!/usr/bin/env python3
"""Board-vs-git guard: tickets/BOARD.md must never claim DONE for work that isn't
actually in git (DM-066).

Why this exists: five times in this project's history, BOARD.md (and STATE.md, and a
ticket's own header) said a ticket was fully DONE while its real output sat uncommitted
or unpushed in the working tree — twice for the exact same ticket, 22 files the second
time. Every one of those passed every doc-based cross-check that existed, because
/context/ and /tickets/ are gitignored (GIT.md §2): a fully current, fully consistent set
of internal docs proves nothing whatsoever about whether the code they describe ever
reached git. The board held a COPY of the truth (a status someone typed) instead of the
SOURCE (git itself) — the exact shape this whole ticket is about.

Deliberate simplification, stated rather than hidden: BOARD.md has no reliable
structured per-ticket file manifest to cross-reference — a ticket's own "Relevant files"
list is prose written before the work started, not a contract, and drifts from whatever a
session actually touched. Rather than ship a guard that pretends to a precision it can't
deliver, this checks the coarse signal that would have caught every real incident above:
if ANY ticket on the board is marked DONE, the working tree must be clean. A narrower,
ticket-scoped guard is future work, honestly out of reach without a doc convention that
doesn't exist today.

"Commits not yet pushed" is reported but NOT blocking, and this is deliberate, not an
oversight - caught by testing this guard against a real `git push` before shipping it:
a pre-push hook runs BEFORE the push completes, so the very commit(s) about to be sent
are, by definition, still "ahead of upstream" at the moment the hook runs. Blocking on
that would fail every legitimate push. What actually matters — and what genuinely
happened in both real incidents — is uncommitted work sitting in the tree; that check
stays blocking.

Structural limit, worth naming once rather than rediscovering: this can ONLY ever run
locally. /tickets/ is gitignored, so CI's checkout never has BOARD.md at all — there is
no version of this check that could run as a CI step, and it is not wired into
check_quality.py for that reason (a check that can never do anything in CI shouldn't
pretend to be part of the set that mirrors it). It is wired into BOTH tools/pre-commit
and tools/pre-push instead, so the very next git operation of any kind, on any machine
that has the local hooks installed (GIT.md §6), catches a stale DONE claim. That is also
this guard's own honest blind spot, recorded rather than assumed away: a machine that
skipped hook setup, or a commit made with --no-verify, never runs this at all — and if
literally nothing is committed or pushed in a session, no hook fires regardless of what
is on the board, because hooks only fire on git operations. The next session's own
`git status` is still the backstop of last resort, same as every prior instance of this
failure was actually caught.

Usage: python3 tools/check_board_vs_git.py
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BOARD = REPO_ROOT / "tickets" / "BOARD.md"

# Matches a real ticket table row (`DM-### | STATUS | ...`), never a prose mention of
# "DONE" elsewhere in the file (banners, change-log narration) - anchored to the ticket
# ID starting the line, which is the one place BOARD.md's own convention states a status.
_ROW_RE = re.compile(r"^(DM-\d+)\s*\|\s*(TODO|WIP|DONE|BLOCKED)\s*\|", re.MULTILINE)


def done_tickets() -> list[str]:
    text = BOARD.read_text(encoding="utf-8", errors="replace")
    return [m.group(1) for m in _ROW_RE.finditer(text) if m.group(2) == "DONE"]


def working_tree_dirty(only_unstaged: bool = False) -> str | None:
    """`only_unstaged=True` is what pre-commit needs: at that point in the git lifecycle
    the currently-staged files ARE about to be committed, so counting them as "leftover"
    would fail every single commit, staged changes included - the exact kind of
    guard-that-blocks-everything this project's own edge cases warn gets disabled by
    whoever hits it first. Only worktree-column changes (unstaged edits, "??" untracked)
    represent files that will still be dirty AFTER this commit lands. pre-push has no
    pending commit to exclude, so it checks the full status - by GIT.md §5's own
    "finish the DoD, then commit, then push" sequence, the tree should already be clean
    by push time for a well-behaved session.
    """
    result = subprocess.run(
        ["git", "status", "--porcelain"], capture_output=True, text=True, cwd=REPO_ROOT
    )
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    if only_unstaged:
        lines = [line for line in lines if line.startswith("??") or line[1:2] != " "]
    return "\n".join(lines) if lines else None


def unpushed_commit_count() -> int | None:
    result = subprocess.run(
        ["git", "rev-list", "@{u}..", "--count"],
        capture_output=True, text=True, cwd=REPO_ROOT,
    )
    if result.returncode != 0:
        # No upstream configured (e.g. a brand-new local branch) - not the failure mode
        # this guard exists to catch, so don't block on a comparison that can't be made.
        return None
    return int(result.stdout.strip() or "0")


def main() -> int:
    # pre-commit is mid-lifecycle (files are staged, about to be committed); pre-push and
    # a bare manual run have no such pending operation to exclude.
    pre_commit_mode = "--pre-commit" in sys.argv[1:]

    if not BOARD.exists():
        # No internal docs bundle on this machine (GIT.md §6) - nothing to check. Never
        # block a clone that legitimately has no tickets/BOARD.md at all.
        print("no tickets/BOARD.md on this machine - nothing to check.")
        return 0

    done = done_tickets()
    if not done:
        print("no ticket marked DONE on tickets/BOARD.md - nothing to check.")
        return 0

    problems: list[str] = []

    dirty = working_tree_dirty(only_unstaged=pre_commit_mode)
    if dirty is not None:
        problems.append(
            "working tree is NOT clean:\n"
            + "\n".join(f"      {line}" for line in dirty.splitlines())
        )

    # Informational only, deliberately non-blocking - see the module docstring for why
    # blocking on this would fail every legitimate push.
    ahead = unpushed_commit_count()
    if ahead:
        print(f"note: {ahead} local commit(s) not yet pushed to the upstream branch")

    if problems:
        sys.stderr.write(
            "\nBOARD-VS-GIT GUARD FAILED\n"
            f"tickets/BOARD.md marks {len(done)} ticket(s) DONE ({', '.join(done)}), "
            "but git disagrees:\n\n"
            + "\n".join(f"  - {p}" for p in problems)
            + "\n\nA ticket is not DONE until its work is committed AND pushed "
            "(GIT.md §5, TESTING.md §4). Either finish landing the work, or fix the "
            "board - it must not hold a status git can't back up.\n"
        )
        return 1

    print(f"{len(done)} ticket(s) marked DONE on the board; working tree clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
