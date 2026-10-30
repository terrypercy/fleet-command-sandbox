# Fleet Coordination

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (SR shown, reveal events, flagship lock, splinter credit, scope note)
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — enemy doctrine is fixed and readable, so a loss names a counter); Pillar 5 (Living Against Made — machine doctrine depends on the link graph); Pillar 4 (Plan in the Open — doctrine is learnable and shown in the Dossier). Out of scope: player machine ships (Coherence & Links rule 17, post-MVP) and organic enemy fleets (Ship AI Open Q2); each needs its own doctrine family under Pillar 5, not a reuse of this one.

## Summary

Fleet Coordination is the fleet-level brain. It runs a fixed, data-authored doctrine for each enemy machine fleet (formation, battle phases, focus sharing) and writes each ship's goal and focus into Fleet Orders' slots; for player ships with no goal it supplies the default doctrine. Its grip follows the link graph: a fraying fleet contracts, a broken one splinters into individual, predictable ships, and every phase change is telegraphed first.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Deterministic RNG & Seed Streams, Fleet Orders, Ship AI, Runtime ID Service`

## Overview

Fleet Coordination is the fleet-level brain. For **enemy machine fleets**, it
runs a fixed **doctrine**: it places ships in a formation around their relay
or keystone, moves the fleet through battle phases, shares out focus fire, and
writes every ship's goals and focus directly into Fleet Orders' slots for Ship
AI to execute. For **player ships with no goal**, it supplies the default
doctrine Ship AI falls back to.

Doctrine is **data and fixed**: each enemy fleet or stronghold has one, authored
by Machine Nodes & Strongholds, which never changes in battle and is never
touched by difficulty. That is what lets the Dossier describe it truthfully and
a counter stay valid (Pillars 1 and 4). Its strength depends on the link graph:
as the fleet's Coherence frays, the formation contracts; when it breaks, Fleet
Coordination writes nothing, and the formation **splinters into individual,
predictable ships** (concept). Every phase change is telegraphed before it
happens.

## Player Fantasy

**The machine is one mind, and I can cut it into many.** The enemy moves as a
single will: the screen closes around its relay, every gun turns on one target.
The player learns the pattern from the Dossier and the Debrief, then makes the
cut, and watches one mind become five confused ships.

*Anchor moment:* a Lattice Screen holds a front arc around its relay. The
player's severing fire strains two links; the relay pulses and the slot ghosts
pull in (a tell, 1.5 s); the screen contracts. Then the relay dies, and the
five escorts stop where they are, each firing at whatever is nearest.

**Pillars served:**
- **Pillar 1:** doctrine is fixed and recorded, so a loss names a counter.
- **Pillar 5:** machine doctrine depends on the link graph, end to end.
- **Pillar 4:** doctrine is described from its own data; changes are telegraphed.

**This system must never make the player feel:** "they changed tactics for no
reason", "the Dossier lied about how they fight", or "the AI just broke"; the
splinter must read as my cut working.

## Detailed Design

### Core Rules

**A. Doctrine**

1. **Doctrine is a `doctrine` content kind** with: `formation` (template,
   anchor, `r_pm`, `spread`, `col_sp`), target `priority` weights, `engage`
   thresholds, `on_cut` (`reflow`, `hold_gap` or `contract`), `fray_r_pm`,
   `focus_share_pm` and `focus_split`. MVP has three:
   - **Lattice Screen**: a front arc around the relay; heavy relay guarding;
     reflows after a cut.
   - **Spear**: a column ahead of the relay; all fire on one target (flagship
     weighted high); leaves the gap after a cut.
   - **Anvil**: a full ring around a keystone; never advances past its anchor
     leash; contracts after a cut.
2. **Doctrine is fixed.** Each enemy fleet or stronghold has one `doctrine_id`
   (authored by Machine Nodes & Strongholds). It never changes in battle;
   `stronghold_strength` and `enemy_ai_level` never read it (Gameplay Settings
   & Modifiers rule 10).
3. **The Dossier text is generated from the doctrine's fields** (template plus
   values), never written by hand; if the data changes, the description
   changes with it. It states `consolidate_sr` and `withdraw_sr` as ratios
   (e.g. "falls back when outmatched 5:3; breaks at 1:4"). Fleet Coordination
   supplies one generated sentence per doctrine field, each tagged with the
   event that reveals it (e.g. `on_cut` by a logged reflow, contraction or
   gap-hold; `focus_split` by a logged `FocusAssigned`). The Dossier owns when
   sentences are revealed; this system guarantees every field has a reveal
   event that can be seen in battle.
4. **Anchors.** Each root relay or keystone anchors one formation of the ships in
   its subtree (Coherence & Links rule 2). The relay itself holds at
   `anchor_back` behind the screen.

**B. Running a fleet**

5. **Phases**: APPROACH → ENGAGE → CONSOLIDATE → WITHDRAW, plus SUSPENDED
   (triggers, Formulas D2). Strongholds never withdraw (`withdraw_sr` 0);
   roaming machine fleets withdraw at `withdraw_sr` 250, a readable "they broke"
   win state.
6. **Goal writing.** Fleet Coordination writes Move, Hold, Escort or Attack goals
   and Focus targets directly into Fleet Orders' slots, never through the order
   queue (Fleet Orders rule 11). Only LINKED and RELAYED ships receive goals; a
   cut ship's goal stays SUSPENDED (Fleet Orders rule 10).
7. **Cadence.** A fleet decides every `FLEET_DECIDE_N` (30) ticks, staggered by
   fleet ID, and immediately on an interrupt: a band change, a link snapping in
   the fleet, the Focus target dying or retreating, a phase taking effect. It
   runs at the start of P2, before Ship AI, reading Coherence one tick stale.
   `FLEET_DECIDE_N` is the same at every AI level; execution scales only through
   Ship AI's `ExecParams`.
8. **Determinism.** One draw per fleet per tick on
   `base:fleet.tiebreak#<fleet_id>`, decision or not; ties go to the draw, then
   the lower Runtime ID; candidates in ascending Runtime ID; integer arithmetic
   with Combat Space's angle units and tables.

