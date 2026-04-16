# Light Language — Weapons as Light Instruments

**Goal:** Weapons are remembered by rhythm and light behaviour, not projectile count.

---

## Core Principle

Weapons are **light instruments**. Each weapon has:

- **Unique emission rhythm** — when and how often light pulses
- **Distinct beam/pulse pattern** — shape and timing of the emission
- **Identifiable glow timing** — glow is never constant; pulse on fire, dim between shots

---

## Cadence Rules (Weapon-Specific)

| Weapon | Rhythm type | Visual behaviour |
|--------|-------------|------------------|
| **Beam** | Continuous breathing | Lock-on telegraph then beam; intensity breathes (sin) during pulse. |
| **Burst** | Rhythmic packets | Short flashes per shot; 3-shot burst then pause; dim between packets. |
| **Spread** | Fan wave | One pulse per volley; fan of pellets = single wave pulse at origin. |
| **Homing** | Delayed glow | Trail/glow starts dim; ramps up after straight phase (curve = full glow). |
| **Rear** | Reactive pulse | Pulse only when moving; fire = one flash, no idle glow. |
| **Drones** | Orbit oscillate | Orbit trail alpha oscillates (sin); trail never constant. |

---

## Visual Rhythm

- **Glow is NOT constant.** Implementations:
  - **Pulse on fire** — muzzle flash and/or weapon glow spike on each shot (driven by `LightLanguage.get_glow_pulse_duration(weapon_id)`).
  - **Dim between shots** — no persistent bright glow on weapon or projectile; `dim_between_mult` in cadence config can drive optional “between shot” dim state.
  - **React to combo / build ignition** — when build triggers (`EventBus.build_ignited`), add temporary rhythm layer + light echo + brief harmonic glow (see Build Synergy).

---

## Build ignition — emotional highlight (system coming online)

When a build triggers (weapon + tag ignition), the moment is an **emotional highlight**, not an explosion. Feels like: **a system coming online.**

1. **World brightness rises briefly** — `BeatConductor.request_world_ripple()` from BuildIgnitionFX (glow ~1.2×, cool tint).
2. **Color tone shifts** — Cool/cyan fullscreen overlay (very low alpha), then fades.
3. **Subtle time slow** — `EventBus.time_scale_dip_requested` (~0.35 s at 0.72×); moment of focus.
4. **Light echo radiates outward** — 4 expanding rings from player/screen center (WeaponLightController). No explosion.

**No explosion:** No hit flash, no heavy screen shake. Constants: `BUILD_SYNERGY_ECHO_RINGS`, `BUILD_SYNERGY_ECHO_SPEED`, `BUILD_SYNERGY_ECHO_MAX_RADIUS` in `LightLanguage`; ignition glow/tint/duration in `BuildIgnitionFX`.

---

## Readability Constraint

- **Gameplay silhouettes remain sharp.** Light never hides hitboxes.
- Overlay alpha and glow strength are capped (`GLOW_MAX_ALPHA_OVERLAY`, trail/core contrast).
- Muzzle flashes and echoes are short-lived; no constant bloom on player/enemy/bullet silhouettes.

---

## Implementation

- **LightLanguage** (autoload): `LIGHT_CADENCE` per weapon_id; `get_emission_rhythm()`, `get_glow_pulse_duration()`, `get_beam_breath_speed()`, `is_delayed_glow_trail()`, `get_delayed_glow_initial_alpha()`, `get_orbit_oscillate_speed()`, etc.
- **WeaponLightController**: Listens to `build_ignited`; spawns light echo rings and requests harmonic environmental pulse.
- **MuzzleFlashVFX**: Uses `LightLanguage.get_glow_pulse_duration(weapon_id)` when available so flash duration is musical per weapon.
- **Beam** (`beam.gd`): During pulse, glow alpha breathes via `get_beam_breath_speed/min/max`.
- **Bullet** (homing): Trail/glow alpha ramps from `get_delayed_glow_initial_alpha` to 1.0 over `get_delayed_glow_ramp_sec` after straight phase.
- **Spread / Homing**: Emit `muzzle_flash_requested` at fire so they get a pulse (spread one per volley, homing one per shot).
- **OrbitDrone**: Trail added; alpha oscillates with `get_orbit_oscillate_speed` and min/max alpha.

---

## Files

- `scripts/autoload/light_language.gd` — Cadence config, rhythm types, build synergy constants, readability caps.
- `scripts/vfx/weapon_light_controller.gd` — Build ignition: light echo + harmonic glow.
- `scripts/vfx/muzzle_flash_vfx.gd` — Uses LightLanguage pulse duration.
- `scripts/weapons/beam.gd` — Breathing intensity during beam pulse.
- `scripts/weapons/bullet.gd` — Delayed glow for homing trail.
- `scripts/weapons/orbit_drone.gd` — Orbit trail with oscillating alpha.
