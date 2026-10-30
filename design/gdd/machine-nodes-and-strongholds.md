# Machine Nodes & Strongholds

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (counter roles; relay_cut supporting after the opening; readiness calibration; every loss names a cause; truth-neutral nodes; reserved fragment)
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — every stronghold is a fixed, authored puzzle whose counters are data); Pillar 5 (Living Against Made — strongholds are built around keystones and the link graph); Pillar 4 (Plan in the Open — the counter taxonomy feeds the Dossier and Debrief)

## Summary

Machine Nodes & Strongholds owns the authored machine positions (a keystone, a relay tree, a garrison and one fixed doctrine per anchor) and the counter taxonomy as moddable data. A stronghold never withdraws and resets in full between attempts, so it is a fixed point of difficulty the player grows into. It breaks when its keystone dies and yields its archive fragment. Every node names a counter that wins without allies, proven by the AI-vs-AI Runner, and the Dossier shows a truthful readiness range.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Content Data & Mod Loading, Hulls & Ship Definition, Coherence & Links, Fleet Coordination`

## Overview

Machine Nodes & Strongholds owns the authored machine positions on the sector
map and the **counter taxonomy**. A **machine node** is a `machine_node` content
definition: a keystone, a tree of relays, a garrison, one doctrine per anchor, a
layout, an archive-fragment slot and a Dossier block. A **stronghold** is the
battle a node fields. It never withdraws, and it resets in full between
attempts, so it is a fixed point of difficulty the player grows into. It is
**broken** when its keystone is destroyed; the node then goes inert and yields
its archive fragment. A **counter** is a `counter` content definition: a named
weakness with a Debrief cause, a counter-action, what it affects, what exploits
it, the Battle Record evidence that proves it, and the kits that realise it.
Counters are data, so mods can add them. Every node names at least one counter
that wins without allies, and the AI-vs-AI Runner must prove that it does. The
Dossier shows a readiness range computed from the player fleet, the stronghold
and the counters the player has fielded.

## Player Fantasy

**"It beat me. Now I know why, and I know what to bring."** The first time, the
stronghold is a wall: a ring of machines around a keystone that will not move
and will not break. The Debrief names the cause ("links held: the Anvil
contracted around the keystone"). The Dossier names the counter ("cut the relay
links"). The player refits, comes back, and the same wall comes apart where they
were told it would. The stronghold did not get weaker. The player got right.

Target aesthetics (MDA): **Challenge** first (a fixed, readable puzzle),
**Discovery** second (the Dossier fills in; the fragment at the end). This
deliberately inverts the concept's order (Discovery 2, Challenge 3) for this
combat-facing system. SDT:
**competence** through a truthful readiness range and a named counter;
**autonomy** through more than one viable counter per node.

**Pillars served:**
- **Pillar 1, *Every Defeat Is a Lead*:** every stronghold loss maps to a named
  counter with a Debrief cause and a counter-action (rules 9–12).
- **Pillar 5, *Living Against Made*:** strongholds are built around a keystone
  and the link graph; cutting links is always a counter (rules 1–4, 13).
- **Pillar 4, *Plan in the Open*:** the readiness range and counter text are
  generated from data, never written by hand (rules 18–20).

## Detailed Design

### Core Rules

**A. Nodes and strongholds**

1. **A machine node is a `machine_node` content kind** (base kind; envelope by
   Content Data Core Rule 7; body schema owned here). Body fields:
   | Field | Type | Range | Notes |
   |---|---|---|---|
   | `region_id` | ref → `region` | 1 | Sector Map (#26) |
   | `map_pos` | int pair | map units | Must fall within `SYSTEM_RADIUS_MU` of exactly one `star_system` (Sector Map & Travel rule 2) |
   | `keystone` | ref → `hull` | 1 | Role Keystone, class Capital (Hulls rule 2) |
   | `relays[]` | list of `{id, hull, parent}` | 0 – 6 | `parent` is `keystone` or another relay id; must form a tree |
   | `garrison[]` | list of `{hull, base_n, n_min, parent}` | 1 – 12 entries | `parent` is the keystone or a relay |
   | `doctrines[]` | list of `{anchor, doctrine_id}` | one per anchor | anchor = keystone or a root relay (Fleet Coordination rule 4) |
   | `layout` | list of `{member, x_pm, y_pm}` | per member | node-local start positions, permille of the anchor's `link_range` |
   | `fragment_slot` | ref → `fragment_slot` | 0 – 1 | Authored and seed-independent; Truth Seeding (#16) fills its content per save |
   | `roaming[]` | list of roaming defs (rule 14) | 0 – 2 | MVP authors at most 1 |
   | `dossier` | block (rule 18) | 1 | counters, helper faction |
   | `first_encounter` | bool | — | Settings rule 10a applies |
   | `exempt_lasting_cost` | bool | — | Copied into the battle setup (Battle Resolution rule 19, Vigor rule 18); at most one node per save, sequenced by Onboarding (#53) |
1a. **Nothing on a node reveals the truth** (Pillar 2). Whether a node has a
    `fragment_slot` is authored and seed-independent; Truth Seeding fills
    content only. No node field, map marker, Dossier line, `NodeBroken` beat or
    garrison composition varies with the seeded maker.
2. **The keystone is an immobile relay** (Coherence & Links rule 2). Its move
   speed is 0 in battle whatever its hull says. It is the root of the node's link
   tree. Every relay and garrison ship links, directly or through relays, to the
   keystone.
3. **Doctrine is authored per anchor and never changes** (Fleet Coordination
   rule 2). A garrison fleet's `withdraw_sr` is forced to 0 whatever its
   doctrine says (Fleet Coordination rule 5).
4. **Strength scaling.** `stronghold_strength_permille` (`s`) is accepted as this
   system's key (Gameplay Settings table, † removed). It scales exactly two
   things: garrison counts (D1) and the defensive stats `hull_max`, `armour_max`
   and `ward_max` of every node member (D2). It never changes the keystone, the
   relay tree, any `doctrine_id`, any weapon, any `counters[]` tag, the layout or
   the Dossier counters (Settings rule 10).
5. **One battle per attempt.** Engaging a node starts a stronghold battle with
   seed `node_seed = H(campaign_seed, node_id, attempt_index)` through
   Deterministic RNG (#2). `attempt_index` starts at 0 and rises by 1 per battle.
   The node's members spawn at `layout`, every member at full stats.

**B. Between attempts**

6. **Full reset.** When a stronghold battle ends and the node is not broken, every
   destroyed or damaged member is restored at once. The garrison respawns at D1
   counts. No damage carries over. This resolves Hulls Open Question 2:
   stronghold self-repair is total and immediate.
7. **Why full reset.** Chip damage never replaces a counter: killing relays and
   escorts, then retreating, buys nothing. What carries over is the player's
   knowledge (Dossier, Debrief) and kit. Defeat costs are Battle Resolution's.
8. **The layout does not change between attempts.** Only `node_seed` changes,
   which moves tie-break draws, never composition.

**C. Counters**

9. **A counter is a `counter` content kind** (Content Data Core Rule 17). Body:
   | Field | Type | Range | Notes |
   |---|---|---|---|
   | `name_key` | text key | 1 | "Relay cut" |
   | `cause_key` | text key | 1 | Debrief cause, e.g. "links held" |
   | `action_key` | text key | 1 | counter-action, e.g. "cut the relay links" |
   | `affects[]` (inbound) | list of tags or refs | ≥ 1 | hull counter tags (`relay`, `regrowing`), doctrine fields, organic cores |
   | `exploited_by[]` (outbound) | list of refs | ≥ 1 | damage types, order types, module or weapon refs |
   | `evidence` | `{event, predicate}` | 1 | **cause polarity**: true when the cause operated (rule 11); the Debrief names the cause only when it held |
   | `worked` | `{event, predicate}` | 1 | **success polarity**: true when the counter was applied; feeds the Dossier (rule 11) |
   | `requires_allies` | bool | — | false = a solo counter |
   | `kits[]` | list of `{weapons[], modules[], orders[]}` | ≥ 1 | each kit realises the counter; gear unlocks kits |
10. **Validation.** A counter missing any field above is a validation error.
    Mods add counters in their own namespace and never change base counters
    (Content Data rule 5).
11. **Predicates** are a fixed engine list, in two polarities:
    - **cause** (for `evidence`): `band_held(WHOLE, anchor, pm)` (the anchor
      spent ≥ pm of the battle in WHOLE), `armour_regrew(pm)` (enemy armour
      regrew ≥ pm of its max in total), `ward_held(pm)` (wards absorbed ≥ pm of
      player damage on warded ships), `core_damage_ge(pm)` (player cores took ≥
      pm of `C0` as core damage), `focus_on(flagship)` (a `FocusAssigned` on
      the flagship held ≥ `TELL_TICKS`), `hits_inside_arc(arc, pm)` (≥ pm of
      player hits on a screen landed inside its front arc);
    - **success** (for `worked`): `link_snapped_by(type)`,
      `band_entered(state, anchor)`, `regrowth_stalled`, `ward_emptied`,
      `core_damage_lt(pm)`, `focus_lost(flagship)`, `hit_outside_arc(arc)`.
    A mod counter may use only these. The Debrief names a counter's cause only
    when its `evidence` held in the Battle Record (After-Action Debrief rule 7);
    the Dossier records `worked`.
12. **MVP counter set** (six, base namespace). The four damage types map one to
    one onto the first four (Weapons & Damage, type-to-counter mapping):
    | ID | Cause (Debrief) | Counter-action | Affects | Exploited by | Evidence (cause) | Worked (success) | Can be solo |
    |---|---|---|---|---|---|---|---|
    | `relay_cut` | links held | cut the relay links | `relay`, `network_fed` | SEVERING; Focus on a relay | `band_held(WHOLE, anchor, 750)` | `link_snapped_by(SEVERING)` | yes |
    | `regrowth_stall` | armour regrew | stall regrowth, then burst | `regrowing` | KINETIC | `armour_regrew(500)` | `regrowth_stalled` | yes |
    | `ward_break` | ward held | strip the ward first | machine wards | ENERGY | `ward_held(500)` | `ward_emptied` | yes |
    | `core_exposure` | Vigor ran dry | keep cores out of the breaker's arc | the node's RUPTURE-armed members (weapon tag `core_breaker`) | Hold, Escort, Move out of arc | `core_damage_ge(300)` | `core_damage_lt(100)` | yes |
    | `focus_screen` | flagship focused | screen the flagship, bait the lock | Spear `focus_share_pm` | Escort order; decoy hull | `focus_on(flagship)` | `focus_lost(flagship)` | yes |
    | `flank_arc` | met the screen head-on | strike outside the screen's arc | Lattice Screen `spread` | Move order to a flank | `hits_inside_arc(front, 800)` | `hit_outside_arc(front)` | yes |
    "Can be solo" says the counter may take role `solo` on a node (rule 18).
    `core_exposure` is defensive: it names a player loss and how to avoid it.
    RUPTURE maps to it as the type the node turns on the player's cores, so its
    `affects[]` targets the node's RUPTURE weapons and rule 19 can match it.
13. **Every node's link tree is cuttable, so `relay_cut` is always listed.**
    On a node with `first_encounter` false it is `supporting`: it does not
    satisfy `NODE_NO_SOLO_COUNTER`, and the Runner fails the node if
    `relay_cut`'s cheapest kit alone wins ≥ `PROOF_WIN_MIN` at `s` 1000 (error
    `NODE_RELAY_CUT_SUFFICIENT`). Cutting links always matters against the made
    (Pillar 5), but it is never the whole answer after the opening.

**D. Breaking a node**

14. **Roaming fleets.** A roaming def has `fleet` (relay, garrison, doctrine;
    same schema as rule 1 minus keystone), `route[]` (≥ 2 `star_system` refs, each joined to the next by a lane; the first is the node's own system; Sector Map & Travel),
    `period_days`, `roam_max`. On world day `d`, a node in ACTIVE spawns one fleet
    at the node if `(d − phase) mod period_days = 0` and fewer than `roam_max` of
    its fleets exist. `phase` is one draw at campaign start on
    `base:node.roam#<node_id>`. Fleets walk `route[]` in order and loop. Roaming
    fleets keep their doctrine's `withdraw_sr` (a doctrine field, 250 for the
    three MVP doctrines); garrisons are forced to 0 by rule 3.
