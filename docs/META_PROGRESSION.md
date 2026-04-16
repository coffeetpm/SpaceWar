# Meta Progression: New Possibilities (Minimal Stat Upgrades)

## Goal

- **Runs unlock new gameplay possibilities.** Each run matters; even failure advances progression (run fragments added on game over).
- **Currency:** **Energy Fragments.** Used for: unlocking new weapons, experimental modifiers (synergy/force), new systems (magnet tech, starting energy). See **docs/META_AND_PICKUP.md**.
- **Focus on new possibilities**, not power creep. **Minimal stat upgrades only:** small pickup magnet (magnet tech), slight starting energy (+5 fragments at run start). No flat +% damage/fire rate/HP.

---

## Unlock Categories

### 0. Refraction Duplication (first meta — new system)

- **Goal:** First unlock changes **how the game feels**, not just numbers. Player feels: *"I unlocked a system."*
- **What:** When projectiles travel, a **refracted echo path** appears: secondary light trajectory, **visual and functional** (echo deals 50% damage). Applies to all projectile weapons (spread, burst, homing, rear, synergy/force bullets) and to the beam (secondary beam at angle).
- **Rules:** Readable (echo is fainter, thinner trail); no clutter (one echo per shot, alternate ±angle); integrates with all weapons (BulletPool for projectiles, WeaponBeam for beam).
- **Cost:** `SaveManager.UNLOCK_COST_REFRACTION` (80). Appears first in System Lab under "Systems".

### 1. Weapon archetypes

- **What:** Start-weapon options at run start (Beam, Spread, Drones, Pulse, Homing).
- **Default:** Beam, Spread.
- **Unlocks:** Drones, Burst (Pulse), Homing.
- **Gate:** `SaveManager.get_unlocked_weapons()`; `WeaponSelectUI` only shows unlocked weapons.
- **Cost:** `SaveManager.UNLOCK_COST_WEAPON` (currency per weapon).

### 2. Synergy types

- **What:** Synergy effects that can appear as upgrade choices (e.g. afterimage, shockwave_split, electric_burst, bending_beams, gravity_slow, spreading_fire).
- **Default:** afterimage, shockwave_split.
- **Unlocks:** electric_burst, bending_beams, gravity_slow, spreading_fire (and any future synergy effect ids).
- **Gate:** `SaveManager.is_synergy_effect_unlocked(effect_id)`; `StageManager._get_upgrade_choices()` only adds synergy upgrades whose `synergy_effect` is unlocked.
- **Cost:** `SaveManager.UNLOCK_COST_SYNERGY`.

### 3. Force combinations

- **What:** Force-pair effects (LIGHT+TIME, LIGHT+SPACE, SPACE+TIME) that trigger during combat when the run has both forces.
- **Default:** afterimage (LIGHT+TIME).
- **Unlocks:** bending_beams (LIGHT+SPACE), gravity_slow (SPACE+TIME).
- **Gate:** `SaveManager.is_force_pair_effect_unlocked(effect_id)`; `SynergyManager._run_effect()` skips force-pair effects that are not unlocked.
- **Cost:** `SaveManager.UNLOCK_COST_FORCE_PAIR`.

---

## Implementation

- **SaveManager** (`scripts/autoload/save_manager.gd`):
  - **CURRENCY_DISPLAY_NAME** = "Energy Fragments". Persists `total_currency`, `unlocked_weapons`, `unlocked_synergy_effects`, `unlocked_force_pair_effects`, `magnet_level`, **starting_energy_level**, **refraction_duplication**.
  - **Refraction Duplication:** `is_refraction_unlocked()`, `unlock_refraction()` (cost 80). First meta unlock = new gameplay system.
  - Unlocks spend Energy Fragments and save. **Minimal stat:** `get_starting_energy_bonus()`, `unlock_starting_energy()` (+5 fragments at run start, cost 120, max level 1).
  - Constants: `ALL_WEAPON_IDS`, `ALL_SYNERGY_EFFECT_IDS`, `ALL_FORCE_PAIR_EFFECT_IDS` for UI and validation.

- **Refraction Duplication:** `BulletPool` spawns a refracted echo (rotated direction, 50% damage, fainter visual) for every player bullet when unlocked. `Bullet` supports `is_refraction_echo` (shorter/thinner trail, lower alpha). `WeaponBeam` adds a refraction pulse (secondary line at angle, 50% damage) when unlocked. System Lab shows "Refraction Duplication" as first unlock under "Systems".

- **WeaponSelectUI:** Uses `_get_available_weapons()` filtered by `SaveManager.get_unlocked_weapons()`.

- **StageManager._get_upgrade_choices():** Uses `_is_synergy_unlocked(upgrade)` so only unlocked synergy effects enter the pool. Stat upgrades (fire_rate, damage, max_hp) are always in-run options, not meta-unlocked.

- **SynergyManager._run_effect():** Before running a force-pair effect (afterimage, bending_beams, gravity_slow), checks `SaveManager.is_force_pair_effect_unlocked(effect_name)`.

---

## Unlock UI (to hook)

- **Where:** e.g. run-end menu, main menu, or dedicated “Meta” screen.
- **Actions:** Show list of lockable items (weapons / synergy effects / force pairs); on purchase call `SaveManager.unlock_weapon(id)` (or synergy / force_pair) and refresh.
- **Display:** Use `SaveManager.get_unlocked_weapons()` etc. to show locked vs unlocked; use `get_total_currency()` and `UNLOCK_COST_*` for affordability.

---

## Summary

| Unlock type     | Expands by                           | Not        |
|-----------------|--------------------------------------|------------|
| **Refraction**  | **New system: echo paths (visual + 50% dmg)** | —          |
| Weapon          | New start identity                   | +% damage  |
| Synergy type    | New upgrade effects in pool          | +% fire rate |
| Force pair      | New LIGHT/SPACE/TIME combo           | +% HP      |
| Magnet tech     | Pickup radius (minimal stat)         | —          |
| Starting energy | +5 fragments at run start (minimal)  | —          |

Focus: **new possibilities**. First meta = Refraction Duplication (new system feel). Only minimal stat upgrades (magnet, starting energy).
