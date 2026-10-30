# Points of Interest

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — derelicts, archives and witnesses hold evidence beyond the strongholds); Pillar 4 (Plan in the Open — what a site costs to search is shown before you commit)

## Summary

Points of Interest are the derelicts and archives placed in star systems: the non-stronghold sources of evidence. A site is revealed by arrival, a port rumour or another search; searching it takes half a day of real campaign time (paid in upkeep, previewed, interruptible with progress kept) and always reads the same whether or not it holds a fragment. A search grants the site's fragment slot through Archive Fragments, shows a truth-neutral site log and may reveal further sites; sites leave hooks for salvage, witnesses and survey contracts.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Sector Map & Travel, Archive Fragments & Evidence`

## Overview

Points of Interest places derelicts and archives (and, later, witnesses) in star
systems. They are the places where evidence waits outside the strongholds. A
point of interest (POI) is an authored **site** (Sector Map rule 2) with a kind,
a truth-neutral name and log text, and an optional fragment slot owned by
Archive Fragments (#28). It starts hidden, unless its system's sites start
known. It is revealed by arrival, by a port rumour, or by searching another
site. The player searches it from inside its system. A search is ordinary
campaign time, not a skip. It takes `SEARCH_S` (half a day) and its time, cost,
preview and notice are the same whatever the slot holds. When the search
completes, this system calls `grant(slot, source)` on #28, unlocks the site's
log, and reveals any sites the log points to. A searched site stays searched.
This system has no random draws, reads no fragment content, and saves its
search progress in its own small section.

## Player Fantasy

You are a salvager-detective working a cold case. A rumour in a port bar names
a wreck two lanes out. You plan the trip, see that a search costs half a day,
and see whether a raider will cross the system while you work. You commit.
Your fleet holds over the hull while the day runs on. Then the find card opens:
a sealed relic, a log, or nothing legible. Either way the site log tells you
what this place was, and it may point you at the next one. Every site is a
small story, and some of them lead somewhere.

MDA: **Discovery** first (hidden sites, rumours, logs that point onward),
**Narrative** second (each site's log), **Challenge** third (fitting a search
into the clock and around roaming fleets). SDT: **Autonomy** (which lead to
chase, and when; Pillar 2), **Competence** (the preview is exact and the risk is
readable; Pillar 4).

The player should never feel "the search took longer, so it must be good", "the
site's name told me who did it" or "that trip was wasted".

## Detailed Design

### Core Rules

**A. Sites**

1. **A POI is a `poi` content kind** (base kind; envelope by Content Data Core
   Rule 7; body schema owned here). It is authored and seed-independent, and is
   **not** a truth kind. Body fields:

   | Field | Type | Range | Notes |
   |---|---|---|---|
   | `poi_kind` | enum | `derelict`, `archive`; `witness_site` reserved | Sets icon, card art and the search verb |
   | `map_pos` | int pair | 0 – 10,000 each (mu) | Its system is derived by Sector Map rule 2 (within `SYSTEM_RADIUS_MU`) |
   | `name_key` | text key | 1 | Shown on the map and the site card. Truth-neutral (rule 4) |
   | `log_key` | text key | 1 | The site log, shown when the search completes. Truth-neutral (rule 4) |
   | `reveals[]` | list of refs → site | 0 – `POI_REVEALS_MAX` (3) | Sites revealed when the search completes, in list order (rule 13) |

2. **The fragment slot is found by reverse lookup.** A POI does not name its
   slot. #28's `fragment_slot.host` names the POI (Archive Fragments rule 1),
   and this system builds `slot_of(poi)` at load. One source of truth, no
   duplicate reference. At most one slot per POI (#28 `SLOT_HOST_SHARED`).
3. **Load validation** (content load, all errors unless marked):
   - `POI_SLOT_KIND_MISMATCH`: a slot's `source_kind` differs from its host's
     `poi_kind` (a `derelict` slot on an archive);
   - `POI_WITNESS_RESERVED`: a `witness` slot on a POI, or a `witness_site` POI,
     while `POI_WITNESS_ENABLED` is false (rule 25);
   - `POI_REVEAL_UNKNOWN`, `POI_REVEAL_SELF`: a `reveals[]` entry names no site,
     or the POI itself;
   - `POI_NO_YIELD` (warning): a POI with no slot and no `reveals[]`;
   - `SITE_OUTSIDE_SYSTEM` stays Sector Map's (rule 2).
4. **Truth-neutral surface.** Name and log text follow lore bible §1.1. They name
   no race, and use no attribute vocabulary (scripts, era names, numbering
   bases, metals, doctrines). A site's kind, position, name, log, reveals and
   search parameters never vary with the seed. Only the slot's content is
   seeded, by #28 placement. This is Truth Seeding G6 for "location" and Sector
   Map rule 25.
5. **MVP content.** One `derelict` POI and one `archive` POI, each hosting one
   `document` slot (#28 MVP slots). At MVP `m_d = n_d = 5`, so both always hold
   a fragment and meet `NONSTRONGHOLD_DOC_MIN` (#28 rule 5). The rules below
   still treat an empty slot exactly like a full one (rule 11 of #28).
   Witnesses stay at ports.

**B. Knowledge**

6. **Known at the start**: a POI whose system has `start_known_sites` true.
   Every other POI starts hidden (Sector Map rule 22).
7. **Revealed** (Sector Map rule 23; permanent), by any of:
   - arriving in its system (`map.arrive`);
   - a port rumour, `reveal(site_id, source = port_rumour)` (Ports rule 27);
   - another POI's search, `reveal(site_id, source = poi_search)` (rule 13).
   There is no scan reveal at MVP (hook, rule 27). This system never stores
   reveal state; it reads `is_revealed(site_id)` from Sector Map.
8. **What a revealed POI shows**: its icon, name, kind, and an "evidence here"
   marker if it has a slot and is not SEARCHED (#28 Visual/Audio). The marker is
   the same for every class and for an empty slot. A POI without a slot shows no
   marker. Slot presence is authored, so this is maker-neutral.

**C. Searching**

9. **The Search order.** A revealed POI in state UNSEARCHED or SUSPENDED offers
   **Search** while the player fleet is in its system, undocked (`IN_SYSTEM`)
   and not in an offer. If the fleet is docked in that system, Search undocks
   it first, in the same order. One search runs at a time.
10. **A search is campaign time, not a skip.** It runs at the CAMPAIGN rate, as
    travel does (World Clock rules 12 and 15: port rest stays the only wait).
    Rivals, contracts and roaming fleets move visibly while it runs. On start,
    this system registers one `poi.search_done` event at `due_s` (D1). There is
    no per-tick loop.
11. **Same cost whatever the slot holds.** `SEARCH_S`, the preview, the start
    notice, the marker, the progress bar and the completion notice depend only
    on the POI kind and the fleet's clock, never on the slot's class, content or
    emptiness (#28 rule 11). `SEARCH_S` is one value for all kinds at MVP.
    There is no credit fee at MVP; daily upkeep runs as usual (Credits).
12. **Suspension.** A search becomes SUSPENDED, keeping its progress (D1), when
    any of these happens: a `map.contact` offer opens (Sector Map rule 20), or
    the Engage offer on a node; the player commits a route or docks; the fleet
    falls back after a loss-class battle. The `poi.search_done` event is
    cancelled. A win-class battle or a finished Evade leaves the search
    SUSPENDED; the player resumes it with Search (no auto-resume, so the player
    always re-reads the preview). Battle time and Evade time never count as
    search time.
13. **Completion**, in one tick at `due_s`, in this order:
    1. the POI goes SEARCHED and records `searched_day`;
    2. `PoiSearched(poi_id, tick)` is logged at record tier (no content field);
    3. if it has a slot: `grant(slot_id, source = poi_kind)` on #28. #28 opens
       the find card (a planning hold) or shows "Nothing legible survived here";
    4. the site card opens with the log text (`log_key`) under the find card;
    5. each `reveals[]` entry calls `reveal(site_id, source = poi_search)` in
       list order.
    This system never reads what the grant returned. Steps 1–5 are the same
    for every slot state.
14. **The preview (Pillar 4).** Hovering or pressing Search shows, before
    commit: time left (days, two decimals, D1); daily upkeep charges that fall
    in the window (D2); and known risks, which are the sighted roaming fleets
    whose predicted contact (Sector Map rules 19, 24) falls before `due_s`. The
    preview never mentions what the site holds, beyond the authored "evidence
    here" marker.
15. **Risk is the map's, not the site's.** A POI owns no encounter at MVP.
    Danger during a search is the ordinary map: a roaming fleet that enters the
    system makes contact by geometry and it is an offer (Sector Map rules 19,
    20). A Hostile-owned system's patrol contacts on arrival, before any search.

**D. Repeat visits**

16. **SEARCHED is permanent.** The Search order is replaced by "Searched day d".
    The site card and log stay readable from the map and the Dossier. Nothing
    regrows, restocks or re-rolls.
17. **SUSPENDED keeps its progress** across leaving, docking, battles, saves and
    any number of days. Returning and pressing Search continues from `done_s`.
18. **A late grant is still a grant.** If a rival (#32) has already acted on a
    POI's fragment, the search still calls `grant`; #28 and #32 decide the
    outcome (#28 Open Question 1). This system never branches on it.

**E. Determinism and save**

19. **No random draws.** Every value is authored or an integer function of the
    clock. Search start, suspension and resume are orders stamped with their
    tick, so a replay repeats them.
20. **Event kind** (World Clock rule 6):

    | Kind | Priority | Visible | `interrupts_skip` | Fires |
    |---|---|---|---|---|
    | `poi.search_done` | 150 | yes | yes (default) | rule 13 |

    The flag stays at its default (a grant changes the case). It cannot fire
    during a skip: rest needs a docked fleet and a defeat suspends the search
    (rule 12). At an equal `due_s`, `map.contact` (200) fires first, suspends
    the search and cancels this event.
21. **Own section `base:points_of_interest`**, version 1, loads after
    `base:sector_map` and `base:archive_fragments`. Per POI that is not
    UNSEARCHED: `{poi content ID, state, done_s, searched_day}`. Plus the active
    search: `{poi content ID, start_s, event seq}` or none. Ceiling **4 KiB**
    (D3). Reveal flags stay in `base:sector_map`; fragment state stays in
    `base:archive_fragments`.
22. **No surface path reveals slot content.** The save header, slot summary,
    POI tooltip and bug-report bundle list neither which POI holds what class
    nor whether a slot is empty (#28 rule 30).
23. **Content changes after new game.** A retired POI drops its saved entry on
    load with a warning. A slot added to an existing POI by a mod is empty
    (#28 rule 28). A SEARCHED POI is never searched again, even if it gains a
    slot.

**F. Hooks for later systems (not MVP)**

24. **Salvage (#36, Vertical Slice).** A derelict may later add salvage to the
    hold on completion. The amount must be authored per POI or per kind, never
    a function of the slot (rule 11).
25. **Witnesses at POIs.** When `POI_WITNESS_ENABLED` is true, a `witness_site`
    POI hosts an `account` slot and grants it on completion with
    `source = witness` (#28 rule 9). Its log and name follow #28 rule 1: the
    site is where the account is kept, never whose it is.
26. **Contracts (#38).** A "survey" contract may name a POI and read
    `PoiSearched`. Rewards may not depend on the slot.
27. **Scans and guardians.** A sensor reveal (`source = scan`) and an authored
    guardian offer on Search are reserved. A guardian must be authored per POI
    and seed-independent.

### States and Transitions

Per POI search state (reveal state is Sector Map's):

| State | Entered when | Clock | Leaves to |
|---|---|---|---|
| UNSEARCHED | load (default; not saved) | — | SEARCHING (Search) |
| SEARCHING | Search order (rule 9) | CAMPAIGN rate | SEARCHED (`poi.search_done`), SUSPENDED (rule 12) |
| SUSPENDED | offer, route commit, dock, loss fallback | — | SEARCHING (Search) |
| SEARCHED | completion (rule 13) | — | — (permanent) |

Search needs `is_revealed(poi)` and the fleet `IN_SYSTEM` in the POI's system
(Sector Map place states). At most one POI is SEARCHING.

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Sector Map & Travel (#26) | both | Site membership (rule 2); `is_revealed()`; `reveal(site_id, poi_search)`; fleet place; predicted contacts for the preview; route commit, dock and offers suspend a search |
| Archive Fragments & Evidence (#28) | #29 → #28 | `slot_of(poi)` from slot `host`; `grant(slot_id, source)` on completion; never reads the result |
| Ports, Rest & Care (#27) | #27 → #26 → #29 | Rumours reveal POIs (rule 27); no direct call |
| World Clock (#8) | both | Registers `poi.search_done`; CAMPAIGN rate; no skip |
| Credits, Upkeep & Sinks | Credits → #29 (read) | `U_day` for the preview; upkeep fires by Credits' own rule |
| Content Data & Mod Loading (#4) | both | Kind `poi`; rule 3 validation |
| Save/Load & Migration (#5) | #29 → #5 | Section `base:points_of_interest`, 4 KiB |
| Simulation Tick & Pause (#1) | #29 → #1 | Site card as a planning hold when no find card opens |
| Dossier | #29 → Dossier | Site logs of searched POIs |
| Exposure & Rival Investigation (#32) | none direct | Rivals target fragments via #28, not POIs |
| Salvage (#36), Contracts (#38) | future | Hooks, rules 24 and 26 |

## Formulas

### D1. Search progress and due time

Variables: `SEARCH_S` (knob, 43,200 s); `done_s` (saved progress, 0 –
`SEARCH_S`); `t_start` (clock_s at Search); `t_stop` (clock_s at suspension).

- `remain_s = SEARCH_S − done_s`
- `due_s = t_start + remain_s`
- On suspension: `done_s = min(SEARCH_S, done_s + (t_stop − t_start))`
- Preview days = `remain_s × 100 div 86,400`, shown as `d.dd`

Range: `remain_s` 1 – 172,800 at the safe range of `SEARCH_S`. All integers.

### D2. Upkeep in the preview

Credits charges upkeep once per day roll. The charges in a window are:
`rolls = (due_s div 86,400) − (t_now div 86,400)`;
`upkeep_preview = rolls × U_day`. Range: `rolls` 0 – 2 at the safe range.
This is exact, not an estimate, because nothing else changes `U_day` while
the clock runs without an order (an order re-runs the preview).

### D3. Section size

Per entry: content ID ≤ 128 B + state 1 B + `done_s` 4 B + `searched_day` 4 B
≈ 137 B. Active search ≈ 128 + 8 + 8 = 144 B. At `POI_MAX_PER_REGION` 24:
24 × 137 + 144 ≈ 3.4 KB, under 4 KiB.

### D4. Real time at 1×

`real_s = remain_s × 120 div 86,400` (World Clock: 120 real seconds per day).

### Worked example (MVP)

The fleet is in the derelict's system. `SEARCH_S` = 43,200, `done_s` = 0, Search
at `t_start` = 100,000 (day 1).

- D1: `remain_s` = 43,200; `due_s` = 143,200; preview "0.50 days".
- D2: rolls = 143,200 div 86,400 − 100,000 div 86,400 = 1 − 1 = 0; upkeep 0.
- D4: 43,200 × 120 div 86,400 = 60 real seconds.
- A roaming fleet makes contact at 120,000. Suspend: `done_s` = min(43,200,
  0 + 20,000) = 20,000. The player fights and wins; the clock is 121,800.
- Resume: `remain_s` = 23,200; `due_s` = 145,000. Preview "0.26 days"
  (23,200 × 100 div 86,400 = 26). Rolls = 1 − 1 = 0.
- At 145,000: SEARCHED; `grant(D1, derelict)`; the find card opens, then the
  log; `reveals[]` fire. The same times hold if the slot is empty.

Check: 20,000 + 23,200 = 43,200 = `SEARCH_S`. Battle time (1,800 s) is not
counted.

## Edge Cases

- **Docked in the POI's system**: Search undocks and starts in one order.
- **Route committed during a search**: SUSPENDED at the commit tick; progress
  kept.
- **Route planner opened during a search**: the planner holds the clock; the
  search is not suspended unless a route is committed.
- **Contact and completion at the same `due_s`**: the contact fires first
  (priority 200 > 150), suspends the search, and cancels completion. After the
  offer, `done_s` = `SEARCH_S` and `remain_s` = 0, so pressing Search
  completes the search in that same tick.
- **Loss-class battle during a search**: SUSPENDED before the defeat skip; the
  fleet docks at the fallback port; progress kept.
- **Two POIs in one system**: one search at a time; starting the second
  suspends the first.
- **Hostile patrol in the system**: contact happens on arrival. The player may
  search after resolving it; any later contact suspends as normal.
- **Search pressed in an unrevealed system**: impossible; arrival reveals.
- **POI with no slot**: steps 3 of rule 13 is skipped; the site card opens as
  its own planning hold. Time, preview and notices are unchanged.
- **Empty slot (not at MVP)**: #28 shows "Nothing legible survived here"; log
  and reveals still follow.
- **A `reveals[]` entry already revealed**: `reveal()` is a no-op (permanent).
- **Share preview open**: the clock is held, so no completion lands inside it
  (#28 rule 24).
- **Save mid-search**: `start_s` and event seq are saved; load resumes exactly.
- **Degenerate: save-scum to peek**: content is placed at new game and the
  card opens only on completion; reloading changes nothing.
- **Degenerate: read time as a tell**: impossible; time is one knob (rule 11).
- **Degenerate: farm a site**: SEARCHED is permanent; nothing regrows.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Sector Map & Travel (#26) | Hard | Sites, reveal, fleet place, contacts, preview risks |
| Archive Fragments & Evidence (#28) | Hard | `fragment_slot.host`, `grant` |
| World Clock (#8) | Hard | CAMPAIGN rate, event registration |
| Content Data & Mod Loading (#4) | Hard | `poi` kind, validation |
| Save/Load & Migration (#5) | Hard | Own section |
| Simulation Tick & Pause (#1) | Hard | Site card planning hold |
| Credits, Upkeep & Sinks | Soft | `U_day` for the preview |
| Ports, Rest & Care (#27) | Soft (indirect) | Rumour reveals |
| Dossier | Hard (reverse) | Site logs |
| Salvage (#36), Contracts (#38), Exposure (#32) | Soft (future) | Hooks |

Bidirectional check: #26 (rules 2, 23, Interactions) and #28 (rule 9,
Interactions) already name #29. #8, #4, #5, #1, Credits and the Dossier need the
amendments in the report.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `SEARCH_S` | 43,200 (0.5 day) | 21,600 – 172,800 | Gate | Time a search costs; must keep a POI detour inside the "fail, prepare, return" loop (`RETURN_TRIP_MAX_S` 172,800) |
| `POI_REVEALS_MAX` | 3 | 0 – 6 | Gate | How far one log can point |
| `SEARCH_AUTO_UNDOCK` | true | bool | Feel | Search from a docked fleet in one click |
| `SEARCH_AUTO_RESUME` | false | bool | Feel | Resume after a win without re-pressing (off: re-read the preview) |
| `POI_WITNESS_ENABLED` | false | bool | Gate | Witnesses at POIs (rule 25) |
| `SEARCH_CREDIT_COST` | 0 | 0 – 500 | Curve | Reserved; one value for all kinds if ever used |
| `POI_MAX_PER_REGION` | 24 | 4 – 48 | — | Save budget (D3) |
| Section ceiling | 4 KiB | 2 – 16 KiB | — | Save budget |
| MVP POIs (authored) | 1 derelict, 1 archive | ≥ #28 non-node document slots | Gate | Evidence before the first return |

In `assets/data/map/poi/`. `SEARCH_S` must never be split by slot class.

## Visual/Audio Requirements

- Map icon per `poi_kind`; "evidence here" marker per #28, identical for every
  class and for an empty slot; a searched variant of the icon.
- Search progress shown as a ring on the site, driven by the clock only.
- Site card art by `poi_kind` only; never a value, never race art (#28 rule 22).
- Search start and completion cues by `poi_kind` only. The find cue that
  follows is #28's (class and source kind).
- Art and audio direction belong to their leads.

## Game Feel

- **A held breath, not a wait**: half a day is 60 real seconds at 1×; the map
  stays live, so watching a raider's line creep toward the system is tension,
  not idling.
- **Every site pays**: completion always opens a card and a log, and often a
  new lead.
- **No tell-by-timing**: every search of a kind takes the same time.

## UI Requirements

- Search button on the site panel, with the preview (rule 14) on hover and on
  the button.
- Disabled-state reasons: "Not in this system", "Resolve the contact first",
  "Searched day d".
- Progress ring on the map and a line in the fleet status: "Searching ⟨site⟩,
  0.26 days left".
- Site card: name, kind, log text; opens under #28's find card.
- Dossier: a "Sites" list of searched POIs with their logs, in search order.
- 📌 **UX Flag — Points of Interest**: site panel, preview and site card belong
  in the UX spec.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Slot kind, host, grant, same path, materialised placement, surfaces | `design/gdd/archive-fragments-and-evidence.md` | Rules 1, 5, 9, 10, 11, 22, 28, 30; MVP slots | Rule dependency |
| Sites, known sites, reveal, contacts, offers, truth-neutral | `design/gdd/sector-map-and-travel.md` | Rules 2, 5, 19, 20, 22–25, 33, 34 | Rule dependency |
| Rumours | `design/gdd/ports-rest-and-care.md` | Rule 27 | Rule dependency |
| CAMPAIGN rate, events, skips, only wait | `design/gdd/world-clock.md` | Rules 6, 12–15 | Rule dependency |
| Daily upkeep | `design/gdd/credits-upkeep-and-sinks.md` | Upkeep rule | Data dependency |
| G6 location | `design/gdd/truth-seeding-and-candidates.md` | G6 | Rule dependency |
| Neutrality checklist | `design/narrative/lore-bible.md` | §1.1 | Rule dependency |
| Derelicts, archives, testimony as sources | `design/gdd/game-concept.md` | Core fantasy; MVP | Source |

## Acceptance Criteria

- **AC-01 (Logic; rule 3)**: fixtures with a kind mismatch, a witness slot while disabled, an unknown or self reveal each fail load with the named error; a POI with no slot and no reveals loads with `POI_NO_YIELD`.
- **AC-02 (Logic; rule 2)**: `slot_of(poi)` returns the slot whose `host` names it, and none for a slotless POI.
- **AC-03 (Logic; rules 6, 7)**: a POI in a system with `start_known_sites` false offers no Search at day 0, and offers it after arrival, a port rumour or another POI's search.
- **AC-04 (Logic; rule 9)**: Search is unavailable outside the POI's system, during an offer, and on a SEARCHED POI; from a docked fleet it undocks and starts in one order.
- **AC-05 (Logic; rules 10, D1)**: a search from `done_s` 0 completes at exactly `t_start + SEARCH_S`, with one `poi.search_done` registered and no skip requested (World Clock AC-17 still passes).
- **AC-06 (Logic; rule 11)**: for a relic, a record, a forgery and an empty slot in one POI, the preview, `due_s`, notices, marker and upkeep charged are byte-identical.
- **AC-07 (Logic; rule 12, D1)**: contact, route commit, dock and loss fallback each suspend the search with `done_s` = elapsed search time; battle and Evade time are not counted.
- **AC-08 (Logic; rule 13)**: completion sets SEARCHED, logs one `PoiSearched` with no content field, calls `grant` once with `source = poi_kind`, then reveals `reveals[]` in list order.
- **AC-09 (Logic; rule 20)**: a contact and completion at the same `due_s` give a suspended search and no grant; resuming completes it.
- **AC-10 (Logic; D2)**: the preview's upkeep equals the upkeep actually charged between `t_start` and `due_s` with no intervening order, for starts on either side of a day roll.
- **AC-11 (Logic; rule 16)**: a SEARCHED POI never calls `grant` again across 100 revisits and a reload.
- **AC-12 (Logic; rules 19, 21)**: the same seed and orders give a byte-identical `base:points_of_interest` section; a save mid-search, loaded, completes at the same tick as an uninterrupted run.
- **AC-13 (Logic; rule 22)**: no slot class, emptiness or placement appears in the save header, POI tooltip or bug-report bundle (text search).
- **AC-14 (Logic; rule 4, G6)**: over 30,000 seeds per maker, every POI field, `due_s`, card art key and audio cue is identical across makers; only the fragment card differs.
- **AC-15 (Logic; D3)**: 24 POIs, all SUSPENDED with longest IDs, fit in 4 KiB.
- **AC-16 (Review; rule 4)**: a writing review confirms every POI name and log passes the lore bible §1.1 checklist and uses no race name or attribute vocabulary.
- **AC-17 (Playtest; rules 5, 14)**: in a 5-player playtest, every tester searches at least one POI before the first stronghold return, at least 4 of 5 say the preview told them what the search would cost, and none reports that a site's name, place or search time "gave away" the maker.
- **AC-18 (Playtest; rule 13)**: at least 4 of 5 testers rate a site visit as worth the trip, including any whose search yielded nothing legible (fixture build with one empty slot).

## Open Questions

Resolved with the recommended defaults (the owner may revisit any at review):
- **Search is campaign time, not a skip** (keeps World Clock rule 15 and AC-17
  intact; rivals visibly move).
- **Progress is kept** across interruptions.
- **No credit fee** at MVP; upkeep is the cost.
- **No scan reveal and no guardian** at MVP.
- **Search length** is half a day (`SEARCH_S` 43,200), tuned at the first
  playtest.
- **Event order**: World Clock orders events by `(due_s, priority, seq)`
  ascending (rule 6), so `poi.search_done` (150) fires after upkeep (100) and
  before contacts (200) at the same instant: a search that ends as a contact
  arrives grants first, then the offer opens.

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 4 | Derelict salvage amount and whether it is per kind or per POI. | #36 owner, economy-designer | #36 design |
| 5 | POI witness sites: when, and how a spoken account is "searched". | owner, narrative-director | Vertical Slice |
| 6 | Final site names and logs for the MVP derelict and archive. | writer, narrative-director | Before content lock |
