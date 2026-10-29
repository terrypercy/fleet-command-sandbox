# Runtime ID Service

> **Status**: In Design
> **Author**: owner + agents
> **Last Updated**: 2026-10-29
> **Last Verified**: 2026-10-29
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — every Debrief cause traces to a specific ship or fleet); Pillar 2 (The Truth Is Yours to Tell — fragments and investigators tracked across the campaign)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-29 — CONCERNS resolved. Records store the name and kind with the ID when written; a compaction check aborts compaction when a section under-reports its IDs; changes of hands emit a recorded event; a ship rebuilt from its wreck is always a new ID

## Summary

Runtime ID Service gives every live thing in the simulation (ships, fleets,
archive fragments, rival investigators) a plain integer identity. It is issued
once from one counter, saved exactly, and never reused, even after the thing is
destroyed. For the player, it means the Debrief, the Battle Record and every
save always talk about the same ship, fragment or rival. It exists because
replays, per-ship random streams, saves and the Debrief's causes all need one
stable, deterministic way to say "this one".

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None` (hard); soft contracts with Simulation Tick & Pause, Content Data & Mod Loading, Save/Load. Depended on by Save/Load, Combat Event Bus & Battle Record, Combat Space, Archive Fragments, Deterministic RNG & Seed Streams (keyed streams), Fleet Orders, Ship AI, Fleet Coordination, Debrief, AI-vs-AI Runner

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
     player. GDScript cannot enforce the type, so sequence numbers live only in
     fields named `proj_seq`, and a lint fails when one is passed to a Runtime ID
     parameter (AC-26).
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
     phases P1–P8 (in battle or in a campaign tick, Simulation Tick & Pause rule
     4), or new-game setup. Within a phase, issuers run in the order of that
     phase's handlers (Simulation Tick & Pause rule 3; for example Ship AI, then
     Fleet Coordination, in P2), and each issues in its own processing order,
     ascending Runtime ID. A replay therefore issues exactly the same IDs.
   - **An `issue()` outside a simulation step is a fatal error, in release
     builds too.** A silent extra ID would desync every replay after it. Fatal
     errors are reported to an injected `FatalSink`, which aborts in shipped
     builds and records in tests (Acceptance Criteria).
   - UI, presentation, previews, placement ghosts, tools and loading never issue
     an ID. A preview uses `NONE` or a presentation-local handle.
   - A thing's ID is issued at the spawn call, and its status is `SPAWNING`
     until the **end-of-tick point** (after P8, before P9; rule 6), where it
     becomes live. It is in no `live_ids()` snapshot before then, and first acts
     in the next tick. For example, a reinforcement spawned in P4 is not
     processed in P5–P8 of the same tick.
   - A spawn that is later cancelled still uses up its ID: it is retired at the
     next retire point (rule 6) with `issue tick = retire tick`, and later
     compacted like any tombstone. Gaps in the sequence are normal.
4. **Never reused, never reassigned.**
   - Once issued, an ID names that one thing for the rest of the save. It is
     never issued again, even after the thing is destroyed, and it never moves to
     another thing.
   - **Ships keep their ID through changes of hands:** lending to or from an
     ally, capture, and a breakaway faction joining the player. Owner and faction
     are fields owned elsewhere, not part of identity. History, losses and blame
     stay with the ship (Player Fantasy).
   - **A change of hands is recorded.** The system that changes a ship's owner
     emits a replay-visible ownership-change event: the ship's ID, the old and new
     owner, and `tick_index`. The Battle Record and blame history keep it, so any
     thread followed back shows the change ("the captured *Varrow*").
   - **A ship rebuilt from its wreck is always a new ship, with a new ID.** A
     retired ID never comes back to life. Salvage & Recovery (#36) may store a
     `rebuilt_from` link to the old ID so the story can say "built from *Varrow*'s
     keel". The old ship's history and blame stay with the old ID.
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
     `SPAWNING`, `COMPACTED`, `NEVER_ISSUED` (any ID at or above `next_id`) or
     `NONE` (0, and
     any negative value, which also trips a debug assert), and `kind_of(id)`
     answers for any ID
     still in the table, including retired ones (not compacted ones, rule 6). The owning system resolves a live ID to its record
     (for example `get_ship(id)`), and returns `GONE` for any ID that is not live.
     **A lookup never returns a different thing.**
   - Each owning system checks `kind_of(id)` at its own boundary in debug builds,
     so a fleet ID passed where a ship ID is expected fails loudly. Release builds
     have no such check; GDScript has no zero-cost typed IDs.
6. **Retirement keeps a tombstone.**
   - **The retire point is the end of each tick, after P8 and before P9**, in
     battle and in campaign ticks alike. It is the same end-of-tick point where
     spawned things become live (rule 3): retirements are applied first, then
     spawns. When a thing is destroyed or removed
     during a tick, its owner calls `retire(id)`; the call is queued, and takes
     effect at the retire point. Everything in that tick, P1 to P8, still sees
     the thing. *Simulation Tick & Pause rule 3 does not yet name this point; it
     needs a one-line note at that GDD's re-review.*
   - Queued retirements are applied in ascending Runtime ID, so the result never
     depends on which owner queued first. Retiring an ID that is already retired
     or queued is a no-op; retiring `NONE`, a negative ID or a never-issued ID is
     a debug assert, and a logged no-op in release builds.
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
     - **A compaction check runs before compaction commits.** Every ID found in
       any saved section must be in the union of the IDs the sections report
       through `held_ids()`. If one is missing, compaction is aborted for that
       save (the save itself still succeeds, uncompacted) and the bug is logged
       naming the section and the ID. A section that under-reports therefore
       costs save size, never the player's save.
   - The service stores **no names**. **Every record that names a thing stores
     the thing's display name and kind alongside its ID when the record is
     written**: a Battle Record event, a blame entry, a Dossier line. A Debrief
     or blame line about a ship long since compacted therefore still names it
     correctly. Which system supplies the display name is open (Open Questions).
7. **References between systems are by ID only.**
   - Orders, target locks, escort assignments, fleet membership, held fragments,
     the Battle Record and saves all store Runtime IDs.
   - No simulation field holds an object reference: no member of a simulation
     class is typed as an object, node, resource or callable, or as a container
     of them (AC-26), and `SimState`'s fields are checked at run time (AC-09).
     Holding a resolved record in a local variable inside one phase is fine.
   - **Stale references are checked on read.** A holder whose ID now resolves
     to `GONE` clears it in its own phase and emits an event stamped with
     `tick_index`, so the cleanup is replay-visible. Each holder's GDD owns its
     policy: for example Fleet Orders (#19) decides what an order whose target
     is gone does, and Simulation Tick & Pause already rejects an order whose
     subject is gone (`OrderRejected(subject_lost)`).
   - **Fleet membership** is the exception: Fleet Coordination (#21) prunes
     retired ship IDs at the retire point (rule 6), straight after the
     retirements are applied, so the list is accurate for the next tick. A fleet
     left empty is retired at the next retire point.
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
   - Things spawned during a tick are in no snapshot until the end-of-tick point
     (rule 3).
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
      decides whether it is substituted or removed. **Removal retires it at the
      first retire point after the load completes**, never during the load
      itself.
    - A mid-battle save must hold `next_proj_seq` and each live projectile's
      sequence number (D3); one without them is refused.
    - **Migration is not a load.** If Save/Load's migration of an older save
      needs new IDs, it issues them in its own versioned migration step, after
      validation and before the first tick, from the restored `next_id` (Save/Load
      #5 owns migration).
    - **Substitution** (Content Data & Mod Loading, Core Rule 13) rebinds an
      identity's content ID in that same migration step, to a replacement of the
      same kind. Each rebind is a recorded event in the identity digest, like an
      issue or a retirement.
    - A save with no saved digest is refused, as one with no `next_id` is.
    - `next_id` and the identity table's **digest** are part of `state_hash`.
      The digest is a running hash of issue, retire, compaction and substitution
      events (D2);
      it is itself **saved and restored**, so a reloaded game hashes exactly as
      the original run did. *Simulation Tick & Pause rule 14's list of hashed
      state needs `next_id`, this digest and the projectile sequence added at its
      re-review.*
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
| **Spawning** | `issue()` during a phase | No: in no snapshot this tick; `status()` answers `SPAWNING` | The end-of-tick point (after P8) → Live; or a cancel → Retired there |
| **Live** | The end-of-tick point after its spawn; or restored by a load | Yes, in ascending order | `retire()` takes effect at the retire point → Retired; or a load finds its content missing → Inert |
| **Inert** | A load finds its content ID missing (mod removed) | No: skipped by every phase, record kept | Content returns on a later load → Live; or Content Data removes it → Retired at the first retire point after the load |
| **Retired** | The retire point (end of a tick, after P8) | No: tombstone only | A campaign save finds nothing refers to it → Compacted |
| **Compacted** | Campaign-save compaction | No: not in the table; `status()` still answers `COMPACTED`, because the ID is below `next_id` | Never (terminal). The ID is never reissued |

`NONE` (0) is not a status of an issued ID; it is the empty value.

### Interactions with Other Systems

| System | Flows into this system | Flows out of this system | Interface owner |
|---|---|---|---|
| Simulation Tick & Pause (#1) | Phase context, `tick_index` | Ascending `live_ids()`; `next_id` and the identity digest for `state_hash`; the retire point (end of each tick, after P8) | Tick owns phase order and the hash; this system owns IDs |
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
megabytes per tick. The table's contribution is therefore a running digest of
issue, retire, compaction and substitution events, which is **saved with the table** so a
reload continues it exactly (Core Rule 11; ADR).

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
| proj_seq_max | int | 1 – ≈ 7.2 million in practice; capped at 2^53 − 1 (fatal past it) | calculated | Highest sequence number issued in one battle |

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

### Issuing

- **If `issue()` is called when `next_id = MAX_RUNTIME_ID`**: it returns
  2^53 − 1 and `next_id` becomes 2^53, the "exhausted" state. That state can be
  saved and loaded; the next `issue()` is a fatal error (D1).
- **If `issue()` is called outside a simulation step** (from UI, presentation, a
  preview, a tool, or during a load): it is a fatal error in every build (Core
  Rule 3). A silent extra ID would desync every replay after it.
- **If two systems issue IDs in the same phase**: they issue in the order of that
  phase's handlers (Simulation Tick & Pause rule 3), each in ascending Runtime ID
  of the thing that triggered the spawn (Core Rule 3).
- **If a spawn is cancelled after `issue()`**: the ID is used up, and the entry
  is retired at the next retire point with `issue tick = retire tick` (Core Rule
  3). A cancelled spawn is never reported as live.
- **If a reinforcement is issued in P4 of the tick a battle ends**: it is
  `SPAWNING` until the end-of-tick point, then live, and its ID carries into the
  campaign along with `next_id` (Core Rules 3 and 10).

### Lookups

- **If `status(id)` is called with an ID at or above `next_id`**: it answers
  `NEVER_ISSUED`. With 0 it answers `NONE`. With a negative value it answers
  `NONE` and trips a debug assert (Core Rule 5).
- **If a fleet ID is passed to `get_ship()` in a release build**: it returns
  `GONE`, never a ship, because one counter makes every ID globally unique (Core
  Rule 1). The holder clears it and emits an event (Core Rule 7). The bug is
  silent, but the replay is unaffected. Debug builds assert at the boundary.
- **If an ID is `INERT`**: owners return `GONE` for it (Core Rule 5), so orders and
  locks holding it are cleared (Core Rule 7). Fleet Coordination prunes only
  *retired* IDs, so fleet membership keeps an inert ship until it is retired or
  its content returns.

### Retirement and compaction

- **If `retire()` is called twice for one ID, or for an ID already queued**: the
  second call is a no-op (Core Rule 6).
- **If `retire()` is called with `NONE`, a negative ID or a never-issued ID**: a
  debug assert fires; in release builds it is a logged no-op (Core Rule 6).
- **If a thing is destroyed mid-phase**: its retirement is queued and takes effect
  at the retire point after P8. Every later phase of the same tick still sees it
  (Core Rule 6).
- **If a projectile hits after its shooter was retired**: the Battle Record names
  the shooter's ID. Compaction never runs in battle, so `kind_of` still answers for
  it (Core Rule 6).
- **If a record stops referring to an ID and later wants its name or kind**:
  `status` answers `COMPACTED` and the kind is unknown. Only what the record
  stored itself survives (Core Rule 6).
- **If a mid-battle save is made**: nothing is compacted. The next campaign save
  compacts (Core Rule 6).
- **If compaction runs**: it counts every saved section as a reference, including
  retained Battle Records and replay logs: **it keeps every ID that any saved
  section's `held_ids()` reports**. A record created later can only get an ID from
  something that already holds it, so nothing it needs has been compacted.

### Changes of hands

- **If a lent, captured or defecting ship is destroyed**: it is retired under its
  one Runtime ID, and its history and blame stay with that ID (Core Rule 4).
- **If two fleets merge and later split**: the absorbed fleet's ID stays retired,
  and the split issues a fresh fleet ID. `base:fleet.tiebreak#<new_id>` is a new
  stream (Deterministic RNG & Seed Streams, rule 5).
