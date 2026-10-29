# Runtime ID Service

> **Status**: In Design
> **Author**: owner + agents
> **Last Updated**: 2026-10-29
> **Last Verified**: 2026-10-29
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — every Debrief cause traces to a specific ship or fleet); Pillar 2 (The Truth Is Yours to Tell — fragments and investigators tracked across the campaign)

## Summary

[To be designed]

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

Runtime ID Service gives every live thing in the simulation a **Runtime ID**: a
plain integer that names one specific instance for as long as the campaign
lasts. Live things include this ship, that fleet, the archive fragment the
player is carrying, and the rival investigator on their trail. An ID is issued
once, saved and restored exactly, and **never reused within a save**, even
after the thing it named is destroyed. Because IDs are integers with a fixed
order, every system can process live things in one deterministic order
(*ascending Runtime ID*, Simulation Tick & Pause rule 3). Saves, the Combat
Event Bus and Battle Record, the Debrief and the RNG system's per-ship streams
can all point at "the same ship" and mean exactly the same thing.

A Runtime ID is **not** a content ID. A content ID such as `base:hull.lancer` or
`mymod:weapon.arc` names a *kind* of thing, comes from data, and belongs to
Content Data & Mod Loading (#4). A Runtime ID names *one instance* of that kind:
the third Lancer built in this campaign. A live thing carries both, its own
Runtime ID and its definition's content ID.

The player never sees an ID, but feels what it guarantees:
- **The Debrief names the right ship.** "Your escort *Varrow* was cut off from
  the line at 3:12" is a fact about one ship, traced through the Battle Record.
- **A save brings back the same galaxy.** The fragment the player is holding,
  and the investigator who is about to find another, are the same ones after a
  load.
- **Battles replay exactly.** Every system walks live things in the same order
  every time.

Without this system three things would break:
- Systems would refer to live things by engine handles, node paths or list
  positions. These change between runs and across save and load, so replays,
  the Battle Record and saves would point at the wrong thing, or at nothing.
- Processing order would fall back to creation or dictionary order, which
  shifts as content changes. Determinism (Simulation Tick & Pause rule 14) and
  per-ship RNG streams (Deterministic RNG & Seed Streams, rule 5) depend on a
  stable order and on IDs that are never reused.
- Cross-system references (an order targeting a ship, a fragment held by a
  fleet, a blame event about a race's ship) would need a bespoke scheme in
  every system.

*How* IDs are stored and issued (the counter's representation, any per-kind
ranges, how a lookup from ID to object is kept) is an implementation choice →
**becomes an ADR** (likely the save schema or Tick/Pause/Determinism ADR). This
GDD specifies behaviour, guarantees and contracts only.

## Player Fantasy

**Every ship is remembered as itself.** The player experiences this system
**indirectly**. What they feel is that the galaxy keeps track of individuals,
not counts.

The escort they lost at 3:12 is the same ship the Debrief names, the Battle
Record follows and the campaign remembers. A fragment they have carried through
three saves is still that fragment. The rival who beat them to a find is the same
rival who comes back later. **Follow any thread back, and it leads to exactly one
ship, fragment or rival.**

*Anchor moment:* the Debrief says "*Varrow* was cut off from the line at 3:12."
The player remembers *Varrow* breaking formation. The game and the player are
talking about the same ship.

**Pillars served:**
- **Pillar 1, *Every Defeat Is a Lead*:** "Can the Debrief name at least one
  specific, actionable cause and counter for this loss?" A cause is specific only
  if it names the right ship.
- **Pillar 2, *The Truth Is Yours to Tell*:** fragments and the rivals hunting
  them stay themselves across the whole campaign, so the case the player builds
  is about real, persistent things.

**Tone:** modest and archival. The verbs are *remembers, names, keeps, follows*.
The player never sees a number; they see names, and the names always point at
the right thing.

**This system must never make the player feel:**
- **That the record confused their ships.** No Debrief, Ledger or save may blame,
  credit or bring back the wrong ship, fragment or rival.
- **That a dead ship came back.** A new ship never inherits a destroyed ship's
  history, losses or blame, even with the same hull and the same name.

*Shaped by `creative-director` (framing A, "Every ship is remembered as itself",
closed with framing B's line, "the thread always leads to one thing"). Framing B
alone was judged too close in tone to the RNG GDD's "sealed" framing.*

## Detailed Design

### Core Rules

1. **One counter, starting at 1.**
   - Every Runtime ID comes from one global, monotonic counter, `next_id`,
     shared by every kind of live thing.
   - `0` is `NONE`. It is never issued and means "no thing" wherever an ID field
     is empty. Negative values are invalid.
   - The ID is a plain integer and does **not** encode its kind. Ascending Runtime
     ID is therefore pure creation order across all kinds, the total order
     Simulation Tick & Pause rule 3 relies on.
   - IDs stay at or below `MAX_RUNTIME_ID = 2^53 − 1` (D1), so every ID is exact as
     a JSON number and as a float. Issuing past it is a fatal error, and the
     counter never wraps.
2. **What gets a Runtime ID.**
   - Ships (the player's, allied, enemy and machine), fleets, archive fragments
     and rival investigators get one. Each later GDD that adds a kind of live
     thing declares it here, through the kind table (rule 5).
   - **Projectiles do not.** A projectile gets a **battle-local sequence number**
     from a counter that restarts at 1 every battle. It is a separate type, is
     never accepted where a Runtime ID is expected, and is never shown to the
     player.
     - Projectiles are short-lived and numerous (about 200,000 in a typical
       battle, D3), and nothing refers to a dead projectile after its battle.
     - A mid-battle save holds the sequence counter and each live projectile's
       sequence number, so a reload numbers new projectiles exactly as the
       original run did (D3). Hit rolls are
       keyed by shooter ship and weapon slot, not by projectile (Deterministic
       RNG & Seed Streams, rule 5).
     - In the Battle Record, a hit names its shooter's Runtime ID and slot.
     - Within a phase, ships are processed in ascending Runtime ID, then
       projectiles in ascending sequence number (Combat Space #11 owns
       projectile processing). *This needs a one-line note in Simulation Tick &
       Pause rule 3 at its re-review.*
3. **Issued only inside the simulation, in a deterministic order.**
   - `issue(kind, content_id)` can be called only from a simulation step: tick
     phases P1–P8, a campaign step, or new-game setup. Within a phase, issuance
     follows the issuer's processing order, ascending Runtime ID (Simulation Tick
     & Pause rule 3). A replay therefore issues exactly the same IDs.
   - UI, presentation, previews, placement ghosts, tools and loading never issue
     an ID. A preview uses `NONE` or a presentation-local handle.
   - A thing's ID is issued at the spawn call. The thing becomes live at the end
     of the phase that spawned it, and first acts in the next tick. For example,
     a reinforcement spawned in P4 is not processed again in P5–P8 of the same
     tick.
   - A spawn that is later cancelled still uses up its ID. Gaps in the sequence
     are normal.
4. **Never reused, never reassigned.**
   - Once issued, an ID names that one thing for the rest of the save. It is
     never issued again, even after the thing is destroyed, and it never moves to
     another thing.
   - **Ships keep their ID through changes of hands:** lending to or from an
     ally, capture, and a breakaway faction joining the player. Owner and faction
     are fields owned elsewhere, not part of identity. History, losses and blame
     stay with the ship (Player Fantasy).
   - **Fleets:** a ship moving between fleets keeps its ship ID. A split creates a
     new fleet ID for the new group; the original keeps its own. A merge retires
     the absorbed fleet's ID. (Fleet tie-break RNG streams are keyed by fleet ID,
     so this matters.)
5. **The service owns identities, not objects.**
   - The service owns `next_id` and one **identity table**: for every ID ever
     issued, its kind, its content ID, its issue tick, and its status.
   - Each owning system keeps its own records, keyed by ID, inside `SimState`:
     Combat Space holds ships, Archive Fragments holds fragments, and so on. The
     service holds no gameplay data and no object references. That avoids two
     sources of truth, and keeps the service in the Foundation layer.
   - **Looking a thing up:** `status(id)` answers `LIVE`, `INERT`, `RETIRED`,
     `COMPACTED`, `NEVER_ISSUED` or `NONE`, and `kind_of(id)` answers for any ID
     still in the table, including retired ones (not compacted ones, rule 6). The owning system resolves a live ID to its record
     (for example `get_ship(id)`), and returns `GONE` for any ID that is not live.
     **A lookup never returns a different thing.**
   - Each owning system checks `kind_of(id)` at its own boundary in debug builds,
     so a fleet ID passed where a ship ID is expected fails loudly. Release builds
     have no such check; GDScript has no zero-cost typed IDs.
6. **Retirement keeps a tombstone.**
   - When a thing is destroyed or removed, its owner calls `retire(id)` at a fixed
     point: the end of P7 in battle (Simulation Tick & Pause rule 3), or the end
     of the campaign step. Everything earlier in that tick still sees it.
   - Its entry in the identity table becomes a **tombstone**: kind, content ID,
     issue tick and retire tick. The Battle Record, the Debrief and blame history
     can ask what an old ID was for as long as they refer to it.
   - **Unreferenced tombstones are compacted** at each campaign save. A
     tombstone that no kept record refers to (Battle Record history, blame, the
     Debrief, the Dossier, any saved section) is dropped. Owner decision
     (2026-10-29); without it, a long campaign's table outgrows the save budget
     (D2).
     - The ID is still **never reissued**. That guarantee comes from `next_id`,
       not from the tombstone.
     - `status(id)` answers **`COMPACTED`** for an ID below `next_id` that is no
       longer in the table: retired, with its details forgotten. `kind_of(id)`
       is then unknown, so a record that needs a retired thing's kind or name
       after it stops referring to the ID stores them itself (Open Questions).
     - Compaction happens only at a campaign save, never in battle, so a battle
       and its replay see the same table.
   - The service stores **no names**. A record that must show a name later (the
     Debrief, blame history) stores the name it had at the time, as part of that
     record (Open Questions).
7. **References between systems are by ID only.**
   - Orders, target locks, escort assignments, fleet membership, held fragments,
     the Battle Record and saves all store Runtime IDs.
   - No system keeps an object reference past the end of the function that
     resolved it. Holding a resolved record in a local variable inside one phase
     is fine; holding it in a field is not.
   - **Stale references are checked on read.** A holder whose ID now resolves
     to `GONE` clears it in its own phase and emits an event stamped with
     `tick_index`, so the cleanup is replay-visible. Each holder's GDD owns its
     policy: for example Fleet Orders (#19) decides what an order whose target
     is gone does, and Simulation Tick & Pause already rejects an order whose
     subject is gone (`OrderRejected(subject_lost)`).
   - **Fleet membership** is the exception: Fleet Coordination (#21) prunes
     retired ship IDs at the end of P7, so the list is accurate for the next
     tick.
8. **Names are labels, never keys; IDs are never shown.**
   - Player-facing names such as *Varrow* belong to whichever system names the
     thing (Hulls & Ship Definition #10 or Fleet Orders #19, to be decided). They
     may repeat, change, or be reused after a loss.
   - **No system may use a name as a key.** Every lookup, save reference and
     Battle Record entry uses the Runtime ID. The name is fetched only when text
     is shown, and renaming never changes an ID.
   - **The raw integer never appears in player-facing text.** Telling apart two
     live ships with the same name ("*Varrow* II") is a presentation job. The ID
     may appear in the dev debug overlay and the bug-report bundle.
9. **Processing order.**
   - The service offers `live_ids(kind)`: a snapshot of live IDs, always in
     ascending order, taken when it is called. Phase code iterates that snapshot,
     never a Dictionary's keys or insertion order.
   - Things spawned during a phase are not in that phase's snapshot (rule 3).
10. **Battles use campaign IDs.**
    - A ship in battle keeps its campaign Runtime ID. There is no separate battle
      ID, so the Battle Record, the Debrief and the campaign all talk about the
      same ID (Pillar 1).
    - Each battle's setup record holds the roster's Runtime IDs and the value of
      `next_id` at battle start. It is written into the Battle Record header with
      the battle seed (Deterministic RNG & Seed Streams, rule 10).
    - **The AI-vs-AI runner and a replay rebuild the battle from that record**:
      the same roster IDs, and the same `next_id` for things spawned mid-battle.
      IDs are carried in, never re-derived, so the IDs and the per-ship RNG
      streams of a replay match the original exactly. A runner scenario with no
      campaign authors its roster IDs and starting `next_id` directly.
    - Things spawned mid-battle (reinforcements) draw from the same counter, and
      the counter's value at battle end carries on into the campaign.
11. **Saves and loads.**
    - **Saved** (at a tick boundary, Simulation Tick & Pause rule 17): `next_id`
      and the whole identity table, live entries and tombstones. Every other
      section refers to things by ID only.
    - **A load restores exactly and never issues or retires.** Loading validates
      the table before any owning system's section loads. The load is refused,
      and the error names the ID, if:
      - `next_id` is not greater than every ID in the table and every ID any
        section refers to;
      - an ID is 0 or negative, or appears twice;
      - an ID that any section refers to is not in the table. Compaction only
        drops tombstones nothing refers to, so a referenced ID is always there
        as a live, inert or retired entry.
    - Gaps in the sequence are legal.
    - **Content removed by a mod:** a live thing whose content ID no longer
      exists becomes **`INERT`**. It keeps its ID and its record, is skipped by
      every phase, and resumes if the mod returns. Content Data & Mod Loading (#4)
      decides whether it is substituted or removed; removal retires it.
    - `next_id` and the identity table are part of `state_hash` (Simulation Tick
      & Pause rule 14).
12. **Independent and injected.**
    - The service is a plain-data object owned by `SimState`, handed to systems
      by injection. It is never a global singleton or autoload, so tests and the
      headless runner each build their own (coding standards: dependency
      injection over singletons).
    - It never uses the engine's object identities: no `get_instance_id()`,
      Object or Callable `hash()`, node paths, `RID` or resource paths. Those
      change between runs and are not saved (Simulation Tick & Pause rule 14;
      AC-34 lint).

### States and Transitions

The status of one Runtime ID:

| Status | Entered by | Simulation sees it? | Leaves when |
|---|---|---|---|
| **Unissued** | — (the number exists only as a future value of `next_id`) | No | `issue()` |
| **Spawning** | `issue()` during a phase | Not in this phase's snapshot | The phase ends → Live |
| **Live** | End of the spawning phase; or restored by a load | Yes, in ascending order | `retire()`; or a load finds its content missing → Inert |
| **Inert** | A load finds its content ID missing (mod removed) | No: skipped by every phase, record kept | Content returns on a later load → Live; or Content Data removes it → Retired |
| **Retired** | `retire()` at the end of P7 or a campaign step | No: tombstone only | A campaign save finds nothing refers to it → Compacted |
| **Compacted** | Campaign-save compaction | No: not in the table; `status()` still answers `COMPACTED`, because the ID is below `next_id` | Never (terminal). The ID is never reissued |

`NONE` (0) is not a status of an issued ID; it is the empty value.

### Interactions with Other Systems

| System | Flows into this system | Flows out of this system | Interface owner |
|---|---|---|---|
| Simulation Tick & Pause (#1) | Phase context, `tick_index` | Ascending `live_ids()`; `next_id` and the identity table for `state_hash`; the retire point (end of P7) | Tick owns phase order and the hash; this system owns IDs |
| Deterministic RNG & Seed Streams (#2) | — | Ship and fleet IDs as stream keys; the never-reused guarantee | RNG owns stream names |
| Content Data & Mod Loading (#4) | Content IDs at issue; missing content after a mod change | A content ID per identity; the `INERT` status | Content owns content IDs and substitution |
| Save/Load & Migration (#5) | The saved table on load | `next_id` and the identity table; load validation | Save owns the format and encoding; this system owns the validation rules |
| Combat Event Bus & Battle Record (#9) | — | Runtime IDs in every event; tombstones; the battle roster and `next_id` for the record header | The Record owns events and names-at-the-time |
| Hulls & Ship Definition (#10) or Fleet Orders (#19) | — | IDs to attach names to | The naming owner (to be decided) |
| Combat Space (#11) | Spawn and destroy requests for ships | Ship IDs; projectile sequence numbers | Combat Space owns ship and projectile records and order |
| Fleet Orders (#19), Ship AI (#20) | — | `GONE` for stale order targets and locks | Each owns its stale-reference policy |
| Fleet Coordination (#21) | Fleet create, split, merge, dissolve | Fleet IDs | Fleet Coordination owns membership and prunes it |
| After-Action Debrief (#24) | — | IDs and tombstones to trace causes | Debrief |
| AI-vs-AI Runner (#25) | Authored roster IDs and starting `next_id` | Identical IDs across runs | Runner owns scenarios |
| Archive Fragments (#28), Exposure & Rival Investigation (#32) | Fragment and investigator spawn and retire | Their IDs | Each owns its records |
| Presentation (#45, #46) | — | IDs in spawn and despawn events, to create and free views | Presentation; it never writes simulation state |

**What no system can do:**
- issue an ID outside a simulation step
- reuse, release or reassign an ID
- look a thing up by name, or by its position in a list
- keep an object reference across ticks
- show a raw ID to the player
- use an engine object identity as an ID

*Specialists consulted:*
- `systems-designer` (primary: one counter, projectiles, tombstones, saves, changes of hands)
- `lead-programmer` (the service owns identities, not objects; the API surface and its limits)
- `gameplay-programmer` (lazy stale-reference checks, spawn timing, fleet membership)
- `engine-programmer` (engine identities banned, the 2^53 cap, ascending snapshots)

*Owner decisions (2026-10-29):*
- a plain counter; the kind is not encoded in the ID
- ships keep their campaign ID in battle, and the roster and `next_id` are recorded

*Specialist disagreement, resolved by the owner:* `lead-programmer` proposed the
kind in the high bits and battle-local IDs; the other three proposed a plain
counter and campaign IDs. The owner chose the latter on both.

*Handed to the ADR:*
- the identity table's data structure, and the per-owner record stores
- the wire encoding of IDs (decimal strings where IDs are dictionary keys)
- how `issue()` is restricted to simulation steps (a context token plus lint)
- the projectile sequence's representation
- how compaction finds references (each owning section reports the IDs it
  holds)
- hashing the identity table incrementally (a running hash of issue, retire and
  compaction events), so `state_hash` does not rehash megabytes every tick (D2)

All engine behaviour here is NOT SOURCEABLE in `docs/engine-reference/godot/`
(there is no `modules/core.md`); the ADR verifies it with probe tests.

## Formulas

All IDs and counts are integers. None of these values is a gameplay tuning knob.

### D1. ID range and headroom

The ids_per_campaign formula is defined as:

`ids_per_campaign = N_setup + B × (s_battle + f_battle) + C_campaign`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| N_setup | int | ≈ 1,000 | calculated | IDs issued at new-game setup |
| B | int | 2,000 (worst: 4,000) | calculated | Battles: 100 hours (worst 200) at one battle every 3 minutes (Deterministic RNG & Seed Streams D2) |
| s_battle | int | 100 (worst: 200) | calculated | Ships newly issued per battle (enemies, reinforcements). Counting the whole roster overstates it, which is the safe direction |
| f_battle | int | 4 (worst: 20) | calculated | Fleets created per battle, splits included |
| C_campaign | int | ≈ 10,000 (worst: 100,000) | calculated | Fragments, investigators and campaign fleets |
| MAX_RUNTIME_ID | int | 2^53 − 1 = 9,007,199,254,740,991 | constant (engineering) | The hard cap (Core Rule 1) |
| ids_per_campaign | int | 1 – `MAX_RUNTIME_ID` | calculated | IDs issued in one save |

**Output Range:**
- **Typical:** 1,000 + 2,000 × 104 + 10,000 = **219,000** IDs, 0.010% of 2^31.
- **Worst:** 1,000 + 4,000 × 220 + 100,000 = **981,000** IDs, 0.046% of 2^31, and
  about 1.1 × 10⁻¹⁰ of the cap.
- **Rate bound:** even one ID every tick for 200 hours is 43.2 million IDs, about
  2.0% of 2^31. Reaching 2^31 in 200 hours would need about 50 IDs per tick,
  sustained.
- **Thresholds,** as in Simulation Tick & Pause D8:
  - issuing past `MAX_RUNTIME_ID` is a hard assert;
  - `next_id` crossing 2^31 logs one warning;
  - storing an ID in 32 bits is banned.
- `next_id = 2^53` (the cap plus one, still exact) is the "exhausted" state. It
  is legal to save and load; any further `issue()` is a fatal error.

**Example:** the worst case's 981,000 IDs use 0.046% of the 32-bit range, and the
2^53 cap leaves about 9 × 10⁹ times that much room.

### D2. Identity table size

The identity_table_bytes formula is defined as:

`identity_table_bytes = entries × (b_id + b_kind + b_content + b_issue + b_retire + b_status + overhead)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| entries | int | live entries + referenced tombstones | calculated | Entries kept after compaction (Core Rule 6) |
| b_id | int | 7 (max 16) | calculated | Decimal digits of the ID |
| b_kind | int | 1 | calculated | Kind code |
| b_content | int | ≈ 24 (interned index: ≈ 4) | calculated | Content ID reference, such as `base:hull.frigate_mk2` |
| b_issue, b_retire | int | 8 each | calculated | Tick digits (43.2 million at 200 hours is 8 digits). Empty while live |
| b_status | int | 1 | calculated | `LIVE`, `INERT` or `RETIRED` |
| overhead | int | ≈ 20 | constant (Save/Load #5 format) | Separators and keys, as in Deterministic RNG & Seed Streams D7 |
| IDENTITY_TABLE_SAVE_CEILING_MB | float | **8, provisional** | constant (engineering) | Largest the uncompressed section may be |

**Output Range:** about 69 bytes per entry, rounded to 70.
- **Without compaction**, every issued ID stays: a typical 100-hour campaign is
  219,000 × 70 ≈ **15.3 MB**, and the worst case is about **68.7 MB**. The 8 MB
  ceiling holds about 114,000 entries, which a typical campaign passes after about
  990 battles (about 50 hours). This is why compaction is required (Core Rule 6).
- **With compaction**, `entries` is the live set plus the tombstones that kept
  records still refer to. How many those are depends on how long the Battle
  Record and blame history are kept, which their GDDs decide (Open Questions). The
  section must stay within the 8 MB ceiling, which is about 114,000 entries.
- Interning content IDs and using a compact row (about 34 bytes) halves every
  figure above.

**Example:** a 40-hour campaign issues 1,000 + 800 × 104 + 4,000 = 88,200 IDs.
Even uncompacted, 88,200 × 70 ≈ 6.2 MB is under the ceiling. Compaction keeps
far longer campaigns under it.

*Hashing:* putting the whole table into `state_hash` every tick would hash
megabytes per tick. The table's contribution is therefore hashed incrementally,
as a running hash of issue, retire and compaction events (ADR).

### D3. Projectile sequence bound

The proj_seq_max formula is defined as:

`proj_seq_max = (P_live / T_life) × T_battle`

This is Little's law: at a steady state, projectiles spawned per tick equal the
live count divided by the lifetime in ticks.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| P_live | int | 500 (stress: 1,000) | calculated | Live projectiles (Simulation Tick & Pause D10 fixture) |
| T_life | int (ticks) | 30 – 600 (180) | data file (Weapons & Damage #12 owns it) | Mean projectile lifetime |
| T_battle | int (ticks) | 72,000 (worst: 216,000) | calculated | A 20-minute battle (worst: 60 minutes) at 60 Hz |
| proj_seq_max | int | 1 – 2^31 − 1 | calculated | Highest sequence number issued in one battle |

**Output Range:**
- **Typical:** 500 / 180 × 72,000 = **200,000**. With a 10-second lifetime,
  500 / 600 × 72,000 = 60,000.
- **Worst:** 1,000 / 30 × 216,000 = **7.2 million**, 0.34% of 2^31. A 64-bit
  int (GDScript's `int`) is far more than enough. The sequence is about 43% of
  2^24, so it is **never cast to float**.
- A 60-minute battle would reach 2^31 only at about 9,942 spawns per tick.

**Reset and saves:**
- `next_proj_seq` is set to 1 at battle setup. 0 means "no projectile".
- It is discarded at battle end, so campaign saves never hold it.
- A mid-battle save holds `next_proj_seq` and each live projectile's sequence
  number (Core Rule 2). Without them, a reload would number new projectiles
  differently, ascending-sequence processing would differ from the original
  run, and the replay would desync.

**Example:** a 20-minute battle with 3-second projectiles issues sequence
numbers 1 to 200,000.

### D4. Lookup cost budget

*An estimate: NOT SOURCEABLE in the engine reference; measured by the tick-rate
spike.*

The resolve_cost formula is defined as:

`resolve_ms = E × k × t_resolve_us / 1000 ≤ RESOLVE_SHARE × L`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| E | int | 600 | calculated | Entities per tick: 100 ships + 500 projectiles |
| k | int | ≈ 5 | calculated | ID lookups per entity per tick |
| t_resolve_us | float (µs) | 0.1 – 1.0 | calculated (measured by the spike) | Cost of one `status()` or owner `get_*()` lookup |
| L | float (ms) | 4.0 | calculated (Simulation Tick & Pause D10) | Per-tick pass line |
| RESOLVE_SHARE | float | **0.10, provisional** | constant (engineering; needs technical-director sign-off) | Share of `L` that lookups may use |

**Output Range:** 3,000 lookups per tick cost 0.3 ms at 0.1 µs each (7.5% of
`L`), and 3.0 ms at 1.0 µs each (75% of `L`). To fit a 0.4 ms share, one lookup
must cost at most **0.133 µs**.
**Example:** 600 × 5 × 0.5 µs = 1.5 ms, which is 37.5% of `L` and fails the share.

GDScript call overhead alone can decide whether a tick fits its budget, so the
shape of the lookup API (an inline index versus a checked wrapper) is an ADR
decision driven by this measurement.

*Specialist consulted: `systems-designer`. Every figure was re-checked
arithmetically. Owner decision (2026-10-29): unreferenced tombstones are
compacted at each campaign save (D2).*

*For the ADR:*
- **D2:** store the table as parallel packed arrays, not a Dictionary of
  Dictionaries; intern content IDs in the save; hash the table incrementally;
  define how sections report the IDs they hold for compaction.
- **D3:** keep the projectile sequence a 64-bit int, saved in mid-battle saves.
- **D4:** measure `t_resolve` in the spike, and fix the lookup API's shape from the
  result.

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## Game Feel

[To be designed]

## UI Requirements

[To be designed]

## Cross-References

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
