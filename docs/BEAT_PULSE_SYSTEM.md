# Beat Pulse System — Wiring & Params

Rhythm-driven neon shooter: pulse, breathe, react in time without audio analysis. Beat advances with **scaled** delta so it **pauses** during hitstop.

**Design goal:** Uninterrupted rhythm — player carried by momentum and cadence. Minimal hard stops; weapon cadence leads tempo; waves and visuals align with beat. See **docs/RHYTHM_FLOW_DESIGN.md**.

---

## BeatManager.gd (autoload: `BeatManager`) — timing source

**Location:** `scripts/autoload/beat_manager.gd`

- **Single source of beat grid:** BPM, beat timer, **bar** (4 beats), **phrase** (4 bars = 16 beats). Emits `beat_pulse`, `bar_pulse`, `phrase_pulse`.
- **API:** `get_beat_index()`, `get_bar_index()`, `get_phrase_index()`, `get_beat_phase()`, `get_seconds_to_next_beat()`. See **docs/BEAT_MANAGER.md**.

## BeatConductor.gd (autoload: `BeatConductor`) — visual response

**Location:** `scripts/autoload/beat_conductor.gd`

**Behaviour:**
- **Driven by BeatManager:** No internal timer; connects to `BeatManager.beat_pulse`. On each beat:
  1. **Glow boost:** Tween `Environment.glow_intensity` from `base * (1 + pulse_glow_boost)` back to `base` over `pulse_glow_duration` (default 0.1s).
  2. **Background pulse:** Full-screen overlay (white, low alpha) fades from `pulse_bg_alpha` to 0 over the same duration.
  3. **Dust (optional):** If `enable_dust` and a node named **BeatDust** exists, set position to camera center and trigger one burst.
  4. **Enemy scale pulse (optional):** If `enable_enemy_pulse`, every node in group `"enemy"` gets a tiny scale tween on their `Visual` (from `scale * enemy_pulse_scale` back to `scale` over `enemy_pulse_duration`).

**Explosions:** BeatConductor listens to `EventBus.explosion_requested` and runs a stronger glow pulse (1.18× base, 0.12s).

**Stage clear:** Call `BeatConductor.stage_clear_pulse()` when the stage timer ends (StageManager does this). Stronger glow (1.35×) + soft cyan full-screen flash; then StageManager waits 0.25s before setting `Engine.time_scale = 0`.

**Exports (BeatConductor):**

| Param | Default | Description |
|-------|---------|-------------|
| `pulse_glow_boost` | 0.10 | Glow intensity bump above base (keep ≤ 0.18). |
| `pulse_glow_duration` | 0.1 | Duration of glow/bg pulse (s). |
| `pulse_bg_alpha` | 0.016 | Max alpha of white background pulse (subtle). |
| `ignition_boost_mult` | 1.4 | After build ignition, pulse strength multiplier for ~1.8 s. |
| `ignition_boost_seconds` | 1.8 | Duration ignition amplifies beat. |
| `enable_dust` | true | Trigger BeatDust each beat. |
| `enable_enemy_pulse` | true | Tiny scale pulse on enemies each beat. |
| `enemy_pulse_scale` | 1.03 | Scale multiplier for enemy pulse (e.g. 1.02–1.05). |
| `enemy_pulse_duration` | 0.1 | Duration of enemy scale tween. |

**BPM** is on **BeatManager** (90–160, default 120). See **docs/BEAT_MANAGER.md**.

**Wiring:**
- **BeatManager** (autoload) → timing source; **BeatConductor** (autoload) → visual; connects to `BeatManager.beat_pulse`.
- **Environment:** BeatConductor finds `WorldEnvironment` on `current_scene` and tweens its `environment.glow_intensity`.
- **Overlay:** BeatConductor creates a CanvasLayer + ColorRect for beat and stage-clear flashes.
- **BeatDust:** Under main scene root (Main), node named **BeatDust** (CPUParticles2D); position set each beat to camera center.
- **Spawn on beat:** WaveSpawner connects to `BeatConductor.beat_pulse`; when a spawn is due it sets `_pending_spawn` and actually spawns on the next beat.
- **Player rhythm:** thruster_fx.gd connects to `beat_pulse` (brief cockpit/thruster brighten) and to `EventBus.near_dodge_feedback` (stronger brighten on dodge).

---

## Shader / material params

- **Glow:** No new shaders. The existing **Environment** resource (`neon_glow.tres`) is tweened directly: `glow_intensity` is boosted then restored. Base value is read once when the environment is first acquired (`BASE_GLOW_INTENSITY` 0.7 or the resource’s current value).
- **Background pulse:** A full-screen **ColorRect** (white, alpha 0 → `pulse_bg_alpha` → 0) is used; no background shader change.
- **Stage clear:** Same overlay with a cyan-tinted color and slightly higher alpha; no new materials.

---

## BPM presets (recommended)

| Preset | BPM | Use |
|--------|-----|-----|
| **Slow** | 110 | Calmer, more space between beats. |
| **Default** | 120 | Balanced rhythm. |
| **Up-tempo** | 130 | More energetic; keep pulse params subtle. |

## Pulse parameters (safe ranges)

| Setting | Safe range | Notes |
|---------|------------|--------|
| **BPM** | 90–160 | 110–130 recommended; high BPM can feel busy. |
| **pulse_glow_boost** | 0.06–0.18 | Keep ≤ 0.18 for comfort; no nausea. |
| **pulse_glow_duration** | 0.06–0.12 | 0.1s default; short so it doesn’t distract. |
| **pulse_bg_alpha** | 0.01–0.025 | Keep subtle. |
| **enemy_pulse_scale** | 1.02–1.05 | Tiny so enemies breathe, not pop. |
| **Stage clear glow** | 1.25×–1.45× | 1.35× in code. |

---

## Main.tscn changes

- **BeatDust** (CPUParticles2D): Under root (Main), z_index 50, amount 6, lifetime 0.35, explosiveness 1, emission_shape point, spread 180°, low velocity, small scale, rainbow gradient (SubResource), additive material. Position is set each beat by BeatConductor to the camera center.

---

## Safety (TASK 5)

- **Hitstop:** Beat timer uses `_process(delta)`. When `Engine.time_scale` is reduced (hitstop or player damage), delta is scaled, so the beat timer advances more slowly and pulses effectively pause with the action. Pulses do not break or override hitstop.
- **Pause:** Call `BeatConductor.set_paused(true)` when the game is paused (e.g. menu); `set_paused(false)` on resume.
- **Subtle / no nausea:** Defaults keep glow boost ≤ 0.1, bg alpha ≤ 0.016, enemy scale pulse 1.03×. Do not increase these beyond the recommended ranges.
