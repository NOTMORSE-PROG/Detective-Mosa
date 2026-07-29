class_name Juice
extends RefCounted
# DM-057 - reusable game-feel helpers: pop() (tween-with-overshoot / squash-stretch),
# shake() (eased screen shake), hit_stop() (freeze-frame on impact), burst() (small
# particle burst). Toolkit only - DM-057b (M5) is the first ticket allowed to call these
# from a real screen. Nothing below names a screen ID or a game concept (trust, lives,
# chismis, etc.) - that's what keeps this reusable across DM-022/DM-027/DM-028/DM-057b
# instead of each call site reinventing its own tween.
#
# Static-only, not an autoload: every helper's target is already a node in the tree, so
# target.create_tween() reaches a SceneTree without Juice needing one of its own -
# CODING.md §3's autoload-ordering hazards don't apply to something never in that list.
#
# Weight, not just mechanism: hit_stop() and shake() are the heaviest, most
# consequence-coded tools here - reserve them for moments meant to feel like they
# matter. pop() and burst() are lighter and safe as general confirmation feedback too.
# Which register a given call site needs is DM-057b's call, not this file's.
#
# gdlint's class-definitions-order enforces one strict, non-interleavable ordering
# (consts -> staticvars -> funcs) across the whole file, so every helper's tuning consts
# live together up top rather than next to that helper's own functions further down -
# each block below is still labelled per helper to keep that split navigable.

const PALETTE: Palette = preload("res://data/palette.tres")

# --- pop() tuning ---
## Peak overshoot on the dominant (Y) axis, +18%.
const POP_STRENGTH_DEFAULT: float = 0.18
## X overshoots at 60% of Y's strength - the "taller, not wider" read.
const POP_SQUASH_RATIO: float = 0.6
## Seconds, total (rise + settle).
const POP_DURATION_DEFAULT: float = 0.30
## 40% rise to peak, 60% settle - launches fast, settles slower.
const POP_UP_FRACTION: float = 0.4
## Overbright modulate multiply for the reduced-motion substitute, not a new token.
const POP_REDUCED_FLASH: Color = Color(1.4, 1.4, 1.4, 1.0)
const POP_REDUCED_DURATION: float = 0.15
const SFX_POP_DEFAULT: StringName = &"ui_select"

# --- shake() tuning ---
## Authored deliberately conservative on desktop - screen shake reads roughly 2x
## stronger on a phone at arm's length than on a monitor (ticket edge case).
## Confirmed on a real device (Xiaomi 22101316UG, DM-057's device pass): reads as a
## genuine, felt shake at arm's length, not imperceptible - no retune forced. DM-057b
## may still want to move this per-call-site, but this default is no longer a guess.
const SHAKE_MAGNITUDE_DEFAULT: float = 8.0  ## px, at the 1024x768 reference (DESIGN.md §6)
## Seconds - middle of the mandated 0.1-0.3s band (ticket AC).
const SHAKE_DURATION_DEFAULT: float = 0.2
## Hz, random-direction step rate - ~15-25Hz reads as "shake," not buzz or discrete jolts.
const SHAKE_FREQUENCY_DEFAULT: float = 22.0
## Darken multiply for the reduced-motion substitute - opposite direction from pop's
## brighten, kept visually distinguishable from it.
const SHAKE_REDUCED_DIM: Color = Color(0.75, 0.75, 0.75, 1.0)
const SHAKE_REDUCED_DURATION: float = 0.15
## Provisional - no generic impact/thud clip exists yet; see DM-057.md gap note.
const SFX_SHAKE_DEFAULT: StringName = &"ui_transition"

# --- hit_stop() tuning ---
## Seconds, REAL elapsed time (not scaled by the freeze it itself creates).
const HIT_STOP_DURATION_DEFAULT: float = 0.05
## Not 0.0 - true zero risks downstream divide-by-zero in anything assuming delta > 0;
## reads as a full freeze at this duration regardless.
const HIT_STOP_TIME_SCALE: float = 0.05

