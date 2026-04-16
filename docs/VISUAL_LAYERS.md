# Visual Layers — Tetris Effect–Style Hierarchy

**Goal:** Visually rich but always readable. Beauty in the background, clarity in the foreground.

---

## Three Layers

| Layer | Purpose | Content | Rules |
|-------|--------|--------|--------|
| **LAYER 1 — Gameplay** | Highest priority | Player, enemies, bullets, boss | Sharp, high contrast, clean silhouettes. Minimal glow bloom. |
| **LAYER 2 — Interaction FX** | Timed, rhythmic | Hit flashes, weapon ignition, beat pulses, pressure vignette | Moderate glow. Never persistent clutter. |
| **LAYER 3 — Atmosphere** | Beauty | Nebula (parallax), particles, theme motifs, distant stars | Fade behind gameplay. Lower opacity during intense combat. Never overlap player silhouette heavily. |

---

## Scene Layering Structure

- **CanvasLayer -202:** EmotionFeedback overlay (fullscreen tint, very low alpha). Emotional feedback layer — background tone shift (calm/tension/release/focus). Drawn first (back). See **docs/EMOTIONAL_FEEDBACK_LAYER.md**.
- **CanvasLayer -201:** AtmosphereBeauty (drifting nebula, soft star clusters, distant luminous shapes, light dust). Extremely low movement; opacity tied to combat intensity and emotion breath.
- **CanvasLayer -200 (LAYER_ATMOSPHERE):** ParallaxController (Stars, Dust, Fog). Drawn next.
- **CanvasLayer -199:** ThemeMotifController (per-theme motif overlays). Same priority as atmosphere.
- **World (default layer 0):** Gameplay. Background z_index -100, StarDust -99, then BulletPool, Player, Enemies at 0. Boss in World when spawned.
- **CanvasLayer 40 (LAYER_FX):** HitFlash (fullscreen flash). Interaction FX drawn above gameplay.
- **CanvasLayer 45:** PressureVignette. Slight vignette + bloom when many enemies near player.
- **CanvasLayer 100 (LAYER_UI):** UI.

Constants live in **VisualLayers** autoload: `LAYER_ATMOSPHERE`, `LAYER_GAMEPLAY`, `LAYER_FX`, `LAYER_FX_PRESSURE`, `LAYER_UI`.

---

## Opacity Control Logic

- **ThemeManager.combat_density** (0–1): Derived from active bullet count. Used for motif and atmosphere fade.
- **VisualLayers.get_atmosphere_opacity_multiplier():** `1.0 - combat_density * ATMOSPHERE_COMBAT_FALLOFF`. Used by AtmosphereOpacityController and (for motif) ThemeMotifController.
- **AtmosphereOpacityController:** Each frame sets Parallax (Stars, Dust, Fog) and optional World/StarDust `modulate.a` from opacity multiplier × beat boost. Connects to BeatConductor.beat_pulse for a short brightness boost (ATMOSPHERE_BEAT_BOOST, ATMOSPHERE_BEAT_DURATION).
- **ThemeMotifController:** Already sets motif opacity from `ThemeManager.get_motif_opacity_multiplier()`. Also multiplies by `VisualLayers.get_atmosphere_beat_multiplier()` so motifs pulse with beat.

---

## Focus-Based Visual System

**Goal:** Center gameplay area stays sharp and readable; edges become atmospheric and dreamlike. Player feels in control at the center, surrounded by a living universe.

- **Center (focus region):** Full clarity, high contrast, minimal atmospheric overlay. Achieved by radially fading **atmosphere only** (parallax, nebula, star clusters) so that near screen center their alpha is reduced; gameplay is never blurred or softened.
- **Outer edges:** Softer glow, full atmospheric particles and nebula, reduced detail — atmosphere is at full strength toward the edges.
- **Dynamic focus:** Driven by `ThemeManager.combat_density`. When combat is **intense**, focus tightens (larger clear center, more edge softening). When **calm**, atmosphere expands (smaller clear center, less edge softening).
- **Implementation:** `VisualLayers.get_focus_center()`, `get_focus_inner_radius()`, `get_focus_outer_radius()` (UV-space radial mask). ParallaxController and AtmosphereBeauty set these each frame on parallax and nebula/star_clusters shaders. Shaders multiply atmosphere alpha by `smoothstep(inner, outer, distance(UV, center))` so center = 0, edges = 1.
- **Do not blur gameplay:** Only atmosphere layers (parallax, atmosphere beauty) use the focus mask. Gameplay (World, player, bullets, boss) is never blurred or vignette-softened.

