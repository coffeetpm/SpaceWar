# Enemy visual identity — Abstract constructs

**Goal:** Enemies feel like **light-based machines** and **geometric systems**. Controlled threat, technological presence.

---

## Visual rules

- **Polygon forms** — Defined shapes (hex, diamond, bars, rings). No soft blobs or organic silhouettes.
- **Rotating segments** — Parts can rotate at slow, intentional speeds. Mechanical, not fluttering.
- **Energy cores** — Central or focal bright element; reads as power source, not “eye” or “face”.
- **Refraction surfaces** — Cool tint, low alpha, thin rings or bands. Light as medium, not skin.

---

## Movement

- **Smooth** — No jitter or sudden snaps; use easing and consistent speed.
- **Intentional** — Motion has purpose (approach, hold, shift). Not wandering or fleeing.
- **Sculptural** — Trajectories and rotations feel composed. Installation-art tone.

---

## Avoid

- **Organic motion** — No wobble, breathing, or creature-like pulse.
- **Creature-like behaviour** — No faces, limbs, or “looking at” player as character.
- **Traditional ships** — No cockpit, wings, or vehicle silhouette. Prefer abstract geometry.

---

## Emotion

| Target | Avoid |
|--------|--------|
| **Controlled threat** | Panic, aggression, horror |
| **Technological presence** | Living creature, military unit |

---

## Reference

- **Showcase:** `scripts/demo/showcase_enemy.gd` — Abstract construct with refraction ring, rotating segments, energy core, splittable body halves. Used in beam showcase scenes.
- **In-game enemies:** `scenes/enemies/enemy_*.tscn` — When redrawing, apply same rules: polygon forms, optional rotating elements, energy core (Visual/Core), no ship/creature read.
- **Tone:** Aligns with **docs/INSTALLATION_ART_TONE.md** (moving constructs, geometric entities, light-driven machines).
