extends Node
## Tetris Effect–style visual hierarchy: beauty in background, clarity in foreground.
## Layer 1 = gameplay (sharp). Layer 2 = interaction FX (timed). Layer 3 = atmosphere (fades during combat).

# ----- CanvasLayer layer numbers (lower = drawn first = back) -----
## Nebula, parallax stars/dust/fog, theme motifs, ambient particles. Fade behind gameplay during combat.
const LAYER_ATMOSPHERE := -200
## Gameplay lives in World (default layer 0). Player, enemies, bullets, boss — crisp, high contrast.
const LAYER_GAMEPLAY := 0
## Hit flashes, weapon ignition, beat pulses, pressure vignette. Moderate glow, never persistent.
const LAYER_FX := 40
const LAYER_FX_PRESSURE := 45
const LAYER_UI := 100

# ----- Opacity / lighting rules -----
## When many bullets present: reduce atmosphere opacity by 20–40%. Falloff 0.35 = 35% max reduction.
const ATMOSPHERE_COMBAT_FALLOFF := 0.35
## Brief brightness multiplier on atmosphere when beat pulses (e.g. 1.08).
const ATMOSPHERE_BEAT_BOOST := 1.08
const ATMOSPHERE_BEAT_DURATION := 0.12
## Slow "breathing" oscillation period (seconds). Breath multiplier = 0.94 + 0.06*sin.
const ATMOSPHERE_BREATH_PERIOD := 14.0
const ATMOSPHERE_BREATH_MIN := 0.94
const ATMOSPHERE_BREATH_MAX := 1.0

## Call from AtmosphereOpacityController or similar. 1 = full, lower during intense combat (20–40% reduction).
func get_atmosphere_opacity_multiplier() -> float:
	var density: float = 0.0
	if ThemeManager:
		density = ThemeManager.combat_density
	return 1.0 - density * ATMOSPHERE_COMBAT_FALLOFF


## Slow breathing multiplier for atmosphere (never constant). 0.94–1.0 over ATMOSPHERE_BREATH_PERIOD.
func get_atmosphere_breath_multiplier() -> float:
	var t := Time.get_ticks_msec() * 0.001
	var phase := t * (TAU / ATMOSPHERE_BREATH_PERIOD)
	return ATMOSPHERE_BREATH_MIN + (ATMOSPHERE_BREATH_MAX - ATMOSPHERE_BREATH_MIN) * (sin(phase) * 0.5 + 0.5)

## Stage progression: gentle brightness nudge (1.0 = rest, ~1.04 = just cleared). Set by ParallaxController on wave/stage clear.
var _stage_progression_multiplier: float = 1.0
func set_stage_progression_multiplier(v: float) -> void:
	_stage_progression_multiplier = clampf(v, 1.0, 1.06)
func get_stage_progression_multiplier() -> float:
	return _stage_progression_multiplier

# ----- Focus: center sharp, edges atmospheric (do not blur gameplay; only soften atmosphere) -----
## When combat is intense: tighten focus (larger clear center). When calm: atmosphere expands (smaller clear center).
const FOCUS_INNER_CALM := 0.18
const FOCUS_INNER_INTENSE := 0.38
const FOCUS_OUTER_CALM := 0.52
const FOCUS_OUTER_INTENSE := 0.72
const FOCUS_CENTER := Vector2(0.5, 0.5)

func get_focus_center() -> Vector2:
	return FOCUS_CENTER

func get_focus_inner_radius() -> float:
	var d: float = ThemeManager.combat_density if ThemeManager else 0.0
	return lerpf(FOCUS_INNER_CALM, FOCUS_INNER_INTENSE, d)

func get_focus_outer_radius() -> float:
	var d: float = ThemeManager.combat_density if ThemeManager else 0.0
	return lerpf(FOCUS_OUTER_CALM, FOCUS_OUTER_INTENSE, d)

## Optional: combine with beat pulse for rhythmic atmosphere. 1.0 when no recent beat.
func get_atmosphere_beat_multiplier() -> float:
	if not has_meta("_beat_until"):
		return 1.0
	var until: float = get_meta("_beat_until", 0.0)
	if Time.get_ticks_msec() * 0.001 > until:
		return 1.0
	return get_meta("_beat_boost", 1.0)

## Call when beat pulses (e.g. from BeatConductor.beat_pulse). Sets short boost for atmosphere.
func set_atmosphere_beat_pulse() -> void:
	set_meta("_beat_until", Time.get_ticks_msec() * 0.001 + ATMOSPHERE_BEAT_DURATION)
	set_meta("_beat_boost", ATMOSPHERE_BEAT_BOOST)
