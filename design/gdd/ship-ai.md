# Ship AI

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on hidden ember verdicts, hold-cap precedence, rationing missing from the Debrief, the mode contradiction, and ally readability at L4; all five revised, plus lent ships and pillar order
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — AI choices and rationing are recorded with reasons); Pillar 5 (Living Against Made — two behaviour families, Vigor and Coherence); Pillar 4 (Plan in the Open — every pause in fire is explained in words); Pillar 3 (Hands on the Helm — ships carry out orders as goals, never puppets)

## Summary

Ship AI runs every ship but the flagship: a fixed pipeline (goal executor,
targeting, weapons, movement) with integer utility scores, staggered decisions
and deterministic tie-breaks, turning goals into steering, aim and fire. Orders
are goals it never changes in kind. Organic ships ration Vigor and turn fresh
flanks; machine ships fire on a steady beat, guard their relays and switch to a
cut behaviour when their link snaps. Difficulty changes execution only, and
every target choice carries a reason the Debrief can read (Pillars 3, 5 and 1).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Deterministic RNG & Seed Streams, Gameplay Settings & Modifiers, Combat Event Bus & Battle Record, Combat Space, Weapons & Damage, Vigor, Coherence & Links, Fleet Orders`

## Overview

Ship AI runs one ship's behaviour, every ship but the flagship, in phase P2 of
each battle tick. It turns a goal (from Fleet Orders for player ships, from
Fleet Coordination for enemies) into the intents other systems consume: a
desired heading and thrust vector for Combat Space, an aim and fire intent per
weapon slot for Weapons & Damage, and retreat intent where allowed.

It is a **fixed-layer pipeline**: goal executor → targeting → weapons →
movement, with **integer utility scores** inside targeting and weapon use, and
a small set of modes (Normal, Rationing, Cut, Suspended, Retreating). It is
deterministic: candidates come from Combat Space queries in ascending Runtime
ID, ties break on the AI's keyed stream then Runtime ID, and nothing reads a
float or the wall clock.

Two behaviour families carry Pillar 5: **organic ships ration Vigor**, turn a
fresh flank to spare struck cores and stand off when empty; **machine ships**
fire on a steady beat, stay inside link range, converge on whoever attacks
their relay, and switch to a visible cut behaviour when their link snaps. At
MVP every organic AI ship is the player's and every enemy is a machine.

## Player Fantasy

**Crew who understand the goal, against opponents you can read.** The player
says *what*; their captains work out *how*: flanking, rationing fire, turning a
fresh side to the enemy. And the enemy machines are precise and legible, a
pattern the player learns to break by cutting their links.

*Anchor moment:* the player's Seedcaller pauses its fire as its Vigor runs
low; a moment later it fires one finishing shot into a damaged Vector Line.
Across the field, the machine escorts swing as one toward the frigate attacking
their relay.

**Pillars served:**
- **Pillar 3:** ships execute goals and never change what was ordered (rule 3).
- **Pillar 5:** two visibly different behaviour families (rule 12).
- **Pillar 1:** every target choice carries a reason code the Debrief can read
  (rule 14).

**This system must never make the player feel:** "my ships did something dumb
with Vigor" or "the enemy cheats".

## Detailed Design

### Core Rules

**A. Pipeline and cadence**

1. **Four fixed layers**, every tick, per ship in ascending Runtime ID: goal
   executor → targeting → weapons → movement. Modes are a small explicit state
   (Normal, Rationing, Cut, Suspended, Retreating).
2. **Cadence.** Steering, per-slot fire intent and the ember check run every
   tick. Full re-scoring runs when `(tick + ship_id) mod DECIDE_N == 0`
   (staggered), and immediately on an **interrupt**: Focus change, target
   destroyed or retreated, goal change, `LinkState` change, Coherence band
   change, or first damage from a new attacker. A Focus change is a slot read,
   not a re-score. The AI's keyed tie-break stream is drawn once per ship per
   tick, decision or not (Deterministic RNG & Seed Streams rule 7).
3. **Orders are goals** (Fleet Orders rule 6). The executor may choose path,
   throttle, facing, range band, ember policy, dodging and targets of
   opportunity within the goal's leash. It may never change the goal's kind,
   leave its leash (Fleet Orders D4, D5), ignore an in-range Focus target, or
   set retreat intent for a player ship (Fleet Orders rule 7).

**B. Layers**

4. **Goal executor**: Move (arrive per Fleet Orders D1, then anchor); Attack
   (close to the range band; at EMPTY stand off at maximum range); Escort (hold
   the D2 slot, engage within D5); Hold (engage within D4); Regroup (D3, then
   Escort); Retreat (steer to the own retreat zone, set retreat intent). With
   no goal, doctrine from Fleet Coordination applies. The leash is checked before
   any movement is output.
5. **Targeting**: (1) the Focus target, if in range or within the leash
   (mandatory); (2) the Attack goal's target; (3) the best score (D1) among
   enemies from `query_circle` over leash ∩ maximum range. A cut machine
   targets `query_nearest` (Coherence & Links rule 6). A slot that cannot bear on
   the primary target may take the in-arc enemy with the best shown hit chance
   (Weapons & Damage D5), recorded as `opportunity`.
6. **Aim.** Ship AI owns its ships' aim: the bearing to the target with **lead**
   of `lead_pm` of the target's current velocity (rule 13), quantized like any
   aim. Weapons & Damage then draws spread.
7. **Weapons — the organic ember policy** (closes Vigor Open Question 3). Holding
   fire visibly protects: the membrane scales with `P ÷ C` and every spend
   erodes the ceiling (Vigor rules 6–7). By band:
   - **OK**: fire every slot that bears;
   - **LOW**: fire a slot only if its shown hit chance ≥ `RATION_HIT_PM` (400 ‰),
     or the shot is a finishing shot (damage ≥ target's hull), or the target is
     the Focus target;
   - **below `RESERVE_PM`** (150 ‰ of `C`): hold everything except Focus and
     finishing shots;
   - **EMPTY**: ember shots only at the Focus target or finishing shots;
   - **FLOOR**: fire freely (erosion has stopped, Vigor rule 9).
   **Hold cap**: never hold more than `MAX_HOLD_TICKS` (180) while a valid target
   offers a shown hit chance ≥ 600 ‰. The cap applies **at LOW and below
   `RESERVE_PM` only**; at EMPTY only Focus and finishing shots fire; at FLOOR
   there is nothing to cap. Opportunity shots (rule 5) obey the same band
   verdict.
8. **Fed weapons when cut**: no fire intent; fed mounts are left out of the
   range band (D2) until relinked.
9. **Movement**:
   - stay inside the range band (D2);
   - a hull with `blind_rear` keeps the main threat's bearing outside the stern
     arc + 15°;
   - **organic ships turn a fresh flank**: when the core facing the threat has
     `C_k` below `FLANK_PM` (700 ‰) of the cores' mean, rotate toward the
     freshest core, if the guns still bear;
   - **dodging** is a deterministic jink (`lat = ±JINK_PM`, sign flipped every
     `JINK_PERIOD` ticks by ID parity, no draw), only while large projectiles
     are inbound;
   - **machine ships** keep their desired position within `LINK_SAFE_PM`
     (850 ‰) of their provider's `link_range`.
10. **Self-preservation (enemy only)**: at hull ≤ `retreat_hull_pm` (hull
    doctrine data; machine default 0 = never), retreat intent is set after the
    level's retreat delay (rule 13). Player ships never self-retreat.
11. **Cut behaviour** (Coherence & Links rule 7): within one tick of `SNAPPED`, a
    machine switches to its `cut_behaviour`, with nearest-targeting and the
    published multipliers; with its fleet's band BROKEN, no fleet goal runs.

**C. Families, levels and reasons**

12. **Two behaviour families a player can see:**
    1. **fire cadence**: organic fire varies with Vigor (visible rationing
       pauses, then finishing shots); machine fire is a steady beat until cut,
       then fed guns go dark;
    2. **facing**: organics turn a fresh flank; machines hold formation facing;
    3. **pursuit**: machines break off at the edge of link range (learnable);
       organics chase within their leash and stand off when empty;
    4. **relay protection**: machine escorts converge on whatever attacks their
       relay (`relay_guard`); organic escorts guard only their ward;
    5. **when cut**: machines switch to one of four distinct cut behaviours;
       organics have no cut state; they degrade gradually through Vigor bands.
13. **`enemy_ai_level` changes execution only** (Gameplay Settings & Modifiers
    rule 10). It enters only through an `ExecParams` table; candidate sets,
    utility terms, weights, cut behaviours and thresholds never read it:

    | Parameter | L0 | L1 | L2 | L3 | L4 |
    |---|---|---|---|---|---|
    | Reaction delay (ticks, interrupt to act) | 30 | 20 | 12 | 6 | 3 |
    | Aim lead (`lead_pm`) | 0 | 500 | 750 | 900 | 1,000 |
    | Focus join delay (ticks) | 60 | 40 | 24 | 12 | 6 |
    | `DECIDE_N` | 12 | 10 | 8 | 6 | 6 |
    | Retreat delay past threshold (ticks) | 120 | 90 | 60 | 30 | 15 |

    **Player ships** always use `ALLY_EXEC` = the L2 row; the difficulty setting
    never changes them. **Relay strikes stay a player skill**: player escorts
    prefer relays on their own only if SEVERING-armed (`relay_strike`).
14. **Reason codes** for `TargetChosen` (Battle Record rule 9; emitted on change
    only): `focus_called`, `ordered`, `retaliate`, `threat`, `lowest_hull`,
    `nearest`, and new `relay_guard`, `relay_strike`, `opportunity` (raising
    `EVENT_SCHEMA_VERSION`). An interrupt-forced choice uses its cause;
    otherwise the code is the largest weighted term. Because `TargetChosen` is
    the first event dropped when a record fills (Battle Record rule 17), no
    Debrief-critical fact lives only in it. **Rationing reaches the Debrief**:
    Ship AI accumulates per-ship counters (held-fire ticks per Vigor band,
    ember shots fired) into the Battle Record's end-of-battle aggregates, so the
    Debrief can say "your line held fire 40 % of the engagement at LOW Vigor".
15. **Budget**: Ship AI ≤ `AI_SHARE_MS` (0.35 ms) at the 95th percentile on the
    D10 steady fixture; scratch buffers are preallocated; no allocation in P2.
    *Whether GDScript meets this is NOT SOURCEABLE until the D10 spike.*
16. **Debug view** (presentation only, not hashed): per ship the top three
    candidates with each score term, mode, Vigor band and per-slot ember verdict
    with hold counter, leash ring, range band, link leash, next decide tick, and
    tie-break draw counts (for the AI-vs-AI Runner).

### States and Transitions

| Mode | Entered when | Leaves to |
|---|---|---|
| Normal | default | Rationing (organic LOW or below), Cut (machine snapped), Suspended (band BROKEN), Retreating (retreat intent) |
| Rationing | organic band LOW, below `RESERVE_PM`, or EMPTY | Normal (band recovers, or FLOOR: fires freely), Retreating |
| Cut | machine link snapped | Normal (relinked) |
| Suspended | fleet band BROKEN | Normal (band recovers) |
| Retreating | retreat intent (order, or enemy self-preservation) | Departed (Combat Space) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Fleet Orders (#19) | #19 → #20 | Goal and Focus slots; may / may-not list; leashes |
| Fleet Coordination (#21) | #21 → #20 | Enemy goals and doctrine when no goal |
| Combat Space (#11) | both | Queries; desired heading and thrust; multipliers; retreat intent |
| Weapons & Damage (#12) | #20 → #12 | Aim (with lead) and fire intent per slot; shown hit chance used for scoring (no draw) |
| Vigor (#13) | #13 → #20 | Bands, `P`, `C`, per-core `C_k`; closes Vigor Open Question 3 |
| Coherence & Links (#14) | #14 → #20 | Published state, cut behaviours, band doctrine |
| Deterministic RNG & Seed Streams (#2) | #2 → #20 | One tie-break draw per ship per tick |
| Gameplay Settings & Modifiers (#7) | #7 → #20 | `enemy_ai_level` → `ExecParams` only |
| Combat Event Bus & Battle Record (#9) | #20 → #9 | `TargetChosen` with reason codes |
| AI-vs-AI Runner (#25) | #20 → #25 | Debug data, draw counts |

## Formulas

### D1. Target score

`S = 4 × threat + 3 × (1,000 − hull‰) + 2 × hit‰ + dist + role + stick`

| Term | Range | Definition |
|---|---|---|
| threat | 0 – 1,000 | `min(1,000, dps_vs_me × 1,000 div THREAT_DPS_REF)`, halved if I am outside its range |
| hull‰ | 0 – 1,000 | Target's hull share |
| hit‰ | 0 – 1,000 | Shown hit chance (Weapons & Damage D5) |
| dist | 0 – 1,000 | `max(0, (R_max − d) × 1,000 div R_max)` |
| role | 0 / 600 / 800 | `relay_strike` (SEVERING-armed organics) 600; `relay_guard` (machines) 800 |
| stick | 0 / 150 | 150 if the candidate is the current target |

**Example** (R_max 800): a relay 500 u away, hull 60 %, hit 229 ‰, threat 300,
attacker SEVERING-armed → 1,200 + 1,200 + 458 + 375 + 600 = **3,833**. A line ship
300 u away, hull 90 %, hit 450 ‰, threat 700, the current target → 2,800 + 300 +
900 + 625 + 150 = **4,775**. The line ship wins; the code is `threat`.

### D2. Range band

Sort the ship's usable slots by `range_u`, longest first, accumulating DPS share;
`hi` = the range at which the cumulative share reaches `BAND_DPS_PM` (600 ‰),
× 900 ‰; `lo = hi × 600 ‰`.
**Example:** 800 u at 25 % share and 400 u at 75 %: share reaches 600 ‰ at 400 u →
hi = **360**, lo = **216**. At EMPTY, hi = longest range × 900 ‰ = 720. Cut: fed
slots excluded.

## Edge Cases

- **If the Focus target is outside the leash**: hold the leash; engage when it
  enters.
- **If the Focus target offers a finishing shot at EMPTY**: fire the ember.
- **If the target retreats**: `OrderEnded`, re-decide that tick.
- **If `SEEK_RELAY` has no provider**: behaves as `HOLD_STATION` (Coherence &
  Links rule 7).
- **If every core is dark**: rationing uses `C_floor`.
- **If an escort's ward dies**: anchor where it is (Fleet Orders).
- **If a ship is disabled or destroyed on tick T**: it makes no draw on T.
- **If a ship is lent by a faction**: it is a player ship: `ALLY_EXEC`, Fleet
  Orders goals, its race's behaviour family.
- **If two candidates tie exactly**: tie-break draw, then lower Runtime ID;
  adding an unrelated candidate never changes the winner.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Deterministic RNG & Seed Streams (#2) | Hard | Tie-break stream |
| Gameplay Settings & Modifiers (#7) | Hard | `enemy_ai_level` |
| Combat Event Bus & Battle Record (#9) | Hard | `TargetChosen` |
| Combat Space (#11), Weapons & Damage (#12), Vigor (#13), Coherence & Links (#14) | Hard | State and intents |
| Fleet Orders (#19), Fleet Coordination (#21) | Hard | Goals |
| AI-vs-AI Runner (#25) | Soft (reverse) | Debug data |

Bidirectional check: Fleet Orders, Combat Space, Weapons, Vigor, Coherence and
Settings name Ship AI.

## Tuning Knobs

| Knob | Default | Safe range |
|---|---|---|
| Score weights | 4 / 3 / 2 / 1 | 0 – 8 |
| `THREAT_DPS_REF` | data | per balance |
| `DECIDE_N` | per level | 4 – 12 |
| `RATION_HIT_PM` | 400 | 250 – 600 |
| `RESERVE_PM` | 150 | 100 – 300 |
| `MAX_HOLD_TICKS` | 180 | 60 – 300 |
| `FLANK_PM` | 700 | 500 – 900 |
| `JINK_PM`, `JINK_PERIOD` | data | feel |
| `LINK_SAFE_PM` | 850 | 700 – 950 |
| `BAND_DPS_PM` | 600 | 400 – 800 |
| `ExecParams` table | rule 13 | per level |
| `retreat_hull_pm` | 0 (machines) | 0 – 500 |
| `AI_SHARE_MS` | 0.35 ms | 0.25 – 0.5 |

All in `assets/data/ai/`.

## Visual/Audio Requirements

- The five family differences (rule 12) must be visible at combat zoom.
- A brief "rationing" cue on an organic ship holding fire (shape, not colour).

## Game Feel

- **Allies look deliberate**: pauses in fire read as choices, followed by
  finishing shots.
- **Enemies look precise but breakable**: a steady beat, then visible disarray
  after a cut.

## UI Requirements

- Hovering an ally while paused shows its goal, target and reason in words
  ("Attacking: threat"), and **each slot's ember verdict in words with the
  deciding number** ("Holding: Vigor LOW, hit 23 % < 40 %"; "Firing: finishing
  shot"; "Firing: Focus").
- The debug overlay (rule 16) is a developer view, also used by the AI-vs-AI
  Runner.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Goals, may / may-not, leashes | `design/gdd/fleet-orders.md` | Rules 1, 5–7, 10–11; D1–D5 | Rule dependency |
| Intents, queries, multipliers | `design/gdd/combat-space.md` | Rules 5, 6a, 12, 15 | Rule dependency |
| Fire, spread, shown hit chance | `design/gdd/weapons-and-damage.md` | Rules 3, 4, 9, 10; D5 | Rule dependency |
| Bands, membrane, ember | `design/gdd/vigor.md` | Rules 5–10; Open Question 3 (closed here) | Rule dependency |
| Cut behaviours, band doctrine | `design/gdd/coherence-and-links.md` | Rules 4–8 | Rule dependency |
| Reason codes | `design/gdd/combat-event-bus-and-battle-record.md` | Rules 9, 17 | Data dependency |
| Execution-only AI level | `design/gdd/gameplay-settings-and-modifiers.md` | Rule 10; AC-21 | Rule dependency |
| Tie-break draws | `design/gdd/deterministic-rng-and-seed-streams.md` | Rule 7; AC-19 | Rule dependency |

## Acceptance Criteria

- **AC-01 (Logic; determinism)**: the D10 fixture gives the same `state_hash` across 3 runs; a save, load and continue hashes the same as an uninterrupted run.
- **AC-02 (Logic; rule 2)**: exactly one tie-break draw per ship per tick.
- **AC-03 (Logic; D1)**: the worked scores are 3,833 and 4,775 and the line ship is chosen with code `threat`; for a tied pair, adding an unrelated candidate leaves the winner unchanged.
- **AC-04 (Performance; rule 15)**: P2 Ship AI ≤ 0.35 ms at the 95th percentile on the D10 steady fixture; the full-retarget scene stays within `sim_budget_ms`.
- **AC-05 (Logic; rule 3)**: across a scripted goal matrix, no goal's kind ever changes and no ship leaves its D4/D5 leash.
- **AC-06 (Logic; rule 3)**: an in-range Focus target is fired on within the reaction delay + 1 tick, even at LOW or EMPTY.
- **AC-07 (Logic; rules 3, 10)**: a player ship never sets retreat intent without a Retreat order.
- **AC-08 (Logic; rule 7)**: each band gives the specified fire or hold verdict; FLOOR fires freely; the `MAX_HOLD_TICKS` cap holds at LOW and below RESERVE and never forces a non-Focus, non-finishing shot at EMPTY; opportunity shots obey the band verdict.
- **AC-15 (Logic; rule 14)**: on a fixture, the per-ship held-fire ticks per band and ember-shot counts in the record equal the simulated totals.
- **AC-09 (Logic; rule 11)**: each cut behaviour starts within 1 tick of `SNAPPED` with its multipliers; fed guns get no fire intent; with the band BROKEN no fleet goal runs.
- **AC-10 (Logic; rule 14)**: `TargetChosen` is emitted on change only, with the right code for each of the 9 causes.
- **AC-11 (Logic; rule 13)**: in a forced-trigger fixture, the set of (ship, tactic) pairs is identical at L0 – L4; a static check confirms doctrine code never reads `ExecParams`; player ships behave identically at every level.
- **AC-12 (Logic; D2)**: an engaged ship stays inside its D2 band in at least 95 % of ticks.
- **AC-13 (Visual; rule 12)**: the five family differences are captured as retained screenshots in `production/qa/evidence/`.
- **AC-14 (Playtest)**: run at enemy level L2 and L4: at most 1 in 5 testers calls ally Vigor use "dumb" or "wasteful", and at least 3 of 5 can explain why a ship paused its fire using only in-game UI. If the rate rises at L4, tune the L4 `ExecParams` row, never `ALLY_EXEC`.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Budget**: 0.35 ms of the ~0.7 ms remainder needs technical-director sign-off and the D10 spike. | technical-director | Tick/determinism ADR spike |
| 2 | **Organic enemies** (post-MVP): use `retreat_hull_pm` and the organic family as opponents. | game-designer | Post-MVP |
| 4 | **All weights and thresholds** are starting values for the AI-vs-AI Runner to tune. | systems-designer | Runner tuning |
