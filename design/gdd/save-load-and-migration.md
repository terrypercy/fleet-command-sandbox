# Save/Load & Migration

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on Summary wording, the unstated battle-start retry risk, and the mid-battle crash promise; all three revised
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — defeat costs time or resources, never the run, and the save policy keeps that true); Pillar 2 (The Truth Is Yours to Tell — one fixed truth per save, kept intact across every save, load and update)

## Summary

Save/Load & Migration writes a whole campaign to one file per slot and reads it
back exactly. Every stateful system writes its own versioned section, so an
older save is carried forward into a newer build, and the player is told
before anything is lost. Writing a save can never damage the previous one.
Outside battle, saving is free. In battle there is only a suspend save, so
leaving costs nothing. Rolls are tied to the tick, so replaying a battle, from
its start or after a crash, gives the same result unless the plan changes
(Pillars 1 and 2).

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Deterministic RNG & Seed Streams, Runtime ID Service, Content Data & Mod Loading`

## Overview

Save/Load & Migration is the framework that writes a campaign to disk and reads
it back exactly. It is not one big save routine. **Every stateful system
registers its own versioned save section** (the systems index's contract), and
this system orchestrates them:
- it writes all sections together, at a tick boundary, into one file;
- it reads them back in a fixed order, validating each, with the Runtime ID
  section first;
- when a save is older than the game, it migrates each section forward through
  that section's own registered migrations.

A save is plain data: a versioned document of primitive values, content IDs
and Runtime IDs. It never contains engine objects, node trees, scripts or
resource paths (concept: "never save node trees").

Every save carries a **header** that says exactly what made it: the save format
version, the game build, the engine version, the OS and CPU architecture, the
tick rate, and the loaded content (the package list and content hashes). The
header lets the game decide, before reading anything else, whether the save can
load as-is, needs migration, needs the player's confirmation, or must be
refused (Simulation Tick & Pause, rule 14; Content Data & Mod Loading, Core Rule
13).

The player never sees sections or headers. They feel what this system
guarantees:
- **A save brings back the same galaxy.** The same ships, the same fragment in
  the hold, the same rival on the trail, and the same hidden truth, exactly
  where they left it.
- **Updates never cost a campaign.** An older save opens in a newer build,
  migrated forward. When something cannot be carried over, the game says what
  and why, before anything is lost.
- **Nothing is ever half-written.** A crash, a full disk or a power cut during a
  save never corrupts the previous save.

Without this system three things would break:
- Every stateful system would invent its own file format and versioning, and an
  update to any one of them could silently break every existing save.
- The determinism the rest of the game is built on (Simulation Tick & Pause,
  rule 14) would not survive a save and a load, because nothing would guarantee
  that state comes back bit-for-bit, in a fixed order.
- A long campaign, the "defeat costs time or resources, never the run" promise
  (Pillar 1), and the one truth per save (Pillar 2) would all depend on luck.

*How* saves are encoded and written (the file format, compression, the atomic
write, the section registry's data structure) is an implementation choice →
**becomes the save schema ADR** named in the concept's suggested ADRs. This GDD
specifies behaviour, guarantees and contracts only.

## Player Fantasy

**Put the war down; it waits for you.** The player experiences this system
**indirectly**. What they feel is that the game never has to be finished in one
sitting, and never takes a campaign away from them.

The player can walk away at any moment, even mid-volley, and come back to find
the campaign just as they left it: the half-turned flank, the queued orders, the
rival two systems out. An update, a crash or a power cut never takes the campaign
from them; a crash mid-battle costs at most a couple of minutes, never the
campaign. When a new build changes something their save depended on, the game
names the one thing that changed, before anything is carried over, and then the
campaign opens.

*Anchor moment:* the machine line is closing, and the player has to leave. They
quit. Days later, after a patch, they load. The battle is paused on the same tick
with the same orders queued, and a single line explains the one thing the update
changed.

**Pillars served:**
- **Pillar 1, *Every Defeat Is a Lead*:** "defeat costs time or resources, never
  the run." Leaving costs nothing, and a crash or an update never costs the run.
  A defeat is answered by the Debrief and a return attempt, not by reloading the
  same moment (the battle save policy, Detailed Design). A battle can be retried
  from its start, but rolls repeat, so only a changed plan changes the outcome:
  retrying is how the lead gets used. The cost of a defeat that is kept belongs
  to the Debrief and campaign systems, not to save policy.
- **Pillar 2, *The Truth Is Yours to Tell*:** one fixed truth per save, carried
  intact through every save, load and update.
- **The pillar-tension resolution:** "challenge should feel relaxing." Pause stops
  the battle; this system lets the player stop the game itself.

**Tone:** patient and dependable. The verbs are *waits, keeps, carries,
resumes*.

**This system must never make the player feel:**
- **"I lost hours because the game crashed, or because I updated."**
- **"My campaign was quietly changed under me."** Every migration loss is named,
  and confirmed by the player, before it happens.

*Shaped by `creative-director` (framing A, "Put the war down; it waits for you").
Framing B, "Your campaign outlives every update", was judged too narrow; its
migration beat lives in the paragraph above.*

## Detailed Design

### Core Rules

**A. What a save is**

1. **One campaign, one folder; one slot, one file.** Every campaign has a
   `campaign_id`: a random 128-bit value from OS entropy, never drawn from the
   seed streams (Deterministic RNG & Seed Streams). Its saves live under
   `user://saves/<campaign_id>/`, one self-contained file per slot. Nothing is
   ever written under `res://`, and no save ever spans two files. The game never
   quotes a real OS path to the player.
