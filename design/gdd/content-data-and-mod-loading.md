# Content Data & Mod Loading

> **Status**: In Design
> **Author**: owner + agents
> **Last Updated**: 2026-10-29
> **Last Verified**: 2026-10-29
> **Implements Pillar**: Pillar 4 (Plan in the Open — everything the player optimises is readable data, including the counter taxonomy the Dossier speaks); Pillar 5 (Living Against Made — the two resource models expressed as data)

## Summary

Content Data & Mod Loading turns every kind of thing the game knows (hulls,
weapons, races, fragment templates, the counter taxonomy, loot tables) into
validated, read-only data under stable namespaced IDs, from the base game and from
mods alike. For the player, it means every number on screen is the number the
fight uses, and a broken or unsafe file is stopped before it can reach a battle or
a save. It exists because the game is data-driven, its saves and replays must
record exactly which content they were made with, and mods must be able to add to
the galaxy without running code or rewriting its rules.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None` (hard); soft contracts with Deterministic RNG & Seed Streams, Runtime ID Service, and each consumer's schema. Depended on by Settings, Hulls, Truth Seeding, Faction Reputation, Machine Nodes & Strongholds, Sector Map, Archive Fragments, Loot & Crafting, Save/Load, and every system whose kind is content

## Overview

Content Data & Mod Loading turns every *kind* of thing the game knows about into
validated data the simulation can trust. Kinds include hulls, weapons, ship
systems, races and factions, archive fragment templates, the counter taxonomy,
loot and mission tables, and difficulty presets. Each kind is a **content
definition**: a record written in JSON or CSV, loaded at startup, checked against
a schema, and turned into a typed, read-only object. Every definition has a
**content ID**, a stable namespaced string such as `base:hull.lancer` or
`mymod:weapon.arc`. The base game is simply the `base` content package. A mod
is another package, with its own namespace, that adds definitions or changes
existing ones under rules this system enforces.

A content ID is **not** a Runtime ID. The content ID `base:hull.lancer` names
the *kind*, the Lancer hull. A Runtime ID names *one* Lancer in this campaign
(Runtime ID Service). A live thing carries both.

Content is fixed once loading finishes. The simulation reads definitions and
never changes them, so the same content and the same seed always give the same
game. The set of loaded content has a **content hash**, written into every
save and replay header (Simulation Tick & Pause, rule 14). A replay made with
different content is never treated as verified.

The player never sees this system work. They feel what it guarantees:
- **The numbers are real and readable.** Every stat, counter and weight the
  Dossier, the Ledger or a tooltip shows comes from one definition, so what the
  game says and what it does always agree (Pillar 4).
- **A bad file never breaks a game.** Broken or unsafe data is refused at load,
  with an error that names the file and the field. It never reaches a battle.
- **Mods add, they don't corrupt.** A mod can extend the galaxy, but it cannot
  silently rewrite a base rule, run code, or quietly change a save it did not
  make.

Without this system three things would break:
- Values would be hard-coded across systems, against the coding standard that
  "gameplay values must be data-driven". Balancing would mean editing code.
- Every system would invent its own file format, ID scheme and validation, and
  the RNG system's weight and permille checks, and Runtime ID Service's content
  IDs, would have no single owner.
- Modding would mean loading arbitrary engine resources. The concept warns
  that third-party `.tres` files are a possible script-execution path.

*How* content is stored and loaded (the schema language, file layout, the
parser, the merge algorithm, how the content hash is computed) is an
implementation choice → **becomes the content/mod data format ADR** named in the
concept's suggested ADRs. This GDD specifies behaviour, guarantees and contracts
only.

## Player Fantasy

**What the Dossier says is what the ship does.** The player experiences this
system **indirectly**. What they feel is that the numbers on the page are the
numbers in the fight.

Every number the player reads, whether a hull's armour, a counter in the
Dossier or a weight in the Ledger, is the number the battle uses. There is no
second, hidden copy and no folklore from patch notes. Once the player has
learned a stat, it stays true everywhere it appears, and a plan built on the
page holds up in the fight. **A broken file is stopped at the door; it never
reaches a battle.**

*Anchor moment:* the Dossier says the relay hull is weak to arc weapons. The
player refits with arc weapons, and the Debrief shows the relay going down
exactly as the numbers said it would.

**Pillars served:**
- **Pillar 4, *Plan in the Open*:** "Everything the player needs to optimise is
  inside the game and readable once learned — no wiki." With it, the anti-pillar
  "**NOT wiki-dependent**: no hidden formulas or unexplained modifiers."
- **Pillar 5, *Living Against Made*:** the organic and machine rule sets are
  data. They stay asymmetric and readable, and they never drift from what the
  game shows.

**Tone:** plain and honest, like a spec sheet the player can trust. The verbs
are *reads, matches, holds, refuses*.

**This system must never make the player feel:**
- **That the screen lied to them.** No tooltip, Dossier or Ledger value may
  differ from what the simulation uses, and no modifier may act that the player
  cannot read somewhere in the game.
- **That a file broke their campaign.** No bad, missing or changed content may
  crash a battle, corrupt a save or silently change one. Refusal happens at load,
  in plain words, before play.

*Secondary audience (later): a modder can add to the galaxy in their own
namespace, and is told exactly which file and field is wrong. Their work
extends the game; it never silently rewrites a base rule or someone else's
save.*

*Shaped by `creative-director` (framing A, "What the Dossier says is what the
ship does", closed with framing B's refusal line). Framing B, "The galaxy is
built to one specification", was judged too close in tone to the RNG and
Runtime ID GDDs, and centred on modding, a later channel. Modders get one
secondary line because the concept makes modding "a secondary channel later".*

## Detailed Design

### Core Rules

1. **Everything is a package; `base` is package zero.**
   - A **package** is a folder with a manifest and data files. The shipped game is
     the package `base`. A mod is any other package.
   - `base` always loads first and must load. If it fails validation, the game
     shows the error and does not start.
   - **Base content** lives inside the exported game (`res://`). **Mods** live in
     `user://mods/<package>/`, the one location that behaves the same in the
     editor and in exports on every platform. An optional extra mod folder can be
     set in config.
   - **The manifest** declares:
     - `namespace` (the package's ID and the prefix of everything it defines)
     - `package_version`
     - `game_version_range`
     - `depends_on` (hard, with version ranges)
     - `load_after` (a soft ordering hint)
     - `display_name_key`
     - its string tables
2. **Mods are data only.**
   - The loader reads only files whose lowercased final extension is on the
     **allowlist**: `.json`, `.fctable` (CSV tables, rule 6) and UTF-8
     `.txt`/`.md`. Images and audio are post-MVP, each behind its own review.
   - **Hard ban**, refusing the whole package with a named error:
     - engine resources and scenes: `.tres`, `.res`, `.scn`, `.tscn`;
     - scripts and native code: `.gd`, `.gdc`, `.gdextension`, `.dll`, `.so`,
       `.dylib`;
     - containers: `.pck`, `.zip`;
     - plain `.csv` (the engine imports it as a translation; tables use
       `.fctable`);
     - executables, double extensions (`hull.json.gd`), and any unknown or
       extensionless file.
   - Mod files are opened as raw text through this system's own loader, **never
     through the engine's resource loader** (`load()`, `ResourceLoader`,
     `ProjectSettings.load_resource_pack`). Those can instantiate scripts or
     override `res://` paths, as the concept warns.
   - No field may name a script, class, scene or resource to instantiate. Fields
     hold IDs, numbers and text keys only, and behaviour comes from base-game
     code selected by an ID or enum.