# --- burst() tuning ---
## "Small," per the ticket's own framing - not a fountain.
const BURST_COUNT_DEFAULT: int = 10
const BURST_LIFETIME: float = 0.5  ## seconds per particle
## Degrees - omnidirectional, fits any call site regardless of what's "up" there.
const BURST_SPREAD_DEFAULT: float = 180.0
const BURST_SPEED_MIN: float = 40.0  ## px/s
const BURST_SPEED_MAX: float = 90.0  ## px/s
## Slight downward arc so particles settle rather than fly forever in straight lines.
const BURST_GRAVITY_Y: float = 60.0
const BURST_SCALE_MIN: float = 0.5
const BURST_SCALE_MAX: float = 1.0
const BURST_REDUCED_RADIUS: float = 10.0  ## px
const BURST_REDUCED_FADE_DURATION: float = 0.25
## px, base diameter of the generated particle dot before scale_amount_min/max apply -
## CPUParticles2D with no texture set draws each particle as a single unscaled pixel
## (confirmed by pixel-sampling a real capture: correct colour, correct position, present
## at the right frame, but only 1-2px per particle - functionally correct and visually
## unregistered, which is exactly what the ticket's own "tune for registration, not
## spectacle" edge case warns against). 16px keeps the "small" framing while actually
## being visible against bg-deep at arm's length.
const BURST_PARTICLE_DIAMETER: int = 16
## Provisional - no generic sparkle/confetti clip exists yet; see DM-057.md gap note.
const SFX_BURST_DEFAULT: StringName = &"ui_tap_alt"
## Transparent-black sentinel meaning "use Palette.gold." A preloaded Resource's field is
## not reliably const-foldable as a default-parameter expression in GDScript, so the real
## default is resolved in the function body instead of risking a parse error here.
const _BURST_COLOR_UNSET: Color = Color(0, 0, 0, 0)

# ---------------------------------------------------------------------------
# Reduce-motion - single accessor point (ticket's pre-implementation research note).
# Defaults OFF. DM-053 replaces is_reduce_motion_enabled()'s body with a real read
# (SaveManager-backed, same settings.json pattern AudioDirector's bus volumes already
# use) - every helper below calls only this function, never the backing var.
# ---------------------------------------------------------------------------
static var _reduce_motion_forced: bool = false

## Reentrancy token for hit_stop() - see hit_stop()'s own doc comment below.
static var _hit_stop_id: int = 0

## Lazily built, cached once - burst() may fire often (once per correct mini-game answer,
## eventually), and regenerating a soft-circle Image/ImageTexture per-pixel on every call
## would be wasteful when the same 16x16 texture is correct every time.
static var _particle_texture_cache: ImageTexture = null


static func is_reduce_motion_enabled() -> bool:
	return _reduce_motion_forced


## Dev/test-only - the demo scene's toggle and GUT tests are the only sanctioned
## callers. Named _for_testing so nobody mistakes this for the real DM-053 setting.
static func set_reduce_motion_override_for_testing(enabled: bool) -> void:
	_reduce_motion_forced = enabled


# ---------------------------------------------------------------------------
# pop() - tween-with-overshoot / squash-and-stretch.
# ---------------------------------------------------------------------------


## Scales `target` up past base_scale with an overshoot, then settles back to it. Never
## reads target.scale directly - Control and Node2D each declare "scale" independently
## (CanvasItem itself declares neither position nor scale), so this only ever WRITES via
## Tween's string-keyed tween_property, always from an explicit .from(base_scale). That's
## what lets one function work on both a Control-based UI element and a Node2D sprite
## without duck-typed get/set.
static func pop(
	target: CanvasItem,
	base_scale: Vector2 = Vector2.ONE,
	strength: float = POP_STRENGTH_DEFAULT,
	duration: float = POP_DURATION_DEFAULT,
	sfx_id: StringName = SFX_POP_DEFAULT
) -> Tween:
	if sfx_id != &"":
		AudioDirector.play_sfx(sfx_id)
	if is_reduce_motion_enabled():
		return _pop_reduced(target)

	var peak: Vector2 = Vector2(
		base_scale.x * (1.0 + strength * POP_SQUASH_RATIO), base_scale.y * (1.0 + strength)
	)
	var up_time: float = duration * POP_UP_FRACTION
	var settle_time: float = duration - up_time

	var tw: Tween = target.create_tween()
	tw.set_ignore_time_scale(true)  # a concurrent hit_stop() must never stretch this out
	var rise: PropertyTweener = tw.tween_property(target, "scale", peak, up_time)
	rise.from(base_scale)
	rise.set_trans(Tween.TRANS_BACK)  # TRANS_BACK is what produces the overshoot itself
	rise.set_ease(Tween.EASE_OUT)
	var settle: PropertyTweener = tw.tween_property(target, "scale", base_scale, settle_time)
	settle.set_trans(Tween.TRANS_QUAD)
	settle.set_ease(Tween.EASE_OUT)
	return tw


static func _pop_reduced(target: CanvasItem) -> Tween:
	target.modulate = POP_REDUCED_FLASH
	var tw: Tween = target.create_tween()
	tw.set_ignore_time_scale(true)
	var fade: PropertyTweener = tw.tween_property(
		target, "modulate", Color.WHITE, POP_REDUCED_DURATION
	)
	fade.set_trans(Tween.TRANS_QUAD)
	fade.set_ease(Tween.EASE_OUT)
	return tw


