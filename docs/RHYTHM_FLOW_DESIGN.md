# Rhythm flow design — Uninterrupted momentum

**Goal:** The player feels **carried by momentum and cadence**. Minimal hard stops; transitions are smooth; the world pulses with action. Rhythm is the spine of the experience.

---

## Flow rules

- **Minimal hard stops** — Avoid full freezes (e.g. `Engine.time_scale = 0`) except where necessary (e.g. game-over, true pause menu). Prefer brief, beat-synced pauses (hitstop, ignition) that resolve within the same cadence.
- **Transitions are smooth** — Stage clear → upgrade → next stage should feel like a **continuation**, not a break. Use stage_clear_pulse (glow + tint) as the emotional beat, then bring in the upgrade UI with a soft fade. **World slows, does not stop:** `Engine.time_scale = UPGRADE_CHOICE_TIME_SCALE` (e.g. 0.22) during choice so beat and atmosphere keep running.
- **Upgrades feel like continuation, not interruption** — Upgrade choice is part of the run’s rhythm. **No hard pause:** time scale stays ~0.22 so background keeps breathing and weapon can idle. UI: upgrades appear as **light constructs** (soft glow cards), minimal framing, selection feels like **tuning energy**. Hint: “Tune and continue” encourages quick decision. See **docs/UPGRADE_FLOW.md**.

---

## Combat pacing

- **Weapon cadence leads tempo** — BeatConductor BPM (e.g. 120) is the reference. Weapons are **light instruments** (see **LIGHT_LANGUAGE.md**): burst fires on beat, beam breathes, spread/homing have distinct pulse timing. Fire rates and patterns should align to or subdivide the beat so shots feel in time.
- **Enemy waves align with rhythm** — WaveSpawner defers spawns to the **next beat** (`_pending_spawn` + `beat_pulse`). Spawn delay phases (ramp / chaos / peak) still drive *when* a spawn is due, but the actual spawn happens on beat. No mid-beat spawn pop.
- **Boss attacks follow beat structures** — Boss patterns (telegraph → attack → cooldown) should use beat-aligned timings where possible (e.g. phase changes on beat, attack windups in multiples of beat length). See **BOSS_DESIGN.md** for telegraph hierarchy; add rhythm alignment to pattern design.

---

## Visual response

- **Background pulses gently with action** — BeatConductor drives glow + overlay pulse every beat; AtmosphereOpacityController and AtmosphereBeauty use beat multiplier. EmotionFeedback adds breath and tint by game state. Result: the world breathes and brightens in time with the player, not at random.
- **Ignition moments amplify rhythm** — Build ignition (BuildIgnitionFX + WeaponLightController) is a **system coming online**: world brightness rise, cool tint, subtle time slow, light echo. It extends the rhythm (slight slow, then release), it doesn’t break it. No explosion, no full-screen flash.
- **Hit effects timed, not random** — Hitstop and hit flash use fixed, short durations (e.g. 0.065s hitstop, 0.09s flash). Muzzle flash duration comes from LightLanguage (weapon cadence). Combo and world ripple (VisualRhythmController) are throttled or triggered by discrete events so they feel like part of the same pulse, not noise.

---

## Avoid

| Avoid | Prefer |
|-------|--------|
| **Sudden pauses** | Brief, intentional dips (hitstop, ignition) that resolve within 1–2 beats |
| **Menu-like interruptions** | Overlay or side panel for upgrades; beat can continue at low scale or with “reward” state |
| **Jarring UI overlays** | UI that fades in with rhythm, stays readable without full-screen takeover |
| **Random hit/hitstop timing** | Fixed durations; optional: trigger hitstop on beat or half-beat for consistency |
| **Spawns mid-beat** | Spawn on next beat (WaveSpawner already does this) |
| **Weapon fire ignoring tempo** | Fire rate and burst patterns aligned to BPM (Burst weapon already waits for beat) |

---

## Implementation reference

| System | Role in rhythm flow |
|--------|----------------------|
| **BeatManager** | Single source of beat **grid**: BPM, beat/bar/phrase, `beat_pulse`, `bar_pulse`, `phrase_pulse`. Timer scaled by `Engine.time_scale`. See **docs/BEAT_MANAGER.md**. |
| **BeatConductor** | **Visual** response to beat (glow, overlay, dust, enemy pulse). Driven by `BeatManager.beat_pulse`; emits `beat_pulse` for backward compat. Ignition temporarily amplifies pulse. |
| **WaveSpawner** | Spawns on beat when `_pending_spawn`; phase delays (ramp/chaos/peak) set *when* to set pending, not when to instantiate. |
| **Weapon cadence** | LightLanguage per-weapon rhythm (burst, beam, spread, etc.); Burst weapon waits for beat to fire next volley. Muzzle flash duration from cadence. |
| **StageManager** | Stage clear: `stage_clear_pulse()` then short delay then `time_scale = 0` and upgrade UI. **Design target:** make this feel like a breath then continuation; consider keeping beat running or soft transition. |
| **Hitstop** | Single time-scale manager; hitstop and time_scale_dip use fixed durations; beat advances with scaled delta so it stays in sync. |
| **BuildIgnitionFX / WeaponLightController** | Ignition = rhythm highlight (brightness, tint, time slow, echo); no explosion. |
| **VisualRhythmController** | Shot/combo/boss phase trigger world ripple (throttled); timed, not random. |

---

## Related docs

- **BEAT_PULSE_SYSTEM.md** — BeatConductor wiring, BPM, pulse params.
- **RHYTHM_LAYER_DELIVERABLES.md** — Combat sync, spawn on beat, stage clear pulse.
- **LIGHT_LANGUAGE.md** — Weapon cadence, build ignition as emotional highlight.
- **EMOTIONAL_FEEDBACK_LAYER.md** — World reacts to actions; emotion stays in atmosphere.
- **BOSS_DESIGN.md** — Telegraph hierarchy; add beat-aligned pattern design where applicable.
