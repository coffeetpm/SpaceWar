# Boss Encounters: Skill Challenges

## Goal

Boss fights test **movement, positioning, and timing**—not raw build power. A skilled player with a weak build should outperform an unskilled player with a strong build. No build should trivialize the boss.

---

## Boss Rules

| Rule | Meaning |
|------|--------|
| **Pattern-based attacks** | Every attack is a fixed sequence or cycle. No RNG spray; player can learn and plan. |
| **Clear readable telegraphs** | Before each attack: visible wind-up, direction, and safe/unsafe zones. Telegraph duration long enough to read (e.g. 0.4–0.8s). |
| **Safe zones exist** | Every attack has at least one reliable way to avoid damage (dodge, position, or timing). No undodgeable one-shots. |
| **Punish greed** | Standing still to DPS or overcommitting is risky. Boss rewards repositioning and disciplined timing. |

---

## Structure (60s fight)

Boss burst duration is **60 seconds** (see `StageManager.boss_burst_duration`). Phases are derived from elapsed time in the burst.

| Phase | Time | Purpose |
|-------|------|--------|
| **Phase 1: Pattern learning** | 0–20s | Introduce 1–2 attack patterns. Telegraphs are clear; tempo moderate. Player learns tells and safe zones. |
| **Phase 2: Pressure** | 20–40s | Add complexity: more patterns, shorter windows, or overlapping threats. Still fair; no cheap hits. |
| **Phase 3: Peak chaos** | 40–60s | Maximum intensity: faster cycles, combined patterns, or tighter safe zones. Skill ceiling moment. |

**Implementation note:** `StageManager.get_boss_phase()` returns 0 (not boss), 1 (0–20s), 2 (20–40s), or 3 (40–60s). Use it to drive pattern selection and intensity.

---

## Balance Rule: Threaten ALL Builds

- **No build trivializes the boss.** Beam, Drones, Spread, Pulse, and any synergy combo must all find the fight challenging.
- **Damage type:** Boss should not be immune to one damage type; avoid “only bullets work” or “only drones work.” Prefer: all sources work, but **positioning and timing** matter more than DPS.
- **Avoid:** Boss with huge HP that only high-DPS builds can kill in 60s. Prefer: boss has moderate HP; survival and consistency matter. Optionally scale boss HP or attack intensity with burst index, not with player build.
- **Safe zones and telegraphs** should be readable and usable regardless of weapon (no “you must stand exactly here with beam only”).

---

## Rhythm alignment

- **Boss attacks follow beat structures** where possible: telegraph duration, attack windup, and cooldown in multiples of beat length (e.g. BeatConductor BPM 120 → 0.5s per beat). Phase changes can align to beat so the fight feels part of the run’s cadence. See **docs/RHYTHM_FLOW_DESIGN.md**.

---

## Visual Rule: Readable Over Neon Chaos

- **Boss attacks must read clearly** against neon VFX, bullets, and background.
- **Telegraph hierarchy:** Use ArtDirection brightness tiers. Boss telegraphs (warning zones, charge lines, safe gaps) should be **Tier 1 or Tier 2** so they pop above trails and ambient glow.
- **Contrast:** Distinct color or shape for “danger” (e.g. red/orange or thick outline) vs “safe” (e.g. dark gap or blue tint). Avoid telegraphs that blend with player bullets (cyan) or enemy bullets (yellow/green).
- **Motion:** Telegraphs can use scale-up, pulse, or line growth so the **motion** reads even in clutter. Static small indicators get lost.

---

## Implementation Hooks

- **Boss burst active:** `StageManager._is_boss_burst(burst_index)` and 60s `burst_timer`; `WaveSpawner` receives `is_boss` and `set_burst_time_remaining(remaining)`.
- **Boss phase (1/2/3):** `StageManager.get_boss_phase()` returns 1, 2, or 3 during a boss burst; 0 otherwise.
- **Future boss entity:** A dedicated Boss scene/script can subscribe to burst start (e.g. EventBus or StageManager signal when burst_index triggers boss) and drive pattern selection, telegraphs, and safe zones from phase and timer. Regular add spawns can be reduced or disabled during boss so the encounter stays readable.

---

## Summary

| Pillar | Boss design |
|--------|-------------|
| **Skill, not power** | Movement, positioning, timing win. Build power helps but doesn’t replace skill. |
| **Rules** | Pattern-based, telegraphs, safe zones, punish greed. |
| **60s structure** | Phase 1 learn, Phase 2 pressure, Phase 3 peak chaos. |
| **Balance** | Every build is threatened; no build trivializes. |
| **Visual** | Telegraphs readable over neon (tier, contrast, motion). |
