# Ports, Rest & Care

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (defeat cost shown with the longest recovery rest; care once per ship per expedition; interrupt kinds and investigator steps named)
> **Implements Pillar**: Pillar 5 (Living Against Made — organic Vigor is restored only by rest and care in port, never vented); Pillar 1 (Every Defeat Is a Lead — the port is where a loss turns into a plan); Pillar 4 (Plan in the Open — every service shows its days and price before you commit)

## Summary

Ports, Rest & Care is the port hub: free, instant docking by faction band (a free port always docks you), a header that shows wallet, upkeep and the defeat cap, and the hook later services plug into. Rest is one previewed skip that restores the Vigor ceiling and organic hull, scars included, paid in days and upkeep; care restores Vigor fully with no days, paid in the owning organic faction's standing. After a defeat the fleet arrives docked at the fallback port with the rest panel open, and no port fact depends on the seeded maker.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `World Clock, Vigor, Faction Reputation & Standing, Sector Map & Travel`

## Overview

Ports, Rest & Care owns the port: the one place a fleet docks, rests and
restores. A port is a site on a star system (Sector Map & Travel rule 1). It
has an owner, which is the system's owner faction or `none`. Its owner's band
decides whether the fleet may dock (Faction Reputation & Standing rule 3).
Docking and undocking are free and instant. **Rest** is the only explicit wait
in the game (World Clock rule 15). It is one World Clock skip that restores
every organic ship's Vigor ceiling (Vigor rule 16) and clears hull damage,
scars included (Hulls & Ship Definition rule 8). It costs days, and those days
cost upkeep (Credits, Upkeep & Sinks rule 4). It never costs a fee. **Care**
is the living races' alternative: at a faction's own port, a ship's Vigor
ceiling is restored at once, paid in that faction's standing (Vigor rule 17,
Faction Reputation D2). It costs no days. Every region has a **free port**
with no owner, which can never refuse docking, so a rest is always reachable
(Faction Reputation rule 9). The port is also the **hub** for later services:
market, refit, contracts, salvage, lay-up and rumours. This GDD defines the
hub and the hooks they plug into, not those services. Every port screen is a
planning hold (`PLANNING:*`), so reading never costs days. The hub header
shows credits, daily upkeep and the defeat-cost cap, so nothing about the
economy is hidden.

## Player Fantasy

*You limp into Halt with four ships at their scar lines and the bow core of
the Wren burned down to a quarter. The port screen holds the clock. The header
reads 3,410 credits, 420 a day, defeat cap 10,800. The rest panel says "Until
full: 4 days 6 hours, 1,680 upkeep. Visible before it ends: Corvane contract
expires, day 41." You could buy the Wren's ceiling back from the Spiralward at
their port two jumps on, for 21 standing. You rest. On day 41 the contract
lapses, as the panel said it would. The fleet undocks whole, and you know
exactly what the loss cost.*

Target aesthetics (MDA): **Challenge** through **Submission**. The port is the
exhale in the sawtooth: tension builds over an expedition, and the port
releases it at a price the player chose. The player should feel *I am
choosing between days, credits and goodwill*, never *I am waiting*.

- **Pillar 5, *Living Against Made*:** organic Vigor and scars come back only
  through rest or care in port (rules 10, 16). Nothing vents them.
- **Pillar 1, *Every Defeat Is a Lead*:** after a loss, the fleet docks at the
  fallback port with the Debrief behind it and the rest previewed (rule 24).
  A free port is always in reach.
- **Pillar 4, *Plan in the Open*:** every rest shows its length, its upkeep
  and the visible events inside it before it starts. Every care purchase shows
  its standing price and band change first (rules 13, 17).
- **Pillar 2, *The Truth Is Yours to Tell*:** which ports offer care is a pure
  function of authored ownership. It never depends on the seeded maker
  (rule 28).

SDT: **Autonomy** (three viable recoveries: rest, care, or press on wounded);
**Competence** (the preview teaches exactly what a battle cost);
**Relatedness** (care is goodwill from a living race, spent on your crew).

## Detailed Design

### Core Rules

**A. The port**

1. **One content kind, `port`** (envelope by Content Data Core Rule 7; body
   schema owned here). A `star_system` references at most one port (Sector Map
   rule 1).
   | Field | Type | Range | Notes |
   |---|---|---|---|
   | `name_key` | text key | 1 | |
   | `site_pos` | int pair | 0 – 10,000 (mu) | within `SYSTEM_RADIUS_MU` of its system (Sector Map rule 2) |
   | `services[]` | list of service IDs | 1 – 12 | `rest` is mandatory and implied; see rule 3 |
   | `rumours[]` | list of refs → site | 0 – `RUMOURS_MAX` (4) | revealed on first docking (rule 27) |
   | `repair_facility` | bool | — | machine hull repair (hook, rule 21); false at MVP |
2. **The owner is never authored on the port.** A port's owner is its
   system's `owner_faction`. Owner `none` makes it a **free port**. One source
   of ownership means the port and the map can never disagree.
