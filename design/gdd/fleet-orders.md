# Fleet Orders

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 3 (Hands on the Helm — the fleet is commanded, not puppeted); Pillar 4 (Plan in the Open — orders are visible, editable and queued in the open)

## Summary

Fleet Orders is the player's command vocabulary for every ship but the
flagship: Move, Attack, Escort, Hold, Regroup, Focus Fire, Retreat and Cancel,
each with defined subjects, targets, completion and rejection reasons. Orders
pass through the tick's order queue, visible and editable until they apply, and
become goals that Ship AI executes but may never change in kind. Each ship holds
a goal with queued waypoints and a separate focus target (Pillars 3 and 4).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Input & Controls, Combat Space, Runtime ID Service`

## Overview

Fleet Orders is the vocabulary the player uses to command every ship except
the flagship: Move, Attack, Escort, Hold Position, Regroup, Focus Fire,
Retreat and Cancel. It defines what each order means: who can receive it, what
it targets, when it is done, and why it can be refused. It turns an applied
order into a **goal** that Ship AI (#20) executes, and holds queued waypoints.

Orders cross into the simulation only through Simulation Tick & Pause's order
queue (rule 5): stamped for a tick, visible and editable until then, applied in
P1, recorded. An order is a **goal, not a puppet string**: Ship AI decides *how*
(path, range, facing, dodging); Fleet Orders decides *what*, and the AI may never
change what. That is how Pillar 3's "fleet commanded, not puppeted" holds.

Each ship has two slots: a **Goal slot** (where to be and what to do, with up to
`MAX_WAYPOINTS` queued after it) and a **Focus slot** (which target to prefer),
so "move there, and focus that relay" is one plan.

## Player Fantasy

**The admiral's word, laid out on the table.** The player says what; their
captains decide how. Orders are few, and they hold. Paused, the battlefield is a
map: every order is a visible line, and resuming is watching the plan play out.

*Anchor moment:* paused, the player drags a box around three frigates, right-
clicks the flank, Shift-right-clicks behind the relay, and Alt-right-clicks the
relay itself. Lines and markers appear. They unpause; the frigates swing wide,
and every gun in the fleet turns on the relay.

**Pillars served:**
- **Pillar 3:** the fleet is commanded through goals; the AI never overrides
  what was ordered (rule 6).
- **Pillar 4:** every order is visible and editable before it applies.

**This system must never make the player feel:** "my ships did their own
thing" or "I had to micromanage every shot".

## Detailed Design

### Core Rules

**A. The orders**

1. **The MVP order set:**

   | Order | Subjects | Target | Done when | Persistence | Rejections |
   |---|---|---|---|---|---|
   | **Move** | ship, selection | point (clamped to `FIELD_R − EDGE_W`) | within `ARRIVE_R` and speed ≤ `SETTLE_PM` (D1) | one-shot; then the ship **anchors** there as Hold | `flagship_not_covered` |
   | **Attack** | ship, selection | enemy ship | target destroyed or retreated | standing until done | `target_lost`, `target_invalid` |
   | **Escort** | ship, selection | ally, not self | never (ends on replace or `target_lost`) | standing | `target_invalid`, `target_lost` |
   | **Hold Position** | ship, selection | point (default: current) | never | standing | `flagship_not_covered` |
   | **Regroup** | selection, fleet | the flagship | all subjects in slot (D3), then Escort(flagship) | one-shot, then standing | `no_flagship` |
   | **Focus Fire** | whole fleet (flagship's AUTO group included) | enemy ship | target destroyed or retreated | standing, Focus slot only | `target_lost`, `target_invalid` |
   | **Retreat** | ship, selection, flagship | own retreat zone | reported to Battle Resolution | standing, cancellable until reported | `subject_retreated` |
   | **Cancel** | selection | — | immediate | queue edit | — |

   **Cancel** removes the selection's pending commands and, for ships with an
   active goal, enqueues a CLEAR: the Goal slot and waypoints empty and the ship
   returns to AI doctrine (Ship AI, Fleet Coordination).
2. **The flagship** takes only Focus Fire, Attack (which sets only its AUTO
   group's focus) and Retreat (Flagship Piloting rule 12). Move, Hold, Escort
   and Regroup addressed to it are rejected `flagship_not_covered`; in a mixed
   selection, the rest of the selection still receives the order.
3. **Live hotkeys F1 – F5** (Input & Controls rule 3): F1 Attack (the locked
   target, else the enemy nearest the cursor); F2 Move (to the cursor); F3 Hold;
   F4 Regroup; F5 Focus Fire (the locked target). **Retreat is never on a single
   key**: it is reached through the order menu (R), or Shift+RMB on the player's
   own retreat zone.
4. **Right-click in the Command context**: empty space → Move; enemy → Attack;
   ally → Escort; own flagship → Regroup; the subject itself → Hold here.
   Alt+RMB on an enemy → Focus Fire (single-input alternative: the order menu,
   Input & Controls rule 9).
5. **Queue.** Shift+RMB appends a waypoint. A non-queued order replaces the
   active goal and clears its waypoints. At most `MAX_WAYPOINTS` (8); one more is
   rejected `queue_full`. Appending after a standing goal (Hold, Escort,
   Retreat) is rejected `queue_after_standing`; Attack completes, so it may sit
   mid-queue. A new Focus Fire always replaces the old one. Same-tick
   conflicts resolve by enqueue sequence, last wins (Simulation Tick & Pause).

**B. Goals, not strings**

6. **An order is a goal.** Ship AI owns *how*; Fleet Orders owns *what*.
   - **The AI may**: choose path, throttle, facing and range band; choose its
     ember-fire policy (Vigor); dodge; shoot targets of opportunity within the
     goal's leash.
   - **The AI may not**: change the goal's kind, leave its leash, ignore an
     in-range Focus target, or retreat.
   An Attack on a target out of range closes distance; a ship at EMPTY Vigor
   keeps attacking, possibly standing off at maximum range.
7. **Player ships never retreat on their own** at MVP (Combat Space rule 12:
   retreat needs explicit intent). The decision stays the player's; the "hull
   critical" auto-pause (Simulation Tick & Pause) gives them time to make it.
8. **Selection groups** 5 – 9 store Runtime IDs (presentation state, not in
   `state_hash`); dead ships are pruned on recall.

**C. Life cycle**

9. **Orders while paused** go through the queue stamped for the next tick, with
   a visible marker; editable or cancellable until that tick, after which an
   edit is a new order.
10. **When things change:**
    - target dies → Attack and Focus end `target_destroyed`; the next waypoint,
      or doctrine, takes over the same tick; Escort ends `target_lost` and the
      ship anchors where it is;
    - an enemy machine ship is cut → its goal is SUSPENDED and its
      `cut_behaviour` governs; on relink the goal resumes if still valid; with
      its fleet's band BROKEN, every machine goal is suspended (Coherence &
      Links rules 4–8);
    - battle ends → pending commands are `cancelled_by_context_end` (Simulation
      Tick & Pause) and every slot is cleared; nothing carries over.
11. **Enemy goals** are written by Fleet Coordination (#21) directly into the same
    slot structure; they never pass through the player's order queue.
12. **Events**: `OrderApplied` (P1); `OrderRejected` with the reasons above
    (adding `queue_full`, `queue_after_standing`, `flagship_not_covered`,
    `no_flagship`); and a new record-tier `OrderEnded(order_id, subject,
    outcome: done | target_destroyed | target_retreated | target_lost |
    replaced | cleared)` (Battle Record rule 9; raises `EVENT_SCHEMA_VERSION`).

### States and Transitions

| Order state | Entered when | Leaves to |
|---|---|---|
| Pending | enqueued (editable) | Active (applied in P1), Cancelled |
| Waiting | queued as a waypoint | Active (previous goal ends) |
| Active | applied | Ended (outcome), Suspended (enemy only) |
| Suspended | enemy ship cut or band BROKEN | Active (relinked, still valid), Ended |
| Ended | done, target lost, replaced, cleared | — |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | both | Order queue, apply-tick stamp, `OrderRejected`, `cancelled_by_context_end` |
| Input & Controls (#6) | #6 → #19 | Gestures, F1–F5 (named here; Input Open Question 5 resolved), order menu, selection groups |
| Flagship Piloting (#15) | both | The flagship's covered orders (rule 2) |
| Combat Space (#11) | #19 → #11 | Point clamping; retreat intent; queries for Escort and Regroup slots |
| Coherence & Links (#14) | #14 → #19 | Cut and BROKEN suspend enemy goals |
| Ship AI (#20), Fleet Coordination (#21) | #19 → them | Goal and Focus slots read in P2; the may / may-not list (rule 6) |
| Combat Event Bus & Battle Record (#9) | #19 → #9 | `OrderApplied`, `OrderRejected`, `OrderEnded` |
| Combat HUD (#46) | #19 → #46 | Order lines, slot ghosts, end-of-order flashes |
| Opening skirmish | — | Teaches Focus Fire (concept: "one fleet order") |

## Formulas

### D1. Arrival

`ARRIVE_R = max(ARRIVE_MIN, 2 × world_radius)`, and `|vel| ≤ SETTLE_PM ‰ × v_cap`.
**Example:** radius 30 → `ARRIVE_R` 60 u (`ARRIVE_MIN` 40).

### D2. Escort screen

`R = r_ward + r_self + SCREEN_GAP`; escort i of n (ascending Runtime ID) sits at
bearing `threat_bearing + (i − (n − 1) ÷ 2) × SCREEN_SPREAD`, where
`threat_bearing` points at `query_nearest(enemy)` (else the ward's heading).
**Example:** ward 60, self 30, gap 80 → R = 170; three escorts at −30°, 0°, +30°
off the threat bearing.

### D3. Regroup chevron

Slot k (k = 1 … n, ascending Runtime ID): `rank = (k + 1) div 2`, `side = +1` if
k is odd else −1; local offset `(−rank × ROW_SP, side × rank × COL_SP)`.
**Example** (120, 100): k = 1 → (−120, +100); k = 2 → (−120, −100); k = 3 →
(−240, +200).

### D4. Hold leash

The ship engages only within `HOLD_LEASH` (400 u) of its anchor and returns when
beyond it.

## Edge Cases

- **If a Move point is outside the field**: it is clamped and accepted.
- **If an escorted ward retreats**: Escort ends `target_retreated`; the ship
  anchors.
- **If Regroup is ordered with the flagship dead**: `no_flagship`; an active
  Regroup becomes Hold at each ship's position.
- **If two ships escort each other**: allowed; both screen the nearest threat.
- **If a Focus target is outside every ship's range**: goals continue; the focus
  waits.
- **If Attack targets an ally**: `target_invalid`.
- **If the selection is empty**: no order; a UI cue.
- **If Retreat is active when the battle ends**: context-end handling applies.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | Queue |
| Input & Controls (#6) | Hard | Gestures |
| Combat Space (#11) | Hard | Clamp, queries, retreat |
| Runtime ID Service (#3) | Hard | Subjects and targets by ID |
| Flagship Piloting (#15), Coherence & Links (#14) | Soft | Covered set; suspension |
| Ship AI (#20), Fleet Coordination (#21), HUD (#46), #9 | Hard (reverse) | Slots, events, display |

Bidirectional check: Tick, Input, Flagship Piloting and Combat Space name Fleet
Orders.

## Tuning Knobs

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `MAX_WAYPOINTS` | 8 | 4 – 12 | Queue length |
| `ARRIVE_MIN` | 40 u | 20 – 80 | Move completion |
| `SETTLE_PM` | 100 ‰ | 50 – 300 | Arrival speed |
| `SCREEN_GAP` | 80 u | 40 – 160 | Escort spacing |
| `SCREEN_SPREAD` | 30° | 15 – 45° | Escort spread |
| `ESCORT_LEASH` | 600 u | 300 – 1,200 | Escort chase range |
| `ROW_SP`, `COL_SP` | 120, 100 u | 60 – 240 | Regroup formation |
| `HOLD_LEASH` | 400 u | 200 – 800 | Hold engagement range |

All in `assets/data/orders/`.

## Visual/Audio Requirements

- Order lines and markers by type, distinguished by shape and pattern, not
  colour alone; queued waypoints numbered.
- A short flash when an order ends; a distinct cue on rejection with its reason.

## Game Feel

- **Few orders, held firmly**: an order keeps working without re-issuing.
- **Pausing to plan feels natural**: orders given paused apply on the first
  resumed tick.

## UI Requirements

- Command context: order lines, queue numbers, escort and regroup slot ghosts,
  focus marker.
- Order menu (R): every order, keyboard-navigable.
- Rejection messages name the reason.
- 📌 **UX Flag — Fleet Orders**: include order visuals and the order menu in the
  Combat HUD UX spec before epics.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Order queue, stamping, rejections | `design/gdd/simulation-tick-and-pause.md` | Rule 5; Orders and input edge cases | Rule dependency |
| Gestures, hotkeys | `design/gdd/input-and-controls.md` | Rules 3, 9, 13–15; Open Question 5 (resolved here) | Rule dependency |
| Flagship's covered orders | `design/gdd/flagship-piloting.md` | Rule 12 | Rule dependency |
| Retreat intent, clamp, queries | `design/gdd/combat-space.md` | Rules 10, 12, 15 | Rule dependency |
| Suspension of machine goals | `design/gdd/coherence-and-links.md` | Rules 4–8 | Rule dependency |
| Order events | `design/gdd/combat-event-bus-and-battle-record.md` | Rule 9 (`OrderEnded` added) | Data dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 4)**: RMB on empty space, an enemy, an ally, the own flagship and the subject itself yields Move, Attack, Escort, Regroup and Hold.
- **AC-02 (Logic; rule 5)**: a non-queued order clears waypoints; Shift+RMB appends; the 9th waypoint is rejected `queue_full`; appending after Hold is rejected `queue_after_standing`.
- **AC-03 (Logic; D1)**: Move ends `done` exactly when D1 is met (radius 30, 60 u), and the ship then anchors as Hold.
- **AC-04 (Logic; D2, D3)**: three escorts take the D2 slots; Regroup slots match D3 for k = 1 … 5 regardless of insertion order.
- **AC-05 (Logic; rule 10)**: Attack on a destroyed target ends `target_destroyed`, and the next waypoint is active the same tick.
- **AC-06 (Logic; rule 2)**: Move to the flagship is rejected `flagship_not_covered`; Attack and Focus to the flagship set its AUTO focus; in a mixed selection the other ships receive the order.
- **AC-07 (Logic; rules 6–7)**: a ship at EMPTY Vigor under Attack never changes its goal and never retreats without a Retreat order.
- **AC-08 (Logic; rule 10)**: a cut enemy goal is SUSPENDED and resumes on relink if still valid; with its band BROKEN, no machine goal executes.
- **AC-09 (Logic; rule 10)**: at context end, pending commands are logged `cancelled_by_context_end` and every slot is empty.
- **AC-10 (Logic; determinism)**: a replay of the same commands reproduces identical `OrderApplied` and `OrderEnded` sequences and `state_hash`.
- **AC-11 (Logic; rule 3)**: F1 – F5 issue Attack, Move, Hold, Regroup and Focus Fire in Combat-live without the command cursor; no single key issues Retreat.
- **AC-12 (Logic; Input rule 9)**: with the keyboard only (Tab, R, arrows, Enter), every order can be issued.
- **AC-13 (Logic; rule 12)**: every ended order emits exactly one `OrderEnded` with the right outcome.
- **AC-14 (Playtest)**: in the opening skirmish, at least 4 of 5 first-time testers use Focus Fire a second time unprompted and in the right context, and can say afterwards what it made the fleet do.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Ship AI and Fleet Coordination must accept** the may / may-not list (rule 6). | #20, #21 | When designed |
| 2 | **Formations beyond Regroup's chevron** (line abreast, wedge) — post-MVP. | game-designer | Post-MVP |
| 3 | **Auto-retreat thresholds for player ships** — not at MVP (rule 7). | game-designer | Playtest |
