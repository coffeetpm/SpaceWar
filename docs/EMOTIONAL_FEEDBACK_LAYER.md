# Emotional feedback layer (Tetris Effect–style)

**Goal:** The world reacts emotionally to player actions. Not louder — **more expressive**. Gameplay clarity always priority; emotion stays in atmosphere layer.

---

## Triggers → emotion

| Trigger | Target state | Duration (then decay to calm) |
|--------|---------------|-------------------------------|
| **Weapon ignition** (build_ignited) | Release | 2 s |
| **Build synergy** (first_synergy_triggered) | Focus | 1 s |
| **Build synergy** (second_synergy_triggered) | Release | ~1.5 s |
| **Boss defeat** | Release | 3 s |
| **Stage clear** | Release | 2 s |
| **Low HP** (player_damaged) | Tension | 6 s |
| **Run start** | Calm | — |

Transitions between states are **smooth** (lerp). No hard cuts.

---

## Emotion states

| State | Use | Background tone | Breath | Shimmer | Pulse |
|-------|-----|-----------------|--------|---------|--------|
| **Calm** | Default, run start | Neutral | 1.0 | 0 | 0 |
| **Tension** | After player damage | Slight warm | 1.12 | 0.25 | 0.15 |
| **Release** | Build ignition, stage clear, boss defeat | Cool / cyan | 1.06 | 0.45 | 0.25 |
| **Focus** | First synergy | Slight blue | 0.96 | 0.08 | 0.05 |

---

## World responses (atmosphere only)

- **Background color tone shift** — Fullscreen overlay (CanvasLayer -202), very low alpha tint. Calm = none; tension = warm; release = cool; focus = slight blue.
- **Light intensity breathing** — Atmosphere opacity multiplied by emotion breath intensity (parallax, nebula, star clusters, dust). Tension = slightly stronger breath; focus = slightly calmer.
- **Distant particles shimmer** — Dust scale (AtmosphereBeauty) scales with emotion shimmer strength. Release = more visible shimmer; tension = subtle.
- **Environmental pulse waves** — BeatConductor world ripple and environmental pulse overlay alpha multiplied by `1 + emotion_pulse_strength`. Release/tension make existing pulses slightly more expressive.

All of the above are **additive to existing** atmosphere; they do not replace combat opacity or focus. Gameplay layer is never tinted or softened by emotion.

---

## Implementation

- **EmotionFeedback** (autoload) — Holds current/target emotion, lerps each frame. Connects to EventBus (run_started, build_ignited, first_synergy_triggered, second_synergy_triggered, boss_defeated, stage_cleared, player_damaged). Draws emotion tint overlay (layer -202). Exposes `get_emotion_tint()`, `get_emotion_breath_intensity()`, `get_emotion_shimmer_strength()`, `get_emotion_pulse_strength()`.
- **AtmosphereBeauty** — Multiplies opacity by `EmotionFeedback.get_emotion_breath_intensity()`. Scales dust by emotion shimmer.
- **AtmosphereOpacityController** — Multiplies parallax/StarDust opacity by emotion breath intensity.
- **BeatConductor** — `request_world_ripple` and `request_environmental_pulse` multiply overlay alpha by `1 + get_emotion_pulse_strength()`.

---

## Rules

- **Gameplay clarity always priority.** No emotion on gameplay layer (player, bullets, enemies, boss).
- **Emotion stays in atmosphere layer.** Tint overlay, breath, shimmer, and pulse only affect background/parallax/particles.
- **Smooth transitions.** No sudden jumps; lerp toward target state.
- **Not louder.** Expressive, not overwhelming. Keep alpha and multipliers low.
