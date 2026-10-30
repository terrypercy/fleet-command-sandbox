# Coherence & Links

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on dwell delaying cuts, SEEK_RELAY with no provider, hidden cut reasons, capacity snaps, strain-as-flux, no AC-19 fallback, and Debrief data for uncut formations; all seven revised
> **Implements Pillar**: Pillar 5 (Living Against Made — machine strength is relayed bandwidth through visible links, not a per-ship pool); Pillar 4 (Plan in the Open — link state is readable at a glance); Pillar 1 (a cut is a nameable cause and counter)

## Summary

Coherence is the machine fleets' strength: bandwidth supplied by relay ships and
carried to every machine ship through visible links that read as solid, dashed,
snapped or relayed. Linked ships fire their network-fed guns, refill wards and
fight in coordination; a cut ship keeps fighting alone until it relinks. The
satisfying moment is the cut: one relay killed, or its links severed, and a
formation comes apart. A deterministic, event-driven fleet graph that is
allocated, never spent, it stays unlike Vigor (Pillars 5, 4 and 1).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Combat Event Bus & Battle Record, Combat Space, Hulls & Ship Definition`

## Overview

Coherence is the machine side's strength: fleet-wide **bandwidth** supplied by
relay ships and carried to every other machine ship through **visible links**.
A linked ship fires its network-fed guns, refills its ward and fights in
coordination with its fleet. A **cut** ship keeps fighting, but alone: fed guns
silent, ward decaying, no coordination, until it relinks.

The satisfying moment is **the cut** (concept): kill a relay, or strain its
links with severing fire, and a formation comes apart line by line. The player
reads the wiring at a glance (solid, dashed, snapped, relayed) and plans one
exact cut.

Coherence is deliberately unlike Vigor. It is a **fleet graph**, not a per-ship
pool; it lives in *other* ships, not in the ship's own cores; it is
**allocated, never spent**; and it recovers within a battle, with no cost
carried between battles (rule 18). The graph changes only on events, never
every frame, and its maths are integer and deterministic.

## Player Fantasy

**The surgeon.** The player reads the wiring, makes one exact cut, and the
formation comes apart. Five escorts were moving as one; a Lattice Relay dies;
five lines snap with a spark; the escorts' fed lances fall silent and they
scatter to hold station or hunt for a link. The same cut can be made slowly,
too: severing fire turns a line dashed, then snaps it, and keeps it from
relinking.

*Anchor moment:* paused, the player traces the lines back to one relay behind
the Vector Lines. They order the escorts to screen and send the flagship's
Rootcutter at it. Two hits: the lines go dashed. Three: they snap. Unpaused,
the formation breaks.

**Pillars served:**
- **Pillar 5, *Living Against Made*:** a fleet graph against per-ship cores
  (rule 18).
- **Pillar 4, *Plan in the Open*:** the lines are the plan; their states read
  without colour.
- **Pillar 1, *Every Defeat Is a Lead*:** every cut is recorded with its cause
  and actor, so "your links were cut at 3:12 by X" is always nameable.

**This system must never make the player feel:** "the machines were just
another health bar" or "I couldn't tell what the lines meant".

## Detailed Design

### Core Rules

**A. The graph**

1. **Nodes.** Every machine ship in a battle is a node of its fleet's graph.
   A **relay** (`relay_capacity` > 0, Hulls rule 9) is a **provider**: it
   supplies bandwidth and has `link_ports`. A stronghold's **keystone** is an
   ordinary relay hull with `max_speed` 0. Organic ships are never nodes. One
   graph per fleet.
2. **Links (edges).** A ship links to one provider. A relay may itself link to
   another relay; bandwidth then flows from the upstream-most relay (the
   **root**), and a ship linked through a chain of two or more relays is
   **RELAYED**. Chains are at most `MAX_HOPS` (3) relays long.
3. **Assignment** (in P6, only when the graph is **dirty**, rule 12):
   1. every existing link that is still valid is kept (**sticky**), checked in
      ascending target Runtime ID, so lines never jump between unaffected ships;
   2. unlinked ships whose relink timer has expired are then assigned in hop
      passes `h = 1 … MAX_HOPS`: pass 1 offers roots; pass `h` offers relays
      linked in pass `h − 1`; within a pass, ships go in ascending Runtime ID;
   3. a ship's candidates are providers within the provider's `link_range`
      (with hysteresis, rule 9), with a free port and with
      `root_free ≥ coherence_demand`;
   4. it takes the candidate with the smallest (distance², hops, Runtime ID),
      using one port and its demand from the root's capacity;
   5. a relay covers its own `coherence_demand` from its own capacity first.
   Distances are integer squared, after `>> 8` (Combat Space D3). The graph is
   kept in Runtime-ID-indexed arrays, never in dictionary order.
4. **Fleet Coherence** is `C‰ = linked_demand × 1,000 ÷ total_demand` over the
   fleet's live machine ships, with bands **WHOLE** (≥ 750), **FRAYING**
   (400 – 749) and **BROKEN** (< 400); a band drops only after a 50 ‰ margin
   past its threshold. Each change emits `CoherenceBand` (Battle Record). The
   band gates fleet-level doctrine in Ship AI (#20): BROKEN means no fleet
   orders are executed.

**B. Linked and cut**

5. **Authored stats are the linked state.** Being linked grants no bonus; it is
   what lets a ship use everything it has:
   - `network_fed` mounts fire (Hulls rule 10; Weapons & Damage rule 3);
   - the ward refills at `ward_refill` (Weapons & Damage rule 7);
   - coordination: shared targets, focus fire and formation keeping (Ship AI).
6. **A cut ship keeps fighting.** When its link snaps:
   - fed mounts go Silent and any burst in progress is cancelled;
   - unfed mounts fire normally;
   - its ward decays at `WARD_DECAY_PM` (200 ‰ of `ward_points` per second;
     empty in 5 s);
   - it loses coordination and targets the nearest enemy (`query_nearest`, ties
     to the lower ID), so it is predictable;
   - it follows its hull's `cut_behaviour` (rule 7).
   A cut ship is never disabled. Content validation refuses a non-relay machine
   hull with no unfed mount, so every cut ship can still shoot.
7. **Cut behaviours** (the `cut_behaviour` IDs; Ship AI executes them, each must
   look different on screen):
   - `HOLD_STATION`: throttle 0, keeps heading; turn at 700 ‰;
   - `SEEK_RELAY`: steers to the nearest live provider with a free port
     (`fallback_relay_id`, refreshed on every recompute) and relinks on arrival;
     with `fallback_relay_id` NONE it behaves as `HOLD_STATION` until a provider
     is valid;
   - `INDEPENDENT`: keeps its last target, then the nearest; speed 900 ‰,
     turn 800 ‰;
   - `RETURN_TO_LINK_POINT`: steers back to where it was last linked
     (`last_link_pos`).
   Multipliers are published to Combat Space (rule 6a).
8. **What #14 publishes per machine ship** (read by Ship AI in P2, one tick
   stale): state (LINKED / RELAYED / CUT / RELINKING), `cut_tick`,
   `relink_eta_tick` (an exact tick, or NONE) with a **reason** (`TIMER`,
   `STRAINED`, `NO_PROVIDER`, `CAPACITY`), `fallback_relay_id` and
   `last_link_pos`. Only `TIMER` carries an ETA; a strained ship never shows
   one.

**C. Link states**

9. **Every link has a visible state**, emitted as `LinkState` on each change
   (Battle Record rule 9):
   - **SOLID**: healthy;
   - **DASHED**: strain ≥ `DASH_PM` (500 ‰) of the link's hold, **or** distance
     > `DASH_RANGE_PM` (900 ‰) of `link_range`;
   - **SNAPPED**: strain ≥ hold (`cause_code = jammed`), **or** distance >
     `link_range` (the ring the HUD shows; `cause_code = range`), **or** the
     provider is destroyed, retreated or stalled (`relay_lost`), **or** the
     ship's existing link is lost because reassignment found no capacity
     (`capacity`, a new code in the Battle Record). A ship refused before it
     ever linked (for example at battle start) is simply CUT with reason
     `CAPACITY`: no snap event and no spark;
   - **RELAYED**: linked through two or more relays; drawn solid with a mid-line
     node mark.
   A snapped link can form again only within `DASH_RANGE_PM` of range (90 %), so
   a ship at the edge never flickers. No ship changes link state twice within
   `LINK_DWELL` (30 ticks); **`relay_lost`, `jammed` and stall snaps are exempt**,
   so a cut always lands on the tick it happens; dwell gates only range-driven
   changes and SOLID/DASHED toggles.
10. **Strain.** A SEVERING hit (Weapons & Damage rule 6) adds `LinkStrain` to the
    target's link. Strain decays by `STRAIN_DECAY` (2 per tick) after 30 ticks
    with no new strain. When strain reaches the link's hold, the link snaps
    `jammed`, with the actor that crossed the threshold. Strain on an unlinked
    ship still counts: it cannot relink until its strain is below `DASH_PM` of
    its hold, so keeping severing fire on a cut ship keeps it cut.
11. **Stalling a relay.** Strain on a relay fills its stall meter; when full, the
    relay **stalls** for `STALL_TICKS` (300): all its out-links snap `jammed`.
    The relay keeps its own upstream link and keeps fighting. Out-links of a
    snapped relay snap `relay_lost`, with the same actor.

**D. Timing and recompute**

12. **The graph is recomputed only on events**, gathered for the whole tick and
    resolved in **one** recompute in P6: a provider destroyed or retreated, a
    snap, a stall starting or ending, a relink timer expiring, a ship arriving.
    Destruction happens in P7, so a **P7 destruction hook** emits the SNAPPED
    `relay_lost` events on the tick of the kill and marks the graph dirty;
    reassignment happens in P6 of the next tick. All events of a tick are
    emitted in ascending Runtime ID.
13. **Range is checked cheaply.** Each link's length is checked every
    `LINK_CHECK_N` (6) ticks, staggered by `target_id mod LINK_CHECK_N`. With the
    10 % hysteresis band, `LINK_CHECK_N ≤ hysteresis ÷ (2 × fastest ship's
    movement per tick)`, so no crossing is missed (Formulas D5).
14. **Relinking** waits `relink_ticks` (Formulas D3) after a cut; while it runs a
    short dotted stub pulses from the ship's receive point with its ETA; a ship
    held cut for another reason (strain, no provider, capacity) shows a static
    stub with a reason icon on pause-hover instead; on relink the line
    draws in from the provider over 20 ticks, dashed then solid.
15. **Coherence draws no random numbers.** Links, strain, stall meters, timers
    and wards are in `state_hash`.
16. **Budget.** Steady-state P6 work ≤ `COHERENCE_SHARE_MS` (0.3 ms) at the 95th
    percentile on Simulation Tick & Pause's D10 fixture; a full recompute ≤
    1.5 ms on its event tick (within `sim_budget_ms`); no allocation after
    warm-up.

**E. Scope**

17. **No player machine ships at MVP.** Content validation refuses a machine
    hull in the player fleet. Post-MVP (breakaways), player machine ships link
    only to player relays, never to enemy relays; enemy severing can jam them
    like any machine ship. Jamming at MVP is only through SEVERING; there are no
    area jammers.
18. **Not Vigor, and not a mana pool:**
    1. a fleet graph, not a pool per ship;
    2. located in *other* ships (relays), not in the ship's own cores;
    3. never spent: firing consumes nothing; bandwidth is allocated, not drawn;
    4. recovers within the battle (relink), with no cost carried between
       battles; Vigor's ceiling erodes for the expedition;
    5. one cut changes many ships at once; an empty Vigor pool changes one;
    6. the counters are target choice and position (relay kill, severing,
       baiting range); Vigor's counter is rupture on cores.
    7. **strain is not flux**: it never limits the struck ship's own fire, and a
       stall silences the relay's subtree, not the relay itself; the effect
       lands on *other* ships.
    Coherence keeps its own modifier keys (Gameplay Settings & Modifiers rule 13).
19. **A per-battle `CoherenceSummary`** goes into the Battle Record at battle
    end: time spent in each band per fleet, and per relay its subtree size,
    damage taken, and whether it was ever struck, strained or stalled. A defeat
    against a formation that was never cut can then be named ("relay L-01 was
    never targeted").

### States and Transitions

| Ship state | Entered when | Behaviour | Leaves to |
|---|---|---|---|
| Linked | assigned at hop 1 | Full stats | Relayed, Strained, Cut |
| Relayed | assigned at hop ≥ 2 | Full stats; RELAYED line | Linked, Strained, Cut |
| Strained | strain ≥ `DASH_PM` of hold or range > 90 % | DASHED line; full stats | Linked (strain decays / closer), Cut |
| Cut | link snapped | Fed silent, ward decays, `cut_behaviour` | Relinking (timer running) |
| Relinking | after a cut | Dotted stub; exact ETA shown | Linked/Relayed (assigned), Cut (no candidate or strain) |

| Relay state | Entered | Leaves |
|---|---|---|
| Active | default | Stalled (meter full), Destroyed |
| Stalled | stall meter full | Active (after `STALL_TICKS`) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | Tick → #14 | P6 recompute; **P7 destruction hook** (amendment); ascending ID |
| Hulls & Ship Definition (#10) | #10 → #14 | Machine block; link attach points; **validator: non-relay machine hulls need ≥ 1 unfed mount; no machine hulls in the player fleet at MVP** |
| Weapons & Damage (#12) | both | Feed gate; ward refill and decay; `LinkStrain` in; `WardRefilled` with relay |
| Combat Space (#11) | both | Positions; published multipliers (cut behaviours) |
| Combat Event Bus & Battle Record (#9) | #14 → #9 | `LinkState` (adds `cause_code = capacity`), `CoherenceBand` |
| Ship AI (#20) | #14 → #20 | Published state, `cut_behaviour`, band doctrine |
| Machine Nodes & Strongholds (#23) | #23 → #14 | Keystones as immobile relays; stronghold layouts |
| Gameplay Settings & Modifiers (#7) | #7 → #14 | Its own keys only (never shared with Vigor) |
| Combat HUD (#46), art | #14 → them | Line states, stubs, ETAs |

## Formulas

### D1. Link hold and relay stall meter

`hold = 200 + 40 × coherence_demand` (240 – 1,000); `stall_meter = 600 + 10 × relay_capacity` (600 – 1,200).

### D2. Fleet Coherence

`C‰ = linked_demand × 1,000 ÷ total_demand` (0 – 1,000; no band if total is 0).

### D3. Relink delay

`relink_ticks = RELINK_BASE + RELINK_PER_DEMAND × coherence_demand` = 120 + 12 × demand (132 – 360 ticks, 2.2 – 6 s at 60 Hz).

### D4. Ward decay

`decay_s = ceil(ward_points × WARD_DECAY_PM ÷ 1,000)` per second; per tick
`(decay_s × (k + 1)) div 60 − (decay_s × k) div 60`, k = ticks since the cut
mod 60, so every decrement is an integer and the per-second total is exact.

### D5. Range-check cadence

`LINK_CHECK_N ≤ (link_range × (1,000 − DASH_RANGE_PM) ÷ 1,000) ÷ (2 × v_max_u_per_tick)`.
**Example:** `link_range` 1,200, hysteresis 120 u, fastest ship 400 u/s = 6.67
u/tick: N ≤ 120 ÷ 13.3 = 9; the default 6 is safe. Content validation checks the
smallest `link_range` against the fastest hull.

### D6. Worked example: the cut

A Lattice Relay L-01 (capacity 30, own demand 4, 5 ports, range 1,200 u) links
five escorts with demands 4, 5, 5, 6, 6 (26, exactly the 26 left). Before:
C‰ = 30 × 1,000 ÷ 30 = **1,000, WHOLE**; five SOLID lines.
- **Kill:** L-01 dies at tick T in P7: five `LinkState(SOLID → SNAPPED,
  relay_lost, killer)` at T. Linked demand 0 of 26 (L-01 is gone): C‰ = **0,
  BROKEN**, one `CoherenceBand(WHOLE → BROKEN)`. The demand-5 escort's relink
  timer is 180 ticks, but with no provider left it stays cut; its 800-point
  ward loses 160 per second and is empty after 300 ticks.
- **Severing alternative:** a Rootcutter hit of 300 × `sever_permille` 600 =
  180 strain against a hold of 200 + 40 × 5 = 400: hit 2 (360 ≥ 200, i.e. ≥
  500 ‰ of hold) turns the line DASHED; hit 3 (540 ≥ 400) SNAPS it `jammed`.

## Edge Cases

- **If two providers tie on distance**: fewer hops wins, then the lower ID.
- **If relays would form a loop**: impossible; each pass offers only relays
  linked in earlier passes.
- **If a fleet has no machine ships**: no band, no event.
- **If a relay's capacity is below its own demand**: it has no free capacity but
  stays self-supplied.
- **If strain lands on the tick its target is destroyed**: discarded.
- **If a relay retreats**: its links snap `relay_lost` with actor NONE.
- **If three relays die on one tick**: one recompute; the result and events are
  identical whatever order they were removed in.
- **If a ship moves out of range during its relink delay**: it finds no
  candidate and stays cut.
- **If several severing sources hit one link**: the actor is the one whose hit
  crossed the threshold.
- **If a ship hovers at the edge of range**: hysteresis and `LINK_DWELL` allow
  at most one change per dwell.
- **If a keystone is destroyed**: it is an ordinary relay loss; the stronghold's
  own consequences belong to Machine Nodes & Strongholds (the node breaks,
  rules 16–17).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | P6, P7 hook |
| Hulls & Ship Definition (#10) | Hard | Machine block, validator rules |
| Weapons & Damage (#12) | Hard (both) | Feed, wards, strain |
| Combat Space (#11) | Hard | Positions, multipliers |
| Combat Event Bus & Battle Record (#9) | Hard | Events |
| Ship AI (#20), Machine Nodes & Strongholds (#23), HUD (#46) | Hard (reverse) | Published state, keystones, display |
| After-Action Debrief, Dossier | Hard (reverse) | `CoherenceSummary` and link events for causes and relay intel |

Bidirectional check: Hulls, Weapons, Combat Space and Battle Record already name
Coherence & Links.

## Tuning Knobs

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `MAX_HOPS` | 3 | 2 – 4 | Relay chain depth |
| Band thresholds | 750 / 400, margin 50 | ±100 | Doctrine gates |
| `DASH_PM` | 500 | 300 – 700 | When strain shows |
| `DASH_RANGE_PM` | 900 | 850 – 950 | Range warning and hysteresis |
| Hold formula | 200 + 40 × demand | ±50 % | How hard links are to sever |
| Stall meter | 600 + 10 × capacity | ±50 % | How hard relays are to stall |
| `STALL_TICKS` | 300 | 180 – 600 | Stall length |
| `STRAIN_DECAY` | 2 per tick after 30 | 1 – 5 | Strain recovery |
| Relink delay | 120 + 12 × demand | ±50 % | Recovery after a cut |
| `WARD_DECAY_PM` | 200 /s | 100 – 500 | How fast a cut ward fails |
| Cut multipliers | 700 / 900 / 800 | 500 – 1,000 | Cut behaviours |
| `LINK_CHECK_N` | 6 | 3 – 15 (D5) | Range-check cost |
| `LINK_DWELL` | 30 ticks | 15 – 60 | Flicker guard |
| `COHERENCE_SHARE_MS` | 0.3 | 0.2 – 0.5 | Budget |

All in `assets/data/coherence/`.

## Visual/Audio Requirements

- **Line patterns read without colour** (concept): SOLID, DASHED, SNAPPED (with a
  spark), RELAYED (solid with a mid-line node). At 32 px in greyscale, testers
  name them in ≥ 90 % of cases (Hulls R3).
- Snaps spark and make a short, distinct sound; a stall shows on the relay.
- Relinking: a pulsing dotted stub, then the line drawing in.
- Each cut behaviour looks different (hold, seek, independent, return).
- Link and relay visuals carry no organic-race lineage (concept; Hulls rule 14).

## Game Feel

- **The cut lands at once**: lines snap on the tick of the kill.
- **Recovery is visible and timed**: the relink ETA is exact and shown.

## UI Requirements

- Paused: link lines with state; hovering a relay highlights its whole subtree
  and shows capacity used and ports; a cut ship shows its relink ETA (TIMER) or
  its reason (STRAINED, NO_PROVIDER, CAPACITY).
- **Strain without a bar**: hovering a link while paused shows "hits to dash /
  hits to snap" for the selected weapon (computed, no draw).
- Fleet Coherence band per machine fleet on the HUD.
- 📌 **UX Flag — Coherence & Links**: include line states, relay subtree
  highlight and ETAs in the Combat HUD UX spec before epics.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Phases P6/P7 | `design/gdd/simulation-tick-and-pause.md` | Phase table (P7 hook added) | Rule dependency |
| Machine block, validator | `design/gdd/hulls-and-ship-definition.md` | Rules 6, 9–11, 15 (validator amended) | Data dependency |
| Feed, ward, strain | `design/gdd/weapons-and-damage.md` | Rules 3, 6, 7, 13 | Rule dependency |
| Multipliers, positions | `design/gdd/combat-space.md` | Rules 6a, 15; D3 | Rule dependency |
| `LinkState`, `CoherenceBand` | `design/gdd/combat-event-bus-and-battle-record.md` | Rules 9, 14 (`capacity` cause added) | Data dependency |
| Own modifier keys | `design/gdd/gameplay-settings-and-modifiers.md` | Rule 13 | Rule dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 3)**: over 1,000 seeded layouts, assignment is identical across 3 runs and across shuffled input orders, and every link meets range, port and capacity limits.
- **AC-02 (Logic; rule 3)**: a ship with two providers at equal distance takes the one with fewer hops, then the lower ID.
- **AC-03 (Logic; rule 3)**: destroying relay A changes no link of a ship that was not on A (sticky links).
- **AC-04 (Logic; rule 12, D6)**: a kill at tick 11,520 records five `SNAPPED relay_lost` events at 11,520 and the reassignment at 11,521; C‰ goes 1,000 → 0 with one `CoherenceBand(WHOLE → BROKEN)`.
- **AC-05 (Logic; rules 9–10, D6)**: three hits of 180 strain on a hold of 400 give DASHED on hit 2 and SNAPPED `jammed` on hit 3 with the right actor; strain decays 2 per tick only after 30 clear ticks; a ship with strain ≥ 500 ‰ of its hold never relinks.
- **AC-06 (Logic; D3, rule 8)**: relink happens at exactly `120 + 12 × demand` ticks after the cut when a candidate exists, and the published `relink_eta_tick` equals that tick.
- **AC-07 (Logic; D4)**: an 800-point ward reaches 0 exactly 300 ticks after a cut, with every per-tick decrement an integer.
- **AC-08 (Logic; rule 6)**: a cut ship's fed mounts fire 0 shots and its unfed mounts fire normally; content validation refuses a non-relay machine hull with no unfed mount.
- **AC-09 (Logic; rule 7)**: each `cut_behaviour` publishes its stated multipliers and movement intent.
- **AC-10 (Logic; rule 11)**: a stalled relay snaps all its out-links for `STALL_TICKS` and keeps its own fed mounts working.
- **AC-11 (Logic; rule 2)**: no chain exceeds `MAX_HOPS`; links through two or more relays are RELAYED; a chain of `MAX_HOPS + 1` relays leaves the last relay and its ships cut.
- **AC-12 (Logic; rule 9)**: a ship oscillating across `link_range` with amplitude under the hysteresis band for 600 ticks changes state at most once; over 3,600 D10 ticks there are 0 `LINK_DWELL` violations.
- **AC-13 (Logic; rule 13)**: a range break is detected within `LINK_CHECK_N` ticks of crossing `link_range`.
- **AC-14 (Logic; rule 12)**: three relays destroyed on one tick cause exactly one recompute, and `state_hash` is identical across all six removal orders.
- **AC-15 (Logic; rule 12)**: a topology recompute runs only on ticks with a dirty event (call log).
- **AC-16 (Logic; rule 17)**: content validation refuses a machine hull in the player fleet at MVP.
- **AC-17 (Performance; rule 16)**: steady P6 Coherence work ≤ 0.3 ms at the 95th percentile on the D10 fixture; a full recompute ≤ 1.5 ms; allocation delta 0 over 3,600 ticks.
- **AC-18 (Visual)**: at 32 px in greyscale, testers name SOLID, DASHED, SNAPPED and RELAYED in ≥ 90 % of cases.
- **AC-20 (Logic; rule 9)**: a ship that relinked 10 ticks before its relay dies snaps `relay_lost` on the kill tick (dwell exemption).
- **AC-21 (Logic; rule 7)**: `SEEK_RELAY` with no provider left behaves as `HOLD_STATION` until one becomes valid.
- **AC-22 (Logic; rule 8)**: a cut ship held by strain publishes reason `STRAINED` and no ETA; a ship refused at battle start is CUT with reason `CAPACITY` and emits no `SNAPPED`.
- **AC-23 (Logic; rule 19)**: after a battle in which relay L-01 was never struck, `CoherenceSummary` records it with 0 damage and the Debrief can name "relay never targeted".
- **AC-24 (UI)**: hovering a link while paused shows hits-to-dash and hits-to-snap for the selected weapon, matching D1 and the weapon's strain per hit.
- **AC-19 (Playtest; prototype caveat)**: 5 players with no genre briefing, where the relay is not the largest silhouette: in at least 3 of 5, the first deliberate target by the second skirmish is the relay, and at least 3 of 5 say in interview that the **lines** told them, not that "it looked like a commander".

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Budget**: with Combat Space 1.2, RNG 0.6, Weapons 1.2 and Coherence 0.3 ms, about 0.7 ms of `L` is left for Ship AI, Vigor and the record. | technical-director, performance-analyst | Tick/determinism ADR spike |
| 2 | **P7 destruction hook** (rule 12) must be added to Simulation Tick & Pause's phase table. | Tick owner | Tick re-review |
| 3 | **Link priority by role** (fed-heavy ships first) instead of plain ID. | game-designer | Balance pass |
| 4 | **Player machine ships and breakaways** (rule 17). | game-designer | Post-MVP |
| 5 | **Area jammers** as a weapon or module. | game-designer | Post-MVP |
| 6 | **All numbers** are starting values; no balance data yet. | systems-designer | When `assets/data/coherence/` exists |
| 7 | **If AC-19 fails** (the lines don't teach relay-first): options are a relay-subtree trace on first sighting, Dossier pre-tagging of known relays, or a stronger line-convergence treatment. | creative-director, ux-designer | Vertical-slice playtest |
