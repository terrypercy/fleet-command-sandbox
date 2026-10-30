# Sector Map & Travel

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 4 (Plan in the Open — routes, travel time and what waits along them are shown before you commit); Pillar 1 (Every Defeat Is a Lead — the way back to a stronghold is short and known); Pillar 2 (The Truth Is Yours to Tell — the map is where evidence and rumours are found)

## Summary

Sector Map & Travel is the campaign map: a hand-made region of star systems joined by lanes, with ports, machine nodes and points of interest placed in them. The fleet travels lane by lane at the speed of its slowest ship, as real campaign time that costs upkeep, and the route planner previews time, cost and known risks with the clock held. Contacts with roaming machine fleets or hostile patrols are solved by exact maths and always offered (Fight, Evade, Turn back), never auto-started; after a loss the fleet falls back to the nearest non-hostile port inside the defeat's bounded day cost.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Deterministic RNG & Seed Streams, Content Data & Mod Loading, World Clock`

## Overview

Sector Map & Travel is the campaign's space. At Tier 0 it holds one hand-made
region of 3–5 star systems joined by lanes. Ports, machine nodes and points of
interest sit inside systems. The player's fleet moves lane by lane. On a lane
it moves continuously at the speed of its slowest ship, slowed a little by
fleet size. Every leg's time is an exact integer number of game-seconds,
known before departure. Travel runs on the World Clock's CAMPAIGN rate, so
upkeep, contracts and rivals move while you fly. The route planner holds the
clock and shows each leg's days, arrival day, upkeep and known risks before you
commit. Hostile fleets (roaming machine fleets and the patrols of Hostile
factions) meet you by a fixed geometric rule, never a dice roll. Every contact
is an offer you resolve: Fight, Evade or Turn back. After any loss-class battle
the fleet falls back to the nearest non-hostile port inside the defeat's
bounded day cost, so the way back to a stronghold is short and known. The map
uses no random draws at MVP, and no map fact varies with the seeded maker.

## Player Fantasy

*You are the admiral with the chart table.* Before you leave port you know
how long the trip takes, what it costs, and what you know is out there. The
region is small and becomes familiar: the lane to the Spindle node is a day
and a half, the free port at Halt is one jump back. When a machine patrol
shows up on your lane, you see it coming, and the choice is yours. Losing
never strands you. You wake up in port a few days later, the Dossier open,
and the stronghold is still one known jump away.

*Anchor moment:* the planner shows "Halt → Spindle: 1.97 days, arrive Day 36,
upkeep 1,200, patrolled lane (Spindle roaming fleet)". You go anyway. On day 35
a notice says "Contact: Spindle Lattice, closing, 1.0 day". You turn back,
refit, and come back on the patrol's off day.

Target aesthetics (MDA): **Submission** first (calm, readable travel between
fights; the concept rates it 7), **Challenge** second (choosing when and how to
travel through danger), **Discovery** third (sites revealed by visiting and by
rumours). SDT: **autonomy** through route choice and the three contact
options; **competence** through exact, truthful time and risk previews.

**Pillars served:**
- **Pillar 4, *Plan in the Open*:** every leg's time and upkeep are computed
  before you commit; contact uses a rule the planner can show (rules 12–15,
  D3–D5).
- **Pillar 1, *Every Defeat Is a Lead*:** a loss places you in the nearest
  safe port inside the defeat's day cost; strongholds are authored near ports
  (rules 26–28, 4).
- **Pillar 2, *The Truth Is Yours to Tell*:** the map is where sites are
  revealed, and nothing on it depends on who the maker is (rules 21–25).

## Detailed Design

### Core Rules

**A. The map**