3. **Mods read only their own folder and write nothing.**
   - Every path in a manifest or definition is relative. The loader refuses:
     - absolute paths, drive letters, and `res://` or `user://` prefixes;
     - `..`, empty segments, backslashes, NUL bytes and percent-encoded forms;
     - Windows reserved device names.
   - After that lexical check, the canonical resolved path must still be inside
     the package's root. Symbolic links and junctions are refused, not followed.
   - The loader writes only its own error log under `user://`.
4. **Content IDs are permanent, namespaced strings.**
   - Format `<namespace>:<kind>.<name>`, for example `base:hull.lancer`. Lowercase
     ASCII, `[a-z0-9_]` in each part, at most 64 bytes in total (D1), the same cap
     as RNG stream names.
   - **A package may define IDs only in its own namespace.** `base` is reserved.
     If two mod packages claim the same namespace, **both are refused**, so the
     outcome never depends on folder order (rule 9).
   - **An ID is permanent once it has shipped in a save.**
     - A rename goes through an `aliases` list on the new definition (old ID →
       new ID), in the same namespace and kind. Chains are flattened: if `B`
       lists alias `A` and later `C` lists alias `B`, then `A` resolves to `C`. An
       alias that collides with a live ID is an error.
     - A removed ID goes in the package's `retired_ids` list, optionally with
       `replaced_by`, a live ID of the **same kind** (rule 13). A `replaced_by`
       that is itself retired is followed, up to `REF_DEPTH` (D1). It may point
       into another namespace only if the package `depends_on` it.
     - A definition may refer to an alias (resolved, with a warning). A reference
       to a retired ID is an error.
     - A kind never changes through an alias or a replacement. An ID's kind is
       part of identity (Runtime ID Service, Edge Cases).
5. **Add-only at MVP.**
   - No package may modify, replace or delete another package's definitions,
     `base` included. Two packages can therefore never touch one definition.
     They can only refer to each other's IDs, through `depends_on`.
   - This keeps "mods add, they don't corrupt" (Player Fantasy) and keeps every
     base rule the Dossier shows true. Owner decision (2026-10-29).
   - A field-level patch mechanism is post-MVP, with its own ADR (Open
     Questions).
6. **One format per kind, chosen by its shape.**
   - **JSON** is for nested kinds: hulls with mounts, fragment templates, races
     and factions. **CSV** is for flat, one-row-per-record tables a spreadsheet
     edits: weapons, loot and mission weights, difficulty presets, the counter
     taxonomy, string tables. Owner decision (2026-10-29).
   - Each kind has exactly one format, fixed in its schema. A file holds one kind
     from one package.
   - Files are UTF-8. A leading BOM is stripped. CRLF line endings are
     normalised to LF, since Windows spreadsheets write them; a lone CR is an
     error.
   - **CSV:** a header row is mandatory. Column order does not matter, and an
     unknown column is an error.
   - **JSON:** written with a stable key order and one field per line, so git
     diffs stay line-level. A duplicate key in one object is an error.
   - Godot imports `.csv` files as translations, so CSV tables use the single
     project extension **`.fctable`**, read by this system's loader and listed in
     the export filter (ADR). A double extension such as `.table.csv` would be
     refused by rule 2. *This engine behaviour is NOT SOURCEABLE in the engine
     reference; the ADR verifies it.*
