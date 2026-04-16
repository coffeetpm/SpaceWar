# Weapon Evolution — Stable Tech to Experimental Phenomena

**Goal:** Early gameplay feels engineered and precise. Later builds introduce unstable experimental effects.

**Evolution rule:** Player should feel **"I built a machine"** → **"I unlocked something unstable"**.

---

## Tier 1 — Core Tech

Weapons behave like **engineered devices**:

- **Beam emitters** — Lock-on, stable energy stream.
- **Orbit drones** — Predictable orbital nodes.
- **Pulse cannons** — Burst, spread, homing, rear: rhythmic discharge.
- **Targeting systems** — Clear telegraphs, sharp emission.

**Visuals:** Clean. Sharp emission. Predictable behaviour.

**When:** Run has only the weapon’s primary force (no second force, no build ignition yet). `SynergyManager.get_evolution_tier()` returns `1`.

---

## Tier 2 — Experimental

As builds stack (second force unlocked, or build ignition triggered):

- **Time distortion trails** — TIME + LIGHT → afterimage; delayed duplicate shots. Trails can read as “stretched in time”.
- **Refraction duplicates** — LIGHT + SPACE → bending beams; extra projectiles at angles. Refraction splits, not magic.
- **Delayed explosions** — Shockwave Cascade (weapon + delay/echo); cascade behaviour feels like delayed triggers.
- **Space bending shots** — Bending beams, gravity slow zones (SPACE + TIME). Shots that curve or zones that distort.

**Visuals:** Less stable, more dynamic, **but still readable**. Slight trail flicker, hue shift, or “unstable” accent when tier is 2; no clutter.

**When:** Run has **2+ forces** (e.g. weapon LIGHT + upgrade TIME) or **at least one build ignition** (e.g. Beam Net, Shockwave Cascade). `SynergyManager.get_evolution_tier()` returns `2`.

---

## Mapping to Existing Systems

| Experimental effect   | System / trigger                    | Implementation hint                          |
|-----------------------|--------------------------------------|-----------------------------------------------|
| Time distortion trails| TIME + LIGHT → afterimage            | SynergyManager `_effect_afterimage`; delayed bullet spawn. Trail: optional time-warp visual when TIME in run. |
| Refraction duplicates | LIGHT + SPACE → bending_beams        | SynergyManager `_effect_bending_beams`; extra angled projectiles.           |
| Delayed explosions    | Weapon + delay/echo → Shockwave Cascade | Build ignition; gameplay already has cascade. Explosion VFX can add micro-delay or second pop when tier 2. |
| Space bending shots   | SPACE + TIME → gravity_slow          | SynergyManager `_effect_gravity_slow`; time_scale_dip + zone visual.         |

---

## API

- **SynergyManager.get_evolution_tier()** → `1` (Core Tech) or `2` (Experimental).
  - Returns `2` if `get_run_forces().size() >= 2` or `_ignited_effects.size() > 0`, else `1`.
- **Use tier for:**  
  - Visuals: muzzle/trail/beam “stability” (tier 2 = slight instability: jitter, hue shift, or scanline).  
  - UI: optional “Experimental” or “Unstable” label when tier 2.  
  - Audio: optional layer when tier 2 (e.g. subtle distortion).

---

## Readability

- Tier 2 effects remain **readable**: hitboxes and silhouettes stay clear.
- “Unstable” = **feel**, not noise: one or two subtle cues (e.g. trail modulation, brief scanline on fire) are enough.
- See **docs/VISUAL_IDENTITY.md** (tech light, sharp edges) and **docs/LIGHT_LANGUAGE.md** (rhythm, no constant glow).

---

## Visual Evolution Feedback (triggered moments only)

Player sees when tech becomes experimental via one-shot feedback at:

| Trigger | Feedback |
|--------|----------|
| **First synergy** (run reaches 2 forces) | Refraction flicker (full-screen tint, 0.14s). Beam weapon: beam stability flicker (brief scale/alpha pulse on beam). |
| **Second synergy** (first build ignition) | Temporal echo (full-screen tint, 0.2s). |
| **Ignition point** (every `build_ignited`) | Energy distortion rings (WeaponLightController). Refraction flicker + temporal echo. |

- **EventBus:** `first_synergy_triggered`, `second_synergy_triggered` (emitted by SynergyManager).
- **EvolutionFeedbackController:** Listens to the above and `build_ignited`; plays refraction flicker and temporal echo overlays. Not constant; triggered moments only.
- **Beam:** `weapon_beam.gd` connects to `first_synergy_triggered` and calls `WeaponBeam.play_stability_flicker()` for a brief beam stability change.

---

## Optional Visual Hook (Tier 2)

- **Player bullet glow:** When `get_evolution_tier() == 2`, `bullet.gd` applies a slight extra modulation to player bullet glow alpha (0.97–1.03 from a faster sin) so emission feels less stable but still readable.