2. **Slot kinds.** Each campaign has:
   - `MANUAL_SLOTS` manual slots (20), saved and overwritten only by the player;
   - `AUTOSAVE_SLOTS` rotating autosaves (3), the oldest overwritten first;
   - one **battle-start** slot, overwritten at each battle start;
   - one **suspend** slot (rules 22–24).
   There is no quicksave at MVP. Save UI (#51) offers "save now" outside battle.
3. **A file is a header followed by sections.** The **header** is readable on
   its own, so the slot list never parses a section. It is capped at
   `HEADER_MAX` and holds:
   - `format_version`, `campaign_id`, `slot_kind`, `save_counter` (rises by 1
     with every save in the campaign), `saved_at_utc`;
   - the build, engine version, OS, CPU architecture and `TICK_RATE`
     (Simulation Tick & Pause, rule 14);
   - the package list with each package's version and content hash, plus the
     global content hash (Content Data & Mod Loading, Core Rule 13);
   - each section's ID, version, byte length and checksum;
   - the display meta: captain name, in-game day, location key, played
     seconds.
   Each **section** is one system's payload. Every 64-bit value in the file
   (Runtime IDs, RNG state, hashes) is written as a string, never as a bare
   number.
4. **A payload is plain data only.** Allowed: integers, strings, booleans,
   arrays, and string-keyed maps; content IDs as strings; Runtime IDs as
   integers. Forbidden: engine objects, nodes, resources, callables, node
   paths, resource paths, engine value types (stored as explicit integer or
   fixed-point fields instead), and raw floats anywhere in a payload.
   If a float cannot be avoided, its schema declares an explicit bit-pattern
   field and the value is stored as its exact bit pattern, never as decimal
   text, with -0.0 written as +0.0 and NaN or infinity refused (the
   same rule as Content Data D3). Saves never use an object-deserialising engine
   call or a resource load (rule 26).
5. **Canonical output.** Keys sorted by byte value, arrays in their stored order,
   collections keyed by Runtime ID written sorted by ID, sections written in
   registry order. Saving, loading and saving again produces byte-identical
   sections and a byte-identical header, except `save_counter`, `saved_at_utc`
   and the header checksum, which change with every save. Dictionary iteration order is never a source of order.
6. **A checksum detects accidental corruption, nothing more.** Each section and
   the header carry a checksum. It is never described, to players or in code, as
   tamper protection. Editing your own save is allowed: validation, not trust,
   is the defence (rules 25–28).

**B. The section registry**

7. **Every stateful system registers exactly one section** before the first save
   or load. A registration declares:
   - `section_id`: permanent and namespaced (`base:…` or the mod's package
     namespace), at most `NAME_MAX_BYTES` (64);
   - `version`: an integer, starting at 1;
   - `ceiling_bytes`: the most this section may ever write;
   - `loads_after`: the sections it must load after;
   - `required`: whether a save without it is refused;
   - `battle_part`: whether it writes extra state that exists only in battle
     (rule 22);
   - one migration per version step, N to N+1, with no gaps.
   The registry is built at startup and injected; it is never an autoload.
   A duplicate ID, a dependency cycle or a missing migration step stops the game
   at startup as a programmer error. Every member of the simulation state is
   tagged with the one section that owns it; a test walks the simulation state's
   members and fails if any member has no section or more than one. (A missing
   migration step is therefore caught at startup; the load-time refusal in rule
   16 is defence in depth.)
8. **A section owns its payload; Save/Load owns the envelope.** Save/Load never
   reads inside a payload. A section never reads another section's payload:
   links between systems go by ID only (Runtime ID Service, Core Rule 7), and
   cross-section checks happen in one pass after all sections load (rule 14).
9. **Writing a section is a pure function of the simulation state.** It issues
   no IDs, retires nothing, does no I/O and changes nothing (Runtime ID Service,
   Core Rule 11).
10. **Two kinds of version.** `format_version` covers the envelope only: the
    header layout, the section index, the encoding and the checksum scheme. A
    section's `version` covers its payload. Any added, removed, renamed,
    retyped or re-ranged field, or any change of meaning, raises the section
    version by exactly 1 and ships a migration and a test fixture together.
11. **A migration is a pure step on data.** It takes one version's payload and
    returns the next version's. It reads no clock, draws no random number,
    touches no live object and issues no IDs. A migration that needs new IDs
    declares the request, and Save/Load fulfils it after validation, before the
    first tick (Runtime ID Service, Core Rule 11). A migration that discards
    player-visible data must declare that loss; declared losses join the
    confirm summary (rule 15).
12. **Every version since 1.0 stays loadable.** Every format and section version
    made by a public release keeps its migration and its fixture forever.
    `MIN_SAVE_FORMAT` is the first public format. Dropping a version needs its
    own ADR and a named refusal that says which build can still open the save.

**C. Loading**

13. **Load order is fixed.** Header, then format check, then content comparison
    (and confirmation), then the Runtime ID section (validated per Runtime ID
    Service, Core Rule 11), then the remaining sections in dependency order,
    ties broken by `section_id` byte order. Registration order never matters.
14. **A load is all-or-nothing.** Stages, in order:
    1. probe: size and header limits (rule 25);
    2. decide the outcome from the header (rule 15);
    3. parse and validate each section against its own version's schema;
    4. migrate each section in memory, then validate the result against the
       current schema;
    5. build a fresh simulation state, Runtime ID table first, then each section
       in load order;
    6. one cross-reference pass: every Runtime ID a section refers to resolves,
       with the right kind, and `next_id` is above every ID seen;
    7. fulfil migration ID requests and content substitutions (Content Data,
       Core Rule 13), before tick 1;
    8. swap the fresh state in.
    Any failure at any stage refuses the load with a named reason (rule 16). The
    running game, and every file on disk, are left exactly as they were.
15. **Outcome from the header, in precedence order Refuse > Confirm > Migrate >
    Compatible.**
    - **Compatible**: current format, every section at its current version,
      identical content hashes. Loads silently.
    - **Migrate**: an older format or section version with a complete chain.
      Loads silently, unless a migration declares a loss.
    - **Confirm**: the content differs (Content Data, Core Rule 13's pre-load
      summary), or a migration declares a loss. One combined summary; Cancel
      changes nothing. A different build, OS or CPU architecture is an
      information line ("replays from this save may not verify") and never
      blocks.
    - **Refuse**: any rule-16 reason.
    Whether every migration chain exists is checked before the confirm summary
    is shown, so the player is never asked to accept a load that will then fail.
16. **Named refusals.** A save is refused, naming the reason, when: it is larger
    than `SAVE_MAX`; it fails a parse or limit check; a checksum fails (names the
    section); its format or any section is newer than this build (names the
    section); a migration step is missing (names the section and the two
    versions); it is older than `MIN_SAVE_FORMAT`; Runtime ID validation fails
    (names the ID); a required section is missing; a reference does not resolve
    (names section, field and ID); or it holds battle state (battle-start or
    suspend) at a different `TICK_RATE`, which cannot resume exactly.
17. **Unknown sections.** A section this build does not know is handled by its
    namespace:
    - namespace of a package that is not loaded (a missing mod): **carried
      untouched**, as opaque bytes, and rewritten byte-for-byte on the next save.
      All carried sections share one `OPAQUE_MAX` budget. Reinstalling the mod
      restores its state. The pre-load summary names the missing package.
    - `base:` or the namespace of a loaded package: corruption or a newer build;
      refused.
    - no valid namespace: refused.

**D. Saving**

18. **When a save may happen.** Only at a tick boundary, with no load, migration
    or other save in progress. A request made mid-step waits for the next
    boundary. Outside BATTLE, saving is free (manual or autosave). In BATTLE,
    the only saves are the battle-start autosave, written at the tick-0
    boundary before the first step (rule 19), and the suspend save (rules
    22–24); the Save UI greys out
    manual saving there and says why.
19. **Autosave triggers**, each at the next boundary:
    - battle start, at tick 0, before the first step (the battle-start slot);
    - after docking at a port resolves;
    - after a battle outcome is committed;
    - every `AUTOSAVE_DAYS` in-game days (3) and every `AUTOSAVE_REAL_MIN`
      real minutes (10).
    Non-battle autosaves are never closer than `AUTOSAVE_MIN_GAP_S` (60 s).
    Autosave is on by default.
20. **The capture is synchronous; the write is not.** At the boundary, Save/Load
    adds `SYSTEM:save` to the hold set (Simulation Tick & Pause, rule 10), asks
    every section for its payload in one call stack, and releases the hold. No
    tick runs during the capture. Every payload is a deep copy of plain data.
    Encoding, checksums and the file write then run off the simulation, on that
    copy only. Only one save is in flight at a time; a second request waits.
21. **The write never harms the previous save.** The file is written to
    `<slot>.tmp` in the same folder; every write result is checked; it is
    flushed, closed, re-read and its checksums verified; only then does it
    replace the slot, keeping the previous file as `<slot>.bak` until the
    replacement succeeds. Any failure (a full disk, no permission, a failed
    verify) deletes the `.tmp`, leaves the slot and `.bak` untouched, and tells
    the player the save failed and why. The game keeps running and the player can
    retry. A section over its ceiling fails the save; it is never trimmed. On
    startup, orphaned `.tmp` files are deleted. The slot list reads headers only
    and verifies the header checksum; a slot whose file is missing, or whose
    header fails, is listed from its `.bak`. The full section checksums are
    verified when the slot is loaded; a failure there falls back to the `.bak`,
    telling the player.
    *Whether the platform rename replaces atomically is NOT SOURCEABLE; the
    guarantee is the behaviour above, not a rename property (save schema ADR).*

**E. Suspend (battle)**

22. **The suspend save.** In BATTLE, the suspend slot is written:
    - when the player quits: the current step finishes, `PLAYER_PAUSE` is added,
      and the suspend is written; quitting waits for the write;
    - every `SUSPEND_REFRESH_S` real seconds of unpaused battle (120), at the
      next boundary, so a crash costs at most that much battle.
    A suspend holds everything a campaign save holds plus each section's battle
    part (battle RNG streams, projectile sequence, order queue, latches, the
    replay log so far, `tick_index`). A suspend with any declared battle part
    missing is refused at write time; a campaign save with a battle part is
    refused at load.
23. **Loading a suspend** restores the last whole tick under `PLAYER_PAUSE`. The
    suspend file is deleted only after the resumed battle runs its first whole
    tick, so a crash before that tick leaves it usable. A failed delete is
    retried each tick and done at battle end at the latest; it never blocks play.
    Loading any other save leaves the suspend untouched. A battle-start autosave
    loads as a fresh battle at tick 0; identical inputs give identical rolls
    (Deterministic RNG & Seed Streams, rule 11).
24. **Closing the window is a quit.** The close request is caught, the suspend
    or a campaign save completes, then the game exits. A forced kill (task kill,
    crash, power loss) cannot be caught: the player gets back the newest
    completed save. *Close-request and platform suspend handling is NOT
    SOURCEABLE (save schema ADR).* Where a platform signals suspend or sleep, the
    game saves then too.

**F. Saves are untrusted input**

25. **Limits before reading, in order.** File size against `SAVE_MAX` before any
    read; header against `HEADER_MAX`; declared lengths against the actual size;
    section count against `SECTIONS_MAX`; each section against its own
    `ceiling_bytes`; then Content Data D1's limits during parsing (`JSON_DEPTH`,
    `ARRAY_LEN`, `OBJECT_KEYS`, `STRING_FIELD_MAX`, `ID_MAX_BYTES`); non-finite
    or out-of-range numbers refused. The first failure refuses the load. The one
    exception is carried sections over `OPAQUE_MAX`: they are not a refusal but
    a declared loss in the confirm summary (rule 17, Edge Cases). No limit failure ever crashes or hangs the game.
