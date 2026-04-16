# Signature builds — Three memorable run identities

**Goal:** Builds that drastically change feel, have unique visual language, and are achievable early–mid run.

---

## Build 1 — Light Refraction

**Identity:** Beam splitting, mirror effects, afterimages. The run feels like controlling a single coherent beam that multiplies and echoes.

### Gameplay feel
- One main beam (Photon Lance) that **splits** into extra projectiles (bending beams) or leaves **afterimages** (delayed duplicate shots).
- **Mirror** = afterimage + bending read as “light reflecting”; splitting reads as refraction.
- High clarity: player always knows “I am the beam build.”

### Weapon synergy mapping
| Weapon | Role in build |
|--------|----------------|
| **Photon Lance (beam)** | Core. Only weapon that triggers light_pulse; enables Resonant Echo, Bending Beams, Spreading Fire. |
| Pulse Array / Burst Cannon / Seeker Volley | Can contribute via **Pulse Split** (shockwave splits) for a hybrid “light + time” feel; not the primary Light Refraction weapon. |

**Primary path:** Choose **Photon Lance** → take **Resonant Echo** (afterimage) and/or **Spreading Fire** (beam spreads) or any **Chain**-enabled upgrade for bending/spread. One light upgrade is enough for early identity; two (e.g. Echo + Spreading Fire or Echo + Bending via Chain) for mid-run signature.

### Upgrade mapping
| Upgrade | Effect | Build role |
|---------|--------|------------|
| **Resonant Echo** | Beam leaves an energy afterimage | Core. Defines “mirror/echo” feel. |
| **Spreading Fire** | Beam energy spreads to nearby targets | Core. Adds spatial spread (light + space). |
| **Chain** | Enables spreading energy synergies | Enabler. Unlocks Spreading Fire; supports “beam everywhere” fantasy. |
| **Pulse Split** | Shockwave splits into side projectiles | Secondary. On time weapons gives “temporal split”; supports hybrid. |
| *Bending Beams* | (Force-pair: light + space) Extra angled projectiles + small burst | Core. Achieved when running Photon Lance + any space upgrade (e.g. Chain). |

### Visual identity suggestions
- **Primary hue:** Cyan–white beam core; keep existing `TIER2_BULLET_CORE_PLAYER` / beam Line2D.
- **Signature VFX:** Afterimage = same beam color at ~60% opacity, 1–2 frame delay; Bending = same core with a slight **prism/spectral** tint (very light magenta or green edge) so “split light” reads.
- **Mirror read:** Short trail or duplicate line behind main beam; afterimage spawn slightly offset or on same line.
- **UI hint:** Run summary or resonance line can show “Light Refraction” when weapon is beam and run has at least one light-tagged synergy (see BuildVocabulary).

---

## Build 2 — Time Collapse

**Identity:** Slow zones, delay explosions, temporal waves. The run feels like time is the weapon—delays and freezes.

### Gameplay feel
- **Slow zones:** Gravity/slow effect (space+time) creates visible “time blip” and brief time_scale dip—read as temporal zone.
- **Delay explosions:** Afterimage (time+light) = “delayed” second shot; Pulse Split = “wave” that splits. Both read as “delayed” or “wave” effects.
- **Temporal waves:** Pulse Array / Burst / Seeker fire in waves; Pulse Split adds perpendicular waves. Strong “rhythm + delay” feel.

### Weapon synergy mapping
| Weapon | Role in build |
|--------|----------------|
| **Pulse Array (spread)** | Core. Wide time_pulse triggers; best for Pulse Split and for building “temporal wave” density. |
| **Burst Cannon (burst)** | Core. Rhythmic volleys + Pulse Split = clear “delayed wave” pattern. |
| **Seeker Volley (homing)** | Core. Rewind-like homing + delay/echo synergies. |
| Photon Lance | Hybrid: Resonant Echo gives “temporal echo” for beam (time+light). |

**Primary path:** Choose **Pulse Array**, **Burst Cannon**, or **Seeker Volley** → take **Pulse Split** (shockwave splits). Add **Resonant Echo** if offered (beam run) for afterimage, or any upgrade that triggers **gravity_slow** (space+time) for slow zones. Achievable with one strong time upgrade (Pulse Split) early; add second force (space for slow zone) mid-run.

### Upgrade mapping
| Upgrade | Effect | Build role |
|---------|--------|------------|
| **Pulse Split** | Shockwave splits into side projectiles | Core. “Temporal waves” and “split timing.” |
| **Resonant Echo** | Beam leaves an energy afterimage | Hybrid. On beam = “delay explosion” / echo. |
| *Gravity slow* | (Force-pair: space+time) Zone visual + brief time_scale dip | Core. “Slow zone” read; need both space and time in run (e.g. time weapon + Chain or Orbit Shock). |

