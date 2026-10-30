# Weapons & Damage

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on the flux test (membrane now erodes the ceiling, no toggle/overload; blocking on #13), unrecorded shield and ward events, the membrane visual, missing expected-damage readout, and the stern claim; all five revised
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — every point of damage has a recorded source and type the Debrief can name); Pillar 4 (Plan in the Open — odds and ranges are shown, computed, never hidden); Pillar 5 (Living Against Made)

## Summary

Weapons & Damage defines weapons as integer data and resolves every shot: one
seeded spread draw per shot, geometric projectile sweeps (no hidden hit rolls),
asymmetric shields (a Vigor-paid organic membrane, a link-fed machine ward), a
ratio armour pool that ablates under fire and never makes a ship immune, and
four damage types that each counter a different defence. Every point of damage
is recorded with its source, slot and type, so the Debrief can name the cause
and the counter (Pillars 1, 4 and 5).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Deterministic RNG & Seed Streams, Combat Event Bus & Battle Record, Combat Space, Hulls & Ship Definition`

## Overview

Weapons & Damage defines what a weapon is as data, how it fires, how its shots
travel and hit, and how damage passes through shields and armour into hull. It
runs in P4 (fire and projectiles) and P5 (damage) of every battle tick, in
ascending Runtime ID and slot order, with integer maths only.

Its job for the player is to make **every hit carry a signature**. Each of four
damage types does something different to living ships and to machines, so the
player learns which tool opens which defence, and the Debrief can name it:
*kinetic* grinds organic regrowth, *energy* burns machine wards, *severing*
strains relay links, *rupture* strikes Vigor cores. Shields are asymmetric, as
Pillar 5 requires: an organic **membrane** costs Vigor to hold, a machine
**ward** refills only while the ship is linked.

Hits are decided by **geometry**, not dice: a weapon draws one spread offset per
shot from its keyed stream, then the projectile flies and either touches a hull
or doesn't. The hit chance the player sees is the computed spread cone, never a
roll.

## Player Fantasy

**Every hit has a signature.** The player reads a fight by what each weapon is
doing: thorns grinding a coral hull's regrowth, a lance burning down a ward, a
filament snapping a relay link with a spark. A loss is never "they did more
damage"; it is "my energy never reached their wards because the relay kept
refilling them", and the Debrief says so. On the flagship, *where* you hit
matters too: a core, a relay, and at MVP the blind stern through weapon arcs
(a hull with no guns covering its stern; Hulls `blind_rear`).

*Anchor moment:* the player's Glowlance burns a Vector Line's ward to nothing,
but it refills. Paused, they see the Lattice Relay behind it. They swap targets
to the relay with a Rootcutter; the link snaps, the ward stops refilling, and
the Vector Line's fed guns fall silent.

**Pillars served:**
- **Pillar 1:** every point of damage has a source, type and slot in the record
  (Battle Record rule 9), so causes and counters are nameable.
- **Pillar 4:** odds and ranges are computed and shown, never hidden or drawn.
- **Pillar 5:** membrane and ward, Vigor-paid and link-fed, are different
  mechanisms, not reskins.

**This system must never make the player feel:** "armour made it immune", "I
lost to a dice roll", or "I can't tell what that weapon is doing".

## Detailed Design

### Core Rules

**A. The weapon definition**

1. **A weapon is a `weapon` content definition**, integers only:

   | Field | Range | Notes |
   |---|---|---|
   | `family` | organic: `spine`, `photic`, `filament`; machine: `driver`, `lance`, `needle` | Side-specific (never reskinned); matches a mount's `accepts` (Hulls rule 4) |
   | `size` | S, M, L | Must fit the mount |
   | `delivery` | projectile, beam, instant | |
   | `dmg` | 1 – 5,000 | Per shot, or per pulse for beams |
   | `dmg_type` | KINETIC, ENERGY, SEVERING, RUPTURE | Rule 6 |
   | `range_u` | 100 – 1,200 | `FIELD_R` ≥ 2.5 × the longest range (Combat Space rule 10) |
   | `speed_u_s` | 100 – 2,000 | Projectiles only |
   | `proj_radius_u` | 1 – 16 | Projectiles only |
   | `refire_ticks` | 1 – 600 | |
   | `burst`, `burst_gap_ticks` | 1 – 8; 0 – 30 | |
   | `spread_h` | 0 – 4,096 heading units (0 – 22.5°) | Rule 9 |
   | `slew_deg_s` | 0 – 360 | Turret turn rate within the mount's arc |
   | `beam_pulse_ticks` | 1 – 30 | Beams only |
   | `sever_permille`, `core_permille` | 0 – 1,000 | Type effects (rule 6) |
   | `vigor_per_shot` | 0 – 500 | Organic only: a draw Vigor (#13) grants or refuses |
   | `feed` | 0/1 | Machine only: fires only from a `network_fed` mount while linked (Hulls rule 10) |

2. **Size bands** (from `systems-designer`'s time-to-kill derivation; starting
   values for balance): **S** 15 – 30 damage, refire 60 – 90 ticks (anti-light);
   **M** 80 – 160 damage, refire 180 – 240 ticks; **L** 300 – 600 damage, refire
   300 – 480 ticks (a broadside worth timing during a pause).
3. **Fire conditions** (P4, ships in ascending Runtime ID, slots in ascending
   `slot_id`): cooldown is 0, the target is within range and the mount's arc,
   and the cost hook passes (the fed mount is linked, or Vigor answers). Vigor
   (#13, rule 5) answers **full** (normal shot), **ember** (the pool is empty:
   an ember shot at Vigor's ember damage and refire, burning the ceiling) or
   **refused** (only the per-second flow cap: no fire, no draw, retry next
   tick). A membrane request carries the hit's contact point. **Flagship
   branch:** the flagship's PRIMARY and SECONDARY groups fire on their held
   bit instead, with no target or range check, only when the aim bearing is
   inside the mount's arc (Flagship Piloting rule 7). A link cut mid-burst cancels the rest of the burst.
4. **Phase stagger.** A weapon's first shot in a battle waits
   `(ship_id × 7 + slot_index) mod refire_ticks` ticks, so a fleet never fires
   every gun on the same tick. This costs no draw. The flagship's player
   groups are exempt (Flagship Piloting rule 7).
5. **Projectiles** are battle-local entities with a sequence number from
   `next_proj_seq` (Runtime ID Service: projectiles use a battle-local sequence,
   not Runtime IDs). Lifetime is `ceil(range_u × TICK_RATE ÷ speed_u_s)` ticks.
   They cannot be targeted at MVP. `MAX_LIVE_PROJECTILES` is 1,000; at the cap
   a weapon holds its cooldown and the event is logged. **No friendly fire** at
   MVP.

**B. Damage types and layers**

6. **Four damage types**, each a bit in the Battle Record's `dmg_type_mask`,
   with a permille multiplier per layer (membrane / ward / armour / hull) and an
   effect:

   | Type | Membrane | Ward | Armour | Hull | Effect | Counters |
   |---|---|---|---|---|---|---|
   | KINETIC | 1000 | 500 | 1000 | 1000 | Doubles the hit ship's armour-regrowth delay | `regrowing` |
   | ENERGY | 750 | 1500 | 500 | 1000 | — | machine wards |
   | SEVERING | 1000 | 1000 | 250 | 250 | Sends link strain `dmg × sever_permille ÷ 1000` to Coherence & Links (#14) | `relay`, `network_fed` |
   | RUPTURE | 500 | 750 | 1000 | 1000 | A hit inside a Vigor core's region passes `core_permille` of its hull damage to Vigor (#13) as core damage | organic cores |

   Membranes resist rupture, wards resist kinetic, regrowth punishes slow
   damage: no type dominates.
7. **Shields are asymmetric** (Pillar 5):
   - **Organic membrane**: absorbs `membrane_permille` of each hit (a new
     `organic` field in Hulls), **scaled by the ship's current Vigor** (a spent
     ship's membrane is thin). What it absorbs is taken from the **Vigor
     ceiling**, not from the spendable pool: the membrane trades long-term
     endurance, which only care or port rest restores, for surviving this hit.
     It has **no toggle and no overload state**. At the ceiling floor it absorbs
     nothing (the flow-cap refusal does not apply to the membrane). This keeps
     shots (spending) and the membrane (erosion) on different parts of Vigor,
     so the pair never reproduces a single flux-and-overload pool (Pillar 5).
     The maths are Vigor's (Vigor D3; confirmed 2026-10-30).
   - **Machine ward**: a pool of `ward_points` (new `machine` field in Hulls)
     that refills at `ward_refill` per second **only while the ship is linked**;
     cut, it stops refilling and decays (rate owned by #14). Cutting a link
     visibly drops a barrier.
8. **Armour is a single ablative pool** per ship, with a ratio formula and a
   floor (Formulas D2): big shots punch through, small shots are mostly eaten,
   and **no ship is ever immune** (hull damage ≥ 1 for any shot that reaches
   armour). Each hit also ablates armour. Organic armour regrows after
   `OUT_OF_FIRE_S` without damage (Hulls rule 8; Formulas D4); machine armour
   never regrows.

**C. Hits**

9. **Geometry decides hits; spread is drawn.** At fire time the weapon draws one
   `int_range(−spread_h, spread_h)` heading offset from
   `base:combat.hit#<ship_id>/<slot>` (tick-indexed, Deterministic RNG & Seed
   Streams), always, even when `spread_h` is 0. Projectiles have no impact roll:
   each tick a projectile sweeps from its old to its new position with
   `query_segment` (Combat Space rule 15, padded by `proj_radius_u`, enemy mask)
   and hits the first contact (lowest parameter, ties to the lower Runtime ID).
   Beams and instant weapons sweep their full segment at fire time and hit the
   first ship they touch. Sweeping makes tunnelling impossible. `chance_permille`
   is not used for hits at MVP.
