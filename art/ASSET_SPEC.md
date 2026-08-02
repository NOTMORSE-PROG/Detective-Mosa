# ASSET_SPEC — the artists' brief

Read this before you draw anything. Every rule here exists because it already went wrong
once — the first delivery broke two of them, and fixing them after the fact meant a
79-file re-export. Catching them before you start costs nothing.

Reviewed and drafted with `mosa-art-director` (`DM-008`, 2026-07-29).

## The intake ritual (`DM-050`)

What happens every time a real file replaces a placeholder:

1. **Drop the real file at the exact path the slot table names**, same filename, same
   convention (`{CHARACTER}/{CHARACTER}-{Pose}{Direction}.png`). This is what makes the
   swap free — see `DM-008`'s own demonstration
   (`tickets/M1-design-system/evidence/dm008-swap-before.png` / `-after.png`).
2. **Run S23** (`src/scenes/AssetAudit.tscn`, dev builds only) and confirm the slot now
   shows **Final**, not **Placeholder**. Status is computed from the file itself (an MD5
   compare against the known placeholder output — `data/AssetManifest.gd`), never hand-set,
   so this step can't silently lie.
3. **`mosa-art-director` consistency pass** on the new file against everything already in
   the game — line weight, outline colour, character scale, eye-line height, shadow
   treatment, palette adherence (their own agent brief's checklist). No single person
   reliably catches this across five contributors.
4. **Regenerate the slot table below**: `godot --headless --path . -s
   tools/generate_asset_brief.gd`. Do not hand-edit the generated section at the bottom of
   this file (marked clearly below) — it's overwritten from `data/asset_manifest.tres`
   every time, and a hand-edit there just gets silently discarded on the next run.
5. **Push.** `tools/count_placeholders.gd` runs in CI on every push and prints
   `placeholders: N / total`, so progress is visible without asking anyone.

**A manifest that drifts from reality is worse than no manifest** — this is why step 2's
status is derived, not typed. If a slot's file is deleted or its path changes without
updating `data/asset_manifest.tres`, S23 reports it as **missing**, loudly, rather than
silently keeping stale data.

---

## Canvas size ceilings — and why they're not optional

| Slot type | Max dimensions | Why |
|---|---|---|
| Character portrait/sprite | 1024×1024 (practical: ~300–400px wide × ~820px tall, tight-cropped) | The game screen itself is only 1024×768 |
| Backdrop | Exactly 1600×768 | See "wider than 4:3" below |
| Evidence / UI art | 1024×1024 | Always shown small, never full-screen |
| Pixel/movement sheet | Native pixel size, no upscaling | Upscaling destroys the pixel grid — see below |
| Absolute ceiling, anything | 4096×4096 | Past this, phones can't display it at all |

**What happens if you go over:** the image does not error, does not warn you, and does not
crash the game. It simply **renders as a solid black rectangle on Android phones** — a
mobile GPU limit, not a bug in our code. This looks exactly like a broken art file, so the
instinct is to redraw it. It isn't broken — it's oversized. If a character or backdrop ever
shows up as a black box on a phone, check the pixel dimensions before touching the drawing.

**Export at game size, not canvas size.** If you're working in a document that's much larger
than the final export (a common default), export a flattened copy at the target size above
— don't hand over the full working canvas.

**Automated check:** `tools/check_asset_sizes.py` runs on every push and blocks anything
over these ceilings — a rule nobody can verify by eye is a rule that decays across five
contributors.

## Formats

**Export flattened PNG.** PSD cannot be opened by the game engine at all — not "opens
wrong," genuinely cannot be read. If your tool saves layered files, flatten and export PNG
before handing it over. WebP, JPEG, and a few others also work, but PNG is what everyone
else is using and keeps things simple.

## Backdrops are drawn wider than the screen

The game screen is 4:3, but backdrops are painted at 1600×768 — noticeably wider. On a
phone that isn't exactly 4:3 (most aren't), the extra width fills in with **more of your
scene**, not black bars on the sides. If you paint exactly to the 4:3 frame, phones with a
different screen shape will show empty black strips down the sides of your art.