3. **Services.** Base service IDs: `rest`, `care`, `fleet` (lay-up and
   reactivation), `rumours`, `market`, `refit`, `contracts`, `salvage`,
   `repair`. Mods add IDs in their own namespace (Content Data rule 5).
   - `rest`, `fleet` and `rumours` are always present. Content may not remove
     them.
   - **`care` is derived, never authored.** A port offers care if and only if
     its owner is a faction whose `organic` flag is true. Content listing or
     omitting `care` is a validation error (`PORT_CARE_AUTHORED`). Free ports
     never offer care: they have no ledger row to spend.
   - `market`, `refit`, `contracts`, `salvage` and `repair` are authored per
     port. Each is shown only if its owning system has registered a provider
     (rule 22). At MVP no provider is registered, so they show as "not yet
     available".
4. **Validation** (content load, all errors): `PORT_CARE_AUTHORED` (rule 3);
   `PORT_NO_SYSTEM` (no system references the port); `PORT_SHARED` (two
   systems reference one port); `PORT_RUMOUR_UNKNOWN` (a rumour names no
   site); `PORT_RUMOUR_SELF` (a rumour names a site in the port's own system,
   which arrival already reveals). The free-port rule per region stays with
   Sector Map (`REGION_NO_FREE_PORT`, Sector Map rule 3).

**B. Docking**

5. **Who may dock.** A free port always allows docking. A faction port allows
   it when `can(owner, dock)` is true, which is band Wary or above (Faction
   Reputation rule 3). A Hostile port refuses, and the refusal names the band.
6. **Docking is free and instant.** In IN_SYSTEM at a system with a port, the
   order Dock moves the fleet to DOCKED in the same tick. No fee, no time. The
   route planner may mark a route's last system "dock on arrival" (default on
   when that system has a dockable port). Then `map.arrive` docks the fleet in
   its handler. An order is stamped with its tick, so a replay repeats it.
7. **Undocking is free and instant.** Undock moves the fleet to IN_SYSTEM.
   Depart (a route order) undocks and departs in the same tick (Sector Map
   states).
8. **Docked time passes at the CAMPAIGN rate and restores nothing.** Upkeep
   and events run as normal. Only a rest (section C) restores. This keeps rest
   the one explicit wait (World Clock rule 15) and keeps every restoration
   previewed. A docked fleet is never contacted (Sector Map rule 33).
9. **Losing docking rights while docked.** If the owner's band falls to
   Hostile while the fleet is docked, then at that event's instant:
   - a running rest stops (rule 15) and cannot be resumed;
   - the fleet is moved to IN_SYSTEM;
   - a notice and hold explain why ("Spiralward ports closed to you").
   The hostility event already has `interrupts_skip` (World Clock rule 14).

**C. Rest**

10. **What rest restores.** For each ship in the active roster and each
    mothballed ship travelling with the fleet:
    - an organic ship's Vigor ceiling `C` (per core) rises toward `C0` at
      `REST_RESTORE_PM_PER_DAY` (Vigor rule 16, D4);
    - an organic ship's hull rises toward its maximum, scars included, at
      `PORT_HULL_PM_PER_DAY` (150 ‰ of max hull per game day; D2);
    - a machine ship's hull is not restored by rest. It needs a repair
      facility (rule 21). At MVP the player has no machine hulls (Credits
      rule 3).
    Rest restores nothing else. Crew is not a system at MVP. Laid-up ships
    rest only if the rest happens at their port.
11. **Each ship's need.** `need_s(ship)` is the composed length to restore
    that ship fully: the longer of its Vigor time and its hull time, then
    composed with `rest_days_permille` (D1, D3). The ships rest in parallel,
    so the fleet's full rest `L_full` is the longest `need_s`, capped at
    `SKIP_MAX_S` (World Clock rule 13).
12. **Choosing a length.** The Rest panel offers:
    - **Until full** (default): length `L_full`;
    - **Days**: a length in steps of `REST_STEP_S` (21,600, a quarter day), from
      one step up to `L_full`, with the last step clipped to `L_full`.
    A rest longer than `L_full` is not offered: rest is never a free wait. If
    `L_full` is 0 (nothing to restore), Rest is unavailable with the reason
    "Fleet fully restored".
13. **The preview.** Before the player commits, the Rest panel shows, for the
    chosen length `L`:
    - each ship's Vigor ceiling and hull, now and after (D4), as values and as
      a share of maximum;
    - `L` in days and hours, and the day it ends;
    - the upkeep it will cost: fleet upkeep and suppression upkeep for the
      daily charges inside the rest (D5), and whether the wallet covers them
      (ships that would be mothballed are named, in lay-up order);
    - every queued World Clock event with `visible` true and `due_s` inside
      the rest, in queue order (World Clock rule 6);
    - what may interrupt it, by kind: "May be interrupted by: hostility,
      exposure, case events", then "Investigator progress due inside this
      rest:" with each known investigator step due inside `L` (the concept
      says investigators work visibly on the clock).
    The panel is `PLANNING:port_rest`, so it costs no days.
14. **Starting a rest** is an order `rest(L)`. It records `{start_s, L,
    per-ship deficits and need_s}`, registers `port.rest_done` at
    `start_s + L` (priority 300, visible, not `interrupts_skip`), and asks the
    World Clock for one `skip(L, reason = port_rest)`. A rest is one skip. It
    never chains skips, and it is never longer than `SKIP_MAX_S`.
