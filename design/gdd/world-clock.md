# World Clock

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on idling vs rule 15, port screens costing days, unannounced skip events, and the defeat day ceiling; all four revised
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — a defeat costs days, never the run); Pillar 2 (The Truth Is Yours to Tell — rival investigators work visibly on the clock)

## Summary

The World Clock counts campaign time in whole game-seconds and fires every timed
campaign event (contract expiry, rival investigator steps, rest completion) in
one fixed order. It runs during travel, port time and battle, and stops whenever
the simulation is held, so days mean something but never pass while the player
is reading the board. Rests skip ahead in a moment, battles cost at most half a
day, and nothing fires during a battle (Pillars 1 and 2).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Deterministic RNG & Seed Streams, Save/Load & Migration`

## Overview

The World Clock is the campaign's single measure of time and its single
**event scheduler**. It counts game time in whole game-seconds, turns that into
days, and fires every timed campaign event (a contract expiring, a rival
investigator's next search step, a rest finishing) in one fixed, deterministic
order.

It advances only in phase P8 of a simulation tick (Simulation Tick & Pause,
rules 3–4) and only while nothing holds the simulation: it reads `is_held()`
and never keeps a pause of its own. So it stops while combat is paused, while a
planning screen is open, during the Debrief, and while the game is closed, and
it runs during travel, port time and battle (concept). It keeps running in the
sandbox after the optional ending (the Reckoning).

Three behaviours shape the campaign:
- **Travel is continuous**: time passes tick by tick, so rivals move visibly.
- **Rest and defeat costs jump ahead**: the clock skips through the event queue
  in a few ticks instead of making the player wait.
- **Battles cost a little time, never much**: the clock runs slowly in battle
  and a battle's cost has a fixed ceiling. Events that fall due during a
  battle wait, and fire in order once the Debrief closes, so a battle replays
  from its battle seed alone (Deterministic RNG & Seed Streams, Core Rule 6).

## Player Fantasy

**The war doesn't wait, but it never ambushes you.** Days mean something: a
rest costs a week, a contract runs out, a rival gets two systems closer. But
the clock only moves when the player is acting, never while they are reading
the board, and it never turns a defeat into the end of the run.

*Anchor moment:* the player docks after a defeat and rests for five days. The
days roll past in a moment; a notice says the investigator reached the next
system on day 42; the rest stops early when a contract offer arrives. The
player reads it, paused, and decides.

**Pillars served:**
- **Pillar 1:** the clock *bounds* a defeat's cost in days (battle time cap, one
  defeat skip of at most `DEFEAT_MAX_S`). The guarantee that a retry stays
  affordable belongs to Exposure & Rival Investigation (#32) and Contracts &
  Missions (#38), which must honour it.
- **Pillar 2:** rival investigators act on the clock, visibly and
  deterministically.
- **Pillar 4:** the clock never runs while a planning screen is open.

**This system must never make the player feel:** "time passed while I was
reading" or "I lost the campaign by resting".

## Detailed Design

### Core Rules

**A. Time**

1. **Game time is an integer count of game-seconds**, `clock_s`, starting at 0
   for a new campaign. It is a 64-bit integer; storing it in 32 bits is banned.
   `DAY_S` = 86,400. Nothing in the clock is a float.
2. **Days.** `day_now = clock_s div DAY_S`, shown to the player as day
   `day_now + 1`. Time of day is display only at MVP; no rule reads it.
3. **The clock advances only in P8, only while `is_held()` is false**, by the
   context's rate per tick (Formulas D1). Real time reaches it only through
   tick counts; it never reads a wall clock.
   - **CAMPAIGN**: `REAL_S_PER_DAY_CAMPAIGN` (120) real seconds per game day at
     1× speed: 12 game-seconds per tick at 60 Hz, 24 at 30 Hz.
   - **BATTLE**: `REAL_S_PER_DAY_BATTLE` (720): 2 game-seconds per tick at
     60 Hz, 4 at 30 Hz. A battle's total is capped at `BATTLE_MAX_S` (43,200,
     half a day); once reached, the clock stops adding battle time.
   - The rate must divide exactly (`DAY_S` divisible by `REAL_S_PER_DAY ×
     TICK_RATE`), or content validation refuses the value. Game time per real
     second is the same at 60 Hz and 30 Hz.
   - **Reading never costs days.** Besides the concept's planning screens
     (Dossier, Ledger, Case File, Debrief), every port service screen (market,
     refit, care, contract board) and the sector map's route planner hold the
     simulation. Port time therefore passes only through docking, departure
     and rest. *The hold reasons belong to Simulation Tick & Pause (#1), which
     must add these screens to its `PLANNING:*` list.*
4. **Speed changes how many ticks run, never the rate.** At 2× speed a game day
   of travel takes 60 real seconds, because twice as many ticks run (Simulation
   Tick & Pause rule 9). Outcomes never depend on speed.
5. **Day roll.** After its events fire in a tick, P8 reports `day_rolled(from,
   to)` whenever `day_now` changed. A skip can cross many days in one tick;
   consumers must never assume +1. Autosave (Save/Load & Migration D3) reads
   `day_now` itself; it is not a clock event.

**B. The scheduler**

6. **Every timed campaign event lives in one queue.** An event is
   `{seq, due_s, priority, kind, owner, visible, payload}`. `visible` marks an
   event the player knows about (a contract expiry, a known investigator
   arrival), which the rest panel can preview. Systems register events; the
   clock fires them. **Order is (due_s, priority, seq), ascending**, always.
   - `seq` is a saved counter, +1 per registration (events are not entities and
     use no Runtime IDs).
   - Priority bands: 90 payouts (contract rewards, so they land before upkeep at
     the same instant); 100 world changes (contract expiry and replacement,
     fleet upkeep, standing drift); 200
     rival actions (investigator steps); 300 player completions (rest done);
     900 notices. Lower fires first at the same instant.
7. **Handlers act at the event's time, not the tick's.** Each handler receives
   `t_event = due_s`, so a result never depends on tick size, speed or skip
   rate. Handlers draw only from their owner's campaign streams
   (Deterministic RNG & Seed Streams, Core Rule 6).
8. **Registering, cancelling, rescheduling.** `register()` returns `seq`. A due
   time already in the past is set to now and logged. An event registered for
   the current instant fires in the same pass; a same-instant chain longer than
   `SAME_INSTANT_CHAIN_MAX` (256) is a programmer error. `cancel(seq)` on an
   event already fired or cancelled does nothing. Rescheduling is cancel plus
   register (a new `seq`). The queue holds at most `EVENT_QUEUE_MAX` (8,192)
   events.
9. **Nothing fires in BATTLE.** P8 adds battle time and fires no event; events
   that fall due stay in the queue (RNG Open Question 1: no campaign system
   acts inside a battle — Exposure & Rival Investigation #32 must accept this).
10. **Catch-up after a battle.** In P8 of the **first CAMPAIGN tick** after the
    battle (after the outcome is committed and the Debrief closes, Simulation
    Tick & Pause AC-38), every event now due fires in normal order, **before**
    that tick adds its own time.
11. **No event ever starts a battle.** An event that wants a fight (an ambush,
    an interception) registers an **encounter offer**. All due events finish
    first; then offers are presented in the order they were made, under a hold.
    A battle starts only when the player resolves an offer, or when an offer's
    own rule (in its owning GDD) starts it after the player has seen it (RNG
    Open Question 2).

**C. Travel, rest and skips**

12. **Travel is continuous.** Travel and port time add the CAMPAIGN rate each
    tick, so rivals and contracts move visibly, and predicted travel time is
    shown in days (Sector Map & Travel #26).
13. **Rest and day costs use a skip.** `skip(duration_s, reason)` advances the
    clock through the queue in a few ticks: each tick fires every event with
    `due_s ≤ min(target, clock_s + SKIP_S_PER_TICK)`, at most
    `SKIP_EVENTS_PER_TICK` events per tick, moving the clock to each event's
    time, then to the window's end. There is never a loop over days.
    `duration_s ≤ SKIP_MAX_S` (60 days, a technical limit on rests); a longer
    request is refused. **A defeat's day cost is one skip of at most
    `DEFEAT_MAX_S`**; a defeat may never chain skips, so this is the hard
    ceiling on what one defeat costs in days. A rest's length is
    `modifier_compose(base_rest_s, rest_days_permille)` in seconds (Gameplay
    Settings & Modifiers D2), so nothing rounds to whole days.
14. **A skip can be interrupted.** An event whose kind is flagged
    `interrupts_skip` stops the skip after every event at that same instant has
    fired. **Any event that changes exposure, faction hostility or the state of
    the case is `interrupts_skip` by default**; its owning GDD may clear the
    flag only with a stated reason. The clock stays at that instant, the
    remaining target is kept, and
    the event's owner adds its hold and prompt. The player may resume or
    abandon the rest; the choice is an order, stamped with its tick, so a
    replay repeats it.
15. **The only explicit wait is port rest** (Ports, Rest & Care #27). No other
    "wait N days" command exists. Idling in flight still passes time at the
    CAMPAIGN rate. A site search (Points of Interest #29) is not a wait: it is
    an action that runs at the CAMPAIGN rate, is never a skip, and ends with a
    `poi.search_done` event (priority 150). Making contract replacement worthless to farm by idling
    belongs to Contracts & Missions (#38), for example by drawing replacements
    in a fixed seeded sequence so waiting never improves the draw.

**D. Saving**

16. **The clock saves as section `base:world_clock`**: `clock_s`, `next_seq`,
    the current battle's accrued time, any skip in progress (target and
    reason), and the queue sorted by `seq`. Handlers are found by event
    `kind`, never stored. Ceiling: 1 MiB (about 8,192 events × 128 B), counted
    within Save/Load's "all other systems" placeholder (Save/Load D1). An event
    whose kind belongs to a missing mod is carried untouched with that mod's
    data (Save/Load Core Rule 17) and never fires until the mod returns.

### States and Transitions

The state is derived from context, `is_held()` and skip state; it is never a
stored enum.

| State | When | Clock advances | Events fire | Leaves to |
|---|---|---|---|---|
| Running (campaign) | CAMPAIGN, not held, no skip | CAMPAIGN rate | Yes, as due | Held, Skipping, Running (battle) |
| Skipping | CAMPAIGN, not held, skip active | jumps through the queue (rule 13) | Yes, in order | Running (target reached), Skip-interrupted, Held |
| Skip-interrupted | an `interrupts_skip` event fired | No (held by its owner) | No | Skipping (resume), Running (abandon) |
| Running (battle) | BATTLE, not held, under cap | BATTLE rate | **No** (deferred) | Battle-capped, Held, Catching-up (battle ends) |
| Battle-capped | BATTLE, battle time = `BATTLE_MAX_S` | No | No | Catching-up (battle ends) |
| Held | `is_held()` true (pause, planning, Debrief, menu, save) | No | No | the previous state |
| Catching-up | first CAMPAIGN tick(s) after battle, deferred events due | not until they finish | Yes, in order | Running (campaign) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | Tick → clock | P8 call each tick; `is_held()`; context; `TICK_RATE`. Tick owns holds; the clock only reads them |
| Deterministic RNG & Seed Streams (#2) | clock → RNG | Handlers draw campaign streams only outside BATTLE, in queue order (Core Rule 6; OQ1 and OQ2 answered by rules 9–11) |
| Save/Load & Migration (#5) | clock → save | `base:world_clock` section; `day_now` for autosave D3 and the header |
| Gameplay Settings & Modifiers (#7) | #7 → clock | `rest_days_permille` via `modifier_compose` (rule 13) |
| Sector Map & Travel (#26) | both | Travel uses the CAMPAIGN rate; shows predicted days |
| Ports, Rest & Care (#27) | #27 → clock | Rest requests a skip; base rest lengths and their floor |
| Exposure & Rival Investigation (#32) | #32 → clock | Registers investigator steps (priority 200); must accept "nothing fires in battle" |
| Credits, Upkeep & Sinks (#18); Contracts & Missions (#38); Background Faction Economy (#43) | each → clock | Register their timed events; own what happens when they fire (e.g. contract replacement) |
| After-Action Debrief (#24) | → clock | A defeat's day cost is one skip of `defeat_skip_s(report)` (Debrief D5), bounded by `DEFEAT_MAX_S`; it runs when the Debrief closes |
| Combat HUD (#46), campaign UI | clock → UI | Day and time display; notices |

## Formulas

### D1. Game time per tick

`r_ctx = DAY_S / (REAL_S_PER_DAY_ctx × TICK_RATE)` (must be an integer)

| Variable | Type | Range | Description |
|---|---|---|---|
| DAY_S | int | 86,400 | Game-seconds per day |
| REAL_S_PER_DAY_ctx | int | campaign: 60–240; battle: 360–1,440 | Real seconds per game day at 1× |
| TICK_RATE | int | 60 or 30 | Simulation Tick & Pause |
| r_ctx | int | 1 – 48 | Game-seconds added per unheld tick |

**Examples:** campaign 86,400 / (120 × 60) = 12; at 30 Hz, 86,400 / (120 × 30) =
24. Battle 86,400 / (720 × 60) = 2. Every safe value of the knobs divides
exactly (60, 90, 120, 180, 240 for campaign; 360, 480, 720, 1,440 for battle at
both tick rates).

### D2. Day index

`day_now = clock_s div DAY_S`; shown day = `day_now + 1`.
**Example:** `clock_s` 86,399 → day 0 (shown "Day 1"); +12 → 86,411 → day 1,
and `day_rolled(0, 1)` is reported.

### D3. Battle time cost

`battle_s = min(unheld_battle_ticks × r_BATTLE, BATTLE_MAX_S)`

**Output Range:** 0 – 43,200 s (half a day). **Example:** a 3-minute battle at
1× is 10,800 unheld ticks × 2 = 21,600 s = 0.25 day. A 10-minute battle would
be 72,000 s and is capped at 43,200.

### D4. Skip length in ticks

`ticks ≤ ceil(D / SKIP_S_PER_TICK) + ceil(E / SKIP_EVENTS_PER_TICK)`

| Variable | Type | Range | Description |
|---|---|---|---|
| D | int | 1 – `SKIP_MAX_S` | Skip length in game-seconds |
| E | int | 0 – `EVENT_QUEUE_MAX` | Events due in the window |
| SKIP_S_PER_TICK | int | 3,600 – 86,400; **43,200** | Visual speed of a skip |
| SKIP_EVENTS_PER_TICK | int | 16 – 256; **64** | Events fired per skip tick at most |

**Output Range:** at most 120 + 128 = 248 ticks (about 4 s at 60 Hz) for the
largest skip with a full queue; typically under 20. **Example:** an Admiral rest
of 5 base days: (432,000 × 1,250 + 500) div 1,000 = 540,000 s (6.25 days); with
25 events due, ticks ≤ ceil(540,000 / 43,200) + ceil(25 / 64) = 13 + 1 = 14
(about 0.23 s at 60 Hz).

### D5. Range

Travel alone: 200 hours of real play at 1× is 720,000 s ÷ 120 = 6,000 days
(5.2 × 10⁸ s). Rests and defeats add at most `SKIP_MAX_S` each. Typical
campaigns stay far below 2³¹ s (24,855 days), but a worst case could cross it,
so `clock_s` is 64-bit (rule 1); the save asserts below 2⁵³ − 1.

## Edge Cases

- **If the simulation is held during a skip**: the skip freezes and resumes
  when the hold clears.
- **If the player single-steps in CAMPAIGN**: the clock or the skip advances by
  exactly the ticks run.
- **If a save is taken during catch-up or a skip**: the remaining queue and
  skip target are saved, and the load resumes them exactly (saves are on tick
  boundaries; Save/Load Core Rule 18).
- **If a save is made after a battle's outcome but before catch-up**: the
  deferred events are in the queue and fire after load.
- **If the game falls back to 30 Hz**: the rate doubles per tick; game time per
  real second is unchanged.
- **If a rest composes to 0 seconds**: a programmer error; Ports & Rest sets a
  floor above 0.
- **If a skip is requested beyond `SKIP_MAX_S`**: refused; a rest must be
  shortened. A defeat requesting more than `DEFEAT_MAX_S`, or a second skip, is
  refused as a programmer error.
- **If many events fall due at one instant**: they all fire, in priority then
  `seq` order; a chain past `SAME_INSTANT_CHAIN_MAX` is a programmer error.
- **If the queue is full**: registering refuses with a programmer error naming
  the owner; the owning system must not create unbounded events.
- **If a contract expires during a battle**: it fires at catch-up; its
  replacement (Contracts & Missions) also happens then.
- **If two encounter offers come from one catch-up**: both are presented in the
  order made; the second waits until the first is resolved.
- **If a battle exceeds the time cap**: the clock shows the cap reached; the
  battle continues; no further days accrue.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | P8 call, `is_held()`, context, `TICK_RATE` |
| Deterministic RNG & Seed Streams (#2) | Hard | Campaign streams drawn by handlers outside BATTLE |
| Save/Load & Migration (#5) | Hard | `base:world_clock` section |
| Gameplay Settings & Modifiers (#7) | Soft | `rest_days_permille` |
| #18, #26, #27, #32, #38, #43, Defeat & Debrief | Hard (reverse) | Register events or skips; own their handlers |

Bidirectional check: Simulation Tick & Pause and Deterministic RNG & Seed
Streams list the World Clock; Save/Load lists it (soft, now satisfied). The
systems index lists it under #18, #26, #27, #32, #38 and #43.

## Tuning Knobs

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `REAL_S_PER_DAY_CAMPAIGN` | 120 | 60, 90, 120, 180, 240 | Campaign pace | Days fly; rivals feel frantic | Rivals feel static |
| `REAL_S_PER_DAY_BATTLE` | 720 | 360, 480, 720, 1,440 | Battle's day cost | Battles cost a lot of days | Battles feel timeless |
| `BATTLE_MAX_S` | 43,200 | 21,600 – 86,400 | Ceiling on battle time cost | — | Long battles cost too much |
| `SKIP_S_PER_TICK` | 43,200 | 3,600 – 86,400 | How fast a rest looks | Slow skips | Days blur |
| `SKIP_EVENTS_PER_TICK` | 64 | 16 – 256 | Skip frame cost | Slow skips | Frame spikes |
| `SKIP_MAX_S` | 5,184,000 (60 days) | 7 – 90 days | Ceiling on one skip | Long rests split | Defeat cost too high |
| `DEFEAT_MAX_S` | 1,209,600 (14 days), provisional | 3 – 30 days | Hard ceiling on one defeat's day cost (Pillar 1) | Defeat feels free | Defeat feels like losing the run |
| `SAME_INSTANT_CHAIN_MAX` | 256 | 64 – 1,024 | Runaway-chain guard | — | — |
| `EVENT_QUEUE_MAX` | 8,192 | 1,024 – 16,384 | Queue and save size | Systems refused | Save grows |

## Visual/Audio Requirements

- A day/time readout on campaign screens (Combat HUD shows battle time and the
  cap state).
- During a skip, days visibly roll (a counter, not a cutscene); notices from
  fired events appear in order. No sound requirement beyond a soft UI tick.

## Game Feel

- **Rests are quick.** A rest of a week finishes in well under a second unless
  something interrupts it (D4).
- **Interruptions are calm.** An interrupted rest stops under a hold with the
  reason; nothing happens until the player decides.

## UI Requirements

- Campaign day display ("Day 42"); travel predictions in days.
- A rest panel showing the length (after modifiers) and, **before the rest is
  confirmed, every `visible` queued event that falls within it** (contract
  expiries, known investigator arrivals); a Resume/Abandon prompt when
  interrupted.
- A catch-up summary after battle ("While you fought: …") listing notices from
  deferred events, in order.
- 📌 **UX Flag — World Clock**: include the day display, rest panel and catch-up
  summary in the campaign UX spec (`/ux-design`) before epics.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| P8, `is_held()`, contexts, speed | `design/gdd/simulation-tick-and-pause.md` | Rules 3, 4, 9, 10; AC-36, AC-38 | Rule dependency |
| Campaign streams not drawn in battle | `design/gdd/deterministic-rng-and-seed-streams.md` | Core Rule 6; OQ1, OQ2 (answered) | Rule dependency |
| Autosave by day; section ceilings | `design/gdd/save-load-and-migration.md` | D1, D3; Core Rules 7, 17 | Data dependency |
| Rest scaling | `design/gdd/gameplay-settings-and-modifiers.md` | Rule 13; D2 | Formula dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 3, D1)**: at `TICK_RATE` 60 in CAMPAIGN one unheld tick adds 12 to `clock_s`; at 30 it adds 24; in BATTLE it adds 2 and 4.
- **AC-02 (Logic; rule 3)**: a `REAL_S_PER_DAY` value that does not divide exactly (e.g. 100 at 60 Hz) is refused by content validation.
- **AC-03 (Logic; rules 2, 5, D2)**: from `clock_s` 86,399, one campaign tick gives `day_now` 1 and exactly one `day_rolled(0, 1)`; a skip from day 3 to day 9 reports one `day_rolled(3, 9)`.
- **AC-04 (Logic; rule 6)**: three events at the same `due_s` with priorities 200, 100, 100 and `seq` 5, 9, 7 fire in the order 7, 9, 5.
- **AC-05 (Logic; rule 7)**: during a skip, each handler receives its own `due_s`, not the tick's time.
- **AC-06 (Logic; rule 9)**: an event due mid-battle does not fire during the battle, and no campaign stream is drawn.
- **AC-07 (Logic; rule 10)**: with four deferred events, all four fire in P8 of the first CAMPAIGN tick after the Debrief closes, in order, before that tick adds time.
- **AC-08 (Logic; rule 11)**: a deferred event that registers an encounter offer does not start a battle; the remaining deferred events fire first; the offer is shown under a hold.
- **AC-09 (Logic; rule 3, D3)**: 30,000 unheld battle ticks at 60 Hz add exactly 43,200 s; further ticks add none.
- **AC-10 (Logic; rule 3)**: with `is_held()` true for 600 frames, `clock_s` is unchanged and nothing fires (Simulation Tick & Pause AC-36).
- **AC-11 (Logic; rule 13, D4)**: a 540,000-s skip with 25 events due ends in ≤ 14 ticks with the clock at the target.
- **AC-12 (Logic; rule 13)**: a skip of `SKIP_MAX_S` + 1 is refused.
- **AC-13 (Logic; rule 14)**: an `interrupts_skip` event at T stops the clock at T after all events at T fire; the remaining target is kept; resuming reaches the original target; the result equals an uninterrupted skip with the same choices.
- **AC-14 (Logic; rule 4)**: the same seed and orders at 1× and 2× give identical event logs and `clock_s` at every matching tick count.
- **AC-15 (Logic; rule 16)**: a save mid-skip, loaded, completes the skip byte-identically to an uninterrupted run; a save between outcome and catch-up fires the deferred events after load.
- **AC-16 (Logic; rule 8)**: registering in the past sets the due time to now, logs it, and fires it this pass after earlier `seq`s; cancelling a fired event does nothing; a same-instant chain of 257 fails as a programmer error.
- **AC-17 (Logic; rule 15)**: no UI action other than port rest requests a skip.
- **AC-17b (Logic; rule 13)**: a defeat requesting a skip of `DEFEAT_MAX_S` + 1, or a second skip, is refused as a programmer error.
- **AC-17c (Logic; rule 14)**: during a 30-day rest, an event that changes exposure at day 12 stops the skip at day 12 under a hold; a kind whose owner cleared the flag does not.
- **AC-17d (Logic; rule 3)**: opening the market, refit, care or contract-board screen, or the route planner, holds the simulation; 600 frames pass with `clock_s` unchanged.
- **AC-17e (UI; UI Requirements)**: the rest panel lists every `visible` event due within the rest before confirmation; an event outside the rest window is not listed.
- **AC-18 (Performance; D4)**: the largest skip (60 days, full queue) completes in ≤ 248 ticks and no skip tick exceeds the simulation budget (Simulation Tick & Pause, `sim_budget_ms`).
- **AC-19 (UI)**: the day display, rest panel (with interruption) and catch-up summary have retained screenshots in `production/qa/evidence/` when their stories close.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | ~~**No campaign system acts inside a battle**~~ **Resolved 2026-10-30:** accepted; investigator leads are clock events and never fire in battle (Exposure & Rival Investigation). | #32 | Closed |
| 2 | ~~**Whether an encounter offer can auto-start after being seen**~~ **Resolved 2026-10-30:** never; every contact is an offer the player resolves (Sector Map & Travel rules 17–20; `map.contact` interrupts skips). (e.g. an unavoidable interception) belongs to the encounter's owning GDD. | Sector Map & Travel (#26), encounter owners | When designed |
| 3 | **Pace values** (120 s/day travel, 720 s/day battle, half-day cap) need a playtest against rival pace and contract lengths. | game-designer | First campaign playtest |
| 4 | **Time of day** has no rule at MVP; a day/night or shift mechanic would need a GDD change. | game-designer | Post-MVP |
| 5 | **Section ceiling** (1 MiB) counts within Save/Load's "all other systems" placeholder; confirm when that placeholder is broken down. | Save/Load owner | When ceilings are declared |
| 6 | ~~**`DEFEAT_MAX_S`** value and how a defeat's day cost is computed under it.~~ **Resolved 2026-10-30:** the skip length is `defeat_skip_s(report)` (After-Action Debrief D5: 1 – 7 days at Standard, 14 at most at `defeat_cost_permille` 2000), queued in #8's delivery slot and run when the Debrief closes; `DEFEAT_MAX_S` stays 14 days. | After-Action Debrief (#24) | Closed |
| 7 | **Port-screen holds** (rule 3) must be added to Simulation Tick & Pause's `PLANNING:*` list. | Tick owner | Tick re-review |
| 8 | **Idle-proof contract replacement** (rule 15). | Contracts & Missions (#38) | When #38 is designed |
| 9 | **Default interrupt kinds** (rule 14): resolved for investigators (a find always interrupts a skip; a lead does not; Exposure & Rival Investigation); hostility changes still open. | Faction Reputation | When #17 is revised |
