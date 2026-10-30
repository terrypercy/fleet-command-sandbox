# Flagship Piloting

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on missing P5/P4/P1 framing, no flagship loss context for the Debrief, machine flagships, and the pause wording in AC-13; all four revised
> **Implements Pillar**: Pillar 3 (Hands on the Helm — the flagship is never abstracted; the player flies it directly while commanding the fleet); Pillar 5 (Vigor gates player fire); Pillar 4 (nothing fails silently); Pillar 1 (loss context for the Debrief)

## Summary

Flagship Piloting turns the player's live command into the flagship's intent
each tick: the hull turns toward the mouse aim (Q/E override and are the
keyboard path), W/S thrust and reverse and A/D strafe at reduced speeds, player
weapon groups fire the tick the button is held with no fleet stagger, and four
ability bits trigger boost and the hull's active ability. It is the only ship
that takes a live command, which is how the flagship is never abstracted while
the fleet is commanded (Pillar 3).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Input & Controls, Combat Space, Weapons & Damage, Vigor, Coherence & Links`

## Overview

Flagship Piloting is what the player's live command does to the one ship they
fly. Each tick, in P1, it turns the recorded command (move axis, aim, fire
bits, ability bits, move frame; Simulation Tick & Pause rule 6) into the
flagship's **intent**: a desired heading and a local thrust vector for Combat
Space, which guns fire, and which abilities trigger.

It is the only ship that takes a live command. Everything else in the fleet
answers to orders (Fleet Orders, Ship AI), which is how Pillar 3 holds: **the
flagship is never abstracted, and the fleet is commanded, not puppeted.**

At its heart are three choices: the hull **turns toward the mouse aim** (Q/E
override it, and are the keyboard path); W/S thrust and reverse and A/D strafe,
at reduced speeds; and the flagship's **player groups fire on the tick the
button is held**, without the fleet's fire stagger, so firing feels immediate.

## Player Fantasy

**The heavy hand on the helm, with the captain at the rail.** The player feels
the mass: they commit to a turn, the hull swings, and the guns come to bear one
by one. And they fly and fight at once, looking up to give an order without
letting go of the ship.

*Anchor moment:* a Vector Line closes on the Spiralward's blind rear. The player
swings the cursor; the hull begins its slow turn; they tap the pivot ability and
the turn snaps faster; the turret comes into arc on the tick the line enters it,
and the broadside lands.

**Pillars served:**
- **Pillar 3, *Hands on the Helm*:** live, immediate control of one ship; pause
  is always available; nothing pilots the flagship for the player.
- **Pillar 5, *Living Against Made*:** Vigor shapes when the flagship can fire
  and boost; player fire is never free of it (rule 7, ember behaviour).
- **Pillar 4, *Plan in the Open*:** arcs, cooldowns and Vigor state are always
  visible; nothing fails silently.
- **Pillar 1, *Every Defeat Is a Lead*:** a lost flagship reports how it was
  lost (rule 13), so the Debrief can name the blind side.

**This system must never make the player feel:** "the ship did something I
didn't tell it to, without showing me why", "my shot came late", or "I can't fly this with the keys I
have".

## Detailed Design

### Core Rules

**A. Movement**

1. **The command becomes an intent.** Each tick in P1, from the latest sample
   (Simulation Tick & Pause rule 6), Flagship Piloting produces
   `desired_h` and a **local thrust vector** `(fwd, lat)` in permille, which
   Combat Space turns into motion (Combat Space rule 5, amended to take a thrust
   vector).
2. **Thrust from the move axis.** With the move axis `(ax, ay)` in permille
   (Input & Controls D1):
   - `fwd = ay`, but reverse (ay < 0) is scaled to `REVERSE_PM` (400 ‰);
   - `lat = ax` scaled to `STRAFE_PM` (500 ‰);
   - **ship-relative** frame: the axis is used as it is;
   - **screen-relative** frame: the world axis is first rotated into the ship's
     frame by −h, then the same scaling applies, so screen-relative never skips
     the strafe and reverse penalties.
   A zero axis gives a zero target velocity: the ship brakes to a stop.
3. **Facing follows the mouse; Q/E override it.** In ship-relative mode the hull
   turns toward the aim (Formulas D1). Holding Q or E sets `desired_h = h ±
   16,384` (a quarter turn ahead), so it turns at full rate. On release, facing
   holds the current heading until the aim bearing moves `REENGAGE_H` (1,024
   heading units, about 5.6°) from where it was at release, so the ship never
   snaps back to the cursor. Q and E together cancel. In screen-relative mode
   the hull turns toward the aim (Input & Controls rule 16).
4. **Keyboard-only flight is complete**: Q/E turn, WASD thrust and strafe, and
   aim is the locked target (Input & Controls rule 17) or straight ahead.
5. **No autopilot.** With nothing pressed, the flagship brakes to a stop and
   holds its heading.

**B. Weapons**

6. **Weapon groups.** Each mount on the flagship instance has a `weapon_group`:
   PRIMARY, SECONDARY or AUTO (saved on the instance; set in Refit & Loadout).
   The default: the largest forward-covering mounts are PRIMARY, other
   forward-covering mounts SECONDARY, and mounts whose arc excludes the bow
   AUTO.
7. **Player groups fire when held.** A PRIMARY or SECONDARY mount fires when
   its cooldown is 0, its group's fire bit is held, the **aim bearing is inside
   the mount's arc**, and the Vigor hook passes (Vigor rule 5). The shot leaves
   along the turret's current angle; it needs no target and no range check (the
   projectile expires at its range). **Player groups are exempt from phase
   stagger** (Weapons & Damage rule 4): a held bit with cooldown 0 fires on that
   tick. If the aim is outside the arc, the mount does not fire (it protects
   Vigor and teaches facing). AUTO mounts follow the ordinary fire rules,
   stagger included, choosing targets as Ship AI does.
8. **Turrets slew toward the aim**, at the weapon's `slew_deg_s`, clamped to the
   mount's arc (Formulas D3).
9. **Target lock** is sampler and presentation state, not simulation state: T
   locks the nearest enemy (ties to the lower Runtime ID), Shift+T cycles the
   other way; when the locked ship is destroyed the lock clears, with no
   automatic re-lock, and aim-at-lock stays armed. No lead at MVP.

**C. Abilities**

10. **Four ability bits**, defined by the `ability` content kind (`cost_mv`,
    `duration_ticks`, `cooldown_ticks`, `effect`; at MVP an effect may only
    publish Combat Space rule 6a multipliers):
    - **bit 1, Boost**: forwards the request to Vigor (rule 10); toggle by
      default, hold or toggle per Input & Controls rule 9;
    - **bit 2, the hull's `active_ability`**: for the Spiralward, a placeholder
      "pivot": `t_step` × 2,000 ‰ for 120 ticks, cooldown 900 ticks;
    - **bits 3–4**: reserved for graft abilities post-MVP; pressing them does
      nothing.
    Flagship Piloting is a rule-6a publisher, applied after Vigor and Coherence.

**D. The flagship**

11. **One flagship per battle**, fixed in the battle header (`flagship_id`); it
    cannot be swapped mid-battle at MVP. At MVP it is always organic (Coherence
    & Links rule 17).
12. **Precedence** (Simulation Tick & Pause rule 6): the live command always
    governs movement, aim and player-group fire. Queued orders to the flagship
    cover only **retreat intent** (Combat Space rule 12) and the **AUTO group's
    focus target**.
13. **If the flagship is disabled** (hull 0; Battle Resolution rule 7) **or departs**: its intent goes to zero, the lock clears,
    and Flagship Piloting stops publishing (Tick already ignores the command).
    It reports **loss context** with the loss: the killing hit's bearing
    relative to the heading, and whether that bearing was inside any player-
    group arc, so the Debrief can name it ("struck from the uncovered rear").
    The battle continues; the fleet fights on under Fleet Orders (Battle
    Resolution rule 6).
    The battle's outcome is Battle Resolution's. The camera follows the flagship
    by default (Camera & Combat View #45).
14. **The ghost path** uses the flagship's last applied intent (Combat Space
    rule 8).

### States and Transitions

| State | Entered when | Behaviour | Leaves to |
|---|---|---|---|
| Piloting | battle running, flagship alive | Command → intent each tick | Cursor-held, Sim-held, No flagship |
| Cursor-held | command cursor active (Input rule 15) | Aim frozen, player fire off, movement live | Piloting (released) |
| Sim-held | any hold | Command discarded (Input rule 11); intent kept for the ghost | Piloting (hold clears) |
| No flagship | flagship destroyed or departed | No intent, no lock, nothing recorded | — |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | Tick → #15 | The sampled command in P1; precedence; recording |
| Input & Controls (#6) | #6 → #15 | Bindings, move frame, command cursor, keyboard aim; **facing source decided here (rule 3)** |
| Combat Space (#11) | #15 → #11 | `desired_h` and local thrust vector (Combat Space rule 5 amended); 6a multipliers; ghost path |
| Weapons & Damage (#12) | #15 → #12 | Player-group fire rule (rule 7; adds a flagship branch to Weapons rule 3 and an exemption to rule 4) |
| Vigor (#13) | both | Boost and shot grants; ember behaviour |
| Hulls & Ship Definition (#10) | #10 → #15 | Stats, mounts, `active_ability`; instance `weapon_group` |
| Refit & Loadout | → #15 | Group assignment |
| Fleet Orders (#19), Ship AI (#20) | both | Retreat intent and AUTO focus; AUTO targeting |
| Camera & Combat View (#45) | #15 → #45 | Follow target |
| Battle Resolution, After-Action Debrief | #15 → them | Flagship loss + loss context (killing bearing, inside/outside player arcs); outcome owned by Battle Resolution |

## Formulas

`pm(x, p) = sign(x) × ((|x| × p + 500) div 1,000)` (sign-preserving permille).

### D1. Heading from aim

`desired_h = atan2_tab(aim_y, aim_x)`; if both `|aim_x|` and `|aim_y|` are below
`AIM_DEADZONE_Q` (4 aim quanta = 0.25 u), `desired_h = h`.

### D2. Thrust into a target velocity

`wx = (fwd × cos h + lat × sin h) >> 16`; `wy = (fwd × sin h − lat × cos h) >> 16`
(table trig, Q16); target velocity = `w × v_cap div 1,000`, truncated toward 0.

| Variable | Range | Description |
|---|---|---|
| fwd, lat | −1,000 – 1,000 (length ≤ 1,000) | Local thrust, permille |
| h | 0 – 65,535 | Heading |
| v_cap | Combat Space D1 | Speed cap |

### D3. Turret slew

`s_step = slew_deg_s × 65,536 div (360 × TR)`; `half = arc × 65,536 div 720`;
turret target = `clamp(bearing − h − facing, −half, +half)`, moved at most
`s_step` per tick.

### Worked example (Spiralward, placeholder stats: speed 90, accel 30, turn 30, 60 Hz)

- Motion constants (Combat Space D1): `v_cap` = 5,898,240 div 60 = **98,304**;
  `a_step` = 1,966,080 div 3,600 = **546**; `t_step` = 1,966,080 div 21,600 = **91**.
- **Thrust**: facing east (h = 0), W + D gives axis (707, 707); lat = pm(707, 500)
  = 354; w = (707, −354); target velocity (69,500, −34,799) ≈ 71 u/s east-south-
  east, reached from rest in ceil(77,724 ÷ 546) = **143 ticks**.
- **Reverse**: S alone gives fwd = −400; target −39,321 along the heading.
- **Turn**: aim at (−200 u, +200 u) → desired 24,576 (135°), reached after
  ceil(24,576 ÷ 91) = **271 ticks** (4.5 s).
- **Guns**: an M turret with arc 120° has half = **10,922**; with `slew_deg_s` 60,
  `s_step` = **182**. The aim enters its arc once h ≥ 24,576 − 10,922 = 13,654,
  on tick ceil(13,654 ÷ 91) = **151**. That gap is the blind rear, in numbers.

## Edge Cases

- **If the aim is exactly on the ship**: facing holds (D1 dead zone).
- **If the move axis is zero**: the ship brakes to a stop.
- **If the player switches move frame mid-battle**: it applies from the next
  tick; velocity is unchanged, so there is no jump.
- **If the command cursor is held**: aim is frozen as a relative offset, so the
  world bearing stays constant; player fire is off; movement stays live.
- **If Vigor is EMPTY**: player shots fire as ember shots, boost is an ember
  boost, movement is at 900 ‰ (Vigor rule 9); a flow-cap refusal retries next
  tick.
- **If Q and E are both held**: they cancel; facing holds.
- **If the locked target leaves weapon range**: the lock is kept.
- **If the aim is outside every player-group arc**: nothing fires; the HUD shows
  the arcs.
- **If the flagship retreats**: it departs through its own retreat zone like any
  ship (Combat Space rule 12); the outcome is Battle Resolution's.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | Command, P1, precedence |
| Input & Controls (#6) | Hard | Bindings, frame, cursor |
| Combat Space (#11) | Hard | Intent; amended rule 5 |
| Weapons & Damage (#12) | Hard | Player-group fire branch |
| Vigor (#13) | Hard | Grants, boost |
| Coherence & Links (#14) | Soft | Organic flagship at MVP |
| Hulls (#10), Refit & Loadout, #19, #20, #45, Battle Resolution | Hard (reverse/soft) | Stats, groups, orders, camera, outcome |

Bidirectional check: Tick, Input, Combat Space, Weapons and Vigor name Flagship
Piloting.

## Tuning Knobs

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `STRAFE_PM` | 500 | 300 – 800 | Sideways speed |
| `REVERSE_PM` | 400 | 250 – 700 | Backing speed |
| `REENGAGE_H` | 1,024 | 364 – 4,096 | Mouse facing after Q/E release |
| `AIM_DEADZONE_Q` | 4 | 1 – 32 | Aim near the hull |
| Pivot multiplier / duration / cooldown | 2,000 ‰ / 120 / 900 ticks | 1,200 – 2,500 / 60 – 300 / 300 – 1,800 | Spiralward ability |

In `assets/data/piloting/` and `assets/data/abilities/`.

## Visual/Audio Requirements

- Muzzle flash and thrust plume on input (presentation-side prediction at 30 Hz,
  Simulation Tick & Pause).
- Arc wedges for player groups while a fire button is held; out-of-arc mounts
  shown dim, by shape not colour.
- The pivot ability has a readable swing cue.

## Game Feel

- **Heavy but responsive**: turns take seconds, but the first visible response
  (plume, flash) is within the latency target.
- **Firing is immediate**: player groups never wait for stagger.

## UI Requirements

- HUD: player-group arcs and cooldowns, ability cooldowns, lock marker, move
  frame indicator; a mark when AUTO-group mounts fire on their own, and a mark
  for the EMPTY Vigor slowdown.
- Refit screen: weapon-group assignment per mount (Refit & Loadout).
- 📌 **UX Flag — Flagship Piloting**: include arcs, group readouts and ability
  cooldowns in the Combat HUD UX spec before epics.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Command, sampling, precedence, latency | `design/gdd/simulation-tick-and-pause.md` | Rule 6; Game Feel latency | Rule dependency |
| Bindings, frame, cursor, keyboard aim | `design/gdd/input-and-controls.md` | Rules 3, 9, 11, 15–17; D1 | Rule dependency |
| Motion, thrust vector, ghost | `design/gdd/combat-space.md` | Rules 5 (amended), 6a, 8, 12; D1 | Rule dependency |
| Fire rules, stagger | `design/gdd/weapons-and-damage.md` | Rules 3 (flagship branch), 4 (exemption), 9 | Rule dependency |
| Boost, ember | `design/gdd/vigor.md` | Rules 5, 9, 10 | Rule dependency |

## Acceptance Criteria

- **AC-01 (Logic; D2)**: W alone at h = 0 gives target velocity (98,304, 0); W + D gives (69,500, −34,799); S alone gives (−39,321, 0) for the Spiralward placeholder.
- **AC-02 (Logic; rule 2)**: in screen-relative mode facing north, "up" gives the same target as ship-relative W, and "down" is capped at `REVERSE_PM`.
- **AC-03 (Logic; D1, rule 3)**: the 135° turn completes on tick 271; an aim offset of (0, 0) leaves h unchanged; after Q/E is released, h holds until the aim bearing moves 1,024.
- **AC-04 (Logic; rule 7, D3)**: the example M turret first fires on tick 151, never earlier; with the aim outside its arc it does not fire.
- **AC-05 (Logic; rule 7)**: a PRIMARY shot with cooldown 0 fires on the first tick that reads the held bit (no stagger); an AUTO mount on the flagship staggers.
- **AC-06 (Logic; Input rule 15)**: while the command cursor is held, no player-group shot fires and `desired_h` stays constant while movement still changes.
- **AC-07 (Logic; rule 13)**: after the flagship is destroyed there is no intent, no lock and no recorded command.
- **AC-08 (Logic; rule 10)**: bit 1 forwards boost to Vigor; bit 2 triggers the hull's ability with its cooldown; bits 3 – 4 do nothing at MVP.
- **AC-09 (Logic; determinism)**: replaying a recorded battle in both move frames reproduces positions bit for bit.
- **AC-10 (Logic; rule 12)**: a queued order to the flagship affects only retreat intent and the AUTO group's focus; it never changes movement, aim or player-group fire.
- **AC-11 (Logic; rule 4)**: a full battle flown with Q/E, WASD, T and V only (no mouse) fires player groups and completes.
- **AC-12 (Performance; latency)**: an input event shows its effect (muzzle flash or plume) within ≤ 83 ms worst case at 60 Hz; in the simulation, a changed command is applied in the first P1 after its sample.
- **AC-13 (Playtest; Game Feel)**: 4 of 5 testers fly the Spiralward and keep its blind rear away from a Vector Line for 60 s without pausing, and describe the controls as "heavy but responsive", never "laggy"; and 4 of 5 describe pausing to give an order as natural, not as a penalty.
- **AC-14 (Logic; rule 13)**: a flagship destroyed by a hit from 180° off its heading with no player-group arc covering it reports loss context `(bearing 32,768, covered = false)`, and the record carries it for the Debrief.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Spiralward stats and its `active_ability`** are placeholders. | game-designer, systems-designer | Balance pass |
| 2 | **Combat Space rule 5 amendment** (thrust vector) must be confirmed in its review. | Combat Space owner | Next review |
| 3 | **Aim lead** on locked targets — not at MVP. | game-designer | Post-MVP |
| 4 | **Flagship swap mid-battle** (transfer command to another ship). | game-designer | Post-MVP |
| 5 | **A Q/E-only facing setting** (mouse aims turrets only) as an option for Starsector veterans. | game-designer | Vertical Slice |
| 6 | **Machine flagship piloting** (post-MVP): how Coherence and links change player fire and abilities, resolved inside the asymmetry, never the organic model reskinned. | game-designer | Before machine-flagship content |