15. **Interruption.** An `interrupts_skip` event (World Clock rule 14) stops
    the skip at its instant. The rest record stays open, and the hold offers
    **Resume** (the same skip continues to the same target) or **End rest**.
    Ending applies restoration for the time elapsed so far (D4). Rule 9 ends
    it with no choice. Resume and End are orders stamped with their tick.
16. **Restoration is applied once,** when the rest ends: at `port.rest_done`,
    at End rest, or by rule 9. It uses the total elapsed rest time `t` (D4),
    so an interrupted then resumed rest restores the same as an unbroken one.
    The amount is pro rata to elapsed time (Vigor rule 16).
17. **Rest is paid in upkeep and nothing else.** Credits' daily charges fire
    inside the skip (Credits rule 4). This system adds no rest fee (Credits
    rule 13, condition c). If the wallet empties mid-rest, Credits mothballs
    ships by lay-up order (Credits rule 6). The rest continues, and mothballed
    ships still rest.

**D. Care**

18. **What care is.** At a port offering care (rule 3), for one organic ship
    at a time, the player may buy a **full Vigor restore**: `C` returns to `C0`
    on every core. The price is `quote_care(owner, ship)` (Faction Reputation
    D2), paid as an atomic standing spend with the port's owner. On `OK`, this
    system calls `restore(ship, C0 − C, source = care)` (Vigor rule 17). It
    costs no days and no credits.
