extends Node
## Dynamic background themes. Initial: SPACE. After first boss: switch to next theme.
## Smooth fade + color shift on transition. Does not change art direction palette for gameplay.

enum ThemeId {
	SPACE,
	TIME_FIELD,
	VOID_FRACTURE,
	ORBITAL_CORE,
}

signal theme_changed(theme_id: int, transition_duration: float)

var current_theme: int = ThemeId.SPACE
var _boss_ever_defeated: bool = false
## 0–1: higher when many bullets on screen. Motifs reduce opacity when high (readability).
var combat_density: float = 0.0


func _ready() -> void:
	current_theme = ThemeId.SPACE
	theme_changed.emit(current_theme, 0.0)
const COMBAT_DENSITY_MAX_BULLETS := 60.0
const MOTIF_DENSITY_FALLOFF := 0.75

# Theme display names for UI
const THEME_NAMES: Dictionary = {
	ThemeId.SPACE: "SPACE",
	ThemeId.TIME_FIELD: "TIME FIELD",
	ThemeId.VOID_FRACTURE: "VOID FRACTURE",
	ThemeId.ORBITAL_CORE: "ORBITAL CORE",
}

# Parallax / background tint hints per theme (RGB, keep alpha in materials)
const THEME_STAR_COLOR: Dictionary = {
	ThemeId.SPACE: Color(0.5, 0.6, 0.85),
	ThemeId.TIME_FIELD: Color(0.6, 0.5, 0.9),
	ThemeId.VOID_FRACTURE: Color(0.4, 0.7, 1.0),
	ThemeId.ORBITAL_CORE: Color(0.9, 0.6, 0.35),
}

const THEME_DUST_COLOR: Dictionary = {
	ThemeId.SPACE: Color(0.2, 0.22, 0.35),
	ThemeId.TIME_FIELD: Color(0.18, 0.2, 0.38),
	ThemeId.VOID_FRACTURE: Color(0.1, 0.15, 0.3),
	ThemeId.ORBITAL_CORE: Color(0.25, 0.2, 0.18),
}

const THEME_FOG_COLOR: Dictionary = {
	ThemeId.SPACE: Color(0.08, 0.1, 0.18),
	ThemeId.TIME_FIELD: Color(0.1, 0.08, 0.18),
	ThemeId.VOID_FRACTURE: Color(0.06, 0.08, 0.15),
	ThemeId.ORBITAL_CORE: Color(0.12, 0.1, 0.08),
}


func get_theme_name(theme_id: int) -> String:
	return THEME_NAMES.get(theme_id, "SPACE")


func set_theme(theme_id: int, transition_duration: float = 1.2) -> void:
	theme_id = clampi(theme_id, 0, ThemeId.ORBITAL_CORE)
	if theme_id == current_theme:
		return
	current_theme = theme_id
	theme_changed.emit(current_theme, transition_duration)


## Call after first boss defeat to advance to next theme (smooth transition).
func advance_theme_after_boss() -> void:
	if _boss_ever_defeated:
		return
	_boss_ever_defeated = true
	var next: int = (current_theme + 1) % (ThemeId.ORBITAL_CORE + 1)
	if next == ThemeId.SPACE:
		next = ThemeId.TIME_FIELD
	set_theme(next, 1.5)


func get_star_color() -> Color:
	return THEME_STAR_COLOR.get(current_theme, THEME_STAR_COLOR[ThemeId.SPACE])


func get_dust_color() -> Color:
	return THEME_DUST_COLOR.get(current_theme, THEME_DUST_COLOR[ThemeId.SPACE])


func get_fog_color() -> Color:
	return THEME_FOG_COLOR.get(current_theme, THEME_FOG_COLOR[ThemeId.SPACE])


## Call from motif controller or main loop; normalizes bullet count to 0–1.
func set_combat_density_from_bullet_count(active_bullets: int) -> void:
	combat_density = clampf(float(active_bullets) / COMBAT_DENSITY_MAX_BULLETS, 0.0, 1.0)


## Multiplier for motif layer opacity: 1.0 when calm, lower when many bullets (keeps bullets readable).
func get_motif_opacity_multiplier() -> float:
	return 1.0 - combat_density * MOTIF_DENSITY_FALLOFF