**C. Coherence, the player, and visibility**

9. **Response to Coherence** (Coherence & Links rule 4):
   - **WHOLE**: the template as authored;
   - **FRAYING**: radius to `fray_r_pm`; phase forced to CONSOLIDATE; focus share
     halved;
   - **BROKEN**: nothing is written; every goal is SUSPENDED; ships fall to their
     cut behaviour (Coherence & Links rule 7; Ship AI rule 11);
   - **relinked to FRAYING or better**: doctrine resumes in CONSOLIDATE, after a
     tell.
10. **The player default doctrine** applies only to player ships with no goal:
    Ship AI treats them as a loose Escort of the flagship (Fleet Orders D2 screen,
    D5 leash), following the fleet's Focus slot and never retreating. Nothing is
    written into the Goal slot, so the Debrief can tell "ordered" from "default".
11. **Telegraphs.** A phase change, reflow or contraction is declared at tick T
    and takes effect at T + `TELL_TICKS` (90 ticks, 1.5 s), shown as a pulse on
    the anchor relay and slot ghosts. The lead is the same at every AI level and
    longer than the slowest reaction delay. BROKEN suspension is immediate: the
    snapped lines are its tell. A `FocusAssigned` whose target is the flagship
    is shown at once as a lock marker from each assigned ship, visible while the
    assignment holds; focus is not delayed by `TELL_TICKS`, only made visible
    immediately.
12. **The record.** Record-tier events (never dropped like `TargetChosen`):
    `DoctrinePhase(fleet, doctrine, from, to, cause, declared_tick,
    effective_tick)` (for BROKEN, `cause` names the destroyed ship and the
    snapped link) and `FocusAssigned(fleet, target, ships, reason)`; and an
    end-of-battle `DoctrineSummary` (ticks per phase, slot occupancy, focus
    targets) in the Battle Record's aggregates.

### States and Transitions