7. **Every definition has the common envelope; each consumer owns its body.**
   - **This system owns the envelope:** `id`, `kind`, `schema_version`,
     `name_key`, `desc_key`, `tags`, `aliases`.
   - **Each consuming system's GDD owns its kind's body schema:** its fields,
     types, ranges and defaults. Examples: Hulls & Ship Definition (#10) for
     hulls, Machine Nodes & Strongholds (#23) for the counter taxonomy, Loot &
     Crafting (#39) for loot tables. A consumer registers its kind with this
     system.
   - **Strict schemas.** An unknown field, a missing required field, or a value
     out of its stated range is an error; nothing is silently ignored, so typos
     surface.
   - A file with a newer `schema_version` than the game understands is refused.
     An older one is migrated by its kind's registered migration, or refused with
     a message saying which.
   - **Tuning knobs:** every GDD knob whose source is "data file" is a schema
     field with its stated safe range, and the schema range is the validator's
     range. A script checks that each such knob maps to a field (AC).
   - **Numbers:** integers are validated as integers, within ±2^53, rejecting
     `1.5` where an integer is required. NaN and infinity are always rejected.
     Floats are discouraged in definitions; probabilities are integer permille
     (Deterministic RNG & Seed Streams, D4).
8. **This system validates the RNG system's inputs.**
   - **Weighted tables** (for `weighted_pick`): integer weights from 0 to 2^31, a
     total from 1 to 2^31, at most 2^16 entries, stored sorted by unique
     `stable_id`, never as a Dictionary. A negative weight, a zero total or a
     duplicate `stable_id` refuses the package. The loader checks this itself,
     whatever the engine's `rand_weighted` does (concept, Technical
     Considerations).
   - **Permille values:** integers from 0 to 1000.
   - **Stream names declared by a mod** follow the RNG naming rules. A `base:`
     stream name refuses the mod. **If two mods' stream names collide, both
     packages are refused**, so the outcome never depends on load order. If a
     mod's stream name collides with a `base` stream, the mod alone is refused.
9. **Loading is staged and all-or-nothing per package.**
   - Each package passes through the stages in States and Transitions, and
     nothing it defines is visible until the whole package passes.
   - **Failure granularity:**
     - A **mod** with any error is refused whole. Skipping single definitions is
       never done, because a partial mod leaves dangling references.
     - Every package that `depends_on` a refused package is refused too.
     - A **`base`** error stops the game from starting.
   - The game starts with every package that passed, and the mod screen lists
     each refused one with its errors.
   - **Load order is computed, never arbitrary:** `base` first, then a
     topological sort over `depends_on` and `load_after`, ties broken by
     namespace in byte order. A cycle of `depends_on` edges, or a missing hard
     dependency, refuses the packages involved. A cycle made only of `load_after`
     hints is broken by dropping those hints, with a warning. Files within a
     package are read in sorted path order, never in file-system listing order.
   - **Global limits** (D1) are applied in load order: a package that would push
     a total past its limit is refused, and later packages are checked against
     what remains. Only packages that pass count toward the totals. Packages
     beyond the 64th in load order are refused.
10. **Cross-references are resolved and checked before freezing.**
    - In files, a reference to another definition is a content ID field typed by
      the target kind. After every package has parsed, references are resolved,
      and the definitions point straight at each other. Each one also keeps the
      raw ID, for errors and display.
    - A dangling reference or a wrong-kind reference is an error. Whether a kind
      may form cycles is that kind's schema decision.
    - The resolver tracks visited definitions and stops at depth 8 (D1). There is
      no inheritance, templating or expansion feature, so content can never
      multiply itself.
11. **Frozen after load; read-only to the simulation.**
    - When loading succeeds, the definitions are **frozen**: one-way, before the
      first tick.
    - The simulation and UI read them through an injected `ContentDatabase` with a
      typed getter per kind (`get_hull(id)`, `get_weapon(id)`). It is never an
      autoload, and no code outside this system opens a content file.
    - **What changes is never the definition.** Damage, refits, ammunition and
      modifiers live on the instance's record in `SimState`, keyed by Runtime ID
      (Runtime ID Service, Core Rule 5). Derived stats are a pure function of the
      definition and the instance record, and are never saved.
    - **Enforcing read-only** (GDScript has no constant objects):
      - definitions are plain `RefCounted` classes built once by a factory, never
        `Resource`s;
      - their arrays and dictionaries are made read-only recursively at freeze;
      - a CI lint bans assigning to a definition's fields outside this system;
      - a test re-hashes all definitions after a long scripted run and compares
        them to the load-time hash (AC).

      *Engine read-only behaviour is NOT SOURCEABLE; the ADR probes it.*
    - **A content ID that is missing at run time is a programmer error.**
      Validation at load makes it impossible from content, and the save check
      (rule 13) makes it impossible from saves. If one happens anyway, it is a
      debug assert, and is reported to the injected `FatalSink` in release
      builds. There is no `GONE` for content: definitions never disappear while
      the game runs.
12. **The content hash identifies exactly what is loaded.**
    - After freezing, the system computes a **global content hash** from a
      canonical serialization of every loaded package, in load order (D3). It
      covers:
      - each package's namespace and version, and its alias and retired-ID tables;
      - all definitions, sorted by content ID, keys sorted, integers written as
        integers.

      It does not cover file names, paths, whitespace, line endings or
      timestamps. It is the same on every platform.
    - Each package also gets its own **package hash**, so a mismatch can say
      which package differs.
    - Save and replay headers record the global hash, the ordered package list
      with versions, and each package hash (Simulation Tick & Pause, rule 14).
    - **A replay is verified only with an identical global hash.** Any difference
      marks it "unverified".
    - **The content hash is for determinism, not security.** Anyone can recompute
      it, so it is never described as tamper protection.
13. **Loading a save made with different content: warn, then load.** Owner
    decision (2026-10-29). Before the save loads, it compares its recorded
    packages with the loaded set:
    - **Identical** (same packages, and the same **package hashes**, not just the
      same version numbers): the save loads normally. A modder who edits content
      without bumping the version is still detected.
    - **A package the save used is missing, refused, or different:** the player
      sees a pre-load summary of what is missing or changed, and chooses to
      continue or cancel. Cancelling changes nothing. If they continue, each
      instance whose content ID no longer resolves is handled in this order:
      - **Substituted:** if a loaded package lists the ID in `retired_ids` with a
        `replaced_by` of the same kind, the instance is rebound to the
        replacement and stays live. The rebinding happens in the post-validation
        migration step, and is a recorded identity event (Runtime ID Service,
        Core Rule 11).
      - **Removed:** if a loaded package lists the ID in `retired_ids` with no
        replacement (its author retired it on purpose), the instance is retired
        at the first retire point after the load.
      - **Kept inert:** otherwise, typically because its whole package is missing,
        the instance becomes `INERT`. It is saved as inert, and **resumes if the
        package returns** (Runtime ID Service, Core Rule 11). Removing a mod
        therefore never destroys the player's things outright.
    - A package refused only by the load-time watchdog (`LOAD_TIMEOUT`, D2) is
      reported as such in the summary, never as missing content.
    - **An extra package the save did not use:** allowed. It only adds IDs the
      save never mentions. The header is updated at the next save.
    - **A renamed ID:** the save's IDs are mapped through the alias table during
      load validation, before the first tick.
    - **A `base` version difference with no migration:** the save is refused.
    - **Replays** made under a different content hash play as "unverified"
      (rule 12).
    - **Saves are untrusted input** (they are shared). They use the same parser,
      the same limits and the same validation as mods. A save never carries code,
      resource paths or object data, and is never deserialized into objects.
14. **Player-facing text is a key, never a literal.**
    - Definitions hold localisation keys (`hull.lancer.name`), never display
      strings. Each package ships its own string tables (CSV: a key, plus one
      column per locale), with keys prefixed by its namespace.
    - A missing translation falls back to the base locale, then to the key itself,
      with a warning. A key reference to no entry at all is a validation error.
    - Numbers shown to the player are never baked into text; they are formatted
      from definition values, so the screen and the simulation agree (Player
      Fantasy).
    - **Mod and save text is plain text to the UI.** It is never rendered as
      BBCode or used as a format template. Brackets are escaped before any
      BBCode-enabled control, and control, bidirectional-override and zero-width
      characters are stripped (UI Requirements).
    - Numbers in a description come only from a fixed list of placeholders the
      game fills from definition values (for example `{stat:armour}`). An unknown
      placeholder is shown literally.
    - String tables, and `.txt`/`.md` files (read only by the mod screen), are
      **not** in the content hash: text never changes what the simulation does.
15. **Mods are enabled only between sessions.**
    - The enabled set changes only on the mod screen, with no campaign loaded. It
      never changes mid-campaign.
    - The game tells the player once that mods are community content loaded at
      their own risk, and always shows which mods are active.
    - **Hot reload** exists only in dev builds, only on the main menu with no
      campaign loaded. It builds a second, staged content database through the
      full load, and swaps it in only if `base` succeeds. If the reload fails, the
      previous database stays loaded and the errors are shown. Requested in a
      release build or with a campaign loaded, it is refused and logged.
16. **One loader, two front ends.**
    - A **headless validator** shares the game loader's code, so the two can never
      disagree. It runs from the command line and in CI. It reports every error
      in one pass, as `file:line: [severity] field: message` with a stable error
      code, and optionally as JSON.
    - **Exit codes:** 0 means clean (warnings allowed), 1 means validation
      errors, 2 means the tool itself failed.
    - **Errors are structured:** package, file, line or row, field, code and a
      message key. They appear on the mod screen and in the log, and never crash
      the game.
    - Schema documentation for modders is generated from the schemas, never
      written by hand.
17. **The counter taxonomy is content.**
    - The counter taxonomy is a `base` kind, `counter`, with the common envelope
      and a body schema owned by Machine Nodes & Strongholds (#23). The Debrief
      reads it and the Dossier displays it (systems index, Circular
      Dependencies).
    - Mods may add counters in their own namespace. Under add-only (rule 5), they
      cannot change base counters.

### States and Transitions

**Each package**, in load order:

| Stage | Entered when | Passes to | Fails to |
|---|---|---|---|
| **Discovered** | Its folder is found (base: built in; mods: the mod folders) | Manifest OK | Refused |
| **Manifest OK** | Manifest parsed; namespace, version and game-version range valid; files allowlisted and paths contained | Ordered | Refused |
| **Ordered** | Hard dependencies present; load order fixed | Parsed | Refused, and every package depending on it |
| **Parsed** | Every file parsed within the size and count limits (D1) | Schema OK | Refused |
| **Schema OK** | Envelopes and body schemas valid; weights, permille and stream names valid | Linked | Refused |
| **Linked** | Cross-references, aliases and retired IDs resolved | Staged | Refused |
| **Staged** | Waiting for every package to finish; nothing visible yet | Frozen | — |
| **Frozen** | Registered, read-only and hashed | Unloaded (back at the main menu) | — |
| **Refused** | Terminal for this start-up; listed on the mod screen with its errors | — | — |

**The content database:**

| State | Entered when | Leaves when |
|---|---|---|
| **Unloaded** | Start-up; or returning to the main menu for a mod change | Loading begins. (A dev reload never passes through here: it builds a staged second database and swaps it in only on success, rule 15) |
| **Loading** | Packages pass through their stages | `base` reaches Frozen → Ready; `base` is Refused → Failed |
| **Ready** | Every surviving package is Frozen and the hash is computed | Back to the main menu with no campaign loaded → Unloaded |
| **Failed** | `base` was refused | Never: the game shows the error and does not start |

### Interactions with Other Systems

| System | Flows into this system | Flows out of this system | Interface owner |
|---|---|---|---|
| Simulation Tick & Pause (#1) | — | The global content hash and package list for save and replay headers | Tick owns the header and the "unverified" rule; this system owns the hash |
| Deterministic RNG & Seed Streams (#2) | Its table and permille limits; its stream naming rules | Validated weighted tables and permille values; validated stream declarations from mods | RNG owns the limits and the stream registry; this system validates at load |
| Runtime ID Service (#3) | — | Content IDs at issue; which IDs exist after a content change; substitute or remove decisions (`retired_ids`, `replaced_by`); aliases | Runtime ID owns `INERT` and retirement; this system owns substitution and removal |
| Save/Load & Migration (#5) | Recorded package list and hashes | The comparison result and pre-load summary; alias mapping of saved IDs | Save owns the format and migration; this system owns the content comparison |
| Gameplay Settings & Modifiers (#7) | — | Difficulty presets as a kind; the enabled mod set | Settings owns preset meaning |
| Hulls (#10), Truth Seeding (#16), Faction Reputation (#17), Strongholds (#23), Sector Map (#26), Archive Fragments (#28), Loot & Crafting (#39), and every later kind | Their kind's body schema and migrations | Frozen, typed definitions through `ContentDatabase` | Each consumer owns its schema; this system owns the envelope and the pipeline |
| After-Action Debrief (#24), Dossier (#47) | — | The counter taxonomy (`counter` kind) | Strongholds (#23) owns it; the Debrief reads it; the Dossier displays it |
| Menus, Settings & Save UI (#51) | The player's choices on the mod screen | Package list, refusal reports, the pre-load summary, the risk notice | #51 owns the screens |
| Presentation and all UI | — | Localisation keys and string tables; plain-text mod strings | Each screen owns its layout; this system owns the escaping rule |
| Telemetry & Playtest Logging (#54) | — | The active package list and global hash for bug reports | #54 |

**What no package and no system can do:**
- run code or load an engine resource from a mod
- read outside its own folder, or write anything
- define an ID outside its own namespace, or change another package's content
- change a definition after freezing
- enable or disable a mod during a campaign
- show mod or save text as markup

*Specialists consulted:*
- `systems-designer` (primary: package model, add-only, staged pipeline, the
  mismatch policy, aliases)
- `security-engineer` (data-only allowlist and ban list, path containment,
  limits, UI escaping, saves as untrusted input)
- `tools-programmer` (formats per kind, strict schemas, one validator shared with
  the game, error format, generated docs)
- `gameplay-programmer` (injected database, read-only enforcement, instance vs
  definition, resolved references)
- `engine-programmer` (`user://mods/`, CSV import pitfall, BOM, integer rules,
  canonical hash)

*Owner decisions (2026-10-29):*
- add-only at MVP
- warn, then load, when a save's content differs
- JSON for nested kinds and CSV for flat tables

*Specialist disagreements, resolved by the owner:*
- `gameplay-programmer` proposed refusing any save with a missing content ID;
  `systems-designer` proposed warn-then-load. The owner chose warn-then-load.
- `engine-programmer` leaned toward JSON only; `tools-programmer` proposed JSON
  plus CSV. The owner chose JSON plus CSV.

*Handed to the content/mod data format ADR:* the schema language and parser;
file extensions and export filters; the canonical hash specification and
algorithm (SHA-256 recommended); typed-class generation; the read-only probes;
symlink detection on each platform; localisation through the engine's
translation server or a custom table. Every engine fact here is NOT SOURCEABLE in
`docs/engine-reference/godot/` (there is no `modules/core.md`), and each must be
verified on 4.7.2 before the ADR is accepted.

## Formulas

All limits are integers and engineering constants, shared by the game and the
validator through one constants file. None is a gameplay tuning knob. **`base`
is held to the same limits as mods**, so CI catches the base game creeping
toward them.

### D1. Load limits

The total_data_bytes formula is defined as:

`total_data_bytes = Σ_{p=0..N} bytes_p ≤ TOTAL_DATA_MAX`, where every `bytes_p ≤ PKG_DATA_MAX`, `N ≤ MODS_MAX`, and every file is `≤ FILE_MAX`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| bytes_p | int | 0 – 8 MiB | calculated | Data bytes in package p (p = 0 is `base`) |
| N | int | 0 – 64 | calculated | Enabled mods |
| total_data_bytes | int | 0 – 64 MiB | calculated | All content data read in one start-up |

**Limits** (all constant, engineering). "Headroom" is the base game's estimated
need at its growth scale (about 400 records) divided by the limit:

| Constant | Value | Base need (growth) | Headroom | Why |
|---|---|---|---|---|
| `FILE_MAX` | 1 MiB | ≈ 0.31 MiB (largest one-locale string table) | 0.31 | One 4-locale table would be 0.97 MiB, so **string tables are one file per locale** |
| `PKG_DATA_MAX` | 8 MiB | ≈ 2 MiB | 0.25 | 400 records × ≈ 1.5 KB, plus strings |
| `TOTAL_DATA_MAX` | 64 MiB | ≈ 2 MiB | 0.03 | Without it, 65 × 8 MiB = 520 MiB |
| `FILES_PER_PKG` | 1,000 | ≈ 300 | 0.30 | One file per hull, plus tables |
| `JSON_DEPTH` | 16 | ≈ 5 | 0.31 | hull → mounts → mount → arcs |
| `ARRAY_LEN` (and CSV rows) | 10,000 | ≈ 2,600 | 0.26 | The largest string table |
| `OBJECT_KEYS` | 1,000 | ≈ 40 | 0.04 | The widest body schema |
| `ID_MAX_BYTES` | 64 | ≈ 24 | 0.38 | The same cap as RNG stream names (`name_max_bytes`) |
| `NAMESPACE_BYTES` | 2 – 24 | 4 (`base`) | — | Leaves at least 38 bytes for `kind.name` |
| `LOC_KEY_MAX_BYTES` | 128 | ≈ 30 | 0.23 | A 64-byte ID plus a suffix, with margin |
| `STRING_FIELD_MAX` | 256 bytes | ≈ 40 | 0.16 | Tags and short text |
| `DESC_MAX` | 4,000 code points **and** 16,000 bytes | ≈ 600 | 0.15 | The byte cap bounds UTF-8, up to 4 bytes per code point |
| `DEFS_PER_PKG` | 5,000 | 400 | 0.08 | String rows do not count as definitions |
| `DEFS_TOTAL` | 50,000 | 400 | 0.008 | Binds before 65 × 5,000 would |
| `MODS_MAX` | 64 | — | — | Enabled at once |
| `REF_DEPTH` | 8 | ≈ 3 | 0.38 | mission → loot table → item |
| `DEP_DEPTH` | 16 | 0 | — | The longest `depends_on` chain |
| `SAVE_MAX` | 32 MiB (**provisional**) | — | — | See below |

**Output Range:** 0 – 64 MiB; base alone is about 2 MiB.
- **Save cap:** Runtime ID Service D2's identity ceiling is 8 MB (7.63 MiB). A
  16 MiB cap would leave only 8.37 MiB for every other section, none of which has
  a ceiling yet. `SAVE_MAX` is therefore 32 MiB, provisionally, until Save/Load &
  Migration (#5) sums its section ceilings; it should then be at least 1.5 times
  that sum. `FILE_MAX` does not apply to saves.
- **Crossing a limit** refuses the package that crosses it, in load order, so the
  outcome is deterministic. A limit is never trimmed to fit.

**Example:** base (2 MiB) plus 10 mods of 3 MiB is 32 MiB, under 64 MiB, so all
load. Base plus 20 mods of 4 MiB would be 82 MiB, so the mods that cross 64 MiB
are refused, in load order.

### D2. Load-time budget

*Estimates: NOT SOURCEABLE in the engine reference; measured by the spike.*

The t_load formula is defined as:

`t_load = t_io + n_rows × t_row + bytes_canon × c_hash`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t_io | float (ms) | 5 – 340 | calculated | File reads, at about 200 MB/s |
| n_rows | int | 2,000 – 100,000 | calculated | Definitions plus string rows |
| t_row | float (µs) | ≈ 12 | constant (engineering; measured) | Parse, validate and link per row (≈ 5 + 5 + 2) |
| bytes_canon | int | ≈ total_data_bytes | calculated | D3's input |
| c_hash | float (ns per byte) | ≈ 20 | constant (engineering; measured) | Canonical serialization; the SHA-256 itself is native |
| BASE_COLD_BUDGET_MS | int | 250 | constant (engineering) | Cold load of `base` alone |
| PKG_PARSE_ABORT_S | int | 5 | constant (engineering) | Watchdog for one package |

**Output Range:** about 50 ms (base at Early Access scale) to about 2.9 s (64 mods,
every one at its limits).
- **Early Access base:** 5 + 2,000 × 12 µs (24 ms) + 1 MiB × 20 ns (21 ms) ≈
  **50 ms**, 20% of the budget.
- **64 mods at the limits:** 336 + 1,200 + 1,342 ms ≈ **2.9 s**. That is
  acceptable on the main menu with a progress bar.
- One 8 MiB mod parses in under 100 ms, so the 5 s watchdog has ample headroom.
- **The watchdog depends on the machine,** so a slow PC could refuse a mod a fast
  one loads. It is reported as a distinct `LOAD_TIMEOUT`, never as a content
  error. What content loads rests only on D1's deterministic byte and count
  limits.

**Example:** the growth-scale base (about 3,000 rows, 2 MiB) takes about 10 + 36
+ 42 ≈ **88 ms**.

**The spike measures** per-row parse, validate and link time for JSON and for
CSV; `c_hash`; and `t_io` from `res://` and `user://`. All of it on the
minimum-spec machine.

### D3. Canonical content hash

The content_hash formula is defined as:

`H_pkg = SHA256("FCPK" ‖ u32(FMT) ‖ S(namespace) ‖ S(version) ‖ L(aliases, by old ID) ‖ L(retired IDs, each (id, replaced_by or "")) ‖ L(definitions, by content ID, each E(def)))`
`H_global = SHA256("FCCH" ‖ u32(FMT) ‖ u32(n) ‖ for each package in load order: S(namespace) ‖ S(version) ‖ H_pkg)`

**Encodings:**
- `S(x)` is a big-endian `u32` byte length followed by the UTF-8 bytes, with no
  normalization.
- `L(…)` is a big-endian `u32` count followed by the elements, sorted byte-wise.
- `E(value)` is typed:
  - `'i'` then a big-endian `int64`;
  - `'s'` then `S`;
  - `'b'` then 0 or 1;
  - `'n'` for null;
  - `'a'` then a `u32` count, then the elements in stored order;
  - `'o'` then a `u32` count, then each `S(key) ‖ E(value)`, keys sorted
    byte-wise;
  - `'f'` then the binary64 bits, big-endian, with −0.0 written as +0.0 (NaN
    and infinity are already rejected at load).
- CSV rows are hashed **after** schema typing, so the cell `5` and the JSON value
  `5` hash the same.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| FMT | int | 1 | constant (engineering) | Version of this serialization; bumping it changes every hash |
| n | int | 1 – 65 | calculated | Loaded packages |
| H_pkg, H_global | bytes | 32 each | calculated | Written in headers as 64 hex characters |

**Output Range:** 256 bits. The chance that any two of k different content sets
share a hash is about k² / 2^257: even at k = 2^32 it is about 2^−193 (≈ 8 ×
10⁻⁵⁹).

**Example:** base plus 2 mods: the global input is about 150 bytes (12 bytes of
prefix and count, plus each package's namespace, version and 32-byte hash).
The header carries 64 + 3 × 64 = 256 hex characters: the global hash and the
three package hashes.

### D4. Weighted-table total

The weight_total formula is defined as:

`weight_total = Σ_{i=1..n} w_i`; the table is valid only if `1 ≤ weight_total ≤ 2^31`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n | int | 1 – 65,536 (2^16) | data file (the consumer's table) | Entries |
| w_i | int | 0 – 2^31 | data file (the consumer's table) | One weight |
| weight_total | int (64-bit) | 0 – 2^47 | calculated | 2^16 × 2^31 = 140,737,488,355,328, below 2^63 − 1, so it cannot overflow |

**Output Range:** valid totals are 1 to 2,147,483,648 (Deterministic RNG & Seed
Streams, D5). The validator checks the total **explicitly** before any RNG call
could see the table. It may stop summing once the running total passes 2^31.
- A total of exactly 2^31 is legal; one weight of 2^31 then forces every other
  weight to 0.
- A zero-weight entry is legal (it is never picked), and the validator **warns**.

**Example:**
- `[700, 250, 50]` totals 1,000: valid.
- `[2^31, 2^31]` totals 4,294,967,296: refused, `WEIGHT_TOTAL_RANGE`.
- `[0, 0]` totals 0: refused.

*Specialist consulted: `systems-designer`. It adopted `security-engineer`'s
limits, adding a 64 MiB total cap, a 128-byte localisation-key cap, a dependency
depth of 16, a byte cap on descriptions, and one string table per locale. It
raised the save cap from 16 MiB to 32 MiB. Every figure was re-checked; one
estimate was corrected (an 8 MiB mod parses in under 100 ms).*

*Minor decisions taken in guided mode, on the specialist's recommendation:*
- *the save cap is 32 MiB, provisionally*
- *`base` is held to the same limits as mods*
- *zero-weight entries produce a warning*

*For the ADR:*
- the single constants file
- D3's exact byte layout and `FMT`, with golden-hash test vectors
- D2's measurements on the minimum-spec machine
- confirming that GDScript's `int` is 64-bit on 4.7.2 (NOT SOURCEABLE)

## Edge Cases

### Packages and order

- **If `load_after` names a package that is not loaded**: the hint is ignored,
  with no warning.
- **If a dependency is present but outside the `depends_on` version range**: it
  counts as missing, and the package is refused with `DEP_VERSION`.
- **If a package's `game_version_range` excludes this build**: it is refused at
  the Manifest OK stage.
- **If a `depends_on` chain is longer than `DEP_DEPTH` (16)**: the package at
  depth 17, and every package that depends on it, are refused.
- **If a dependency is refused for any reason**: its dependents are refused too,
  and each error names the root package (Core Rule 9).
- **If two mods claim the same namespace**: both are refused (Core Rule 4).
- **If the `load_after` hints form a cycle**: the hints in the cycle are dropped,
  with a warning, and load order falls back to dependencies and namespace order
  (Core Rule 9).
- **If 65 or more mods are enabled, or a global limit would be crossed**: the
  packages beyond the 64th in load order, and any package that would cross a
  total, are refused. Later packages that still fit are loaded (Core Rule 9, D1).

### Files and formats

- **If a file is 0 bytes**: it is a parse error. A CSV table with only a header
  row is valid and holds zero records.
- **If a file is not valid UTF-8, or has a BOM anywhere but at the start** (for
  example a `.dll` renamed `.json`): the package is refused with `ENCODING`,
  before any parse.
- **If a CSV table was saved with semicolons or decimal commas** (a European
  spreadsheet locale): it fails as an unknown column or a column-count mismatch,
  under the error code `CSV_DIALECT`, which names the likely cause.
- **If a file uses CRLF line endings**: they are normalised to LF. A lone CR is an
  error (Core Rule 6).
- **If a file name has a trailing dot or space (`a.json.`), or two paths in a
  package differ only by case**: the package is refused, because these behave
  differently across platforms.
- **If an extension is uppercase (`HULL.JSON`)**: it is lowercased and accepted
  (Core Rule 2).
- **If a JSON object repeats a key**: it is an error (Core Rule 6), even though
  the engine's parser might keep the last value silently.

### IDs

- **If a definition's `kind` field differs from the kind in its ID**:
  `KIND_MISMATCH` error.
- **If one ID is both an alias and in `retired_ids`, or both a live definition and
  a retired ID**: error.
- **If two definitions in one package claim the same alias**: error naming both.
- **If an ID is exactly 64 bytes**: accepted. At 65 bytes it is refused (D1).
- **If a `replaced_by` names a different kind, or a missing ID**: error (Core Rule
  4).

### Schemas and numbers

- **If an integer field is written `5.0`, `1e3`, `+5` or `005`**: it is refused.
  This needs a lexical check on the number's text, because a parser that reads
  every number as a float loses the difference (ADR).
- **If an integer is beyond ±2^53**: it is refused, by the same lexical check; a
  float parse cannot tell 2^53 from 2^53 + 1.
- **If a definition is migrated from an older schema**: the content hash covers
  the migrated, frozen form (D3).
- **If a weight table's total is exactly 2^31, or an entry's weight is 0**: both
  are legal; a zero weight produces a warning (D4).

### References

- **If a reference chain reaches depth 9**: `REF_DEPTH` error naming the chain.
- **If a cycle exists in a kind whose schema forbids cycles**: error listing the
  cycle's members.
- **If a definition refers to a package it does not `depends_on`**: error, even if
  that package happens to be loaded. Otherwise whether it loads would depend on
  what the player happened to enable (Core Rule 5).

### Saves

- **If a save is larger than `SAVE_MAX`**: it is refused before parsing (D1).
- **If a save refers to an ID whose namespace is missing from the save's own
  header**: it is refused as malformed.
- **If a save's package has the same version but a different package hash**: it is
  treated as changed, and the pre-load summary says so (Core Rule 13).
- **If a save holds an ID that is now an alias**: it is mapped to the current ID
  during load validation (Core Rule 13).
- **If a save's `base` version differs and no migration exists**: the save is
  refused.
- **If a save carries object data, a resource path or a script reference**: it is
  read as plain data or refused; nothing is ever instantiated from it (Core Rule
  13).
- **If the player cancels the pre-load summary**: nothing changes, and they return
  to the menu.

### Runtime

- **If gameplay code asks for a content ID that does not exist**: it is a debug
  assert, and is reported to the `FatalSink` in release builds (Core Rule 11).
- **If code writes to a frozen definition's array or dictionary**: the engine
  raises an error. A write to a plain field is caught by the lint and the
  post-run re-hash test (Core Rule 11).
- **If a hot reload is requested in a release build, or with a campaign loaded**:
  it is refused and logged. A failed dev reload leaves the previous content
  loaded (Core Rule 15).

### Text

- **If a string key is missing in one locale**: it falls back to the base locale,
  then to the key itself, with a warning (Core Rule 14).
- **If a definition refers to a string key that no table defines**: validation
  error. A table key that nothing refers to is a warning.
- **If a mod's text holds BBCode, `{0}`, `%s`, or a placeholder not on the fixed
  list**: it is shown literally (Core Rule 14).
- **If a refused mod's display name cannot be loaded**: the mod screen shows its
  namespace.

### Security

- **If a path in a mod is absolute, uses `..`, or resolves outside the package**:
  the package is refused (Core Rule 3).
- **If a mod folder contains a symbolic link or junction**: the package is refused,
  and the link is not followed (Core Rule 3).
- **If a package takes longer than 5 s to parse**: it is refused with
  `LOAD_TIMEOUT` (D2). The watchdog is **off in the headless validator and in
  CI**, so their results never depend on the machine.

### Hash

- **If the same content is saved with a different file order, line endings or
  whitespace**: the hash is identical, because it covers the canonical form, not
  the files (D3).
- **If an enabled mod defines nothing**: it still enters the global hash, so
  replays made without it become "unverified" (D3).

*Specialist consulted: `systems-designer`. It found four conflicts with the draft,
all resolved:*
- *The proposed `.table.csv` was a double extension, which rule 2 bans; tables
  now use `.fctable` (Core Rule 6).*
- *"A duplicate namespace refuses the second package" depended on folder order;
  both are now refused (Core Rule 4).*
- *A failed dev reload could not keep the old content; the reload now builds a
  staged second database (Core Rule 15).*
- *Substitution rebound IDs outside any recorded event, and Runtime ID Service's
  "resumes if the mod returns" could never happen. Instances from a missing
  package now stay inert and resumable, only deliberately retired IDs are
  removed, and each substitution is a recorded identity event. Runtime ID
  Service's Core Rule 11 and D2 were updated to match (Core Rule 13).*

*It also raised 12 open questions; 11 are answered above or in the Core Rules (CRLF,
package-hash comparison, global limits, `load_after` cycles, a collision with a
`base` stream, `replaced_by` chains, references to aliases, alias flattening,
description numbers, the watchdog in CI, string tables and the hash). The
twelfth, whether a retired ID may be re-added, is in Open Questions.*

## Dependencies

### Upstream (what this system needs)

**Hard dependencies: none.** The package model, the loader, the validator and the
content hash work with nothing else designed. That is why the system sits in the
Foundation layer.

**Interface contracts** (soft). Each is data handed in, never a call back into
another system's logic:

| System | Hard / soft | Interface | Notes |
|---|---|---|---|
| Deterministic RNG & Seed Streams (#2) | Soft (limits handed in) | `weighted_pick` and permille limits; the stream naming rules | This system validates content against them at load (Core Rule 8) |
| Runtime ID Service (#3) | Soft | `INERT`, retirement and the substitution event | Runtime ID applies the statuses; this system decides substitute, remove or keep inert (Core Rule 13) |
| Each consuming system | Soft (schemas handed in) | Its kind's body schema and migrations | Registered with this system; without them a kind cannot load (Core Rule 7) |

### Downstream (what depends on this system)

**Listed in the systems index:**

| System | Hard / soft | What it relies on |
|---|---|---|
| Gameplay Settings & Modifiers (#7) | Hard | Difficulty presets as a kind; the enabled mod set |
| Hulls & Ship Definition (#10) | Hard | Owns the hull kind's schema; reads frozen hull definitions |
| Truth Seeding & Candidates (#16) | Hard | Candidate races and the per-race attribute table as content |
| Faction Reputation & Standing (#17) | Hard | Faction definitions |
| Machine Nodes & Strongholds (#23) | Hard | Owns the `counter` kind (Core Rule 17) and node definitions |
| Sector Map & Travel (#26) | Hard | Systems, lanes and hand-placed anchors as content |
| Archive Fragments & Evidence (#28) | Hard | Claim templates and fragment definitions |
| Loot & Crafting (#39) | Hard | Loot tables, validated by D4 and Core Rule 8 |

**Not yet listed in the index.** Each needs this system in its own Dependencies,
and the index should list it at the next update:

| System | Hard / soft | What it relies on |
|---|---|---|
| Simulation Tick & Pause (#1) | Soft | The global content hash and package list for save and replay headers (Core Rule 12) |
| Deterministic RNG & Seed Streams (#2), Runtime ID Service (#3) | Soft | Validated tables and stream declarations; content IDs and the mismatch policy. *Not added to the index: #2 and #3 sit above #4 in the Foundation layer, and a system may depend only on one above it. Their GDDs record the contract* |
| Save/Load & Migration (#5) | Hard | The content comparison, the pre-load summary, alias mapping, the shared parser and limits for saves (Core Rule 13; D1 `SAVE_MAX`) |
| Weapons & Damage (#12), Vigor (#13), Coherence & Links (#14), Ship AI (#20), Refit & Loadout (#35), Markets & Trade (#37), Contracts & Missions (#38) | Hard | Each owns its kind's schema and reads frozen definitions |
| After-Action Debrief (#24), Dossier (#47) | Hard | The counter taxonomy; every number shown comes from a definition (Player Fantasy) |
| Menus, Settings & Save UI (#51) | Hard | The mod screen, refusal reports, the pre-load summary, the risk notice |
| Telemetry & Playtest Logging (#54) | Soft | The active package list and global hash in bug reports |

**Bidirectional check:**
- Deterministic RNG & Seed Streams lists Content Data & Mod Loading (#4) as a soft
  upstream dependency for namespaces, mod stream declarations and table
  validation ✓.
- Runtime ID Service lists Content Data & Mod Loading (#4) as a soft upstream
  dependency for content IDs and the `INERT` status ✓; its Core Rule 11 and D2
  now also record substitution as an identity event.
- Simulation Tick & Pause does not yet name this system for the content hash in its
  header (rule 14). Flag for its re-review.
- Every other system above must list Content Data & Mod Loading in its own
  Dependencies when it is designed.

## Tuning Knobs

**This system owns no gameplay tuning knobs.** Every designer-tuned value lives in
a consumer's content, under that consumer's schema and safe ranges (Core Rule 7).
This system only guarantees the value is valid and the same everywhere it is read.

### Engineering constants (versioned; not tuning knobs)

Changing any of these changes what content is accepted, or the hash. Each change is
versioned.

| Constant | Value | Why it is fixed |
|---|---|---|
| Load limits (`FILE_MAX`, `PKG_DATA_MAX`, `TOTAL_DATA_MAX`, `FILES_PER_PKG`, `JSON_DEPTH`, `ARRAY_LEN`, `OBJECT_KEYS`, `ID_MAX_BYTES`, `NAMESPACE_BYTES`, `LOC_KEY_MAX_BYTES`, `STRING_FIELD_MAX`, `DESC_MAX`, `DEFS_PER_PKG`, `DEFS_TOTAL`, `MODS_MAX`, `REF_DEPTH`, `DEP_DEPTH`) | See D1 | Security and determinism. The same for `base` and mods |
| `SAVE_MAX` | 32 MiB (**provisional**) | Until Save/Load (#5) sums its section ceilings (D1) |
| `BASE_COLD_BUDGET_MS` | 250 | Start-up budget for `base` (D2) |
| `PKG_PARSE_ABORT_S` | 5 | Watchdog; off in the validator and CI (D2) |
| Hash `FMT` | 1 | Version of the canonical serialization; bumping it changes every hash (D3) |
| Weight-table bounds | weights 0 – 2^31; total 1 – 2^31; up to 2^16 entries | Owned by Deterministic RNG & Seed Streams (D5); checked here (D4) |
| File allowlist and ban list | Core Rule 2 | Mods are data only |
| Table extension | `.fctable` | Avoids the engine's CSV import (Core Rule 6) |

**Knobs owned elsewhere** (referenced, not duplicated):
- every stat, weight, probability and threshold in content, owned by the system
  whose kind it is (Hulls #10, Weapons #12, Loot #39, and so on)

## Visual/Audio Requirements

**None at MVP.** Content data carries no images or sound; asset references belong to
each kind's schema, and the art pipeline. Mod images and audio are post-MVP, each
behind its own security review (Core Rule 2; Open Questions).

*`art-director` and `audio-director` were not consulted: Visual/Audio is optional
for `Core` systems, and this system has no visual or audio surface at MVP.*

## Game Feel

**Not applicable.** The player never operates this system during play. Its feel
contribution is indirect: the numbers on screen match the fight (Player Fantasy),
and start-up stays quick (D2).

## UI Requirements

This system contributes three player-facing surfaces. The screens themselves
belong to Menus, Settings & Save UI (#51).

1. **The mod screen.**
   - Lists every package found: its display name (or its namespace, if its name
     could not load), its version, whether it is enabled, and its status (loaded,
     or refused with its errors).
   - Each error is shown in plain words: the file, the line or row, the field,
     and what is wrong. The stable error code is visible for bug reports.
   - Mods are enabled and disabled only here, with no campaign loaded (Core
     Rule 15).
   - The first time any mod is enabled, a one-time **risk notice** says that mods
     are community content, loaded at the player's own risk. The active mod list
     is always visible from the main menu.
2. **The pre-load summary** (Core Rule 13). Shown before a save whose content
   differs from the loaded set. It lists, by package:
   - what is missing, refused (including a watchdog timeout) or changed;
   - how many things will be **kept inert** (they come back if the mod returns),
     **substituted**, or **removed** because their author retired them;
   - that replays from this save will be "unverified".

   The player chooses **Continue** or **Cancel**; Cancel changes nothing.
3. **Text safety for every screen.** Mod and save text is plain text (Core Rule 14):
   - never rendered as BBCode;
   - brackets escaped before any BBCode-enabled control;
   - control, bidirectional-override and zero-width characters stripped;
   - newlines collapsed in single-line fields;
   - numbers only from the fixed placeholder list.

   Long values quoted in error messages are truncated.

Every element must be usable with the keyboard alone, and its meaning must never
rely on colour alone (project accessibility requirements).

> **📌 UX Flag — Content Data & Mod Loading**: this system has UI requirements. In
> Phase 4 (Pre-Production), run `/ux-design` for the mod screen and the pre-load
> summary **before** writing epics. Stories that reference this UI should cite
> `design/ux/[screen].md`, not this GDD.

## Cross-References

| This GDD references | Document | Section | What is relied on |
|---|---|---|---|
| Pillar 4, *Plan in the Open*; the anti-pillars | `design/gdd/game-concept.md` | Game Pillars; Anti-Pillars | "Everything the player needs to optimise is inside the game and readable once learned — no wiki"; "no hidden formulas or unexplained modifiers" |
| Pillar 5, *Living Against Made* | `design/gdd/game-concept.md` | Game Pillars | Asymmetric rule sets, kept readable |
| Mod data rules | `design/gdd/game-concept.md` | Technical Considerations | JSON or CSV against a schema, into typed classes; avoid third-party `.tres`; validate weights in the loader; stable namespaced IDs |
| Modding is later | `design/gdd/game-concept.md` | Player Motivation Profile; Retention Hooks | "a secondary channel later"; "mods later" |
| Counter taxonomy | `design/gdd/systems-index.md` | Overview; Circular Dependencies | The counter taxonomy is data here, owned by Strongholds; the Debrief reads it; the Dossier displays it |
| Content hash in headers | `design/gdd/simulation-tick-and-pause.md` | Core Rules, rule 14 | The content hash recorded in every save and replay header; a mismatch is refused or "unverified" |
| Table and permille limits | `design/gdd/deterministic-rng-and-seed-streams.md` | Core Rule 7; Formulas, D4–D5 | Weight and permille bounds this system validates |
| Stream names from mods | `design/gdd/deterministic-rng-and-seed-streams.md` | Core Rule 4; Edge Cases, Mods | Namespaces, `base:` reserved, collisions refused |
| Content IDs vs Runtime IDs; `INERT` | `design/gdd/runtime-id-service.md` | Overview; Core Rule 11 | Kinds vs instances; inert on missing content; substitution as an identity event |
| Identity ceiling | `design/gdd/runtime-id-service.md` | Formulas, D2 | 8 MB, used to size `SAVE_MAX` (D1) |
| Engine facts | `docs/engine-reference/godot/` | `breaking-changes.md`; `current-best-practices.md` | 4.7.2 `rand_weighted` rejects negative weights; 4.4 `FileAccess` return types; 4.5 `duplicate_deep()`. Everything else about JSON, CSV import, resource loading and file access is NOT SOURCEABLE (no `modules/core.md`) |

No other system GDD exists yet. Each system in Dependencies → Downstream must
cross-reference this GDD when it is written.

## Acceptance Criteria

[To be designed]

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Field-level patches for mods** (post-MVP). Which fields may be patched, one patcher per field or merge rules, how conflicts are shown, and how patches enter the hash. | game-designer, technical-director | A dedicated ADR, before modding is scheduled |
| 2 | **Images and audio in mods.** Which formats, decoded how, and with what limits, each behind its own security review. | security-engineer, technical-artist | Before modding is scheduled |
| 3 | **Who owns the mod screen and the pre-load summary**: Menus, Settings & Save UI (#51), or a separate screen? | ux-designer | When #51 is designed |
| 4 | **Which locales does the base game ship**, and is the base locale English? | producer, localization-lead | Before string tables are authored |
| 5 | **The final `SAVE_MAX`.** 32 MiB is provisional until Save/Load & Migration (#5) sums its section ceilings (D1). | Save/Load (#5) | When #5 is designed |
| 6 | **May a retired content ID be re-added later?** Proposed: yes, by removing it from `retired_ids`; instances already retired stay retired (Runtime ID Service never revives an ID). | systems-designer | Content/mod data format ADR |
| 7 | **The content/mod data format ADR:** schema language and parser; `.fctable` and the export filters; the canonical hash's exact bytes (D3); typed-class generation; read-only probes; symlink detection per platform; the lexical integer check; the translation server or a custom table. Every engine fact here is NOT SOURCEABLE. | technical-director | Before any content is authored in quantity |
| 8 | **A distribution channel for mods** (a workshop or a plain folder), and whether it changes the trust model. | producer, security-engineer | Post-MVP, with platform integration (#57) |
| 9 | **Simulation Tick & Pause amendment** at its re-review: its rule 14 header should record the package list and per-package hashes (Core Rule 12), not only one content hash. | Simulation Tick & Pause owner | Its re-review |