# ---------------------------------------------------------------------------
# shake() - eased screen shake, 0.1-0.3s (hard bound, ticket AC).
# ---------------------------------------------------------------------------


## Shakes `target` around its current position and returns it there exactly. Every
## individual hop is itself eased (TRANS_SINE/EASE_IN_OUT) and the overall amplitude
## decays along a cubic ease-out envelope via Tween.interpolate_value() - never linear
## at either level, since a linear shake reads as a bug (ticket AC).
static func shake(
	target: CanvasItem,
	magnitude: float = SHAKE_MAGNITUDE_DEFAULT,
	duration: float = SHAKE_DURATION_DEFAULT,
	frequency_hz: float = SHAKE_FREQUENCY_DEFAULT,
	sfx_id: StringName = SFX_SHAKE_DEFAULT
) -> Tween:
	if sfx_id != &"":
		AudioDirector.play_sfx(sfx_id)
	var base_position: Vector2 = target.position
	if is_reduce_motion_enabled():
		return _shake_reduced(target)

	var step_count: int = maxi(4, roundi(duration * frequency_hz))
	var step_duration: float = duration / step_count
	var tw: Tween = target.create_tween()
	tw.set_ignore_time_scale(true)
	for i in step_count:
		# interpolate_value(initial_value, delta_value, elapsed_time, duration, ...) -
		# second arg is a DELTA not an endpoint, so -1.0 here means "decay from 1.0 down
		# to 1.0 + (-1.0) = 0.0", not literally "-1.0" (verified against ClassDB this
		# session, not assumed from memory - a wrong read here would silently invert or
		# double the envelope).
		var envelope: float = Tween.interpolate_value(
			1.0, -1.0, float(i), float(step_count), Tween.TRANS_CUBIC, Tween.EASE_OUT
		)
		var offset: Vector2 = (
			Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * magnitude * envelope
		)
		var hop: PropertyTweener = tw.tween_property(
			target, "position", base_position + offset, step_duration
		)
		hop.set_trans(Tween.TRANS_SINE)
		hop.set_ease(Tween.EASE_IN_OUT)
	var settle: PropertyTweener = tw.tween_property(
		target, "position", base_position, step_duration
	)
	settle.set_trans(Tween.TRANS_SINE)
	settle.set_ease(Tween.EASE_OUT)
	return tw


static func _shake_reduced(target: CanvasItem) -> Tween:
	target.modulate = SHAKE_REDUCED_DIM
	var tw: Tween = target.create_tween()
	tw.set_ignore_time_scale(true)
	var fade: PropertyTweener = tw.tween_property(
		target, "modulate", Color.WHITE, SHAKE_REDUCED_DURATION
	)
	fade.set_trans(Tween.TRANS_QUAD)
	fade.set_ease(Tween.EASE_OUT)
	return tw


# ---------------------------------------------------------------------------
# hit_stop() - a few-ms freeze of the visual timescale on impact.
# ---------------------------------------------------------------------------


## Freezes Engine.time_scale near-zero for duration_sec of REAL time, then restores it.
## Never touches the audio mixer - Engine.time_scale does not affect AudioStreamPlayer
## playback (verified against the 4.7 Engine docs), so a track playing through the freeze
## does not stutter or pitch-shift.
##
## Silent by default (sfx_id ""): unlike pop/shake/burst, hit_stop has no visual shape of
## its own - it's a modifier that makes a SIMULTANEOUS effect land harder, so the audible
## half of "hit_stop then shake" should come from the shake, not from two overlapping
## sounds. Pass an explicit sfx_id only when using hit_stop standalone.
##
## Reentrant-safe: if a second hit_stop() starts before the first one's timer fires, the
## FIRST call's restore becomes a no-op instead of snapping time_scale back to 1.0 out
## from under the still-wanted freeze.
static func hit_stop(
	duration_sec: float = HIT_STOP_DURATION_DEFAULT, sfx_id: StringName = &""
) -> void:
	if sfx_id != &"":
		AudioDirector.play_sfx(sfx_id)
	if is_reduce_motion_enabled():
		return

	_hit_stop_id += 1
	var my_id: int = _hit_stop_id
	Engine.time_scale = HIT_STOP_TIME_SCALE
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	# ignore_time_scale=true is load-bearing: without it, this "50ms" timer would itself
	# be slowed by the time_scale it's supposed to be timing the end of - 50ms / 0.05
	# would become a full second, turning a hit-stop into a freeze bug.
	await tree.create_timer(duration_sec, true, false, true).timeout
	if _hit_stop_id == my_id:
		Engine.time_scale = 1.0


