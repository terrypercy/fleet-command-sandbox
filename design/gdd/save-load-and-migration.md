# Save/Load & Migration

> **Status**: In Design
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — defeat costs time or resources, never the run, and the save policy keeps that true); Pillar 2 (The Truth Is Yours to Tell — one fixed truth per save, kept intact across every save, load and update)

## Summary

[To be designed]

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Runtime ID Service`

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
| Platform (#57) | save → platform | One self-contained file per slot with `save_counter` and `saved_at_utc`, so cloud sync can resolve conflicts; `.tmp` and `.bak` are never synced. Cloud transport and conflict rules belong to #57. |
| Battle Record (#9) | record → save | The replay log lives in the sim section's battle part; empty in a battle-start autosave. |

## Formulas

[To be designed]

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
