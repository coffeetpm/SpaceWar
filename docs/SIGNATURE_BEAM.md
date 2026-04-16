# Signature Beam — Game Identity Moment

**Goal:** The beam feels like it **slices space open**, not just fires a projectile. Used for trailer opening, store GIF, main menu background.

---

## Beam Behaviour

- **Strong linear emission** — Core line + tight glow (WeaponBeam).
- **Slight delay before firing (charge feel)** — Lock-on telegraph (thin line, dim) for `telegraph_duration` (0.12s).
- **After firing, refraction trail** — When the pulse ends, a thin line (slice in space) lingers and fades over 0.35s. Technological, not smoky.
- **Space behind beam slightly distorts** — Refraction trail reads as “space was cut”; optional future: subtle distortion shader.

---

## Impact (when beam pulse ends)

- **Clean energy fracture** — 6 thin radial lines (crack) at beam tip.
- **Light shards** — 5 short lines expand from center, brief hold, then collapse and fade.
- **Quick collapse back to normal space** — Total impact duration ~0.2s.

Implemented in **BeamImpactVFX** (`scripts/vfx/beam_impact_vfx.gd`), spawned by the beam when the pulse ends at the beam tip.

---

## Visual Tone

- **Technological, precise, engineered.** Sharp edges, directional, no fantasy glow.
- **Installation-art feel:** Minimal space, geometric light, refraction fields, dark void. Calm tension, focused movement. Not a battlefield; interactive light installation. See **docs/INSTALLATION_ART_TONE.md**.
- **Not:** fantasy, explosive, smoky, war/military framing.

See **docs/VISUAL_IDENTITY.md**.

---

## Usage

- **In-game:** Every beam shot leaves a refraction trail and spawns the impact at the beam tip (in `beam.gd`).
- **Trailer / store GIF / main menu:** Run the standalone scene **`scenes/demo/signature_beam_moment.tscn`**.
  - Timeline: 0.55s pause → 0.12s charge (telegraph) → 0.14s fire → refraction trail + impact play automatically → 1.8s loop delay then repeat.
  - Script: `scripts/demo/signature_beam_moment.gd`. Beam collision disabled for demo.
  - Use as main menu background (e.g. SubViewport or scaled TextureRect) or run as standalone for recording.

---

## Beam showcase (Steam GIF / trailer / branding)

**Scene:** `scenes/demo/beam_showcase_moment.tscn` — minimal, stylish full sequence (no player).

**Sequence:** (1) Dark space → (2) Beam charge → (3) Beam fires and slices → (4) Enemies split → (5) Refraction trail → (6) Reset.

**Rules:** Minimal particles, controlled glow, strong contrast, precise timing. Emotion: calm power, precision, high-tech.

---

## Mid-distance gameplay composition (playable feel)

**Scene:** `scenes/demo/beam_showcase_gameplay.tscn` — player visible, enemies approach, mid-distance view. For Steam GIF, trailer opening, store visuals.

**Camera:** Mid-distance (zoom 0.85, position 480,324). Player, enemies, beam, and environment all visible. No zoom too close, no full-screen effects, gameplay readable.

**Sequence:** (1) Player idle in dark space (2) Enemies approach from the right (3) Beam charges (4) Beam slices through enemies (5) Clean refraction trail remains (6) Reset and loop.

**Visual tone:** Minimal, sharp, precise. Installation-art: calm tension, geometric entities, dark void. See **docs/INSTALLATION_ART_TONE.md**.

- **ShowcasePlayer** (`scripts/demo/showcase_player.gd`): Minimal wedge ship (Polygon2D), nose right. Beam is child of Player.
- **ShowcaseEnvironment** (`scripts/demo/showcase_environment.gd`): A few distant star points, very low alpha. No clutter.
- **BeamShowcaseGameplay** (`scripts/demo/beam_showcase_gameplay.gd`): Timeline idle → approach (tween enemies in) → charge → fire → trail → reset. Enemies reset to start X for next loop.
- **ShowcaseEnemy** (`scripts/demo/showcase_enemy.gd`): Abstract construct — polygon body, rotating segments, energy core, refraction ring. `split()` slides halves apart and fades; sculptural. See **docs/ENEMY_VISUAL_IDENTITY.md**.

---

## Files

- `scripts/weapons/beam.gd` — Refraction trail + impact spawn at pulse end; telegraph + pulse logic.
- `scripts/vfx/beam_impact_vfx.gd` — Clean fracture + light shards, expand/collapse.
- `scenes/demo/signature_beam_moment.tscn` — Beam-only demo (no enemies).
- `scripts/demo/signature_beam_moment.gd` — Beam-only timeline.
- `scenes/demo/beam_showcase_moment.tscn` — Full showcase (dark → charge → fire → splits → trail → reset).
- `scripts/demo/beam_showcase_moment.gd` — Showcase timeline.
- `scripts/demo/showcase_enemy.gd` — Minimal geometric enemy, clean split.
- `scenes/demo/beam_showcase_gameplay.tscn` — Mid-distance gameplay composition (player + enemies + beam + env).
- `scripts/demo/beam_showcase_gameplay.gd` — Gameplay timeline (idle, approach, charge, fire, trail, reset).
- `scripts/demo/showcase_player.gd` — Minimal player ship visual.
- `scripts/demo/showcase_environment.gd` — Minimal distant stars.
