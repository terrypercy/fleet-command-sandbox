# Combat Space

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on the soft edge not holding fast ships, accidental retreat by geometry, overclaiming ghost paths, unannounced pushes on the flagship, and no stated movement-modifier channel; all five revised
> **Implements Pillar**: Pillar 3 (Hands on the Helm — the flagship moves exactly as flown); Pillar 4 (Plan in the Open — ranges, arcs and positions are readable and exact)

## Summary

Combat Space is the battlefield as the simulation sees it: exact fixed-point
positions, headings and velocities, a steered-velocity integrator driven by each
hull's speed, acceleration and turn rate, solid hulls that push apart without
damage, a circular field with soft edges and per-side retreat zones, and a
uniform grid answering ordered spatial queries. Ships carry weight and
overshoot turns, yet their motion is exactly predictable, so pausing shows a
true ghost path (Pillars 3 and 4).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Runtime ID Service, Hulls & Ship Definition`

## Overview

Combat Space is the battlefield as the simulation sees it: where every ship and
projectile is, how ships move, how they keep apart, where the edges and retreat
zones are, and how other systems ask "what is near this point?". It runs in
phase P3 (movement) of every battle tick, in ascending Runtime ID order
(Simulation Tick & Pause, rule 3), and serves read-only spatial queries to
Weapons & Damage, Ship AI and Coherence & Links in P4–P6.

Three choices define it:
- **Exact integer space.** Positions, velocities and headings are fixed-point
  integers; there are no floats in Combat Space, so there is no NaN, and a
  cross-platform hash test stays possible after MVP.
- **Our own integrator, never engine physics.** The simulation does not use
  Godot physics bodies (Simulation Tick & Pause, rule 2). Scene nodes only draw
  the result, interpolated between ticks.
- **Weight that stays readable.** Ships accelerate and turn at their hull's
  rates, so they carry momentum and overshoot turns, but the motion is exactly
  predictable: paused, the game can show where every ship will be.

## Player Fantasy

**Weight under your hands, and the admiral's table when you pause.** The
flagship is heavy: the player feels it commit to a turn and uses its momentum.
Escorts swing wide, frigates dart. And at any moment, pausing shows exact
positions, arcs and ranges, with a faint ghost of where each ship is heading,
so the plan is made on facts.

*Anchor moment:* the Spiralward swings through a hard turn, overshoots by half a
length, and its blind rear briefly faces a Vector Line. The player pauses; the
ghost path shows the overshoot will clear in a second; they queue the escorts to
cover it.

**Pillars served:**
- **Pillar 3, *Hands on the Helm*:** the flagship moves exactly as flown, at its
  hull's rates (rule 5), except where contact or the edge pushes it, and both
  are shown with a cue (Game Feel).
- **Pillar 4, *Plan in the Open*:** positions and ranges are exact; the ghost
  path makes momentum predictable (rule 8).

**This system must never make the player feel:** "the ship slid somewhere I
couldn't predict" or "two ships merged into one blob".

## Detailed Design

### Core Rules

**A. Units and numbers**

1. **The world unit (u)** is the length every system uses. At reference zoom,
   1 u is one screen pixel. A light hull's radius is about 12 u, a capital's
   about 80 u (Hulls & Ship Definition, `world_radius`).
2. **Positions and velocities are Q16.16 fixed-point integers**: 1 u = 65,536
   sub-units. `AIM_QUANTUM` (1/16 u; Simulation Tick & Pause rule 6) is exactly
   4,096 sub-units. No float is ever stored or computed in Combat Space.
3. **Heading** `h` is an integer in [0, 65,536), in 1/65,536 of a turn
   (0 = east, counter-clockwise). The Battle Record's `qh = h >> 8` (1/256 turn)
   and `qx = pos_x >> 16` (whole u) are exact.
4. **Trigonometry comes from tables**: a 4,096-entry Q16 sine table and a
   1,024-entry arctangent table with octant folding, generated offline and
   shipped as data inside the content hash. Runtime `sin()`, `cos()` and
   `atan2()` are never called by the simulation. Square roots use an integer
   `isqrt`. Products are taken after `>> 8` where needed so no intermediate
   exceeds 2⁴⁵ (well inside 64-bit integers); engine 32-bit vector types are
   never used for arithmetic.

**B. Movement (P3)**

5. **Steered velocity.** From the hull's stats (Hulls & Ship Definition, rule 1),
   at battle start, with `TR` = `TICK_RATE` and integer division:
   `v_cap = max_speed × 65,536 div TR`, `a_step = accel × 65,536 div TR²`,
   `t_step = turn_rate × 65,536 div (360 × TR)` (Formulas D1). Each tick, for
   each ship in ascending Runtime ID order:
   1. turn `h` toward the desired heading by at most `t_step` (an exact 180°
      tie turns counter-clockwise);
   2. move the velocity vector toward `dir(h) × throttle × v_cap` by at most
      `a_step` (vector move-toward);
   3. `pos += vel`;
   4. apply the edge rule (rule 10), then the hard limit (rule 11).
   The desired heading and throttle come from Flagship Piloting (#15) for the
   flagship and from Ship AI (#20) for every other ship. Because velocity lags
   heading, ships carry momentum and overshoot turns; because the lag is
   bounded by `a_step`, the motion is fully predictable.
6. **Mass** decides only the share of separation push (rule 9) and any future
   knockback. Acceleration is already the hull's `accel`.
6a. **Other systems change movement only through published multipliers.** Each
   tick, `v_cap`, `a_step` and `t_step` are computed from the hull's base
   values times permille multipliers that named systems publish for that ship
   (Vigor #13, Coherence & Links #14, and later Weapons & Damage effects),
   applied in a fixed order (ascending system number) with `modifier_compose`
   rounding (Gameplay Settings & Modifiers D2). Combat Space stays neutral to
   both sides; the organic/machine asymmetry lives in the systems that publish.
   Every active multiplier is visible on the HUD (Pillar 4).
7. **Placement.** Ships appear or move discontinuously only through
   `place(id, x, y, h)` during battle setup or P3: velocity is zeroed, the grid
   is updated, and a record event is emitted. Nothing else may set a position.
8. **The ghost path** is presentation's: while paused, it runs the full P3 step
   (movement, separation and the edge rule) forward on a copy of the state for
   `GHOST_S` seconds with each ship's current intent, and draws the result,
   labelled **"if nothing changes"**. Friendly ghosts (the flagship and ships
   under direct orders) are drawn in full; enemy ghosts are drawn shorter and
   dimmer, as momentum only, because enemy AI may choose a new intent any tick.
   It never touches the simulation.

**C. Contact and bounds**

9. **Hulls are solid, and contact does no damage.** Each ship is a circle of its
   `world_radius`. After every ship has moved, one separation pass reads a
   snapshot of the new positions (so the result never depends on order) and,
   for each overlapping pair, pushes them apart by `min(overlap, PUSH_MAX)`,
   shared by mass: ship A moves `m_B ÷ (m_A + m_B)` of it. Exactly coincident
   centres separate along x, the lower Runtime ID toward −x. Ramming and contact
   damage are not at MVP (a capital bulldozing everything would be a degenerate
   strategy).
10. **The battlefield is a circle** of radius `FIELD_R` (3,000 u). Within the
    edge band (`EDGE_W`, 400 u inside the edge), after the steering step, the
    **outward part of a ship's velocity is clamped** to at most
    `v_cap × (FIELD_R − r) ÷ EDGE_W`, falling linearly to 0 at `FIELD_R`, where
    `r` is its distance from the centre (Formulas D4). So no ship, however fast
    or however hard it is flown outward, passes `FIELD_R`; it slides along the
    edge, never takes damage, and a visible edge line appears as it nears.
    Content validation checks the fastest hull against the smallest `EDGE_W`. `FIELD_R` must be at least 2.5
    times the longest weapon range (Weapons & Damage) and larger than the
    largest `link_range` (Hulls), so a ship can stand outside a relay's reach.
11. **Hard limit.** Any coordinate is clamped to ±`HARD_LIMIT` (16,384 u =
    ±2³⁰ sub-units) before the grid is rebuilt; a clamp is logged and asserted
    in debug builds. It exists only to make overflow impossible.
12. **Deployment and retreat zones.** Each side has a deployment arc on the
    circle (its direction comes from the battle setup) and a **retreat zone**:
    the part of the edge band within ±`RETREAT_ARC` (60°) of its own
    deployment direction. **Only a ship carrying an explicit retreat intent**
    (from Flagship Piloting for the flagship, from a fleet order through Ship AI
    for others) enters the Retreating state there; inside its own zone the edge
    clamp does not apply to it, and a countdown shows on the ship. A retreating
    ship that stays in its zone for `RETREAT_HOLD` ticks, or reaches `FIELD_R`
    in it, is reported to Battle Resolution, which owns the retreat rules. A
    ship without retreat intent is never reported, however long it stays in the
    zone; geometry never retreats a ship for the player.
13. **No obstacles at MVP.** The battle layout carries an empty `obstacles[]`
    list as a hook; line of sight is always clear at MVP.

**D. Spatial queries**

14. **A uniform grid** of `CELL` (256 u) cells covers the field (24 × 24 at
    `FIELD_R` 3,000), plus one overflow cell. Ships are inserted in ascending
    Runtime ID order after the separation pass; projectiles after their P4
    advance (Weapons & Damage). The grid is read-only from then until the next
    rebuild. It uses reused packed integer arrays; queries allocate nothing.
15. **The query API** (all results in ascending Runtime ID order, written into
    caller-owned arrays):
    - `query_circle(x, y, r, mask, out) → count` (exact ≤ test);
    - `query_nearest(x, y, r, mask) → id` (ties to the lower ID; NONE if
      nothing);
    - `query_segment(x0, y0, x1, y1, pad, mask, out) → count` (projectile
      sweeps);
    - `overlap_pairs(out) → count` (pairs with a < b, lexicographic).
16. **Combat Space emits** `Track` positions and the positions in `Destroyed`
    (Battle Record), and gives Flagship Piloting the settled flagship position
    for aim conversion (Simulation Tick & Pause, rule 6).

### States and Transitions

| State | Entered when | Behaviour | Leaves to |
|---|---|---|---|
| Active | placed at battle setup | Moves, collides, queryable | Retreating, Destroyed |
| Retreating | inside its own retreat zone **with retreat intent** | Edge clamp off; countdown shown; timer counts to `RETREAT_HOLD` | Active (leaves the zone or intent cancelled), Departed |
| Departed | timer reached | Removed from the grid; reported to Battle Resolution | — |
| Destroyed | hull reaches 0 (Weapons & Damage) | Removed from the grid at the end-of-tick step | — |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | Tick → #11 | P3 call; `TICK_RATE`; ascending ID order; no engine physics |
| Runtime ID Service (#3) | #3 → #11 | IDs for ships and projectiles; order |
| Hulls & Ship Definition (#10) | #10 → #11 | `max_speed`, `accel`, `turn_rate`, `mass`, `world_radius` |
| Weapons & Damage (#12) | both | Grid queries in P4/P5; projectile insertion; longest range constrains `FIELD_R` |
| Coherence & Links (#14) | #11 → #14 | Range queries for links |
| Flagship Piloting (#15) | both | Desired heading and throttle in; settled position out |
| Ship AI (#20) | both | Desired heading and throttle in; queries out |
| Battle Resolution | #11 → BR | Retreat-zone departures |
| Combat Event Bus & Battle Record (#9) | #11 → #9 | `Track`, positions in events, placements |
| Camera & Combat View (#45), HUD (#46) | #11 → them | Interpolated positions; ghost path; edge line |

## Formulas

### D1. Motion constants per tick

`v_cap = max_speed × 65,536 div TR`; `a_step = accel × 65,536 div TR²`;
`t_step = turn_rate × 65,536 div (360 × TR)`

| Variable | Type | Range | Description |
|---|---|---|---|
| max_speed | int | 20 – 400 u/s | Hulls |
| accel | int | 5 – 400 u/s² | Hulls |
| turn_rate | int | 5 – 180 °/s | Hulls |
| TR | int | 60 or 30 | `TICK_RATE` |
| v_cap | int | 21,845 – 436,906 sub-units/tick at 60 Hz | Speed cap |
| a_step | int | 91 – 7,281 | Velocity change per tick at 60 Hz |
| t_step | int | 15 – 546 | Heading change per tick at 60 Hz |

**Example** (max_speed 200, accel 100, turn_rate 90, 60 Hz): `v_cap` = 13,107,200
div 60 = **218,453** (3.333 u/tick); `a_step` = 6,553,600 div 3,600 = **1,820**, so
0 → full speed takes ceil(218,453 ÷ 1,820) = **121 ticks** (about 2.0 s);
`t_step` = 5,898,240 div 21,600 = **273**, so a 180° turn (32,768) takes
**121 ticks**. At 30 Hz truncation differs slightly; `TICK_RATE` is in every
replay header, so this never breaks a replay.

### D2. Separation share

`push = min(overlap, PUSH_MAX)`; `move_A = push × m_B div (m_A + m_B)`;
`move_B = push − move_A`.

**Example:** masses 1 and 3 overlapping by 8 u with `PUSH_MAX` 8 u: A moves 6 u,
B moves 2 u. With the default `PUSH_MAX` 2 u per tick: A 1.5 u, B 0.5 u this
tick, the rest on later ticks.

### D3. Arithmetic range

Coordinates ≤ 2³⁰ sub-units; differences ≤ 2³¹; after `>> 8`, squares ≤ 2⁴⁶ and
a sum of two ≤ 2⁴⁷, far below 2⁶³.

### D4. Edge clamp

`v_out_max = v_cap × (FIELD_R − r) div EDGE_W` for `FIELD_R − EDGE_W ≤ r ≤ FIELD_R`;
the outward (radial) component of velocity is reduced to `v_out_max` if larger.

**Example:** `v_cap` 436,906 (400 u/s), `EDGE_W` 200 u: at r = FIELD_R − 100 u
the outward speed may be at most half of `v_cap`; at r = FIELD_R it is 0. The
tangential component is untouched, so the ship slides along the edge.

## Edge Cases

- **If a coordinate passes `HARD_LIMIT`**: it is clamped, logged and asserted in
  debug (rule 11).
- **If a hull's mass is below 1**: content validation refuses it; the code also
  uses `max(1, mass)`.
- **If two centres coincide exactly**: rule 9's x-axis tie-break.
- **If a ship is faster than its cap** (after a published multiplier lowers
  `v_cap`, rule 6a): it loses `a_step` per tick until under the cap.
- **If many ships overlap at once** (a crowded spawn): each tick pushes at most
  `PUSH_MAX` per pair; crowds spread over a few ticks without jumps.
- **If a ship leaves the field at full speed**: the edge acceleration turns it
  back within the band; it never passes `FIELD_R + EDGE_W` in normal play, and
  the hard limit catches anything else.
- **If a ship sits in another side's retreat zone**: nothing happens; only its
  own side's zone counts.
- **If a projectile is outside the field**: it stays in the overflow cell;
  Weapons & Damage decides when it expires.
- **If the battle starts with ships overlapping** (bad setup): the separation
  pass resolves it in the first ticks; a warning is logged for the setup data.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | P3, order, `TICK_RATE` |
| Runtime ID Service (#3) | Hard | IDs |
| Hulls & Ship Definition (#10) | Hard | Motion stats, radius, mass |
| #12, #14, #15, #20, Battle Resolution, #9, #45, #46 | Hard (reverse) | Queries, intents, positions |
| Vigor (#13), Coherence & Links (#14) | Hard (reverse) | Publish movement multipliers (rule 6a) |

Bidirectional check: Simulation Tick & Pause and Hulls already reference Combat
Space (AIM_QUANTUM, world unit); downstream GDDs must cite the query API.

## Tuning Knobs

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `FIELD_R` | 3,000 u | 2,000 – 4,096 | Battlefield size | Cramped, no room outside relay reach | Long approaches |
| `EDGE_W` | 400 u | 200 – 800 | Edge softness | Abrupt edge | Edge eats space |
| `RETREAT_ARC` | 60° | 30 – 90° | Retreat zone width | Hard to retreat | Retreat too easy |
| `RETREAT_HOLD` | 180 ticks | 60 – 600 | Time to leave | Accidental retreats | Retreat feels stuck |
| `PUSH_MAX` | 2 u/tick | 1 – 8 | Separation speed | Lingering overlap | Visible shoving |
| `CELL` | 256 u | 128 – 512 | Query cost | Many cells | Many entries per cell |
| `GHOST_S` | 3 s | 1 – 5 | Ghost path length | Too short to plan | Clutter |
| `HARD_LIMIT` | 16,384 u | fixed | Overflow guard | — | — |

## Visual/Audio Requirements

- Edge line: appears within `EDGE_W` of the edge, never colour-only.
- Retreat zone and deployment arcs shown on the first paused frame of a battle.
- Ghost paths while paused: per ship, flagship emphasised, labelled "if
  nothing changes"; enemy ghosts shorter and dimmer (rule 8).
- Push and edge cue on the flagship (Game Feel); retreat countdown on a
  retreating ship.

## Game Feel

- **Heavy but exact.** A heavy hull visibly overshoots a 90° turn at full speed;
  it reads as weight, not lag (playtest AC-15).
- **No merging.** Hulls never draw overlapping for more than a few ticks.
- **No unexplained drift.** Whenever the flagship is pushed by contact or
  clamped at the edge, a short cue shows on it, so the player sees the cause.
- Presentation interpolates between the last two ticks (Simulation Tick & Pause
  D4), so 60 Hz motion looks smooth at any frame rate.

## UI Requirements

- Ghost-path toggle (on by default) in tactical settings.
- Range rings and arcs come from Weapons & Damage and the HUD; Combat Space
  supplies exact positions.
- 📌 **UX Flag — Combat Space**: include edge line, zones and ghost paths in the
  Combat HUD UX spec before epics.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| P3, order, no engine physics, AIM_QUANTUM | `design/gdd/simulation-tick-and-pause.md` | Rules 2, 3, 6, 14; D4 | Rule dependency |
| Motion stats, radius | `design/gdd/hulls-and-ship-definition.md` | Rules 1, 15 | Data dependency |
| `Track`, `qx/qy/qh` | `design/gdd/combat-event-bus-and-battle-record.md` | Rules 6, 9 | Data dependency |

## Acceptance Criteria

- **AC-01 (Logic; D1)**: for max_speed 200, accel 100, turn_rate 90 at 60 Hz, `v_cap` = 218,453, `a_step` = 1,820, `t_step` = 273.
- **AC-02 (Logic; rule 5)**: from rest at full throttle, that hull reaches `v_cap` on exactly tick 121; a 180° turn completes on exactly tick 121.
- **AC-03 (Logic; rule 3)**: `qh = h >> 8` for all 65,536 headings matches the Battle Record encoding; `qx = pos_x >> 16`.
- **AC-04 (Logic; rule 2)**: every recorded aim offset is an exact multiple of 4,096 sub-units.
- **AC-05 (Logic; rule 2, 4)**: a static check finds no float type, `sin`, `cos`, `atan2`, `sqrt` or physics-body call in Combat Space simulation code.
- **AC-06 (Logic; rule 9, D2)**: masses 1 and 3 overlapping by 8 u with `PUSH_MAX` 8 separate by 6 u and 2 u in one tick; with `PUSH_MAX` 2, by 1.5 u and 0.5 u per tick; the result is identical when the two ships' processing order is swapped.
- **AC-07 (Logic; rule 9)**: exactly coincident centres separate along x, the lower ID toward −x.
- **AC-08 (Logic; rule 11)**: a ship placed at 20,000 u is clamped to 16,384 u and a clamp is logged.
- **AC-09 (Logic; rule 15)**: over 1,000 seeded layouts of 40 ships, `query_circle` returns exactly the brute-force set, sorted by ID; `query_nearest` ties go to the lower ID.
- **AC-10 (Logic; rule 14)**: grid rebuild and queries allocate nothing over 3,600 ticks (allocation-count delta 0).
- **AC-11 (Logic; determinism)**: 3,600 ticks with 40 ships give identical `state_hash` sequences over 3 runs.
- **AC-12 (Logic; rule 10, D4)**: the fastest hull (`max_speed` 400) with throttle held outward and `EDGE_W` 200 never passes `FIELD_R`, takes no damage, and slides along the edge; a hull with retreat intent in its own zone does pass the clamp.
- **AC-13 (Logic; rule 12)**: a ship with retreat intent held in its own retreat zone is reported on exactly tick `RETREAT_HOLD`; a ship without retreat intent is never reported, however long it stays; one in the enemy's zone is never reported.
- **AC-14 (Performance)**: Combat Space's own work (movement, separation, grid) at Simulation Tick & Pause's D10 fixture takes ≤ 1.2 ms at the 95th percentile; projectile sweeps count against Weapons & Damage.
- **AC-15 (Playtest; Game Feel)**: at full speed the Spiralward visibly overshoots a 90° turn, and testers describe it as "heavy", not "laggy".
- **AC-16 (Playtest; rule 8)**: paused at any moment, the flagship's ghost path, and the ghost of a ship under a direct order, predicts its position 3 s later within one hull radius (with no new input), including separation and the edge.
- **AC-16b (Visual; rule 8)**: enemy ghosts are visibly shorter and dimmer than friendly ones, and every ghost is labelled "if nothing changes".
- **AC-18 (Logic; rule 6a)**: a Vigor multiplier of 800 and a Coherence multiplier of 500 on `v_cap` 218,453 apply in ascending system order with `modifier_compose` rounding, giving (218,453 × 800 + 500) div 1,000 = 174,762, then (174,762 × 500 + 500) div 1,000 = 87,381; both multipliers appear on the HUD.
- **AC-19 (Visual; Game Feel)**: whenever the flagship is moved by separation or clamped at the edge, a short cue shows on it within one frame.
- **AC-17 (Visual)**: in screenshots of a 12-ship melee, no two hulls draw overlapping for more than `ceil(overlap ÷ PUSH_MAX)` ticks.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Q16.16 fixed point and the 1.2 ms allocation** need a technical-director review and a spike; GDScript integer vs float speed is NOT SOURCEABLE. | technical-director, engine-programmer | Tick/determinism ADR spike |
| 2 | **`FIELD_R` vs weapon ranges**: confirm when Weapons & Damage sets ranges (rule 10). | Weapons & Damage (#12) | When #12 is designed |
| 3 | **Ramming / contact damage** — not at MVP; revisit with a balance pass. | game-designer | Post-MVP |
| 4 | **Obstacles and terrain** (asteroids, nebulae) — hook only at MVP. | game-designer, level-designer | Post-MVP |
| 5 | **`world_radius` type** (integer u) must be confirmed in Hulls' presentation block. | art-director | Art bible |
