extends Node
## Central palette for neon arcade look. Use these everywhere for consistency.
## Visual identity: TECHNOLOGICAL LIGHT — energy systems, precision instruments, refraction tools. Not magical.
## Sharp edges, directional beams, pulse-driven emission, energy lines. No soft fantasy glow or organic smoke.
## Player + player bullets: cyan/blue (energy). Enemies: magenta/purple (hostile systems). Enemy bullets: yellow/green.
## Impact: clean flashes + energy spikes; rainbow reserved for stage-clear / rare accent only.

# ----- Player & player bullets (cyan/blue) -----
const PLAYER_PRIMARY := Color(0.35, 0.75, 1.15, 0.95)
const PLAYER_ACCENT := Color(0.5, 0.9, 1.3, 0.95)
const PLAYER_TRAIL_HEAD := Color(0.35, 0.85, 1.0, 0.9)
const PLAYER_TRAIL_TAIL := Color(0.2, 0.6, 1.0, 0.0)
const PLAYER_BULLET := Color(0.3, 0.9, 1.2, 0.95)
const PLAYER_BULLET_GLOW := Color(0.22, 0.7, 1.0, 0.45)
const PLAYER_BULLET_CORE := Color(0.4, 0.95, 1.25, 0.95)

# ----- Enemies (magenta/purple) -----
const ENEMY_PRIMARY := Color(1.0, 0.35, 0.6, 0.95)
const ENEMY_OUTLINE := Color(0.5, 0.15, 0.35, 0.75)
const ENEMY_CORE := Color(1.0, 0.5, 0.75, 0.95)

# ----- Enemy bullets (yellow/green) -----
const ENEMY_BULLET := Color(0.85, 1.0, 0.35, 0.95)
const ENEMY_BULLET_GLOW := Color(0.6, 0.9, 0.3, 0.4)
const ENEMY_BULLET_CORE := Color(0.9, 1.0, 0.45, 0.95)
const ENEMY_BULLET_TRAIL_HEAD := Color(0.9, 1.0, 0.4, 0.85)
const ENEMY_BULLET_TRAIL_TAIL := Color(0.6, 0.9, 0.3, 0.0)

# ----- Rainbow (explosions, stage-clear only) -----
static func get_explosion_gradient() -> Gradient:
	var g := Gradient.new()
	g.add_point(0.0, Color(1, 0.2, 0.5))
	g.add_point(0.25, Color(1, 0.6, 0.2))
	g.add_point(0.5, Color(0.3, 1, 0.5))
	g.add_point(0.75, Color(0.2, 0.6, 1))
	g.add_point(1.0, Color(0.7, 0.3, 1))
	return g

# ----- Hit flash / UI -----
const HIT_FLASH_WHITE := Color(2.0, 2.0, 2.0)
const PLAYER_DAMAGE_FLASH := Color(0.9, 0.4, 0.5, 0.4)

# ----- Brightness tiers (Tier 1 = brightest, enforce hierarchy) -----
# Tier 1: player core, explosion core (brightest) — clean energy, not magic
const TIER1_PLAYER_CORE := Color(0.65, 0.95, 1.35, 0.98)
const TIER1_COCKPIT_GLOW := Color(0.4, 0.8, 1.2, 0.5)
const TIER1_EXPLOSION_CORE := Color(0.95, 1.0, 1.05, 0.92)
const TIER1_ENERGY_SPIKE := Color(0.4, 0.88, 1.1, 0.85)
# Tier 2: enemy cores, bullet heads
const TIER2_ENEMY_CORE := Color(1.0, 0.55, 0.78, 0.96)
const TIER2_BULLET_CORE_PLAYER := Color(0.45, 0.98, 1.3, 0.96)
const TIER2_BULLET_CORE_ENEMY := Color(0.92, 1.0, 0.5, 0.96)
const TIER2_BULLET_GLOW_PLAYER := Color(0.28, 0.75, 1.05, 0.5)
const TIER2_BULLET_GLOW_ENEMY := Color(0.5, 0.85, 0.28, 0.35)
# Tier 3: trails, enemy bodies (trail opacity must be lower than bullet core)
const TIER3_ENEMY_BODY := Color(0.4, 0.12, 0.22, 0.7)
const TIER3_TRAIL_HEAD_PLAYER := Color(0.32, 0.82, 1.0, 0.52)
const TIER3_TRAIL_TAIL_PLAYER := Color(0.18, 0.55, 1.0, 0.0)
const TIER3_TRAIL_HEAD_ENEMY := Color(0.85, 1.0, 0.38, 0.5)
const TIER3_TRAIL_TAIL_ENEMY := Color(0.55, 0.88, 0.28, 0.0)
# Tier 4: background (reference only; keep dark)

# ----- Boss: Refraction Examiner — clean, sharp, high readability; minimal noise -----
const BOSS_LIGHT_CORE := Color(1.0, 0.94, 0.8, 0.98)
const BOSS_LIGHT_SHELL := Color(0.82, 0.78, 0.65, 0.68)
const BOSS_BEAM_CORE := Color(1.0, 0.9, 0.55, 0.96)
const BOSS_BEAM_GLOW := Color(0.92, 0.72, 0.4, 0.35)
const BOSS_TELEGRAPH := Color(0.98, 0.55, 0.22, 0.78)
const BOSS_TELEGRAPH_EDGE := Color(0.55, 0.22, 0.08, 0.45)
const BOSS_TELEGRAPH_SHARP := Color(0.98, 0.6, 0.25, 0.85)

# ----- Particles: secondary layer only (decorate motion, do not overpower silhouette) -----
const PARTICLE_THRUSTER := Color(0.18, 0.45, 0.7, 0.35)
const PARTICLE_EXPLOSION_BASE := Color(0.7, 0.7, 0.8, 0.5)
const PARTICLE_BEAT_DUST := Color(0.55, 0.55, 0.7, 0.38)
const PARTICLE_AMBIENT := Color(0.22, 0.22, 0.3, 0.22)
