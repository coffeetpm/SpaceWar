extends Resource
class_name UpgradeData
## Scriptable upgrade: id, display name, description, stackable effect.
## Tags enable synergy: weapons and upgrades have tags; synergies trigger off tag matches.
## Synergy upgrades: set effect_type to "synergy" and synergy_trigger / synergy_effect.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
## Optional path to icon texture (e.g. res://resources/icons/upgrade_beam.png). Used when icon is null.
@export var icon_path: String = ""
@export var max_stacks: int = 1
@export var effect_type: StringName  # e.g. "fire_rate", "damage", "max_hp", "projectile_speed", "synergy"
@export var effect_value: float

# ----- Force vocabulary (LIGHT / TIME / SPACE) -----
@export var primary_force: String = ""  # "light", "time", "space" — upgrade derives from this force
# ----- Tag system (synergy-driven) -----
@export var tags: Array[String] = []  # force sub-tags e.g. ["echo"], ["orbit"], ["delay"]
## When to run (e.g. "light_pulse", "time_pulse", "space_tick"). Only used if effect_type == "synergy".
@export var synergy_trigger: String = ""
## What to run (e.g. "afterimage", "electric_burst", "shockwave_split"). Only used if effect_type == "synergy".
@export var synergy_effect: String = ""
## This synergy only runs when source (weapon) has at least one of these tags.
@export var require_source_tags: Array[String] = []
## This synergy only runs when player has at least one upgrade with one of these tags (cross-synergy).
@export var require_upgrade_tags: Array[String] = []
