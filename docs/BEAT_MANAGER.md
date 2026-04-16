# Beat Manager — Music-led gameplay timing

**Goal:** Gameplay rhythm aligns with an **internal beat grid**. Beat **guides** timing; input stays **responsive** (no lock).

---

## BeatManager (autoload)

**Script:** `scripts/autoload/beat_manager.gd`

- **Tracks:** BPM, beat timing, **bar** (4 beats), **phrase** (4 bars = 16 beats).
- **Signals:** `beat_pulse` (every beat), `bar_pulse` (every 4 beats), `phrase_pulse` (every 16 beats).
- **API:**
  - `get_bpm()` / `set_bpm(value)` — BPM 90–160.
  - `get_beat_index()` — global beat count.
  - `get_bar_index()` — current bar (beat_index / 4).
  - `get_phrase_index()` — current phrase (beat_index / 16).
  - `get_beat_phase()` — 0..1 within current beat (for subdivisions).
  - `get_seconds_to_next_beat()` — seconds until next beat.
  - `set_paused(bool)` / `is_paused()` — freeze beat (e.g. pause menu).

- **Timer:** Runs in `_process(delta)`; delta is scaled by `Engine.time_scale`, so beat pauses with hitstop/time slow.

---

## BeatConductor (visual, driven by BeatManager)

- **No internal timer.** Connects to `BeatManager.beat_pulse`; on each beat: glow pulse, background overlay, dust, enemy scale pulse. Still emits `beat_pulse` for backward compatibility (WaveSpawner, thruster_fx, weapon_burst, etc.).
- **Ignition amplifies beat:** Listens to `EventBus.build_ignited`. For a short window (~1.8 s), pulse glow and background alpha are multiplied by `ignition_boost_mult` (default 1.4). Background pulses more strongly; beat guides timing, input unchanged.

---

## Gameplay hooks to beat

| System | Hook | Behaviour |
|--------|------|-----------|
| **Weapon cadence** | BeatConductor.beat_pulse (via BeatManager) | Burst weapon fires on beat; other weapons can use `get_beat_phase()` for subdivisions. Cadence aligns; input not locked. |
| **Enemy waves** | BeatConductor.beat_pulse | WaveSpawner spawns on **next beat** when pending. For phrase-aligned waves: connect to `BeatManager.phrase_pulse` (e.g. every phrase start = wave pulse or intensity bump). |
| **Boss attacks** | BeatManager API | Boss can schedule attacks to **beat drops** using `get_seconds_to_next_beat()`, `get_beat_index()`, or `bar_pulse` / `phrase_pulse`. |

---

## Visual

- **Background pulses lightly on beat** — BeatConductor (glow + overlay) on each BeatManager beat.
- **Ignition amplifies beat temporarily** — Build ignition sets a short window where pulse strength is higher; then back to normal.

---

## Important

- **Gameplay must still feel responsive.** Beat **guides** timing (spawns, cadence, boss patterns); it does **not** lock or delay player input. Input is always immediate.
- **Beat grid is internal** — No audio file required; BPM and timer define the grid. Optional: future music can sync to same BPM.

---

## Files

- `scripts/autoload/beat_manager.gd` — BPM, beat/bar/phrase, signals.
- `scripts/autoload/beat_conductor.gd` — Visual response to beat; ignition boost; forwards beat_pulse.
- `docs/BEAT_PULSE_SYSTEM.md` — Legacy doc; timing now owned by BeatManager.
- `docs/RHYTHM_FLOW_DESIGN.md` — Flow and rhythm design.