- **If a fleet splits in P2 on the tick its flagship dies**: the new fleet is
  `SPAWNING` until the end-of-tick point. There, the flagship is retired first,
  then the new fleet becomes live, and Fleet Coordination prunes membership. P3–P8
  still see the flagship and the old fleet.

### Battles and the runner

- **If a battle ends on its first tick**: the Battle Record header's `next_id` is
  the value at battle start, and the campaign continues from the value at battle
  end (the same, if nothing spawned).
- **If an enemy retreats from a battle**: retreat is not retirement. The ship keeps
  its ID and stays live; Battle Resolution & Retreat (#22) decides where it goes.
- **If a replay or the runner rebuilds a battle**: it builds its own service from
  the Battle Record header (Core Rules 10 and 12), and never writes to the live
  campaign's `next_id`.
- **If a runner scenario's authored `next_id` is not greater than every roster
  ID, or a roster ID is 0, negative or duplicated**: the scenario goes through the
  same validation as a load (Core Rule 11), and the run is refused.

### Saves

- **If `next_id` is missing from a save**: the load is refused. `next_id` is never
  re-derived as "highest ID + 1", because that could reissue a compacted ID or a
  gap, and RNG keys must never be reused (Deterministic RNG & Seed Streams,
  rule 5).
- **If a save holds a duplicate ID, an ID of 0, or a referenced ID missing from the
  table**: the load is refused, and the error names the ID (Core Rule 11).
- **If a mid-battle save lacks `next_proj_seq` or a live projectile's sequence
  number**: the load is refused (Core Rule 11). The counter cannot be rebuilt,
  because projectiles already destroyed had higher numbers.
- **If an order refers to an `INERT` ship**: the ship resolves to `GONE`, so the
  order is handled by its owner's stale-reference rule (Core Rule 7).
- **If a returning mod gives a content ID a different kind**: the thing stays
  `INERT` and an error names it. An ID's kind never changes, because kind is part
  of identity.
- **If an `INERT` ship is in a mid-battle save**: it takes no part in the battle.
  Battle Resolution (#22) treats it as absent (provisional; Open Questions).
- **If migrating an older save needs new IDs**: migration issues them in its own
  step, after validation and before the first tick (Core Rule 11).

### Projectiles

- **If the projectile sequence reaches 2^53 − 1**: it is a fatal error, as for
  Runtime IDs (D1). D3 shows a battle would need about 10^9 times the worst-case
  fire rate to get there.
- **If a projectile outlives its shooter**: its sequence number is unchanged, and
  hit attribution uses the shooter's retired ID.

### Presentation

- **If a view exists for an ID that has just been retired**: that tick's
  despawn event, flushed in P9, frees the view.
- **If two live ships share a name**: presentation tells them apart; their IDs are
  unaffected (Core Rule 8).

*Specialist consulted: `systems-designer`. It found four conflicts with the draft,
all resolved:*
- *Simulation Tick & Pause rule 3 named no retire point; this GDD now defines one,
  at the end of each tick after P8 (Core Rule 6).*
- *A running hash of identity events could not survive a reload; the digest is now
  saved (Core Rule 11).*
- *Content removal at load contradicted "a load never retires"; it now retires at
  the first retire point after the load.*
- *"Campaign step" is not a Simulation Tick & Pause concept; it is now a campaign
  tick.*

*It also raised 13 open questions; 10 are answered above. The other 3 are in Open
Questions: whether missiles that can be targeted need IDs, how Battle Resolution
counts an inert ship, and who keeps a retired thing's name.*

## Dependencies

### Upstream (what this system needs)

**Hard dependencies: none.** The counter, the identity table and the lookup rules
work with nothing else designed. That is why the system sits in the Foundation
layer.

**Interface contracts** (soft). Each is data handed in, never a call back into
another system's logic:

| System | Hard / soft | Interface | Notes |
|---|---|---|---|
| Simulation Tick & Pause (#1) | Soft (data handed in) | Phase context, `tick_index`, the end-of-tick point after P8 | The retire point (Core Rule 6) and issuance order (Core Rule 3) hang on Tick's phase order. Tick hashes `next_id` and the identity digest |
| Content Data & Mod Loading (#4) | Soft | The content ID given at `issue()`; which content IDs exist after a mod change | Drives the `INERT` status. Content Data decides substitution or removal |
| Save/Load & Migration (#5) | Soft (reverse) | This system *provides* its section: `next_id`, the identity table and its digest | Save owns the format, encoding and migration; this system owns the load validation rules (Core Rule 11) |

### Downstream (what depends on this system)

**Listed in the systems index:**

| System | Hard / soft | What it relies on |
|---|---|---|
| Save/Load & Migration (#5) | Hard | Every cross-section reference is a Runtime ID; the identity section loads first and is validated (Core Rule 11) |
| Combat Event Bus & Battle Record (#9) | Hard | IDs in every event; tombstones for retired things; the battle roster and `next_id` for the record header (Core Rule 10). **Must store each named thing's display name and kind with its ID when an event is written**, and keep ownership-change events (Core Rules 4 and 6) |
| Combat Space (#11) | Hard | Ship IDs; the projectile sequence; ascending processing (Core Rules 2 and 9) |
| Archive Fragments & Evidence (#28) | Hard | Fragment IDs that survive the whole campaign |

**Not yet listed in the index.** Each needs this system in its own Dependencies,
and the index should list it at the next update:

| System | Hard / soft | What it relies on |
|---|---|---|
| Deterministic RNG & Seed Streams (#2) | Hard for keyed streams | Ship and fleet IDs as stream keys, never reused within a save (that GDD's rule 5). *Not added to the index: #2 is listed above #3 in the Foundation layer, and a system may depend only on one above it; the RNG GDD records the contract instead* |
| Hulls & Ship Definition (#10) or Fleet Orders (#19) | Soft | IDs to attach player-facing names to (Core Rule 8). Which one owns names is open |
| Fleet Orders (#19), Ship AI (#20) | Hard | `GONE` for stale targets and locks; each owns its stale-reference policy (Core Rule 7) |
| Fleet Coordination (#21) | Hard | Fleet IDs; the split and merge rules; prunes membership at the retire point (Core Rules 4 and 7) |
| Battle Resolution & Retreat (#22) | Hard | Retreat is not retirement; inert ships treated as absent (Edge Cases) |
| After-Action Debrief (#24) | Hard | IDs and tombstones to trace causes to one ship (Player Fantasy; Pillar 1) |
| AI-vs-AI Runner & AI Debug Tools (#25) | Hard | Authored roster IDs and starting `next_id`; battles rebuilt from the Battle Record header (Core Rule 10) |
| Exposure & Rival Investigation (#32) | Hard | Investigator IDs that survive the campaign |
| Faction Belief & Blame (#30) | Hard | Blame entries keyed by Runtime ID. **Must store the display name and kind with the ID when an entry is written** (Core Rule 6) |
| Battle Resolution & Retreat (#22), Allied Lending (#33), Breakaway Machine Faction (#44) | Hard | Ships keep their ID through capture, lending and defection; **whichever changes an owner emits the ownership-change event** (Core Rule 4) |
| Salvage & Recovery (#36) | Soft | A rebuilt ship gets a new ID, with an optional `rebuilt_from` link (Core Rule 4) |
| Camera & Combat View (#45), Combat HUD & Tactical Overlay (#46) | Soft | IDs in spawn and despawn events, to create and free views; never shows a raw ID |
| Telemetry & Playtest Logging (#54) | Soft | IDs in the bug-report bundle and dev overlay |

**Bidirectional check:**
- Simulation Tick & Pause lists Runtime ID Service (#3) as a soft upstream
  dependency for processing order ✓. At its re-review it also needs the retire
  point (rule 3), the projectile exception (rule 3), and `next_id`, the identity
  digest and the projectile sequence in its hashed state (rule 14).
- Deterministic RNG & Seed Streams lists Runtime ID Service (#3) as required for
  keyed streams ✓.
- Every other system above must list Runtime ID Service in its own Dependencies
  when it is designed.

## Tuning Knobs

**This system owns no gameplay tuning knobs.** Nothing about an ID changes how
the game plays, and a knob here could only break determinism or saves.

### Engineering constants (versioned; not tuning knobs)

| Constant | Value | Why it is fixed |
|---|---|---|
| `NONE` | 0 | The empty ID; never issued (Core Rule 1) |
| First issued ID | 1 | Counter start (Core Rule 1) |
| `MAX_RUNTIME_ID` | 2^53 − 1 | Exact as a JSON number and a float (D1). Issuing past it is fatal |
| 32-bit warning threshold | 2^31 | One warning when `next_id` crosses it; storing an ID in 32 bits is banned (D1) |
| Projectile sequence start | 1 per battle (0 = no projectile) | Reset at battle setup (D3) |
| `IDENTITY_TABLE_SAVE_CEILING_MB` | 8 (**provisional**) | Largest the uncompressed identity section may be (D2) |
| `RESOLVE_SHARE` | 0.10 (**provisional**) | Share of the per-tick pass line that ID lookups may use. Needs technical-director sign-off (D4) |
| Retire point | End of each tick, after P8 and before P9 | Fixed by Core Rule 6; moving it changes what each phase sees |

**Knobs owned elsewhere** (referenced, not duplicated):
- mean projectile lifetime (Weapons & Damage #12), which drives D3
- ship counts per battle (encounter design), which drive D1 and D4

## Visual/Audio Requirements

**None.** This system has no art or sound. Presentation creates and frees each
entity's view from the spawn and despawn events, keyed by Runtime ID (Core Rule
7), and never writes back to the simulation.

*`art-director` and `audio-director` were not consulted: Visual/Audio is optional
for `Core` systems, and this system has no visual or audio surface.*

## Game Feel

**Not applicable.** The player never operates this system. Its only feel
contribution is indirect: the right ship is always named (Player Fantasy).

## UI Requirements

This system contributes no screen and no player-facing element. It sets two rules
for every UI that shows a live thing:
1. **The raw Runtime ID never appears in player-facing text** (Core Rule 8).
   Screens show names, and tell apart two same-named ships themselves, for example
   "*Varrow* II". How they do it belongs to the HUD, the Debrief and the naming
   owner's UX specs.
2. **A view that refers to a retired or inert thing** shows it as gone, never as
   another thing. A tooltip, Debrief entry or Dossier line for a destroyed ship
   reads from the record that stored its name at the time (Core Rule 6).

**Developer-only:** the dev debug overlay and the bug-report bundle may show raw
IDs and statuses (`LIVE`, `INERT`, `RETIRED`, `COMPACTED`).

*No UX flag is raised: this system adds no screen, and the rules above are
constraints for the specs of the screens that show live things.*

## Cross-References

| This GDD references | Document | Section | What is relied on |
|---|---|---|---|
| Pillar 1, *Every Defeat Is a Lead* | `design/gdd/game-concept.md` | Game Pillars | "Can the Debrief name at least one specific, actionable cause and counter for this loss?" |
| Pillar 2, *The Truth Is Yours to Tell* | `design/gdd/game-concept.md` | Game Pillars | Fragments and investigators persist across the campaign |
| Content IDs vs instance IDs | `design/gdd/game-concept.md` | Technical Considerations | "stable namespaced string IDs (`base:…`, `mymod:…`)"; content IDs belong to Content Data (#4) |
| System role and consumers | `design/gdd/systems-index.md` | Overview; Systems Enumeration | "Stable IDs for live things: ships, fleets, fragments and rival investigators"; consumers #5, #9, #11, #28 |
| Phase order, ascending Runtime ID | `design/gdd/simulation-tick-and-pause.md` | Core Rules, rule 3 | Processing order; the handler order issuers follow (Core Rule 3) |
| Contexts | `design/gdd/simulation-tick-and-pause.md` | Core Rules, rule 4 | Campaign ticks run P1, P7 and P8 |
| `state_hash`, 2^53 | `design/gdd/simulation-tick-and-pause.md` | Core Rules, rule 14; Formulas, D8 | Hashed state; the 2^53 limit and the 2^31 warning pattern (D1) |
| Saves at tick boundaries | `design/gdd/simulation-tick-and-pause.md` | Core Rules, rule 17 | The identity section is saved between ticks |
| `OrderRejected(subject_lost)` | `design/gdd/simulation-tick-and-pause.md` | Edge Cases, Orders and input | The existing stale-subject rule (Core Rule 7) |
| Engine identity ban | `design/gdd/simulation-tick-and-pause.md` | Acceptance Criteria, AC-34 | `get_instance_id` and `hash(` banned in simulation code |
| Per-tick pass line `L` | `design/gdd/simulation-tick-and-pause.md` | Formulas, D10 | The budget `RESOLVE_SHARE` takes its share from (D4) |
| Keyed streams | `design/gdd/deterministic-rng-and-seed-streams.md` | Core Rules, rule 5 | Ship and fleet IDs as keys; never reused within a save |
| Battle Record header | `design/gdd/deterministic-rng-and-seed-streams.md` | Core Rules, rule 10 | Battle seed and registry version written at battle start, alongside this system's roster and `next_id` |
| Battle and save size precedents | `design/gdd/deterministic-rng-and-seed-streams.md` | Formulas, D2 and D7 | Battles per campaign; per-record save overhead (D1, D2) |
| Engine facts | `docs/engine-reference/godot/` | — | NOT SOURCEABLE: no `modules/core.md`, so object identity, Dictionary behaviour and JSON integer parsing are unchecked |

No other system GDD exists yet. Each system in Dependencies → Downstream must
cross-reference this GDD when it is written.

## Acceptance Criteria

**How tests stay isolated.** The fixtures:
- **`SimContextFixture`** opens and closes a phase context (P1–P8, a campaign
  tick, new-game setup) or a non-simulation context (UI, presentation, load,
  tool), so tests can call `issue()` from inside and outside a simulation step.
- **`FatalSink`** is injected and records fatal errors instead of aborting, so
  the fatal paths can be checked (Core Rule 3).
- **`AssertMode`** (`DEBUG` / `RELEASE`) is injected, so assert behaviour and
  logged no-ops both run in one build.
- **`FakeShipStore`** and **`FakeFleetStore`** are owner stores with `get_*()` and
  `held_ids()`. Their Dictionaries are filled in scrambled insertion order.
- **`IdFixtures`** holds pinned rosters and `NEXT_ID_FIX`. Boundary values (0, −1,
  2^31, 2^53 − 1, 2^53) appear inline, because the exact number is the point of
  those tests.

Unit tests round-trip saves through an in-memory buffer. Test files are named
`runtime_id_[feature]_test.gd`, and functions `test_[scenario]_[expected]`. Every
comparison is an exact integer `==`.

### Logic: unit tests, `tests/unit/runtime_id/` (BLOCKING)

- **AC-01 (Core Rule 1)**: **GIVEN** a fresh service, **WHEN** a ship, a fleet and a
  ship are issued, **THEN** they get 1, 2 and 3, and `next_id == 4`. `status(0) ==
  NONE`; `status(−1) == NONE`, and it asserts in `DEBUG`.
- **AC-02 (Core Rule 1, D1)**: **GIVEN** `next_id = 2^53 − 1`, **WHEN** `issue()`
  runs, **THEN** it returns `9007199254740991` and `next_id == 9007199254740992`.
  That state saves and loads unchanged, and the next `issue()` records exactly one
  `FatalSink` entry and returns no ID. **GIVEN** `next_id = 2^31 − 1`, **WHEN**
  three IDs are issued, **THEN** exactly one 2^31 warning is logged.
- **AC-03 (Core Rule 2, D3)**: **GIVEN** two battles in sequence, **THEN** each
  battle's first projectile gets sequence 1. Spawning 1,000 projectiles leaves
  `next_id` unchanged. A campaign save after a battle holds no `next_proj_seq`.
- **AC-04 (Core Rule 3)**: **WHEN** `issue()` is called from P2, a campaign tick and
  new-game setup, **THEN** each call succeeds. **WHEN** it is called from UI,
  presentation, load or tool contexts, in both `AssertMode`s, **THEN** each call
  records one `FatalSink` entry and `next_id` is unchanged.
- **AC-05 (Core Rule 3, same-phase issuers)**: **GIVEN** two P2 handlers, Ship AI
  then Fleet Coordination, each spawning for triggers {9, 4}, **THEN** IDs are
  issued in handler order, and within each handler for trigger 4, then 9.
- **AC-06 (Core Rules 3, 6, 9, spawn timing)**: **GIVEN** a reinforcement spawned in
  P4 of tick T, **THEN** `status` answers `SPAWNING` through P8 of T, it is in no
  `live_ids()` snapshot during P4–P8 of T, and it is not processed in T. **AFTER**
  the end-of-tick point it is `LIVE`, and it is first processed in P1 of T + 1.
  **GIVEN** a retirement and a spawn queued in the same tick, **THEN** the
  retirement is applied first.
- **AC-07 (Core Rule 3, cancelled spawn)**: **GIVEN** a spawn cancelled after
  `issue()`, **THEN** its `status` is never `LIVE`. After the end-of-tick point it
  is `RETIRED` with `issue_tick == retire_tick`, and the next `issue()` returns the
  next number, leaving a gap.
- **AC-08 (Core Rule 4)**: **GIVEN** ship 5 retired, **WHEN** 1,000 more IDs are
  issued, **THEN** none equals any earlier ID. Changing a ship's owner or faction,
  or lending, capturing or defecting it, leaves its ID unchanged. A fleet split
  gives the new group a new ID and the original fleet keeps its own. A merge
  retires the absorbed fleet at the retire point.
- **AC-09 (Core Rule 5)**: **GIVEN** crafted IDs in each state, **THEN** `status`
  answers `LIVE`, `INERT`, `RETIRED`, `SPAWNING`, `COMPACTED`, `NEVER_ISSUED` (for
  `next_id` and `next_id + 1`) and `NONE`. `kind_of` answers for retired IDs.
  Owners return `GONE` for every non-live ID. **GIVEN** a fleet ID passed to
  `get_ship()`, **THEN** `DEBUG` asserts and `RELEASE` returns `GONE`. **GIVEN** the
  service's and `SimState`'s property lists, **THEN** no field holds an Object,
  Node, Resource or Callable.
- **AC-10 (Core Rule 6)**: **GIVEN** `retire()` called in P3, **THEN** `status ==
  LIVE` through P8, and `RETIRED` after P8 and before P9. Queuing {9, 4, 7} and
  queuing {4, 7, 9} give equal digests. A second `retire()` of the same ID, or of a
  queued ID, leaves the digest unchanged. `retire()` of `NONE`, −1 or `next_id`
  asserts in `DEBUG`; in `RELEASE` it logs once and leaves the digest unchanged.
- **AC-11 (Core Rule 6, compaction)**: **GIVEN** tombstone A, reported by a
  `FakeShipStore`'s `held_ids()`, and tombstone B, which nothing reports, **WHEN** a
  battle tick and a mid-battle save run, **THEN** both are still in the table.
  **WHEN** a campaign save runs, **THEN** A is still in the table with its kind, B
  reports `COMPACTED`, `kind_of(B)` is unknown, `next_id` is unchanged, and the
  next `issue()` is not B.
- **AC-11b (Core Rule 6, compaction check)**: **GIVEN** a fixture section whose
  `held_ids()` omits an ID it stores, **WHEN** a campaign save runs, **THEN**
  compaction is aborted, the save succeeds uncompacted, one error names the
  section and the ID, and the next load succeeds.
- **AC-11c (Core Rules 4, 6, names and changes of hands)**: **GIVEN** ship 12 named
  "*Varrow*" is captured, then destroyed, and a campaign save compacts it away,
  **THEN** the Battle Record holds an ownership-change event (12, old owner, new
  owner, tick), and every record about ship 12 still shows "*Varrow*" and its kind
  from what it stored. **GIVEN** a ship rebuilt from ship 12's wreck, **THEN** it
  gets a new ID, `status(12)` stays retired or compacted, and its `rebuilt_from`
  is 12.
- **AC-12 (Core Rule 7)**: **GIVEN** an order whose target is retired, **THEN** its
  holder clears the target in its own phase and emits one event with that
  `tick_index`. **GIVEN** a fleet whose last ship is retired, **THEN** the ship
  leaves the membership straight after the retire point, and the fleet is retired
  at the next retire point.
- **AC-13 (Core Rule 8)**: **GIVEN** two live ships named "Varrow", **WHEN** one is
  renamed, **THEN** both IDs are unchanged and lookups still resolve correctly. The
  service's property list has no name field.
- **AC-14 (Core Rule 9)**: **GIVEN** owner Dictionaries filled in the order 7, 3, 9,
  **THEN** `live_ids(SHIP) == [3, 7, 9]`. A spawn during iteration leaves the
  snapshot already taken unchanged.
- **AC-15 (Core Rule 10; edge: a battle ending on its first tick)**: **GIVEN** a
  campaign roster {3, 8} and `next_id = 20`, **THEN** the battle uses IDs 3 and 8,
  the header holds `[3, 8]` and `20`, the first reinforcement gets 20, and the
  campaign resumes from the value at battle end. A battle that ends on tick 1 with
  no spawns resumes at 20.
- **AC-16 (Core Rule 11, load validation)**: **WHEN** fixture saves are loaded,
  **THEN** each of these is refused with an error naming the ID or field:
  - `next_id` not greater than the highest ID in the table, or than a referenced
    ID;
  - ID 0, a negative ID, or a duplicate ID;
  - a referenced ID missing from the table;
  - a missing `next_id`, or a missing saved digest;
  - a mid-battle save without `next_proj_seq` or a live projectile's sequence
    number.

  A valid load leaves `next_id` and the digest equal to the saved values. A save
  with gaps loads.
- **AC-17 (Core Rule 11, inert; edge: kind change)**: **GIVEN** a live ship whose
  content is removed, **WHEN** the save loads, **THEN** it is `INERT`, skipped by
  every phase, resolves to `GONE`, and is still in fleet membership.
  - **WHEN** the content returns, **THEN** it is `LIVE`.
  - **WHEN** Content Data removes it, **THEN** it is `RETIRED` at the first retire
    point after the load, never during the load.
  - **WHEN** the content returns as a different kind, **THEN** the ship stays
    `INERT` and an error names it.
- **AC-18 (Core Rule 11, migration)**: **GIVEN** a migration that needs 2 IDs,
  **THEN** they are issued after validation and before tick 1, starting at the
  restored `next_id`.
- **AC-19 (Core Rule 12)**: **GIVEN** two services built in one process, **WHEN**
  one issues 10 IDs, **THEN** the other's `next_id` is unchanged. No autoload
  exposes the service.

### Engine-behaviour probes: `tests/unit/runtime_id/runtime_id_engine_probe_test.gd` (BLOCKING)

These behaviours are **NOT SOURCEABLE** in `docs/engine-reference/godot/` (there is
no `modules/core.md`).

- **AC-20 (D1, JSON)**: **GIVEN** 1 and `9007199254740991`, **WHEN** the ADR's
  codec writes them as decimal strings and `JSON.stringify` and
  `JSON.parse_string` round-trip them, **THEN** each decodes to the same `int`. The
  engine's native number round trip is also run and recorded as an observation; if
  it does not round-trip exactly, the codec must not rely on it.
- **AC-21 (Core Rule 11, dictionary keys)**: **GIVEN** `{1: a, 9007199254740991: b}`,
  **WHEN** it is encoded with decimal-string keys and round-tripped, **THEN** the
  keys decode to exactly `1` and `9007199254740991`. The engine's own key handling
  is recorded as an observation.
- **AC-22 (D1, 64-bit int)**: **THEN** `(1 << 53) + 1 == 9007199254740993` and
  `(1 << 53) + 1 > (1 << 53)`, while `float((1 << 53) + 1) == float(1 << 53)`. An
  int stays exact where a float does not.

### Static checks, CI lint (BLOCKING)

- **AC-23 (Core Rule 12)**: the lint fails on `get_instance_id(`, `hash(` applied
  to an Object or Callable, `get_path(`, `RID` and `resource_path` used as an
  identity in `src/sim/**`.
- **AC-24 (Core Rule 3)**: the lint fails on an `issue(` call outside the
  registered simulation-step handlers and the new-game setup and migration entry
  points.
- **AC-25 (Core Rule 9)**: the lint fails on `for … in <entity Dictionary>`,
  `.keys()` or `.values()` driving simulation order in `src/sim/**`.
- **AC-26 (Core Rules 2, 7)**: the lint fails on:
  - a member variable in `src/sim/**` whose declared type is an Object-derived
    record class, Node, Resource or Callable, or an Array or Dictionary of those;
  - a `proj_seq` value passed to a Runtime ID parameter.

  **What it cannot catch:** an untyped `var` or `Variant` field assigned an object
  at run time. AC-09's property-list check and the save round trip (AC-29) cover
  that case for `SimState`.
- **AC-27 (Core Rule 8)**: the lint fails on `str()`, `%` formatting or
  `String.format` of an `*_id` value in UI and presentation code, outside the
  allowlist (the debug overlay and the bug-report bundle). It catches only values
  that follow the naming convention; AC-35 catches the rest.

**Shown to fail:** one planted violation per item lives in
`tests/fixtures/lint/runtime_id/bad_<item>.gd`: `bad_instance_id`, `bad_object_hash`,
`bad_node_path`, `bad_rid`, `bad_resource_path`, `bad_issue_in_ui`,
`bad_dict_iteration`, `bad_object_field`, `bad_proj_seq_as_id` and
`bad_raw_id_in_text`. CI must exit non-zero on every fixture, and exit 0 on the
production scan, which excludes the fixtures.

### Integration: `tests/integration/runtime_id/` (BLOCKING)

- **AC-28 (Core Rule 11, `state_hash`)**: **GIVEN** a battle played twice headless,
  **THEN** the per-tick hashes are identical, and one planted `issue()` or
  `retire()` at tick T makes them first diverge at T. **GIVEN** a save at T,
  **WHEN** it is reloaded, **THEN** the hash at T and every hash to T + 600 equal
  the uninterrupted run's. Altering only the saved digest makes the hash at T
  differ.
- **AC-29 (Core Rules 6, 11, round trip with compaction)**: **GIVEN** a fixture
  campaign with referenced and unreferenced tombstones, **WHEN** it is saved,
  loaded and saved again, **THEN** the unreferenced tombstones report
  `COMPACTED`, the referenced ones keep their kind and ticks, `next_id` is
  unchanged, and the second save is byte-identical to the first.
- **AC-30 (Core Rule 10, rebuild from the header)**: **GIVEN** only a Battle Record
  header (roster IDs, `next_id`, battle seed) and the command log, **WHEN** an
  isolated instance replays the battle, **THEN** every reinforcement ID and every
  `base:combat.hit#<id>/<slot>` stream seed equal the original's, and the live
  campaign's `next_id` is unchanged.
- **AC-31 (Core Rule 10; edge: runner validation)**: **GIVEN** runner scenarios
  with `next_id` not greater than the highest roster ID, or a roster ID of 0, −1
  or a duplicate, **THEN** each run is refused and the error names the ID. A valid
  scenario runs twice with identical IDs.
- **AC-32 (Core Rule 2, D3, mid-battle save)**: **GIVEN** a save at T with live
  projectiles, **WHEN** it is reloaded and run to T + 600, **THEN** every new
  sequence number and the per-phase processing order equal the uninterrupted
  run's.

### Performance: `tests/performance/runtime_id/`

- **AC-33 (D4; BLOCKING for the lookup-API ADR)**: **GIVEN** Simulation Tick &
  Pause D10's steady scene (E = 600), **WHEN** the tick-rate spike runs, **THEN**
  the report records p95 `t_resolve_us` for `status()` and `get_ship()`, lookups
  per tick, the machine and the build. It **FAILS** if
  `resolve_ms > RESOLVE_SHARE × L`. While `RESOLVE_SHARE` is provisional, a pass
  reports `PROVISIONAL`, not `PASS`.
- **AC-34 (D2)**: **GIVEN** the fixture `tests/fixtures/runtime_id/campaign_100h`
  (219,000 IDs issued), **WHEN** it is campaign-saved, **THEN** the uncompressed
  identity section is at most `IDENTITY_TABLE_SAVE_CEILING_MB` (8 MB), and the
  measured bytes and bytes per entry are recorded. The fixture's count of
  referenced tombstones depends on Battle Record and blame retention (Open
  Questions), so a pass reports `PROVISIONAL` until those GDDs decide it and the
  ceiling is signed off.

### UI: automated (BLOCKING once Camera & Combat View #45 and the HUD #46 exist)

- **AC-35 (Core Rule 8)**: **GIVEN** a fixture state whose IDs start at the sentinel
  `NEXT_ID_FIX = 7340000001`, **WHEN** every player-facing view-model string and
  every string-table entry with its bound arguments is rendered, **THEN** none
  contains a sentinel ID's decimal form. The debug overlay and the bug-report
  bundle are excluded. Telling two same-named ships apart belongs to the
  presentation GDDs, and is not tested here.

*Specialist consulted: `qa-lead`. It flagged eight items as not testable or
ambiguous, all resolved:*
- *Fatal errors now go to an injected `FatalSink` (Core Rule 3).*
- *The projectile-sequence type is enforced by a lint (Core Rule 2, AC-26).*
- *Rule 7's object-reference ban is now checkable (AC-26, AC-09).*
- *Compaction keeps every ID that `held_ids()` reports.*
- *Spawn timing was ambiguous: spawns now become live at the end-of-tick point,
  with a `SPAWNING` status (Core Rule 3).*
- *D3's range and the projectile cap now agree (2^53 − 1).*
- *A save with no digest is refused (Core Rule 11).*
- *D2's ceiling test stays provisional until retention is decided (AC-34).*

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Who owns player-facing names**, Hulls & Ship Definition (#10) or Fleet Orders (#19)? Records must already store the name with the ID when written (Core Rule 6); only which system supplies the name is open. | #10, #19 | When #10 is designed |
| 2 | **Do missiles that can be targeted, drones or fighters need Runtime IDs?** Anything another system targets or follows over time needs one; ordinary projectiles do not (Core Rule 2). | Weapons & Damage (#12), Combat Space (#11) | When #11 and #12 are designed |
| 3 | **How does Battle Resolution count an inert ship** in a mid-battle save? Provisionally as absent (Edge Cases). | Battle Resolution & Retreat (#22) | When #22 is designed |
| 4 | ~~Is a ship rebuilt from its wreck the same ship?~~ **Resolved 2026-10-29 (CD-GDD-ALIGN):** no. A rebuild is always a new ID, with an optional `rebuilt_from` link (Core Rule 4). | — | — |
| 5 | **How long are Battle Records and blame history kept?** This sets how many tombstones compaction keeps, and so the identity section's real size (D2). | #9, Faction Belief & Blame (#30) | When #9 is designed |
| 6 | **Representation:** the identity table's structure (parallel packed arrays recommended), the lookup API's shape (D4), the wire encoding (decimal strings for dictionary keys), the `issue()` restriction (context token plus lint), the incremental digest, and how sections report references for compaction. All engine facts are NOT SOURCEABLE. | technical-director | An ADR (save schema, or Tick/Pause/Determinism) |
| 7 | **Is `RESOLVE_SHARE = 0.10` signed off, and does a lookup fit 0.133 µs?** Measured by the tick-rate spike (D4). | technical-director, engine-programmer | Tick-rate spike |
| 8 | **Simulation Tick & Pause amendments** needed at its re-review: name the retire point (end of each tick, after P8) and the projectile exception in rule 3; add `next_id`, the identity digest and the projectile sequence to rule 14's hashed state. | Simulation Tick & Pause owner | Its re-review |
