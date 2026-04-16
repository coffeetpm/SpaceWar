# EXP + Level Up (Vampire-Survivors style) — Deliverables

## Summary

- Drops = EXP. EXP bar under HP. Level up → freeze world → 3 upgrade choices with icons → pick one → unfreeze, state RUNNING.
- Run flow unchanged: RUNNING ↔ UPGRADE_PICK only; level-up uses same UPGRADE_PICK state and unfreeze returns to RUNNING.

---

## File paths and scene nodes

### Scripts

| Path | Role |
|------|------|
| `scripts/autoload/event_bus.gd` | `exp_collected(amount: int)`, `level_up(level: int)` signals |
| `scripts/autoload/run_state.gd` | `gameplay_frozen: bool` — freeze gameplay (movement, enemies, bullets, timers); UI stays interactive |
| `scripts/player/player_controller.gd` | `level`, `exp`, `exp_to_next`; `_on_exp_collected`, `_do_level_up()`; resets on `run_started`; `_physics_process` skips when `gameplay_frozen` |
| `scripts/pickups/currency_pickup.gd` | Emits `EventBus.exp_collected.emit(value)` on collect (magnet behaviour unchanged) |
| `scripts/stage_manager.gd` | `_on_level_up`: sets `stage_state = UPGRADE_PICK`, `gameplay_frozen = true`, hides overlays, emits `upgrade_choice_requested(choices)`. `_on_upgrade_chosen`: if level-up, unfreeze and `stage_state = RUNNING` |
| `scripts/ui/game_hud.gd` | EXP bar + Level label under HP; `_exp_pop_label` "+N EXP" pop on `exp_collected`; weapon icon |
| `scripts/upgrades/upgrade_choice_ui.gd` | Cards: icon (TextureRect), title, 1-line effect, tags; keys 1/2/3 (and KP 1/2/3) to pick; hint "1 2 3 or click" |
| `scripts/enemies/enemy_base.gd` | `_physics_process` / `_process` return when `RunState.gameplay_frozen` |
| `scripts/enemies/wave_spawner.gd` | `_process` returns when `RunState.gameplay_frozen` |
| `scripts/weapons/bullet.gd` | `_physics_process` returns when `RunState.gameplay_frozen` |
| `resources/upgrades/upgrade_data.gd` | `icon: Texture2D`, `icon_path: String`; id, display_name, description, tags, primary_force; apply via UpgradeManager |

### Scenes / nodes

| Scene / Node | Notes |
|--------------|--------|
| `scenes/main/main.tscn` | World/StageManager, UI/HUD, UI/UpgradeChoice, UI/GameOver — no structural change |
| HUD (e.g. UI/HUD/HUDPanel) | EXPBar, EXPLevelLabel, ExpPopLabel, WeaponIcon added in code by `game_hud.gd` |
| UI/UpgradeChoice | UpgradeChoiceUI script; ChoiceContainer holds 3 cards built from UpgradeData |

### Freeze vs state machine

- **Freeze:** `RunState.gameplay_frozen = true` (level-up) / `false` (after pick). No `SceneTree.paused`; gameplay nodes check the flag.
- **State:** Level-up sets `stage_state = State.UPGRADE_PICK`; after upgrade pick (level-up case) sets `stage_state = State.RUNNING`. Burst-end flow unchanged.

---

## Upgrade data binding

- UI reads from `UpgradeData`: `display_name`, `description`, `primary_force`, `tags`, `icon`, `icon_path`.
- Effect line: first line of `description` (trimmed, ~60 chars).
- Tags line: `primary_force` (TIME/LIGHT/SPACE) + `tags`, joined by " · ".
- Apply: `UpgradeManager.apply(upgrade)` (existing applier).

---

## Icons

- If `UpgradeData.icon` or `UpgradeData.icon_path` is set, that texture is used.
- Else procedural placeholder by id/primary_force (circle, ring, triangle, cone, beam, square).
