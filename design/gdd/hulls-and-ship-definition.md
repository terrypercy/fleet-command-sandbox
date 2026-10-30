# Hulls & Ship Definition

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on scar care vs truth-sharing preview, Vigor-vs-flux at the data level, the visible DP adjustment, the stern definition, designation lineage, and the travel-healing gate; all six revised
> **Implements Pillar**: Pillar 5 (Living Against Made — organic and machine hulls are built differently, not reskinned); Pillar 4 (Plan in the Open — a hull's strengths and weaknesses are readable before the fight); Pillar 2 (no machine hull carries organic lineage)

## Summary

Hulls & Ship Definition defines what a ship is: a frozen hull definition (race,
size class, role, integer stats, mounts, module slots, counter tags and
presentation hooks) and a saved per-ship instance (name or designation, damage,
scars, loadout). Organic and machine hulls are built differently, not reskinned:
organics regrow armour and heal to a scar line, machines depend on relays and
flip between linked and cut (Pillar 5). Counter tags are derived from stats
where possible, so the Dossier never lies about structure (Pillar 4).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Content Data & Mod Loading`

## Overview

Hulls & Ship Definition says what a ship **is** as data. A **hull** is a frozen
content definition (Content Data & Mod Loading): its race and maker, size class,
role, stats, weapon mounts, module slots, the counter tags the Dossier and
Debrief speak in, and the hooks presentation needs. A **ship** is one instance
of a hull in the campaign, with its own Runtime ID, name, damage, scars and
loadout.

This is the system where Pillar 5, *Living Against Made*, is either built in or
lost. Organic and machine hulls do not differ only in their resource (Vigor vs
Coherence); they are **built** differently:
- organic armour regrows in battle and organic wounds close between battles,
  down to a scar line;
- machine ships depend on relays and run some guns off the network; cut them off
  and they become ordinary ships;
- machines are symmetric and built from a shared module kit; organic layouts can
  have blind sides;
- organics fade gradually; machines flip between linked and cut.

It deliberately does **not** own movement physics (Combat Space #11), damage
maths (Weapons & Damage #12), Vigor maths (#13), Coherence maths (#14) or refit
rules (Refit & Loadout). It defines the data those systems read.

## Player Fantasy

**A creature you keep alive, against an instrument in a network.** An organic
ship is a living thing the player carries through an expedition: it tires,
heals, scars and keeps its name. A machine ship is one node of something larger,
only as strong as its links, with a designation instead of a name. The player
learns to read a hull's doctrine at a glance, and that reading is the design
test: **the hull tells you how it fights.**

*Anchor moment:* the player's Spiralward limps out of a lost battle with its
rear arc scorched. Over three days of travel its wounds close, but a pale scar
stays until it rests at a Shell port. In the Debrief, the enemy's Lattice Relay,
designation L-07, is marked as the ship to kill first next time.

**Pillars served:**
- **Pillar 5, *Living Against Made*:** structural differences, not reskins
  (Core Rules 7–11).
- **Pillar 4, *Plan in the Open*:** counter tags are derived from stats where
  possible, so the Dossier never lies about a hull's structure (rule 13).
- **Pillar 1:** every hull carries at least one counter tag the Debrief can name.
- **Pillar 2, *The Truth Is Yours to Tell*:** nothing about a machine hull
  (manufacturer, designation) carries organic lineage (rules 6, 14), and losing
  a race's care through the truth is always previewed (rule 8).

**This system must never make the player feel:** "these are the same ship with a
different colour" or "the Dossier told me it had no rear guns, and it did".

## Detailed Design

### Core Rules

**A. The hull definition**

1. **A hull is a `hull` content definition** with the common envelope (Content
   Data & Mod Loading, Core Rule 7) and this body. Every number is an integer.

   | Field | Type | Range | Notes |
   |---|---|---|---|
   | `race` | ref → `race` | — | **The resource model comes from the race** (`race.resource_model` ∈ {vigor, coherence}); a hull never declares its own |
   | `manufacturer` | ref → `manufacturer` | — | A brood or lineage for organics; a kit pattern for the Instrument |
   | `size_class` | enum | light, line, heavy, capital | Rule 3 |
   | `role` | enum | brawler, skirmisher, support, relay, anchor | Doctrine shorthand |
   | `hull_points` | int | 100 – 20,000 | |
   | `armour` | int | 0 – 2,000 | Shape of armour is Weapons & Damage's |
   | `mass` | int | 1 – 1,000 | |
   | `max_speed` | int | 20 – 400 world units/s | World unit: Combat Space |
   | `accel` | int | 5 – 400 | |
   | `turn_rate` | int | 5 – 180 °/s | |
   | `mounts[]` | list | 0 – 12 | Rule 4 |
   | `modules[]` | list | 0 – 8 | Rule 5 |
   | `counters[]` | list of refs → `counter` | 1 – 6 authored | Rule 13 |
   | `deploy_adjust` | int | −10 – +10 | Formulas D1 |
   | `name_key` | text key | — | Class name (Content Data, Core Rule 14) |
   | `organic` block | object | required **iff** the race is Vigor | Rule 7 |
   | `machine` block | object | required **iff** the race is Coherence | Rule 9 |
   | presentation block | object | required | Rule 15 |

2. **Definitions are frozen; derived stats are never saved.** Anything computed
   from a definition (DP, derived tags, effective speed) is recomputed on load
   (Content Data, Core Rule 11).
3. **Size classes** (internal enum; display names are text keys for the
   narrative team):
   - **Light**: fast pickets and relays, the ships you hunt.
   - **Line**: the backbone of a fleet.
   - **Heavy**: holds a position, anchors a formation.
   - **Capital**: a flagship or a stronghold's keystone. At MVP at most one per
     side in a battle.
4. **Mounts.** Each mount has `slot_id` (unique in the hull), `size` (S, M, L),
   `accepts` (a set of weapon families; the enum is Weapons & Damage's),
   `facing` (−179 – 180°), `arc` (0 – 360°; 0 fires straight ahead, 360 ignores
   facing), `pos_x`/`pos_y` (inside the outline), and on machine hulls
   `network_fed` (0/1). A weapon fits a mount if its family is accepted and its
   size is no larger than the mount's (Refit & Loadout owns any size-down rule).
5. **Module slots.** Each has `slot_id` and `module_class`: **`graft`** on organic
   hulls, **`kit`** on machine hulls. The two pools never cross.
6. **Validation** (at content load, Content Data Core Rule 10): duplicate
   `slot_id`, a point outside the outline, a block that doesn't match the race's
   resource model, `link_ports` > 0 with `relay_capacity` 0, 0 mounts on a role
   other than support or relay, a machine hull with a lineage-bearing
   manufacturer, **a non-relay machine hull with no unfed mount** (so every cut
   ship can still shoot; Coherence & Links rule 6), and, at MVP, **a machine
   hull in the player fleet** (Coherence & Links rule 17) are all errors that
   refuse the hull.

**B. Living against made**

7. **The `organic` block**: `vigor_ceiling` (100 – 2,000), `vigor_flow` (maximum
   spend per second, 5 – 200), `armour_regrow_permille_per_min` (0 – 100),
   `scar_line_permille` (0 – 1,000), `membrane_permille` (0 – 600; the share of
   each hit the membrane absorbs for Vigor, Weapons & Damage rule 7). Vigor maths belong to Vigor (#13); the hull
   only states capacity. **Vigor lives in physical cores at positions on the
   hull** (`glow_anchors`, rule 15, each with a core id): unlike a single
   ship-wide flux number, a ship's Vigor is located, and Vigor (#13) must make
   damage to a core's region affect that core.
8. **Organic hulls heal; machine hulls are repaired.**
   - In battle, organic armour regrows at `armour_regrow_permille_per_min` of its
     maximum while the ship takes no damage (the rate is applied by Weapons &
     Damage). Machine armour never regrows.
   - Between battles, organic hull damage closes during travel, but only down to
     the **scar line**: `scar_line_permille` of maximum hull points stays
     damaged until the ship rests at a port (Ports, Rest & Care #27), so one
     rest restores both hull and Vigor. Machine damage needs a repair facility.
   - The healing rate during travel is Ports, Rest & Care's; it must keep the
     defeat-cost floor (Gameplay Settings & Modifiers rule 9).
   - **Which ports can clear a ship's scars is owned by Ports, Rest & Care
     (#27).** If naming a race makes it hostile and that removes scar care for
     any owned ship, the sharing preview must list it as a first-order
     consequence (Pillar 2: consequences of sharing are always previewed).
9. **The `machine` block**: `coherence_demand` (1 – 20), `relay_capacity`
   (0 – 60), `link_range` (0 – 3,000 world units), `link_ports` (0 – 8),
   `ward_points` (0 – 5,000) and `ward_refill` (0 – 500 per second, only while
   linked; Weapons & Damage rule 7) and
   `cut_behaviour` (an ID chosen by Coherence & Links #14 and Ship AI #20).
10. **Machine ships depend on the network; organic ships stand alone.** A
    `network_fed` mount, and the ship's coordination, work only while the ship
    is linked; cut, it follows its `cut_behaviour` (maths in #14 and #20).
    Organic ships have no outside dependency.
11. **Shape follows side.** Machine hulls are strictly symmetric: the validator
    refuses a machine hull whose mounts are not mirror-symmetric. Organic hulls
    may be asymmetric, including a blind side.

**C. Instances**

12. **A ship is an instance keyed by its Runtime ID** (Runtime ID Service, Core
    Rule 2). It saves: `content_id`; name or designation (rule 14); owning
    fleet; `hull_current`; `armour_current` (shape per Weapons & Damage);
    `scar_points` (organic); `loadout` (`slot_id` → weapon or module content
    ID); `vigor_core_mV[]`, the per-core ceilings whose sum is the current
    Vigor ceiling (owned by Vigor #13, rule 2); and its modifier list.
    A ship whose definition is missing follows Content Data Core Rule 13
    (substituted, removed or kept inert).

**D. Readability**

13. **Counter tags are derived where they can be, authored where they can't.**
    - **Structural tags** are added by the validator from the stats:
      `relay` (`relay_capacity` > 0), `network_fed` (any fed mount),
      `blind_rear` (no mount's arc overlaps the **stern**, defined as the arc
      180° ± `STERN_HALF_ARC`, default 30°), `unarmoured` (`armour` 0),
      `regrowing` (`armour_regrow` > 0).
    - **Doctrine tags** (1 – 6) are authored references to `counter`
      definitions (Content Data Core Rule 17; Machine Nodes & Strongholds owns
      their meaning).
    - An authored tag that contradicts the stats is an error, so the Dossier
      never states something false about a hull's structure.
14. **Names and designations.**
    - The class name is `name_key`.
    - An **organic** ship draws a name from its race's name table (a CSV kind)
      on campaign stream `base:hulls.name#<race>` (Deterministic RNG & Seed
      Streams naming rules). The player may rename it: up to 32 characters,
      plain text, sanitised as Content Data Core Rule 14 requires.
    - A **machine** ship gets a **designation**, never a name: the class's short
      code plus a per-class serial counter saved in the campaign (`L-07`). It
      cannot be renamed. The serial is never the Runtime ID (Runtime ID Service,
      Core Rule 8: IDs are never shown). **Class codes and serial formats carry
      no organic-race lineage** (no race's script, letter forms or numbering
      style), so a designation never hints at the seeded maker (Pillar 2).
