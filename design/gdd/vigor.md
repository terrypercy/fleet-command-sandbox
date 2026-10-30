# Vigor

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on the 'inverted curve' flux claim, the floor state, erosion causes for the Debrief, invisible ember cost, and core-rule gaps; all five revised
> **Implements Pillar**: Pillar 5 (Living Against Made — Vigor is living energy, located in cores, eroding and restored only by rest; never flux under another name); Pillar 1 (Every Defeat Is a Lead — running dry changes behaviour, never locks a ship out)

## Summary

Vigor is the living energy of organic ships, held in physical cores on the hull:
a pool that refills in battle from the ship's flow, and a ceiling that erodes
with every spend and every membrane absorption for the rest of the expedition,
restored only by port rest (days) or care (standing). Running dry never disables
a ship; it falls to ember fire, and at the floor it fights and retreats
indefinitely. Located cores, hits that never stop the guns, no overload and two
timescales on one bar keep it from being flux under another name (Pillar 5).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Gameplay Settings & Modifiers, Combat Event Bus & Battle Record, Combat Space, Hulls & Ship Definition`

## Overview

Vigor is the living energy of organic ships. Every organic weapon shot, boost
and membrane absorption is paid in Vigor, and Vigor is held in the ship's
**cores**, the glowing anchors on its hull (Hulls & Ship Definition, rules 7
and 15). It has two parts:

- the **pool**, what the ship can spend right now, which refills steadily from
  its cores during battle;
- the **ceiling**, how large the pool can be, which **erodes with every spend
  for the rest of the expedition** and is restored only by port rest (days on
  the World Clock) or a living race's care (standing).

Shots spend the pool; the membrane spends the ceiling; both erode the
expedition. Running dry never disables a ship: it falls to **ember fire**, a
weakened mode that keeps it fighting by burning its future. At the ceiling's
**floor** a ship still fights, refills and retreats indefinitely.

The design test is the concept's: *if a Starsector player can map Vigor 1:1
onto flux, Vigor fails.* Core Rule 11 lists the concrete differences.

## Player Fantasy

**Spend your own life.** Every shot is breath the ship won't get back this
expedition. The choice lives in the moment of firing: this volley now, or a
brighter ship in the fight after next. And the readout is the ship itself: its
cores glow less as the ceiling erodes and pulse faster as the pool empties, a
creature the player nurses home.

*Anchor moment:* the third fight of an expedition. The Spiralward's cores are
dimmer than at the start; the player holds the Glowlance until the ward is
already down, fires once, and pulls back before the pool runs dry. Back in
port, the rest takes three days, and a rival gets a system closer.

**Pillars served:**
- **Pillar 5, *Living Against Made*:** located cores, hits that never stop the
  guns, no overload or vent, two timescales on one bar (rule 11).
- **Pillar 1, *Every Defeat Is a Lead*:** running dry changes behaviour and is
  recorded ("Vigor ran dry" is a Debrief cause, never a lockout).

**This system must never make the player feel:** "I ran dry and could do
nothing" (the prototype's worst moment), or "this is just flux".

## Detailed Design

### Core Rules

**A. Units and parts**

1. **Vigor is counted in milli-Vigor (mV)**, 1 V = 1,000 mV, all integers. The
   hull's base ceiling `C0` is `vigor_ceiling` (Hulls rule 7) × 1,000.
2. **The ceiling `C` is the sum of per-core ceilings** `C_k`, one per glow
   anchor, split equally at the start. It lives on the ship instance
   (`vigor_core_mV[]`, saved; Hulls rule 12) and carries between battles.
3. **The pool `P`** is what can be spent now; always `0 ≤ P ≤ C`. At deployment
   `P = C`.

**B. In battle**

4. **Refill is continuous**, with no idle delay and no vent action:
   `REFILL_PM` (500 ‰) of the hull's `vigor_flow` per second, from live cores
   (Formulas D1). A core at 0 contributes nothing (refill scales by the share
   of `C_k` that is not dark). Refill depends on `vigor_flow`, which never
   erodes, so an eroded ship keeps its sustained output and loses only burst.
5. **Draws are capped by flow.** All spending in a second (shots and boost) is
   limited to `vigor_flow` by a one-second token bucket. When Vigor (#13)
   answers a weapon's request, it answers one of three:
   - **full**: the shot fires normally, `P −= vigor_per_shot`;
   - **ember**: the band is EMPTY **or** `P < vigor_per_shot`; the shot fires as
     an ember shot (rule 9);
   - **refused**: only when the flow bucket is spent this second; the weapon
     retries next tick and makes no draw (Weapons & Damage rule 3).
6. **Every pool spend erodes the ceiling**: a spend of `s` V removes
   `s × ERODE_MV` mV (20 mV per V; Formulas D2) from `C`, spread across cores in
   proportion to `C_k`, scaled by `vigor_erosion_permille` (Gameplay Settings &
   Modifiers).
7. **The membrane spends the ceiling, not the pool** (Weapons & Damage rule 7):
   - it absorbs `membrane_permille` of a hit, **scaled by `P ÷ C`** (a full ship
     has a strong membrane; a drained one, none);
   - every absorbed point removes `MEMB_MV` (100 mV) from the **core nearest the
     hit's contact point**;
   - if the nearest core is at 0, it takes from the next-nearest live core; a
     core reduced to 0 by any cause goes dark and loses its share of refill
     (rule 4);
   - it never takes `C` below the floor; at the floor it absorbs nothing;
   - it has no toggle and no overload state.
8. **Bands** (`p = P × 1,000 ÷ C`), with hysteresis, each emitted as a `VigorBand`
   event (Battle Record):
   - **OK**;
   - **LOW**: enter below 350, leave at 450 or above;
   - **EMPTY**: enter below 50, leave at 200 or above;
   - **FLOOR**: `C` ≤ `C_floor`; overrides the others for the rest of the battle
     (the ceiling cannot rise in battle).
9. **Running dry changes behaviour; it never disables** (concept; prototype):
   - **EMPTY**: weapons fire **ember shots**: `EMBER_DMG_PM` (400 ‰) damage at
     `EMBER_REFIRE_PM` (2,000 ‰) cooldown, each burning `vigor_per_shot ×
     EMBER_MV` (60 mV per V, three times normal erosion) straight from `C`
     (never below the floor). The membrane is 0 (because `P ≈ 0`). Movement is
     at 900 ‰ (published to Combat Space rule 6a). The pool keeps refilling, so
     EMPTY ends on its own unless the player keeps firing.
   - **FLOOR**: erosion stops (`C` never drops below `C_floor`), so spending and
     ember fire are free; the membrane absorbs nothing; movement is at 850 ‰;
     refill is unchanged. The ship can fight and retreat indefinitely.
   - No Vigor state ever produces `Disabled` or zero speed.
10. **Boost** draws `BOOST_FLOW_PM` (400 ‰) of `vigor_flow` per second while held
    and publishes a `BOOST_PM` (1,400 ‰) multiplier on `v_cap` and `a_step`
    (Combat Space rule 6a). In EMPTY, boost is an ember boost: 1,150 ‰, burning
    `C` like ember shots.
11. **Not flux.** These are the differences a Starsector player meets:
    1. **Taking hits never stops you shooting.** In Starsector, shield hits add
       flux to the same pool the guns use. Here the membrane erodes the ceiling
       and leaves the pool alone, so taking fire shortens the expedition, not
       this fight. Membrane strength also fades gradually with the pool; there
       is no cliff.
    2. **No overload, vent or lockout**: running dry is ember fire, fighting on
       by burning the future.
    3. **Location matters**: the membrane drains the core facing the hit, and
       RUPTURE darkens one core (rule 12). Turning a fresh flank is a tactic.
    4. **Two timescales on one bar**: shots spend the pool (this fight), the
       membrane and every spend erode the ceiling (this expedition).
    5. **Erosion follows choices, not time**: Starsector's combat readiness
       decays with time deployed and costs supplies; Vigor erodes only with
       what the ship spends, and is restored only with days or standing.
12. **Core damage.** A RUPTURE `CoreStruck` (Weapons & Damage rule 11) removes
    `core_damage × 1,000` mV from that core's `C_k` (difficulty does not scale
    it), and the same from `P` (then clamped to `C`). A core at 0 goes dark.
    If every core would go dark, the lowest-index core keeps `C_floor`.
13. **Early warning**, before EMPTY: entering LOW quickens the cores' pulse and
    plays a breath cue; and a "dry in N s" marker appears when `P ÷ net drain <
    WARN_S` (3 s).

**C. Between battles**

14. **Carry-over.** `C` (per core) persists on the ship. At battle end,
    `VigorCeilingEroded(ship, amount, by_source, by_core)` is emitted (Battle
    Record): the total split by source (spend, ember, membrane, core strike) and
    by core, so the Debrief can name the largest erosion source and the core
    that lost the most ("you lost most of your ceiling to ember fire" → hold
    fire; "the bow core took every hit" → turn a fresh flank).
15. **The floor** is `C_floor = (C0 × VIGOR_FLOOR_PM + 999) div 1,000`, with
    `VIGOR_FLOOR_PM` = 250. Difficulty never changes it (Gameplay Settings &
    Modifiers rule 9).
16. **Rest restores the ceiling** at `REST_RESTORE_PM_PER_DAY` (150 ‰ of `C0`
    per game day), composed with `rest_days_permille` (Formulas D4). Rest is a
    World Clock skip requested by Ports, Rest & Care (#27); the fleet rests in
    parallel, so the skip is the longest of every ship's Vigor and scar time
    (Hulls rule 8). An interrupted rest restores pro rata to elapsed time.
17. **Care** (hook only): `restore(ship, mV, source = care)` restores instantly
    and costs no days; Faction Reputation & Standing sets its price in standing,
    from the missing share. Care never raises `C` above `C0`.
18. **The opening loss is exempt.** If a battle carries `exempt_lasting_cost`
    (concept), `C` is reset to its battle-start snapshot at battle end;
    `VigorCeilingEroded` still reports the amount with `restored = true`, so the
    Debrief can say what it would have cost.

### States and Transitions

| State | Entered when | Behaviour | Leaves to |
|---|---|---|---|
| OK | p ≥ 450 (or start) | Full shots and membrane | LOW (p < 350) |
| LOW | p < 350 | Warning pulse and cue; "dry in N s" marker | OK (p ≥ 450), EMPTY (p < 50) |
| EMPTY | p < 50 | Ember fire, membrane 0, 900 ‰ movement | LOW (p ≥ 200) |
| FLOOR | C ≤ C_floor | Erosion stops; membrane 0; 850 ‰ movement; full shots from the pool, ember (free) when the pool is empty | — (rest of battle) |
| Docked / Resting | between battles | `C` carries; rest restores | Deployed |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Hulls & Ship Definition (#10) | #10 → #13 | `vigor_ceiling`, `vigor_flow`, `membrane_permille`, glow anchors; **instance gains `vigor_core_mV[]`** |
| Weapons & Damage (#12) | both | Grant answers full / ember / refused; membrane requests carry the contact point; `CoreStruck` |
| Combat Space (#11) | #13 → #11 | Movement multipliers (boost 1,400 ‰, EMPTY 900 ‰, FLOOR 850 ‰) via rule 6a |
| Combat Event Bus & Battle Record (#9) | #13 → #9 | `VigorBand`, `VigorCeilingEroded` (with `restored`) |
| Gameplay Settings & Modifiers (#7) | #7 → #13 | `vigor_erosion_permille`, `rest_days_permille` (accepted, 250 – 2,000); floor untouched |
| World Clock (#8) | #13 → #8 | Rest length in seconds for the skip |
| Ports, Rest & Care (#27) | both | Rest requests; which ports offer rest and care |
| Faction Reputation & Standing | → #13 | Care price in standing |
| Ship AI (#20) | #13 → #20 | Bands and the ember policy (when to hold fire) |
| Combat HUD (#46), art | #13 → them | Core brightness (`C_k ÷ C_k0`), pulse rate (pool emptiness), warning marker |

## Formulas

### D1. Refill per tick

`racc += vigor_flow × REFILL_PM`; `P += racc div (TICK_RATE)`; `racc = racc mod TICK_RATE`, in mV
(`vigor_flow` in V/s × `REFILL_PM` ‰ = mV/s), clamped to `C`; scaled by the
live-core share.

| Variable | Range | Description |
|---|---|---|
| vigor_flow | 5 – 200 V/s | Hulls |
| REFILL_PM | 250 – 1,000; **500** | Share of flow refilled per second |

**Example:** `vigor_flow` 60, `REFILL_PM` 500: 30,000 mV/s; per tick at 60 Hz
exactly 500 mV; over 60 ticks, 30,000 mV = **30 V/s**. At 30 Hz, 1,000 mV per
tick, the same per second.

### D2. Erosion per spend

`e = (s × ERODE_MV × m + 500) div 1,000` mV, with `s` in V and `m` =
`vigor_erosion_permille`; accumulated so no remainder is lost.

**Example:** 3,000 V spent in a typical battle at m = 1,000: 3,000 × 20 =
**60,000 mV** (60 V, 10 % of a 600-V ceiling). At m = 600: 36,000 mV.

### D3. Membrane

`a = hit × membrane_permille × P div (1,000 × C)` (points absorbed);
`cost = (a × MEMB_MV × m + 500) div 1,000` mV, from the nearest core, clipped to
`C − C_floor`.

**Example:** hit 100, `membrane_permille` 300, `P ÷ C` = 0.6: a = 18 absorbed,
costing 1,800 mV. A typical battle's 300 absorbed points cost 30,000 mV (5 %).

### D4. Rest length

`base_rest_s = ceil(deficit_mV × DAY_S ÷ (C0 × REST_RESTORE_PM_PER_DAY ÷ 1,000))`,
then composed with `rest_days_permille` (Gameplay Settings & Modifiers D2).

**Examples** (C0 600,000 mV): floor to full (deficit 450,000) = **432,000 s**
(5 days) at Standard, 540,000 s at `rest_days_permille` 1,250 (matching World
Clock D4), 216,000 s at 500. After a typical 3-battle expedition (deficit
270,000): **259,200 s** (3 days).

### D5. A typical expedition (calibration target)

Reference organic line ship: C0 600 V, `vigor_flow` 60, guns drawing about
51 V/s at full fire, refill 30 V/s. A typical 3-minute battle spends about
3,000 V and absorbs about 300 points:

| Preset (`vigor_erosion_permille`) | Ceiling lost per battle | After 3 battles | Floor (150 V) reached |
|---|---|---|---|
| Chronicler (600) | 54 V (9 %) | 438 V (**73 %**) | battle 9 |
| Standard (1,000) | 90 V (15 %) | 330 V (**55 %**) | end of battle 5 |
| Admiral (1,250) | 112.5 V (18.75 %) | 262.5 V (**43.75 %**) | end of battle 4 |

The target band is 40 – 70 % after 3 battles **on Standard** (prototype: 58 %);
Chronicler's 73 % is accepted as the easier preset making Vigor cheaper.
`vigor_per_shot` (Weapons & Damage) and `ERODE_MV` are tuned together to keep
Standard in band.

## Edge Cases

- **If every core is struck dark**: the lowest-index core keeps `C_floor`
  (rule 12).
- **If a weapon's `vigor_per_shot` is 0**: Vigor never refuses or embers it.
- **If the hull's ceiling is the minimum (100 V)**: the floor is 25 V; ember fire
  still works.
- **If several bands are crossed in one tick**: only the final band is emitted.
- **If the player "dives to the floor to fight for free"**: at FLOOR, full shots
  still fire from the pool and refill is unchanged, so sustained output is about
  59 % of full fire on the reference ship (30 of 51 V/s); ember shots (about
  20 % DPS) cover the gaps. But the membrane is gone, so the ship takes full
  damage, and it faces the longest rest. That is the deterrent. Floor time is
  logged in playtest (AC-15); if testers dive deliberately, the floor rules are
  revisited.
- **If the nearest core is already dark when a hit lands**: the membrane takes
  from the next-nearest live core (rule 7).
- **If care would exceed `C0`**: clamped to `C0`.
- **If an exempt opening battle is lost**: no ceiling is lost (rule 18).
- **If a rest is interrupted halfway**: half the deficit is restored.
- **If a suspend save is taken mid-battle**: `P`, `racc`, the flow bucket and
  per-core `C_k` are in the battle part (Save/Load Core Rule 22).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | Per-tick refill and bands |
| Hulls & Ship Definition (#10) | Hard | Organic block, cores, instance |
| Weapons & Damage (#12) | Hard (both) | Grants, membrane, core damage |
| Combat Space (#11) | Hard | Movement multipliers |
| Combat Event Bus & Battle Record (#9) | Hard | Events |
| Gameplay Settings & Modifiers (#7) | Hard | Erosion and rest keys |
| World Clock (#8), Ports, Rest & Care (#27), Faction Reputation | Hard (reverse / soft) | Rest skip, care |
| Ship AI (#20), HUD (#46) | Hard (reverse) | Bands, display |

Bidirectional check: Hulls, Weapons, Combat Space, Battle Record and Settings
already name Vigor.

## Tuning Knobs

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `ERODE_MV` | 20 mV per V | 10 – 50 | Expedition length per spend |
| `MEMB_MV` | 100 mV per point | 50 – 200 | Membrane's erosion cost |
| `REFILL_PM` | 500 | 250 – 1,000 | In-battle recovery |
| `VIGOR_FLOOR_PM` | 250 | 150 – 400 | Floor (never changed by difficulty) |
| `EMBER_DMG_PM` | 400 | 250 – 600 | Ember fire strength |
| `EMBER_REFIRE_PM` | 2,000 | 1,500 – 3,000 | Ember fire rate |
| `EMBER_MV` | 60 mV per V | 40 – 100 | Ember's ceiling cost |
| LOW / EMPTY thresholds | 350/450, 50/200 | ±100 | Warning timing |
| `WARN_S` | 3 s | 2 – 5 | Warning lead |
| `BOOST_PM`, `BOOST_FLOW_PM` | 1,400, 400 | 1,200 – 1,600; 200 – 600 | Boost |
| `REST_RESTORE_PM_PER_DAY` | 150 | 100 – 250 | Days to restore |

All in `assets/data/vigor/`.

## Visual/Audio Requirements

- **Core brightness** = `C_k ÷ C_k0` per core; **pulse rate** rises as the pool
  empties (concept: mechanics are the art). Readable in greyscale (Hulls R2).
- A struck dark core visibly goes out.
- Membrane absorption: a ripple across the skin, then a dip in the nearest
  core's pulse; a core never brightens when Vigor is spent (Weapons & Damage).
- Ember shots look and sound weaker; the LOW breath cue is audible but calm.

## Game Feel

- **The choice is in the trigger**: holding fire is a decision, not a cooldown.
- **Running dry is a downshift, not a wall**: the ship keeps moving and firing
  embers, and recovers on its own.

## UI Requirements

- Per organic ship: pool and ceiling on one bar (ceiling as the bar's length,
  pool as its fill, floor marked), band, and the "dry in N s" marker.
- **Ember cost is visible**: while ember fire is active, the ceiling end of the
  bar visibly burns back, and the first ember shot in each EMPTY band plays a
  distinct cue.
- **Flow-cap refusals are explained**: a shot refused by the flow cap (guns plus
  boost drawing more than `vigor_flow`) shows a brief cue on the weapon.
- Port and fleet screens: ceiling per ship and rest days needed.
- 📌 **UX Flag — Vigor**: include the Vigor bar, warning and rest preview in the
  Combat HUD and port UX specs before epics.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Organic block, cores, scar rest | `design/gdd/hulls-and-ship-definition.md` | Rules 7, 8, 12, 15 | Data dependency (instance gains `vigor_core_mV[]`) |
| Grants, membrane, core damage | `design/gdd/weapons-and-damage.md` | Rules 1, 3, 7, 11 (grant results amended) | Rule dependency |
| Movement multipliers | `design/gdd/combat-space.md` | Rule 6a | Rule dependency |
| Vigor events | `design/gdd/combat-event-bus-and-battle-record.md` | Rules 9, 14 | Data dependency |
| Erosion and rest keys; floor | `design/gdd/gameplay-settings-and-modifiers.md` | Rules 9, 13; D2 | Data dependency |
| Rest skip | `design/gdd/world-clock.md` | Rule 13; D4 | Rule dependency |

## Acceptance Criteria

- **AC-01 (Logic; D1)**: at 60 Hz and 30 Hz, a `vigor_flow` 60 ship refills exactly 30,000 mV per second of ticks, clamped at `C`.
- **AC-02 (Logic; D2)**: a 3,000-V spend removes exactly 60,000 mV at m = 1,000 and 36,000 mV at m = 600.
- **AC-03 (Logic; D3, rule 7)**: the hit-100 example absorbs 18 and costs 1,800 mV from the core nearest the contact point; `P` is unchanged; at `P` = 0 nothing is absorbed; at the floor nothing is absorbed; with the nearest core dark it takes from the next-nearest live core; a core drained to 0 by the membrane goes dark and stops contributing refill.
- **AC-04 (Logic; rule 8)**: hysteresis holds: p 349 enters LOW, 449 stays LOW, 450 leaves; 49 enters EMPTY, 199 stays, 200 leaves.
- **AC-05 (Logic; rule 9)**: at EMPTY a weapon fires ember shots at 400 ‰ damage and double cooldown, and `C` falls by `vigor_per_shot × 60` mV per shot; no fixture produces `Disabled` or zero speed from Vigor.
- **AC-06 (Logic; rules 9, 15)**: at FLOOR, a further 10,000 V of spending leaves `C` = `C_floor` and refill stays 30 V/s; the ship moves at 850 ‰ and reaches its retreat zone.
- **AC-07 (Logic; rule 15)**: Settings extremes (250 and 2,000) never change `C_floor`.
- **AC-08 (Logic; rule 12)**: `CoreStruck` reduces only that core's `C_k` and `P`; its brightness falls in proportion; striking every core leaves the lowest-index core at `C_floor`.
- **AC-09 (Logic; D5)**: the scripted 3-battle reference expedition ends at 330 V on Standard, 262.5 V on Admiral and 438 V on Chronicler.
- **AC-10 (Logic; D4)**: floor-to-full rest requests 432,000 s at 1,000, 540,000 s at 1,250 and 216,000 s at 500; an interruption at half time restores half the deficit.
- **AC-11 (Logic; rule 18)**: an exempt opening battle leaves `C` unchanged and emits `VigorCeilingEroded` with `restored = true`.
- **AC-12 (Logic; rule 13)**: under a constant drain, the "dry in N s" marker appears at least 3 s before EMPTY.
- **AC-13 (Logic; rule 5)**: a weapon refused for the flow cap makes no draw and fires on a later tick; full and ember answers are recorded correctly.
- **AC-14 (Logic; rule 10)**: holding boost publishes 1,400 ‰ to Combat Space and draws 24 V/s on a flow-60 ship.
- **AC-15 (Playtest)**: across 10 or more 3-battle expeditions on Standard, at least 70 % end at 40 – 70 % of `C0`; at least 3 of 5 testers change how they spend in battle 3 unprompted; how often EMPTY is reached and time spent at FLOOR are logged; running dry is nobody's worst moment; if any tester deliberately dives to the floor, the floor rules are revisited.
- **AC-17 (Logic; rule 14)**: `VigorCeilingEroded` carries the split by source and by core, summing to the total; the Debrief names the largest source and the core that lost the most.
- **AC-18 (Logic; rule 5)**: in LOW with `P` smaller than a shot's `vigor_per_shot`, the shot is answered ember.
- **AC-19 (UI)**: ember fire shows the ceiling burning back and plays its cue on the first ember shot of each EMPTY band; a flow-cap refusal shows its cue.
- **AC-16 (Playtest; flux test)**: at least 4 of 5 Starsector-literate testers, asked whether Vigor is flux, name at least 2 of rule 11's differences and do not call it "flux renamed".

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Reference loadout and `vigor_per_shot` values** must be set so D5 holds; Weapons' numbers are starting values. | systems-designer, Weapons & Damage | Balance pass |
| 2 | ~~**Which ports offer rest and care**~~ **Resolved 2026-10-30:** every dockable port offers rest; care is offered where the owner is an organic faction, priced by Faction Reputation D2 (Ports, Rest & Care rules 3, 18–19). | Ports, Rest & Care (#27) | Closed |
| 3 | ~~**Ember policy for AI**~~ **Resolved 2026-10-30** by Ship AI rule 7. | Ship AI (#20) | Resolved |
| 4 | **Chronicler at 73 %** after 3 battles is accepted; revisit in playtest. | game-designer | First expedition playtest |
| 5 | ~~**Travel healing gate**~~ **Resolved 2026-10-30**: Credits, Upkeep & Sinks rule 13 signs it off with three conditions. | Credits, Upkeep & Sinks (#18) | Resolved |