19. **Care's limits.**
    - Care restores Vigor only. It does not close hull damage or scars; those
      need rest (rule 10). So credits can never buy instant scar clearing, and
      standing cannot either (Credits rule 13, condition b).
    - Care is full or nothing. A partial restore is not offered at MVP (Open
      Question 3).
    - Care is unavailable when `quote_care` returns UNAVAILABLE: the ship's
      ceiling is full, the band is Wary or Hostile, or the hull is a machine
      hull (Faction Reputation D2 and Edge Cases).
    - Care is refused if the spend would take standing below `SPEND_FLOOR`
      (Faction Reputation rule 5). The quote says so before the player
      confirms.
    - Care is never raised above `C0` (Vigor rule 17).
    - **Care may be bought for a ship at most once per expedition.** An
      expedition ends when a rest brings that ship to full (`need_s` reached);
      care is then available again. Care stays the living races' mid-voyage
      gift and rest the true reset, so the ceiling never becomes a bar to fill
      and vent (Pillar 5's flux test). A second care before a full rest is
      unavailable, with the reason shown.
20. **The care quote** shows the standing price, standing before and after,
    and the band change through `preview` (Faction Reputation rule 11). The
    Care screen is `PLANNING:port_care`.

**E. Repair, recovery and the hub**

21. **Hull repair and recovery.**
    - **Organic hulls** heal toward their scar line while travelling, at
      `TRAVEL_HEAL_PM_PER_DAY` (200 ‰ of max hull per game day; D6). Healing
      never passes the scar line. It is applied at each segment end (D6), never
      tick by tick. The defeat skip counts as travelling (the fleet limps
      home), so ships reach the fallback port at most at their scar line.
      Scars clear only by rest (rule 10). This keeps the defeat-cost floor
      (Gameplay Settings & Modifiers rule 9; Hulls rule 8).
    - **Machine hulls** are repaired only at a port with `repair_facility`
      true, through the `repair` service hook. Its days and price belong to
      that later provider. At MVP no such port exists.
    - **Disabled ships.** Recovery is not a port service. A left-behind ship
      is recovered through the defeat bill (Credits rule 7) and rejoins at the
      fallback port. A win-class disabled ship is recovered free (Battle
      Resolution rule 11). Both return at the hull Hulls & Ship Definition
      sets (Battle Resolution Open Question 3). This GDD assumes
      `RECOVERED_HULL_PM` 100 ‰ of max hull until Hulls decides.
22. **The hub.** Docking opens the Port screen, `PLANNING:port_hub`. Its
    header shows: wallet, hold, daily upkeep (`quote_upkeep()`), days of upkeep
    covered, the defeat cost in full: the billed cap (`quote_defeat_cap()`)
    plus the upkeep of the longest recovery rest from the floor (`L_full` by
    D3 at the current `rest_days_permille`), shown as "Defeat: at most {cap}
    billed, then up to {d} days of rest ({upkeep})". If the recovery rest after
    a defeat would cost more than that line says, it is a bug, not a tuning
    issue. The header also reads "Docked time restores nothing. Rest to
    restore." It shows suppression cover in
    days (Credits rule 9), and the owner's name and band (or "Free port"). Its
    body lists every service with one of three states: available, unavailable
    with a reason (band, free port, nothing to do), or not yet available (no
    provider). Later systems plug in through one hook:
    `register_service(service_id, screen_id, privilege, available(port) →
    OK | reason)`. A service is available when the port lists it, the
    provider is registered, `can(owner, privilege)` holds (always true at a
    free port), and the provider's `available` returns OK. Every service
    screen must be a `PLANNING:<screen_id>` hold (World Clock rule 3).
23. **Fleet service: lay-up and reactivation.** At a docked port the player
    may:
    - mothball an active non-core ship (Credits API `mothball(id)`);
    - **lay up** a mothballed ship here, so it stays at this port and no
      longer travels with the fleet (Sector Map rule 6);
    - **reactivate** a mothballed ship travelling with the fleet, or one laid
      up at this port (Credits rule 6: free; upkeep resumes).
    A laid-up ship's port is saved here. It reactivates only at that port.

**F. After a defeat**

24. **Fallback arrival.** When the defeat skip ends, the fleet is DOCKED at the
    fallback port (Sector Map rule 26, D8). In that same tick:
    - mothballed ships travelling with the fleet may be reactivated here;
    - rumours are given if this is the first docking (rule 27);
    - the Port screen opens with the Rest panel on "Until full" and the
      defeat's bill line from the Debrief (Credits rule 7) in the header.
    No rest starts on its own. The player chooses. This is the concept's loop
    end: in port after the Debrief, with the next attempt planned.
25. **The opening loss** docks at the fallback port with a zero-day skip
    (Sector Map rule 26). Vigor has already reset `C` (Vigor rule 18), so the
    rest panel shows only hull damage, if any.
26. **Laid-up ships stay where they are** through a defeat. The fallback
    port does not move them.

**G. Rumours, truth and save**

27. **Rumours.** On the first docking at a port, this system calls
    `reveal(site_id, source = port_rumour)` (Sector Map rule 23) for each entry
    in `rumours[]`, in list order. It is logged once per port and never
    repeats. Rumours name authored sites only, never fragment content. If the
    port hosts a `witness` fragment slot (optional, authored), it then calls
    Archive Fragments' `grant(slot, witness)`, once, after the rumours.
28. **Truth-neutral.** Port definitions, services, care availability and
    rumours are authored and seed-independent. Care follows ownership and the
    `organic` flag only (rule 3), so content cannot mark the maker's ports
    differently. Care and docking are lost only through the band, which is
    keyed on accusation, not truth (Faction Reputation rule 8). Two seeds
    with identical orders show identical ports and services until the first
    public naming.
29. **Losing a port to hostility moves laid-up ships.** When a faction becomes
    Hostile, every ship laid up at its ports moves, in the same event, to the
    free port of that port's region, still laid up. It is logged and named in a
    notice. The sharing preview must list it (Faction Reputation rule 11).
30. **No random draws.** Docking, rest lengths, restoration, care and healing
    are pure integer functions of state and orders.
31. **Event kind** (World Clock rule 6):
    | Kind | Priority | Visible | `interrupts_skip` | Fires |
    |---|---|---|---|---|
    | `port.rest_done` | 300 | yes | no | a rest reaches its target; restoration applied |
32. **Save section `base:ports`**, version 1, loads after `base:world_clock`,
    `base:sector_map`, `base:faction_standing` and `base:credits`. It holds:
    the open rest record (`start_s`, `L`, the `port.rest_done` `seq`,
    per-ship deficits and `need_s`, elapsed `t`), each laid-up ship's port,
    rumour-given flags per port, and per-ship travel-heal remainders. Ceiling
    4,096 bytes. A save during an interrupt hold restores the same Resume or
    End choice.
33. **API** (no engine types, unit-testable): `can_dock(port) → OK | reason`,
    `dock()`, `undock()`, `quote_rest(L) → preview`, `rest(L)`,
    `resume_rest()`, `end_rest()`, `quote_care(ship)`, `buy_care(ship) → OK |
    REFUSED`, `lay_up(id)`, `register_service(...)`, `services(port)`;
    signals `docked(port)`, `undocked(port)`, `rest_ended(record, restored)`,
    `care_bought(ship, price)`.

### States and Transitions

Fleet at a port (the place itself is stored by Sector Map):

| State | Entered when | Clock | Leaves to |
|---|---|---|---|
| UNDOCKED | IN_SYSTEM, IN_TRANSIT or any non-port state | CAMPAIGN | DOCKED (Dock order, dock on arrival, fallback arrival) |
| DOCKED | docked, no rest open | CAMPAIGN; held while any port screen is open | RESTING (`rest(L)`), UNDOCKED (Undock, Depart, rule 9) |
| RESTING | `rest(L)` | skip | DOCKED (`port.rest_done`), INTERRUPTED (`interrupts_skip` event), UNDOCKED (rule 9) |
| INTERRUPTED | skip stopped by an event | held | RESTING (Resume), DOCKED (End rest), UNDOCKED (rule 9) |

Service row (per port, per service):

| State | When |
|---|---|
| Available | listed, provider registered, privilege held, provider says OK |
| Unavailable (reason) | listed and registered, but privilege or provider check fails |
| Not yet available | listed, no provider registered (MVP for market, refit, contracts, salvage, repair) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| World Clock (#8) | #27 → #8 | One `skip(L, port_rest)` per rest; `port.rest_done` event; reads visible events for the preview; interrupts arrive by rule 14 |
| Vigor (#13) | both | Reads `C`, `C0` per core; D4 base length; `restore(ship, mV, rest | care)` |
| Faction Reputation & Standing (#17) | both | `can(f, dock)`; `quote_care`; `spend`; `preview`; this GDD guarantees the free port (rule 9) |
| Sector Map & Travel (#26) | both | Port def per system; DOCKED state; dock on arrival; fallback port; `reveal()`; segment ends for travel healing |
| Credits, Upkeep & Sinks (#18) | #18 → #27 | `quote_upkeep()`, `quote_defeat_cap()`, suppression cover, `mothball`, `reactivate`; rest days charged by Credits |
| Hulls & Ship Definition (#10) | #10 → #27 | Max hull, `scar_line_permille`, organic or machine; recovered hull value |
| Gameplay Settings & Modifiers (#7) | #7 → #27 | `rest_days_permille` (accepted, 250 – 2,000) |
| Simulation Tick & Pause (#1) | #27 → #1 | `PLANNING:port_hub`, `port_rest`, `port_care`, `port_fleet` hold reasons |
| Battle Resolution (#22), After-Action Debrief (#24) | → #27 | Loss class ends in fallback arrival (rule 24) |
| Faction Belief & Blame (#30) | #27 → #30 | Port and laid-up consequences for the sharing preview |
| Markets (#37), Refit & Loadout (#35), Contracts (#38), Salvage (#36) | them → #27 | `register_service` |
| Port & Fleet Management Screens (#50) | #27 → #50 | Hub layout, preview fields, service rows |
| Save/Load & Migration (#5) | #27 → #5 | Section `base:ports` |

## Formulas

All lengths are integer game-seconds. `DAY_S` = 86,400. `div` is integer
division. `compose(b, m)` is Gameplay Settings & Modifiers D2:
`(b × m + 500) div 1,000`, raised to 1 when `b` > 0.

### D1. Base lengths per ship

`vig_s = ceil(Σ_k (C0_k − C_k) × DAY_S × 1,000 ÷ (C0 × REST_RESTORE_PM_PER_DAY))`
(Vigor D4, summed over cores)

`hull_s = ceil((H_max − H) × DAY_S × 1,000 ÷ (H_max × PORT_HULL_PM_PER_DAY))`;
0 for a machine hull.

`base_s = max(vig_s, hull_s)`

| Variable | Range | Description |
|---|---|---|
| C0, C | 100,000 – 2,000,000 mV | Vigor ceiling, full and now (Vigor rule 1) |
| H_max, H | 1 – hull maximum | Hull points, max and now (Hulls) |
| REST_RESTORE_PM_PER_DAY | 150 (Vigor) | ‰ of C0 per day |
| PORT_HULL_PM_PER_DAY | 100 – 300; **150** | ‰ of H_max per day |

### D2. Hull restored by a full day

`H_day = H_max × PORT_HULL_PM_PER_DAY div 1,000`. With the default, a ship from
its floor-level damage needs as long for hull as for Vigor, so one rest does
both (Hulls rule 8).

### D3. Need and fleet length

`need_s(ship) = compose(base_s(ship), rest_days_permille)`
`L_full = min(SKIP_MAX_S, max over ships of need_s)`

### D4. Restoration for elapsed time t

`frac(ship) = min(t, need_s) ÷ need_s`, applied as:
`ΔC_k = (C0_k − C_k) × min(t, need_s) div need_s` per core;
`ΔH = (H_max − H) × min(t, need_s) div need_s`.
A ship with `need_s` 0 gets nothing. At `t ≥ need_s` the restore is exact.

### D5. Upkeep quoted for a rest

`charges = floor((now_s + L) ÷ DAY_S) − floor(now_s ÷ DAY_S)`
`upkeep_quote = charges × (quote_upkeep() + suppression_daily)`

Credits' daily event is due at each day boundary (Credits rule 4).

### D6. Travel healing per segment

`cap = H_max − ceil(H_max × scar_line_permille ÷ 1,000)`
`acc = rem + elapsed_s × H_max × TRAVEL_HEAL_PM_PER_DAY`
`H' = min(cap, H + acc div (1,000 × DAY_S))`; `rem = acc mod (1,000 × DAY_S)`,
or 0 once `H' = cap`. Applied only if `H < cap`; never lowers `H`.

| Variable | Range | Description |
|---|---|---|
| TRAVEL_HEAL_PM_PER_DAY | 50 – 500; **200** | ‰ of H_max per travelling day |
| scar_line_permille | 200 – 1,000 (Credits rule 13a) | Hulls |
| elapsed_s | 0 – segment length | Lane leg, partial leg, or the defeat skip |

### Worked example (checked)

A line ship: `C0` 600,000 mV, `C` 330,000 (deficit 270,000); `H_max` 1,000,
`H` 700 (deficit 300). Clock at `now_s` 864,000 (day 10, 00:00). Standard
(`rest_days_permille` 1,000). Fleet upkeep 420/day, no suppression.

- D1: `vig_s` = 270,000 × 86,400 × 1,000 ÷ (600,000 × 150) = **259,200 s**
  (3 days, as Vigor D4). `hull_s` = 300 × 86,400 × 1,000 ÷ (1,000 × 150) =
  **172,800 s** (2 days). `base_s` = 259,200.
- D3: `need_s` = (259,200 × 1,000 + 500) div 1,000 = 259,200. At Admiral
  (1,250): 324,000 s (3.75 days). At Chronicler (500): 129,600 s.
- D5 at Standard: end 1,123,200; floor(1,123,200 ÷ 86,400) = 13;
  floor(864,000 ÷ 86,400) = 10; 3 charges × 420 = **1,260 credits**.
- D4, interrupted at `t` = 86,400 and ended: ΔC = 270,000 × 86,400 div
  259,200 = **90,000 mV**; ΔH = 300 × 86,400 div 259,200 = **100**. (Hull
  restores at the fleet's pro-rata pace, not its own faster rate, so the ship
  ends a partial rest evenly restored.)
- D6: the same ship, `scar_line_permille` 250, at `H` 400, travels a 1.5-day
  leg (129,600 s): cap = 750; acc = 129,600 × 1,000 × 200 = 25,920,000,000;
  ÷ 86,400,000 = 300; `H'` = min(750, 700) = **700**. A second such leg stops
  at **750**: the scar (250) waits for port.

## Edge Cases

- **If the fleet is full and docks**: Rest is unavailable ("Fleet fully
  restored"). Docked time still passes at the CAMPAIGN rate.
- **If one ship needs more than `SKIP_MAX_S`** (impossible at defaults: floor
  to full is 5 days, 6.25 at 1,250, 10 at 2,000): `L_full` is capped, the rest
  restores pro rata, and the panel offers a second rest. Two rests are two
  orders, never one chained skip.
- **If the player picks a length shorter than one step**: not offered; the
  minimum is `REST_STEP_S`, or `L_full` if smaller.
- **If an interrupt and `port.rest_done` fall at the same instant**: World
  Clock order applies (priority 300 for rest done fires after 100 and 200).
  The interrupting event fires first, the skip stops after the instant, and
  `port.rest_done` has already fired in that instant, so the rest is complete
  and no Resume is offered.
- **If the save is loaded inside an interrupt hold**: the rest record and
  elapsed `t` are restored; Resume continues to the saved target.
- **If the port's owner turns Hostile during a rest**: rule 9. Restoration for
  `t` so far is applied, the fleet is undocked, and Sector Map's patrol rule
  for Hostile owners applies from that instant (Open Question 6).
- **If the wallet empties mid-rest**: Credits mothballs per rule 6. The rest
  continues; the preview named the ships at risk.
- **If care is bought for a ship mid-rest**: impossible. Care needs DOCKED,
  and RESTING and INTERRUPTED are not DOCKED. In INTERRUPTED the player must
  End rest first.
- **If care is bought, then a rest starts**: the rest uses the new `C`, so
  its length may fall to the hull time.
- **If the opening loss docks at the fallback port**: Vigor has reset `C`;
  only hull damage shows; the rest costs upkeep as normal (the opening's
  exemption covers the bill and Vigor, not later rests).
- **If every port in reach is Hostile but the free port**: the free port is
  the fallback and the rest port (Faction Reputation rule 9).
- **If a faction turns Hostile with ships laid up at its ports**: rule 29
  moves them to the region's free port.
- **If a mod port lists `care`**: validation error `PORT_CARE_AUTHORED`.
- **If a mod faction has no `organic` flag**: treated as false; its ports
  offer no care.
- **If a machine hull is in the fleet**: rest skips its hull (rule 10);
  `quote_care` returns UNAVAILABLE; the ship row reads "needs repair
  facility".
- **If a laid-up ship is the cheapest escort**: the free core is Credits'
  rule; lay-up is refused for the flagship and the free escort.
- **If the fleet docks during a defeat skip**: impossible; fallback arrival
  is the skip's end state.
- **If a ship's `need_s` is 0 but the fleet rests**: it is unchanged; it
  still pays upkeep, as Credits rule 4 bills every active ship.
- **Degenerate: resting to farm events.** Rest is capped at `L_full` and
  unavailable when full, so it cannot be used as a wait. Idling docked passes
  time at the CAMPAIGN rate only, as idling anywhere does (World Clock rule 15).
- **Degenerate: care as a free reset.** Care costs standing, a spend that
  drift never refills above 0 (Faction Reputation rule 6), and it never clears
  scars, so rest days are still needed after a real defeat.

## Dependencies

| System | Kind | Interface |
|---|---|---|
| World Clock (#8) | Hard | `skip`, `register`, visible-event query, interrupts |
| Vigor (#13) | Hard | `C`, `C0`, D4, `restore` |
| Faction Reputation & Standing (#17) | Hard | `can`, `quote_care`, `spend`, `preview` |
| Sector Map & Travel (#26) | Hard | Port ref, DOCKED, fallback port, `reveal`, segment ends |
| Credits, Upkeep & Sinks (#18) | Hard | Quotes, mothball, reactivate, daily charges |
| Hulls & Ship Definition (#10) | Hard | Max hull, scar line, organic or machine, recovered hull |
| Gameplay Settings & Modifiers (#7) | Soft | `rest_days_permille` |
| Simulation Tick & Pause (#1) | Hard | `PLANNING:*` holds |
| Content Data & Mod Loading (#4) | Hard | `port` kind, validation |
| Save/Load & Migration (#5) | Hard | `base:ports` |
| Battle Resolution (#22), After-Action Debrief (#24) | Soft (reverse) | Loss class leads to fallback arrival |
| Faction Belief & Blame (#30) | Soft (reverse) | Preview lines (rule 29) |
| Markets (#37), Refit (#35), Contracts (#38), Salvage (#36) | Soft (reverse) | `register_service` |
| Port & Fleet Management Screens (#50) | Hard (reverse) | Hub and panel data |

Bidirectional: Vigor, Faction Reputation, World Clock, Sector Map, Credits and
Hulls already name #27. Simulation Tick & Pause must add the four hold reasons.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects | Too low | Too high |
|---|---|---|---|---|---|---|
| `PORT_HULL_PM_PER_DAY` | 150 | 100 – 300 | Curve | Rest days for hull | Hull, not Vigor, sets rest length | Hull never matters to rest |
| `TRAVEL_HEAL_PM_PER_DAY` | 200 | 50 – 500 | Curve | How soon a ship reaches its scar line | Long trips still arrive wrecked | Every trip ends at the scar line |
| `REST_STEP_S` | 21,600 | 3,600 – 86,400 | Feel | Granularity of chosen rests | Fiddly list | Can't stop before an event |
| `RUMOURS_MAX` | 4 | 0 – 8 | Gate | Reveals per port | Ports feel empty | Map revealed too fast |
| `RECOVERED_HULL_PM` | 100 (assumed; Hulls owns) | 1 – 500 | Curve | Rest days after a disabled ship | Recovery dominates rest | Disabling costs little |
| `REST_RESTORE_PM_PER_DAY` | 150 | Vigor's | — | Owned by Vigor | — | — |
| `rest_days_permille` | 1,000 | 250 – 2,000 | Curve (preset) | All rest lengths | Rest near free | Rest dominates the clock |
| `SKIP_MAX_S` | 5,184,000 | World Clock's | — | Owned by World Clock | — | — |

All values live in data files (`assets/data/ports/`), never in code.

## Visual/Audio Requirements

- Docking: the fleet glides to the port site on the map and settles; a soft
  mooring cue. No cue on undocking beyond a release sound.
- Rest: during the skip, organic hull glow brightens toward full across the
  skip's few ticks (art reads `C ÷ C0`, Vigor rule 14); scar marks fade only
  at rest end. A low, warm ambient bed while resting.
- Care: a distinct bloom on the ship's cores in the healer race's palette.
  The palette follows the port owner, never the maker.
- Interrupt: the ambient bed cuts; a clear notice sting.

## Game Feel

- The port is a breath out. Holds are instant and silent; no screen ever
  waits on time.
- A rest of several days takes at most a few ticks of real time (World Clock
  rule 13). It should read as "time folds", not as a progress bar.
- The preview's numbers must match the result exactly. Any drift between
  quoted and applied restoration is a bug, not a feel issue.

## UI Requirements

- Port hub: header (wallet, hold, daily upkeep, days covered, defeat cap,
  suppression cover, owner band); service rows with state and reason.
- Rest panel: Until full / Days selector; per-ship before and after; length;
  upkeep with mothball warnings; visible events inside the rest; the
  interrupt line.
- Care screen: per organic ship, the quote, standing before and after, the
  band change, or why care is unavailable.
- Fleet panel: mothball, lay up, reactivate; laid-up ships listed by port.
- Interrupt hold: the event, Resume, End rest, restoration so far.
- Retained screenshots for each screen at story close (UI evidence rule).
  Full specs in `design/ux/` before epics.

## Cross-References

| Topic | Document | Section |
|---|---|---|
| Rest rate, care hook, opening | `design/gdd/vigor.md` | Rules 16 – 18; D4 |
| Bands, care price, free port | `design/gdd/faction-reputation-and-standing.md` | Rules 3, 5, 9, 11; D2; OQ 3 |
| Skips, interrupts, holds | `design/gdd/world-clock.md` | Rules 3, 6, 13 – 15 |
| `rest_days_permille`, composition | `design/gdd/gameplay-settings-and-modifiers.md` | Rule 9; D2 |
| Upkeep, mothball, defeat bill | `design/gdd/credits-upkeep-and-sinks.md` | Rules 4, 6, 7, 13 |
| Scar line, organic and machine | `design/gdd/hulls-and-ship-definition.md` | Rule 8; OQ 7 |
| Free port, laid-up, fallback, DOCKED | `design/gdd/sector-map-and-travel.md` | Rules 1, 3, 6, 23, 26, 33; D8 |
| Disabled and recovered ships | `design/gdd/battle-resolution-and-retreat.md` | Rule 11; OQ 3 |
| Loop end in port | `design/gdd/game-concept.md` | Core loop |

## Acceptance Criteria

- **AC-01 (Logic; rule 3)**: a port whose system owner is an organic faction offers care; a free port and a non-organic owner's port do not; a port def listing `care` fails validation with `PORT_CARE_AUTHORED`.
- **AC-02 (Logic; rule 5)**: Dock succeeds at Wary, Neutral, Trusted and Allied, and at a free port; at Hostile it is refused with the band named.
- **AC-03 (Logic; rule 6)**: Dock and Undock change `clock_s` by 0 and the wallet by 0.
- **AC-04 (Logic; rule 8)**: a fleet docked for 2 game days without resting has unchanged `C` and hull.
- **AC-05 (Logic; rules 11, D1, D3)**: the worked-example ship gives `need_s` 259,200 at 1,000, 324,000 at 1,250 and 129,600 at 500.
- **AC-06 (Logic; rule 12)**: with the fleet full, Rest is unavailable; no length above `L_full` can be ordered.
- **AC-07 (Logic; rule 13, D5)**: from day 10 00:00, a 259,200-s rest quotes 3 charges × 420 = 1,260, and the wallet falls by exactly 1,260 over the rest.
- **AC-08 (Logic; rule 13)**: a visible event due inside the rest appears in the preview; a non-visible one does not.
- **AC-09 (Logic; rule 14)**: a rest issues exactly one `skip` call, with duration ≤ `SKIP_MAX_S`.
- **AC-10 (Logic; rules 15, 16)**: a rest interrupted at 86,400 s, resumed and completed, ends with the same `C` and hull as an unbroken rest of the same length.
- **AC-11 (Logic; D4)**: the worked-example rest ended at `t` 86,400 restores exactly 90,000 mV and 100 hull.
- **AC-12 (Logic; rule 9)**: when the owner turns Hostile mid-rest, the rest ends with pro-rata restoration, the fleet is IN_SYSTEM, and Resume is not offered.
- **AC-13 (Logic; rule 17)**: no credit change during a rest has a cause other than upkeep or suppression.
- **AC-14 (Logic; rule 18)**: care on a ship at m = 300 ‰, heavy, Allied spends exactly 21 standing and leaves `C = C0`; `clock_s` is unchanged.
- **AC-15 (Logic; rule 19)**: care leaves hull and scars unchanged; care on a machine hull, a full ship, or at Wary is unavailable; a spend below `SPEND_FLOOR` is refused and nothing changes; a second care for the same ship before a full rest is unavailable with the reason shown, and is available again after one.
- **AC-26 (Logic; rule 22)**: at `rest_days_permille` 2,000, the header's defeat line equals the billed cap plus the upkeep of a 10-day floor-to-full rest, and a scripted defeat followed by that rest never costs more than the line shows.
- **AC-27 (UI; rule 13)**: the rest preview lists the interrupt kinds and every investigator step due inside the chosen length.
- **AC-16 (Logic; rule 21, D6)**: the D6 example ship reaches 700, then 750, and never exceeds 750 by travel; the defeat skip heals it as travel.
- **AC-17 (Logic; rule 24)**: after a DEFEAT, the fleet is DOCKED at the fallback port when the skip ends, the Rest panel opens on Until full, and no rest has started.
- **AC-18 (Logic; rules 23, 26, 29)**: a laid-up ship reactivates only at its port; it stays there through a defeat; when that port's owner turns Hostile it moves to the region's free port and a notice fires.
- **AC-19 (Logic; rule 27)**: first docking reveals each rumour site once, in list order; a second docking reveals nothing.
- **AC-20 (Logic; rule 28)**: two campaigns with different seeded makers and identical orders produce identical port services, care availability and rumours before the first public naming.
- **AC-21 (Logic; rules 13, 20, 22)**: opening the hub, rest, care or fleet screen holds the simulation; 600 frames pass with `clock_s` unchanged.
- **AC-22 (Logic; rule 32)**: save and load inside an interrupt hold, then Resume, gives the same end state as no save.
- **AC-23 (Logic; rule 22)**: a service with no registered provider shows "not yet available"; registering a test provider makes it available.
- **AC-24 (UI)**: the hub header shows wallet, daily upkeep and defeat cap; hub, rest, care and fleet screens have retained screenshots in `production/qa/evidence/`.
- **AC-25 (Playtest; experiential)**: at least 4 of 5 testers, after a defeat, can say from the port screen alone how many days and credits a full recovery costs, and at least 3 choose between rest and care deliberately rather than by default.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **Care does not clear scars** (rule 19): care restores Vigor only, so
  Faction Reputation D2 stands and scars still cost port days (Credits rule
  13a condition (b)).
- **Laid-up ships at a port that turns Hostile** move to the region's free port
  (rule 29); nothing is ever stranded.
- **Upkeep phase**: Credits' daily upkeep falls due at each day boundary
  (`d × DAY_S`); Credits rule 4 amended to say so.
- **Expulsion**: when rule 9 undocks the fleet in a newly Hostile system, any
  patrol contact is an ordinary offer (Fight, Evade, Turn back; Sector Map
  rules 17–20), never an auto-started battle.
- **Defeat cost shown in full** (CD review): the header adds the longest
  recovery rest to the billed cap (rule 22). Credits D5's "4 rest days" example
  becomes 5 days at Standard (floor to full, Vigor D4); Credits rule 13 now takes N from `L_full`, and its worked figures are re-derived at the next Credits review.
- **Interrupts are named** (rule 13), closing the earlier preview question.

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Recovered hull value** of a disabled ship (this GDD assumes `RECOVERED_HULL_PM` 100 ‰). | Hulls owner (Battle Resolution OQ 3) | #10 re-review |
| 2 | **Partial care** (buy back part of the ceiling)? MVP: full only. | economy-designer | First campaign playtest |
| 4 | **Machine repair**: days and price for a `repair_facility` port. | Refit & Loadout (#35) | Post-MVP |