15. **Where a withdrawn fleet goes** (Battle Resolution Open Question 4). After a
    battle in which it withdrew, a roaming fleet is RETURNING: it travels to its
    home node by the reverse of the route it was on, then REFITS for
    `ROAM_REFIT_DAYS` (5): its surviving ships restore in full; destroyed ships
    are not replaced. It then resumes PATROL from waypoint 0. If its home is
    INERT, it goes to the nearest ACTIVE node in the region (ties to the lower
    node ID); if none exists, it dissolves on arrival. A withdrawal never breaks
    a node.
16. **Broken.** A node is **broken** the tick its keystone's hull reaches 0 in a
    stronghold battle, by any source. It is permanent. That tick:
    - `NodeBroken(node, tick, killer, cause_counter)` is logged at record tier;
      `cause_counter` is the first node counter whose predicate held, else none;
    - the keystone's loss is an ordinary relay loss (Coherence & Links); its
      subtree goes BROKEN unless relinked, and fights on by cut behaviour;
    - the battle continues to its normal end (Battle Resolution).
17. **After a node breaks:** at battle end the node goes BROKEN_UNCLAIMED. Its
    remaining members are removed; nothing respawns; roaming spawns stop. If the
    outcome is win-class, the fragment slot is granted to Archive Fragments (#28)
    at once and the node goes INERT. Otherwise it stays BROKEN_UNCLAIMED and the
    fragment is granted, with no battle, the next time a player fleet arrives in the node's system (reaches the
    node. A fragment at a BROKEN_UNCLAIMED node is reserved for the player and
    counts as unfound for exposure until claimed (Exposure & Rival
    Investigation #32). The map marker changes to the broken state. A node with no
    `fragment_slot` goes straight to INERT.

**E. Dossier, readiness and guarantees**

18. **Dossier block.** `dossier.counters[]` (1 – 6 entries `{counter, role:
    solo | supporting}`; only `solo` entries satisfy rule 19 and the proof in
    rule 21, and a `solo` entry needs `requires_allies` false) and
    optional `helper_faction_id`. Weaknesses shown are derived from the members'
    hull `counters[]` tags, never authored. If any listed counter has
    `requires_allies` true, `helper_faction_id` is required.
19. **The no-ally guarantee (validator).** Every node lists at least one entry
    with role `solo` (error `NODE_NO_SOLO_COUNTER`). Every listed
    counter's `affects[]` must match at least one tag, field or core present on
    the node (error `NODE_COUNTER_NO_TARGET`).
20. **Affordability (validator, post-load cross-kind check).** For each listed
    counter, at least one kit costs at most `COUNTER_COST_CAP` (4,800) by Refit &
    Loadout's price (Credits Open Question 2; D6). Error `COUNTER_UNAFFORDABLE` for
    `base`; warning for mods.
21. **The proof obligation (Runner).** For every node and every solo counter on
    it, the Runner fights the node with the **counter fleet** (the MVP reference
    fleet plus the counter's cheapest kit, playing the counter's scripted plan)
    over `PROOF_SEEDS` (10) fixed seeds, at `s` 1000 and 1200, each at the
    `enemy_ai_level` of the Settings preset with that `s` (2 and 3). The counter passes
    if it wins at least `PROOF_WIN_MIN` (7) (D5). A failing counter blocks release
    of that node.
21a. **Every loss names a cause.** For every node, each of the unprepared
    reference fleet's losses trips at least one listed counter's predicate in
    every one of the `PROOF_SEEDS` battles at `s` 1000 and its preset level, so the Debrief always has a cause
    to name (Pillar 1).
22. **The first stronghold still wins first** (Settings rule 10a). A node with
    `first_encounter` true must also pass the inverse proof: the unprepared MVP
    reference fleet (no kit, default doctrine) loses all `PROOF_SEEDS` battles at
    the Custom minimums, `s` 500 and `enemy_ai_level` 0 (D5). That also covers
    Chronicler (`s` 750, level 1).
23. **Readiness** is shown as a range and a band (D4). It uses only data the
    player could see: their fleet, the node's members at the current `s`, and
    the counters they have fielded and the Dossier has revealed.

**F. MVP content**

24. **The opening stronghold** (`base:node.opening`, working name; Narrative
    names it). `exempt_lasting_cost` and `first_encounter` true. Keystone (Capital, one
    Keystone Breaker, RUPTURE) as the root with doctrine **Anvil**. Two relays,
    children of the keystone. Garrison: 3 escorts per relay (`base_n` 3, `n_min`
    2). Counters: `relay_cut` (solo, opening only), `core_exposure` (solo), `regrowth_stall` (supporting). Expected first
    loss: the Anvil contracts, the Keystone Breaker burns the player's cores;
    the Debrief names "Vigor ran dry" and "links held". Expected first win: cut
    one relay's links (SEVERING), keep cores out of the breaker's arc, kill the
    keystone.
25. **The rest of the MVP region** has the Tier 0 count of further strongholds
    (provisionally two: one Lattice Screen, one Spear), each with at least two
    solo counters (Open Question 1).

### States and Transitions

**Node**

| State | Entered when | Leaves to |
|---|---|---|
| ACTIVE | campaign start | ENGAGED |
| ENGAGED | a stronghold battle starts | ACTIVE (not broken; full reset), BROKEN_UNCLAIMED, INERT |
| BROKEN_UNCLAIMED | keystone destroyed, outcome not win-class | INERT (player fleet reaches the node) |
| INERT | fragment granted, or no fragment slot | — |

**Roaming fleet**

| State | Entered when | Leaves to |
|---|---|---|
| PATROL | spawned, or refit done | ENGAGED |
| ENGAGED | a battle starts | PATROL (won or standoff), RETURNING (withdrew), destroyed |
| RETURNING | withdrew | REFIT, DISSOLVED |
| REFIT | reached a home node | PATROL after `ROAM_REFIT_DAYS` |
| DISSOLVED | no ACTIVE node to return to | — |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Content Data & Mod Loading (#4) | #4 → #23 | Loads `machine_node` and `counter`; runs rule 19–20 checks |
| Hulls & Ship Definition (#10) | #10 → #23 | Keystone and member hulls, counter tags; #23 resolves Hulls OQ2 |
| Weapons & Damage (#12) | #12 → #23 | Type-to-counter mapping (rule 12) |
| Coherence & Links (#14) | #23 → #14 | Keystone as immobile root relay; relay tree |
| Fleet Coordination (#21) | #23 → #21 | `doctrine_id` per anchor, anchors, layout, `withdraw_sr` 0 for garrisons |
| Gameplay Settings (#7) | #7 → #23 | `stronghold_strength_permille` (D1, D2) |
| Battle Resolution (#22) | both | #23 starts the battle; consumes the report (outcome, keystone kill tick, withdrawn ships) |
| Combat Event Bus & Battle Record (#9) | #23 → #9 | `NodeBroken`; reads evidence events |
| Deterministic RNG (#2) | #2 → #23 | `node_seed`, `base:node.roam#<node_id>` |
| After-Action Debrief (#24) | #23 → #24 | Counter causes and actions, evidence predicates |
| AI-vs-AI Runner (#25) | #23 → #25 | Proof obligations (rules 21, 22), counter fleets |
| Archive Fragments (#28) | #23 → #28 | Fragment slot on break |
| Truth Seeding (#16) | #16 → #23 | Fills `fragment_slot` per save |
| Sector Map (#26) | both | Node position, state marker; roaming routes |
| Credits (#18), Refit & Loadout | → #23 | Kit prices for rule 20 |
| Dossier (#47) | #23 → #47 | Counters, weaknesses, helper faction, readiness |
| Onboarding (#53) | #23 → #53 | The opening stronghold |

## Formulas

### D1. Garrison count

`n = clamp((base_n × s + 500) div 1,000, n_min, free_ports(parent))`

| Variable | Range | Description |
|---|---|---|
| base_n | 1 – 8 | Authored count at `s` 1000 |
| s | 500 – 1500 | `stronghold_strength_permille` |
| n_min | 1 – base_n | Floor, so the doctrine's shape survives |
| free_ports | 1 – 8 | The parent's remaining `link_ports` (Coherence & Links) |

Example: `base_n` 3, `n_min` 2, 4 free ports. `s` 750: (2,250 + 500) div 1,000
= **2**. `s` 1200: (3,600 + 500) div 1,000 = **4**. `s` 1500: 5, capped to **4**.
`s` 500: 2 (1,500 + 500 = 2,000 → 2), at the floor.

### D2. Defensive stat scaling

`stat = base × (1,000 + (s − 1,000) × STAT_SHARE_PM div 1,000) div 1,000`
for `hull_max`, `armour_max`, `ward_max`, composed by `modifier_compose`
(Settings rule 10). Weapons are not scaled.

Example: `hull_max` 2,000, `s` 1200, `STAT_SHARE_PM` 500: 1,000 + 200 × 500 div
1,000 = 1,100; 2,000 × 1,100 div 1,000 = **2,200**. At `s` 500: 1,000 − 250 =
750 → **1,500**.

### D3. Stronghold strength

`str_node = Σ over members (hull_max_scaled × dps_rating) div 1,000`, the same
measure as Fleet Coordination D2 at full health. `str_player` is the same sum
over the player's fleet at current hull.

### D4. Readiness range

```
R      = str_player × 1,000 ÷ max(1, str_node)
credit = min(COUNTER_CREDIT_CAP, COUNTER_CREDIT_PM × k)
R_eff  = R × (1,000 + credit) ÷ 1,000
unc    = max(UNC_MIN, UNC_MAX − UNC_STEP × known)
low    = R_eff × (1,000 − unc) ÷ 1,000
high   = R_eff × (1,000 + unc) ÷ 1,000
```

| Variable | Range | Description |
|---|---|---|
| k | 0 – 6 | Listed counters that are both revealed in the Dossier and fielded. A kit counts as fielded only if the fleet carries every weapon and module in it; order-only kits count only when their orders are assigned in the pre-battle plan |
| known | 0 – 12 | Doctrine fields and counters revealed for this node |
| unc | 100 – 400 | Uncertainty, permille |

Bands: `high < BAND_LOW` (600) **Outmatched**; `low ≥ BAND_HIGH` (1,000)
**Ready**; otherwise **Contested**. A range across two bands shows both ("Outmatched
to Contested"). Integer division truncates throughout.

Example: `str_player` 3,000, `str_node` 6,000 → R = **500**. One fielded counter:
credit 300 → R_eff = 500 × 1,300 ÷ 1,000 = **650**. known 2: unc = 400 − 2 × 40 =
**320**. low = 650 × 680 ÷ 1,000 = **442**; high = 650 × 1,320 ÷ 1,000 = **858**.
Shown: "Outmatched to Contested" (442 – 858).

**Truthfulness** is calibrated by the Runner (AC-17): the band must predict the
Runner's win rate, not merely look plausible.

### D5. Proof obligations

Solo counter passes: `wins ≥ PROOF_WIN_MIN` over `PROOF_SEEDS` seeds at each of
`s` 1000 and 1200. First encounter passes: `wins = 0` over `PROOF_SEEDS` at `s`
500 and `enemy_ai_level` 0 for the unprepared reference fleet. Example: 8 of 10 at 1000 and 7 of 10 at
1200 → **pass**; 9 and 6 → **fail** (Admiral fails).

### D6. Counter affordability

`min over kits (Σ price(item)) ≤ COUNTER_COST_CAP`, where `COUNTER_COST_CAP`
= the net surplus of a defeated Standard expedition plus one clean expedition
(Credits Open Question 2, ≈ 4,800 on the D5 fleet). Example: kit A 5,200, kit B
3,900 → **3,900 ≤ 4,800, pass**.

## Edge Cases

- **Keystone killed on the same tick the player's last ship is disabled**: the
  node is broken (rule 16); the outcome is loss-class, so it is
  BROKEN_UNCLAIMED and the fragment waits at the node.
- **Keystone killed, then the player retreats**: broken; remnants are removed
  at battle end; fragment claimed on the next visit with no battle.
- **STANDOFF with the keystone alive**: not broken; full reset (rule 6).
- **Keystone killed by the stronghold's own fire or a third party**: broken all
  the same; `killer` names the source; `cause_counter` may be none.
- **Chip-and-retreat across attempts**: buys nothing; full reset (rule 7).
- **`s` at 500 drives a count below `n_min`**: clamped to `n_min` (D1).
- **`s` raises a count past free ports**: capped; the surplus never spawns.
- **`str_node` 0** (malformed mod): `max(1, …)` avoids division by zero; the
  validator already refuses a node with no garrison (rule 1).
- **Empty player fleet**: R = 0, range 0 – 0, Outmatched.
- **R_eff very large**: integer range is safe; R is capped for display at 9,999.
- **A mod node lists only `requires_allies` counters**: `NODE_NO_SOLO_COUNTER`,
  the node does not load.
- **A mod counter names an unknown predicate**: validation error; the Debrief
  never shows it.
- **Relay tree with a cycle or a relay not under the keystone**: error
  `NODE_TREE`.
- **Two nodes share a roaming fleet's nearest-node distance**: lower node ID.
- **Roaming fleet engaged while RETURNING**: it fights with surviving ships; it
  can withdraw again (rule 15 restarts).
- **Salvage farming by repeat attempts**: Salvage & Recovery (#36) owns yields;
  flagged as Open Question 2.
- **Degenerate: one counter dominates every node.** `relay_cut` is listed
  everywhere but is `supporting` after the opening, and the Runner blocks a node
  where it alone wins ≥ `PROOF_WIN_MIN` (rule 13, `NODE_RELAY_CUT_SUFFICIENT`).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Content Data & Mod Loading (#4) | Hard | Kinds, envelope, validation, rule 17 |
| Hulls & Ship Definition (#10) | Hard | Keystone role, counter tags, `link_ports` |
| Coherence & Links (#14) | Hard | Relay tree, bands, keystone loss |
| Fleet Coordination (#21) | Hard | Doctrines, phases, `withdraw_sr` |
| Weapons & Damage (#12) | Hard | Damage types, type-to-counter mapping |
| Gameplay Settings (#7) | Hard | `stronghold_strength_permille` |
| Battle Resolution (#22) | Hard (both) | Battle start, report, outcomes |
| Deterministic RNG (#2) | Hard | Seeds and streams |
| Credits (#18), Refit & Loadout | Soft | Kit prices |
| Truth Seeding (#16) | Soft | Fragment slot fill |
| Debrief (#24), Runner (#25), Archive Fragments (#28), Sector Map (#26), Dossier (#47), Onboarding (#53) | Hard (reverse) | Counters, proofs, fragments, nodes |

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `STAT_SHARE_PM` | 500 | 250 – 1000 | Curve | How much `s` scales defence vs count |
| `ROAM_REFIT_DAYS` | 5 | 2 – 15 | Gate | Time a withdrawn fleet is off the map |
| `period_days` (per def) | 10 | 5 – 30 | Gate | Roaming pressure |
| `roam_max` (per def) | 1 | 0 – 2 | Gate | Concurrent roamers |
| `COUNTER_CREDIT_PM` | 300 | 150 – 500 | Curve | Readiness weight of a fielded counter |
| `COUNTER_CREDIT_CAP` | 600 | 300 – 1000 | Curve | Max counter credit |
| `UNC_MAX` / `UNC_MIN` / `UNC_STEP` | 400 / 100 / 40 | 200–600 / 50–200 / 20–80 | Curve | Range width vs knowledge |
| `BAND_LOW` / `BAND_HIGH` | 600 / 1,000 | 400–800 / 800–1,400 | Curve | Band thresholds |
| `PROOF_SEEDS` | 10 | 10 – 50 | Gate | Proof confidence vs CI time |
| `PROOF_WIN_MIN` | 7 | 6 – 9 | Gate | Required counter win rate |
| `COUNTER_COST_CAP` | 4,800 | from Credits | Gate | Counter affordability |

## Visual/Audio Requirements

- The keystone reads as the heaviest, stillest object on the field; its links to
  relays are drawn as in Coherence & Links.
- `NodeBroken` gets a distinct, once-per-node beat (visual and audio) that is
  never reused for an ordinary relay loss. Art and Audio direction own the form.
- Map markers for ACTIVE, BROKEN_UNCLAIMED (fragment waiting) and INERT differ by
  shape, not only colour.

## Game Feel

- The return attempt must feel like the same fight going differently, so layout
  and composition are identical (rule 8).
- The keystone kill is the release in the sawtooth; the battle continuing after
  it (rule 16) must read as mop-up, not a new threat.

## UI Requirements

- Dossier per node: weaknesses (derived), counters (name, action, solo marker,
  cheapest kit cost), helper faction if any, and the readiness range with band
  words and numbers.
- Readiness always shows a range, never a single number or a win percentage.
  Above `s` 1200 the band reads "uncalibrated above Admiral".
- Each counter shows its role (solo or supporting).
- Counter text is generated from `counter` data (Content Data rule 14).

## Cross-References

| Topic | Document | Section | Relationship |
|---|---|---|---|
| Counter kind and validation | `design/gdd/content-data-and-mod-loading.md` | Core Rule 17; Dependencies | Schema owner here |
| Keystone as relay | `design/gdd/coherence-and-links.md` | Rule 2; Edge Cases | Rule dependency |
| Doctrine, `withdraw_sr` | `design/gdd/fleet-coordination.md` | Rules 1–5; D2 | Data and rule dependency |
| Stronghold self-repair | `design/gdd/hulls-and-ship-definition.md` | Open Question 2 | Resolved by rule 6 |
| Strength scaling; first stronghold wins | `design/gdd/gameplay-settings-and-modifiers.md` | Rules 10, 10a | Key accepted (rule 4) |
| Withdrawn fleet destination; broken | `design/gdd/battle-resolution-and-retreat.md` | Rule 10; Open Question 4 | Resolved by rules 15–16 |
| Counter affordability | `design/gdd/credits-upkeep-and-sinks.md` | Open Question 2 | Validator rule 20 |
| Type-to-counter mapping | `design/gdd/weapons-and-damage.md` | Damage types table | Rule 12 |
| Strongholds, Dossier, fragments | `design/gdd/game-concept.md` | Core fantasy; Difficulty scaling | Source |

## Acceptance Criteria

- **AC-01 (Logic; rule 1)**: a `machine_node` whose relays do not form a tree under the keystone fails with `NODE_TREE`.
- **AC-02 (Logic; rule 2)**: a keystone never moves in battle, whatever its hull speed.
- **AC-03 (Logic; rule 3)**: a garrison fleet never enters WITHDRAW at any strength ratio.
- **AC-04 (Logic; rule 4, D1)**: `base_n` 3, `n_min` 2, 4 ports gives counts 2, 2, 3, 4, 4 at `s` 500, 750, 1000, 1200, 1500.
- **AC-05 (Logic; rule 4, D2)**: `hull_max` 2,000 scales to 1,500 at `s` 500 and 2,200 at `s` 1200; weapon damage is unchanged.
- **AC-06 (Logic; rule 4)**: at every `s` in 500–1500, the node's doctrine IDs, relay tree and Dossier counters are identical.
- **AC-07 (Logic; rule 5)**: the same `campaign_seed`, node and `attempt_index` give an identical Battle Record hash.
- **AC-08 (Logic; rule 6)**: after a loss in which two relays and four escorts died, the next attempt spawns every member at full stats.
- **AC-09 (Logic; rule 10)**: a counter missing `evidence` or `kits` fails validation; a mod counter cannot replace a base counter.
- **AC-10 (Logic; rule 11)**: the Debrief names a counter's cause only when its predicate held in the Battle Record.
- **AC-11 (Logic; rule 12)**: each of the four damage types resolves to exactly one MVP counter (KINETIC `regrowth_stall`, ENERGY `ward_break`, SEVERING `relay_cut`, RUPTURE `core_exposure`).
- **AC-12 (Logic; rules 14, 15)**: a withdrawn roaming fleet returns home, refits for 5 days with destroyed ships unreplaced, and resumes PATROL; with home INERT it goes to the nearest ACTIVE node by lower ID on ties.
- **AC-13 (Logic; rule 16)**: a keystone at hull 0 logs exactly one `NodeBroken`; a STANDOFF with the keystone alive logs none.
- **AC-14 (Logic; rule 17)**: broken with a win-class outcome grants the fragment at battle end; with a loss-class outcome it grants on the next arrival, with no battle.
- **AC-15 (Logic; rule 19)**: a node with no solo counter fails with `NODE_NO_SOLO_COUNTER`.
- **AC-16 (Logic; rule 20, D6)**: a base node whose counter's cheapest kit costs 4,801 fails `COUNTER_UNAFFORDABLE`.
- **AC-17 (Integration; D4; "in range" read by Runner D3: the win rate falls in the win-rate bands the shown range touches, Outmatched 0–300, Contested 300–700, Ready 700–1,000)**: over the Runner's calibration set, across `s` ∈ {500, 750, 1000, 1200} and every `enemy_ai_level`, battles shown Ready win at least 70%, Contested 30–70% and Outmatched at most 30%; and the Runner's win rate falls inside the shown range in ≥ 80% of calibration battles at each `known` value.
- **AC-18 (Logic; D4)**: the worked example gives 442 – 858, "Outmatched to Contested".
- **AC-19 (Integration; rule 21)**: every MVP node's every solo counter wins ≥ 7 of 10 at `s` 1000 and 1200 in the Runner.
- **AC-20 (Integration; rule 22)**: the unprepared reference fleet loses 10 of 10 against the opening stronghold at `s` 500 and `enemy_ai_level` 0.
- **AC-21 (Logic; determinism)**: roaming spawn days and routes are identical across two runs from the same campaign seed.
- **AC-24 (Integration; rule 13)**: a non-opening node where `relay_cut`'s cheapest kit alone wins ≥ 7 of 10 at `s` 1000 fails `NODE_RELAY_CUT_SUFFICIENT`.
- **AC-25 (Integration; rule 21a)**: for every MVP node, every unprepared-fleet loss in the proof set trips at least one listed counter's predicate.
- **AC-26 (Logic; rule 1a)**: two saves with different seeded makers give byte-identical node definitions, map markers and Dossier counter lists for every node.
- **AC-22 (Playtest; rule 24)**: 4 of 5 new players lose the opening stronghold, then name a counter from its Dossier entry and win within three attempts.
- **AC-23 (Playtest; D4)**: 4 of 5 players describe the readiness range as "about right" after their attempt.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **The fourth damage type** is ENERGY (Weapons & Damage rule 6), so it maps to
  `ward_break`.
- **The proof strengths** are `s` 1000 and 1200 only (Standard and Admiral).
  Custom values above 1200 are the player's choice; the Custom screen says that
  counters are proven only up to 1200.
- **A fragment from a loss-class break** waits at the node (rule 17): the break
  is earned, and claiming it costs a trip, never a battle.
- **Where `withdraw_sr` lives**: it is a doctrine field (250 for the MVP three);
  garrisons override it to 0 (rule 3).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | The Tier 0 count of further MVP strongholds (provisionally two: one Lattice Screen, one Spear) and their doctrines. | producer, game-designer | Before region authoring |
| 2 | Repeat-attempt salvage: should stronghold wrecks yield less on each attempt? | Salvage & Recovery (#36), economy-designer | When #36 is designed |
| 3 | Readiness calibration targets (70% / 30%) and the band words. | ux-designer | Before Dossier (#47) design |
| 4 | `COUNTER_COST_CAP` 4,800 is derived from Credits' D5 fleet; re-derive it when Refit & Loadout prices exist. | economy-designer | When Refit & Loadout is designed |