10. **The hit chance shown is computed, never drawn** (Formulas D5): the share of
    the spread cone the target's hull covers at its current distance, with lead
    from its current velocity, labelled "if nothing changes" (Combat Space rule
    8).

**D. Resolution (P5)**

11. **Order.** Projectile hits in ascending sequence number, then beam and
    instant hits by (ship Runtime ID, slot). For each hit:
    1. shield layer (rule 7);
    2. armour layer (rule 8, D2);
    3. hull;
    4. hooks: core damage (RUPTURE, contact point inside a glow anchor's radius),
       link strain (SEVERING), the regrowth delay reset (KINETIC doubles it);
    5. emit `Hit` (bus) and update the `DamageBucket` (Battle Record rule 9).
12. **Destruction.** A ship whose hull reaches 0 is flagged for P7. Its killer is
    the hit that first crossed 0. Further hits on it that tick are recorded as
    overkill with no kill credit.
13. **New events** (raising `EVENT_SCHEMA_VERSION`, Battle Record rule 9), all
    record-tier: `CoreStruck(ship, core_id, amount)`, `LinkStrain(target,
    amount, actor)`, `ShieldAbsorbed(ship, layer, amount, dmg_type)` (layer:
    membrane or ward, aggregated per `DAMAGE_WINDOW` like `DamageBucket`) and
    `WardRefilled(ship, amount, relay_id)` (aggregated per window). Each
    `DamageBucket` also gains an `absorbed` total. These let the Debrief name a
    loss such as "your energy never reached their wards because the relay kept
    refilling them". To be confirmed by Vigor (#13) and Coherence & Links (#14).
14. **Budget.** P4 and P5 together, including projectile sweeps, take ≤
    `WEAPONS_SHARE_MS` (1.2 ms, 30 % of the 4.0 ms per-tick budget `L`) at the
    95th percentile on Simulation Tick & Pause's D10 fixture. RNG draw time counts
    against RNG's own share.

**E. The MVP weapons** (names are placeholders for the narrative team)

| # | Name | Side | Family / size / delivery | Type | Identity |
|---|---|---|---|---|---|
| 1 | Thornspitter | Organic | spine S projectile | KINETIC | Fast, wide thorns that grind armour and stall regrowth |
| 2 | Seedmortar | Organic | spine L projectile | KINETIC | Slow, dodgeable, punches through plate |
| 3 | Glowlance | Organic | photic M beam | ENERGY | Burns wards; costs a lot of Vigor |
| 4 | Rootcutter | Organic | filament M instant | SEVERING | Short-range link cutter that barely scratches hulls |
| 5 | Mass Driver | Machine | driver M projectile, unfed | KINETIC | Accurate baseline that still fires when cut |
| 6 | Lattice Lance | Machine | lance M beam, fed | ENERGY | Deadly while linked, silent when cut |
| 7 | Coring Needle | Machine | needle S projectile | RUPTURE | Hunts Vigor cores; glances off membranes |
| 8 | Keystone Breaker | Machine | driver L projectile, fed | RUPTURE | The capital gun that holds a stronghold together |

### States and Transitions

| Weapon state | Entered when | Leaves to |
|---|---|---|
| Ready | cooldown 0 | Firing (conditions met), Starved (cost hook fails), Silent (fed and cut) |
| Firing | shot or burst begins | Cooling |
| Cooling | after the last shot of a burst | Ready (after `refire_ticks`) |
| Starved | Vigor refused | Ready (next tick, retry) |
| Silent | fed weapon, ship cut | Ready (link restored) |

| Projectile state | Entered | Leaves |
|---|---|---|
| Flying | spawned | Hit (contact), Expired (lifetime ends) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Deterministic RNG & Seed Streams (#2) | #2 → #12 | One `int_range` per shot on `base:combat.hit#<ship_id>/<slot>` |
| Combat Event Bus & Battle Record (#9) | #12 → #9 | `Hit`, `DamageBucket`, `CoreStruck`, `LinkStrain`; killer and slot |
| Hulls & Ship Definition (#10) | both | Mounts, armour, regrowth, glow anchors; **new fields** `membrane_permille`, `ward_points`, `ward_refill` |
| Combat Space (#11) | both | `query_segment` sweeps; projectiles inserted into the grid; ranges constrain `FIELD_R` |
| Vigor (#13) | both | `vigor_per_shot` and membrane draws granted or refused; core damage |
| Coherence & Links (#14) | both | Fed weapons and wards depend on link state; link strain; ward decay when cut |
| Flagship Piloting (#15), Ship AI (#20) | → #12 | Target and fire intent per slot; Ship AI owns AI ships' aim, including lead (Ship AI rule 6) |
| Gameplay Settings & Modifiers (#7) | #7 → #12 | Stronghold strength scales stats by `modifier_compose` (rule 10 of #7) |
| Combat HUD (#46) | #12 → #46 | Ranges, arcs, shown hit chance, cooldowns |
| Machine Nodes & Strongholds (#23), Debrief | #12 → them | Type-to-counter mapping |

## Formulas

### D1. Layer multiplier

`d_layer = (d × m_type,layer + 500) div 1000`

### D2. Armour

`d_a = D1(d_after_shield, armour)`

`hull_raw = max( d_a × d_a div (d_a + armour_cur), (d_a × FLOOR_PM + 999) div 1000, 1 )`

`hull_dmg = max(1, D1(hull_raw, hull))`

`armour_cur −= min(armour_cur, (d_a × ABLATE_PM + 500) div 1000)`

| Variable | Type | Range | Description |
|---|---|---|---|
| d_a | int | 1 – 5,000 | Damage reaching armour after type multiplier |
| armour_cur | int | 0 – 2,000 | Current armour pool |
| FLOOR_PM | int | 50 – 300; **150** | Minimum share of damage that reaches hull |
| ABLATE_PM | int | 100 – 500; **250** | Armour removed per point of damage |
| hull_dmg | int | 1 – d_a | Hull damage |

**Output Range:** 1 to `d_a`; never 0, so no ship is immune. `d_a²` ≤ 2.5 × 10⁷,
safe in 64-bit integers. **Examples** (`FLOOR_PM` 150): 100 vs armour 300 → 25;
400 vs 300 → 228; 20 vs 2,000 → 3 (the floor); 1 vs 2,000 → 1. A Mass Driver shot
(KINETIC, 120) against a machine with 300 armour and an empty ward: ward layer
converts back to 120 (D3), hull_raw = max(14,400 div 420, 18, 1) = **34**,
armour 300 → **270**.

### D3. Ward overflow

`d_w = D1(d, ward)`; `absorbed = min(ward_cur, d_w)`; `ward_cur −= absorbed`;
`d_after_shield = (d_w − absorbed) × 1000 div m_type,ward`

**Example:** ENERGY 120 against a ward of 100: d_w = 180, absorbed 100, ward 0,
overflow (80 × 1000) div 1500 = 53 raw damage continues to armour.

### D4. Organic armour regrowth

While `tick − last_hit_tick ≥ OUT_OF_FIRE_TICKS` (`OUT_OF_FIRE_S` × `TICK_RATE`;
doubled after a KINETIC hit) and `armour_cur < armour_max`:
`acc += armour_max × r`; `armour_cur += acc div K`; `acc = acc mod K`, with
`K = 60,000 × TICK_RATE` and `r` = `armour_regrow_permille_per_min`. Any hit sets
`last_hit_tick` and resets `acc` to 0. At `armour_max`, `acc` = 0.

**Example:** `armour_max` 300, r = 30, 60 Hz: 9,000 per tick; over 3,600 ticks,
32,400,000 div 3,600,000 = exactly **9** armour per minute. At 30 Hz (K =
1,800,000, 1,800 ticks) also exactly 9.

### D5. Shown hit chance

`hw = atan_tab(r_target × 65,536 div dist)` (heading units)

`hit_permille = min(1000, (2 × hw + 1) × 1000 div (2 × spread_h + 1))`

**Example:** Thornspitter (`spread_h` 1,092 = 6°) at a Lattice Relay (radius 12 u)
500 u away: hw = 250; (501 × 1,000) div 2,185 = **229 ‰**.

### D6. Sustained DPS and time to kill

`dps = dmg × burst × TICK_RATE ÷ refire_ticks`; time to kill is the number of
hits until the sum of D2 hull damage reaches hull points, times
`refire_ticks ÷ TICK_RATE` (a test helper iterates it, because armour ablates).
**Targets:** a line ship (1,500 – 4,000 hull) dies to 2 line ships' focused fire
in **20 – 40 s**; a capital dies to **4** line ships in **60 – 120 s**.

## Edge Cases

- **If a hit lands on a ship already at 0 this tick**: recorded as overkill, no
  kill credit (rule 12).
- **If the shooter is retired before its projectile lands**: the projectile
  keeps flying; `Hit` names the shooter's ID (Runtime ID Service).
- **If a projectile leaves the field**: it expires at its lifetime.
- **If Vigor refuses a shot's cost**: no fire, no draw, retry next tick; because
  draws are tick-indexed, retrying never shifts another weapon's sequence.
- **If a fed weapon's ship is cut mid-burst**: the rest of the burst is
  cancelled; the weapon goes Silent.
- **If armour is 0**: D2 gives `hull_raw = d_a`.
- **If a membrane absorb request is refused**: the full hit continues to armour.
- **If `MAX_LIVE_PROJECTILES` is reached**: weapons hold cooldown; logged.
- **If two projectiles hit the same ship on the same tick**: they resolve in
  sequence order; the first to cross 0 is the killer.
- **If a player reloads a suspend and fires one tick later**: the draw comes
  from that later tick's position; no value is "burned" (RNG tick-indexing).
- **Degenerate strategies**: kiting is bounded by the edge clamp; severing spam
  by link recovery (#14); reload-scumming by tick-indexing; hunting a blind
  stern (no guns covering it) is intended mastery.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Deterministic RNG & Seed Streams (#2) | Hard | Keyed spread draws |
| Combat Event Bus & Battle Record (#9) | Hard | Damage events |
| Hulls & Ship Definition (#10) | Hard | Mounts, armour, shields fields |
| Combat Space (#11) | Hard | Sweeps, grid |
| Vigor (#13), Coherence & Links (#14) | Hard (both ways) | Cost hooks, shields, core damage, link strain |
| #15, #20, #23, #46, Debrief | Hard (reverse) | Intents, counters, display |

Bidirectional check: RNG, Battle Record, Hulls and Combat Space already name
Weapons & Damage.

## Tuning Knobs

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `FLOOR_PM` | 150 | 50 – 300 | Armour floor (no immunity) |
| `ABLATE_PM` | 250 | 100 – 500 | How fast focused fire strips armour |
| `OUT_OF_FIRE_S` | 5 s | 2 – 10 | Regrowth delay |
| Kinetic regrowth suppression | ×2 | ×1 – ×4 | KINETIC's counter strength |
| Type matrix entries | table | 250 – 2,000 | Counter strengths |
| Size bands | rule 2 | ±50 % | Time to kill |
| `MAX_LIVE_PROJECTILES` | 1,000 | 500 – 2,000 | Engineering cap |
| `WEAPONS_SHARE_MS` | 1.2 ms | 1.0 – 1.5 | Frame budget share |
| Per-weapon stats | data | rule 1 ranges | Identity and balance |

All in `assets/data/weapons/`.

## Visual/Audio Requirements

- Each damage type has a distinct impact read **by shape and motion, not colour
  alone**: kinetic chips, energy burn, severing spark on the link line, rupture
  pulse at a core.
- The reserved **white-hot damage flash** (concept) reads as damage on both
  sides.
- Membrane absorption shows as a **ripple across the hull skin** (shape and
  motion), followed by a visible dip in the core's pulse. A core never
  brightens when Vigor is spent (Vigor is core brightness). A ward shows as a
  geometric barrier that visibly drops when cut.
- Fed weapons visibly go dark when Silent.

## Game Feel

- **Broadsides are worth timing**: L weapons' slow refire makes a pause-and-fire
  decision feel weighty.
- **Shots feel honest**: what the player sees hit is what hit; no hidden rolls.

## UI Requirements

- Per weapon on the HUD: range ring, arc, cooldown, state (Ready / Starved /
  Silent), and, on the hovered or locked target, the shown hit chance **and the
  expected hull damage per hit** (computed from D1–D3 with no draw), both
  labelled "if nothing changes".
- The Dossier and Debrief show the type table as each type's counters ("good
  against wards"), never as raw multipliers.
- Hull and weapon cards show damage type icons with the counter they serve.
- 📌 **UX Flag — Weapons & Damage**: include weapon readouts and type icons in
  the Combat HUD UX spec before epics.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Keyed hit stream, tick-indexing | `design/gdd/deterministic-rng-and-seed-streams.md` | Core Rules 3–7; D8 (revised here: one `int_range` per shot) | Rule dependency |
| Damage events, type mask | `design/gdd/combat-event-bus-and-battle-record.md` | Rules 9, 14 | Data dependency |
| Mounts, armour, regrowth, cores | `design/gdd/hulls-and-ship-definition.md` | Rules 1, 4, 7–10 (new shield fields) | Data dependency |
| Sweeps, grid, ghost label | `design/gdd/combat-space.md` | Rules 8, 10, 14–15 | Rule dependency |
| Composition rounding | `design/gdd/gameplay-settings-and-modifiers.md` | D2 | Formula dependency |

## Acceptance Criteria

- **AC-01 (Logic; D2)**: with `FLOOR_PM` 150, damage 100 / 400 / 20 / 1 against armour 300 / 300 / 2,000 / 2,000 gives hull damage 25 / 228 / 3 / 1.
- **AC-02 (Logic; D2)**: a 120-damage armour hit with `ABLATE_PM` 250 takes armour 300 → 270; armour never goes below 0.
- **AC-03 (Logic; rule 8)**: a content scan shows every weapon does at least 1 hull damage against 2,000 armour.
- **AC-04 (Logic; D1, D3)**: a golden table of every type × layer passes, including ENERGY 120 against a 100-point ward leaving 53 overflow.
- **AC-05 (Logic; D4)**: 300 armour at r = 30, out of fire, gains exactly 9 over 3,600 ticks at 60 Hz and over 1,800 ticks at 30 Hz; after a hit at tick t, regrowth first applies at t + 300 (t + 600 after a KINETIC hit), not before.
- **AC-06 (Logic; rule 9)**: every shot makes exactly one `int_range` draw, including at `spread_h` 0; the hit-chance overlay makes zero draws.
- **AC-07 (Logic; rule 9)**: adding a weapon to ship A leaves ship B's spread sequence unchanged.
- **AC-08 (Logic; rule 9)**: a projectile at 2,000 u/s never passes through a 12 u light hull without a hit.
- **AC-09 (Logic; D5)**: the worked case shows 229 ‰; over 10,000 headless shots the measured hit rate is within ±30 ‰.
- **AC-10 (Logic; rules 3, 7)**: a fed weapon and a ward stop within 1 tick of `LinkState → SNAPPED`; a refused Vigor cost gives no fire and no draw.
- **AC-11 (Logic; rule 11)**: a RUPTURE hit whose contact point is inside a glow anchor's radius emits `CoreStruck` with that `core_id`; a SEVERING hit emits `LinkStrain`.
- **AC-12 (Logic; Battle Record)**: every `Hit` sets its type's bit in the bucket's `dmg_type_mask`, and the record resolves slot → weapon; membrane and ward absorption appear as `ShieldAbsorbed` and in the bucket's `absorbed` total; ward refills appear as `WardRefilled` with the relay.
- **AC-18 (Review; rule 7, Pillar 5)**: Vigor (#13)'s review confirms the membrane and `vigor_per_shot` contract does not reproduce a flux-and-overload loop; a Starsector-literate playtester cannot describe Vigor as "flux with a different name".
- **AC-19 (UI)**: the expected-damage readout for a locked target equals D1–D3 computed on the current state and makes zero draws.
- **AC-20 (Playtest)**: AC-17 passes on a scripted ward-refill loss specifically (players name SEVERING the relay as the counter).
- **AC-13 (Logic; rule 5)**: projectile sequence numbers are contiguous from 1 in a battle, and a suspend reload continues them.
- **AC-14 (Logic; rule 4)**: with phase stagger, 40 ships × 3 mounts never fire more than twice the mean shots in any tick over 3,600 ticks.
- **AC-15 (Simulation; D6)**: over 100 seeded duels of reference loadouts, 2 line ships kill 1 line ship in a median of 20 – 40 s, and 4 line ships kill a capital in 60 – 120 s.
- **AC-16 (Performance; rule 14)**: P4 + P5 at the D10 fixture plus a volley scene take ≤ 1.2 ms at the 95th percentile.
- **AC-17 (Playtest)**: after a scripted loss, 4 of 5 players name the counter damage type; the white-hot flash reads as damage on both sides.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Budget split** — with Combat Space 1.2 ms, RNG 0.6 ms and Weapons 1.2 ms, about 1.0 ms of `L` remains for Ship AI, Vigor, Coherence and the record. | technical-director, performance-analyst | Tick/determinism ADR spike |
| 2 | ~~**Blocking: Vigor draw and membrane maths**~~ **Resolved 2026-10-30** by Vigor rules 5–7 and D3 (grant answers full / ember / refused; membrane erodes the ceiling from the nearest core, scaled by P ÷ C). | Vigor (#13) | Resolved |
| 3 | **Ward decay and link strain maths** (rules 6–7). | Coherence & Links (#14) | When #14 is designed |
| 4 | **Stern armour** (half armour inside the stern arc) as optional positional play. | game-designer | Post-MVP |
| 5 | **Point defence / targetable projectiles** — not at MVP. | game-designer | Post-MVP |
| 6 | **All weapon numbers** are starting values; no balance data exists yet. | systems-designer, `/balance-check` | When `assets/data/weapons/` exists |