15. **The presentation block** (from `art-director`) holds: `visual_ref` (a
    scene, not a bare sprite, so glow and link anchors are children);
    `world_radius` and `sprite_scale` (kept separate, so collision and art tune
    independently); `glow_anchors[]` (organic only: position, radius, core id;
    Vigor drives brightness, the hull stores no Vigor value); `link_attach_points[]`
    (machine only: position, role receive/relay; refused on an organic hull);
    `mount_points` shared with rule 4; `damage_hooks` (intact, damaged,
    critical); and the flash pivot. Every point lies inside the outline.
16. **Silhouette rules** (binding on the art bible):
    - Class reads from footprint area, lobe or module count, and aspect ratio;
      each step up a class changes at least two of these, and footprint at
      least doubles.
    - Organic hulls are asymmetric and curved, one base shape per race; larger
      classes add lobes of that shape, never a second shape.
    - Machine hulls are symmetric, from one shared module kit; class is module
      count and arrangement. Breakaway machines (post-MVP) break symmetry
      slightly.
    - Bow and heading read from silhouette alone, for both sides.
    - Mounts show as a small mark on the outline (bud or pore on organics,
      hardpoint on machines), distinguished by shape, not colour.

**E. The MVP roster** (race names are placeholders for the narrative team)

| Hull | Race | Size | Role | Identity |
|---|---|---|---|---|
| Seedcaller | Growers (coral/seed-pod) | Line | support | Armour regrows fast; a slow, healing anchor |
| Thornbrood | Growers | Light | skirmisher | High `vigor_flow`, small ceiling: spends hard, fades fast |
| Spiralward | Shell race (spiral) | Heavy | brawler (flagship candidate) | Large ceiling, a blind rear arc; rewards facing discipline |
| Lattice Relay | Instrument | Light | relay | `relay_capacity` 40, lightly armed: the ship you hunt first |
| Vector Line | Instrument | Line | brawler | Mostly `network_fed` mounts; cut, it is an ordinary ship |
| Keystone | Instrument | Capital | anchor | A small relay itself plus heavy guns; holds a stronghold together |

