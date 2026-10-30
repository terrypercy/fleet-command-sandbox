# Combat Event Bus & Battle Record

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on coarsening blurring kill causes and undefined overflow, Vigor-as-disable, the unverified badge, the Dossier dependency, and the pillar header; all five revised
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — the Debrief's causes come only from what the record shows happened); Pillar 4 (Plan in the Open — the battle is replayable and readable after the fact); Pillar 3 (Hands on the Helm — pausing leaves no trace in the record)

## Summary

The Combat Event Bus carries typed, integer-only facts about each tick (hits,
destructions, link cuts, orders, AI choices) from the simulation to the Battle
Record and to presentation, flushed once per tick and never read back by the
simulation. The Battle Record is each battle's authoritative account: a header
that fixes how it was set up, an event log, the replay command log and
end-of-battle aggregates. The Debrief's cause and counter come only from it
(Pillar 1), and old battles stay re-readable as chart replays (Pillar 4).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Deterministic RNG & Seed Streams, Runtime ID Service`

## Overview

The Combat Event Bus carries typed facts about what happened in the
simulation (a hit, a ship destroyed, a link cut, an order applied) from the
tick that caused them to everything that needs to know: the Battle Record,
presentation, audio and debug tools. The **Battle Record** is the permanent log
of one battle, built from those events: a header that says exactly how the
battle was set up, an event log of what happened, the replay command log, and
aggregates computed at battle end.

The Debrief is a **pure function over the Battle Record** (concept). It can
name a specific, actionable cause of defeat ("your links were cut at 3:12 when
the Lance-relay died") only if the Record holds that fact, correctly and in
order. This system guarantees the data; Defeat & Debrief owns the classifier.

Three properties hold everything up:
- **One flush per tick.** Events emitted during the simulation step are
  buffered and flushed once in P9, stamped with `tick_index` (Simulation Tick &
  Pause, rule 3).
- **One-way.** The simulation writes to the bus and never reads it. Nothing a
  subscriber does reaches the tick that produced the event.
- **The record is authoritative.** It is the output of the battle, never
  regenerated from a replay. A same-platform replay must rebuild it byte for
  byte, which is how its correctness is tested.

## Player Fantasy

**Every battle leaves a true account.** The player experiences this system
through the Debrief and the chart replay: an ink-on-paper account of the fight
that says what happened, when, and because of whom, and is never wrong about
it. A defeat is not a mystery; it is a record the player can read and answer.

**Pillars served:**
- **Pillar 1, *Every Defeat Is a Lead*:** the Debrief's cause and counter come
  only from what the Record shows happened.
- **Pillar 4, *Plan in the Open*:** old battles can be re-read and replayed as
  chart marks, so the next attempt is planned from evidence.
- **Pillar 3:** pausing leaves no trace in the record, so nothing ever scores or
  judges the player for using pause.

**This system must never make the player feel:** "the Debrief blamed the wrong
thing" or "I can't see what killed me".

## Detailed Design

### Core Rules

**A. The bus**

1. **Only the simulation emits.** `emit(event)` may be called only by
   simulation handlers during P1–P8 of a tick (P8 covers World Clock and the
   end-of-tick spawn/retire step, Runtime ID Service Core Rule 3). An emit from
   anywhere else (presentation, a subscriber, loading, P9) is a programmer
   error sent to `FatalSink`.
2. **One buffer, one flush.** Events go into one per-tick buffer. P9 flushes it
   once as a frozen `TickBatch {tick_index, events}`; each event carries its
   per-tick `seq` (append index). **Order is append order**: phase order, then
   each phase's handler order, then ascending Runtime ID (Simulation Tick &
   Pause rule 3). Nothing is sorted afterwards; debug builds assert the order.
3. **Delivery is after the step and read-only.** Subscribers receive each batch
   after P9, in tick order (all ticks of a frame, one by one). They cannot emit
   and cannot write simulation state. Anything a subscriber causes (a UI order)
   goes through the order queue and applies at the earliest in the next P1.
4. **The simulation never reads the bus or the Record.** A static check enforces
   it. The Record is therefore a pure function of starting state, battle seed
   and recorded commands.
5. **Two tiers of event.** *Bus-tier* events (one `Hit` per projectile, for VFX
   and audio) exist only on the bus. *Record-tier* events are written to the
   Battle Record. Every event type declares its tier. The bus runs in CAMPAIGN
   ticks too; the Record attaches only in BATTLE.
6. **Events hold integers only.** Every field is an integer, a Runtime ID, a
   tick, or a small code. Positions are quantized world units (`qx`, `qy`);
   headings are `qh` in 1/256 turn. No event carries a name, a string, a
   content-ID string or a float. Content references are a u16 index into the
   header's content table.
7. **Pause is not an event.** Pausing, resuming and holds are not ticks and are
   never recorded.
8. **Mods may add event types**, named `<mod_id>:<name>`. Numeric codes are
   assigned at load by sorting the namespaced names, and the header carries the
   type table and each type's fixed-width schema. Payloads are
   length-prefixed, so a reader can skip a type it does not know. Each mod has a
   record-tier budget of `MOD_EVENTS_PER_TICK` per tick. Core aggregates and the
   Debrief ignore unknown types.

**B. The event set (`EVENT_SCHEMA_VERSION` = 1)**

9. **The MVP taxonomy.** Owning GDDs may add fields (raising the schema version)
   but not remove these.

   | Family | Event (tier) | Fields |
   |---|---|---|
   | Damage | `Hit` (bus) | shooter, slot, target, dmg, dmg_type, shield_absorbed |
   | Damage | `DamageBucket` (record) | attacker, target, window_start, dmg_hull, dmg_shield, hits, dmg_type_mask |
   | Ship state | `Destroyed` (record) | ship, killer, killer_slot, qx, qy |
   | Ship state | `Disabled` (record) | ship, cause_code |
   | Ship state | `Retreated` (record) | ship, cause_code (ordered / auto / rout) |
   | Ship state | `OwnerChanged` (record) | ship, old_owner, new_owner |
   | Vigor | `VigorBand` (record) | ship, from, to (bands owned by Vigor #13) |
   | Vigor | `VigorCeilingEroded` (record, at battle end) | ship, amount |
   | Coherence | `LinkState` (record) | relay, target, from, to (SOLID / DASHED / SNAPPED / RELAYED), cause_code (relay_lost / jammed / range / capacity), actor |
   | Coherence | `CoherenceBand` (record) | fleet, from, to |
   | Orders | `OrderApplied` (record) | order_id, subject, kind, target |
   | Orders | `OrderRejected` (record) | order_id, reason (Simulation Tick & Pause) |
   | Orders | `OrderEnded` (record) | order_id, subject, outcome (done / target_destroyed / target_retreated / target_lost / replaced / cleared) — Fleet Orders rule 12 |
   | AI | `TargetChosen` (record, on change only) | ship, target, reason_code (focus_called / nearest / lowest_hull / threat / ordered / retaliate) |
   | AI | `FocusCalled` (record) | fleet, target |
   | Auto-pause | `AutoPauseTrigger` (record) | trigger_id, subject (fires whether or not the player has the trigger enabled; Simulation Tick & Pause D7) |
   | Lifecycle | `BattleStart`, `BattleEnd` (record) | outcome, cause_code |
   | Spawn/retire | `Spawned` (record) | id, kind, content_ref, name_ref, side, owner |
   | Spawn/retire | `Retired` (record) | id |
   | Track | `Track` (record, every `TRACK_PERIOD` ticks) | ship, qx, qy, qh |

   Damage is folded into `DamageBucket`s: one per (attacker, target) pair per
   `DAMAGE_WINDOW` ticks with any damage. `OrderIssued` is a replay-log entry,
   not an event (rule 12).

**C. The Battle Record**

10. **The header** is written at battle start and holds: battle seed,
    `battle_ordinal` and stream registry version (Deterministic RNG & Seed
    Streams); `EVENT_SCHEMA_VERSION` and the mod type table; the **roster**
    (per ship: Runtime ID, kind, content reference, **name at the time**, side,
    owner, faction, slot → weapon content); the content table; `next_id` at
    start and `battle_start_tick` (Runtime ID Service, Simulation Tick & Pause);
    the frozen `ModifierSet` (Gameplay Settings & Modifiers rule 8); the content
    hash; engine version, build, OS, CPU architecture and `TICK_RATE`.
11. **Names live in the record, once.** The roster and each `Spawned` event
    store a thing's name and kind when it enters the record, so every ID in the
    record resolves to a name without asking the Runtime ID Service (Runtime
    ID Service, Core Rule 8: names are labels, kept at the time).
12. **Event log and command log are separate.** The **command log** (applied
    orders and flagship command changes; Simulation Tick & Pause rule 6) is the
    replay *input*. The **event log** is the battle's *output*, and it is
    authoritative.
13. **Aggregates at battle end.** When the battle context ends, before the
    Debrief hold, the Record computes and stores alongside the raw log:
    - per ship: damage dealt and taken by type, time alive, last Vigor band,
      killer, and Ship AI's rationing counters (held-fire ticks per Vigor band,
      ember shots fired; Ship AI rule 14);
    - per death, a **kill window**: per-attacker damage, hits and damage types
      over the `KILL_WINDOW` ticks before `Destroyed`. It is built from a
      per-target ring buffer the Record fills from bus-tier `Hit`s and written
      as a record-tier `KillWindow` at the moment of `Destroyed`, so its
      precision never depends on `DAMAGE_WINDOW` or coarsening (deterministic,
      because the bus is);
    - per fleet: the Coherence timeline and every link cut, with actor and tick;
    - a `CoherenceSummary` (Coherence & Links rule 19): time in each band per
      fleet, and per relay its subtree size, damage taken, and whether it was
      ever struck, strained or stalled.
    Aggregates are computed by the Record from the log, never by the simulation.
14. **The Debrief contract** (data only; classification is Defeat & Debrief's):
    - *"Links cut at 3:12 by X"*: `LinkState(to = SNAPPED, cause, actor)` with
      `Destroyed(relay, killer)` and the `CoherenceBand` drop; battle time is
      `(tick − battle_start_tick) ÷ TICK_RATE`; X's name from the roster.
    - *"Lost to focus fire"*: the kill window's attacker count and damage
      shares, with `TargetChosen(reason = focus_called)` or `FocusCalled`.
    - *"Vigor ran dry"*: `VigorBand → EMPTY`, then `Destroyed` or `Retreated`
      within `KILL_WINDOW`. Running dry changes behaviour and never disables a
      ship (concept: no hard lockout), so `Disabled.cause_code` never means
      Vigor exhaustion.
    - *The counter*: `dmg_type_mask` with the roster's slot → weapon content.
15. **Replays.** A replay re-runs the battle from the header and command log. It
    is **verified** only when build, content hash, registry version, OS and CPU
    architecture all match; then it must rebuild a byte-identical event log. An
    unverified replay is never used: the Debrief shows the event log as
    recorded, **with no player-facing badge**, because the log is
    authoritative either way; only re-simulation is unavailable. Where a
    replay would be offered, the UI says "Re-simulation unavailable on this
    build", never in the pencil-grey "uncertain" style that belongs to
    historical evidence (concept). "Not re-verified" appears only in debug
    views and the AI-vs-AI Runner (Simulation Tick & Pause rule 14). **Chart playback is drawn from `Track` samples and events, never from
    re-simulation**, so old and unverified battles always play back.
16. **An event-log hash.** The Record keeps a rolling 64-bit hash of the encoded
    event stream, per tick and per battle (algorithm in the Tick/determinism
    ADR, never the engine's `hash()`). A verified replay compares it, catching
    encoder drift that `state_hash` cannot see.

**D. Size and retention**

17. **The live record has ceilings.** During a battle the event log is capped at
    `EVENT_LOG_MAX` (2 MiB), plus an overflow allowance `EVENT_OVERFLOW_MAX`
    (512 KiB) for discrete events only, and the command log at `CMD_LOG_MAX`
    (1 MiB); with simulation state (0.5 MiB, placeholder) they make Save/Load's
    4 MiB "simulation + battle part" ceiling. Coarsening, deterministic and
    logged in the header:
    - at 50 % and 75 % of `EVENT_LOG_MAX`, `DAMAGE_WINDOW` and `TRACK_PERIOD`
      double, never beyond 240 ticks (their safe range);
    - at 90 %, buckets and tracks stop and running per-pair damage totals and a
      last-known position per ship take over;
    - discrete record-tier events continue into the overflow allowance. If even
      that fills, the lowest-value discrete events (`TargetChosen`) stop first;
      `Destroyed`, `Retreated`, `LinkState`, `VigorBand`, `CoherenceBand`,
      `KillWindow` and `BattleEnd` are never dropped (they are bounded by the
      roster). If the command log would pass its cap, it stops and
    the record is flagged `replay_truncated`; the event log stays complete and
    authoritative.
18. **Archived records** live in their own save section, `base:battle_archive`,
    capped at `ARCHIVE_MAX` (5 MiB, uncompressed, as every Save/Load ceiling):
    - **Full** records (header, event log, command log, aggregates): the newest
      first, up to `K_FULL` (8), plus the latest defeat at each stronghold
      (pinned), while their total stays within `ARCHIVE_FULL_MAX` (4 MiB).
      A full record that no longer fits becomes a summary.
    - **Summaries** (header essentials and aggregates, names and kinds inline):
      the newest `SUMMARY_MAX` (512), within 1 MiB.
    - Full records report every ID they hold (Save/Load, held IDs). Summaries
      keep Runtime IDs only for the player's ships; enemies in a summary are
      kept as name + kind + content reference without an ID, releasing their
      tombstones for compaction (Runtime ID Service, Core Rule 6, Open
      Question 5).

### States and Transitions

| State | Entered when | Behaviour | Leaves to |
|---|---|---|---|
| Idle | CAMPAIGN | Bus delivers campaign batches; no record | Recording (battle starts) |
| Recording | `BattleStart` | Header written; record-tier events and commands appended each P9 | Finalizing (battle context ends) |
| Finalizing | battle ends | Aggregates computed; event-log hash closed | Archived-full (before the Debrief hold) |
| Archived-full | finalized | Kept in full | Archived-summary (pushed out by count or bytes, unless pinned) |
| Archived-summary | demoted | Aggregates and inline names only | Dropped (past `SUMMARY_MAX`) |

A suspend save during Recording saves the live record; resuming continues
appending at the same `seq` (Save/Load Core Rule 22).

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | Tick → #9 | P9 flush with `tick_index`; `battle_start_tick`; the command log contents (rule 6). **Amendment:** emits allowed in P1–P8 |
| Deterministic RNG & Seed Streams (#2) | #2 → #9 | Battle seed, ordinal and registry version for the header |
| Runtime ID Service (#3) | both | IDs in every event; roster and `next_id`; names at the time; held IDs and summary release |
| Save/Load & Migration (#5) | #9 → #5 | Live record in the battle part (event log 2 MiB, command log 1 MiB); `base:battle_archive` (5 MiB) |
| Gameplay Settings & Modifiers (#7) | #7 → #9 | Frozen `ModifierSet` in the header |
| Vigor (#13), Coherence & Links, Weapons & Damage, Ship AI (#20), Fleet Orders (#19) | each → #9 | Emit their events (rule 9); own their bands and reason codes |
| Defeat & Debrief | #9 → Debrief | The record and aggregates; classifier lives there |
| Dossier (via Debrief) | #9 → Dossier | The Dossier copies its facts at Debrief time and never depends on an archived full record surviving demotion (rule 18) |
| AI-vs-AI Runner | #9 → runner | Records and their hashes for diffing |
| Presentation (HUD, VFX, audio) | #9 → presentation | Read-only batches after P9 |

## Formulas

### D1. Event-log size per minute

`S_min = N_b × B_b + E_d × B_e + T × B_t`, where `N_b = P_act × (3600 ÷ DAMAGE_WINDOW)` and `T = ships × (3600 ÷ TRACK_PERIOD)`

| Variable | Type | Range | Description |
|---|---|---|---|
| P_act | int | 0 – 300 | Active attacker → target pairs |
| DAMAGE_WINDOW | int | 30 – 240 ticks (60) | Bucket width |
| ships | int | 2 – 100 | Ships in the battle |
| TRACK_PERIOD | int | 30 – 240 ticks (60) | Ticks between `Track` samples |
| E_d | int | 0 – 6,000 | Discrete record events per minute |
| B_b, B_e, B_t | int | 12 / 10 / 7 bytes (estimates) | Encoded sizes |
| S_min | int | 0 – ≈ 280 KB | Event-log bytes per minute |

**Examples:** typical (40 ships, 50 pairs, 1,500 events/min): 3,000 × 12 +
1,500 × 10 + 2,400 × 7 = 36,000 + 15,000 + 16,800 ≈ **68 KB/min**. Heavy (100
ships, 150 pairs, 4,000 events/min): 108,000 + 40,000 + 42,000 ≈ **190 KB/min**.
The command log adds at most 3,600 × 8 B ≈ 29 KB/min.

### D2. How long the live caps last

`minutes_to_first_coarsening = 0.5 × EVENT_LOG_MAX ÷ S_min`.
**Example:** 1 MiB ÷ 68 KB ≈ 15 minutes typical; ÷ 190 KB ≈ 5.5 minutes heavy.
After both doublings the heavy rate falls to about 40 KB/min of discrete
events plus about 40 KB/min of buckets and tracks; buckets and tracks stop at
90 % (about 18 minutes heavy). From then on only discrete events (≈ 40 KB/min)
are written, into the remaining 10 % plus `EVENT_OVERFLOW_MAX`: about 18 more
minutes before the lowest-value events stop.

### D3. Archive size

`A = Σ full_bytes + N_sum × S_sum ≤ ARCHIVE_MAX`

**Example:** 8 typical 10-minute battles at ≈ 0.68 MB uncompressed = 5.4 MB,
over `ARCHIVE_FULL_MAX` (4 MiB = 4.19 MB): the oldest two become summaries,
leaving 6 full ≈ 4.08 MB. 512 summaries × 2 KB = 1 MiB. The section
stays within 5 MiB. Tombstones held ≈ full records × (roster + spawned) ≈ 6 ×
60 = 360, plus player-ship IDs.

### D4. Effect on `SAVE_MAX`

Adding `ARCHIVE_MAX` to Save/Load D1: 23,858,176 + 5,242,880 = 29,101,056 B
(27.75 MiB) × 1.5 = 41.63 → **`SAVE_MAX` = 42 MiB**.

## Edge Cases

- **If a battle ends on tick 0**: the record holds the header, `BattleStart`
  and `BattleEnd` only.
- **If a projectile hits after its shooter was retired**: the event names the
  shooter's ID; compaction never runs in battle (Runtime ID Service).
- **If one tick destroys 20 ships**: buffers grow (logged); no record-tier event
  is ever dropped; presentation spreads its effects over frames on its own
  budget.
- **If per-tick `seq` would overflow** (65,535): a programmer error in debug; in
  release, bus-tier events are dropped first, record-tier never.
- **If a mod event type is unknown at load**: its bytes are kept and skipped; a
  count of skipped events is reported.
- **If a mod exceeds `MOD_EVENTS_PER_TICK`**: the excess is refused with a
  logged warning naming the mod; core events are unaffected.
- **If the content hash, build or platform differs**: the replay is unverified;
  the log and chart playback still show (rule 15).
- **If the command log is truncated**: the record is flagged; no replay is
  offered for it; the Debrief still works.
- **If the player suspends mid-battle**: the live record is saved; resuming
  appends at the same `seq` with no gap or duplicate.
- **If a pinned stronghold defeat would exceed `ARCHIVE_FULL_MAX` alone**: it is
  kept in full and unpinned records demote first; pinned records are bounded by
  the stronghold count.
- **If the player pauses for an hour**: nothing is recorded (rule 7).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | P9 flush, `tick_index`, `battle_start_tick`, command log |
| Deterministic RNG & Seed Streams (#2) | Hard | Header seed and registry version |
| Runtime ID Service (#3) | Hard | IDs, roster, `next_id`, held IDs |
| Save/Load & Migration (#5) | Hard | Battle part and archive section |
| Gameplay Settings & Modifiers (#7) | Soft | `ModifierSet` in the header |
| Event emitters (#13, #19, #20, Coherence, Weapons) | Hard (reverse) | Emit rule 9 events |
| Defeat & Debrief, AI-vs-AI Runner, HUD/VFX/audio | Hard (reverse) | Consume batches and records |
| Dossier | Soft (reverse) | Copies facts at Debrief time; never reads the archive later |

Bidirectional check: Simulation Tick & Pause, RNG, Runtime ID Service, Save/Load
and Settings already name this system.

## Tuning Knobs

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `DAMAGE_WINDOW` | 60 ticks | 30 – 240 | Damage timing precision vs size | Large logs | Vague kill timing |
| `KILL_WINDOW` | 600 ticks | 300 – 1,800 | How far back "what killed me" looks | Misses build-up | Blames old damage |
| `TRACK_PERIOD` | 60 ticks | 30 – 240 | Chart playback smoothness | Large logs | Jerky playback |
| `EVENT_LOG_MAX` | 2 MiB | 1 – 3 MiB | Live battle record size | Early coarsening | Larger saves |
| `EVENT_OVERFLOW_MAX` | 512 KiB | 256 KiB – 1 MiB | Room for discrete events after coarsening | Low-value events stop sooner | Larger saves |
| `CMD_LOG_MAX` | 1 MiB | 0.5 – 1.5 MiB | Replay length | Truncated replays | Larger saves |
| `K_FULL` | 8 | 3 – 20 | Full records kept | Little history | Bytes cap binds |
| `ARCHIVE_FULL_MAX` | 4 MiB | 2 – 8 MiB | Full-record bytes | Few full records | Larger saves |
| `SUMMARY_MAX` | 512 | 128 – 2,048 | Battle history depth | Short history | Larger saves |
| `MOD_EVENTS_PER_TICK` | 32 | 8 – 128 | Mod event budget | Mods starved | Log bloat |

## Visual/Audio Requirements

None of its own. Presentation subscribes to batches; the Debrief draws its chart
replay (ink-on-dark-paper chart language, concept) from `Track` and events.

## Game Feel

- **Effects follow the tick, never lead it.** VFX and audio react to flushed
  batches, so what the player sees always matches the record.
- **No hitches from recording.** Emission and the P9 flush stay within their
  budget share (AC-19).

## UI Requirements

Owned by Defeat & Debrief and the Battle History view: "Re-simulation
unavailable on this build" where a replay would be offered (never a badge on
the account itself, rule 15), a "replay unavailable (truncated)" note, and battle-time stamps as mm:ss. No
screen of its own.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| P9 flush, phases, command log, platform scope | `design/gdd/simulation-tick-and-pause.md` | Rules 3, 6, 14; AC-37 | Rule dependency (emit window amended to P1–P8) |
| Header seed; replay from seed | `design/gdd/deterministic-rng-and-seed-streams.md` | Battle seed and registry version in the record header; AC-36 | Data dependency |
| IDs, names at the time, tombstones | `design/gdd/runtime-id-service.md` | Core Rules 3, 6, 8; Open Question 5 | Rule dependency |
| Section ceilings, battle part | `design/gdd/save-load-and-migration.md` | D1; Core Rule 22 | Data dependency (adds `base:battle_archive`; `SAVE_MAX` → 42 MiB) |
| ModifierSet in the header | `design/gdd/gameplay-settings-and-modifiers.md` | Rule 8 | Data dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 2)**: events emitted across 3 ticks produce exactly 3 flushes, each stamped with its own `tick_index` (Simulation Tick & Pause AC-37).
- **AC-02 (Logic; rule 2)**: over 10,000 ticks of a busy fixture, every flushed tick's events are in phase order, then handler order, then ascending Runtime ID, with `seq` strictly increasing; 0 violations.
- **AC-03 (Logic; rule 1)**: `emit()` from a subscriber, a UI call or P9 reaches `FatalSink`.
- **AC-04 (Logic; rules 3, 4)**: a static check finds no simulation code that reads the bus or the Record; with a null sink, a recording sink and a capture sink, 3,600 ticks give identical `state_hash` sequences; a subscriber's order takes effect no earlier than the next tick.
- **AC-05 (Logic; rule 6)**: the encoded record contains no strings outside the header tables, and no float field.
- **AC-06 (Logic; rule 7)**: pausing and resuming 50 times during a battle changes nothing in the record.
- **AC-07 (Logic; rule 8)**: two mods' event types get the same codes regardless of mod load order; a record with an unregistered mod type loads, skips it and reports the skipped count; a mod over its per-tick budget is refused with a warning.
- **AC-08 (Logic; rules 10, 11)**: the header contains every listed field; the `ModifierSet` round-trips; every Runtime ID in the record resolves to a name and kind from the roster or a `Spawned` event without calling the Runtime ID Service.
- **AC-09 (Logic; rule 12, 15)**: a same-platform replay from the header and command log rebuilds a byte-identical event log and an equal event-log hash (RNG AC-36).
- **AC-10 (Logic; rule 15)**: a record replayed with a different OS or content hash shows its event log unchanged with no player-facing badge; the replay option reads "Re-simulation unavailable on this build"; the debug view and the Runner mark it "not re-verified"; chart playback still works from `Track`.
- **AC-11 (Logic; rule 14)**: in the fixture "relay killed at tick 11,520 with `battle_start_tick` 0", the record holds `LinkState(SNAPPED, relay_lost, actor)` at tick 11,520, shown as 3:12.
- **AC-12 (Logic; rule 13)**: in a 3-attacker focus-fire fixture, the kill window lists all 3 attackers and their damage shares sum to 100 %.
- **AC-13 (Logic; rule 14)**: a ship whose Vigor band goes to EMPTY and which is destroyed within `KILL_WINDOW` has both events in that order; no fixture produces `Disabled` with a Vigor cause.
- **AC-14 (Logic; rule 17, D2)**: a heavy fixture run for 40 minutes keeps the log ≤ `EVENT_LOG_MAX` + `EVENT_OVERFLOW_MAX`; windows double exactly at 50 % and 75 % and never exceed 240 ticks; buckets and tracks stop at 90 %; no never-dropped event is missing compared with an uncapped run; kill windows equal the uncapped run's exactly.
- **AC-15 (Logic; rule 17)**: a command log forced past `CMD_LOG_MAX` sets `replay_truncated`; the event log is complete.
- **AC-16 (Logic; rule 18, D3)**: after 10 battles, at most `K_FULL` full records remain plus pinned defeats, their total ≤ `ARCHIVE_FULL_MAX`; the 9th-oldest is a summary; its enemy-only tombstones are compacted at the next campaign save; the summary still names those enemies correctly.
- **AC-17 (Logic; Edge Cases)**: a suspend save mid-battle, resumed, continues the record with no gap or duplicate `seq`, and the final record equals an uninterrupted run's.
- **AC-18 (Logic; D4)**: with `base:battle_archive` registered at 5 MiB, Save/Load's computed `SAVE_MAX` is 42 MiB.
- **AC-19 (Performance)**: emission plus the P9 flush take ≤ 10 % of the simulation budget at the 95th percentile in Simulation Tick & Pause's steady fixture; a 20-kill tick's P9 takes ≤ 0.5 ms; after warm-up there are 0 per-event Object or Dictionary allocations.
- **AC-20 (Logic; edge)**: a battle ending on tick 0 produces a record with exactly the header, `BattleStart` and `BattleEnd`.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Emit window P1–P8** (rule 1) must be confirmed by Simulation Tick & Pause, whose text says P1–P7. | Tick owner | Tick re-review |
| 2 | **Encoding** (varint, compression) and the event-log hash algorithm. Engine behaviour of packed arrays and allocation in 4.7.2 is NOT SOURCEABLE beyond `deprecated-apis.md:53` (typed arrays) and needs a spike. | technical-director, gameplay-programmer | Combat event bus ADR |
| 3 | **Byte estimates** (D1) are guesses until the encoder exists. | performance-analyst | Event bus spike |
| 4 | **Vigor bands, Coherence bands, reason codes**: owned by Vigor, Coherence & Links and Ship AI. | those GDDs | When designed |
| 5 | **Pinning beyond strongholds** (e.g. the player pins a battle to keep it). | game-designer | Vertical Slice |
| 6 | **Runtime ID summary release** (rule 18) answers Runtime ID Open Question 5; its owner must accept it. | Runtime ID owner | Runtime ID re-review |
