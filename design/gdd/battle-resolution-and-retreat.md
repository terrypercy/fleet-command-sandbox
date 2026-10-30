# Battle Resolution & Retreat

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (salvage loss scaled by share left behind, STANDOFF costed as retreat, fantasy banner fix, Pyrrhic banner, Vigor-floor retreat, lent-ship OQ)
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — a defeat ends with a bounded cost and a named cause, never the run); Pillar 3 (Hands on the Helm — retreat is the player's call and always available); Pillar 4 (Plan in the Open — end conditions are stated before battle)

## Summary

Battle Resolution & Retreat decides how a battle ends and what it ended as: VICTORY, ENEMY_WITHDREW, PLAYER_RETREATED, DEFEAT or STANDOFF. Each tick in P7 it settles ships at zero hull (enemies destroyed, player ships disabled, never lost) and ships that left through a retreat zone, then ends the battle when a side has no ship on the field or the time limit is reached. It hands one fact-only Battle Outcome report to the cost systems and never charges anything itself.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Combat Event Bus & Battle Record, Weapons & Damage, Fleet Orders, Runtime ID Service`

## Overview

Battle Resolution & Retreat decides **how a battle ends and what it ended as**.
Each tick in P7 it settles the ships that reached zero hull and the ships that
left through a retreat zone. Then it checks whether either side has a ship left
on the field. When a side has none, or the time limit is reached, it ends the
battle. It names one outcome: **VICTORY**, **ENEMY_WITHDREW**,
**PLAYER_RETREATED**, **DEFEAT** or **STANDOFF**. It gives every deployed ship an
end state, and it hands one **Battle Outcome report** to the systems that apply
costs and rewards.

It **never charges anything**. Credits, Vigor, World Clock, Hulls and Salvage
read the report and apply their own rules. That keeps the cost of one defeat
bounded where those systems cap it (Pillar 1). Player ships at zero hull are
**disabled, not destroyed**, so a defeat costs recovery, time and Vigor, and
never the fleet. Retreat is always the player's call. It is never automatic,
never on a single key, and always available while a ship can still move
(Pillar 3). The end conditions are fixed and shown before the battle (Pillar 4).

## Player Fantasy

**I chose when to leave, and I know why I lost.** The fight turns. The player
pauses, reads the field and orders the line ships home. They fly the flagship
into the retreat arc while the escorts cover it. Three ships make it out. One
is left drifting, disabled, and it will be recovered at a price the pre-battle
panel already quoted. The Debrief opens on the frame the last ship leaves, and
it names the cause.

*Anchor moment:* the authored opening stronghold. The player's fleet is
outmatched. They retreat, and the banner reads "Withdrawn", or they are
disabled to the last ship, and it reads "Fleet disabled". Neither says "Game
Over". The Debrief opens, and nothing is lost: no days,
no salvage, no Vigor ceiling (`opening_loss`).

**Pillars served:**
- **Pillar 1:** every loss ends in a bounded, reported cost and a Debrief. A
  disabled ship is recovered, never erased.
- **Pillar 4:** the end conditions, the time limit and the retreat zone are
  shown before the first tick.
- **Pillar 3:** retreat is the player's decision and the flagship flies itself
  out. When the flagship is gone, the fleet fights on under orders.
- **Pillar 5:** a machine fleet that breaks withdraws, but its cut ships cannot.
  They stay and fight alone, so cutting the links decides who gets away.

**This system must never make the player feel:** "the game ended my run",
"my ship retreated on its own", "the battle ended for a reason I wasn't told",
or "I was punished for pausing".

## Detailed Design

### Core Rules

**A. Outcomes and end conditions**

1. **Five outcomes.** Each battle ends with exactly one:
   - **VICTORY**: no enemy ship is left on the field, and none withdrew.
   - **ENEMY_WITHDREW**: no enemy ship is left on the field, and at least one
     enemy ship departed through its retreat zone.
   - **PLAYER_RETREATED**: no player ship is left on the field, and at least one
     player ship departed through its retreat zone.
   - **DEFEAT**: no player ship is left on the field, and none departed. Every
     player ship is disabled.
   - **STANDOFF**: the time limit is reached with ships still on both sides
     (rule 5).

   VICTORY and ENEMY_WITHDREW are the **win class**: the player holds the field.
   PLAYER_RETREATED, DEFEAT and STANDOFF are the **loss class**. The win class
   is the "won battle" in Credits rule 2.
2. **Presence.** A ship is **present** when its Runtime ID status is `LIVE`
   and its Combat Space state is Active or Retreating, and it is not disabled.
   Disabled, destroyed, departed and `INERT` ships are absent. `P` and `E`
   count present player-side and enemy-side ships (Formulas D1). Lent ships
   (Allied Lending #33) count on the player side; what a lent ship left behind
   costs is Open Question 7.
3. **The end check** runs once per tick in P7, after destruction and retreat
   processing and before auto-pause trigger evaluation (Simulation Tick & Pause
   rule 3; its Auto-pause edge case). The battle ends on this tick when
   `E = 0`, or `P = 0`, or the time limit is reached. Otherwise the battle
   continues.
4. **Deciding the outcome** (Formulas D2), first match wins:
   - `E = 0` (whatever `P` is): the win class. ENEMY_WITHDREW if any enemy ship
     departed this battle, else VICTORY. When `E` and `P` reach 0 on the same
     tick, this match wins, so a mutual end goes to the player.
   - `P = 0`: PLAYER_RETREATED if any player ship departed this battle, else
     DEFEAT.
   - Time limit reached: STANDOFF.
   Elimination is always checked before the time limit.
5. **The time limit.** The battle ends as STANDOFF when `sim_s`, the battle's
   elapsed simulated seconds (`(tick − battle_start_tick) div TICK_RATE`; held
   time never counts, because no tick runs), reaches `BATTLE_LIMIT_S` (1,800,
   30 minutes of unpaused play). A **standoff warning** is emitted once, when
   `sim_s` first reaches `BATTLE_LIMIT_S − STANDOFF_WARN_S` (120). This is not
   World Clock's `BATTLE_MAX_S`: that caps the game time a battle costs (about
   6 unpaused minutes) and never ends a battle. At STANDOFF, player ships still present count as retreated in good
   order; enemy ships still present stay where their fleet is. The limit exists
   so that a stronghold that never withdraws and a player who never closes
   cannot run a battle forever. STANDOFF is costed as a PLAYER_RETREATED, with
   `retreated_pm` from D4, and the Debrief names the stalemate's cause (the
   enemy's `withdraw_sr` 0 and the damage-share gap). Whether kiting to the
   limit costs less than an ordered retreat is tested by the AI-vs-AI Runner
   (Open Question 5); if it does, STANDOFF is cut.
6. **Flagship loss does not end the battle.** When the flagship is disabled
   or departs, the fleet fights on under Fleet Orders. The player keeps pause,
   step, the order menu and Retreat. Flagship Piloting enters No flagship. The
   battle ends only by rule 3. Reason: rule 2 never makes a ship special, so the
   end conditions stay one sentence long (Pillar 4). Ending at once would also
   abandon escorts that are already retreating.

**B. What happens to each ship**

7. **Zero hull.** Weapons & Damage sets hull to 0 in P5. In P7 this system
   settles each such ship in ascending Runtime ID:
   - **An enemy ship is DESTROYED.** Its DP joins `destroyed_DP` (D3), and its
     ID is queued for retirement at the retire point (Runtime ID Service rule 6).
   - **A player ship is DISABLED.** It stays `LIVE` with its ID. It leaves the
     Combat Space grid, its orders end, and it takes no further part in the
     battle. It is never retired at MVP. Destroying a player ship for good is
     reserved for the optional permadeath mode (concept anti-pillars).
   - Disabling any player ship other than the flagship raises the
     **escort-lost** signal on that tick (Simulation Tick & Pause rule 11).
8. **Retreat.** Combat Space reports every ship whose retreat intent held it
   in its own zone for `RETREAT_HOLD` ticks, or that reached `FIELD_R` there
   (Combat Space rule 12). In P7 this system marks each reported ship
   **RETREATED** in ascending Runtime ID, emits `Retreated` (`cause_code`
   `ordered` for a Retreat order or flagship input, `rout` for a doctrine
   WITHDRAW; `auto` is unused at MVP), and makes Fleet
   Orders end the ship's order with `subject_retreated`. A retreated ship keeps
   its ID and stays `LIVE` (Runtime ID Service: retreat is not retirement). The
   Hulls state becomes Retreated. This system owns no zone, timer or intent.
   Those belong to Combat Space, Fleet Orders and Flagship Piloting.
9. **No pursuit at MVP.** A departed ship is safe. There is no pursuit roll
   and no post-battle chase. The risk of retreating is the `RETREAT_HOLD`
   ticks spent in the zone: a Retreating ship is still on the grid, so it can
   still be shot and disabled. A ship at its Vigor floor can always reach its
   retreat zone and complete `RETREAT_HOLD` (Vigor's no-lockout rule: at FLOOR
   a ship still moves at 850 ‰).
10. **Enemy withdrawal.** A roaming machine fleet in WITHDRAW (Fleet
    Coordination rule 5, `withdraw_sr` 250) carries retreat intent through its
    Goal slots. Its linked ships depart by rule 8 like any ship. Cut ships, and
    every ship of a BROKEN fleet, receive no goal and cannot withdraw. They
    fight on until they are destroyed or the time limit is reached. A departed
    enemy ship returns to its fleet on the campaign map. Machine Nodes &
    Strongholds (#23) decides where the fleet goes. Withdrawn ships give no
    salvage. Strongholds never withdraw (`withdraw_sr` 0).
11. **Left behind.** In a loss-class outcome, every DISABLED player ship is
    **left behind**: the report lists it for recovery (rule 15). In a win-class
    outcome, every DISABLED player ship is **recovered**: the player holds the
    field, and the report lists it with no recovery charge. The hull a
    recovered ship returns with is Hulls' rule, not this system's.
12. **Inert ships are absent** (resolves Runtime ID Service Open Question 3).
    An `INERT` ship in a mid-battle save takes no part and does not count in
    `P` or `E`. It is never destroyed, disabled, retreated or left behind, adds
    nothing to `destroyed_DP` and costs nothing. The report lists it under
    `inert`, and Hulls returns it to its roster state when its content returns.
13. **Capture is not at MVP.** No ship changes hands in battle. If capture is
    added, this system changes the owner and emits the ownership-change event
    (Runtime ID Service rule 4). The end state CAPTURED is reserved.

**C. Ending the battle and the hand-off**

14. **The P7 order** for this system, fixed in code:
    - (a) destruction: rule 7, in ascending Runtime ID;
    - (b) retreat: rule 8, in ascending Runtime ID;
    - (c) the standoff warning, then the end check: rules 3 – 5;
    - (d) then Simulation Tick & Pause evaluates the auto-pause triggers.

    If (c) ends the battle, the triggers in (d) are still evaluated and logged,
    but they add no hold.
15. **The end latch.** When (c) ends the battle, this system sets
    `battle_ending`, builds the Battle Outcome report (rule 17) and emits the
    record-tier `BattleEnd` event. P8 and the retire point run as normal, and
    P9 flushes `BattleEnd` with the tick stamp. Nothing ticks after this tick.
16. **The hand-off.** After that tick's P9, this system calls Simulation Tick &
    Pause's context end. Tick's atomic battle-end step clears `PLAYER_PAUSE` and
    `AUTO_PAUSE`, adds `PLANNING:debrief` and switches to `CAMPAIGN`. Within
    that same step, before the next driver pass, the report is delivered to each
    consumer in **ascending system number**: Deterministic RNG (#2), World Clock
    (#8), Battle Record (#9), Vigor (#13), Credits (#18), Machine Nodes &
    Strongholds (#23), Debrief (#24), then Salvage & Recovery (#36) once it
    exists. The Debrief therefore opens on a closed record with a final bill. No
    campaign tick runs while its hold stands.
17. **The Battle Outcome report** holds facts only, never a price. Its fields
    are `battle_id`, `outcome`, `end_cause` (`ENEMY_ABSENT`, `PLAYER_ABSENT`,
    `MUTUAL`, `TIME_LIMIT`), `end_tick`, `sim_s`, `opening_loss`,
    `flagship_end` (PRESENT, RETREATED or DISABLED), `deployed_DP`,
    `retreated_DP` and `retreated_pm` (D4), `left_behind_DP` (D3), and
    `destroyed_DP` (D3). It also holds these lists in ascending Runtime ID:
    `player_retreated[]`, `player_disabled_left[]`, `player_disabled_recovered[]`,
    `player_present_at_end[]`, `enemy_destroyed[]` (with DP), `enemy_withdrawn[]`,
    `enemy_present_at_end[]`, `inert[]`, and `last_player_loss`, the ship whose
    disabling or departure made `P` 0. Each consumer looks up hull values and
    prices in its own data.
18. **It never charges.** This system calls no spend, charge, erosion or skip.
    Credits' `apply_defeat(report)` runs only for the loss class. Lost salvage
    scales with the share of the fleet left behind (Credits rule 7 and D2,
    using `retreated_pm` from D4): a full retreat loses none and a DEFEAT loses
    all, so bringing more of the fleet home always costs less, and retreating
    one cheap ship early saves almost nothing. The defeat
    cap, the days and the Vigor erosion are each their owner's, so the one-defeat
    bound is enforced where it is defined (Credits rule 7, World Clock's
    `DEFEAT_MAX_S`).
19. **The opening loss.** `opening_loss` is true only when the battle setup
    carries `exempt_lasting_cost = true` (Vigor rule 18's flag) and the outcome is in the loss class.
    Onboarding & Opening Sequence (#53) sets the setup flag on exactly one battle
    per save. This system never sets it from any other source. Every cost
    consumer reads the flag and applies nothing (Credits rule 8; concept: no
    lost salvage, no days). Vigor keys on the setup flag itself and restores
    `C` whatever the outcome (Vigor rule 18). If the player wins the
    opening battle, the flag is false and the win is an ordinary win.
20. **Pause is never graded** (Simulation Tick & Pause rule 18). Neither the
    outcome nor the report reads, records or depends on holds, speed or step
    usage.
21. **Determinism.** This system draws no random numbers. All counts and sums
    are integers. Ships are processed in ascending Runtime ID. Ties are settled
    by rule 4's fixed order. The same seed and command log give the same
    outcome, report and `BattleEnd` tick.
22. **Events** (record tier, Combat Event Bus & Battle Record rule 9; the
    existing names are kept):
    - `Destroyed(ship, killer, killer_slot, qx, qy)` for an enemy at hull 0;
    - `Disabled(ship, cause_code = hull_zero, killer, killer_slot, qx, qy)` for
      a player ship at hull 0. The new killer fields let the Record write the
      **kill window** at hull-zero `Disabled` as it does at `Destroyed`, so the
      Debrief's "lost to focus fire" works on player ships;
    - `Retreated(ship, cause_code)` (rule 8);
    - `StandoffWarning(sim_s)` (new);
    - `BattleEnd(outcome, cause_code = end_cause, opening_loss, P, E,
      destroyed_DP, retreated_DP)`; fields added to the existing event.
    The additions raise `EVENT_SCHEMA_VERSION`.
23. **Save.** The per-ship end states, the departure tallies, `standoff_warned`
    and `battle_ending` are part of `SimState` and are saved mid-battle. Counts
    are rebuilt from the ship states on load, never stored on their own.

### States and Transitions

**Battle**

| State | Entered when | Leaves to |
|---|---|---|
| RUNNING | the battle context starts | WARNED (standoff warning), ENDING |
| WARNED | `sim_s` ≥ `BATTLE_LIMIT_S − STANDOFF_WARN_S` | ENDING |
| ENDING | the end check succeeds in P7 (rule 15) | ENDED |
| ENDED | Tick's atomic battle-end step (rule 16) | — |

**Ship end state** (this system's view; the Hulls state is in brackets)

| State | Entered when | Leaves to |
|---|---|---|
| FIGHTING (Deployed) | battle start | DISABLED, DESTROYED, RETREATED |
| DISABLED (player only) | hull 0, P7 (rule 7) | at end: recovered (win class) or left behind (loss class) |
| DESTROYED (enemy only) | hull 0, P7 (rule 7) | — (retired at the retire point) |
| RETREATED (Retreated) | Combat Space departure processed in P7 (rule 8) | — |
| ABSENT | `INERT` (rule 12) | — |
| CAPTURED | reserved, post-MVP (rule 13) | — |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | both | P7 handler (rule 14); escort-lost signal; context end call; Tick does the atomic step |
| Deterministic RNG & Seed Streams (#2) | #22 → #2 | Report delivery triggers its battle-end step (battle streams discarded, deferred campaign draws) |
| Runtime ID Service (#3) | both | `status()`; retire queue for DESTROYED; disabled and retreated ships stay `LIVE`; inert ships absent |
| World Clock (#8) | #22 → #8 | Report out; World Clock caps battle time cost at `BATTLE_MAX_S` itself. The defeat skip length belongs to Defeat & Debrief, under `DEFEAT_MAX_S` |
| Combat Event Bus & Battle Record (#9) | #22 → #9 | Rule 22 events; the report closes the record |
| Hulls & Ship Definition (#10) | both | DP in; Retreated, Disabled, Destroyed states out |
| Combat Space (#11) | #11 → #22 | Retreat-zone departures; grid removal of disabled ships |
| Weapons & Damage (#12) | #12 → #22 | Hull 0 set in P5, with the killing source |
| Vigor (#13), Credits (#18) | #22 → them | The report; `opening_loss` |
| Flagship Piloting (#15) | #15 → #22 | Flagship loss context (passes to the Record) |
| Fleet Orders (#19) | #22 → #19 | Ends orders with `subject_retreated` or `subject_disabled` |
| Fleet Coordination (#21) | #21 → #22 | WITHDRAW sets retreat intent on linked enemy ships |
| Machine Nodes & Strongholds (#23) | both | `withdraw_sr` 0 for strongholds; report (where a withdrawn fleet goes, node broken) |
| After-Action Debrief (#24) | #22 → #24 | Outcome, `end_cause`, `last_player_loss` |
| Salvage & Recovery (#36) | #22 → #36 | `destroyed_DP`, `enemy_destroyed[]`, left-behind lists |
| Audio Direction (#52) | #22 → #52 | `BattleEnd.outcome` for the end stinger |
| Onboarding & Opening Sequence (#53) | #53 → #22 | `exempt_lasting_cost` in the battle setup |

## Formulas

### D1. Presence

`P = |{ s on the player side : status(s) = LIVE ∧ cs_state(s) ∈ {Active, Retreating} ∧ ¬disabled(s) }|`;
`E` is the same over the enemy side.

| Variable | Range | Description |
|---|---|---|
| P, E | 0 – roster size (≤ 64 per side at MVP) | Present ships per side |
| `dep_P`, `dep_E` | 0 – roster size | Ships of that side that departed this battle |

### D2. Outcome

| Test, in order | Outcome | `end_cause` |
|---|---|---|
| E = 0 ∧ P = 0 | `dep_E` > 0 ? ENEMY_WITHDREW : VICTORY | `MUTUAL` |
| E = 0 | `dep_E` > 0 ? ENEMY_WITHDREW : VICTORY | `ENEMY_ABSENT` |
| P = 0 | `dep_P` > 0 ? PLAYER_RETREATED : DEFEAT | `PLAYER_ABSENT` |
| `sim_s` ≥ `BATTLE_LIMIT_S` | STANDOFF | `TIME_LIMIT` |
| otherwise | — (battle continues) | — |

### D3. DP tallies

`destroyed_DP = Σ DP(s)` over enemy DESTROYED ships;
`left_behind_DP = Σ DP(s)` over player DISABLED ships, in the loss class only (0 in the win class).

Example: three enemy ships of DP 43, 20 and 57 are destroyed, so
`destroyed_DP` = **120**. At `SALVAGE_CR_PER_DP` 20, Credits pays 120 × 20 =
**2,400** into the hold, which matches Credits D5's 120 DP per won battle.

### D4. Retreated share

`retreated_pm = retreated_DP × 1,000 div max(1, deployed_DP)`.

| Variable | Range | Description |
|---|---|---|
| `deployed_DP` | 5 – 9,600 | Σ DP of the player ships fielded at battle start |
| `retreated_DP` | 0 – `deployed_DP` | Σ DP of player ships RETREATED (STANDOFF adds those present at the end) |
| `retreated_pm` | 0 – 1,000 | The Debrief's "share of the fleet brought home" |

### D5. Standoff warning

`warn_s = BATTLE_LIMIT_S − STANDOFF_WARN_S` = 1,800 − 120 = **1,680** simulated seconds
(tick 100,800 after battle start at 60 Hz; 50,400 at 30 Hz). `sim_s` uses integer
division, so the warning fires on the first tick of second 1,680.

### Worked example: a retreat from a stronghold

The player fields a flagship (ID 101, DP 60), two line ships (102 and 103, DP
43 each) and a light (104, DP 20). `deployed_DP` = 60 + 43 + 43 + 20 = **166**.
The enemy is a stronghold (`withdraw_sr` 0).
- **Tick T1:** 103 reaches hull 0 in P5. In P7(a) it is DISABLED, and the
  escort-lost signal is raised. P = 3.
- The player pauses and gives Retreat to 102 and 104 from the order menu, then
  flies the flagship into the retreat arc.
- **T2:** 104 completes `RETREAT_HOLD` (180 ticks). In P7(b) it is RETREATED.
  P = 2.
- **T3:** the flagship departs and is RETREATED. Flagship Piloting goes to No
  flagship, and the battle continues (rule 6). P = 1.
- **T4:** 102 is disabled 40 ticks short of departing. P = 0, E ≥ 1, `dep_P` =
  2, so the outcome is **PLAYER_RETREATED** with `PLAYER_ABSENT`, and
  `last_player_loss` = 102.
- Report: `retreated_DP` = 60 + 20 = **80**; `retreated_pm` = 80,000 div 166 =
  **481**; `left_behind_DP` = 43 + 43 = **86**; `player_disabled_left` = [102,
  103]; `flagship_end` = RETREATED. With a hold of 4,800 and `LOST_SALVAGE_PM`
  500, Credits' lost salvage is 4,800 × 500 × (1,000 − 481) div 1,000,000 =
  **1,245** (a DEFEAT would lose 2,400). Credits bills that and the recovery of 102 and 103,
  within its cap. This system charged nothing.

If this had been the authored opening, `opening_loss` would be true and every
consumer would apply nothing.

## Edge Cases

- **If both sides reach zero on the same tick**: the outcome is the win class
  with `end_cause = MUTUAL` (D2 row 1). Disabled player ships are recovered.
- **If elimination and the time limit fall on the same tick**: elimination
  wins (D2 order).
- **If a ship departs and reaches hull 0 on the same tick**: Combat Space
  removes it from the grid on departure, so it cannot be hit afterwards. It is
  RETREATED, never DISABLED.
- **If a Retreating ship is disabled before `RETREAT_HOLD`**: it is DISABLED.
  The retreat timer is discarded.
- **If the flagship departs while escorts are still fighting**: the battle
  continues (rule 6). The player commands through the order menu and pause.
- **If the flagship is disabled**: the same applies, and the flagship is listed
  as DISABLED. In the loss class it is left behind and recovered by the bill,
  never lost.
- **If every remaining player ship is disabled with none departed**: DEFEAT.
- **If an enemy fleet starts WITHDRAW and then goes BROKEN**: ships already
  departed stay withdrawn. The rest receive no goal and fight on. The outcome
  is ENEMY_WITHDREW if `dep_E` > 0 when `E` reaches 0.
- **If a stronghold and the player never close**: STANDOFF at `BATTLE_LIMIT_S`,
  with a warning 120 simulated seconds before.
- **If a side is entirely `INERT` when a mid-battle save loads**: that side's
  count is 0 at the first P7, and the battle ends by D2. An all-inert enemy
  side gives VICTORY with `destroyed_DP` 0.
- **If a battle setup has no ship on one side**: setup validation refuses it
  before the battle context starts. No outcome is emitted.
- **If the battle ends during a 10-tick step**: the step stops after the ending
  tick (Simulation Tick & Pause, Stepping).
- **If a trigger fires on the ending tick**: it is logged and adds no hold
  (rule 14).
- **If projectiles are still in flight at the end**: they are discarded with
  the battle and have no effect.
- **If the player wins the opening battle**: `opening_loss` is false, and it is
  an ordinary win. Onboarding decides what follows.
- **If `opening_loss` is set on a win-class battle**: it cannot be. Rule 19
  forces it false, and debug builds assert.
- **If a retreated ship is targeted by a pending order after it departs**: the
  order ends `target_retreated` (Fleet Orders rule 10).
- **If the report is delivered twice** (a crash in the hand-off and a reload):
  the battle reloads from the last tick boundary and ends again on the same
  tick with the same report. Each consumer applies by `battle_id` once.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | P7 slot, context end, escort-lost signal |
| Combat Event Bus & Battle Record (#9) | Hard | Events, record close |
| Weapons & Damage (#12) | Hard | Hull 0 in P5 |
| Fleet Orders (#19) | Hard | Retreat order, order end |
| Runtime ID Service (#3) | Hard | Status, retire, order of processing |
| Combat Space (#11) | Hard | Departures |
| Hulls & Ship Definition (#10) | Hard | DP, ship states |
| World Clock (#8) | Soft | Report consumer only; this system reads no clock value |
| Deterministic RNG & Seed Streams (#2) | Soft | Battle-end step ordering only; this system draws nothing |
| Flagship Piloting (#15), Fleet Coordination (#21) | Soft | Loss context; enemy withdrawal intent |
| Credits (#18), Vigor (#13), #23, Debrief (#24), Salvage (#36), Audio (#52), Onboarding (#53) | Hard (reverse) | The report, `opening_loss`, `exempt_lasting_cost` |

Bidirectional check: Simulation Tick & Pause, Runtime ID Service, Combat Space,
Fleet Orders, Flagship Piloting, Hulls, Credits, RNG and Gameplay Settings name
this system. Event Bus, Vigor and Fleet Coordination are amended with this GDD;
Weapons & Damage is confirmed at its re-review (Open Question 5).

## Tuning Knobs

| Knob | Default | Safe range | Effect |
|---|---|---|---|
| `BATTLE_LIMIT_S` | 1,800 sim s | 900 – 3,600 | Unpaused length before STANDOFF. Too low cuts real fights short; too high lets a stalemate drag |
| `STANDOFF_WARN_S` | 120 sim s | 60 – 300 | Lead time before a STANDOFF. Too low gives no time to act; too high warns too early |
| `MUTUAL_TO_PLAYER` | true | true / false | Same-tick mutual end goes to the win class. False would make it a loss class (Open Q2) |
| `PLAYER_ZERO_HULL` | DISABLED | DISABLED; DESTROYED (permadeath mode only) | Whether a player ship can be lost for good |
| `END_BEAT_MS` | 1,200 ms | 600 – 2,000 | Presentation only: the end banner before the Debrief fades in. The simulation is already held |

Owned elsewhere and read here: `RETREAT_HOLD` and `RETREAT_ARC` (Combat Space),
`BATTLE_MAX_S` and `DEFEAT_MAX_S` (World Clock; cost caps, not end conditions), `withdraw_sr` (Fleet
Coordination), the defeat cap (Credits). All in `assets/data/battle/`.

## Visual/Audio Requirements

- A disabled player ship must read as **out, not dead**: it goes dark and
  drifts, it does not explode. Enemy destruction may explode.
- A departure has its own cue at the zone edge, distinct from a destruction.
- The end banner names the outcome in words ("Victory", "They broke",
  "Withdrawn", "Fleet disabled", "Standoff"), never colour alone.
- Each outcome has a stinger (Audio #52). Loss-class stingers frame the loss as
  a lead, not a punishment (systems index).
- The standoff warning has a one-time audio cue and a HUD line.

## Game Feel

- **Getting out is a fight**: the `RETREAT_HOLD` window under fire is the
  tension, with no dice afterwards.
- **No sudden endings**: every end condition is shown before battle, and the
  time limit is warned.
- **The Debrief arrives on the beat**: the banner holds for `END_BEAT_MS`, then
  the Debrief opens with the cause.

## UI Requirements

- Pre-battle panel: "The battle ends when either side has no ship on the field,
  or at the time limit"; the retreat zone; the defeat-cap lines from Credits;
  "STANDOFF counts as a retreat; salvage lost scales with the share of the
  fleet left behind".
- End banner on `end_cause = MUTUAL`: "Pyrrhic victory", and the Debrief
  explains the same-tick rule.
- HUD: present counts per side (D1); disabled ships marked on the field; the
  standoff countdown after the warning.
- Paused, after the flagship is gone: the order menu's Retreat stays reachable
  for any selection (Fleet Orders rule 3).
- Debrief header: outcome, `end_cause`, `retreated_pm` as "N of M brought home",
  and the left-behind list.
- 📌 **UX Flag — Battle Resolution**: include the end banner, the present counts
  and the standoff countdown in the Combat HUD UX spec, and the outcome header
  in the Debrief spec.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| P7, context end, triggers, rule 18 | `design/gdd/simulation-tick-and-pause.md` | Rules 3, 10, 11, 18; Auto-pause and Context edges | Rule dependency |
| Retreat is not retirement; inert | `design/gdd/runtime-id-service.md` | Core Rules 4, 6; Edge Cases; Open Q3 | Rule dependency |
| Zones, `RETREAT_HOLD` | `design/gdd/combat-space.md` | Rule 12 | Rule dependency |
| Retreat order, `subject_retreated` | `design/gdd/fleet-orders.md` | Rules 1 – 3, 7, 10, 12 | Rule dependency |
| Flagship loss | `design/gdd/flagship-piloting.md` | Rule 13 | Rule dependency |
| DP, ship states | `design/gdd/hulls-and-ship-definition.md` | D1; States | Data dependency |
| Salvage, bill, `opening_loss` | `design/gdd/credits-upkeep-and-sinks.md` | Rules 2, 7, 8; D2 | Data dependency |
| Withdraw | `design/gdd/fleet-coordination.md` | Rule 5; D2 | Rule dependency |
| `BATTLE_MAX_S` is a cost cap, not an end | `design/gdd/world-clock.md` | Rule 3; Tuning Knobs | State trigger |
| Defeat bounds, opening loss | `design/gdd/game-concept.md` | Core Mechanics; Flow State Design; Pillar 1 | Pillar dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 21)**: the same seed and command log give identical outcome, report and `BattleEnd` tick across two runs; this system makes no RNG draw.
- **AC-02 (Logic; rule 4, D2)**: each D2 row has a fixture producing its outcome and `end_cause`, including the MUTUAL tick.
- **AC-03 (Logic; rule 4)**: a fixture where elimination and `BATTLE_LIMIT_S` coincide ends with the elimination outcome.
- **AC-04 (Logic; rule 6)**: disabling the flagship with escorts present does not end the battle; orders to escorts still apply on the next tick.
- **AC-05 (Logic; rule 7)**: an enemy at hull 0 is DESTROYED and retired at the retire point; a player ship at hull 0 is DISABLED, stays `LIVE` and is never retired.
- **AC-06 (Logic; rule 7)**: disabling a non-flagship player ship raises escort-lost on that tick; disabling the flagship does not.
- **AC-07 (Logic; rule 8)**: a ship reported by Combat Space is RETREATED on the same tick's P7, keeps its ID, and its order ends `subject_retreated`.
- **AC-08 (Logic; rule 8)**: no player ship is ever RETREATED without retreat intent; no single key press creates one.
- **AC-09 (Logic; rule 10)**: a roaming fleet at SR ≤ 250 departs its linked ships; its cut ships do not depart; a stronghold never departs a ship.
- **AC-10 (Logic; rule 12)**: a mid-battle save with an `INERT` enemy ship gives E without it; the ship appears only under `inert[]` and adds 0 to `destroyed_DP`.
- **AC-11 (Logic; rule 14)**: on the ending tick, a true hull-critical trigger is logged and adds no hold.
- **AC-12 (Logic; rule 16)**: between the ending tick's P9 and the next driver pass, the hold set is never empty, `PLANNING:debrief` is present, and no campaign tick runs.
- **AC-13 (Logic; rule 16)**: consumers receive the report in ascending system number, once each per `battle_id`.
- **AC-14 (Logic; rule 18)**: this system calls no Credits, Vigor or World Clock mutator; a test spy records zero calls.
- **AC-15 (Logic; rule 19)**: `opening_loss` is true only for a loss-class outcome of a setup with `exempt_lasting_cost`; with it, Credits' bill is 0 and the hold is unchanged.
- **AC-16 (Logic; rule 20)**: two runs of one command log, one with 40 pauses and steps and one with none, give byte-identical reports.
- **AC-17 (Logic; worked example)**: the fixture gives PLAYER_RETREATED, `retreated_pm` 481, `left_behind_DP` 86 and `last_player_loss` 102.
- **AC-18 (Logic; D3)**: destroying enemies of DP 43, 20 and 57 gives `destroyed_DP` 120.
- **AC-19 (Logic; rule 5)**: `StandoffWarning` is emitted once at `sim_s` 1,680, and STANDOFF at 1,800 lists the present player ships as retreated; a battle paused for an hour of wall time at `sim_s` 100 is still running at `sim_s` 1,000.
- **AC-22 (Logic; rule 18, Credits D2)**: with hold 4,800 and `LOST_SALVAGE_PM` 500, a 1-of-4 retreat (DP 20 of 166, `retreated_pm` 120) loses 2,112, a full DEFEAT loses 2,400 and a full retreat loses 0.
- **AC-23 (Logic; rule 9)**: a ship at its Vigor floor with retreat intent reaches its zone and completes `RETREAT_HOLD` in a no-enemy fixture.
- **AC-24 (Logic; UI)**: a MUTUAL end shows the "Pyrrhic victory" banner.
- **AC-20 (Playtest)**: 4 of 5 testers, after the opening loss, say they lost nothing lasting and can name why they lost.
- **AC-21 (Playtest)**: 4 of 5 testers who retreat at least once say they chose the moment themselves.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **Permanent ship loss**: never in the default mode; player ships are DISABLED
  (rule 7). DESTROYED applies to player ships only in the optional permadeath
  mode.
- **Mutual same-tick end**: goes to the player (rule 4, `MUTUAL_TO_PLAYER`).
- **STANDOFF**: kept as a fifth, loss-class outcome, costed as a
  PLAYER_RETREATED (rule 5), pending Open Question 5.
- **Retreat costs less than defeat**: lost salvage scales with the share left
  behind (rule 18; Credits D2 amended). The CD review rejected "DEFEAT only",
  because one cheap early retreat would erase the cost.
- **Gameplay Settings † keys**: this system reads no Tier C key.
  `stronghold_strength_permille` belongs to Machine Nodes & Strongholds (#23),
  and `defeat_cost_permille` to Credits and the Debrief.
- **Vigor on retreat vs defeat**: Vigor erodes from spending, whatever the
  outcome. Only `exempt_lasting_cost` restores it (Vigor rule 18).
- **Runtime ID Service Open Question 3**: inert ships are absent (rule 12).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Hull 0 handling**: confirm that Weapons & Damage only sets hull 0 in P5, and that this system's P7 hook settles it (rule 7). | Weapons & Damage owner | #12 re-review |
| 2 | **RNG battle-end order**: confirm that the RNG battle-end step (stream discard, deferred campaign draws) fits rule 16's ascending delivery. | RNG owner | #2 re-review |
| 3 | **Recovered hull value** of a disabled ship after a win or a paid recovery. | Hulls owner | #10 re-review |
| 4 | **Where a withdrawn machine fleet goes**, and whether its node counts as broken. | Machine Nodes & Strongholds (#23) | When #23 is designed |
| 5 | **`BATTLE_LIMIT_S`** of 30 unpaused minutes is a starting point; tune it with the AI-vs-AI Runner's battle-length data. The Runner also tests whether kiting to STANDOFF costs less than an ordered retreat; if it does, STANDOFF is cut. | systems-designer | Runner tuning |
| 6 | **How a defeat's day cost is computed** from the report, under `DEFEAT_MAX_S` (World Clock Open Question 6). | Defeat & Debrief (#24) | When #24 is designed |
| 7 | **Left-behind lent ships**: the standing cost with the lending faction, previewed before battle. | Faction Reputation & Standing, Allied Lending (#33) | When #33 is designed |