### States and Transitions

A hull definition has no states (frozen). A ship instance:

| State | Entered when | Leaves to |
|---|---|---|
| Docked | in port | Travelling, Deployed |
| Travelling | leaves port | Docked (arrives), Deployed (battle) — organic wounds close toward the scar line |
| Deployed | battle starts and it is fielded | Travelling/Docked (battle ends), Disabled, Destroyed, Retreated |
| Retreated | leaves the battle (Battle Resolution) | Travelling |
| Disabled | hull points reach 0, player side (Battle Resolution rule 7) | Travelling (recovered after a win, or left behind and billed by Credits after a loss) |
| Destroyed | hull points reach 0, enemy side (player side only in the optional permadeath mode) | — (Runtime ID retirement; Battle Record keeps it) |
| Inert | its definition is missing (Content Data Core Rule 13) | Docked (content returns) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Content Data & Mod Loading (#4) | #4 → #10 | `hull`, `race`, `manufacturer`, name-table and `counter` kinds; validation; freezing |
| Runtime ID Service (#3) | #3 → #10 | Each ship is a Runtime ID |
| Deterministic RNG & Seed Streams (#2) | #2 → #10 | `base:hulls.name#<race>` campaign stream |
| Combat Space (#11) | #10 → #11 | Mass, speed, accel, turn rate, `world_radius` |
| Weapons & Damage (#12) | both | Mount sizes, families, arcs; armour value; applies armour regrowth |
| Vigor (#13) | #10 → #13 | `organic` block capacities; ship's current ceiling |
| Coherence & Links (#14) | #10 → #14 | `machine` block; link attach points; `cut_behaviour` |
| Flagship Piloting (#15) | #10 → #15 | Flagship candidate hulls and their stats |
| Ship AI (#20) | #10 → #20 | Role, counters, `cut_behaviour` |
| Machine Nodes & Strongholds (#23) | both | Counter meanings; strongholds scale by numbers only (Settings rule 10) |
| Ports, Rest & Care (#27) | #10 → #27 | Scar line; travel healing rate is #27's |
| Refit & Loadout | #10 → refit | Mount and module rules |
| Save/Load (#5) | #10 → #5 | Instance fields (rule 12) in the fleet section |
| Dossier, Debrief | #10 → them | Counter tags, roles, class names, designations |
| Battle Record (#9) | #10 → #9 | Roster entries: content, name or designation, slot → weapon |

## Formulas

### D1. Deployment points (DP)

`t_res = vigor_ceiling div 100` (organic) or `relay_capacity div 5` (machine)

`B = hull_points div 200 + armour div 40 + max_speed div 40 + Σ mount_value + 2 × module_count + t_res`

`DP = (B × K_size + 99) div 100 + deploy_adjust`, clamped to 5 – 150

| Variable | Type | Range | Description |
|---|---|---|---|
| mount_value | int | S 1, M 2, L 4 | Per mount |
| module_count | int | 0 – 8 | Module slots |
| K_size | int | light 100, line 110, heavy 125, capital 150 | Size multiplier (permille-of-100) |
| deploy_adjust | int | −10 – +10 | Authored correction |
| DP | int | 5 – 150 | Cost to field the ship (Fleet Coordination and Battle Resolution use it) |

**Example:** a line organic with 2,400 hull, 300 armour, speed 120, mounts
M + M + S, 3 modules, ceiling 600: B = 12 + 7 + 3 + 5 + 6 + 6 = 39; DP =
(39 × 110 + 99) div 100 = 4,389 div 100 = **43**.

### D2. Scar line

`hull_floor_between_battles = (hull_points × scar_line_permille + 500) div 1000`
(integer, `modifier_compose` rounding).

**Example:** a 2,400-hull organic with `scar_line_permille` 300 heals during
travel to no better than 2,400 − 720 = 1,680 until it rests; at 1,000, wounds
never close between battles; at 0, travel heals fully.

## Edge Cases

- **If a hull has 0 mounts**: valid only as support or relay (rule 6).
- **If `armour` is 0**: regrowth does nothing; the `unarmoured` tag is added.
- **If a loadout names a `slot_id` the hull no longer has** (a mod changed it):
  the item moves to cargo with a notice; nothing is deleted.
- **If a mount's arc is 360**: `facing` is ignored; `blind_rear` cannot apply.
- **If a weapon is larger than every mount**: Refit refuses it; it stays in cargo.
- **If an organic hull's race is changed by a mod to a Coherence race**: the hull
  is refused at load (block mismatch).
- **If the player renames a ship to an empty or control-only string**: it reverts
  to its previous name.
- **If two machine ships of a class are built**: they get consecutive serials;
  serials are never reused.
- **If a capital ship would be the second on one side**: deployment refuses it
  (rule 3), at MVP.
- **If a stronghold's difficulty rises**: its hulls keep their tags and doctrine;
  only stats and counts scale (Gameplay Settings & Modifiers rule 10).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Content Data & Mod Loading (#4) | Hard | Kinds, validation, freezing |
| Runtime ID Service (#3) | Hard | Instance identity |
| Deterministic RNG & Seed Streams (#2) | Soft | Name stream |
| #11, #12, #13, #14, #15, #20, #23, #27, Refit & Loadout, Dossier, Debrief, #9 | Hard (reverse) | Read the definition and instance |

Bidirectional check: Content Data and Runtime ID Service already list hull
content and ship IDs. Downstream GDDs must cite this one.

## Tuning Knobs

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `K_size` table | 100 / 110 / 125 / 150 | 100 – 200 each | DP scaling by class |
| DP divisors | 200 / 40 / 40 | ±50 % | DP weight of hull, armour, speed |
| Mount values | 1 / 2 / 4 | 1 – 8 | DP weight of guns |
| `deploy_adjust` limits | ±10 | ±5 – ±20 | Authored correction room |
| Default `armour_regrow_permille_per_min` | 30 | 0 – 100 | Organic in-battle resilience |
| Default `scar_line_permille` | 300 | 200 – 600 | How much rest matters |
| `STERN_HALF_ARC` | 30° | 15 – 60° | What counts as the stern for `blind_rear` |
| Counter tag cap | 6 | 3 – 8 | Dossier density |
| Name length | 32 characters | 16 – 48 | UI fit |

All values are data (`assets/data/hulls/`).

## Visual/Audio Requirements

From `art-director`, binding on the art bible (none exists yet):
- **R1**: at minimum combat zoom, each hull ≤ 32 px across and filled solid black,
  a tester names side and class with ≥ 90 % accuracy.
- **R2**: in greyscale, a full-Vigor and a spent organic ship are distinguishable
  at 32 px.
- **R3**: in greyscale, solid, dashed and snapped links are distinguishable at
  minimum zoom.
- **R4**: no two hulls of the same class and side overlap in silhouette beyond the
  art bible's threshold.
- **R5**: hull emissive light sits above the background's value range.
- **R6**: every mount, glow and link point lies inside the outline (validator).
Deferred to the art bible: pixel ratios, race hues, the Vigor pulse curve,
damaged silhouettes, the module kit, and how player-owned machine hulls read.

## Game Feel

- **Organic ships feel alive**: they visibly breathe (glow), regrow and scar.
- **Machine ships feel networked**: their strength visibly depends on their
  link lines; a cut ship visibly changes behaviour.

## UI Requirements

- Hull card (port, refit, Dossier): class name, role, size, mounts with arcs,
  counter tags with their meaning, DP (base and authored adjustment shown as
  separate lines, D1), and for organics the scar state.
- Fleet list: names for organic ships, designations for machine ships.
- 📌 **UX Flag — Hulls & Ship Definition**: include the hull card and fleet
  list in the refit and Dossier UX specs before epics.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Kinds, envelope, freezing, missing content, counters, text keys | `design/gdd/content-data-and-mod-loading.md` | Core Rules 7, 10, 11, 13, 14, 17 | Data dependency |
| Instance IDs; IDs never shown | `design/gdd/runtime-id-service.md` | Core Rules 2, 8 | Rule dependency |
| Name stream naming | `design/gdd/deterministic-rng-and-seed-streams.md` | Stream names | Rule dependency |
| Strongholds scale by numbers; defeat-cost floor | `design/gdd/gameplay-settings-and-modifiers.md` | Rules 9, 10 | Rule dependency |
| Roster in the record | `design/gdd/combat-event-bus-and-battle-record.md` | Rule 10 | Data dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 1)**: a hull with any non-integer number fails to load, naming the field.
- **AC-02 (Logic; rules 1, 7, 9)**: a hull whose `organic`/`machine` block does not match its race's resource model is refused; a hull with no resource-model field takes it from its race.
- **AC-03 (Logic; rule 6)**: each listed validation error (duplicate `slot_id`, point outside outline, `link_ports` without relay capacity, 0 mounts on a brawler, machine with lineage manufacturer) refuses the hull with a named reason.
- **AC-04 (Logic; D1)**: the D1 fixture gives DP 43; every `base` hull's DP is within 5 – 150.
- **AC-05 (Logic; rule 13)**: the validator adds `relay` to every hull with `relay_capacity` > 0 and `blind_rear` to every hull with no stern coverage; an authored tag contradicting stats is an error.
- **AC-06 (Logic; rule 11)**: a machine hull with asymmetric mounts is refused; the same layout on an organic hull loads.
- **AC-07 (Logic; rule 5)**: a graft module in a kit slot (and the reverse) is refused at refit validation.
- **AC-08 (Logic; rule 2)**: a hull definition's hash is unchanged after 30 simulated minutes of damage and refits.
- **AC-09 (Logic; rule 12)**: a save → load round trip reproduces every instance field exactly; no derived stat appears in the save.
- **AC-10 (Logic; rule 8, D2)**: an organic ship at 900/2,400 hull with scar line 300 heals during travel to exactly 1,680 and no further; resting restores 2,400; a machine ship heals none during travel.
- **AC-11 (Logic; rule 14)**: machine ships show designations with consecutive per-class serials that never equal their Runtime ID and cannot be renamed; a renamed organic ship keeps its name across save and load; an empty rename reverts.
- **AC-12 (Logic; rule 13)**: every MVP hull has at least one counter tag that resolves to a `counter` with a Debrief cause key.
- **AC-13 (Logic; rule 15)**: an organic hull with `link_attach_points` or a machine hull with `glow_anchors` is refused; every point lies inside the outline.
- **AC-14 (Playtest; rule 16, R1)**: 4 of 5 testers name the two relay hulls as first targets without being told, and tell organic from machine at 32 px in solid black.
- **AC-15 (Playtest; Pillar 5)**: asked to describe the Spiralward's resource after one battle, at least 4 of 5 Starsector players name, unprompted, a behaviour flux and CR lack (located cores, a ceiling eroded by wounds, rest-bound recovery). Owned jointly with Vigor (#13); this GDD's part is the located cores (rule 7).
- **AC-17 (UI; D1)**: the hull card shows base DP and the authored adjustment as separate lines ("Doctrine premium +4"), and their sum equals the DP charged at deployment.
- **AC-18 (Logic; rule 13)**: with `STERN_HALF_ARC` 30°, a single mount whose arc ends exactly at 150° (just touching the stern range) does not prevent `blind_rear`; one reaching 151° does.
- **AC-19 (Logic; rule 14)**: every designation class code and serial format passes a lineage check against the organic races' scripts and numbering styles (review checklist with narrative-director).
- **AC-16 (Visual; R2–R5)**: the art bible's readability checks pass on every MVP hull, with retained screenshots in `production/qa/evidence/`.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | ~~**Gate: travel healing**~~ **Signed off 2026-10-30 by Credits, Upkeep & Sinks rule 13**, on three conditions: scar line ≥ 200, no credits-only scar clearing, no rest fee (Vigor sign-off: Vigor D5 keeps erosion costly). Original gate: (rule 8). Ports, Rest & Care (#27) cannot be approved until Vigor (#13) and Credits, Upkeep & Sinks (#18) show that a defeat still costs time or resources under the default `scar_line_permille`, which is itself subject to that sign-off. | #13, #18, #27, economy-designer | Before #27 approval |
| 2 | ~~**Stronghold self-repair** between attempts~~ **Resolved 2026-10-30:** full, immediate reset (Machine Nodes & Strongholds rule 6). | Machine Nodes & Strongholds (#23) | Closed |
| 3 | **Race and class display names**, name tables and designation codes. Brief: designation codes and serial formats carry no organic-race lineage (rule 14). | narrative-director, writer | Vertical Slice |
| 7 | ~~**Scar care by port**~~ **Resolved 2026-10-30:** scars clear by rest at any non-Hostile port, free ports included; care restores Vigor only; travel heals to the scar line at `TRAVEL_HEAL_PM_PER_DAY` (Ports, Rest & Care rules 14–19, D6). | Ports, Rest & Care (#27) | Closed |
| 4 | **Player-owned machine hulls** (a breakaway faction joins late): naming, repair and how they read. | game-designer, art-director | Post-MVP |
| 5 | **All stat ranges and the roster's numbers** are starting values; no balance data exists yet. | systems-designer, `/balance-check` | When `assets/data/hulls/` exists |
| 6 | **Art bible** does not exist; R1–R6 and rule 16 must be carried into it. | art-director | Before asset production |
