# Boss: Refraction Examiner (LIGHT type)

## Identity

**Refraction Examiner** — precision skill test. Teaches players to read beam attacks and move precisely. Build helps but does not win the fight; skill-based survival.

---

## Attack rules (every attack)

1. **Telegraph phase** — visible wind-up before damage.
2. **Readable direction** — player can see where the beam will go.
3. **Dodge window** — time to move (telegraph duration, optionally + lock delay).

---

## Attacks

| Attack | Description |
|--------|-------------|
| **Sweep Beam** | Slow scan; clear telegraph. Phase 1. |
| **Reflection Beam** | Beam bounces via nodes; cross angles. Phase 2. |
| **Precision Grid** | Beam net with moving safe gaps. Phase 3. |
| **Lock Shot** | Delayed aim at player; direction locked at telegraph start, then fire. Phase 2+. |

---

## Balance

- **No random spam** — fixed intervals; deterministic timing (e.g. Precision Grid uses no RNG).
- **Skill-based survival** — reading telegraphs and positioning win.
- **Build helps but does not win** — boss threatens all builds; no build trivializes the fight.

---

## Visual tone

- **Clean, sharp, minimal noise, high readability.**
- Telegraphs: `BOSS_TELEGRAPH_SHARP` when `sharp_style = true`; thinner glow.
- Boss palette: `ArtDirection.BOSS_LIGHT_*`, `BOSS_TELEGRAPH_*`.

---

## Fight duration & phases

~60 seconds. `StageManager.get_boss_phase()`: 1 = 0–20s, 2 = 20–40s, 3 = 40–60s.

- **Phase 1:** Sweep Beam only (fixed interval).
- **Phase 2:** Sweep + Reflection Beam + Lock Shot (fixed intervals).
- **Phase 3:** Sweep + Reflection + Lock Shot + Precision Grid.

---

## Node structure

```
RefractionCore (Node2D) — BOSS_DISPLAY_NAME = "Refraction Examiner"
├── Visual (Shell, Core, Halo)
├── BeamEmitters
│   ├── SweepBeam (BossBeamSweep) + TelegraphLine
│   ├── ReflectionBeams (BossBeamReflection)
│   ├── LockShot (BossLockShot) + TelegraphLine
│   └── GridBeams (BossBeamGrid / Precision Grid)
└── PhaseController (BossPhaseController)
```

---

## Scripts

- **refraction_core.gd** — Root; Refraction Examiner identity; halo rotation.
- **boss_phase_controller.gd** — Fixed intervals; Sweep / Reflection / Lock Shot / Precision Grid; no spam.
- **telegraph_line.gd** — Clean sharp telegraph; optional `sharp_style`.
- **attacks/boss_beam_base.gd** — Rule: telegraph → readable direction → dodge window; base for beam attacks.
- **attacks/boss_beam_sweep.gd** — Sweep Beam.
- **attacks/boss_beam_reflection.gd** — Reflection Beam.
- **attacks/boss_beam_grid.gd** — Precision Grid (deterministic).
- **attacks/boss_lock_shot.gd** — Lock Shot (delayed aim at player; direction locked at start).

---

## Boss clear feedback (technical accomplishment)

When boss burst ends (60s), **mastery not spectacle**:

1. **Stop all projectiles** — `BulletPool.clear_all()`.
2. **0.25s silence** — no beat pulse, no explosion.
3. **Boss core collapses inward** — `RefractionCore.play_collapse_inward(0.4)` (Visual scale → 0).
4. **One clean radial light pulse** — `BossClearVFX` on `boss_clear_radial_pulse`; single ring, expand + fade.
5. **HUD: CLEAR** — `EventBus.boss_clear_show_cleared`; label 1.5s.
6. **Subtle glow on player** — `EventBus.boss_clear_player_glow`; modulate ~1s then restore.

Rules: no explosion spam, no particle flood; minimal, precise, clean. Emotion: *"I mastered the fight."*

---

## Boss reward: gameplay unlock (no stat boost)

After the clear sequence, the player is granted **one free meta unlock** so they feel *"I unlocked a new way to play"*:

- **New weapon variant** — one locked start weapon (Beam / Spread / Drones / Pulse / Homing) via `SaveManager.grant_unlock_weapon(id)`.
- **New synergy trigger** — one locked synergy effect (e.g. Chain Shock, Spreading Fire) via `grant_unlock_synergy_effect(id)`.
- **New force interaction** — one locked force-pair effect (LIGHT+SPACE, SPACE+TIME) via `grant_unlock_force_pair_effect(id)`.

Category is chosen from available locked groups (weapon / synergy / force); one item from that group is unlocked. No currency cost; no stat boost. HUD shows *"Unlocked: [display name]"* for 2.5s.
