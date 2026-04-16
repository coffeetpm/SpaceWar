# HUD Swap Instructions — Neon Sci-Fi Overhaul

This doc describes the new HUD layout and how to safely revert or replace it.

---

## What Changed

### Part 1 — Player movement (1.5x)

| Script | Change |
|--------|--------|
| `scripts/player/player_controller.gd` | `MAX_SPEED` 280 → 420, `ACCELERATION` 1200 → 1800, `FRICTION` 920 → 1380 |
| `scripts/player/thruster_fx.gd` | Speed ratio denominator 300 → 420 |
| `scripts/vfx/camera_shake.gd` | `follow_smoothing` 5 → 6, added `look_ahead_scale` 0.06; target position includes velocity look-ahead |
| `scripts/main/main.gd` | Removed direct camera position set in `_process`; follow is handled by CameraShake |

### Part 2 — HUD structure

- **Top:** `TopBar` panel with `RunStatusLabel` (minimal run status: "Burst N" / "Boss!").
- **Right panel:** `HUDPanel` with:
  - **TimerLabel** — largest (26px), countdown.
  - **WaveLabel** — small subtitle (11px).
  - **HPBar** — ProgressBar (neon fill) + **HPLabel** (numeric).
  - **BuildIdentity** — weapon · force (e.g. "Spread · Temporal").
  - **EarnedLabel** / **TotalCurrencyLabel** — currency.
- **Center:** Notifications created by `game_hud.gd`: ignition text, CLEAR label, boss reward, BossClearFlash (clean flash on boss clear).

### Styles (main.tscn)

- **StyleBoxFlat_hud:** Glass panel (dark semi-transparent bg), thin neon border, soft shadow glow.
- **StyleBoxFlat_topbar:** Thin top bar, bottom border only.
- **StyleBoxFlat_hp_bg / StyleBoxFlat_hp_fill:** HP bar background and fill (neon blue).

### Interaction feedback

- **Upgrade picked:** `EventBus.upgrade_picked` → HUD panel brief brightness pulse (modulate tween).
- **Player damaged:** `EventBus.player_damaged` → HUD panel brief red tint (modulate tween).
- **Boss clear:** `boss_clear_show_cleared` → CLEAR label + full-HUD clean flash (ColorRect fade out).

---

## Node Paths (keep for compatibility)

StageManager and game_hud rely on these paths. Do not rename if you want existing logic to keep working:

- `UI/HUD`
- `UI/HUD/TopBar/RunStatusLabel`
- `UI/HUD/HUDPanel`
- `UI/HUD/HUDPanel/WaveLabel`
- `UI/HUD/HUDPanel/TimerLabel`
- `UI/HUD/HUDPanel/HPBar`
- `UI/HUD/HUDPanel/HPLabel`
- `UI/HUD/HUDPanel/BuildIdentity`
- `UI/HUD/HUDPanel/EarnedLabel`
- `UI/HUD/HUDPanel/TotalCurrencyLabel`
- `UI/HUD/RunCompleteLabel`

---

## Reverting to the old UI

1. **Restore old HUD layout in main.tscn**
   - Remove `TopBar` and `RunStatusLabel`.
   - Remove `HPBar` and `BuildIdentity` from `HUDPanel`.
   - Restore original order and offsets for WaveLabel, TimerLabel, HPLabel, EarnedLabel, TotalCurrencyLabel (see git history or backup).
   - Restore original `StyleBoxFlat_hud` (no shadow) and remove `StyleBoxFlat_topbar`, `StyleBoxFlat_hp_bg`, `StyleBoxFlat_hp_fill`.

2. **Restore game_hud.gd**
   - Remove `@onready` refs to `_hud_panel`, `_hp_bar`, `_build_identity`.
   - Remove `_on_upgrade_picked`, `_on_player_damaged`, `_flash_boss_clear`, `_on_build_ignited`, `_update_build_identity`, `_on_run_started`.
   - Remove HP bar and build identity update from `_process`.
   - Restore original CLEAR and BossUnlockedLabel creation (no BossClearFlash).

3. **StageManager**
   - In `_update_hud()`, remove the block that sets `TopBar/RunStatusLabel`.
   - Optional: remove `EventBus.upgrade_picked.emit()` from `_on_upgrade_chosen` if you remove the upgrade-pulse feature.

4. **EventBus**
   - Optional: remove `signal upgrade_picked` if nothing else uses it.

---

## Adding a new HUD scene

To swap in a completely different HUD scene:

1. Create your HUD scene (e.g. `scenes/ui/my_hud.tscn`) with a root Control.
2. Ensure it has the same node paths above (or add a thin adapter script that forwards to your nodes).
3. In main.tscn, replace the children of `UI/HUD` by instancing your scene as the only child and naming key nodes as above, **or** keep `UI/HUD` as the root and instance your scene as a child, then in game_hud.gd / StageManager use your node paths.
4. If your HUD uses different paths, update `game_hud.gd` and `stage_manager.gd` to use `get_node_or_null("YourPath")` for every label/panel they reference.

---

## Art direction

HUD colors are aligned with the existing palette (cyan/blue for UI, no change to combat/enemy/background palette). To adjust:

- Panel border / glow: edit `border_color` and `shadow_color` in `StyleBoxFlat_hud` (main.tscn).
- Text: `theme_override_colors/font_color` on each Label.
- HP fill: `StyleBoxFlat_hp_fill` `bg_color`.