---

## Lighting Rules

- **Bloom:** Applied mostly to background (environment glow_hdr_threshold = 0.88 so only bright pixels bloom). Atmosphere (parallax, motifs) can use higher saturation/values so they bloom; gameplay stays crisp.
- **Gameplay:** Crisp edges, lower bloom contribution. Optional: use **crisp_gameplay_material.tres** (shader `crisp_gameplay.gdshader`, crisp_scale ≈ 0.84) on player, bullets, enemies so RGB stays below threshold.
- **Color saturation:** Highest in atmosphere; lower in bullets (ArtDirection BULLET_GLOW_ALPHA_SCALE, TIER2/TIER3 trail colors).

---

## Rhythmic Motion

- **BeatConductor.beat_pulse:** Drives environment glow pulse (BeatConductor), atmosphere opacity boost (VisualLayers + AtmosphereOpacityController), and motif beat multiplier (ThemeMotifController).
- **Ambient particles:** StarDust (World) and parallax layers receive opacity from AtmosphereOpacityController; parallax motion is camera-driven (ParallaxController). Optional: subtle scale or brightness pulse on beat in parallax shaders.

---

## Interaction Hooks

- **VisualLayers.set_atmosphere_beat_pulse():** Call on beat (e.g. from BeatConductor.beat_pulse) to set a short atmosphere brightness boost.
- **VisualLayers.get_atmosphere_opacity_multiplier():** For any system that needs “how much should atmosphere show” (e.g. custom particles).
- **ThemeManager.get_motif_opacity_multiplier():** Used by ThemeMotifController; same combat-based falloff.
- **AtmosphereOpacityController:** Requires ParallaxController and optional World/StarDust path. No extra hooks; runs every frame.

---

## Atmosphere Beauty (Layer -201)

- **Nebula:** Full-screen shader (`nebula_drift.gdshader`) — slow drifting FBM noise gradients. `drift_speed` ≈ 0.035.
- **Star clusters:** Full-screen shader (`star_clusters.gdshader`) — soft dots with slow drift and twinkle. `drift_speed` ≈ 0.018.
- **Luminous shapes:** A few large Polygon2D ellipses, very low alpha (0.05–0.06), slow position/rotation drift (≈ 8 px, 0.02 rad/s).
- **Dust:** CPUParticles2D, low amount (24), long lifetime (12 s), low speed (2–8). Additive material.
- **Opacity:** Same as rest of atmosphere — `VisualLayers.get_atmosphere_opacity_multiplier()` × beat multiplier. Fades when many bullets (combat density). Never competes with gameplay.

## Files

- `scripts/autoload/visual_layers.gd` — Layer constants, atmosphere opacity/beat helpers.
- `scripts/vfx/atmosphere_beauty.gd` — Builds nebula, star clusters, luminous shapes, dust; drives opacity from combat/beat.
- `scripts/vfx/atmosphere_opacity_controller.gd` — Drives parallax + optional StarDust opacity and beat.
- `scripts/vfx/theme_motif_controller.gd` — Motif opacity (combat + beat multiplier).
- `scripts/vfx/parallax_controller.gd` — Parallax scroll; ParallaxLayer uses layer -200.
- `resources/environment/neon_glow.tres` — glow_hdr_threshold 0.88, tuned for background bloom.
- `resources/shaders/crisp_gameplay.gdshader` + `resources/materials/crisp_gameplay_material.tres` — Optional material for gameplay to reduce bloom (crisp edges).
