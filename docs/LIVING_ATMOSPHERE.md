# Living, Rhythmic Atmosphere (Tetris Effect–style)

**Emotion target:** A breathing universe, not a cinematic wallpaper.  
**No cinematic visuals.** Subtle motion and breathing only.

---

## Atmosphere behaviour

- **Slow drifting nebula** — `nebula_drift.gdshader`: FBM noise, very low `drift_speed` (~0.035). Optional `breath_speed` for slow opacity oscillation (0.92–1.0).
- **Soft star clusters** — `star_clusters.gdshader`: Soft dots, small brightness variation (`twinkle`), slow drift, optional `breath_speed` for gentle alpha breath.
- **Distant light particles** — AtmosphereBeauty dust: low speed (2–8), long lifetime (12s), low saturation. Luminous shapes drift at ~8 px.

Everything feels **alive**, not explosive. **Visual identity:** background light reads as data flow, power grids, refraction fields — not cosmic magic (see **docs/VISUAL_IDENTITY.md**).

---

## Emotional feedback layer (Tetris Effect–style)

The world reacts **emotionally** to player actions — not louder, more expressive. States: **calm**, **tension**, **release**, **focus**. Smooth transitions.

**Triggers:** weapon ignition (build_ignited), build synergy (first/second), boss defeat, stage clear, low HP (player_damaged). **Responses:** background color tone shift (very low alpha overlay), light intensity breathing, distant particles shimmer, environmental pulse waves. All in **atmosphere layer only**; gameplay clarity always priority. See **docs/EMOTIONAL_FEEDBACK_LAYER.md**.

---

## Rhythm layer (background reacts to gameplay)

Beat-synced environmental reactions: the world subtly responds to rhythm. **A heartbeat, not fireworks.** All triggers use soft background pulse + slight color breathing + optional distant particle shimmer (BeatDust).

- **World ripple (weapon / combo / boss phase)** — Universe reacts to player actions like ripples in space. **Never strong, never distracting.** Triggers: **weapon fire cadence** (throttled), **combo increase** (consecutive kills in 1.5s window), **boss phase change**. Reactions: subtle background brightness pulse (glow ~1.01–1.015×), very soft **color shift wave** (overlay with tint: blue for shots, purple for combo, cyan for boss phase), optional **distant particle shimmer** (BeatDust) on combo ≥ 3. Implemented via **BeatConductor.request_world_ripple(duration, glow, overlay_alpha, trigger_dust, overlay_tint)** and **VisualRhythmController**; **ComboTracker** emits `combo_increased` when combo ≥ 2.
- **Enemy wave start** — `wave_started`: glow 1.02×, 0.18s; overlay alpha 0.006; triggers distant particle shimmer.
- **Boss spawn** — Boss spawn: 1.05×, 0.2s; overlay 0.008; dust.
- **Stage clear** — `stage_cleared`: glow 1.04×, 0.22s; overlay 0.008; dust. ParallaxController also runs stage progression brightness nudge (1.04 → 1.0 over 1.2s).

Implemented via **BeatConductor.request_environmental_pulse** (wave/stage/boss spawn) and **request_world_ripple** (weapon cadence, combo, boss phase) and **VisualRhythmController** wiring to EventBus. Never constant; all short-lived.

---

## Rhythm and flow

- **Background pulses gently with action** — Beat drives glow and atmosphere opacity; EmotionFeedback adds breath by state. Hit and ignition effects use **fixed, short durations** so they feel timed, not random. See **docs/RHYTHM_FLOW_DESIGN.md** (visual response, avoid sudden pauses).

---

## Visibility rule

Atmosphere **fades during heavy combat**.

- **ThemeManager.combat_density** (0–1) from active bullet count.
- **VisualLayers.ATMOSPHERE_COMBAT_FALLOFF = 0.35** → when many bullets, atmosphere opacity reduced by **up to 35%** (in the 20–40% range).
- AtmosphereOpacityController and AtmosphereBeauty multiply opacity by `get_atmosphere_opacity_multiplier()` so layers recede when the screen is busy.

---

## Lighting rule

- **Glow belongs to background**, not gameplay.
- **Gameplay:** Sharp edges, limited bloom (e.g. `crisp_gameplay_material`, glow_hdr_threshold 0.88).
- **Background:** Soft glow, low saturation, layered depth (parallax, nebula, star clusters, motifs).

---

## Breathing (never constant)

- **Global breath** — VisualLayers `get_atmosphere_breath_multiplier()`: 0.94–1.0 over ~14s. Applied to parallax and atmosphere beauty opacity.
- **Nebula shader** — `opacity * (0.92 + 0.08*sin(TIME*breath_speed))`.
- **Star clusters shader** — `col.a *= (0.94 + 0.06*sin(TIME*breath_speed))` plus per-star twinkle.

Result: subtle motion and breathing without cinematic sweeps.

---

## Files

- `scripts/autoload/emotion_feedback.gd` — Emotional feedback layer (calm/tension/release/focus, triggers, overlay, lerp).
- `scripts/autoload/visual_layers.gd` — Combat falloff, breath multiplier, stage progression multiplier.
- `scripts/vfx/atmosphere_opacity_controller.gd` — Parallax + StarDust opacity (combat, beat, breath, stage).
- `scripts/vfx/atmosphere_beauty.gd` — Nebula, star clusters, luminous shapes, dust; same opacity rules.
- `scripts/vfx/parallax_controller.gd` — Scroll, theme colors, stage progression brightness nudge.
- `scripts/vfx/visual_rhythm_controller.gd` — Shot, boss, wave → short glow pulses / soft wave.
- `resources/shaders/nebula_drift.gdshader` — Drift + optional breath on opacity.
- `resources/shaders/star_clusters.gdshader` — Clusters, twinkle, optional breath.