# ---------------------------------------------------------------------------
# burst() - a small particle burst for an otherwise-flat action.
# ---------------------------------------------------------------------------


## Spawns a one-shot CPUParticles2D under `parent` at `global_position` and frees itself
## via the `finished` signal CPUParticles2D emits once a one_shot burst completes - no
## manual cleanup timer needed. CPUParticles2D over GPUParticles2D deliberately: works
## under every Godot 4 rendering method including Compatibility, needs no
## ParticleProcessMaterial resource, and the CPU cost of ~10 particles is immaterial - the
## right trade for a "small" burst across whatever Android GPUs this ships to (DM-055's
## oldest-phone pass hasn't run yet). Deviates from this ticket's own "Relevant files"
## hint (which named GPUParticles2D); logged as a deliberate call, not an oversight.
static func burst(
	parent: Node,
	global_position: Vector2,
	count: int = BURST_COUNT_DEFAULT,
	spread_deg: float = BURST_SPREAD_DEFAULT,
	color: Color = _BURST_COLOR_UNSET,
	sfx_id: StringName = SFX_BURST_DEFAULT
) -> void:
	if sfx_id != &"":
		AudioDirector.play_sfx(sfx_id)
	var resolved_color: Color = PALETTE.gold if color.a <= 0.0 else color
	if is_reduce_motion_enabled():
		_burst_reduced(parent, global_position, resolved_color)
		return

	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = BURST_LIFETIME
	particles.explosiveness = 1.0  # all particles fire together - a burst, not a stream
	particles.direction = Vector2.UP
	particles.spread = spread_deg
	particles.initial_velocity_min = BURST_SPEED_MIN
	particles.initial_velocity_max = BURST_SPEED_MAX
	particles.gravity = Vector2(0, BURST_GRAVITY_Y)
	particles.scale_amount_min = BURST_SCALE_MIN
	particles.scale_amount_max = BURST_SCALE_MAX
	particles.color = resolved_color
	particles.texture = _particle_texture()
	# add_child BEFORE setting global_position, not after: a parentless node has no
	# transform chain, so "global" and "local" are the same value at that moment - set
	# global_position before parenting and add_child will NOT compensate for the new
	# parent's own transform, silently shifting the burst's on-screen position by whatever
	# that parent is offset from the origin. Parent first, then position.
	parent.add_child(particles)
	particles.global_position = global_position
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


## Soft-edged white circle, alpha-falls-off at the rim - tinted per-particle by
## CPUParticles2D's own `color` property (a white source texture is what lets that
## tinting work correctly; a pre-coloured texture would fight it). White, not the same
## `_make_circle_icon()` used by Settings.gd's slider grabber, because that helper takes a
## fixed colour baked into the pixels - burst() needs colour to stay a runtime value.
static func _particle_texture() -> ImageTexture:
	if _particle_texture_cache != null:
		return _particle_texture_cache
	var diameter: int = BURST_PARTICLE_DIAMETER
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center := Vector2(diameter / 2.0, diameter / 2.0)
	var radius: float = diameter / 2.0
	for y in diameter:
		for x in diameter:
			var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha: float = clampf(radius - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_particle_texture_cache = ImageTexture.create_from_image(img)
	return _particle_texture_cache


static func _burst_reduced(parent: Node, global_position: Vector2, color: Color) -> void:
	var dot := _BurstDot.new()
	dot.setup(color, BURST_REDUCED_RADIUS)
	parent.add_child(dot)
	dot.global_position = global_position  # see burst()'s own ordering note above
	var tw: Tween = dot.create_tween()
	tw.set_ignore_time_scale(true)
	var fade: PropertyTweener = tw.tween_property(
		dot, "modulate:a", 0.0, BURST_REDUCED_FADE_DURATION
	)
	fade.set_trans(Tween.TRANS_QUAD)
	fade.set_ease(Tween.EASE_OUT)
	tw.finished.connect(dot.queue_free)


## Nested, not a separate file: the only thing the reduced-motion burst path needs is "a
## flat circle that fades in place," and CanvasItem exposes no generic draw-a-shape signal
## to hook from outside - a two-line _draw() override is the plain way to get one. Nesting
## it keeps the "one place" promise instead of a second file for four lines of logic.
class _BurstDot:
	extends Node2D
	var _color: Color
	var _radius: float

	func setup(color: Color, radius: float) -> void:
		_color = color
		_radius = radius

	func _draw() -> void:
		draw_circle(Vector2.ZERO, _radius, _color)