**Practical rule: compose your focal point in the center ~1024px column of your 1600px
canvas.** Treat the outer ~290px on each side as a bonus — nice to fill with more scene, but
never where the important thing is, because narrower phones won't show it.

⚠️ **Backdrops are always COVER-transformed at render time, never placed 1:1** (`DESIGN.md
§5`, 2026-07-29 reopen). 1600px isn't wide enough for every real device: the test Xiaomi's
real logical viewport under `expand` stretch measures 1706.67px wide (2400×1080 physical,
scaled). A backdrop placed at its native 1:1 size on a phone wider than 1600 logical px would
show black bars down both sides — a real bug found on `DM-010`'s device pass, not a
hypothetical. Every backdrop-consuming scene scales the source texture to at least cover the
full logical viewport width (bottom-anchored, so the floor line stays put and any excess is
cropped from the ceiling) rather than trusting the 1600px canvas to always be wide enough.

## Every backdrop needs a near-black framing layer — this is not optional

Look at any Hollow Knight screenshot (the reference the game's whole look is built from):
the top and both edges of the screen are dark, jagged, flat silhouette shapes — no
detail, no rendering, just black shapes cut into the frame. That layer is the single
biggest reason those scenes look expensive. It's also the cheapest thing to draw in the
entire image — flat shapes, no shading.

**For us: tarpaulins, basketball backboards, sari-sari store awnings, laundry lines, tangled
electrical wires** — whatever silhouette makes sense for that location, cut into the top and
side edges as flat near-black shapes. It should be **its own separate file**, same 1600×768
canvas, transparent except for the silhouette shapes — not painted into the backdrop itself.
That way it can be adjusted without repainting the scene under it, and it can move
independently of the background when the camera pans (`Parallax2D` gives it its own scroll
rate, per `REFERENCES.md`'s own Reference A recipe).

Keep it asymmetric — don't mirror the left and right edges. Nothing in this game's
compositions is centered or symmetric; that's part of what keeps a scene from looking flat.

⚠️ **Neither backdrop delivered so far (`livingroom.png`/Mang Ver's sala, `bilistore.png`/
Dali Mart) has this layer yet** — confirmed by looking at both directly, not assumed. This
predates this spec, so it isn't an artist error; it's a follow-up pass still owed. Both are
shipping with a placeholder framing layer in the meantime (see the slot table).

## Everything is near-monochrome, one hue family per location

Pick one warm hue family per location (gold, amber, teal — whatever suits the place) and
stay inside it. Contrast and light direct the eye, not a variety of colors. If a piece needs
a color the current palette can't express, that's a conversation before you draw it (via
`DESIGN.md §5`), not after.

## Anchor — bottom-center of your own crop, not a fixed canvas position

Every delivered character sprite is cropped tight to its own content (measured directly:
`MOSA-IdleFront.png` is 285×812px, `MOSA-IdleLeft.png` is 196×812px, `MOSA-ShockedFront.png`
is 370×811px — the width varies by pose, the art is never padded to a fixed canvas). In every
file checked, the character's feet sit exactly at the bottom edge, horizontally centered in
that crop. **Keep doing this** — it's already correct and it's what lets the game swap Idle
for Shocked without the character appearing to float or sink.

## File naming — the short-prefix convention (`DM-069`, 2026-07-31)

`{PREFIX}/{PREFIX}-{Pose}{Direction}.png`, e.g. `mosa/M-IdleFront.png`,
`alingvilma/AV-HappyFront.png`. **Superseded the original all-caps full-name convention**
(`MOSA-IdleFront.png`) the 2026-07-31 delivery arrived under — every artist had
independently switched to short prefixes by that delivery, with zero filename overlap
against anything shipped before it. Owner decision: **adopt theirs rather than rename on
intake** (`DM-069`) — renaming on every future delivery is a recurring chore, and it breaks
the shared vocabulary when an artist says "I fixed `AV-Happy`."

| Character | Prefix | Character | Prefix |
|---|---|---|---|
| Mosa | `M-` | Jorge | `J-` |
| Aling Vilma | `AV-` | Bugoy | `B-` |
| Aling Mila | `AM-` | Kap. Torres | `KAP-` |
| Mang Ver | `MV-` | Madam Baby | `MB-` |
| Mang Tomas | `MT-` | | |

**Reference sheets are not game assets.** A combined turnaround/expression sheet (no
`Front`/`Left`/`Right` suffix, e.g. `M-Idle.png`, `MOSA-Expressions.png`) is working
reference, not something the game loads — those live in `art/source/delivered-reference/`,
gitignored, not in `art/characters/`. Every game-ready sprite is individually cropped with a
direction suffix. If a pose only exists as a combined sheet, it isn't usable yet — it needs
an individual crop exported the same way every other pose already was.

**Exception, deliberately kept as-is: the `*-HalfBody.png` master sheets.** Each is a
1024×980 sheet of ~16–17 poses that the individual `*-HalfBodyIdle/Happy/...` crops are
sliced from (`DM-069`) — it stays in `art/characters/` rather than moving to
`delivered-reference/` because, unlike a redundant combined sheet, it still holds poses
nobody has cropped yet (e.g. Jorge's master has shocked/frowning/side/back views beyond his
5 cropped `J-HalfBody*` files). Moving it to the gitignored reference folder would make
future crops impossible without re-extracting the original delivery zip. **Slice from the
masters; never inventory only the crops** — a pose audit that counts crop files alone
under-reports every character by roughly half.

## Known gaps after the 2026-07-31 delivery — old file kept, not replaced

Several poses tracked in the manifest have **no equivalent under the new convention** —
confirmed by looking at the art, not just the filenames (differently-named poses turned out
to be genuinely different content, not renames — e.g. Mosa's old `Disappointed` and the new
`Serious` are different expressions entirely). Their manifest slots still point at the old
full-name file, which is why `art/characters/` still has a small number of `MOSA-*` /
`JORGE-*` / `BUGOY-*` / `ALINGVILMA-*` / `ALINGMILA-*` / `MANGTOMAS-*` files alongside the
new short-prefix ones — **these specific ones are load-bearing, not leftover clutter**:

- Mosa `Disappointed` (F/L/R) — new set has `Serious` instead, a different expression.
- Jorge `Shy` (F/L/R) — `Left`/`Right` were already placeholder before this delivery.
- Bugoy `Phone` (F/L/R) — not remade even in the new HalfBody set.
- **Aling Vilma `Idle` (F/L/R) — she has no idle/walk pose at all under the new convention.**
  The only directional poses that arrived are `Happy`/`Shocked`/`Worried`. Worth a direct
  ask to the artist, since every other character kept an `Idle` set.
- Aling Mila `Relieved` and `Worried` (F/L/R) — both show her carrying shopping bags, a coin
  purse, and a phone; the new set's `Curious`/`Panic`/`Phone`/`Serious` poses don't reproduce
  that prop combination. Worth keeping deliberately: they're closer to CH2.1's panic-buying
  scene than anything in the new delivery.
- Mang Tomas `Thinking` (F/L/R) — not remade; new set is `Idle` directional only.

Two files also stay under the **old** name for a different reason — `Title.gd` and
`Continue.gd` reference `MOSA-IdleFront.png`/`MOSA-ThinkingFront.png` directly, bypassing the
manifest entirely. Before deleting any old-convention file, confirm it against both the
manifest **and** `grep -rhoE 'res://art/[^"]*\.(png|tres)' src/`.

## Pixel art, and texture filtering

The game is pixel art throughout, at two deliberate densities — high-res (~1024px) for
portraits and backdrops, low-res (~32×50/frame) for the movement sheet (`DESIGN.md §5`,
2026-07-31). **`project.godot` sets
`rendering/textures/canvas_textures/default_texture_filter = 0`** (Nearest) project-wide
(`DM-069`) — texture filtering is a property of whichever node displays a texture, not the
image file, and Godot 4 has no per-folder import default, so one project setting covers
every sprite and backdrop. The walk-cycle sheet is `art/characters/mosa/M-Sprites.png`
(256×256, top-level — not the old `movement/` subfolder).

## Deferred — not yet confirmed slots, so not in the manifest below

**Aling Vilma's Phones pose** is still only a combined reference sheet — currently moot,
since the prologue's warning beat is a phone-screenshot UI asset, not a rendered character.
Not forgotten; one narrative confirmation away from becoming a real row in
`data/asset_manifest.tres`. (Mang Ver's expression range, previously listed here as
unconfirmed, arrived as his 8-pose `MV-HalfBody*` set in the 2026-07-31 delivery and is now
registered.)

---

## Slot table

_Generated from `data/asset_manifest.tres` by `tools/generate_asset_brief.gd` - do not
hand-edit this section, edit the manifest and regenerate. Counts: 126 final, 4
placeholder, 0 missing, 130 total._

### Characters

| Character | Pose | Front | Left | Right | Owner |
|---|---|---|---|---|---|
| Mosa | Idle | final | final | final | (see manifest) |
| Mosa | Thinking | final | final | final | (see manifest) |
| Mosa | Shocked | final | final | final | (see manifest) |
| Mosa | Disappointed | final | final | final | (see manifest) |
| Mangver | Idle | final | final | final | (see manifest) |
| Jorge | Idle | final | final | final | (see manifest) |
| Jorge | Angry | final | final | final | (see manifest) |
| Jorge | Shy | final | **placeholder** | **placeholder** | (see manifest) |
| Bugoy | Idle | final | final | final | (see manifest) |
| Bugoy | Phone | final | final | final | (see manifest) |
| Alingvilma | Idle | final | final | final | (see manifest) |
| Alingvilma | Shocked | final | final | final | (see manifest) |
| Alingvilma | Smile | final | final | final | (see manifest) |
| Alingmila | Idle | final | final | final | (see manifest) |
| Alingmila | Relieved | final | final | final | (see manifest) |
| Alingmila | Worried | final | final | final | (see manifest) |
| Mangtomas | Idle | final | final | final | (see manifest) |
| Mangtomas | Thinking | final | final | final | (see manifest) |
| Mosa | movement walkcycle | final | — | — | (see manifest) |
| Mosa | halfbody idle | final | — | — | (see manifest) |
| Mosa | halfbody idlewaist | final | — | — | (see manifest) |
| Mosa | halfbody sad1 | final | — | — | (see manifest) |
| Mosa | halfbody sad2 | final | — | — | (see manifest) |
| Mosa | halfbody sad3 | final | — | — | (see manifest) |
| Mosa | halfbody shocked | final | — | — | (see manifest) |
| Mosa | halfbody smirk1 | final | — | — | (see manifest) |
| Mosa | halfbody smirk3 | final | — | — | (see manifest) |
| Alingvilma | halfbody handchest | final | — | — | (see manifest) |
| Alingvilma | halfbody happy | final | — | — | (see manifest) |
| Alingvilma | halfbody idle | final | — | — | (see manifest) |
| Alingvilma | halfbody sad | final | — | — | (see manifest) |
| Alingvilma | halfbody shocked | final | — | — | (see manifest) |
| Alingvilma | halfbody tilt | final | — | — | (see manifest) |
| Alingvilma | halfbody waist | final | — | — | (see manifest) |
| Bugoy | halfbody eyesfrown | final | — | — | (see manifest) |
| Bugoy | halfbody frown | final | — | — | (see manifest) |
| Bugoy | halfbody happy | final | — | — | (see manifest) |
| Bugoy | halfbody happy2 | final | — | — | (see manifest) |
| Bugoy | halfbody idle | final | — | — | (see manifest) |
| Bugoy | halfbody sad | final | — | — | (see manifest) |
| Bugoy | halfbody sad2 | final | — | — | (see manifest) |
| Bugoy | halfbody sadtears | final | — | — | (see manifest) |
| Bugoy | halfbody shocked | final | — | — | (see manifest) |
| Bugoy | halfbody waist | final | — | — | (see manifest) |
| Jorge | halfbody close | final | — | — | (see manifest) |
| Jorge | halfbody handchest | final | — | — | (see manifest) |
| Jorge | halfbody happy | final | — | — | (see manifest) |
| Jorge | halfbody idle | final | — | — | (see manifest) |
| Jorge | halfbody waist | final | — | — | (see manifest) |
| Mangtomas | halfbody armschest | final | — | — | (see manifest) |
| Mangtomas | halfbody eyesclose | final | — | — | (see manifest) |
| Mangtomas | halfbody frown | final | — | — | (see manifest) |
| Mangtomas | halfbody grin | final | — | — | (see manifest) |
| Mangtomas | halfbody happy | final | — | — | (see manifest) |
| Mangtomas | halfbody idle | final | — | — | (see manifest) |
| Mangtomas | halfbody sad | final | — | — | (see manifest) |
| Mangtomas | halfbody sad2 | final | — | — | (see manifest) |
| Mangtomas | halfbody side | final | — | — | (see manifest) |
| Mangver | halfbody happy | final | — | — | (see manifest) |
| Mangver | halfbody happywink | final | — | — | (see manifest) |
| Mangver | halfbody idle | final | — | — | (see manifest) |
| Mangver | halfbody sad | final | — | — | (see manifest) |
| Mangver | halfbody sad2 | final | — | — | (see manifest) |
| Mangver | halfbody thinking | final | — | — | (see manifest) |
| Mangver | halfbody thinkingsad | final | — | — | (see manifest) |
| Mangver | halfbody tilt | final | — | — | (see manifest) |
| Alingmila | halfbody handchest | final | — | — | (see manifest) |
| Alingmila | halfbody idle | final | — | — | (see manifest) |
| Alingmila | halfbody panic | final | — | — | (see manifest) |
| Alingmila | halfbody shocked | final | — | — | (see manifest) |
| Alingmila | halfbody think | final | — | — | (see manifest) |
| Alingmila | halfbody waist | final | — | — | (see manifest) |
| Alingmila | halfbody wallet | final | — | — | (see manifest) |

### Backdrops

| Slot | Kind | Status | Size |
|---|---|---|---|
| sala_amber_backdrop | backdrop_content | final | 1600x768 |
| sala_amber_framing | backdrop_framing | **placeholder** | 1600x768 |
| court_gold_backdrop | backdrop_content | final | 1600x768 |
| court_gold_framing | backdrop_framing | **placeholder** | 1600x768 |
| chap1_intro_backdrop | backdrop_content | final | 1600x768 |
| chap2_intro_backdrop | backdrop_content | final | 1600x768 |
| chap3_intro_backdrop | backdrop_content | final | 1600x768 |

### Props

| Slot | Status | Size |
|---|---|---|
| props_exclamation | final | 580x387 |
| props_exclamationbub | final | 580x387 |
| props_question | final | 580x387 |
| props_questionbub | final | 580x387 |
| props_pinboard | final | 1600x768 |
| props_fakenews | final | 1600x768 |
| props_files | final | 405x370 |
| props_tv | final | 1600x768 |
| props_phone | final | 138x205 |

### Branding

| Slot | Status | Size |
|---|---|---|
| branding_groupbanner | final | 1463x641 |
| branding_icarus2 | final | 612x612 |
| branding_icrus | final | 504x529 |

### Evidence

| Slot | Status | Size |
|---|---|---|
| evidence_kap_dfphone1 | final | 1220x967 |
| evidence_kap_dfphone2 | final | 1220x967 |

## M6 preview (not this ticket's scope, recorded so it isn't re-derived later)

✅ Kap. Torres (normal + deepfaked, `art/characters/kaptorres/`, `DM-069`): delivered,
Front/Left/Right for both `KAP-Idle` and the deepfaked `KAP-DF`, plus `KAP-DFPhone1/2`
(phone-screen stills, registered as `evidence` slots for `DM-036`). Not yet given directional
manifest slots — genuinely M6 scope, not part of this ticket's registration list.
Madam Baby: still one file, `MB-Idle.png` — a multi-pose sheet (she's at a radio mixing desk
with a mic), not yet individually cropped into per-pose slots the way the seven `DM-012`
characters are.
Aling Mila and Mang Tomas: both fully delivered and directional, same quality bar as the
Ch1 cast, already organized under `art/characters/`.
Dali Mart: **`bilistore.png` no longer exists in the repo** — the 2026-07-31 delivery's
`Bili Store 1.png` (a modern 24-hour convenience store, not the sari-sari style the PDF
described) is the confirmed Ch2 panic-buying backdrop (`STATE.md`, `DM-069`); `ss-store.png`
is Mang Ver's own sari-sari store, the prologue/hub location. Neither has its framing layer
yet. Radyo Kanto: no backdrop at all yet.