26. **No object deserialisation, ever.** Save code never calls an engine API
    that rebuilds objects from save data, and never loads a resource from a path
    in a save. A static check enforces this.
27. **Paths and names.** The folder is named by `campaign_id`, never by
    player text. A valid `campaign_id` is exactly 32 lowercase hex characters;
    anything else refuses the save. A player-chosen slot label is display meta
    only. Importing a save copies the chosen file, through the size-capped read,
    into a staging folder, validates it, then moves it into the folder of the
    `campaign_id` in its header (created if absent) as a new manual slot; if that
    campaign's manual slots are full, the import is refused with that reason; nothing is ever loaded in place from an arbitrary
    path. Links and non-regular files are refused.
28. **Header text is plain text.** Captain name and every display string are
    shown as plain text with Content Data, Core Rule 14's escaping: length
    capped, control and bidi-override characters stripped, no markup.

### States and Transitions

**Save machine**

| State | Enters when | Leaves to |
|---|---|---|
| IDLE | startup; a save ends | REQUESTED (manual, autosave, suspend or quit request) |
| REQUESTED | a request is made | AWAIT_BOUNDARY; or IDLE if refused (in BATTLE without suspend, load in progress) |
| AWAIT_BOUNDARY | mid-step request | CAPTURING at the next tick boundary |
| CAPTURING | `SYSTEM:save` held | WRITING (hold released) |
| WRITING | encoding and `.tmp` write off the simulation | VERIFYING; FAILED on any write error |
| VERIFYING | `.tmp` closed | COMMITTED; FAILED on a checksum mismatch |
| COMMITTED | slot replaced | IDLE |
| FAILED | any error | IDLE, with the reason shown; `.tmp` deleted, slot and `.bak` untouched |

**Load machine**

| State | Enters when | Leaves to |
|---|---|---|
| IDLE | — | PROBE |
| PROBE | size and header limits | COMPARE; REFUSED |
| COMPARE | outcome decided (rule 15) and chains checked | AWAIT_CONFIRM (Confirm); PARSE_VALIDATE (Compatible, Migrate); REFUSED |
| AWAIT_CONFIRM | summary shown | PARSE_VALIDATE (accept); IDLE (cancel, nothing changed) |
| PARSE_VALIDATE | sections parsed against their version's schema | MIGRATE; REFUSED |
| MIGRATE | chains run in memory, result validated | BUILD; REFUSED |
| BUILD | fresh state built, cross-reference pass, ID requests and substitutions | ARMED; REFUSED |
| ARMED | fresh state swapped in | IDLE; the game is at tick 0 or the suspend tick under `PLAYER_PAUSE` |
| REFUSED | from any state | IDLE, reason shown; nothing changed |

