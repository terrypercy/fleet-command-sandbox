# Save/Load & Migration

> **Status**: In Design
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — defeat costs time or resources, never the run, and the save policy keeps that true); Pillar 2 (The Truth Is Yours to Tell — one fixed truth per save, kept intact across every save, load and update)

## Summary

Save/Load & Migration writes a whole campaign to one file per slot and reads it
back exactly. Every stateful system writes its own versioned section, so an
older save is carried forward into a newer build, and the player is told
before anything is lost. Writing a save can never damage the previous one.
Outside battle, saving is free. In battle there is only a suspend save, so
leaving the game costs nothing and a bad roll can't be undone by reloading
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
from them. When a new build changes something their save depended on, the game
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
  same moment (the battle save policy, Detailed Design).
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
   fixed-point fields instead), and floats in authoritative simulation state.
   If a float cannot be avoided, it is stored as its exact bit pattern, never
   as decimal text, with -0.0 written as +0.0 and NaN or infinity refused (the
   same rule as Content Data D3). Saves never use an object-deserialising engine
   call or a resource load (rule 26).
5. **Canonical output.** Keys sorted by byte value, arrays in their stored order,
   collections keyed by Runtime ID written sorted by ID, sections written in
   registry order. Saving, loading and saving again produces a byte-identical
   file. Dictionary iteration order is never a source of order.
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
   at startup as a programmer error. A test enumerates every stateful system and
   fails if one owns no section.
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
    the only save is the suspend save (rules 22–24); the Save UI greys out
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
    startup, orphaned `.tmp` files are deleted, and a slot whose file is missing
    or fails its checksum falls back to its `.bak`, telling the player.
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
    `ceiling_bytes`; then Content Data D1's depth, array, key, string and ID
    limits during parsing; non-finite or out-of-range numbers refused. The first
    failure refuses the load. No limit failure ever crashes or hangs the game.
26. **No object deserialisation, ever.** Save code never calls an engine API
    that rebuilds objects from save data, and never loads a resource from a path
    in a save. A static check enforces this.
27. **Paths and names.** The folder is named by `campaign_id`, never by
    player text. A player-chosen slot label is display meta only. Importing a
    save copies the chosen file into the campaign folder through the size-capped
    read, then validates it; nothing is ever loaded in place from an arbitrary
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
| Simulation + battle part (replay log) | 4 MiB | **placeholder** for Simulation Tick & Pause and Battle Record (#9) |
| Materialised truth case | 1 MiB | **placeholder** for Truth Seeding (Content Data, Core Rule 18) |
| All other systems, combined | 8 MiB | **placeholder** until each owning GDD declares its ceiling |
| Header | 64 KiB | this GDD |
| Carried sections (`OPAQUE_MAX`) | 2 MiB | this GDD |

**Output Range:** the sum is 23,858,176 bytes (22.75 MiB). × 1.5 = 34.13 MiB,
rounded up to **`SAVE_MAX` = 35 MiB**. This replaces Content Data D1's
provisional 32 MiB. `SAVE_MAX` is **computed at startup from the registry**, not
typed in: when a GDD declares or changes a ceiling, `SAVE_MAX` follows, and a
test asserts the computed value equals the registered one. `SAVE_MAX` bounds
the file size before any read **and** the decoded size: decoding stops and
refuses the save the moment it would pass `SAVE_MAX` (a decompression-bomb
guard, whatever compression the save schema ADR picks).

**Example:** a mod registers a 1 MiB section. The sum becomes 23.75 MiB, × 1.5 =
35.63, so `SAVE_MAX` rises to 36 MiB.

### D2. Section ceiling check

At write: `bytes_s ≤ ceiling_bytes_s` for every section, or the save fails
(Core Rule 21). At load: every declared `bytes_s ≤ ceiling_bytes_s` and
`Σ carried_bytes ≤ OPAQUE_MAX`, checked before the section is parsed (Core
Rule 25). `SECTIONS_MAX` = 256 bounds the section count (registered plus
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
  then once per 10 minutes at most, so the player is told but not spammed. A
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
| `SAVE_CAPTURE_MS` | 50 (provisional) | 16 – 100 | Hitch budget (D6) | Unmeetable | Visible stalls |
| `MIN_SAVE_FORMAT` | first public format | fixed | Oldest loadable save (Core Rule 12) | — | — (raising it needs an ADR) |

All live in a data file (coding standards: gameplay values data-driven), except
`MIN_SAVE_FORMAT`, which changes only by ADR.

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

[To be designed]

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **File format, compression and checksum algorithm** (canonical JSON vs binary; ZSTD/GZIP; SHA-256 reused from Content Data D3 or a cheaper hash). Engine JSON, compression and hashing behaviour on 4.7.2 is NOT SOURCEABLE (no `modules/core.md`) and needs a spike. | technical-director | Save schema ADR |
| 2 | **Platform write semantics**: whether `DirAccess.rename` replaces atomically (especially on Windows), whether `flush` reaches disk. The GDD's guarantee is behavioural (Core Rule 21); the ADR picks the sequence. NOT SOURCEABLE. | technical-director, godot-specialist | Save schema ADR + on-device probe |
| 3 | **Close and suspend notifications**: window close-request handling and platform sleep/suspend signals on Windows, Linux and Steam Deck. NOT SOURCEABLE. | godot-specialist | Save schema ADR |
| 4 | **Force-kill replay window** (Edge Cases): the 120 s suspend refresh lets a force-kill replay up to two minutes of battle. Accepted 2026-10-30; confirm it does not undercut Pillar 1 in playtest. | creative-director | First battle playtest |
| 5 | **Section ceilings** for the simulation/replay log, the truth case and all other systems are placeholders (D1). Each owning GDD must declare its own. | each owning GDD | As each is designed |
| 6 | **Cloud conflict resolution** (two devices, same campaign). `save_counter` is provided; the rule belongs to Platform. | Platform Integration (#57) | When #57 is designed |
| 7 | **Time budgets** (D6) are estimates and must be measured. | performance-analyst | Before the save schema ADR is accepted |
| 8 | **Thumbnails** are omitted at MVP (a sidecar breaks single-file saves; image decoding adds attack surface). Post-MVP, an optional, ignorable section with decode caps. | game-designer | Post-MVP |