| Phase | Entered when | Leaves to |
|---|---|---|
| APPROACH | battle start | ENGAGE |
| ENGAGE | an enemy within engage range | CONSOLIDATE, WITHDRAW, SUSPENDED |
| CONSOLIDATE | strength ratio low, or band FRAYING | ENGAGE, WITHDRAW, SUSPENDED |
| WITHDRAW | strength ratio ≤ `withdraw_sr` (roaming fleets only) | — |
| SUSPENDED | band BROKEN, from any phase | CONSOLIDATE (relinked to FRAYING or better) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Fleet Orders (#19) | #21 → #19 | Writes enemy Goal and Focus slots directly |
| Ship AI (#20) | #21 → #20 | Goals; player default doctrine |
| Coherence & Links (#14) | #14 → #21 | Bands, published state (read only) |
| Machine Nodes & Strongholds (#23) | #23 → #21 | `doctrine_id`, anchors, layouts |
| Deterministic RNG & Seed Streams (#2) | #2 → #21 | `base:fleet.tiebreak#<fleet_id>` |
| Combat Event Bus & Battle Record (#9) | #21 → #9 | `DoctrinePhase`, `FocusAssigned`, `DoctrineSummary` |
| After-Action Debrief (#24) | #9 → #24 | Doctrine causes |
| AI-vs-AI Runner (#25) | #21 → #25 | Debug data, draw counts |
| Dossier | #21 → Dossier | Generated doctrine text |
| Simulation Tick & Pause (#1) | — | Runs at the start of P2, before Ship AI (amendment) |

## Formulas

### D1. Formation slot

`r = min(r_pm, LINK_SAFE_PM) × link_range ÷ 1,000`;
`bearing_i = θ + (i − (n − 1) ÷ 2) × spread`, where θ is the bearing to
`query_nearest(enemy)` (else the fleet's heading) and i = 0 … n − 1 over linked
non-anchor ships in ascending Runtime ID. Spear: slot i at `A + (r − i ×
col_sp)` along θ.

| Variable | Range | Description |
|---|---|---|
| r_pm | 300 – 850 (capped by `LINK_SAFE_PM`) | Formation radius share of link range |
| spread | 0 – 60° | Slot spacing |

### D2. Strength ratio and phases

`str = Σ (hull_now × dps_rating) div 1,000`; `SR‰ = own × 1,000 ÷ max(1, enemy)`.
APPROACH → ENGAGE: nearest enemy ≤ `engage_pm × link_range ÷ 1,000`. ENGAGE →
CONSOLIDATE: SR ≤ `consolidate_sr` (600) or band FRAYING. Back to ENGAGE: SR ≥
`consolidate_sr` + 100 and band WHOLE. → WITHDRAW: SR ≤ `withdraw_sr`.

### D3. Focus distribution

`k = max(1, focus_share_pm × n_linked div 1,000)` ships on Focus; the target is
the highest weighted score (Ship AI D1 terms plus `relay_attacker` and
`is_flagship`); the k ships nearest the target take it. With `focus_split` 2,
assign round-robin over the top two targets.

### Worked example: a Lattice Screen loses its relay

Relay L-01 plus five escorts (Coherence & Links D6); `link_range` 1,200, `r_pm`
550 → r = **660**; spread 30°, θ = 0°. Slots at −60°, −30°, 0°, +30°, +60°:
about (330, −572), (572, −330), (660, 0), (572, 330), (330, 572). Focus: 600 × 5
div 1,000 → **k = 3**; two stay as relay guards.
- **Severing two escorts (demand 6 + 6)**: C‰ = 18 × 1,000 ÷ 30 = **600, FRAYING**.
  A 90-tick tell, then r = 400 × 1.2 = **480** and k = **1** (share halved); the
  three linked escorts reflow to −30°, 0°, +30°.
- **Killing L-01 at T**: C‰ = 0, **BROKEN**. At T + 1 nothing is written;
  `DoctrinePhase(ENGAGE → SUSPENDED, band_broken)` is logged. With no provider,
  `SEEK_RELAY` falls back to `HOLD_STATION`: five ships sit still and fire at the
  nearest enemy. That is the splinter.

## Edge Cases

- **If an enemy fleet has no relay**: content validation refuses it.
- **If the anchor relay is stalled**: slots hold; the band decides what follows.
- **If a fleet has several roots**: one formation per root.
- **If no escort is linked**: only the relay holds.
- **If the Focus target retreats**: re-decide the same tick.
- **If the band goes BROKEN during a tell**: the tell is cancelled and logged.
- **If a keystone anchors the formation**: Anvil only (it cannot move).
- **If a slot falls outside the field**: clamped to `FIELD_R − EDGE_W`.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | P2 order |
| Deterministic RNG & Seed Streams (#2) | Hard | Tie-break stream |
| Fleet Orders (#19), Ship AI (#20) | Hard | Slots, execution |
| Coherence & Links (#14) | Hard | Bands |
| Runtime ID Service (#3) | Hard | Order and identity |
| Machine Nodes & Strongholds (#23), Debrief (#24), Runner (#25), Dossier | Hard (reverse) | Doctrine, causes, debug |

Bidirectional check: Fleet Orders and Ship AI name Fleet Coordination.

## Tuning Knobs

| Knob | Default | Safe range |
|---|---|---|
| `FLEET_DECIDE_N` | 30 | 15 – 60 |
| `TELL_TICKS` | 90 | 60 – 180 |
| `r_pm`, `fray_r_pm`, `spread`, `col_sp` | per doctrine | D1 ranges |
| `consolidate_sr` | 600 | 400 – 800 |
| SR hysteresis | 100 | 50 – 200 |
| `withdraw_sr` | 0 (strongholds), 250 (roaming) | 0 – 400 |
| `focus_share_pm` | 600 | 200 – 1,000 |
| `engage_pm` | 1,100 | 900 – 1,500 |

All in `assets/data/doctrine/`.

## Visual/Audio Requirements

- Tells: the anchor relay pulses and slot ghosts appear for `TELL_TICKS`.
- The splinter (BROKEN) must read at once: formation lines vanish and ships stop
  moving as one. BROKEN plays a distinct audio sting, and the Debrief credits
  the kill that caused it (`DoctrinePhase.cause`).
- Flagship focus: a lock marker from each assigned ship (rule 11).

## Game Feel

- **One mind, then many**: a whole formation moves as a unit until it breaks.
- **No surprises**: every shift is announced.

## UI Requirements

- Paused: the formation's slots and phase name over each enemy fleet; the tell
  countdown when one is running; each enemy fleet's strength ratio against the
  player's fleet, marked with its `consolidate_sr` and `withdraw_sr` thresholds.
- Live: flagship lock markers (rule 11).
- Dossier: the generated doctrine description per node.
- 📌 **UX Flag — Fleet Coordination**: include formation slots, phase names and
  tells in the Combat HUD UX spec; the doctrine text in the Dossier spec.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Slots, suspension | `design/gdd/fleet-orders.md` | Rules 6, 10, 11; D2, D5 | Rule dependency |
| Execution, `LINK_SAFE_PM`, scoring | `design/gdd/ship-ai.md` | Rules 2–5, 9–13; D1 | Rule dependency |
| Bands, cut behaviours | `design/gdd/coherence-and-links.md` | Rules 2–8, 19; D6 | Rule dependency |
| Doctrine unaffected by difficulty | `design/gdd/gameplay-settings-and-modifiers.md` | Rule 10 | Rule dependency |
| Doctrine events | `design/gdd/combat-event-bus-and-battle-record.md` | Rules 9, 13 | Data dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 8)**: the same seed and command log give identical `DoctrinePhase` and `FocusAssigned` streams across two runs; exactly one tie-break draw per fleet per tick.
- **AC-02 (Logic; rule 2)**: at L0 and L4, phase effective ticks and focus targets are identical; only Ship AI execution differs.
- **AC-03 (Logic; rule 2)**: changing `stronghold_strength` changes ship counts and stats, never the `doctrine_id`.
- **AC-04 (Logic; rule 11)**: every phase change has `effective_tick − declared_tick = TELL_TICKS`, except BROKEN suspension.
- **AC-05 (Logic; rule 9)**: while BROKEN no slot is written; on relink to FRAYING or better, CONSOLIDATE resumes after a tell; at FRAYING every slot radius equals `fray_r_pm × link_range ÷ 1,000` (±1 u).
- **AC-06 (Logic; D1)**: no formation slot lies beyond `LINK_SAFE_PM` of `link_range`.
- **AC-07 (Logic; rule 6)**: cut ships never receive new goals.
- **AC-08 (Logic; D3)**: the k from D3 equals the number of ships whose Focus slot is set.
- **AC-09 (Logic; worked example)**: the Lattice fixture reproduces the slots, k and the BROKEN timing.
- **AC-10 (Logic; rule 3)**: every Dossier sentence maps to a doctrine field, changing the field changes the sentence, and an AI-vs-AI test confirms the described behaviour (e.g. "Spear leaves gaps").
- **AC-11 (Logic; rule 10)**: player ships with no goal keep an empty Goal slot and stay within `ESCORT_LEASH` of the flagship.
- **AC-12 (Logic; rule 12)**: `DoctrinePhase` and `FocusAssigned` survive a full Battle Record.
- **AC-13 (Logic; rule 5)**: a roaming fleet withdraws at SR ≤ 250; a stronghold never withdraws.
- **AC-14 (Playtest)**: 4 of 5 testers can describe a formation's weakness after one loss.
- **AC-15 (Logic; D2, UI)**: when paused, the displayed SR equals D2's SR‰ ±1 for every enemy fleet.
- **AC-16 (Logic; rule 3)**: every doctrine field has a reveal event that a Battle Record fixture can produce.
- **AC-17 (Logic; rule 11)**: every flagship-targeted `FocusAssigned` emits a visible lock on the same tick.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **P2 order** (Fleet Coordination before Ship AI) must be written into Simulation Tick & Pause's phase table. | Tick owner | Tick re-review |
| 2 | **A fourth doctrine** ("Swarm": many small relays). | game-designer | Post-MVP |
| 3 | **Doctrine values** are starting points for the AI-vs-AI Runner. | systems-designer | Runner tuning |