### Visual identity suggestions
- **Primary hue:** Keep player cyan; **time effects** = cool blue–purple (`Color(0.4, 0.5, 0.9)`) for slow zone; afterimage = same as beam with slight **motion blur** or lower alpha.
- **Signature VFX:** Slow zone = soft circular flash or expanding ring (existing explosion_requested with blue–purple); “delay” = afterimage spawn 1–2 frames late; “temporal wave” = Pulse Split projectiles use a **slightly different trail** (e.g. dashed or fade-fast) so they read as “echo wave.”
- **UI hint:** “Time Collapse” when primary weapon is time (spread/burst/homing) and run has time_pulse-triggered synergies or gravity_slow.

---

## Build 3 — Space Orbit

**Identity:** Drones, gravity pull, orbit fields. The run feels like controlling space—orbit and area.

### Gameplay feel
- **Drones:** Orbital Sentinels (orbit + pull) are the core; contact = orbit tick, triggers Orbit Shock (electric burst).
- **Gravity pull:** Bending Beams (light+space) and Spreading Fire add “pull” or “spread” in space; Chain/warp tag supports “spreading” fantasy.
- **Orbit fields:** Electric burst on drone contact reads as “orbit field discharge”; gravity_slow (space+time) reads as “gravitic zone.”

### Weapon synergy mapping
| Weapon | Role in build |
|--------|----------------|
| **Orbital Sentinels (drones)** | Core. Only weapon that triggers space_tick; enables Orbit Shock and defines “orbit field” feel. |
| Photon Lance | Hybrid. With Chain or Spreading Fire = “bent beam” and “spread” in space (bending_beams, spreading_fire). |

**Primary path:** Choose **Orbital Sentinels** → take **Orbit Shock** (sentinels discharge on contact). Add **Chain** or **Spreading Fire** for “orbit + spread” or pair with beam in a two-force run for Bending Beams. One upgrade (Orbit Shock) is enough for early identity; add Spreading Fire or gravity_slow (e.g. time upgrade) for mid-run.

### Upgrade mapping
| Upgrade | Effect | Build role |
|---------|--------|------------|
| **Orbit Shock** | Sentinels discharge on contact | Core. Defines “orbit field” and electric burst. |
| **Chain** | Enables spreading energy synergies | Enabler. Space tag; unlocks Spreading Fire. |
| **Spreading Fire** | Beam energy spreads to nearby targets | Hybrid. Strong when run has beam + space (e.g. drones run later picking beam-related upgrade, or beam run + Chain). |
| *Bending Beams* | (Force-pair: light+space) Angled projectiles + burst | Hybrid. Beam + space run. |
| *Gravity slow* | (Force-pair: space+time) Slow zone | Core. “Orbit/gravitic zone” read. |

### Visual identity suggestions
- **Primary hue:** Keep drone cyan core; **orbit/space effects** = electric blue–white (`Color(0.5, 0.85, 1.0)`) for Orbit Shock burst; gravity = blue–purple for slow zone.
- **Signature VFX:** Drones = clear **orbital path** (existing orbit); electric burst = tight, bright **radial burst** on contact; “orbit field” = optional faint ring or radius around player when drones are active; Spreading Fire = short **arc or cone** to nearest target.
- **UI hint:** “Space Orbit” when weapon is drones and run has at least one space-tagged upgrade (Orbit Shock or Chain) or space+time (gravity_slow).

---

## Summary table

| Build | Primary weapon(s) | Core upgrades | Force-pair effects | Achievable |
|-------|--------------------|---------------|--------------------|------------|
| **Light Refraction** | Photon Lance | Resonant Echo, Spreading Fire, Chain | Bending Beams (light+space) | Stage 1–2: beam + 1 upgrade |
| **Time Collapse** | Pulse Array, Burst Cannon, Seeker Volley | Pulse Split | Gravity slow (space+time), Afterimage (time+light) | Stage 1–2: time weapon + Pulse Split |
| **Space Orbit** | Orbital Sentinels | Orbit Shock, Chain | Bending Beams, Gravity slow, Spreading Fire | Stage 1–2: drones + Orbit Shock |

---

## Implementation note

- **BuildVocabulary** can define the three signature build IDs and a function `get_signature_build(weapon_id, run_forces)` that returns the build name (or null) for run summary / resonance UI.
- Upgrade and weapon mapping above are the single source of truth for which upgrades and weapons support each build; adjust .tres and vocabulary if new upgrades are added.