1. **Three base content kinds** (envelope by Content Data Core Rule 7; body
   schemas owned here): `region`, `star_system`, `lane`.
   | Kind | Field | Type | Range | Notes |
   |---|---|---|---|---|
   | `region` | `name_key` | text key | 1 | |
   | `region` | `systems[]` | list of refs → `star_system` | 3 – 5 at Tier 0 | `REGION_SIZE_MIN`/`MAX` |
   | `star_system` | `region_id` | ref → `region` | 1 | |
   | `star_system` | `map_pos` | int pair | 0 – 10,000 each (mu) | map units, region frame |
   | `star_system` | `owner_faction` | ref → `faction` or `none` | 0 – 1 | `none` = unaligned |
   | `star_system` | `port` | ref → port def (#27) or none | 0 – 1 | |
   | `star_system` | `patrol` | fleet def or none | 0 – 1 | used only while the owner is Hostile (rule 18) |
   | `star_system` | `start_known_sites` | bool | — | true = its sites start known (rule 22) |
   | `lane` | `a`, `b` | refs → `star_system` | 2, distinct, same region | undirected |
2. **Sites.** A port, a machine node (#23) or a point of interest (#29) is a
   **site**. A site belongs to the one system whose `map_pos` lies within
   `SYSTEM_RADIUS_MU` (300) of the site's `map_pos`. No such system, or more
   than one, is a validation error (`SITE_OUTSIDE_SYSTEM`). Ports are
   referenced by the system directly.
3. **Validation.** The lane graph of a region must be connected
   (`REGION_DISCONNECTED`). No two lanes join the same pair
   (`LANE_DUPLICATE`). Each lane's length (D1) must lie in
   `LANE_LEN_MIN_MU`–`LANE_LEN_MAX_MU` (200–4,000) (`LANE_LENGTH`). Each region
   needs at least one system with `owner_faction` none and a port: the free
   port (Faction Reputation rule 9) (`REGION_NO_FREE_PORT`). Mods add systems
   and lanes in their own namespace and never move base systems (Content Data
   rule 5).
4. **Strongholds sit near ports.** For every machine node, the shortest path
   time (D3) from its system to the nearest port system, at the reference speed
   `V_REF` (1,000 mu/day), must be at most `RETURN_TRIP_MAX_S` (172,800, two
   days). Otherwise the Runner warns `NODE_FAR_FROM_PORT`. This keeps
   "fail, prepare, return, win" short.

**B. Travel**

5. **Lane by lane.** The player fleet is always in exactly one place: docked at
   a port, in a system (undocked), or on a lane moving from one end to the
   other. There is no stop in the middle of a lane, and no wait command (World
   Clock rule 15). Holding in a system undocked still passes time.
6. **Speed.** Each hull's size class (light, line, heavy, capital, the classes
   Credits rule 4 already bills) has a travel speed in mu per day. The fleet
   moves at the slowest class present among **every ship in the roster**,
   mothballed and lent ships included, scaled down by fleet size (D2). Speed is
   fixed at departure from a system and does not change mid-lane.
7. **Leg time.** A lane's time is `leg_s` (D3), an integer number of
   game-seconds, rounded up. At departure, the fleet registers a `map.arrive`
   event at `depart_s + leg_s` (rule 33). Its position at any `clock_s` is
   computed from `(lane, direction, depart_s, speed)` (D4); it is never
   integrated tick by tick, so arrival never depends on tick rate or speed
   setting.
8. **Travel runs on the CAMPAIGN rate** (World Clock rule 12). Travel is never a
   skip. At 1× speed a one-day leg takes 120 real seconds.
9. **Upkeep runs in travel.** Credits' daily upkeep and suppression upkeep fire
   as normal during travel. The planner quotes them with D5.
10. **Travel restores nothing but organic scars.** Vigor is not restored in
    travel (Vigor rule 16). Organic hulls heal toward their scar line while
    travelling, at the rate Ports, Rest & Care sets (Hulls rule 8). Both happen
    in the World Clock's time; this system only reports "travelling".
11. **Reversing.** At any moment on a lane the player may order Turn back. The
    fleet reverses where it stands and returns to the system it left. The order
    is stamped with its tick (replays repeat it). The `map.arrive` event is
    cancelled and re-registered at the new arrival time.

**C. The route planner**

12. **The planner is a `PLANNING:route_planner` screen.** Opening it holds the
    clock (World Clock rule 3; Simulation Tick & Pause hold list). Reading it
    never costs time.
13. **Paths.** The player picks up to `ROUTE_STOPS_MAX` (4) stops in order.
    Each leg between stops is the path with the least total time (D3 at the
    current fleet speed). Ties go to fewer lanes, then to the lexicographically
    lower sequence of lane IDs. A toggle **Avoid hostile systems** (default on)
    removes systems whose owner is Hostile from the search, unless no other
    path exists; then the path through them is shown with a warning.
14. **The preview** shows, per leg and in total: days (two decimals), arrival
    day, upkeep (D5), suppression upkeep, the visible World Clock events that
    fall due before arrival (contract expiries, known investigator arrivals),
    and known risks (rule 15). The numbers are the same functions the run uses.
15. **Known risks** are: Hostile-owned systems on the path (patrol contact on
    arrival, rule 18); lanes in a revealed roaming route ("patrolled lane");
    and, for a sighted hostile fleet (rule 24), its predicted contact time (D6)
    against the planned path, assuming no new orders on either side.
16. **Commit** is one order stamped with its tick. A committed route can be
    replaced at any time. A new route that starts mid-lane must begin by
    finishing or reversing the current lane.

**D. Encounters**

17. **Who can meet you.** Two kinds of hostile map fleet: **roaming machine
    fleets** (Machine Nodes rule 14), which move on lanes like you, and
    **patrols**, which sit in a Hostile-owned system and never move. Machine
    node garrisons never intercept; a stronghold battle starts only when the
    player chooses Engage at the node's site (rule 20).
18. **Patrols.** A system's `patrol` is active while its `owner_faction` is in
    the Hostile band (Faction Reputation rule 2, `engages_on_sight`). Arriving
    in that system undocked makes contact at the arrival time. A fleet can
    never dock there (Faction Reputation rule 2).
19. **Contact is geometry, not chance.** A roaming fleet and the player fleet
    make contact at the first instant both are on the same lane within
    `INTERCEPT_RANGE_MU` (100) of each other (D6), or both are in the same
    system. A fleet docked at a non-hostile port is never contacted. The time
    is solved exactly when either fleet starts a new segment, and registered as
    a `map.contact` event (rule 33). There are no random draws.
20. **Every contact is an offer** (World Clock rule 11). The handler holds the
    clock and shows the enemy, its readiness range if known, and three choices.
    Nothing auto-starts a battle (this resolves World Clock Open Question 2).
    - **Fight**: a battle starts at the contact point (Battle Resolution).
    - **Evade**: available only when D7 passes. The player fleet holds still for
      `EVADE_DELAY_S` (21,600, a quarter day), then resumes its route. Contact
      with that fleet is suppressed until either fleet ends its current
      segment.
    - **Turn back**: available when the enemy is not behind the player on the
      same lane in the same direction (it is approaching, or the contact is a
      patrol). It works as rule 11, or, in a system, as leaving by the lane the
      fleet arrived on. Contact with that fleet is suppressed as for Evade.
    A greyed choice states why ("Spindle Lattice is faster (800 vs 760)").
    Engaging a machine node is the player's own offer: the Engage button on an
    ACTIVE node's site, available while the fleet is in its system.
21. **Simultaneous contacts** are offered one by one in registration order. If
    a battle ends in the loss class, every other open offer is cancelled,
    because the fleet moves to port (rule 26). After a win-class battle, contact
    times are recomputed from the new positions.

**E. Knowledge and fog**

22. **What is known at the start.** Every system and lane of the region, every
    system's owner faction and port, and every machine node's site and marker
    are known from day 0. Other sites (points of interest) start hidden unless
    their system has `start_known_sites` true.
23. **How sites are revealed.** Arriving in a system reveals all its sites.
    Other systems reveal sites through `reveal(site_id, source)`, called by
    Ports, Rest & Care (port rumours) and Points of Interest (testimony that
    points elsewhere). Visiting a node's system, or a reveal naming the node,
    reveals its roaming route. A reveal is permanent.
24. **Sighting.** A hostile map fleet is sighted while it is in, or on a lane
    touching, the system the player fleet is in or is travelling to. Sighting is
    re-evaluated at segment starts, so it never depends on tick size. A sighted
    fleet is drawn live and its next contact time is shown. A notice
    ("Contact: Spindle Lattice, closing, 1.0 day") fires once when a fleet first
    becomes sighted with a predicted contact.
25. **Truth-neutral.** Every system, lane, site position, patrol, route and
    reveal is authored and seed-independent. Truth Seeding fills fragment
    content only. No map fact, marker, reveal or contact varies with the seeded
    maker. Hostility reaches the map only through the faction band, which is
    truth-blind (Faction Reputation rule 8).

**F. After a battle**

26. **Loss class: fall back to port.** After a PLAYER_RETREATED, DEFEAT or
    STANDOFF (Battle Resolution rule 5), when the Debrief closes, the World
    Clock runs the defeat skip (Debrief D5). At the skip's end the fleet is
    **docked at the fallback port** (D8): the nearest port, by path time from
    the battle's position, whose owner is not Hostile. The trip is inside the
    skip; it costs no extra time. The free port (rule 3) guarantees one exists.
    The opening loss uses the same placement with its zero-day skip.
27. **Every ship comes back.** Player ships are disabled, never lost (Battle
    Resolution rule 7); left-behind ships return through the defeat bill
    (Credits rule 7). So the fleet arriving at the fallback port is the whole
    roster. A fleet with no ships cannot occur (Edge Cases).
28. **Win class: carry on.** After VICTORY or ENEMY_WITHDREW, the fleet stays at
    the contact point and resumes its committed route once the clock returns to
    CAMPAIGN. The lane's remaining time is unchanged by the battle; battle time
    has already passed on the clock. A withdrawn roaming fleet turns RETURNING
    (Machine Nodes rule 15); a destroyed one is removed.
29. **Broken nodes.** Arriving in the system of a BROKEN_UNCLAIMED node counts as
    "a player fleet reaches the node" (Machine Nodes rule 17), and the fragment
    is granted on arrival.

**G. Roaming fleets on the map**

30. **Roaming fleets use lanes.** A roaming route's waypoints are systems,
    each joined to the next by a lane; the first is the node's own system. A
    roaming fleet moves at its own D2 speed, waits `ROAM_DWELL_S` (21,600) at
    each waypoint, and loops (Machine Nodes rule 14). RETURNING reverses the
    route it was on. The map owns its position; Machine Nodes owns its ships.

**H. Determinism, events and save**

31. **No random draws at MVP.** Map layout is authored; speeds, paths, contacts
    and fallback ports are pure integer functions. Roaming spawn phase is Machine
    Nodes' draw (`base:node.roam#<node_id>`). Tier 1 procedural generation will
    declare its own campaign streams (Deterministic RNG Core Rule 6).
32. **Battle seeds.** A contact battle's seed is
    `H(campaign_seed, enemy_fleet_id, encounter_index)` through Deterministic
    RNG's battle-seed derivation; `encounter_index` is a saved counter, +1 per
    contact battle. Stronghold battles keep `node_seed` (Machine Nodes rule 5).
33. **Event kinds** (World Clock rule 6):
    | Kind | Priority | Visible | `interrupts_skip` | Fires |
    |---|---|---|---|---|
    | `map.arrive` | 300 | yes (player fleet) | no | a fleet reaches a system |
    | `map.roam_step` | 200 | if sighted | no | a roaming fleet ends a segment |
    | `map.contact` | 200 | if sighted | yes | contact (rule 19); handler makes the offer |
    A docked fleet is never contacted, so a port rest is never interrupted by
    this system. Every handler acts at `due_s` (World Clock rule 7).
34. **Save section `base:sector_map`**, version 1, loads after
    `base:world_clock` and before `base:machine_nodes`. It holds: the player
    fleet's place (`DOCKED`/`IN_SYSTEM` + system, or lane, direction,
    `depart_s`, speed), its committed route, pending event `seq`s, contact
    suppressions, `encounter_index`, revealed site flags, and each roaming
    fleet's segment. Ceiling 16,384 bytes. Positions are recomputed from saved
    segments, never stored as floats.

