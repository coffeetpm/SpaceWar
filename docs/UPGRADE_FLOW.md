# Upgrade selection flow — Preserve rhythm

**Goal:** Upgrades feel **integrated into the run rhythm**. No hard pause; world slows, background keeps breathing; selection feels like tuning energy.

---

## Interaction

- **World slows, does not stop** — `StageManager.UPGRADE_CHOICE_TIME_SCALE` (default 0.22). `Engine.time_scale` is set to this when upgrade choice is shown, so:
  - BeatConductor continues (delta is scaled; beat advances at ~22% speed).
  - Atmosphere and parallax keep breathing.
  - Weapon and player remain in scene; weapon can idle.
- **No hard pause** — Avoid `Engine.time_scale = 0` at upgrade. Flow is preserved.

---

## Visual

- **Upgrades appear as light constructs** — Each choice is a soft glow card (ColorRect with cool tint, low alpha). No heavy panel or menu frame.
- **Minimal UI framing** — No full-screen takeover. Cards are the only prominent UI; optional hint at bottom (“Tune and continue”).
- **Selection feels like tuning energy** — Hover brightens the construct slightly; click triggers a brief brighten then fade. No explosion or heavy feedback.

---

## Time

- **Quick decision encouraged** — Copy and presentation suggest “tune and go.” No timer required; the fact that the world is still moving (slow) reinforces that flow continues.
- **Implementation:** `scripts/upgrades/upgrade_choice_ui.gd` builds choice cards as Control + ColorRect + labels; `scripts/stage_manager.gd` uses `UPGRADE_CHOICE_TIME_SCALE` instead of 0 when entering upgrade state.

---

## Related

- **RHYTHM_FLOW_DESIGN.md** — Flow rules, minimal hard stops, upgrades as continuation.
- **BEAT_PULSE_SYSTEM.md** — BeatConductor uses scaled delta, so beat runs during slow-mo.