**Slot lifecycle**: EMPTY → VALID (first commit) → VALID (overwrite or
rotation) → DELETED (player deletes). VALID → DAMAGED when its file and `.bak`
both fail; a damaged slot stays listed, is never auto-deleted, and the load
screen points at the newest valid slot. The suspend slot runs ABSENT → WRITTEN
(quit or refresh) → LOADED_UNCONSUMED → CONSUMED (deleted after the first
resumed tick) → ABSENT; a refresh during the resumed battle writes it again.

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | both | Supplies the tick boundary, `tick_index`, `TICK_RATE` and the sim section (with its battle part). Save/Load adds and releases `SYSTEM:save` and `SYSTEM:load`. Tick signals the first whole tick after a resume, which consumes the suspend. |
| Deterministic RNG & Seed Streams (#2) | RNG → save | Registers the RNG section (≤ 64 KB, campaign streams; battle streams in its battle part). Stream renames are migrations. `campaign_id` never comes from the seed streams. |
| Runtime ID Service (#3) | both | Its identity section loads first and is validated by its Core Rule 11. Save/Load runs compaction at campaign saves (Core Rule 6; a compaction failure never fails the save), unions every section's held IDs for it, and fulfils migration ID requests after validation. |
| Content Data & Mod Loading (#4) | both | Supplies the package list and hashes for the header, the content comparison and pre-load summary (Core Rule 13), alias mapping, the shared limit-checked parser (D1), and the plain-text escaping (Core Rule 14). The materialised case (Core Rule 18) is saved as its own section. Missing-mod sections are carried untouched (rule 17). |
| Every stateful system | system → save | Registers one section (rule 7), writes it purely (rule 9), validates its own payload, owns its migrations and fixtures. |
| Menus, Settings & Save UI (#51) | save → UI | Slot list built from headers only; the confirm summary; named refusal and failure messages; "save now" outside battle; manual saving greyed in battle with the reason. |
| Platform Integration (#57) | save → platform | One self-contained file per slot with `save_counter` and `saved_at_utc`, so cloud sync can resolve conflicts; `.tmp` and `.bak` are never synced. Cloud transport and conflict rules belong to #57. |
| Battle Record (#9) | record → save | The replay log lives in the sim section's battle part; empty in a battle-start autosave. |

## Formulas

### D1. Largest save (`SAVE_MAX`)

The save_max formula is defined as:

`SAVE_MAX = ceil_MiB( SAVE_HEADROOM × ( HEADER_MAX + Σ_s ceiling_bytes_s + OPAQUE_MAX ) )`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| SAVE_HEADROOM | float | 1.25 – 2.0; **1.5** | constant (engineering) | Margin for encoding overhead and ceilings not yet confirmed |
| HEADER_MAX | int | **64 KiB** | constant (this GDD) | Largest header (Core Rule 3) |
| ceiling_bytes_s | int | per section | each owning GDD | Largest payload of registered section `s` (Core Rule 7) |
| OPAQUE_MAX | int | **2 MiB** | constant (this GDD) | Total budget for sections carried untouched (Core Rule 17) |
| ceil_MiB | function | — | — | Round up to a whole MiB |

**Section ceilings at the time of writing:**
| Section | Ceiling | Status |
|---|---|---|
| Runtime ID identity table | 8,000,000 B (7.63 MiB) | Runtime ID Service D2 (provisional) |
| RNG streams | 64,000 B (0.06 MiB) | Deterministic RNG & Seed Streams D7 |
| Simulation + battle part | 4 MiB | Battle Record (#9) rule 17: simulation state 0.5 MiB (placeholder), live event log 2 MiB + overflow 0.5 MiB, command log 1 MiB |
| Battle archive (`base:battle_archive`) | 5 MiB | Battle Record (#9) rule 18 |
| Materialised truth case | 1 MiB | **placeholder** for Truth Seeding (Content Data, Core Rule 18) |
| All other systems, combined | 8 MiB | **placeholder** until each owning GDD declares its ceiling (declared so far: `base:archive_fragments` 64 KiB, `base:sector_map` 16 KiB) |
| Header | 64 KiB | this GDD |
| Carried sections (`OPAQUE_MAX`) | 2 MiB | this GDD |

**Output Range:** the sum is 29,101,056 bytes (27.75 MiB). × 1.5 = 41.63 MiB,
rounded up to **`SAVE_MAX` = 42 MiB** (35 MiB before the battle archive was
added, 2026-10-30). This replaces Content Data D1's provisional 32 MiB. `SAVE_MAX` is **computed at startup from the registry**, not
typed in: when a GDD declares or changes a ceiling, `SAVE_MAX` follows, and a
test asserts the computed value equals the registered one. `SAVE_MAX` bounds
the file size before any read **and** the decoded size: decoding stops and
refuses the save the moment it would pass `SAVE_MAX` (a decompression-bomb
guard, whatever compression the save schema ADR picks).

**Example:** a mod registers a 1 MiB section. The sum becomes 28.75 MiB, × 1.5 =
43.13, so `SAVE_MAX` rises to 44 MiB.

### D2. Section ceiling check

At write: `bytes_s ≤ ceiling_bytes_s` for every section, or the save fails
(Core Rule 21). At load: every declared `bytes_s ≤ ceiling_bytes_s` and
`Σ carried_bytes ≤ OPAQUE_MAX`, checked before the section is parsed (Core
Rule 25). Carried sections that do not fit are dropped, largest first, as a
declared loss in the confirm summary, not a refusal. `SECTIONS_MAX` = 256 bounds the section count (registered plus
carried).

### D3. Autosave due

At each tick boundary outside BATTLE, an autosave is **due** when any is true:

- an event trigger fired since the last autosave (port docking resolved; battle
  outcome committed);
- `day_now − day_at_last_autosave ≥ AUTOSAVE_DAYS`;
- `real_s_since_last_autosave ≥ AUTOSAVE_REAL_MIN × 60`.

A due autosave **runs** only when `real_s_since_last_autosave ≥
AUTOSAVE_MIN_GAP_S`; until then it stays due (deferred, never dropped), and any
number of due triggers coalesce into one autosave. The battle-start autosave is
not subject to the gap.

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| day_now, day_at_last_autosave | int | ≥ 0 | World Clock (#8) | In-game day index |
| real_s_since_last_autosave | int | ≥ 0 | this system (wall clock, outside the sim) | Real seconds, counted while the game is open |
| AUTOSAVE_DAYS | int | 1 – 10; **3** | tuning | |
| AUTOSAVE_REAL_MIN | int | 5 – 30; **10** | tuning | |
| AUTOSAVE_MIN_GAP_S | int | 30 – 300; **60** | tuning | |

**Output Range:** at most one autosave per 60 real seconds outside battle; at
least one every 10 real minutes of play outside battle. **Example:** the player
docks 40 s after a battle outcome autosave. The docking trigger is due but
deferred; it runs 20 s later, at the first boundary after the gap.

*The real-time counter is wall-clock and never enters the simulation or
`state_hash` (Simulation Tick & Pause, rule 14).*

### D4. Suspend refresh and the most battle a crash can cost

`refresh due ⇔ unpaused_real_s_since_last_suspend ≥ SUSPEND_REFRESH_S`

`max_battle_lost = SUSPEND_REFRESH_S + t_write`

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| unpaused_real_s_since_last_suspend | float | ≥ 0 | this system | Real seconds in BATTLE with the hold set empty (time paused costs the player nothing, so it does not count) |
| SUSPEND_REFRESH_S | int | 60 – 300; **120** | tuning | |
| t_write | float | ≤ 3 s target (D6) | measured | Time from capture to a committed file |

**Output Range:** a forced kill or crash mid-battle costs at most about 123
real seconds of battle; a normal quit costs none. **Example:** a 9-minute
battle at 1× speed writes 4 refreshes (at 2, 4, 6, 8 min); a crash at 7:50
resumes from 6:00. At 4× speed the same 120 real seconds hold 480 simulated
seconds, so the loss in battle time is larger but the loss in the player's
time is the same.

### D5. Which save is newest

`newest(campaign) = the valid slot with the largest save_counter`

`save_counter` starts at 1 and rises by 1 with every committed save in the
campaign, of any kind. It is stored in the header and never derived from a
clock, so a changed system clock never reorders saves. `saved_at_utc` is for
display only. Autosave rotation overwrites the autosave slot with the smallest
`save_counter`.

### D6. Time budgets (provisional, to be measured)

| Measure | Target | Notes |
|---|---|---|
| Capture (`SYSTEM:save` held) | ≤ `SAVE_CAPTURE_MS` = **50 ms** | The only hitch the player can feel. Measured at max fleet and projectile counts |
| Save, capture to committed file | ≤ 1 s typical; ≤ 3 s at `SAVE_MAX` | Off the simulation; the game keeps running |
| Load, header to ARMED | ≤ 2 s typical; ≤ 5 s at `SAVE_MAX` | Behind a loading screen |
| Slot list (headers only) | ≤ 100 ms for all slots of one campaign | Header reads only |

These are engineering estimates (typical campaign 10–25 MB of uncompressed
data). They are recorded as baselines by the performance probe (AC) before the
save schema ADR is accepted.

## Edge Cases

**Writing**
- **If the game crashes, is killed or loses power during a save**: the `.tmp` is
  left behind and the slot and `.bak` are untouched. On next launch the `.tmp`
  is deleted and the slot loads as before.
- **If the disk is full, or the folder is not writable**: the save goes to
  FAILED. The `.tmp` is deleted, the old save stays, and the player sees "Save
  failed: not enough disk space" (or "…cannot write to the save folder") with a
  Retry. The game keeps running.
- **If autosaves keep failing**: the failure message is shown the first time,
  then once per `AUTOSAVE_FAIL_NOTICE_MIN` (10) minutes at most, so the player is told but not spammed. A
  manual save attempt always shows its result.
- **If a section is over its ceiling at write**: the save fails, naming the
  section ("Save failed: fleet data too large"), and a bug is logged. It is a
  programmer error, never trimmed (Core Rule 21).
- **If a save is requested while one is in flight**: it waits; a second autosave
  request while one waits is merged into it.
- **If a save is requested during a load**: it is refused silently for
  autosaves, and with "Can't save while loading" for a manual request.
- **If the slot file is replaced but `.bak` cleanup fails**: the slot is valid;
  the stale `.bak` is replaced on the next save.
- **If all 20 manual slots are full**: the player must overwrite or delete one.
  The game never deletes a manual save by itself.
- **If the first overwrite of a slot holds an older format** (a migrated load
  saved back): before replacing it, the old file is kept as
  `<slot>.v<N>.bak`, one per slot, never synced. The player can still go back
  to the build that made it.

**Reading**
- **If the slot file and its `.bak` both fail**: the slot is DAMAGED. It stays
  listed with "This save is damaged and can't be loaded", is never auto-deleted,
  and the load screen offers the newest valid slot.
- **If only the slot file fails and `.bak` is valid**: `.bak` loads, and the
  player is told "The latest save was damaged; loaded the one before it
  (<time>)".
- **If the save is from a newer build**: refused before any section is read:
  "This save was made by a newer version (<build>). Update the game to load it."
- **If a section's migration step is missing**: refused before the confirm
  summary, naming the section and versions (a programmer error in this build).
- **If a save holds battle state at a different `TICK_RATE`** (a suspend or
  battle-start autosave from a 60 Hz machine on the 30 Hz fallback, or the
  reverse): refused, "This battle can't resume on this machine's simulation
  rate"; the load screen offers the newest campaign save of that campaign.
  Campaign saves load normally at any `TICK_RATE`.
- **If the build, OS or CPU architecture differs**: loads; the information line
  says replays recorded before this load may not verify.
- **If a mod is missing**: the pre-load summary names it (Content Data, Core
  Rule 13), its sections are carried untouched (Core Rule 17), and the campaign
  loads.
- **If carried sections exceed `OPAQUE_MAX`**: the ones that do not fit, largest
  first, are listed in the confirm summary as "will be lost"; Cancel changes
  nothing.
- **If a mod is reinstalled at a version whose section is older than the one
  carried**: the save is refused, naming the package and both versions (a newer
  section, Core Rule 16). The player can install the newer mod or remove it
  again, which carries the section untouched once more.
- **If a migration chain would run many steps**: it runs them all; the chain
  length is bounded by the version difference, which is at most the number of
  released versions, so it cannot loop.
- **If a "save" is a hostile file** (oversized, deeply nested, forged version,
  dangling IDs, path tricks, control characters in names): it is refused by the
  first limit or validation that catches it, naming file and field. Nothing
  under `user://` changes and the game does not crash (Core Rules 25–28).
- **If the player loads a save while a game is running and cancels the confirm
  summary**: the running game continues, unchanged.

**Battle and suspend**
- **If the player quits during a suspend refresh**: the quit waits for the
  refresh, then writes the suspend at the current tick.
- **If a suspend write fails on quit**: the player is offered "Retry" or "Quit
  anyway (you'll resume from <time> ago)", naming the last good suspend or the
  battle start.
- **If the game is force-killed mid-battle**: it resumes from the last
  refresh, at most `SUSPEND_REFRESH_S` + `t_write` earlier (D4). *This lets a
  player who force-kills after a bad moment replay up to two minutes of battle.
  Rolls are tied to the tick (Deterministic RNG & Seed Streams, rule 11), so the
  same orders give the same result; different orders may not. A normal quit can
  never do this, because it overwrites the suspend at the current tick.
  Accepted by the owner (2026-10-30) as the price of crash safety; see Open
  Questions.*
- **If the resumed battle is quit again before its first tick**: the quit
  writes a new suspend at the same tick, replacing the old one; nothing is lost.
- **If the suspend cannot be deleted after the first resumed tick**: it is
  retried each tick and removed at battle end at the latest. Until then the
  load screen does not offer it, because the session already holds a newer
  state.
- **If a campaign has a suspend and the player loads a different save of the
  same campaign**: the suspend stays and is still offered as "Resume battle"; it
  is replaced when the next battle in that campaign writes its own suspend.
- **If the battle ends between refreshes**: the outcome autosave (Core Rule 19)
  is written and the suspend is deleted.
- **If the window is closed outside battle**: an autosave runs first (if one is
  not already under way), then the game exits.

**Determinism**
- **If a save is taken at tick T and loaded**: running M more ticks gives the
  same `state_hash` and replay as an uninterrupted run of T + M ticks. The
  accumulator remainder is not saved (Simulation Tick & Pause, rule 17); it is
  not an input to the simulation.
- **If the system clock changes between saves**: ordering is by `save_counter`
  (D5); only the displayed time looks odd.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | Tick boundary; hold set (`SYSTEM:save`, `SYSTEM:load`); `tick_index`, `TICK_RATE`; its section and battle part; header fields (rule 14); first-whole-tick-after-resume signal |
| Deterministic RNG & Seed Streams (#2) | Hard | RNG section (≤ 64,000 B, D7) with battle streams as a battle part; stream-rename migrations |
| Runtime ID Service (#3) | Hard | Identity section loads first and is validated (Core Rule 11); compaction at campaign saves (Core Rule 6); held-ID union; ID requests from migrations |
| Content Data & Mod Loading (#4) | Hard | Package list and hashes; content comparison and pre-load summary (Core Rule 13); aliases; shared limit-checked parser (D1); plain-text escaping (Core Rule 14); materialised case (Core Rule 18) |
| World Clock (#8) | Soft (provisional) | In-game day for D3 and the header's display meta. Until designed, the day trigger is inert |
| Combat Event Bus & Battle Record (#9) | Soft | Replay log in the simulation section's battle part; its ceiling feeds D1 |
| Menus, Settings & Save UI (#51) | Soft (reverse) | Consumes slot list, confirm summary, refusal and failure messages; offers "save now" and import |
| Platform Integration (#57) | Soft (reverse) | Cloud sync of one self-contained file per slot, using `save_counter` |
| Every stateful system | Hard (reverse) | Registers one section (Core Rule 7) and declares its ceiling for D1 |

Bidirectional check: Simulation Tick & Pause, Deterministic RNG & Seed Streams,
Runtime ID Service and Content Data & Mod Loading already name Save/Load as a
dependency. World Clock, Battle Record, Save UI and Platform are not yet
designed; their GDDs must list this contract.

## Tuning Knobs

| Knob | Default | Safe range | Affects | If too low | If too high |
|---|---|---|---|---|---|
| `MANUAL_SLOTS` | 20 | 5 – 50 | Load-screen length; player freedom | Players overwrite saves they wanted | Long, slow slot list |
| `AUTOSAVE_SLOTS` | 3 | 2 – 10 | How far back an autosave reaches | One bad autosave leaves no fallback | Clutter; disk use |
| `AUTOSAVE_DAYS` | 3 | 1 – 10 | Campaign-time cadence | Frequent hitches | More campaign lost to a crash |
| `AUTOSAVE_REAL_MIN` | 10 | 5 – 30 | Real-time cadence | Frequent hitches | Up to that many minutes lost to a crash |
| `AUTOSAVE_MIN_GAP_S` | 60 | 30 – 300 | Spacing between autosaves | Hitch clusters around events | Event autosaves arrive late |
| `SUSPEND_REFRESH_S` | 120 | 60 – 300 | Battle lost to a crash (D4); force-kill replay window | More capture hitches in battle | More battle lost to a crash |
| `SAVE_HEADROOM` | 1.5 | 1.25 – 2.0 | `SAVE_MAX` margin (D1) | Real saves refused | Weaker size guard |
| `HEADER_MAX` | 64 KiB | 16 – 256 KiB | Header size cap | Large package lists refused | Weaker guard |
| `OPAQUE_MAX` | 2 MiB | 0.5 – 8 MiB | Missing-mod data carried | Mod state lost on load | Larger saves |
| `SECTIONS_MAX` | 256 | 64 – 1,024 | Section count cap | Heavily modded saves refused | Weaker guard |
| `AUTOSAVE_FAIL_NOTICE_MIN` | 10 | 1 – 60 | How often a repeating autosave failure is shown | Message spam | Player unaware saves are failing |
| `SAVE_CAPTURE_MS` | 50 (provisional) | 16 – 100 | Hitch budget (D6) | Unmeetable | Visible stalls |
| `MIN_SAVE_FORMAT` | first public format | fixed | Oldest loadable save (Core Rule 12) | — | — (raising it needs an ADR) |

All live in a data file (coding standards: gameplay values data-driven), except
`MIN_SAVE_FORMAT`, which changes only by ADR. A knob outside its safe range in the data file stops
the game at startup as a programmer error, like a registry error (Core Rule 7).

## Visual/Audio Requirements

- **Save indicator**: a small, unobtrusive icon in a screen corner while a save
  is WRITING or VERIFYING, never a modal. It must not overlap the battle HUD's
  critical readouts (Save UI #51 places it).
- **No audio** on autosave or suspend refresh. A manual save may use the
  standard UI confirm sound.
- **Failure** uses the standard warning style (Save UI #51), never a sound
  alone.

## Game Feel

- **Saving is invisible.** The only hitch is the capture (D6, ≤ 50 ms); the
  write happens while the game runs. A refresh mid-battle must not drop the
  player's input: inputs during the capture are queued for the next tick, as
  for any hold (Simulation Tick & Pause).
- **Resuming lands paused.** A suspend or battle-start autosave arms under
  `PLAYER_PAUSE`, so the player gets their bearings before anything moves.
- **Bad news is specific.** Every refusal or failure names what happened and
  what the player can do; never "an error occurred".

## UI Requirements

Owned by Menus, Settings & Save UI (#51); this system supplies the data.
- **Slot list** from headers only: captain name, in-game day, location,
  played time, saved time, slot kind, and a "Resume battle" entry when a
  suspend exists. Damaged slots are shown as damaged, not hidden.
- **Confirm summary**: content changes (Content Data, Core Rule 13), declared
  migration losses and carried-section losses, in one list, with Load and
  Cancel. Information lines (build/OS/architecture) appear separately and never
  block.
- **Refusal and failure messages**: one named reason each (Edge Cases), with
  the action the player can take.
- **In battle**: manual Save is greyed out with "Saving is only possible outside
  battle. Quitting keeps your place."
- **Import**: a file picker that copies into the campaign folder (Core Rule 27).
- 📌 **UX Flag — Save/Load & Migration**: this system has UI requirements. In
  Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the save,
  load and confirm screens **before** writing epics. Stories that reference UI
  should cite `design/ux/[screen].md`, not the GDD directly.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Hold reasons, tick boundary, header fields, determinism | `design/gdd/simulation-tick-and-pause.md` | Rules 10, 14, 17 | Rule dependency |
| Battle streams, tick-indexed rolls | `design/gdd/deterministic-rng-and-seed-streams.md` | Rule 11; D7 ceiling | Data dependency |
| Identity load order and validation; compaction | `design/gdd/runtime-id-service.md` | Core Rules 6, 7, 11; D2 | Rule dependency |
| Content comparison, parser limits, escaping, case | `design/gdd/content-data-and-mod-loading.md` | Core Rules 13, 14, 18; D1, D3 | Rule dependency; this GDD sets the final `SAVE_MAX` |

## Acceptance Criteria

**Test harness for every Logic AC:** Save/Load runs against an injected in-memory
store that logs every open, read, write, rename and delete and can be told to
fail at any one of them, plus an injected wall clock, entropy source and section
registry. Logic tests never touch the real filesystem (migration fixtures are
GDScript constant data, Open Question 10). An AC that needs a real filesystem, a
real process kill or a real device is tagged **Integration** and says so.
*Drafted by `qa-lead`; test counts are its proposals (Open Question 11).*

### Logic — `tests/unit/save/` (BLOCKING)

**A. What a save is**

- **AC-01 (Logic; Core Rule 1)**: **GIVEN** an injected entropy source and seed streams in a known state, **WHEN** a campaign is created, **THEN** `campaign_id` is the 128-bit value from the entropy source written as 32 lowercase hex characters, and every seed stream's state is unchanged. Every path the store is asked to write starts with `user://saves/<campaign_id>/`; none starts with `res://`. One save commits exactly one slot file.
- **AC-02 (Logic; Core Rules 1, 16; Game Feel)**: **GIVEN** each refusal reason in Core Rule 16 and each failure message in Edge Cases, **WHEN** its player-facing message is built, **THEN** it contains no `user://`, no `res://` and no absolute path, and it names a reason and an action the player can take.
- **AC-03 (Logic; Core Rule 2, D5)**: a campaign offers exactly `MANUAL_SLOTS` (20) manual, `AUTOSAVE_SLOTS` (3) autosave, one battle-start and one suspend slot. A 4th autosave replaces the autosave slot with the smallest `save_counter`. With all 20 manual slots full, saving asks the player to overwrite or delete, and no manual save is ever deleted without the player. A second battle start overwrites the battle-start slot.
- **AC-04 (Logic; Core Rule 3)**: **GIVEN** a save whose section bytes are garbage but whose header is intact, **WHEN** the slot list is built, **THEN** it returns every header field Core Rule 3 names and a section-parser spy records zero calls. **GIVEN** a Runtime ID of 2^63 − 1 and an RNG state with its top bit set, **THEN** both round-trip exactly, and the encoded file holds every 64-bit value as a string, with no bare number above 2^53.
- **AC-05 (Logic; Core Rule 4)**: a payload holding, one case each, a node, a resource, a callable, a node path, a resource path, an engine vector value, or a raw float fails the save, naming the section; nothing is committed. In a declared bit-pattern field, −0.0 is written with +0.0's bits, and NaN, +inf and −inf are refused at write.
- **AC-06 (Logic; Core Rule 5)**: the same state built with dictionaries filled in two insertion orders encodes to identical bytes. Keys come out in byte order (test `"B"`, `"a"`, `"é"`); a collection keyed by Runtime ID comes out sorted by ID; sections come out in registry order whatever the registration order.
- **AC-07 (Logic; Core Rule 5, round trip)**: **GIVEN** every migration fixture after migration (AC-15) plus 100 saves generated from fixed seeds, **WHEN** each is saved, loaded and saved again, **THEN** every section is byte-identical, and the header is byte-identical except `save_counter`, `saved_at_utc` and the header checksum.
- **AC-08 (Logic; Core Rule 6)**: flipping any byte of any section refuses the load with a checksum failure naming that section; flipping a header byte refuses it with a header checksum failure. A player-edited, re-checksummed payload that still validates loads. No player-facing string in save code calls the checksum tamper protection (static check).

**B. The section registry**

- **AC-09 (Logic; Core Rule 7, startup errors)**: each of these registries stops the build with a named programmer error, and no save or load can start: a duplicate `section_id`; a `loads_after` cycle of length 2 and of length 3; a section at `version` 3 with only the 1→2 migration; a `section_id` of `NAME_MAX_BYTES` + 1 (65) bytes; a `section_id` outside `base:` or a loaded package's namespace. A 64-byte `section_id` is accepted. The registry is not an autoload in `project.godot` (static check).
- **AC-10 (Logic; Core Rule 7, coverage)**: a test walks every member of the simulation state and fails if any member is tagged with no section, or with more than one.
- **AC-11 (Logic; Core Rule 8)**: during a load each section's entry point receives only its own payload and the ID resolver; a call-order spy shows the cross-reference pass starts only after every section is built. The envelope code saves and loads a section whose payload is opaque random bytes accepted by a schema stub, showing it never reads inside a payload.
- **AC-12 (Logic; Core Rule 9)**: running every section's write twice on the same state gives byte-identical output, and leaves `state_hash`, the Runtime ID `next_id`, the retired-ID set and the store log unchanged.
- **AC-13 (Logic; Core Rule 10)**: each section's schema has a recorded fingerprint per `version`. The test fails if a fingerprint changes without `version` rising by exactly 1, or if `version` rises without a matching N→N+1 migration and fixture. Raising `format_version` changes no section `version`.
- **AC-14 (Logic; Core Rule 11)**: every registered migration, run with the clock, random source, Runtime ID Service and scene tree injected as spies that fail on any call, calls no spy, and the same input twice gives byte-identical output. A declared ID request is fulfilled after validation and before tick 1 (order spy). A declared loss appears in the confirm summary.

**C. Loading**

- **AC-15 (Logic; Core Rule 12, fixtures)**: for every `format_version` from `MIN_SAVE_FORMAT` to current, and every `(section_id, version)` from 1 to current, a fixture exists, migrates to current, passes the current schema and equals its stored expected output. A CI check against the last public release tag fails if any fixture is missing or changed. A fixture below `MIN_SAVE_FORMAT` gets the named refusal naming the build that can open it. A v1 fixture of a section now at v6 runs all 5 steps.
- **AC-16 (Logic; Core Rule 13)**: one section set registered in 5 orders shuffled from fixed seeds gives an identical load-order log every time: header, format check, content comparison, Runtime ID section, then the rest in dependency order with ties by `section_id` byte order.
- **AC-17 (Logic; Core Rule 14, no partial load)**: one test per stage 1–7 with a failure injected there. Each refuses with a named reason, never calls the swap (stage 8), leaves the running game's `state_hash` and Runtime ID table unchanged, and the store log shows no write, rename or delete. Stage 6 uses three fixtures: a dangling reference, a wrong-kind reference, and `next_id` ≤ the highest ID seen.
- **AC-18 (Logic; Core Rule 15)**: a table-driven test expects Refuse > Confirm > Migrate > Compatible: identical content and current versions → Compatible, silent; older section with a complete chain → Migrate, silent; Migrate plus a declared loss → Confirm; content differs → Confirm; content differs plus a refusal reason → Refuse; different build, OS or CPU architecture only → Compatible with the information line. With a chain missing, the confirm-summary callback is never called. Cancelling a confirm leaves the running game and the store log unchanged.
- **AC-19 (Logic; Core Rule 16)**: one fixture per refusal reason, each refused with its named code and data: over `SAVE_MAX`; parse or limit failure; checksum failure (section); newer format; newer section (section); missing migration step (section and both versions — through a test registry that skips the startup check, since rule 7 catches it first); older than `MIN_SAVE_FORMAT`; Runtime ID validation failure (ID); missing required section; unresolved reference (section, field, ID); battle state at a different `TICK_RATE`.
- **AC-20 (Logic; Edge Cases: newer build)**: a save with a newer `format_version` is refused before any section is read (parser spy: zero calls), and the message names the save's build.
- **AC-21 (Logic; Edge Cases: `TICK_RATE`)**: a suspend and a battle-start autosave written at 60 and loaded at 30, and the reverse, are refused with "This battle can't resume on this machine's simulation rate", and the newest campaign save is offered. A campaign save loads across 60 and 30 in both directions.
- **AC-22 (Logic; Core Rule 17, missing mod)**: a save with sections from `modA`, loaded without `modA`, names `modA` in the pre-load summary and loads. Saved again, `modA`'s sections are byte-identical to the originals. With `modA` reinstalled, its state equals its state before removal. An unknown `base:` section, an unknown section in a loaded package's namespace, and a section with no valid namespace are each refused.
- **AC-23 (Logic; Edge Cases: older mod reinstalled)**: a carried `modA` section at v3 with `modA` reinstalled at v2 is refused, naming `modA`, v3 and v2.
- **AC-24 (Logic; Edge Cases: `OPAQUE_MAX`; D2)**: carried sections totalling exactly `OPAQUE_MAX` (2 MiB) load with no loss line. At `OPAQUE_MAX` + 1, from 3 sections of different sizes, the confirm summary lists the ones that do not fit, largest first, as "will be lost". Cancel changes nothing; accepting loads, and the next save omits exactly those sections.

**D. Saving**

- **AC-25 (Logic; Core Rule 18)**: a mid-step request is captured at the next tick boundary (tick spy). A manual save in BATTLE is refused with the in-battle reason. During a load an autosave request is refused silently and a manual one gets "Can't save while loading". While a save is in flight a second request waits, and a further autosave request merges into the waiting one.
- **AC-26 (Logic; Core Rule 19, D3)**, injected wall clock and World Clock day, each boundary tested one step either side:
  - `day_now − day_at_last_autosave` = 2 not due, = 3 due; `real_s_since_last_autosave` = 599 not due, = 600 due;
  - a docking trigger and an outcome trigger each make an autosave due;
  - docking 40 s after an outcome autosave is deferred and runs at the first boundary at or after 60 s;
  - three due triggers give one autosave; a deferred trigger is never dropped;
  - the battle-start autosave runs at tick 0 before the first step, even 1 s after another autosave;
  - autosave is on by default;
  - two runs differing only in the injected wall clock give equal `state_hash` at every tick.
- **AC-27 (Logic; Core Rule 20)**: `SYSTEM:save` is held for the whole capture and released before encoding starts; zero ticks run during the capture. Changing live state after the capture does not change the committed bytes. Encoding and writing run while ticks continue. Only one save is ever in flight.
- **AC-28 (Logic; Core Rule 21, D2 write side)**: the store fails, one test per point, at `.tmp` open, a partial write, flush, close, the re-read, a re-read checksum mismatch, and the replace. In each: the `.tmp` is deleted; slot and `.bak` bytes are unchanged; the machine goes WRITING or VERIFYING → FAILED → IDLE with the reason; ticks keep running; a retry then succeeds. A section at exactly `ceiling_bytes` saves; at `ceiling_bytes` + 1 the save fails naming the section, untrimmed, with a bug logged.
- **AC-29 (Logic; Edge Cases: disk full)**: out-of-space and permission-denied each show "Save failed: not enough disk space" or "…cannot write to the save folder" with Retry, and the old save is unchanged. Autosave failures show the first time, then at most once per `AUTOSAVE_FAIL_NOTICE_MIN` (10) minutes on the injected clock. A failed manual save always shows its result.
- **AC-30 (Logic; Core Rule 21, damaged slot and `.bak`)**: at startup an orphaned `.tmp` is deleted. In the slot list, a slot whose file is missing, or whose header checksum fails, is listed from its valid `.bak`. On load, a slot whose section checksum fails loads its `.bak` with "The latest save was damaged; loaded the one before it (<time>)". A slot whose file and `.bak` both fail is DAMAGED, listed as "This save is damaged and can't be loaded", never deleted, and the load screen points at the newest valid slot. A failed `.bak` cleanup after a successful replace leaves the slot valid, and the stale `.bak` is replaced next save. The first overwrite of an older-format slot first keeps `<slot>.v<N>.bak`, one per slot.
- **AC-31 (Logic; D5)**: `save_counter` starts at 1 and rises by exactly 1 per committed save of any kind; a failed save does not raise it. A slot written later with `saved_at_utc` one day earlier is still newest.
- **AC-32 (Logic; Interactions: Runtime ID Service)**: an injected compaction failure does not stop the campaign save from committing.

**E. Suspend (battle)**

- **AC-33 (Logic; Core Rule 22, quit)**: quitting in BATTLE finishes the current step, adds `PLAYER_PAUSE`, writes the suspend at that tick, and exit waits for the commit. Quitting during a refresh waits for it, then writes at the current tick. A failed suspend write on quit offers "Retry" and "Quit anyway (you'll resume from <time> ago)", naming the last good suspend or the battle start.
- **AC-34 (Logic; Core Rule 22, D4)**, injected clock: at 119 s of unpaused battle no refresh is due, at 120 s one is due and is captured at the next boundary; 300 s with the hold set non-empty adds 0 to `unpaused_real_s_since_last_suspend`; at 4× speed a refresh still comes every 120 real seconds; a 9-minute 1× battle writes refreshes at 2, 4, 6, 8 min and a simulated crash at 7:50 resumes at 6:00. A suspend missing a declared battle part is refused at write; a campaign save holding a battle part is refused at load.
- **AC-35 (Logic; Core Rule 23, consumption)**: a loaded suspend arms at its `tick_index` under `PLAYER_PAUSE` and its file is still present. It is deleted only after Simulation Tick's first-whole-tick-after-resume signal; aborting before that signal leaves it loadable again. A failed delete is retried each tick and done at battle end at the latest, and until then the load screen does not offer it. Quitting before the first resumed tick replaces it at the same tick. A refresh during the resumed battle writes it again. A battle ending between refreshes writes the outcome autosave and deletes it. Loading another save of the same campaign leaves it offered as "Resume battle". The slot runs ABSENT → WRITTEN → LOADED_UNCONSUMED → CONSUMED → ABSENT.
- **AC-36 (Logic; Core Rule 23, battle-start)**: a battle-start autosave loads as a fresh battle at tick 0 with an empty replay log; with the original inputs, `state_hash` at tick 500 equals the original run's.
- **AC-37 (Logic; Core Rule 24)**, injected window and platform events: a close request in BATTLE writes the suspend then exits; outside battle it runs an autosave first (waiting for one in progress) then exits; a platform suspend or sleep signal starts the same save. The engine side is AC-55 and AC-56.

**F. Saves are untrusted input**

- **AC-38 (Logic; Core Rules 25–28, hostile fixtures)**: each fixture in `tests/fixtures/save/hostile/` is refused by the first limit or validation that catches it, naming file and field, without a crash, within the D6 5-s load budget, and with no write, rename or delete in the store log:
  - H01 file of `SAVE_MAX` + 1 (zero bytes read past the size probe); H02 header of `HEADER_MAX` + 1;
  - H03 a declared section length past the end of file; H04 one overlapping the next section;
  - H05 `SECTIONS_MAX` + 1 (257) sections; H06 a section of `ceiling_bytes` + 1;
  - H07 a small file decoding to more than `SAVE_MAX`, refused the moment decoding would pass it;
  - H08–H12 `JSON_DEPTH`, `ARRAY_LEN`, `OBJECT_KEYS`, `STRING_FIELD_MAX`, `ID_MAX_BYTES` each exceeded by 1;
  - H13 a duplicate key; H14 a duplicate `section_id` in the index;
  - H15 NaN, +inf and −inf bit patterns; H16 a 64-bit field that is not a number string, or out of range;
  - H17 a newer format, a newer section, and a format below `MIN_SAVE_FORMAT`;
  - H18 a dangling Runtime ID, a wrong-kind Runtime ID, and a `next_id` too low;
  - H19 an encoded engine object and a resource path (resource-loader spy: zero calls);
  - H20 slot labels `../../x`, `/etc/x` and `C:\x`: shown as display meta only, and every store path stays under `user://saves/<campaign_id>/`;
  - H21 a 0-byte file and a truncated header;
  - H22 a header `campaign_id` that is not 32 lowercase hex characters (including path characters): refused.
- **AC-39 (Logic; Core Rule 28)**: a captain name and other display strings holding control characters, U+202E, markup and one character past Content Data Core Rule 14's cap are shown as plain text, stripped and capped, markup uninterpreted, using Content Data's escaping function itself.
- **AC-40 (Logic; Core Rule 26)**: a CI static check scans save code for the banned object-deserialising and resource-loading calls listed in the save schema ADR; a call planted in a test fixture fails it.
- **AC-41 (Logic; fuzz)**: a recorded fixed seed drives 10,000 mutations (bit flips, truncation, length and version edits, nesting inflation) of 5 valid fixtures, one a suspend. Each mutant loads and passes the cross-reference pass, or is refused with a named reason; none crashes, none passes the 5-s budget, none writes. A failing mutant is kept under `tests/fixtures/save/hostile/fuzz/` as a permanent regression fixture. The same seed gives the same mutants every run.

**Formulas and knobs**

- **AC-42 (Logic; D1)**: with the current ceilings (8,000,000 B; 64,000 B; 4 MiB; 5 MiB archive; 1 MiB; 8 MiB), `HEADER_MAX` 64 KiB and `OPAQUE_MAX` 2 MiB, the startup computation gives Σ = 29,101,056 B and **`SAVE_MAX` = 42 MiB (44,040,192 B)**, equal to the registered value. One more 1 MiB section gives 44 MiB. A file of exactly `SAVE_MAX` passes the size probe; `SAVE_MAX` + 1 fails it.
- **AC-43 (Logic; D2 read side)**: a section declaring exactly `ceiling_bytes` passes; `ceiling_bytes` + 1 is refused before its parse (parser spy: zero calls). 256 sections (registered plus carried) pass; 257 are refused.
- **AC-44 (Logic; Tuning Knobs)**: every knob except `MIN_SAVE_FORMAT` is read from the data file; setting `AUTOSAVE_MIN_GAP_S` to 30 changes AC-26's deferral to 30 s with no code change; a knob outside its safe range stops startup with a named programmer error; no knob default appears as a literal in save code (static check).

### Integration — `tests/integration/save/` (BLOCKING)

- **AC-45 (Integration; Core Rule 14, determinism; in memory)**: with a fixed seed and input script, T = M = 3,000, in one campaign run and one battle run: run A saves at T, loads, runs M ticks; run B runs T + M ticks. `state_hash` at T + M and the replay log are identical. The same holds for a suspend saved at T in battle.
- **AC-46 (Integration; real filesystem and process kill; crash mid-write)**: a child game process is killed (SIGKILL on Linux, process termination on Windows) after `.tmp` creation, mid-write, after flush before the replace, and during the replace, 50 times each. On relaunch no `.tmp` remains and the slot's hash equals the old or the new complete save, never a mix; `.bak` is intact.
- **AC-47 (Integration; real filesystem; disk full)**: the save folder on a size-limited volume filled below the save size, and separately read-only: the save fails with the AC-29 message, the old slot's hash is unchanged, no `.tmp` remains, and ticks continue.
- **AC-48 (Integration; real filesystem; damaged slot)**: AC-30's cases on real damaged files give the same results; a DAMAGED slot's files survive 3 relaunches.
- **AC-49 (Integration; real filesystem; Core Rules 25–28)**: every AC-38 fixture placed in a real campaign folder and also imported: a hash of every file under `user://`, before and after, is identical, and the process exits normally after the full set.
- **AC-50 (Integration; real filesystem; Core Rule 27, import)**: importing a symbolic link, a directory, a named pipe (Linux) and a file of `SAVE_MAX` + 1 is refused with no file created. A valid import is staged, validated, then placed as a new manual slot in its header's campaign folder; with that campaign's manual slots full it is refused with that reason. No open on the source path happens beyond the size-capped read.
- **AC-51 (Integration; real process kill; D4)**: killed at 7:50 of unpaused 1× battle with `SUSPEND_REFRESH_S` 120, the relaunch offers "Resume battle" at the 6:00 refresh under `PLAYER_PAUSE`; the loss is ≤ `SUSPEND_REFRESH_S` + measured `t_write` (AC-58). Killed just after the resumed first tick, no suspend remains and the newest save is offered.
- **AC-52 (Integration; real launch; Core Rule 7)**: a headless launch with each AC-09 broken registry exits non-zero with the named error, never reaches the main menu, and creates nothing under `user://saves/`.
- **AC-53 (Integration; Core Rule 17 with Content Data)**: a save made with a real mod package loads with the package removed, is saved, and loads again with it reinstalled; the mod's section bytes and live state match the original, using Content Data's real loader and pre-load summary.

### On-device probes — Linux, Windows, Steam Deck (BLOCKING before the save schema ADR is accepted)

The behaviours marked NOT SOURCEABLE are verified here, never assumed. Each
result goes to `production/qa/evidence/` with device, OS build and engine build
`4.7.2.stable`.

- **AC-54 (Integration probe; Core Rule 21, rename)**: 1,000 replaces, each interrupted by a kill at a seeded random point, always leave the slot hash equal to the old or new file, never missing or partial. A platform that fails is recorded in the save schema ADR, and AC-46 must still pass there through the `.tmp`/`.bak` fallback alone.
- **AC-55 (Integration probe; Core Rule 24, close)**: the window close button, Alt+F4 (Windows), window-manager close (Linux) and the Steam overlay "Exit game" (Steam Deck), in battle and outside, each commit the suspend or an autosave before exit. Any close path that cannot be caught is recorded and handed to Platform Integration (#57).
- **AC-56 (Integration probe; Core Rule 24, sleep)**: Steam Deck power-button sleep, Windows sleep and Linux suspend mid-battle: the probe records whether a suspend write starts and commits before sleep, and a wake then forced kill resumes from it. No signal is recorded as a finding, not a pass.

### Performance — `tests/performance/save/` (ADVISORY until baselines exist, then BLOCKING against D6)

- **AC-57 (Performance; D6, Core Rule 20, Game Feel)**: capture with `SYSTEM:save` held takes ≤ `SAVE_CAPTURE_MS` (50 ms) at the 95th percentile of 100 captures at max fleet and projectile counts (fixture: Open Question 9); inputs made during capture apply on the next tick, none dropped.
- **AC-58 (Performance; D6, D4)**: capture to committed file ≤ 1 s typical and ≤ 3 s at `SAVE_MAX`; the measured value is `t_write`.
- **AC-59 (Performance; D6)**: load, header to ARMED, ≤ 2 s typical and ≤ 5 s at `SAVE_MAX`.
- **AC-60 (Performance; D6)**: the slot list of one campaign with every slot full takes ≤ 100 ms, reading headers only.
- **Baselines**: AC-57–60 run on Linux, Windows and Steam Deck and are recorded in `production/qa/evidence/` before the save schema ADR is accepted; later runs compare against them.

### UI — evidence through Menus, Settings & Save UI (#51)

- **AC-61 (UI; Core Rule 18, UI Requirements)**: each screen #51 builds from this data contract has a retained screenshot in `production/qa/evidence/` when its story closes: manual Save greyed in battle with "Saving is only possible outside battle. Quitting keeps your place."; a damaged slot listed, not hidden; "Resume battle" when a suspend exists; one confirm summary combining content changes, migration losses and carried-section losses, with information lines shown apart.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **File format, compression and checksum algorithm** (canonical JSON vs binary; ZSTD/GZIP; SHA-256 reused from Content Data D3 or a cheaper hash). Engine JSON, compression and hashing behaviour on 4.7.2 is NOT SOURCEABLE (no `modules/core.md`) and needs a spike. | technical-director | Save schema ADR |
| 2 | **Platform write semantics**: whether `DirAccess.rename` replaces atomically (especially on Windows), whether `flush` reaches disk. The GDD's guarantee is behavioural (Core Rule 21); the ADR picks the sequence. NOT SOURCEABLE. | technical-director, godot-specialist | Save schema ADR + on-device probe |
| 3 | **Close and suspend notifications**: window close-request handling and platform sleep/suspend signals on Windows, Linux and Steam Deck. NOT SOURCEABLE. | godot-specialist | Save schema ADR |
| 4 | **Force-kill replay window** (Edge Cases): the 120 s suspend refresh lets a force-kill replay up to two minutes of battle. Accepted 2026-10-30. In playtest, confirm that neither force-kill replays nor battle-start retries undercut Pillar 1 (a defeat must still cost time or resources). | creative-director | First battle playtest |
| 5 | **Section ceilings** for the simulation/replay log, the truth case and all other systems are placeholders (D1). Each owning GDD must declare its own. | each owning GDD | As each is designed |
| 6 | **Cloud conflict resolution** (two devices, same campaign). `save_counter` is provided; the rule belongs to Platform. | Platform Integration (#57) | When #57 is designed |
| 7 | **Time budgets** (D6) are estimates and must be measured. | performance-analyst | Before the save schema ADR is accepted |
| 8 | **Thumbnails** are omitted at MVP (a sidecar breaks single-file saves; image decoding adds attack surface). Post-MVP, an optional, ignorable section with decode caps. | game-designer | Post-MVP |
| 9 | **Performance fixtures**: "max fleet and projectile counts" and a "typical" campaign save (D6) need named fixtures from the owning GDDs (Combat Space, Fleet, Battle Record). | performance-analyst, owning GDDs | Before AC-57–AC-59 can run |
| 10 | **Migration fixtures vs no-file-I/O unit tests**: proposed as generated GDScript constant data under `tests/fixtures/save/`, so unit tests load a script, not a file. | lead-programmer | Save schema ADR |
| 11 | **AC test counts** (10,000 fuzz mutations, 100 round-trip saves, 50 kills per point, 1,000 rename probes, p95 capture, T = M = 3,000) are qa-lead proposals. | qa-lead | First test plan |