### States and Transitions

Player fleet place (stored):

| State | When | Clock | Leaves to |
|---|---|---|---|
| DOCKED | at a non-hostile port | CAMPAIGN rate (or rest skip, #27) | IN_SYSTEM (undock), IN_TRANSIT (depart) |
| IN_SYSTEM | in a system, not docked | CAMPAIGN rate | DOCKED, IN_TRANSIT, OFFER (contact or Engage) |
| IN_TRANSIT | on a lane | CAMPAIGN rate | IN_SYSTEM (`map.arrive`), OFFER (`map.contact`), IN_TRANSIT (Turn back) |
| EVADING | holding still after Evade | CAMPAIGN rate | IN_TRANSIT / IN_SYSTEM (delay over) |
| OFFER | an encounter offer is open | held | IN_BATTLE (Fight), EVADING, IN_TRANSIT (Turn back) |
| IN_BATTLE | battle running | BATTLE rate | IN_TRANSIT / IN_SYSTEM (win class), FALLING_BACK (loss class) |
| FALLING_BACK | defeat skip running | skip | DOCKED at the fallback port |

Roaming fleet (map side): PATROL_MOVING, PATROL_DWELL, RETURNING, REFITTING
(at home, Machine Nodes rule 15), IN_BATTLE, removed.

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| World Clock (#8) | both | Travel at CAMPAIGN rate; registers `map.*` events; offers under rule 11; runs the defeat skip after which #26 places the fleet |
| Simulation Tick & Pause (#1) | #26 → #1 | `PLANNING:route_planner` and `PLANNING:encounter_offer` holds |
| Content Data (#3) | #3 → #26 | `region`, `star_system`, `lane` kinds; validation codes in rule 3 |
| Deterministic RNG (#2) | #26 → #2 | No draws at MVP; contact battle seed (rule 32) |
| Credits, Upkeep & Sinks (#18) | #18 → #26 | `quote_upkeep()` and suppression upkeep for D5; mothballed ships reactivate at the fallback port |
| Faction Reputation (#17) | #17 → #26 | Band per faction; Hostile = patrols active, no docking |
| Machine Nodes (#23) | both | Node site and marker; roaming route, spawn and RETURNING; map moves roaming fleets; arrival claims BROKEN_UNCLAIMED fragments |
| Battle Resolution (#22) | both | #26 gives the encounter setup; #22 returns outcome class |
| After-Action Debrief (#24) | #24 → #26 | D5 day cost; Debrief names the fallback port |
| Ports, Rest & Care (#27) | both | Port defs per system; docking; rest; `reveal()` from rumours |
| Points of Interest (#29) | both | Sites in systems; `reveal()` |
| Markets (#37), Contracts (#38), Colonies (#42) | #26 → them | System and port IDs; `travel_time()` |
| Exposure (#32) | #26 → #32 | `travel_time(a, b, speed)` for investigator legs; markers for known investigators |
| Ledger (#48) | #26 → #48 | Travel days and upkeep per leg |
| Hulls (#10) | #10 → #26 | Size class per hull; "Travelling" = IN_TRANSIT, IN_SYSTEM, EVADING |

## Formulas

### D1. Lane length

`L = isqrt(dx² + dy²)`, `dx`, `dy` = difference of the two systems' `map_pos`,
computed in 64-bit integers; `isqrt` is the integer floor square root.

| Variable | Range | Description |
|---|---|---|
| dx, dy | −10,000 – 10,000 | mu |
| L | 200 – 4,000 | mu (rule 3) |

Example: (1,000, 2,000) to (1,900, 3,200): dx 900, dy 1,200; 810,000 +
1,440,000 = 2,250,000; isqrt = **1,500**.

### D2. Fleet speed

`v = max(V_MIN, v_slow × max(SIZE_FLOOR_PM, 1,000 − SIZE_DRAG_PM × max(0, n − SIZE_FREE_N)) div 1,000)`

| Variable | Default | Range | Description |
|---|---|---|---|
| v_slow | — | 600 – 1,200 | Speed of the slowest class present (`SPEED_*`) |
| n | — | 1 – 30 | Ships in the roster (rule 6) |
| SIZE_FREE_N | 4 | 2 – 8 | Ships carried with no drag |
| SIZE_DRAG_PM | 25 | 0 – 50 | Drag per extra ship |
| SIZE_FLOOR_PM | 700 | 500 – 1,000 | Least size factor |
| V_MIN | 300 | 200 – 600 | Hard floor, mu/day |

Example: 6 ships, the slowest heavy (800). Factor = 1,000 − 25 × 2 = 950.
v = 800 × 950 div 1,000 = **760** mu/day.

### D3. Leg time

`leg_s = (L × DAY_S + v − 1) div v` (rounded up), `DAY_S` = 86,400.

Example: L 1,500, v 760: 129,600,000 / 760 = 170,526.3 → **170,527 s** (1.97
days; 237 real seconds at 1×). At `V_REF` 1,000: **129,600 s** (1.50 days).

### D4. Position on a lane

Positions use scaled units `q = mu × DAY_S`, so they stay exact.
`q(t) = q0 + dir × v × (t − t0)`, for `t0 ≤ t ≤ t0 + leg_s`, clamped to
`[0, L × DAY_S]`. Shown position = `q div DAY_S`. `dir` is +1 from `a` to `b`,
−1 back; `q0` is 0 or `L × DAY_S` at a system, or the reversal point (rule 11).

### D5. Travel upkeep preview

`days_charged = (t_arrive div DAY_S) − (t_depart div DAY_S)`;
`cost = days_charged × (U_day + S_day)`.

`U_day` = `quote_upkeep()`; `S_day` = daily suppression upkeep (Credits rule
9). It assumes the upkeep event is due at each day start (Open Question 3).

Example: depart `clock_s` 3,000,000 (day 34), leg 170,527 → arrive 3,170,527
(day 36, since 36 × 86,400 = 3,110,400 ≤ it < 3,196,800). days_charged = **2**;
at `U_day` 600, `S_day` 0: **1,200** credits.

### D6. Contact time on a lane

At `t* = max(t0_player, t0_enemy)`, with both on the same lane:
`g = |q_e(t*) − q_p(t*)|`; closing rate `c = −sign(q_e − q_p) × (dir_e × v_e − dir_p × v_p)`.
- if `g ≤ R × DAY_S`: `t_c = t*`;
- else if `c ≤ 0`: no contact on this lane;
- else `t_c = t* + (g − R × DAY_S + c − 1) div c`.
Valid only if `t_c` ≤ both segments' end. `R` = `INTERCEPT_RANGE_MU`.

Example: player a→b, v 760; roaming b→a, v 600; both depart 0; L 1,500.
g = 129,600,000; c = 1,360; R × DAY_S = 8,640,000.
t_c = (120,960,000 + 1,359) div 1,360 = **88,942 s** (1.03 days). Check: at
88,942 the gap is 129,600,000 − 120,961,120 = 8,638,880 ≤ 8,640,000 (contact);
at 88,941 it is 8,640,240 (none). Shown positions: player 782, roaming 882 (76,234,800 div 86,400).

In a system: `t_c = max(entry_p, entry_e)` when both stay intervals overlap.

### D7. Evade check

Evade is available iff `v_p × 1,000 ≥ v_e × EVADE_RATIO_PM`, and, for a patrol,
the system is not a route stop.

Example: v_p 760, v_e 600, `EVADE_RATIO_PM` 1,000: 760,000 ≥ 600,000, **yes**.
v_e 800: 760,000 < 800,000, **no**.

### D8. Fallback port

`fallback = argmin over ports p, owner(p) not Hostile, of path_s(pos, p)`,
ties to the lower port ID. `path_s` from a mid-lane position is the lesser of
(time to end `a` + shortest path from `a`) and (time to `b` + path from `b`), at
the fleet's current speed (D2, D3).

## Edge Cases

- **Roster empty** (only by a mod or bug; the flagship cannot be lost): placement
  logs `MAP_EMPTY_FLEET` and docks the flagship record at the free port.
- **Every port Hostile except the free port**: the free port is the fallback
  (rule 3). If a mod removes it, the region fails `REGION_NO_FREE_PORT` at load.
- **Fallback port farther than the defeat skip**: the skip still places the fleet
  there; the trip is inside the bounded cost. A deliberate loss to "teleport" is
  never cheaper than flying: it costs at least one day (`DEFEAT_FLOOR_S`) plus a
  bill, and it can only take you to the nearest safe port, which rule 4 keeps
  within two days of any node.
- **Contact at the exact moment of arrival**: `map.contact` (200) fires before
  `map.arrive` (300) at the same instant, so the battle happens on the lane end.
- **Overtaking a slower enemy on the same lane**: contact when within R; Turn back
  is available (the enemy is ahead); Evade passes D7.
- **Faster enemy behind you**: Turn back and Evade are unavailable; the offer
  shows Fight alone and says why. Seeing it earlier (rule 24) is the warning.
- **Two contacts at one instant**: offered in `seq` order (rule 21).
- **Reverse order then reverse again**: allowed; each is a new segment.
- **Clock at the half-day battle cap**: the fleet resumes at the contact point;
  roaming events deferred in battle fire in catch-up, and contacts are
  recomputed after catch-up.
- **Mothballing to go faster**: mothballed ships still count (rule 6), so it
  gives nothing.
- **Hostility changes mid-lane** (e.g. a public naming): a destination port that
  turns Hostile is flagged; the route continues; arrival makes patrol contact.
- **Roaming fleet's home goes INERT while it is out**: Machine Nodes rule 15
  picks the new home; the map routes it by D3 paths.
- **`leg_s` overflow**: L ≤ 4,000 and v ≥ 200 bound `leg_s` at 1,728,000 s; 64-bit
  maths throughout.
- **Planner opened during an offer**: refused; the offer must be resolved first.

## Dependencies

| System | Type | Need |
|---|---|---|
| Deterministic RNG & Seed Streams (#2) | Hard | Battle-seed derivation; Tier 1 streams |
| Content Data & Mod Loading (#3) | Hard | The three kinds and validation |
| World Clock (#8) | Hard | Rate, events, offers, skip |
| Simulation Tick & Pause (#1) | Hard | Holds |
| Hulls (#10) | Hard | Size class |
| Credits (#18), Faction Reputation (#17) | Soft | Upkeep quotes; bands |
| Machine Nodes (#23), Battle Resolution (#22), Debrief (#24) | Hard (both) | Nodes, battles, day cost |
| Ports (#27), POI (#29), Markets (#37), Contracts (#38), Colonies (#42), Exposure (#32), Ledger (#48) | Hard (reverse) | System IDs, `travel_time()`, `reveal()` |

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `SPEED_LIGHT` / `LINE` / `HEAVY` / `CAPITAL` | 1,200 / 1,000 / 800 / 600 mu/day | 400 – 2,000 | Curve | Trip time by fleet make-up |
| `SIZE_FREE_N` | 4 | 2 – 8 | Curve | Small-fleet freedom |
| `SIZE_DRAG_PM` | 25 | 0 – 50 | Curve | Cost of a big fleet |
| `SIZE_FLOOR_PM` | 700 | 500 – 1,000 | Curve | Worst size slowdown |
| `V_MIN` | 300 | 200 – 600 | Gate | Hard speed floor |
| `V_REF` | 1,000 | 600 – 1,200 | Gate | Rule 4 check |
| `RETURN_TRIP_MAX_S` | 172,800 | 86,400 – 259,200 | Gate | How short the way back is |
| `LANE_LEN_MIN_MU` / `MAX_MU` | 200 / 4,000 | 100 – 6,000 | Gate | Leg time span |
| `SYSTEM_RADIUS_MU` | 300 | 100 – 500 | Gate | Site placement |
| `INTERCEPT_RANGE_MU` | 100 | 50 – 300 | Feel | How easily you meet fleets |
| `EVADE_DELAY_S` | 21,600 | 0 – 43,200 | Feel | Price of evading |
| `EVADE_RATIO_PM` | 1,000 | 800 – 1,200 | Curve | Who can evade whom |
| `ROAM_DWELL_S` | 21,600 | 0 – 86,400 | Feel | Roaming predictability |
| `ROUTE_STOPS_MAX` | 4 | 2 – 8 | Gate | Planner size |
| `REGION_SIZE_MIN` / `MAX` | 3 / 5 | 3 – 12 | Gate | Tier 0 scope |

Constraint: `SPEED_*` ≥ `V_MIN`; `LANE_LEN_MAX_MU × DAY_S div V_MIN` ≤ `SKIP_MAX_S`.

## Visual/Audio Requirements

- Systems as nodes on a flat chart; lanes as lines; a patrolled lane dashed.
- Site icons per kind. Node markers use Machine Nodes' three shapes (ACTIVE,
  BROKEN_UNCLAIMED, INERT); shape, not colour alone, carries state.
- Hostile-owned systems ringed and labelled, not colour-only.
- Sighted fleets drawn live; unsighted ones not drawn. A soft contact chime on
  the sighting notice and on an offer. Art and audio direction belong to their
  directors.

## Game Feel

- Travel is calm. The fleet glides along the lane; the day counter ticks.
- A contact is announced before it happens whenever the enemy is sighted;
  surprise only comes from what you could not see, never from a roll.
- Planner numbers never lie: arrival and upkeep match the run exactly when no
  new orders or offers occur.

## UI Requirements

- Route planner (PLANNING): stops, per-leg and total days, arrival day,
  upkeep, suppression upkeep, visible events before arrival, known risks,
  Avoid-hostile toggle, Commit.
- Offer panel: enemy name, readiness range if known, Fight / Evade / Turn back
  with reasons for greyed options.
- Fleet tooltip: speed and the ship setting it ("slowest: Bastion, heavy").
- Debrief line after a loss: "You fall back to Halt (docked, Day 41)".
- UX spec to follow in `design/ux/sector-map.md` (ux-designer).

## Cross-References

| Topic | Document | Section |
|---|---|---|
| CAMPAIGN rate, events, offers, skips | `design/gdd/world-clock.md` | Rules 3, 6–15; OQ 2 |
| Planning holds | `design/gdd/simulation-tick-and-pause.md` | Hold list |
| Upkeep, defeat bill, suppression | `design/gdd/credits-upkeep-and-sinks.md` | Rules 4–9 |
| Bands, Hostile, free port | `design/gdd/faction-reputation-and-standing.md` | Rules 2, 8, 9; OQ 3 |
| Nodes, roaming, broken | `design/gdd/machine-nodes-and-strongholds.md` | Rules 1, 1a, 5, 14–17 |
| Defeat day cost | `design/gdd/after-action-debrief.md` | D5 |
| Outcome classes, disabled ships | `design/gdd/battle-resolution-and-retreat.md` | Rules 5, 7, 15 |
| Travel healing, ship states | `design/gdd/hulls-and-ship-definition.md` | Rule 8; States |
| Vigor not restored in travel | `design/gdd/vigor.md` | Rule 16 |

## Acceptance Criteria

- **AC-01 (Logic; rule 3)**: a region with a disconnected system fails `REGION_DISCONNECTED`; one with no unaligned port fails `REGION_NO_FREE_PORT`; a 150 mu lane fails `LANE_LENGTH`.
- **AC-02 (Logic; rule 2)**: a site 301 mu from every system fails `SITE_OUTSIDE_SYSTEM`; a site within 300 mu of two systems fails too.
- **AC-03 (Logic; rule 4)**: a node whose nearest port is 2.1 days at `V_REF` raises `NODE_FAR_FROM_PORT`.
- **AC-04 (Logic; D1)**: (1,000, 2,000) to (1,900, 3,200) gives L 1,500.
- **AC-05 (Logic; D2)**: 6 ships with a heavy slowest give 760; 30 light ships give 1,200 × 700 div 1,000 = 840.
- **AC-06 (Logic; rule 6)**: mothballing the only heavy ship leaves fleet speed unchanged.
- **AC-07 (Logic; D3)**: L 1,500 at 760 gives 170,527 s; at 1,000 gives 129,600 s.
- **AC-08 (Logic; rule 7)**: the same leg arrives at the same `clock_s` at 60 Hz and 30 Hz, and at 1× and 2× speed.
- **AC-09 (Logic; rule 8)**: no skip runs during travel; `clock_s` advances by 12 per tick at 60 Hz while IN_TRANSIT.
- **AC-10 (Logic; D5)**: depart 3,000,000, leg 170,527, `U_day` 600 previews 1,200, and Credits charges exactly 1,200 fleet upkeep over the leg.
- **AC-11 (Logic; rule 12)**: with the planner open for 600 frames, `clock_s` is unchanged.
- **AC-12 (Logic; rule 13)**: two equal-time paths choose the one with fewer lanes, then the lower lane-ID sequence.
- **AC-13 (Logic; rule 13)**: with Avoid hostile on, a path avoids a Hostile system when another path exists, and shows the warning when none does.
- **AC-14 (Logic; rule 14)**: the planner's arrival `clock_s` equals the actual `map.arrive` time when no order or offer intervenes.
- **AC-15 (Logic; D6)**: the head-on example contacts at exactly 88,942 s.
- **AC-16 (Logic; rule 19)**: a fleet docked at a non-hostile port is never contacted by a roaming fleet passing through the system.
- **AC-17 (Logic; rule 20)**: no contact starts a battle until the player picks Fight; 600 frames with an offer open leave `clock_s` unchanged.
- **AC-18 (Logic; D7)**: Evade is offered at 760 vs 600 and greyed at 760 vs 800 with the reason shown.
- **AC-19 (Logic; rule 20)**: Turn back is greyed when a faster enemy closes from behind in the same direction.
- **AC-20 (Logic; rule 20)**: after Evade, the same fleet does not contact again until either fleet ends its segment.
- **AC-21 (Logic; rule 18)**: arriving undocked in a Hostile-owned system with a patrol makes contact at the arrival time; at Wary, no contact.
- **AC-22 (Logic; rules 26, D8)**: after a DEFEAT mid-lane, the fleet is DOCKED at the nearest non-Hostile port (ties to lower port ID) at `clock_s` = battle end + `defeat_skip_s`, with every roster ship present.
- **AC-23 (Logic; rule 21)**: a loss-class battle cancels every other open contact offer.
- **AC-24 (Logic; rule 28)**: after a VICTORY on a lane, the remaining leg time equals the remaining time before the contact.
- **AC-25 (Logic; rule 29)**: arriving in a BROKEN_UNCLAIMED node's system grants its fragment once, with no battle.
- **AC-26 (Logic; rules 22, 23)**: a POI in a system with `start_known_sites` false is hidden at day 0, shown after arrival or a `reveal()`, and never hidden again.
- **AC-27 (Logic; rule 25)**: two saves with different seeded makers and identical orders give byte-identical `base:sector_map` sections and identical contact times through day 30.
- **AC-28 (Logic; rules 31, 34)**: save and reload mid-lane give the same position, arrival time and pending contacts; a full replay from the same seed and orders gives an identical `base:sector_map` hash.
- **AC-29 (Logic; rule 33)**: a contact and an arrival due at the same `due_s` fire contact first.
- **AC-30 (Playtest; rule 4)**: 4 of 5 players describe the trip back to a stronghold after a defeat as "short" or "fine", not "tedious".
- **AC-31 (Playtest; rules 14, 24)**: 4 of 5 players who meet a sighted roaming fleet say they saw it coming.

## Open Questions

Resolved with the recommended defaults (the owner may revisit at review):
- **Travel model**: lane by lane, continuous on the lane, never a skip.
- **No auto-started battles**: every contact is player-resolved (World Clock OQ 2).
- **Mothballed and lent ships count toward speed** (closes a cheap speed exploit).
- **Defeat placement inside the skip** (rule 26): the trip to the fallback port
  happens inside the defeat's bounded day cost, so a loss never adds an
  unbounded flight home.
- **Faction patrols at MVP** (rule 18): Hostile systems keep patrols.
- **Size class**: Hulls already defines `size_class` (light, line, heavy,
  capital; Hulls rule 3).
- **The offer hold** uses the existing planning mechanism:
  `PLANNING:encounter_offer` (Tick rule 10 list amended).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 3 | **Upkeep due time**: D5 assumes Credits' daily upkeep falls due at each day start (`d × DAY_S`). | Credits (#18) | #18 re-review |
| 6 | **Contact battle seed** (rule 32) fits RNG's battle-seed derivation. | RNG (#2) | #2 re-review |
| 8 | **Truth-blind starting standings**: confirm no starting band depends on the seeded maker; otherwise patrols would leak the truth. | Faction Reputation (#17), Belief & Blame (#30) | #17 re-review |
| 9 | **Battle space for a lane or system contact** (terrain, deployment). | Battle Resolution (#22), level-designer | Before encounter content |
| 10 | **Pace**: lane lengths, `SPEED_*` and `RETURN_TRIP_MAX_S` against rival pace and contract lengths. | game-designer | First campaign playtest |
