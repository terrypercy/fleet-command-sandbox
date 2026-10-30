# Deterministic RNG & Seed Streams

> **Status**: In Design
> **Author**: owner + agents
> **Last Updated**: 2026-10-28
> **Last Verified**: 2026-10-28
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — one fixed, hidden truth seeded per save); Pillar 1 (Every Defeat Is a Lead — same-seed replay behind a trustworthy Debrief)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-29 — CONCERNS resolved. The reload promise reworded honestly, plus a mid-battle save-policy question (Open Questions #9); odds surfacing made a contract on every outcome-deciding consumer (UI Requirements 2, AC-43); the Pillar 2 guarantee bounded to in-game and shareable paths (Core Rule 8)

## Summary

Deterministic RNG & Seed Streams is the simulation's only source of random
numbers. It derives an independent named stream for every consumer from one
master seed per save, with each battle on its own seed and its rolls indexed by
tick. For the player, it means the hidden truth is fixed from the first moment,
defeats replay exactly and can be explained, and loading a save never re-rolls
the world. It exists because the seeded mystery, the headless AI-vs-AI runner
and every system that rolls dice depend on draws that never disturb one
another.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None` (hard); soft contracts with Simulation Tick & Pause, Runtime ID Service, Content Data & Mod Loading, Save/Load, World Clock. Depended on by Weapons & Damage, Truth Seeding, Ship AI, Fleet Coordination, AI-vs-AI Runner, Exposure, Contracts, Loot & Crafting

## Overview

Deterministic RNG & Seed Streams is the only source of random numbers in the
simulation. A save holds one **master seed**, chosen once at new game. From it
the system derives a separate, **named stream** for each consumer: truth
seeding, hit rolls, AI tie-breaks, loot, missions, rival investigators, and any
later consumer. A stream's output depends only on its parent seed (the master
seed, or the battle's own seed), the stream's full name (including the Runtime
ID key of a per-ship stream), and its position: how many draws the stream has
made, or, for a battle stream, the battle tick and how many draws it has made
in that tick. Two consequences follow:
- **No consumer can shift another's results.** A weapon that rolls one extra
  hit chance never changes which maker is the hidden truth, what a wreck
  drops, or how a rival investigator moves.
- **Every stream's state is saved, restored and hashed exactly.** It goes
  into every save and into the per-tick `state_hash` (Simulation Tick & Pause,
  rule 14). The same seed and the same recorded commands therefore replay the
  same battle.

Nothing else in simulation code may draw randomness; engine-global random
calls are banned (Simulation Tick & Pause, AC-34).

The player never sees a stream, but feels what it guarantees:
- **The truth is fixed.** The hidden maker is set the moment the game begins,
  and nothing the player does later re-rolls it (concept: *"one fixed, hidden
  truth per save"*).
- **Defeats are explainable.** The battle the After-Action Debrief explains is
  the battle that happened, and the headless runner can prove it by replaying it.
- **Systems stay independent.** Adding a feature never quietly reshuffles the
  rest of the world.

Without this system three things would break:
- Any change to how often one system draws would silently change every other
  system's outcomes, including the seeded truth.
- The AI-vs-AI runner could not reproduce a battle from a seed, so Tier 0's
  boundary test, *"the headless runner reproduces the same battle twice from one
  seed"*, could not pass.
- Tuning in the headless runner would measure noise from unrelated draws
  instead of the change being tuned.

*How* the streams are built (the generator algorithm, how a stream's seed is
derived from the master seed and the name, our own small generator versus a
pinned `RandomNumberGenerator`, and integer-safe encoding) is an implementation
choice → **becomes the Tick/Pause/Determinism ADR** (Simulation Tick & Pause,
Open Question 4). This GDD specifies behaviour, guarantees and contracts only.

## Player Fantasy

**The case was sealed before you arrived.** The player experiences this system
**indirectly**. They never think about seeds. What they feel is that the
galaxy has its own facts and keeps them.

The truth about who built the Instrument was set when this galaxy began.
Nothing the player does can change it, re-roll it or look it up. Every fragment
they find is a real piece of a real case, not something produced to suit their
theory. A detective can only solve a crime that actually happened. The same
holds in battle and in the salvage hold. What happened, happened, and it is
still the same after the player loads a save. **The moment is fixed: a bad
result is answered by changing what you do, and acting at a different moment
is a different action.**

*Anchor moment:* two fragments independently contradict the player's favourite
suspect. The Case File marks the theory ruled out. The player knows the galaxy
did not change its mind: they were wrong, and the evidence was always there.

**Pillars served:**
- **Pillar 2, *The Truth Is Yours to Tell*:** "The truth about who built the
  machines is fixed; the history the galaxy believes is yours to write." This
  system is what makes the truth fixed.
- **Pillar 1, *Every Defeat Is a Lead*:** a defeat can be replayed exactly, so
  its cause can be shown and countered, never put down to chance.
- **Pillar 4, *Plan in the Open*, and the concept's rule that what follows
  "obeys no hidden rule and is legible after the fact":** the game **says**
  that loading does not re-roll outcomes (rule on reloads, Detailed Design), so
  the behaviour is never a hidden rule the player has to discover.

**Tone:** archival and forensic. The player is reading a record, not playing a
slot machine. The verbs are *sealed, recorded, kept, stands*. Player-facing text
never says "luck", "fate", "RNG", "dice" or "roll", and nothing about this
system may sound like a gambling mechanic. Example of the one statement the game
makes about it (wording goes to `narrative-director`): *"This galaxy keeps its
record. Loading returns you to the moment; it does not change what the moment
holds."*

**This system must never make the player feel:**
- **That the truth answered them.** No result may look as if the galaxy picked
  the maker, or chose which fragments exist, because of what the player
  believed, shared or reloaded.
- **That the world is watching their saves.** No hidden rubber-banding, pity
  timers, or difficulty that reacts to reloads. Each draw depends only on the
  seed, the stream's name and its position in that stream (in battle, the tick
  and the draw within it), and the game says so.
- **That a defeat was luck.** Where a random roll decides an outcome, the odds
  are readable before the fight (Pillar 4), and the Debrief names a cause the
  player can counter, never "bad luck".

*Shaped by `creative-director` (framing A, "The case was sealed before you
arrived", closed with framing B's last line). Framing C, "Rivals on the same
clock", belongs to Exposure & Rival Investigation (#32), whose fantasy this
system only makes possible. Owner decision: reloads restore every stream
exactly, and the game says so.*

## Detailed Design

### Core Rules

1. **The only source of simulation randomness.**
   - Every random value that reaches `SimState` is drawn from a stream this
     system owns.
   - Engine-global random calls, `RandomNumberGenerator`, `shuffle` and
     `pick_random` are banned in simulation code (Simulation Tick & Pause,
     AC-34). Shuffles and weighted picks are this system's own helpers (rule 7).
   - Nothing in the simulation reads OS entropy, time, or any other source on
     the lint lists of Simulation Tick & Pause AC-34 and this GDD's AC-31. The
     one exception is the master seed's entropy, read by the driver (rule 8).
2. **Two levels: campaign streams and battle streams.**
   - **Campaign streams** are derived from the save's **master seed** and the
     stream's name.
   - Each battle has its own **battle seed**, derived from the master seed, the
     name `base:battle` and `battle_ordinal`. `battle_ordinal` is a saved
     campaign counter that goes up by 1 each time a `BATTLE` context starts
     (D2).
   - **Battle streams** are derived from the battle seed and the stream's name
     only, never from the master seed directly.
   - Consequences:
     - A battle replays from its battle seed and its command log alone.
     - Campaign draws can never shift battle draws, and battle draws can never
       shift campaign draws.
     - The AI-vs-AI runner seeds a battle directly with a battle seed and needs
       no campaign at all.
     - Loading a save made before a battle gives the same `battle_ordinal`, so
       the same battle. Retreating and engaging again starts a new battle with
       a new ordinal.
3. **A stream's output depends on (parent seed, full name, position), and
   nothing else.**
   - **Campaign streams:** the position is the stream's own draw count. Each
     draw continues the sequence.
   - **Battle streams are tick-indexed:** the position is
     `(battle_tick, draw_index_in_tick)`, where
     `battle_tick = tick_index − battle_start_tick` (Simulation Tick & Pause,
     rule 1) and the index restarts at 0 every tick (D1). A battle roll
     therefore never depends on how many rolls that stream made on earlier
     ticks. That closes the reload loophole of "burning" a known roll with a
     cheap shot first (rule 11). Repeating the same commands still repeats the
     battle exactly, because ticks are part of the record.
   - A stream's seed comes from its **name**, never from a list position or the
     order streams were registered or first used.
   - So adding a stream in a patch never changes an existing stream, a mod's
     streams never change base streams, and creating a stream changes nothing
     until it is drawn.
   - **Renaming a stream changes its output.** A rename is a versioned,
     replay-breaking change, like changing `TICK_RATE`.
4. **Names.** `<namespace>:<system>.<purpose>`, for example `base:combat.hit`,
   `base:truth.maker`, `mymod:raid.spawn`.
   - Names are ASCII, matching
     `^[a-z][a-z0-9_]*:[a-z][a-z0-9_.]*(#(0|[1-9][0-9]*)(/(0|[1-9][0-9]*))*)?$`.
     The optional key suffix (rule 5) is canonical unsigned decimal with no
     leading zeros, so one ship can never have two spellings of its stream.
     A key part that is a Runtime ID is at least 1, because `NONE` (0) is never
     issued (Runtime ID Service, Core Rule 1); a draw keyed by Runtime ID 0 is
     refused like an undeclared name. Other key parts, such as a weapon slot,
     may be 0.
     There is no Unicode, so there is nothing to normalise.
   - A declared key pattern whose longest possible name exceeds
     `NAME_MAX_BYTES` (D1) is rejected when the registry loads, never at first
     draw.
   - `base:` is reserved for shipped content. A mod may use only its own content
     namespace (Content Data & Mod Loading #4 enforces namespaces).
   - Every stream is **declared** by its owning system's GDD and registered as a
     constant in one stream registry. The registry rejects duplicate names, and
     any two names whose derived seeds collide.
   - Drawing from an undeclared name is a hard error in debug builds and is
     refused, with a logged error, in release builds.
5. **Keyed streams for combat and AI; one stream per consumer elsewhere.**
   - **Battle streams drawn per entity are keyed by Runtime ID.** Weapon hit
     rolls use `base:combat.hit#<ship_id>/<weapon_slot>`. Ship AI tie-breaks
     use `base:ai.tiebreak#<ship_id>`, and Fleet Coordination tie-breaks use its
     own `base:fleet.tiebreak#<fleet_id>`, so each stream has exactly one owner
     (rule 6). Each owning GDD declares the key pattern. Adding
     a ship, a weapon or a fleet therefore never changes another ship's rolls.
     A tuning comparison in the headless runner changes only what it changed.
   - **Campaign streams are one per consumer** (for example `base:truth.maker`,
     `base:missions.offer`, `base:rivals.search`). They are drawn in a fixed
     order of campaign events, so order coupling inside them is deterministic.
   - A keyed stream is created lazily on its first draw and lives as long as its
     context. Battle-keyed streams are discarded at battle end.
   - **This depends on Runtime ID Service (#3): a Runtime ID is never reused
     within a save.** A reused ID would replay a destroyed ship's sequence.
6. **Owner-only, phase-ordered draws.**
   - A stream is drawn only by the system that declared it.
   - Battle streams are drawn only inside their owner's tick phase, in ascending
     Runtime ID order (Simulation Tick & Pause, rule 3). Campaign streams are
     drawn only in their owner's campaign step.
   - **Campaign streams are not drawn during `BATTLE`.** A campaign event that
     falls due while a battle runs (a rival's search step on a day that passed
     in battle) draws when the battle context ends, in the World Clock's
     catch-up order. This keeps a battle replayable from its battle seed alone.
     *Provisional contract with World Clock (#8) and Exposure & Rival
     Investigation (#32); see Open Questions.*
   - Nothing draws during presentation, UI, odds previews, save, load or
     hashing. Odds shown to the player (Pillar 4) are **computed, never drawn**.
   - No call reveals a future value: there is no peek and no lookahead.
   - Consumers receive their stream as an injected handle, never by looking up
     a name string at the call site. A handle always refers to the live stream,
     so a load that restores state is seen by every existing handle.
7. **Draw calls (behaviour).** Every call consumes a number of generator steps
   determined only by its inputs and the stream's state. **One draw is one
   32-bit output word**, and draw counts count words (Formulas).
   - **`int_range(a, b)`**: uniform and unbiased over `[a, b]` inclusive, by
     rejection, never by plain modulo (D3). `a > b` is an error.
   - **`chance_permille(p)`**: true with probability `p / 1000`, for integer `p`
     from 0 to 1000 (D4). `p = 0` is never true and `p = 1000` is always true, and
     both still make their `int_range` call, so the draw count never depends on
     `p` taking an edge value.
     **Every outcome-deciding probability is an integer threshold.** Data stores
     probabilities as integer permille.
   - **`unit_float()`**: a float in `[0, 1)` built from 53 bits of output (D6).
     It may feed continuous maths (a spread angle), but never a threshold
     comparison that decides an outcome.
   - **`weighted_pick(table)`**: picks from a table of `(stable_id,
     integer_weight)` entries, sorted by `stable_id` at load (D5). It is never
     a Dictionary.
     - A negative weight is a content error rejected at load. That is
       consistent with Godot 4.7.2's `rand_weighted` refusing negative weights,
       and this helper does not use the engine call.
     - A zero weight is never picked.
     - A table whose weights total 0 is a content error at load. At run time,
       an empty table returns "no pick" and consumes no draw; the caller's GDD
       defines what happens then.
   - **`shuffle(list)`**: Fisher–Yates, using exactly `n − 1` `int_range` calls
     for `n ≥ 2`. A list of 0 or 1 items is returned unchanged with no call.
   - **Computed probabilities** (for example accuracy minus evasion) are
     clamped to 0–1000 by the consumer before the call. `chance_permille`
     asserts `0 ≤ p ≤ 1000`, because load-time validation cannot see computed
     values.
   - **A refused draw** (an undeclared name, or a keyed name that collides when
     created) consumes no word and returns the lowest legal result: `a` for
     `int_range`, false for `chance_permille`, 0.0 for `unit_float`, and "no
     pick" for `weighted_pick`. It is logged. It is a hard error in debug builds,
     and in release builds it stays deterministic. The refusal mode and the
     name hash are injected, so tests can run both modes and force a collision
     (Acceptance Criteria).
   - **AI tie-breaks:** each AI decision draws exactly one value per actor per
     tick from that actor's tie-break stream, whether or not a tie exists.
     Candidates are ranked by utility, then by that value mixed with the
     candidate's ID (the mixing function is defined in the ADR and pinned by a
     known-answer test), then by the candidate's Runtime ID. A tie therefore resolves
     the same way every run, and adding an unrelated candidate never flips which
     of a tied pair wins. Candidate lists are built in ascending Runtime ID.
   - **Sorting:** every simulation sort uses a total order ending in Runtime ID
     or stable content ID, because an engine sort is not assumed to be stable.
8. **The master seed.**
   - One 64-bit master seed is drawn from OS entropy **once, at new game**, by
     the driver boundary (Simulation Tick & Pause, rule 7), and handed into the
     simulation. Nothing else ever sets it.
   - **No player-entered seed at MVP.** A known seed would let the true maker be
     looked up, which breaks Pillar 2 (*"nothing the player does can change it,
     re-roll it or look it up"*, Player Fantasy).
   - **The seed is not shown in normal UI.** It is written into the bug-report
     bundle and the dev debug overlay only, so problems can be reproduced.
   - **Where the Pillar 2 guarantee stops.** No in-game or shareable path reveals
     the truth: no seed entry, no seed in normal UI, and no seed carried from one
     save to another. Inspecting save files or game code is out of scope; the
     seed is in every save by necessity.
   - The bug-report bundle **never prints the results of `base:truth.*` draws**
     in readable form. It carries the seed, which reproduces them, and nothing
     that names the maker.
   - The headless runner and tests pass an explicit master or battle seed.
9. **Presentation randomness is separate.**
   - VFX jitter, camera shake, audio variation and other cosmetic randomness use
     presentation-owned generators that are not seeded from the save.
   - Their output never enters `SimState`. Simulation code cannot reference
     them, and presentation cannot draw a simulation stream. Both are enforced by
     lint: Simulation Tick & Pause AC-34, and this GDD's AC-31 and AC-32. The
     replay hash test (AC-34 here) catches any leak.
10. **Persistence and hashing.**
    - **Saved:** the master seed, `battle_ordinal`, and for each campaign
      stream that has been drawn: its full name, its generator state and its
      draw count. A mid-battle save also holds the battle seed and, for each
      drawn battle stream, its name and total draw count. A battle stream has
      no other state to save: saves happen at tick boundaries, where every
      battle stream's in-tick index is 0 (rule 3).
    - **A load restores stored state; it never fast-forwards.** A renamed
      stream is migrated as a name remap by Save/Load (#5), so an old save
      continues the same sequence.
    - A stream exists in the save and in the hash only **after its first draw**.
    - **Hashed into `state_hash`:** every existing stream's state and draw count,
      ordered by the bytes of the full stream name (never by Dictionary or
      creation order), plus the battle seed in `BATTLE`.
    - **Encoding:** every 64-bit value (seeds, states, counts) is stored as
      bytes or a fixed-width hex string, never as a JSON number (Simulation Tick
      & Pause, rule 14). Save/Load (#5) owns the format.
    - **Battle Record:** the battle seed and the stream registry version are
      written into the Battle Record header (#9) at battle start, so the Debrief
      and the runner can replay it.
11. **Reloads restore exactly, and the game says so.** Loading restores every
    stream's state; nothing is re-derived or re-rolled. Repeating the same
    actions after a load gives the same results, and doing something different
    gives different results. Because battle rolls are tick-indexed (rule 3),
    acting at a different moment gives a different roll, and a known roll
    cannot be "used up" by firing something else first.
    - **The statement:** string key `ui.rng.reload_statement` (Player Fantasy).
      `narrative-director` owns the wording; the screen that shows it, and when,
      are set in the UX spec (Open Questions).
    - **No reaction to reloads:** outcomes are invariant to the number of
      reloads (AC-39). There are no pity timers and no difficulty that adapts to
      reloads.
12. **Platform scope.** A stream's raw output is integer-only. Each shipped
    platform's build must match the golden tables (AC-38). Floats computed from
    it are covered by Simulation Tick & Pause rule 14: verification is
    same-platform only at MVP, and cross-platform replays are marked
    "unverified".

### States and Transitions

| State | Entered by | Live streams | Drawing allowed | Leaves when |
|---|---|---|---|---|
| **Unseeded** | Boot, main menu | None | No: any draw is an error | New game or Load |
| **Campaign** | New game (master seed from entropy, `battle_ordinal = 0`, truth streams drawn) or Load | Campaign streams | Campaign streams, by their owners, in campaign steps | A battle starts; quit |
| **Battle** | `BATTLE` context starts: `battle_ordinal += 1`, battle seed derived and written to the Battle Record header. Or the runner injects a battle seed | Battle streams (keyed and unkeyed); campaign streams held | Battle streams only, in tick phases | The battle context ends |
| **Battle end** | Battle Resolution (#22) ends the context | Battle streams discarded; final states recorded | Deferred campaign events draw, in World Clock catch-up order | Back to Campaign |
| **Replay / headless** | Runner or Debrief replay, given a battle seed and a command log | Battle streams rebuilt from draw 0 | As in Battle | The run ends |

Save and load are not states. They happen at tick boundaries in Campaign or
Battle, and a load returns to the state that was saved.

### Interactions with Other Systems

| System | Flows into this system | Flows out of this system | Interface owner |
|---|---|---|---|
| Simulation Tick & Pause (#1) | Context (`BATTLE`/`CAMPAIGN`), phase, `tick_index` | Stream states and draw counts for `state_hash`; the battle seed | Tick owns phase order and the hash; this system owns streams |
| Runtime ID Service (#3) | Runtime IDs as stream keys; the guarantee that no ID is reused within a save | — | ID Service |
| Content Data & Mod Loading (#4) | Namespaces; declared stream names from mods; weight and permille tables to validate | Load-time rejection of negative weights, zero-total tables and undeclared names | #4 enforces namespaces; this system enforces naming and validation |
| Save/Load & Migration (#5) | Restored stream records | Master seed, `battle_ordinal`, battle seed, stream records | Save owns format and integer-safe encoding |
| World Clock (#8) | Catch-up order for campaign events deferred from a battle | — | World Clock |
| Combat Event Bus & Battle Record (#9) | — | Battle seed and registry version for the record header | #9 |
| Weapons & Damage (#12) | — | `base:combat.hit#<ship_id>/<weapon_slot>`, permille checks | #12 owns hit odds |
| Truth Seeding & Candidates (#16) | — | `base:truth.*` campaign streams, drawn at new game only | #16 |
| Ship AI (#20) | — | `base:ai.tiebreak#<ship_id>`, one draw per actor per decision per tick | Ship AI owns decisions |
| Fleet Coordination (#21) | — | `base:fleet.tiebreak#<fleet_id>`, one draw per fleet per decision per tick | Fleet Coordination owns decisions |
| Battle Resolution & Retreat (#22) | Battle end | — | #22 |
| After-Action Debrief (#24) | — | The battle seed for replay | #24 |
| AI-vs-AI Runner (#25) | Injected battle seeds | Streams and hashes per run | Runner owns seed sweeps |
| Exposure (#32), Contracts (#38), Loot & Crafting (#39), Sector Map (#26, Tier 1 procedural) | — | Campaign streams, one per consumer | Each consumer declares its streams |
| Presentation (#45), Audio (#52) | — | Nothing: they use their own cosmetic generators | Presentation |

**What no system can do:**
- draw from another system's stream
- draw during presentation, UI, preview, save, load or hashing
- peek at or skip ahead in a stream
- set or read the master seed, except the driver at new game, Save/Load, and
  the bug-report bundle
- re-seed a stream after it is created

*Specialists consulted:*
- `systems-designer` (primary: hierarchy, naming, draw rules, lifecycle)
- `gameplay-programmer` (keyed substreams, AI tie-break rule, handles, test fakes)
- `engine-programmer` (own generator recommendation, integer and hex constraints)

*Owner decisions (2026-10-29):*
- two levels, with a battle seed
- keyed streams for combat and AI only
- no player-entered seed at MVP
- the seed is visible in bug reports and debug only

*Specialist disagreement, resolved by the owner:* `systems-designer` proposed
one stream per consumer with optional keys; `gameplay-programmer` proposed
per-entity keys everywhere. The owner chose keys for combat and AI only.

*Handed to the ADR (Simulation Tick & Pause, Open Question 4):*
- the generator: own PCG32 recommended over pinning `RandomNumberGenerator`
- the derivation hash: FNV-1a 64 plus a SplitMix64 mixer recommended, never
  the engine's `String.hash()` or `hash()`
- unsigned 64-bit maths on GDScript's signed `int`
- a counter-based construction for tick-indexed battle streams (D1)
- the byte encoding
- a per-tick draw budget, and a GDExtension fallback if GDScript draws prove
  too slow (see Formulas)

All engine behaviour here is NOT SOURCEABLE in `docs/engine-reference/godot/`
(there is no `modules/core.md`); the ADR verifies it with probe tests.

## Formulas

All stream arithmetic is unsigned 64-bit, carried in GDScript's signed 64-bit
`int`; how is the ADR's choice. **One draw is one 32-bit generator output
word**, and every draw count counts words. All outcome-deciding values are
integers. The only float this system produces is D6's, and it is exact.

### D1. Stream seed derivation

The stream_seed formula is defined as:

`stream_seed = H(parent_seed, name_bytes)`, with H recommended as
`SplitMix64(parent_seed XOR FNV1a64(name_bytes))`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| parent_seed | int (u64) | 0 – 2^64 − 1 | calculated | The master seed (campaign streams) or the battle seed (battle streams) |
| name_bytes | bytes | 3 – `NAME_MAX_BYTES` ASCII bytes | constant (registry) / calculated (key suffix) | The full stream name, including any `#key` |
| NAME_MAX_BYTES | int | 64 | constant (engineering) | Longest legal full name |
| stream_seed | int (u64) | 0 – 2^64 − 1 | calculated | The stream's initial generator seed |

"SplitMix64" here and in every formula means the **full SplitMix64 step**: add
the constant `0x9e3779b97f4a7c15`, then apply the finaliser. The bare finaliser
maps 0 to 0. The full step does not: `SplitMix64(0) = 0xe220a8397b1dcdaf`.

**Output Range:** the full 64 bits.
- The full SplitMix64 step is a bijection, so two names with different
  `FNV1a64` values never give the same seed under the same parent.
- **Collision rule:** the registry rejects any two declared names with equal
  `FNV1a64(name)`. That check holds for every parent seed. A keyed name whose
  hash collides with a live stream is a hard error when it is created.
- For 2,000 names, the chance of any collision is about 2,000² / 2^65 ≈ 1 × 10⁻¹³.

**Example:** `parent = M` and `name = "base:combat.hit#1042/3"` (22 bytes). With
`h = FNV1a64(name)`, `stream_seed = SplitMix64(M XOR h)`. The same `M` and name
give the same seed on every run, on every machine.

**Battle streams are tick-indexed (Core Rule 3).** Each tick, a battle stream
restarts from a per-tick seed:

`tick_seed = SplitMix64(stream_seed XOR SplitMix64(battle_tick))`

Draws in that tick run the generator from `tick_seed`, and `draw_index_in_tick`
starts at 0.

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| battle_tick | int | 0 – 2^53 − 1 | calculated | `tick_index − battle_start_tick` (Simulation Tick & Pause, rule 1) |
| draw_index_in_tick | int | 0 – `DRAW_BUDGET_PER_TICK` in practice | calculated | Words drawn from this stream in this tick; 0 at every tick boundary |
| tick_seed | int (u64) | 0 – 2^64 − 1 | calculated | Generator start for this stream on this tick |

The value at a given `(battle_tick, draw_index_in_tick)` never depends on what
the stream drew on any earlier tick. *The exact construction (this
SplitMix64 form, or a counter-based generator) is the ADR's choice. The
behaviour is fixed here.*

### D2. Battle seed

The battle_seed formula is defined as:

`battle_seed = H(master_seed, "base:battle" ‖ u64le(battle_ordinal))`

`‖` is byte concatenation, and `u64le` is the ordinal as 8 little-endian bytes.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| master_seed | int (u64) | 0 – 2^64 − 1 | calculated (OS entropy, once at new game) | The save's master seed |
| battle_ordinal | int | 1 – 2^63 − 1; 0 means no battle has started | calculated (saved) | Goes up by 1 when a `BATTLE` context starts |
| battle_seed | int (u64) | 0 – 2^64 − 1 | calculated | The parent seed of every battle stream |

**Output Range:** the full 64 bits.
- **The ordinal cannot overflow.** A 100-hour campaign with a battle every 3
  minutes is 2,000 battles, about 2^11, against a limit of 2^63.
- Ordinal 0 never seeds a battle.
- The runner injects `battle_seed` directly and ignores the ordinal.
- **No battle seed can equal a campaign stream's seed.** Both derive from the
  master seed through H, so the registry also rejects any declared campaign
  name whose `FNV1a64` equals that of `"base:battle" ‖ u64le(k)` for any `k`
  from 1 to 65,536. Campaigns longer than 65,536 battles are out of scope.

**Example:** a save made before the 7th battle restores `battle_ordinal = 6`.
The next battle raises it to 7, so
`battle_seed = H(M, "base:battle" ‖ 07 00 00 00 00 00 00 00)`, the same seed it
had before the reload.

### D3. Unbiased int_range(a, b)

The int_range formula is defined as:

`n = b − a + 1`
`threshold = (2^32 − n) mod n`
repeat `x = next_u32()` until `x ≥ threshold`
`int_range = a + (x mod n)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| a, b | int | −2^62 – 2^62, with a ≤ b | calculated | Inclusive bounds. Bounds out of range, or a > b, are an error. The ±2^62 limit keeps `b − a` from overflowing a signed 64-bit int |
| n | int | 1 – 2^31; `n > 2^31` is an error, as `a > b` is | calculated | Size of the range |
| x | int (u32) | 0 – 2^32 − 1 | calculated | One draw |
| p_reject | float | 0 – ≈ 1/3 | calculated | `threshold / 2^32`, the chance one draw is rejected |
| E_draws | float | 1 – 1.5 | calculated | `1 / (1 − p_reject)`, the expected draws per call |

**Output Range:** `[a, b]`, exactly uniform.
- When `n` is a power of two (including n = 1 and n = 2^31), `threshold = 0`
  and no draw is ever rejected.
- The worst case is n = 1,431,655,766 (just above 2^32 / 3): `p_reject ≈ 0.333`,
  so 1.5 draws on average.
- The number of draws varies between calls, but it is fully determined by the
  stream's state.

**Example:**
- n = 6: `threshold = 4`, `p_reject = 9.3 × 10⁻¹⁰`. A draw of 4,000,000,123 is
  accepted. `4,000,000,123 mod 6 = 1`, so `int_range(1, 6) = 2`.
- n = 1000: `threshold = 296`, `p_reject = 6.9 × 10⁻⁸`. A draw of 200 is
  rejected. The next draw, 123,456,789, gives `int_range(0, 999) = 789`.

### D4. chance_permille(p)

The chance_permille formula is defined as:

`chance_permille(p) = int_range(0, 999) < p`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| p | int | 0 – 1000 | data file (the consumer's) | Probability in permille. Validated at load |
| result | bool | — | calculated | True with probability exactly `p / 1000` |

**Output Range:** `p = 0` is never true, and `p = 1000` is always true. Both still
make one `int_range` call. The odds shown to the player are **exactly `p / 10`
percent** to one decimal place, with no float rounding anywhere.
**Example:** with `p = 650` the player is shown "65.0%". A draw of 789 is not
below 650, so the result is false.

### D5. weighted_pick(table)

The weighted_pick formula is defined as:

`cum_i = Σ_{j ≤ i} w_j`
`W = cum_k`
`r = int_range(0, W − 1)`
`weighted_pick = the first entry i with cum_i > r`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| w_i | int | 0 – 2^31 | data file (the consumer's) | Entry weights, in a table sorted by unique `stable_id` at load |
| k | int | 1 – 2^16 | data file (the consumer's) | Number of entries. An empty table returns "no pick" and makes no draw |
| W | int | 1 – 2^31 | calculated | The total weight, checked at load so D3 applies |

**Output Range:** entry `i` is picked with probability exactly `w_i / W`.
- A zero weight gives `cum_i = cum_{i−1}`, so that entry can never be picked.
- A negative weight, a total of 0, a total above 2^31 and a duplicate
  `stable_id` are all content errors at load.

**Example:** `[(alpha, 3), (beta, 0), (gamma, 5)]` gives cumulative sums 3, 3, 8
and `W = 8`. `r` from 0 to 2 picks alpha; `r` from 3 to 7 picks gamma; beta is
never picked. A draw of `r = 3` picks gamma (probability 5/8).

### D6. unit_float()

The unit_float formula is defined as:

`unit_float = ((u1 >> 5) × 2^26 + (u2 >> 6)) / 2^53`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| u1, u2 | int (u32) | 0 – 2^32 − 1 | calculated | Two consecutive draws |
| unit_float | float | 0 – 1 − 2^−53 | calculated | Uniform on a grid of 2^−53 |

**Output Range:** `[0, 1 − 2^−53]`. It never returns 1.0. The result is exact on
every platform: the numerator is an integer below 2^53 and the denominator is a
power of two. Every call uses exactly 2 draws.
**Example:** `u1 = 0x80000000` and `u2 = 0` give `2^26 × 2^26 / 2^53 = 0.5`. All-ones
inputs give `(2^53 − 1) / 2^53`.

### D7. Draw counts, stream counts and save size

The save_stream_bytes formula is defined as:

`S_live = ships × slots + ships + fleets + S_unkeyed`
`save_stream_bytes = S_live × (name_len + 16 + overhead)`

A battle stream's record holds its name and total draw count only (16 hex
characters), because a tick-indexed stream has no state at a tick boundary
(Core Rule 10). Campaign stream records add 16 more characters for generator
state; there are only about 20 of them.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| draw_count | int (u64) | 0 – 2^63 − 1 | calculated (saved) | Words drawn from one stream |
| ships | int | 100 (stress: 200) | calculated | Simulation Tick & Pause D10 steady fixture |
| slots | int | ≈ 6 (placeholder) | data file (Weapons & Damage #12 owns it) | Weapon slots per ship |
| fleets | int | ≈ 4 | calculated | Fleets in the battle (Fleet Coordination tie-break streams) |
| S_unkeyed | int | ≈ 20 | constant (registry) | Unkeyed battle streams |
| name_len | int | ≈ 30 | calculated | Bytes in a keyed name such as `base:combat.hit#4294967296/12` |
| overhead | int | ≈ 20 | constant (Save/Load #5 format) | Separators and field keys |
| S_live | int | ≈ 720 (stress ≈ 1,420) | calculated | Battle streams alive at once |

**Output Range:** about 724 streams at about 66 bytes each, so about 48 KB
(about 94 KB under stress), carried by **mid-battle saves only**. **Ceiling:
the RNG section of a mid-battle save at the D10 steady fixture is at most
64 KB** (`RNG_SAVE_CEILING_KB`, provisional; AC-41). Campaign saves
hold only the unkeyed campaign streams.
- The busiest stream in a 20-minute battle (one AI tie-break per tick) makes
  about 72,000 draws in total, far below 2^63. Because battle streams restart
  every tick, no generator sequence in a battle runs longer than one tick's
  draws.

**Example:** `100 × 6 + 100 + 4 + 20 = 724` streams, and `724 × 66 = 47,784`
bytes.

### D8. Draw budget per tick

The rng_tick_cost formula is defined as:

`rng_ms = draws_per_tick × t_draw_us / 1000 ≤ RNG_SHARE × L`
`DRAW_BUDGET_PER_TICK = floor(RNG_SHARE × L × 1000 / t_draw_us)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| L | float (ms) | 4.0 at 60 Hz (8.0 at 30 Hz) | calculated (Simulation Tick & Pause D10) | Per-tick pass line |
| RNG_SHARE | float | 0.10 – 0.15 (**0.15, provisional**) | constant (engineering; needs technical-director sign-off) | This system's share of `L` |
| t_draw_us | float (µs) | 1 – 3 (an estimate; NOT SOURCEABLE in the engine reference) | calculated (measured by the spike) | Cost of one draw call, including the handle |
| draws_per_tick | int | measured | calculated | Draw calls in one tick |
| DRAW_BUDGET_PER_TICK | int | provisional; set from the spike | constant (engineering) | Draw calls allowed per tick |

**Output Range:** at a 15% share the budget is 0.6 ms, which is 600 draws at
1 µs or 200 at 3 µs. At 10%, it is 400 or 133.
- Estimated demand per tick:
  - 100 AI tie-breaks (one per actor);
  - hit rolls, about 10 on an average tick and up to about 600 on a
    full-broadside volley;
  - 2 per spread `unit_float`.
- **At 3 µs a volley tick fails the budget.** That is the trigger for the
  GDExtension fallback (ADR).
- A demand of 5,000 draws per tick (5–15 ms) would break `L` on its own.

**Example:** with `t_draw = 1.5 µs` and `RNG_SHARE = 0.15`, the budget is
`0.6 × 1000 / 1.5 = 400` draws per tick.

**The tick-rate spike must measure:**
- p95 `t_draw` for each call type: `int_range`, `chance_permille`, `unit_float`,
  a stream's first draw in a tick (the per-tick seed, D1), and a stream's first
  draw ever (lazy creation plus D1);
- p95 and maximum `draws_per_tick` on Simulation Tick & Pause D10's steady and
  worst-case scenes, plus a full-broadside volley;
- all of it headless, on the reference machine.

*Specialist consulted: `systems-designer`. Its proposal corrected three points
in the brief: D3's worst case is 1.5 draws, not 2; `int_range` bounds must stay
within ±2^62 to avoid overflow; and a "draw" is defined as one 32-bit word.
Every worked example was re-checked arithmetically.*

*For the ADR:*
- **D1:** confirm FNV-1a 64 + SplitMix64, and the bijection the collision rule
  relies on.
- **D2:** the ordinal byte encoding.
- **D3:** the `next_u32` source, and unsigned compares on signed `int`.
- **D5:** where the load-time sort and the `W ≤ 2^31` check run.
- **D6:** the 27 + 26 bit layout.
- **D7:** whether a campaign generator's per-stream increment is derived from
  the name or saved. A load restores stored state; it never fast-forwards
  (Core Rule 10).
- **D8:** sign off `RNG_SHARE`, and the `t_draw_us` threshold that triggers the
  GDExtension fallback.

## Edge Cases

### Seeds and derivation

- **If the master seed or a battle seed is 0**: it is valid and derives
  normally. SplitMix64 has no degenerate input, so nothing is remapped.
- **If a declared campaign name's hash equals the battle-seed input for some
  ordinal**: the registry rejects the name at load (D2). Otherwise that battle's
  seed would equal the campaign stream's seed.

### Streams and names

- **If a key is written with a leading zero (`#01042`)**: the name is rejected
  as illegal (Core Rule 4). Keys are canonical decimal, so one ship can never
  have two streams.
- **If a declared key pattern's longest possible name exceeds
  `NAME_MAX_BYTES`** (a long mod namespace plus a 16-digit ID, up to
  `MAX_RUNTIME_ID` in Runtime ID Service D1, plus a slot): the
  declaration is rejected when the registry loads, never at first draw.
- **If a name is drawn that is not declared, or a keyed name collides with a
  live stream when it is created**: the draw is refused as Core Rule 7 says. It
  consumes no word, returns the lowest legal result and is logged. It is a hard
  error in debug builds.

### Draw calls

- **If `int_range(a, a)` is called**: it returns `a` and consumes exactly one
  draw (D3, n = 1, never rejects). The draw count never depends on an edge
  value.
- **If `int_range` is called with `n > 2^31`, `a > b`, or a bound beyond
  ±2^62**: it is an error (D3).
- **If D3 rejects many draws in a row**: it keeps drawing. There is no iteration
  cap, because a cap would change results. The generator's full period
  guarantees the loop ends, and the expected number of draws is at most 1.5.
- **If `shuffle` gets a list of 0 or 1 items**: it returns the list unchanged
  and makes no call (Core Rule 7).
- **If `weighted_pick` has one entry**: it still makes one
  `int_range(0, W − 1)` call, so the draw count does not depend on table size.
- **If a computed probability falls outside 0–1000 at run time** (accuracy
  minus evasion): the consumer clamps it before the call, and
  `chance_permille` asserts the range (Core Rule 7). Load-time validation does
  not cover computed values.

### Battles and contexts

- **If a battle ends on its first tick, or the player retreats from the
  Battle-start pause**: the ordinal is still used up. Streams that were never
  drawn are never saved or hashed. The Battle Record header already holds the
  battle seed.
- **If a `BATTLE` context starts while another is live**: it is an error. Only
  one battle seed exists at a time. Back-to-back engagements pass through
  Battle end and Campaign in between.
- **If Simulation Tick & Pause's tick-rate fallback offers the battle's
  pre-battle state** (a mid-battle save from a different `TICK_RATE`): that state
  holds `battle_ordinal` **before** the increment, so the battle starts again
  under the same seed, not ordinal + 1.
- **If the runner injects a battle seed**: `battle_ordinal` is neither read nor
  written, and the Battle Record header records the seed with ordinal 0.
- **If a ship is disabled and makes no decision on a tick**: it makes no
  tie-break draw. Because battle streams are tick-indexed (Core Rule 3), a
  skipped draw changes nothing on any later tick.
- **If the World Clock passes an event's due time during a battle tick**: P8
  queues the event and makes no draw (Core Rule 6). It draws at battle end, in
  World Clock catch-up order.

### Saves, loads and replay

- **If a save is requested at battle end while deferred campaign draws are
  running**: it waits until catch-up completes. That step is held by a `SYSTEM`
  hold, like any save, and it is not a tick (Simulation Tick & Pause, rule 17).
- **If a declared stream is missing from a save**: it is treated as never
  drawn, and starts from its first position on first use. That matches Core
  Rule 10, where a stream exists only after its first draw.
- **If a stream record is malformed** (a bad name, non-hex or wrong-width hex, a
  draw count above 2^63 − 1, or a duplicate name): the whole load is refused,
  and the error names the stream. Nothing is partly restored or re-derived
  (Core Rule 11).
- **If a save holds a stream that is no longer declared** (its mod was removed):
  the record is kept verbatim and inert. It is never drawn, it is written back
  unchanged, and it **stays in `state_hash`** because it is saved state. Re-adding
  the mod continues the stream where it stopped.
- **If a save from an older registry version holds a renamed stream**: Save/Load
  (#5) migrates the name as a remap, and the stored state continues the same
  sequence. A load never fast-forwards (Core Rule 10).
- **If a replay's stream-registry version differs from the build's**: the replay
  is refused, as a different `TICK_RATE` is (Simulation Tick & Pause, rule 14).
- **If the player reloads a mid-battle save after seeing a weapon miss**: the
  same weapon fired on the same tick misses again. Firing another weapon first
  changes nothing, because rolls are tick-indexed (Core Rules 3 and 11). Waiting
  a tick and firing again is a different action, and it gets a different roll.
  This system cannot stop repeated mid-battle reloads from being used that way;
  the mid-battle save policy decides whether defeat keeps its cost (Open
  Questions).

### Mods

- **If a mod is added mid-campaign**: its streams are created lazily on first
  draw, and base streams are unchanged (Core Rule 3).
- **If a mod declares a `base:` name**: Content Data & Mod Loading (#4) rejects
  the mod at load.
- **If two mods' stream names collide by hash**: both declarations are
  rejected at load, and the error names both mods. Both packages are refused,
  so the outcome never depends on load order (Content Data & Mod Loading, Core
  Rule 8).

### Runtime IDs

- **If a ship is destroyed and another spawns**: the new ship gets a new Runtime
  ID (never reused within a save, Core Rule 5), so it gets a fresh stream. The
  destroyed ship's stream is never drawn again; it stays saved and hashed until
  the battle ends.
- **If a ship from battle N fights in battle N + 1**: the same stream name
  under a new battle seed gives an unrelated sequence.

### Performance

- **If a tick exceeds `DRAW_BUDGET_PER_TICK`**: every draw still runs, and the
  overrun is logged with `tick_index`. Nothing in the simulation skips or
  throttles work because of the budget. Only the wall-time cap (Simulation Tick
  & Pause, rule 8) slows the game, and the overrun shows in the spike report
  (D8).

### Presentation and tools

- **If a Debrief replay runs while campaign state is live**: it uses an isolated
  instance of this system and shares no handles with the live game.
- **If the dev overlay displays streams**: it shows names and draw counts only,
  never a next value (Core Rule 6: no peek).

### Truth seeding

- **If a new game is aborted before its first save**: the seed and the truth are
  discarded, and the next new game draws fresh entropy. This is a new
  campaign, not a re-roll of a save (Pillar 2).
- **If a `base:truth.*` stream is drawn after the new-game step**: the draw is
  refused like an undeclared draw. Truth Seeding (#16) declares these streams
  as new-game-only.

*Specialist consulted: `systems-designer`. It flagged six conflicts with the
earlier draft, all resolved:*
- *Ship AI and Fleet Coordination shared one tie-break stream; each now has its
  own (Core Rule 5).*
- *D3 did not say `n > 2^31` is an error.*
- *`shuffle` gave −1 calls for an empty list.*
- *Stream renames were ambiguous between restore and fast-forward; a load now
  always restores (Core Rule 10).*
- *Keys had no grammar (Core Rule 4).*
- *Per-weapon streams let a reload "burn" a known roll. **Owner decision
  (2026-10-29):** battle streams are tick-indexed (Core Rule 3).*

*Still open: whether a deferred catch-up event can start a battle, and whether a
mid-battle refit can change a weapon slot (Open Questions).*

## Dependencies

### Upstream (what this system needs)

**Hard dependencies: none.** The generator, the derivation, the draw calls and
the registry work with nothing else designed. That is why the system sits in
the Foundation layer.

**Interface contracts** (soft). Each is data handed in, never a call back into
another system's logic:

| System | Hard / soft | Interface | Notes |
|---|---|---|---|
| Simulation Tick & Pause (#1) | Soft (data handed in) | Context (`BATTLE`/`CAMPAIGN`), the current phase, `tick_index` and `battle_start_tick` | Needed for tick-indexed battle streams (Core Rule 3) and the draw rules (Core Rule 6). Tick owns phase order and `state_hash`; this system supplies stream states to it |
| Runtime ID Service (#3) | Soft, but **required for keyed streams** | Runtime IDs as stream keys, and the guarantee that **no ID is reused within a save** | Without it, keyed streams cannot be used. A reused ID would replay a destroyed ship's sequence |
| Content Data & Mod Loading (#4) | Soft | Mod namespaces; streams declared by mods; permille and weight tables to validate | #4 enforces namespaces; this system validates names, permille values and weights |
| Save/Load & Migration (#5) | Soft (reverse) | This system *provides* its section: master seed, `battle_ordinal`, battle seed, stream records, registry version | Save owns the format, integer-safe encoding and rename migration |
| World Clock (#8) | Soft | The catch-up order for campaign events deferred from a battle | Provisional contract (Open Questions) |

### Downstream (what depends on this system)

**Listed in the systems index:**

| System | Hard / soft | What it relies on |
|---|---|---|
| Weapons & Damage (#12) | Hard | `base:combat.hit#<ship_id>/<weapon_slot>`; `chance_permille`; permille hit odds shown exactly (D4). **Must declare and surface its hit odds** (UI Requirements 2) |
| Truth Seeding & Candidates (#16) | Hard | `base:truth.*` streams, drawn at new game only; `weighted_pick` or `int_range` for the true maker |
| Ship AI (#20) | Hard | `base:ai.tiebreak#<ship_id>`; the tie-break ranking rule (Core Rule 7) |
| AI-vs-AI Runner & AI Debug Tools (#25) | Hard | Injected battle seeds; battles that replay from a battle seed alone (Core Rule 2); per-stream draw counts for divergence diagnosis |
| Exposure & Rival Investigation (#32) | Hard | Campaign streams (for example `base:rivals.search`); the deferred-draw rule during battles |
| Contracts & Missions (#38) | Hard | Campaign streams; `weighted_pick`. **Must declare and surface its offer odds** (UI Requirements 2) |
| Loot & Crafting (#39) | Hard | Campaign streams; `weighted_pick` with integer weights validated at load. **Must declare and surface its drop odds** (UI Requirements 2) |

**Not yet listed in the index.** Each needs this system in its own
Dependencies, and the index should list it at the next update:

| System | Hard / soft | What it relies on |
|---|---|---|
| Fleet Coordination (#21) | Hard | `base:fleet.tiebreak#<fleet_id>` |
| Combat Event Bus & Battle Record (#9) | Soft | The battle seed and registry version for the record header |
| After-Action Debrief (#24) | Soft | The battle seed for replay; an isolated instance for replays (Edge Cases). **Cites the odds next to the counter** when a roll is part of a loss's cause, and never names "bad luck" (UI Requirements 2) |
| Sector Map & Travel (#26), Tier 1 procedural generation | Hard (Tier 1) | Campaign streams for seeded, deterministic generation |
| Telemetry & Playtest Logging (#54) | Soft | The master seed in the bug-report bundle (Core Rule 8) |

**Presentation (#45 Camera, #46 HUD, #52 Audio) does not depend on this
system.** It uses its own cosmetic generators (Core Rule 9).

**Bidirectional check:**
- The only other existing GDD is Simulation Tick & Pause. Its Interactions table
  lists this system (#2) and gives `tick_index` "for stream bookkeeping", and
  its rule 14 puts RNG stream states into `state_hash`. That matches.
- Its row should also name `battle_start_tick` and the context, which this
  system now reads (Core Rule 3). Flag this for the Tick GDD's re-review.
- Every system above must list Deterministic RNG & Seed Streams in its own
  Dependencies when it is designed.

## Tuning Knobs

**This system owns no gameplay tuning knobs.** Randomness that a designer
tunes is a value in the *consumer's* data, validated here:
- hit odds as permille (Weapons & Damage #12);
- loot and mission weights (Loot & Crafting #39, Contracts & Missions #38);
- AI utility weights (Ship AI #20).

A knob here would let a designer change every consumer's results at once,
which is exactly what Core Rule 3 forbids.

### Engineering constants (versioned; not tuning knobs)

Changing any of these changes stream outputs or the save format. Each change is
a versioned, replay-breaking change, recorded with the stream-registry version.

| Constant | Value | Why it is fixed |
|---|---|---|
| Generator algorithm and derivation hash H | PCG32 plus FNV-1a 64 and SplitMix64, recommended (ADR decides) | Defines every stream's output (D1) |
| `NAME_MAX_BYTES` | 64 | Bounds stream names and keyed patterns (D1) |
| Probability unit | permille (0–1000) | All outcome-deciding odds are integer permille (D4) |
| `int_range` limits | `n ≤ 2^31`; bounds within ±2^62 | Unbiased rejection and no signed overflow (D3) |
| `weighted_pick` limits | Weights 0 – 2^31, total 1 – 2^31, up to 2^16 entries | Keeps D5 within D3 (D5) |
| Battle-seed collision range | Ordinals 1 – 65,536 checked | Registry check against campaign names (D2) |
| `RNG_SHARE` | 0.15 (**provisional**) | This system's share of the per-tick pass line. Needs technical-director sign-off (D8) |
| `DRAW_BUDGET_PER_TICK` | Set from the tick-rate spike (**provisional**) | A measurement target, never a throttle (D8, Edge Cases) |
| `RNG_SAVE_CEILING_KB` | 64 (**provisional**) | Ceiling on the RNG section of a mid-battle save at the D10 fixture (D7, AC-41) |
| Stream-registry version | Starts at 1 | Bumped on any rename, removal or derivation change. Written into saves and Battle Record headers |

**Knobs owned elsewhere** (referenced, not duplicated):
- hit odds (Weapons & Damage #12)
- loot, mission and offer weights (#39, #38)
- the true-maker candidate set and any weighting of it (Truth Seeding #16)
- AI utility weights (Ship AI #20)

## Visual/Audio Requirements

**None of its own.** The system has no art or sound. It sets one rule for
visuals and audio:
- **Cosmetic randomness never comes from a simulation stream** (Core Rule 9).
  VFX jitter, debris scatter, camera shake, audio pitch and sample variation use
  presentation-owned generators.
- The **outcome** a visual shows (a hit or a miss, the loot that drops) comes
  from the simulation. Only its look varies cosmetically, so two viewings of a
  replay show the same results, though sparks may scatter differently.

*`art-director` and `audio-director` were not consulted: Visual/Audio is
optional for `Core` systems, and this system has no visual or audio surface.*

## Game Feel

**Not applicable.** The player never operates this system directly. Its feel
contribution is indirect, and it is already fixed by the rules: odds shown
exactly (D4), no hidden reaction to reloads (Core Rule 11), and outcomes that
replay identically (Core Rules 2 and 3).

## UI Requirements

This system contributes three small things. None is a screen of its own.

1. **The reload statement** (Core Rule 11). One plain line, string key
   `ui.rng.reload_statement`, telling the player that loading returns them to
   the moment but does not change what the moment holds.
   - `narrative-director` owns the wording, in the archival tone of the Player
     Fantasy. It must never say "luck", "fate", "RNG", "dice" or "roll" (AC-42).
   - The UX spec chooses its screen and timing: for example the load screen,
     shown the first time the player loads a save (Open Questions).
2. **Odds are always surfaced (a contract on every consumer).**
   - Every stream whose draws decide an outcome (a `chance_permille` or
     `weighted_pick` that changes a hit, a drop, an offer or a result) must
     **surface its odds to the player before the outcome matters**, in the
     Dossier, the Ledger, the combat HUD, or the consumer's own screen.
   - Each such stream declares its odds surface in the stream registry
     (`odds_surface`). A stream with no declaration fails CI (AC-43). Streams
     whose draws are not outcome-deciding (AI tie-breaks, spread angles)
     declare `odds_surface: none` with a reason.
   - The odds are shown as `p / 10` percent to one decimal place ("65.0%"),
     never as a rounded float (D4).
   - **The Debrief cites the odds** next to the counter whenever a roll is part
     of a loss's cause. It never names "bad luck" as a cause (Player Fantasy;
     Pillar 1).
3. **Developer-only surfaces.**
   - The **bug-report bundle** includes the master seed, the current battle
     seed, and the stream-registry version, as 16-character hex (Core Rule 8).
   - The **dev debug overlay** lists live streams with names and draw counts
     only, never a next value (Core Rule 6).
   - Neither appears in a release build's normal UI.

> **📌 UX Flag — Deterministic RNG & Seed Streams**: this system has UI
> requirements: the reload statement, and the shared odds-display format. In
> Phase 4 (Pre-Production), run `/ux-design` for the load/save flow before
> writing epics, and decide where the statement appears. Stories that reference
> this UI should cite `design/ux/[screen].md`, not this GDD.

## Cross-References

| This GDD references | Document | Section | What is relied on |
|---|---|---|---|
| Pillar 2, *The Truth Is Yours to Tell* | `design/gdd/game-concept.md` | Game Pillars | "The truth about who built the machines is fixed"; one hidden truth seeded per save |
| Pillar 1 and the pillar tensions | `design/gdd/game-concept.md` | Game Pillars; Anti-Pillars | Defeats explainable; what follows "obeys no hidden rule and is legible after the fact" |
| Tier 0 boundary test | `design/gdd/systems-index.md` | Technical Director Note | "The headless runner reproduces the same battle twice from one seed" (AC-34, AC-37) |
| System role and consumers | `design/gdd/systems-index.md` | Overview; Systems Enumeration | Named streams per consumer derived from the save seed; consumers #12, #16, #20, #25, #32, #38, #39 |
| Phase order, ascending Runtime ID | `design/gdd/simulation-tick-and-pause.md` | Core Rules, rule 3 | The order in which battle streams are drawn (Core Rule 6) |
| `tick_index`, `battle_start_tick` | `design/gdd/simulation-tick-and-pause.md` | Core Rules, rule 1 | `battle_tick` for tick-indexed battle streams (Core Rule 3, D1) |
| `state_hash`, header, platform scope | `design/gdd/simulation-tick-and-pause.md` | Core Rules, rule 14; AC-53 | Stream states hashed in name order; integers above 2^53 never JSON numbers; same-platform verification |
| Engine RNG ban and lint | `design/gdd/simulation-tick-and-pause.md` | Acceptance Criteria, AC-34 | Engine random calls banned in simulation code |
| Per-tick pass line `L` | `design/gdd/simulation-tick-and-pause.md` | Formulas, D10 | The budget `RNG_SHARE` takes its share from (D8) |
| Saves at tick boundaries | `design/gdd/simulation-tick-and-pause.md` | Core Rules, rule 17 | Battle streams carry no state at a boundary (Core Rule 10) |
| Generator choice | `design/gdd/simulation-tick-and-pause.md` | Open Questions, row 4 | "Our own small PRNG vs pinning `RandomNumberGenerator`", handed to the ADR |
| Engine facts | `docs/engine-reference/godot/` | `breaking-changes.md` (4.7.2 `rand_weighted`) | Negative weights rejected. Everything else about the engine's RNG, integers, hashing and JSON is NOT SOURCEABLE (no `modules/core.md`) |

No other system GDD exists yet. Each system in Dependencies → Downstream must
cross-reference this GDD when it is written.

## Acceptance Criteria

**How tests stay isolated.** No criterion reads OS entropy or the wall clock.
The fixtures:
- **`FakeEntropySource`** returns a scripted 64-bit master seed and counts its
  calls.
- **`ScriptedWordSource`** stands in for `next_u32()` with a scripted word list,
  so D3–D6 known-answer tests choose their own draws.
- **`StubNameHash`** is injected in place of `FNV1a64`, so collision tests can
  force a collision without searching for a real one.
- **`RefusalMode`** (`DEBUG` / `RELEASE`) is injected, so both refusal behaviours
  run in one build.
- **`RngFixtures`** holds the pinned seeds `M_FIX` and `B_FIX` and the stream
  names. No magic numbers appear inline, except boundary values where the exact
  number is the point of the test.
- **`state_hash(SimState)`** is Simulation Tick & Pause rule 14; its AC-53 proves
  it can fail.

Unit tests do no file I/O: saves round-trip through an in-memory buffer, and
golden tables load only in integration tests. Test files are named
`rng_[feature]_test.gd`, and functions `test_[scenario]_[expected]`. Every
expected value is an integer or an exact power-of-two float, compared with `==`,
never approximately.

### Logic: unit tests, `tests/unit/rng/` (BLOCKING)

- **AC-01 (D1, known answers)**: **GIVEN** the reference implementations,
  **WHEN** the hash and the generators run, **THEN**:
  - `FNV1a64("") == 0xcbf29ce484222325`, `FNV1a64("a") == 0xaf63dc4c8601ec8c`
    and `FNV1a64("foobar") == 0x85944171f73967e8`;
  - PCG32 seeded with `(initstate 42, initseq 54)` returns `0xa15c02b7`,
    `0x7b47f409`, `0xba1d3330`, `0x83d2f293`, `0xbfa4784b`, `0xcbed606e`;
  - the full SplitMix64 step from state 0 returns `0xe220a8397b1dcdaf`.

  *These values were checked against independent reimplementations of the FNV
  spec, pcg-c and SplitMix64 (2026-10-29). If the ADR chooses a different
  generator, this AC is replaced by that generator's published vector.*
- **AC-02 (rule 3, D1)**: **GIVEN** `M_FIX`, **WHEN** streams A and B are
  registered as A then B in one run and B then A in another, **THEN** each
  stream's seed and its first 64 words are identical in both runs. Registering a
  stream that is never drawn leaves `state_hash` unchanged.
- **AC-03 (rule 2, D2)**: **GIVEN** `M_FIX` and `battle_ordinal = 6`, **WHEN** a
  battle starts, **THEN** the ordinal is 7 and
  `battle_seed == H(M_FIX, "base:battle" ‖ 07 00 00 00 00 00 00 00)`. **GIVEN** a
  reload of that save, **THEN** the next battle seed is identical. Ordinal 0
  never seeds a battle.
- **AC-04 (rule 3, independence)**: **GIVEN** streams X and Y, **WHEN** X makes
  one extra draw, **THEN** Y's next 1,000 words are unchanged.
- **AC-05 (rule 3, D1, tick-indexed)**: **GIVEN** weapon W's stream at
  `battle_tick = T`:
  - **WHEN** weapon V fires first on T, or W draws 5 extra times on T − 1,
    **THEN** W's first word on T is unchanged.
  - **WHEN** W fires on T + 1 instead, **THEN** it gets the word at position
    `(T + 1, 0)`.
  - `draw_index_in_tick` is 0 at every tick boundary.
- **AC-06 (rule 4)**: **GIVEN** the name grammar:
  - **THEN** `base:combat.hit#1042/3`, `base:combat.hit#1042/0` (slot 0),
    `mymod:raid.spawn` and `base:ai.tiebreak#1` are accepted;
  - **THEN** a draw on `base:ai.tiebreak#0` (Runtime ID 0, `NONE`) is refused
    as in AC-08;
  - **THEN** `base:combat.hit#01042`, `Base:x`, `base:combat.hit#` and any
    non-ASCII name are rejected;
  - **THEN** a key pattern whose longest name is 65 bytes is rejected when the
    registry loads, and a 64-byte one is accepted.
- **AC-07 (rule 4, D1, D2)**: **GIVEN** `StubNameHash`, **WHEN** the registry
  loads:
  - **THEN** a duplicate name is rejected;
  - **THEN** two names with equal hashes are both rejected, and the error names
    both;
  - **THEN** a campaign name whose hash equals that of `"base:battle" ‖ u64le(k)`
    is rejected, at `k = 1` and at `k = 65,536`;
  - **THEN** a keyed name that collides with a live stream when it is created is
    refused, as in AC-08.
- **AC-08 (rules 4, 7, refused draw)**: **GIVEN** an undeclared name:
  - **WHEN** each call type draws in `RefusalMode.RELEASE`, **THEN** 0 words are
    consumed, the results are `a` / false / 0.0 / no pick, and one error is
    logged per call;
  - **WHEN** the same draws run in `DEBUG`, **THEN** each is a hard error.
- **AC-09 (rule 5)**: **GIVEN** a battle with ships {3, 8}, **WHEN** it is re-run
  with ship 12 added, **THEN** ship 3's and ship 8's hit sequences are identical
  in both runs, slot by slot and tick by tick.
- **AC-10 (rule 6)**: **GIVEN** a fixture battle state, **WHEN** an odds preview,
  a presentation frame, a save, a load and `state_hash` run in turn, **THEN**
  every stream's draw count and state are unchanged. **GIVEN** the stream
  handle's public methods, **THEN** none of them peeks, skips, re-seeds or
  returns the seed.
- **AC-11 (rule 6)**: **GIVEN** `BATTLE`:
  - **WHEN** a campaign stream is drawn, **THEN** the draw is refused;
  - **WHEN** a stub World Clock event falls due mid-battle, **THEN** it makes no
    draw until battle end, then draws in catch-up order;
  - **WHEN** a save is requested during catch-up, **THEN** it waits until
    catch-up ends.
- **AC-12 (rule 6)**: **GIVEN** a handle held across a load, **WHEN** it draws,
  **THEN** it returns the restored stream's next word.
- **AC-13 (D3)**: **GIVEN** `ScriptedWordSource`:
  - **WHEN** `int_range(1, 6)` runs on `[4,000,000,123]`, **THEN** it returns 2,
    using 1 word;
  - **WHEN** `int_range(0, 999)` runs on `[200, 123,456,789]`, **THEN** it
    returns 789, using 2 words;
  - **WHEN** `int_range(5, 5)` runs, **THEN** it returns 5, using 1 word;
  - **GIVEN** `n = 1,431,655,766`, **THEN** the threshold is 1,431,655,764: word
    1,431,655,763 is rejected and word 1,431,655,764 is accepted;
  - **GIVEN** a source that rejects 3 times in a row, **THEN** the call takes the
    4th word (there is no iteration cap);
  - **THEN** `a > b`, `n = 2^31 + 1` and a bound of `2^62 + 1` are each an error.
- **AC-14 (D3, exact uniformity)**: **GIVEN** `n` in {1, 2, 3, 6, 7, 1000,
  2^31 − 1, 2^31, 1,431,655,766}, **THEN** `(2^32 − threshold) mod n == 0`, and
  `threshold == 0` exactly when `n` is a power of two.
- **AC-15 (rule 7, D4)**: **GIVEN** scripted draws:
  - **THEN** `p = 0` is false and `p = 1000` is true, each using exactly one
    `int_range` call;
  - **THEN** with `p = 650`, the draw 649 gives true, and 650 and 789 give false;
  - **THEN** `p = −1` and `p = 1001` assert;
  - **THEN** the display formatter shows "65.0%" for 650, "0.1%" for 1 and
    "100.0%" for 1000.
- **AC-16 (rule 7, D5)**: **GIVEN** `[(gamma, 5), (alpha, 3), (beta, 0)]`,
  authored in that order:
  - **THEN** it is sorted to alpha, beta, gamma;
  - **THEN** `r` from 0 to 2 picks alpha, `r` from 3 to 7 picks gamma, and beta is
    never picked;
  - **THEN** a one-entry table uses 1 call, and an empty table returns no pick
    using 0 words;
  - **THEN** a negative weight, a total of 0, a total of `2^31 + 1`, a duplicate
    `stable_id` and a `Dictionary` table are each rejected at load.
- **AC-17 (rule 7, D6)**: **GIVEN** the words `(0x80000000, 0)`, **THEN**
  `unit_float() == 0.5`. `(0, 0)` gives `0.0`, and all-ones gives
  `(2^53 − 1) / 2^53`, which is `< 1.0`. Every call uses exactly 2 words.
- **AC-18 (rule 7, shuffle)**: **GIVEN** lists of 0, 1, 2, 5 and 100 items,
  **THEN** the call counts are 0, 0, 1, 4 and 99, and scripted `int_range`
  results give the expected permutation exactly.
- **AC-19 (rule 7, AI tie-breaks)**:
  - **GIVEN** 3 actors over 10 ticks, with and without ties, **THEN** each actor
    makes exactly one tie-break draw per tick;
  - **GIVEN** a tied pair, **WHEN** an unrelated candidate is added, **THEN** the
    same candidate wins;
  - **GIVEN** a ship disabled on tick T, **THEN** it makes no draw on T, and its
    draws on T + 1 onward are unchanged.
- **AC-20 (rule 8)**: **GIVEN** a new game, **THEN** `FakeEntropySource` is called
  exactly once, and a load calls it 0 times. The bug-report bundle and the debug
  overlay model contain the seed as 16-character hex, and no other view model
  contains that string.
- **AC-21 (rule 10, saves)**: **GIVEN** a mid-battle save:
  - **THEN** only streams that have been drawn are present;
  - **THEN** each campaign record holds its name, state and count, and each
    battle record holds its name and count;
  - **THEN** every 64-bit value is 16-character lowercase hex, never a JSON
    number.
- **AC-22 (rule 10, hash)**: **GIVEN** the same streams created in two different
  orders, **THEN** the hashes are equal. **WHEN** one stream's state or count
  changes, or the battle seed changes in `BATTLE`, **THEN** the hash changes.
- **AC-23 (edge: malformed or missing records)**:
  - **GIVEN** in turn a bad name, non-hex, 15-character hex, a draw count of
    `2^63`, and a duplicate name, **THEN** the whole load is refused, the error
    names the stream, and nothing is restored;
  - **GIVEN** a declared stream missing from the save, **THEN** it starts at
    position 0;
  - **GIVEN** a record for a stream that is no longer declared, **THEN** it is
    never drawn, is re-saved byte-identical, and stays in `state_hash`.
- **AC-24 (edge: battle contexts)**:
  - **GIVEN** a live battle, **WHEN** a second `BATTLE` starts, **THEN** it is an
    error;
  - **GIVEN** a battle that ends on its first tick, **THEN** its ordinal is used
    up;
  - **GIVEN** an injected battle seed, **THEN** `battle_ordinal` is neither read
    nor written, and the header records ordinal 0;
  - **GIVEN** a `base:truth.*` draw after the new-game step, **THEN** it is
    refused.
- **AC-25 (edge: performance overrun)**: **GIVEN** `DRAW_BUDGET_PER_TICK = 10` and
  a tick that needs 15 draws, **THEN** all 15 draws run, one overrun is logged
  with `tick_index`, and the results equal those of an unbudgeted run.
- **AC-26 (edge: zero seeds)**: **GIVEN** master seed 0 or battle seed 0, **THEN**
  derivation equals the golden values (AC-38), and no two registered streams
  share a seed.

### Engine-behaviour probes: `tests/unit/rng/rng_engine_probe_test.gd` (BLOCKING)

These behaviours are **NOT SOURCEABLE** in `docs/engine-reference/godot/` (there
is no `modules/core.md`). The probes make an engine upgrade that changes them
fail loudly instead of silently changing every stream.

- **AC-27 (int wrap)**: **GIVEN** `MAX = (1 << 62) − 1 + (1 << 62)`, **THEN**
  `MAX + 1 == 1 << 63`, and `1 << 63` is negative. A PCG multiply step's product
  equals the reference implementation's low 64 bits, held in the fixture.
- **AC-28 (shifts)**: **THEN** `−8 >> 1 == −4` and `−1 >> 63 == −1`, so the engine
  shift is arithmetic. The project's logical shift gives
  `lsr(−1, 32) == 4294967295` and `lsr(1 << 63, 63) == 1`, and its unsigned
  compare gives `ult(0, −1) == true`.
- **AC-29 (int to float)**: **THEN** `int(float(2^53 − 1)) == 2^53 − 1`, and
  `float(2^53 + 1) == float(2^53)`, which shows where exactness ends. D6's largest
  numerator converts exactly.
- **AC-30 (hex round trip)**: **GIVEN** 0, −1, `2^63 − 1` and `−2^63` (built as
  `1 << 63`), **THEN** the codec writes `0000000000000000`, `ffffffffffffffff`,
  `7fffffffffffffff` and `8000000000000000`, and decodes each back to the same
  `int`. The engine's own hex parse is called on the same strings and its result
  is recorded as an observation. If it does not round-trip, the codec must not
  use it.

### Static checks, CI lint (BLOCKING)

- **AC-31 (rules 1, 9)**: **GIVEN** `src/sim/**`, **including the RNG system**,
  **WHEN** CI lints it, **THEN** it fails on any reference to a presentation or
  cosmetic generator, or to the engine RNG calls listed in Simulation Tick &
  Pause AC-34. (That AC excludes the RNG system from its scan; this one does not,
  because Core Rule 7's helpers must not use the engine calls either.)
- **AC-32 (rules 6, 9)**: **GIVEN** presentation and UI code, **THEN** the lint
  fails on any reference to a simulation stream handle or the stream registry,
  and on a name-string lookup at a call site.
- **AC-33 (rules 4, 6, 8)**: **THEN** the lint fails on:
  - a stream name absent from the registry;
  - a draw on another system's stream;
  - a write to the master seed outside the driver and Save/Load.

  **Shown to fail:** one planted violation per item lives in
  `tests/fixtures/lint/rng/bad_<item>.gd`: `bad_sim_calls_cosmetic`,
  `bad_rng_uses_engine_rand`, `bad_presentation_draws_sim`,
  `bad_callsite_name_lookup`, `bad_undeclared_stream`, `bad_foreign_stream` and
  `bad_sets_master_seed`. CI must exit non-zero on every fixture, and exit 0 on
  the production scan, which excludes the fixtures.

### Integration: `tests/integration/rng/` (BLOCKING)

- **AC-34 (Tick, `state_hash`)**: **GIVEN** a battle, **WHEN** the headless runner
  plays it twice, **THEN** the per-tick `state_hash` sequences are identical.
  **WHEN** one extra draw is planted at tick T, **THEN** the sequences first
  diverge at T.
- **AC-35 (Save/Load round trip)**: **GIVEN** a campaign save and a mid-battle
  save at tick T, **WHEN** each is loaded and run to T + 600, **THEN** the hashes
  equal those of an uninterrupted run, and re-saving at T gives byte-identical
  stream records.
- **AC-36 (battle replay from the seed alone)**: **GIVEN** only the Battle Record
  header's seed and registry version, plus the command log, **WHEN** an isolated
  instance with no campaign replays the battle, **THEN** the hashes match the
  original, and a live game's streams are unchanged during the replay. A
  registry-version mismatch is refused.
- **AC-37 (runner injection, rule 2)**:
  - **GIVEN** `B_FIX` injected twice, **THEN** the two runs are identical, and a
    different seed gives a different run;
  - **GIVEN** 50 extra campaign draws before a battle, **THEN** the battle's
    hashes are unchanged;
  - **GIVEN** two different battle command logs, **THEN** the campaign stream
    states after the battle are identical.
- **AC-38 (golden tables, rule 12)**: **GIVEN** `tests/fixtures/rng/<stream>.golden`,
  one per registered stream, **THEN**:
  - campaign streams match their first 16 words under `M_FIX`;
  - battle streams match their first 16 words under `B_FIX` at `battle_tick` 0,
    1 and 1000;
  - a golden table that changes without a registry-version bump fails CI;
  - loading a fixture mod changes no base golden table;
  - each shipped platform's build passes the same tables.
- **AC-39 (rules 10, 11, reload)**:
  - **GIVEN** a mid-battle save, **WHEN** the same weapon fires on the same tick
    after 0 reloads and after 5 reloads, **THEN** the outcomes are identical;
  - **WHEN** it fires one tick later, **THEN** it uses that tick's roll;
  - **GIVEN** an old-registry save with a renamed stream, **WHEN** it is migrated,
    **THEN** it continues the same sequence.

### Performance: `tests/performance/rng/` (BLOCKING for the GDExtension decision)

- **AC-40 (D8)**: **GIVEN** a headless run on the ADR's reference machine, **WHEN**
  the tick-rate spike runs, **THEN** the report records:
  - p95 `t_draw` for `int_range`, `chance_permille`, `unit_float`, a stream's
    first draw in a tick, and a stream's first draw ever;
  - p95 and maximum `draws_per_tick` on Simulation Tick & Pause D10's steady
    scene, its worst-case scenes and a full-broadside volley;
  - the machine and the build.

  It **FAILS** if `rng_ms > RNG_SHARE × L` on any scene, and a fail triggers the
  GDExtension fallback. While `RNG_SHARE` is provisional, a pass reports
  `PROVISIONAL`, not `PASS`.
- **AC-41 (D7)**: **GIVEN** 100 ships × 6 slots and 4 fleets, **THEN**
  `S_live == 724`, and the RNG section of a mid-battle save is at most
  `RNG_SAVE_CEILING_KB` (64 KB). The measured size is recorded.

- **AC-43 (UI Requirements 2, odds contract)**: **GIVEN** the stream registry,
  **WHEN** CI checks it, **THEN** every declared stream has an `odds_surface`
  value, and every `odds_surface: none` carries a reason. **Shown to fail:** the
  fixture `tests/fixtures/lint/rng/bad_missing_odds_surface.gd` declares a stream
  without one, and CI must exit non-zero on it. **GIVEN** a bug-report bundle
  built from a fixture save, **THEN** it contains the master seed and no
  readable `base:truth.*` result (Core Rule 8).

### UI: manual, retained screenshot in `production/qa/evidence/rng/` (BLOCKING)

- **AC-42 (rule 11)**: **GIVEN** the string key `ui.rng.reload_statement`,
  **THEN** it exists in the string table and is not empty, and an automated
  check confirms it contains none of "luck", "fate", "RNG", "dice" or "roll".
  **WHEN** the screen that hosts it (set by the UX spec) is opened, **THEN** the
  statement is visible, and a retained screenshot is filed.

*Specialist consulted: `qa-lead`. It flagged nine rules as not testable as
written. The fixes:*
- *Rules 1, 11 and 12 were reworded against lints, `AC-39` and golden tables.*
- *The refusal mode and the name hash are injectable (rule 7).*
- *The tie-break mixing function is pinned by the ADR (rule 7).*
- *D7 has a 64 KB ceiling.*
- *The "full period" loop guarantee is a proof, so it goes to the ADR.*

*It also caught a Player Fantasy line that contradicted rule 3, and that the
bare SplitMix64 finaliser maps 0 to 0. D1 now names the full step. All four
of its conflicts are resolved.*

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Deferred campaign draws.** Campaign streams are not drawn during a battle; events due mid-battle draw at battle end in catch-up order (Core Rule 6). Does the World Clock queue them, in what order, and does any campaign system *need* to act inside a battle? This contract is provisional. | World Clock (#8), Exposure & Rival Investigation (#32) | When #8 is designed |
| 2 | **Can a deferred catch-up event start a battle?** If so, do the remaining deferred events finish first, or wait until after that battle? | World Clock (#8) | When #8 is designed |
| 3 | **Can a mid-battle refit change the weapon in a slot?** If yes, the new weapon inherits the slot's stream `base:combat.hit#<ship_id>/<slot>` (Core Rule 5). If slots can be added, their keys must stay stable. | Weapons & Damage (#12), Refit & Loadout (#35) | When #12 is designed |
| 4 | **Generator, derivation and encoding.** Own PCG32 or pinned `RandomNumberGenerator`; FNV-1a 64 plus SplitMix64 for H; the tick-indexed construction (D1); the tie-break mixing function; unsigned 64-bit maths on signed `int`; the hex codec. All engine facts are NOT SOURCEABLE; the AC-27–AC-30 probes settle them. | technical-director | Tick/Pause/Determinism ADR (Simulation Tick & Pause, Open Question 4) |
| 5 | **Is `RNG_SHARE = 0.15` signed off, and is GDScript fast enough?** If the spike's `t_draw` breaks the budget on a volley tick (D8), a GDExtension generator is the fallback, which changes the build. | technical-director, engine-programmer, devops-engineer | Tick-rate spike |
| 6 | **Where and when does the reload statement appear?** For example the load screen, on the first load. And who confirms its wording? | UX spec (`/ux-design`), `narrative-director` | Phase 4, before epics |
| 7 | **A player-chosen seed after MVP?** A custom-game seed that excludes the truth streams (so the maker stays unknowable) could support shared challenge runs without breaking Pillar 2. | creative-director | Post-MVP |
| 8 | **Cross-platform golden tables.** MVP verifies on one platform. Add CI runs of AC-38 on every shipped platform post-MVP (ties to Simulation Tick & Pause Open Question 7). | technical-director | Post-MVP |
| 9 | **Mid-battle save policy.** Tick-indexed rolls stop a reload from "burning" a known roll, but repeated mid-battle reloads let a player try the same moment again one tick later. Should mid-battle saves exist only to suspend the game (deleted on load), or as a checkpoint at battle start, so that defeat keeps its time and resource cost (Pillar 1)? | Save/Load & Migration (#5), creative-director | When #5 is designed |
