# Visual Identity — Technological Light

**Goal:** Light behaves like energy systems, precision instruments, and refraction tools. Not magical.

**Overarching tone:** The game reads as an **interactive light installation** — minimal space, geometric light structures, refraction fields, dark void. Calm tension, focused movement, technological art. See **docs/INSTALLATION_ART_TONE.md**.

---

## Light Behaviour

**Use:**
- **Sharp edges** — Crisp boundaries on beams, flashes, and UI. No soft fantasy glow.
- **Directional beams** — Light travels in defined directions (weapon beams, telegraphs, energy spikes).
- **Pulse-driven emission** — Flashes and glows are triggered by events (fire, hit, phase), not constant.
- **Refraction effects** — Prism-like splits, lens flares, clean chromatic edges where appropriate.
- **Energy lines** — Trails, grids, and HUD elements read as conductive or data-carrying lines.

**Avoid:**
- Soft fantasy glow
- Random particle clouds
- Organic smoke-like light

---

## Weapon Light (Feels Engineered)

| Weapon | Identity |
|--------|----------|
| **Beam** | Stable energy stream — directional line, pulse-driven, sharp edges. |
| **Burst** | Charged discharge — short spike or line, crisp on/off. |
| **Spread** | Multi-emitter system — fan of discrete beams or emitters, not a soft cone. |
| **Homing** | Guided energy — directional then curve; trail reads as trajectory data. |
| **Rear** | Reactive discharge — pulse when threshold met. |
| **Drones** | Orbiting energy nodes — small, defined nodes with energy trails; not soft orbs. |

---

## Impact Effects

- **Clean flashes** — Bright core, fast falloff, geometric (circle/poly) not cloud.
- **Energy spikes** — Short directional lines from impact point; radial spikes that extend and fade.
- **Digital distortion** — Optional: brief scanline or glitch line at impact; no bloom cloud.
- **No explosion clouds** — No soft particle clouds or organic smoke; replace with spike/line bursts.

---

## Background Light

**Feels like:**
- Minimal space — sparse, intentional; dark void with geometric light structures.
- Data flow — directional or flowing line elements.
- Power grids — subtle grid or lattice in motifs/shaders.
- Refraction fields — layered, prism-like colour bands; space as medium.

**Motion:** Slow drifting shapes, controlled energy pulses, rhythmic environmental reactions (installation responds to the visitor).

**Not:**
- Cosmic magic — avoid nebulae that read as mystical; prefer tech/energy framing (e.g. “energy field”, “refraction layer”).
- Battlefield clutter — no war debris, no military framing.

---

## Implementation

- **ArtDirection:** Palette and tiers support tech light; explosion core = clean energy flash; no rainbow cloud as default.
- **ExplosionVFX:** Core flash + energy spikes (radial Line2D); optional digital glitch; no particle cloud fallback.
- **MuzzleFlashVFX:** Shapes = line (directional), spike (charged), multi-line fan (spread), geometric emitter (disc → hex/oct); sharp edges.
- **Beam / trails:** Beam glow kept tighter than core; trails with clear head/tail gradient (energy line, not smoke).
- **Background / atmosphere:** Shaders and motifs can expose grid, scanline, or refraction; docs and naming favour “refraction field”, “data layer” over “cosmic” or “magic”.
