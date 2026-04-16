# Rhythm-Driven Neon Shooter — Deliverables

**Goal:** Add a rhythm layer so visuals pulse, breathe, and react in time (no audio analysis).  
**Not changed:** stage system, enemy personality, player readability, art direction palette.

**Flow goal:** Uninterrupted rhythm — minimal hard stops, smooth transitions, upgrades as continuation. See **docs/RHYTHM_FLOW_DESIGN.md**.

---

## TASK 1 — Beat Conductor

**Script:** `scripts/autoload/beat_conductor.gd` (autoload: `BeatConductor`)

- **BPM:** `@export_range(90, 160, 5)` default **120** (recommended presets: 110, 120, 130).
- **Signal:** `beat_pulse` emitted every beat.
- **Pause/resume:** `BeatConductor.set_paused(true)` / `set_paused(false)` to freeze the beat (e.g. when game is paused). During **hitstop**, `_process(delta)` receives scaled delta so the timer effectively pauses without any extra code.

---

## TASK 2 — Global pulse response

On every beat:

| Effect | Implementation |
|--------|----------------|
| **Glow intensity** | Tween `Environment.glow_intensity` from `base * (1 + pulse_glow_boost)` back to base over **0.1s** (`pulse_glow_duration`). |
| **Background pulse** | Full-screen overlay (ColorRect) fades from `pulse_bg_alpha` (default 0.016) to 0 over same duration. |
| **Particle burst** | If `enable_dust` and node **BeatDust** exists in scene, set position to camera center and trigger `restart()` + `emitting = true`. |
| **Enemy scale pulse** | If `enable_enemy_pulse`, each node in group `"enemy"` gets a tween on `Visual.scale` from `scale * enemy_pulse_scale` (default 1.03) back to `scale` over `enemy_pulse_duration` (0.1s). |

Parameters are subtle (low boost, low alpha) so the game feels alive but not distracting.

---

## TASK 3 — Combat sync

| Action | Behaviour |
|--------|-----------|
| **Enemy spawn** | WaveSpawner connects to `BeatConductor.beat_pulse`. When spawn timer would fire, it sets `_pending_spawn = true` and spawns on the **next beat** instead of immediately. |
| **Explosions** | BeatConductor listens to `EventBus.explosion_requested` and runs a **stronger** glow pulse (1.18× base, 0.12s). |
| **Stage clear** | StageManager calls `BeatConductor.stage_clear_pulse()` on stage end: stronger glow (1.35×) + soft cyan full-screen flash; then waits 0.25s before setting `Engine.time_scale = 0`. |

---

## TASK 4 — Player rhythm feedback

**Script:** `scripts/player/thruster_fx.gd`

- **Beat pulse:** Connects to `BeatConductor.beat_pulse`. On each beat, sets `_beat_brighten_until = now + 0.12`. In `_process`, cockpit and cockpit_glow `modulate` get a small boost (default +0.06) while `now < _beat_brighten_until`.
- **Dodge success:** Connects to `EventBus.near_dodge_feedback`. On dodge, sets `_dodge_brighten_until = now + 0.2` and applies a stronger modulate boost (+0.14) so thruster/cockpit briefly brighten.

---

## TASK 5 — Safety

- **Hitstop:** Beat timer uses `_process(delta)`; in Godot 4 delta is scaled by `Engine.time_scale`, so when hitstop or time-scale dip is active, the beat advances more slowly and pulses effectively pause. No change to hitstop logic.
- **Pause:** Explicit `set_paused(true)` when game is paused so the beat does not advance.
- **Subtle / no nausea:** Defaults: `pulse_glow_boost` 0.10, `pulse_bg_alpha` 0.016, `enemy_pulse_scale` 1.03. Ranges documented in `BEAT_PULSE_SYSTEM.md`; do not exceed.

---

## Integration points

| System | Integration |
|--------|-------------|
| **BeatConductor** | Autoload; emits `beat_pulse`; optional `set_paused`. |
| **WaveSpawner** | Connects to `beat_pulse`; spawns on beat when `_pending_spawn`. |
| **ExplosionVFX** | EventBus `explosion_requested` → BeatConductor runs stronger glow. |
| **StageManager** | Calls `BeatConductor.stage_clear_pulse()` then short delay before upgrade UI. Design: stage clear → pulse as “breath” → upgrade choice feels like continuation, not menu interruption (see RHYTHM_FLOW_DESIGN.md). |
| **thruster_fx** | Connects to `beat_pulse` and `EventBus.near_dodge_feedback` for cockpit/thruster brighten. |
| **Main** | Has **BeatDust** (CPUParticles2D) for optional beat particle burst. |

---

## Pulse parameters & BPM presets

See **`docs/BEAT_PULSE_SYSTEM.md`** for full list. Summary:

- **BPM presets:** 110 (slow), 120 (default), 130 (up-tempo).
- **Exports:** `bpm`, `pulse_glow_boost`, `pulse_glow_duration`, `pulse_bg_alpha`, `enable_dust`, `enable_enemy_pulse`, `enemy_pulse_scale`, `enemy_pulse_duration`.

No new paid assets; stage, enemy personality, player readability, and art direction palette unchanged.
