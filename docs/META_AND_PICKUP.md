# Meta-progression and pickup flow

**Goal:** Runs unlock **new gameplay possibilities**. Each run matters; even failure advances progression. Currency is **Energy Fragments**. Pickup feel: **satisfying, automatic, flow-preserving** — no power creep, minimal stat upgrades only (magnet, slight starting energy).

---

## Currency: Energy Fragments

- **Name:** **Energy Fragments** (displayed in HUD, game over, System Lab).
- **Source:** Enemies drop fragments on death (KillDropVisual spawns CurrencyPickup).
- **Use:** Unlock new weapons, experimental modifiers (synergy/force), **magnet tech**, **starting energy** (slight bonus fragments at run start). Focus on **new possibilities**, not stat power creep.
- **Persistence:** Total Energy Fragments saved (SaveManager). On game over, run fragments + stage bonus are added; player spends in System Lab between runs.

---

## Between runs: System lab

- **When:** After game over, "System Lab" button opens the lab. Spend Energy Fragments, unlock tech, then Back or restart.
- **What:** Unlock **weapon archetypes**, **synergy categories**, **experimental tech** (force pairs, magnet tech, starting energy). Magnet: levels 1–3 (pickup radius). Starting energy: one unlock, +5 fragments at run start.
- **Persistence:** Unlocked content appears in future runs (weapons, synergies, force pairs, magnet level, starting energy).

**Implementation:** `scripts/ui/system_lab.gd` (SystemLab). Uses `SaveManager.CURRENCY_DISPLAY_NAME` ("Energy Fragments"); sections: Weapon archetypes, Synergy categories, Experimental tech (force pairs), Magnet tech, Starting energy.

---

## Magnet pickup (collection feel)

- **Base:** Pickup **attract radius** is **3×** original. Player no longer needs to get very close; orbs pull from further away.
- **Behaviour:** When player is near, fragments **accelerate toward player**; a **light trail** follows the orb. Tuned so collection feels **satisfying, automatic, flow-preserving**.
- **Magnet tech (meta):** In System Lab, player can buy magnet levels (cost per level, max 3). Each level adds radius bonus; stacks with base 3×.

**Implementation:** `scripts/pickups/currency_pickup.gd` — 3× radius, acceleration, trail; reads `SaveManager.get_magnet_radius_bonus()`.

---

## Emotion target

- **Each run matters:** Run fragments + burst bonus always added on game over. Even failure advances total Energy Fragments and run count.
- **New possibilities, not power creep:** Lab unlocks new weapons, synergies, force pairs, and minimal stat upgrades (magnet, starting energy). Focus remains on **new gameplay**, not flat stat gains.
- **Pickup:** Collection feels **satisfying**, **automatic**, **flow-preserving**.

---

## Files

- `scripts/autoload/save_manager.gd` — Energy Fragments (CURRENCY_DISPLAY_NAME), total_currency, record_run, unlock_weapon/synergy/force_pair, magnet, **starting_energy** (get_starting_energy_bonus, unlock_starting_energy).
- `scripts/pickups/currency_pickup.gd` — 3× attract radius, acceleration, light trail, magnet bonus.
- `scripts/ui/system_lab.gd` — System lab UI (Energy Fragments label, weapon archetypes, synergy categories, experimental tech, magnet, starting energy).
- `scripts/ui/run_end_menu.gd` — Creates SystemLab and "System Lab" button on game over.
- `scripts/stage_manager.gd` — Run start uses get_starting_energy_bonus(); game over / HUD labels use "Energy Fragments" / "Fragments earned".

See also **docs/META_PROGRESSION.md** for unlock categories and costs.
