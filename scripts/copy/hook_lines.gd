extends Node
## Hook lines for roguelike neon shooter. Light / Time / Space builds. Short, impactful, clear.
## Use for: main menu, run start, boss clear, run summary. Focus: gameplay clarity, rhythm, build identity.

# ----- General (run identity, arcade feel) -----
const GENERAL: Array[String] = [
	"Shape the light. Break the pattern.",
	"Master the beam. Rewrite the run.",
	"Build the force. Survive the burst.",
	"Choose the force. Own the run.",
	"One run. One build. One chance.",
	"Sync the burst. Clear the wave.",
]

# ----- LIGHT (beam, refraction, clarity) -----
const LIGHT: Array[String] = [
	"Bend the light. Cut the chaos.",
	"One beam. One path. No escape.",
	"Refract. Focus. Burn.",
	"Shape the light. Break the pattern.",
	"The beam reads true.",
]

# ----- TIME (pulse, delay, rhythm) -----
const TIME: Array[String] = [
	"Hold the beat. Release the burst.",
	"Delay the hit. Collapse the moment.",
	"Master the pulse. Rewrite the run.",
	"Time the shot. Own the window.",
	"One pulse. One gap. Move.",
]

# ----- SPACE (orbit, pull, position) -----
const SPACE: Array[String] = [
	"Orbit the field. Control the space.",
	"Pull. Orbit. Collide.",
	"Build the force. Hold the line.",
	"Space bends. You don't.",
	"Own the radius. Own the run.",
]

# ----- Run start (identity, commitment) -----
const RUN_START: Array[String] = [
	"Pick your force. Start the run.",
	"One build. Thirty seconds. Go.",
	"Choose the path. Survive the burst.",
]

# ----- Boss clear (mastery, technical) -----
const BOSS_CLEAR: Array[String] = [
	"Pattern broken. Run continued.",
	"Read. Move. Clear.",
	"Mastery. Not luck.",
]

# ----- Game over / run end (identity, replay) -----
const RUN_END: Array[String] = [
	"Run over. Build remembered.",
	"Next run. New force.",
	"Bursts cleared. Identity set.",
]


## Returns a random hook from the given category. Category: general, light, time, space, run_start, boss_clear, run_end.
func get_random(category: String) -> String:
	var list: Array = _get_list(category)
	if list.is_empty():
		return GENERAL[randi() % GENERAL.size()]
	return list[randi() % list.size()]


## Returns a hook for the given force (light, time, space). Falls back to general.
func get_for_force(force: String) -> String:
	var list: Array = _get_list(force)
	if list.is_empty():
		return get_random("general")
	return list[randi() % list.size()]


func _get_list(category: String) -> Array:
	match category.to_lower():
		"general":
			return GENERAL
		"light":
			return LIGHT
		"time":
			return TIME
		"space":
			return SPACE
		"run_start", "start":
			return RUN_START
		"boss_clear", "boss":
			return BOSS_CLEAR
		"run_end", "end":
			return RUN_END
	return GENERAL
