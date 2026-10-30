# Telemetry & Playtest Logging

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — playtest logs verify that defeats lead to informed returns); Pillar 2 (The Truth Is Yours to Tell — logs never record or reveal the maker to the player)

## Summary

Telemetry is an opt-in, local-only, write-only event log for Tier 0 playtests. It
records the facts the concept's pass bar needs (losses, return attempts, loadout
changes, shares and their reasons, Case File use, moderator prompts) as JSON
lines under `user://telemetry/`, and keeps hidden truth (the seeded maker,
fragment classes, rival state) in a separate sealed file that no game path and
no bug report ever reads. It never draws random numbers, never changes the
simulation, is never in the save, and never grades the player.

> **Quick reference** — Layer: `Polish` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Deterministic RNG & Seed Streams, Combat Event Bus & Battle Record, Faction Belief & Blame, Exposure & Rival Investigation`

## Overview

The Tier 0 gate asks three behavioural questions: does a tester retry after a
loss without being prompted, do they change their fleet between attempts, and
can they give a reason for a share. The concept says these are "measured by
behavioural logs", and many GDDs hand Telemetry a hook or a "logged, unscored"
item. This system is that log. It subscribes to the Combat Event Bus, to named
signals from campaign systems, and to the write-only `TelemetrySink` that
Simulation Tick & Pause already requires (Tick AC-52). It writes one JSON-lines
file per play session to the tester's own disk. A moderator can add timestamped
annotations (a prompt given, a share reason heard). An offline summary script
turns the files into per-tester observations: attempts, time from loss to next
attempt, what changed between attempts, shares with and without a reason.
Verdicts live in the Tier 0 test plan, scored by people, never in the files.
Telemetry is a playtest instrument. It is not a player feature, it has no
network path at MVP, and in a release build it is a null sink.

## Player Fantasy

The player should not feel Telemetry at all. There is no score, no streak, no
"you paused 40 times". A tester who opts in sees one small recording mark and
can stop it at any time from Settings. Nothing they do plays differently
because it is recorded.

The real users are the owner and the moderator. Their fantasy is "I can see what
happened, and I can trust it". After a session they should be able to answer,
from the files alone: "Tester T03 lost to the Spire at 14:02, opened the
Debrief, swapped two modules and changed the focus order, and was back at the
Spire seven minutes later with nobody prompting them." They should never be able
to accidentally show a tester the maker while doing so.

## Detailed Design

### Core Rules

**A. What Telemetry is**

1. **A sink, not a system.** Telemetry receives events and writes them. It owns
   no game state that any other system reads. No game system, UI screen or AI
   reads a Telemetry file, buffer or field. Only the offline tools in
   `tools/telemetry/` read the files.
2. **Write-only by construction.** All Telemetry code lives in `src/telemetry/`.
   Other modules call it only through the `TelemetrySink` interface, whose
   methods return nothing (`void`). A CI import lint fails on any read of
   Telemetry data from outside `src/telemetry/`, and on any reference to the
   `user://telemetry/` path outside it (extends Tick AC-52).
3. **Never in the simulation.** Telemetry never draws from any game RNG stream,
   never writes simulation or campaign state, never adds or removes a hold, and
   never enqueues a command. A battle replayed from its record has the same
   event-log hash with Telemetry on, off or capped.
4. **Subscribes to events, never to UI** (systems index). It listens to the
   Combat Event Bus, campaign signals and the `TelemetrySink`. It never polls a
   screen or reads a widget. The one exception is its own UI (rules 26–29).

**B. Builds, consent and privacy**

5. **Playtest builds only.** Recording code is compiled only when the export
   has the `playtest` feature tag. In any other build, `TelemetrySink` is a null
   implementation that discards every call. A CI check lists the release pack
   and fails if the recording classes are present.
6. **Opt-in, off by default.** On the first launch of a playtest build, a
   consent screen explains what is recorded and where. The default button is
   "Don't record". Recording starts only after "Record this session". The
   choice is stored in `user://telemetry/consent.json` and can be changed in
   Settings at any time. Turning it off stops writing at once.
7. **Local files only.** MVP Telemetry opens no socket, makes no HTTP request
   and uploads nothing. Files leave the machine only when the tester or
   moderator copies them by hand.
8. **No personal data.** Telemetry never records a name, email, OS user name,
   machine name, hardware ID, IP address, locale beyond the game's language
   setting, or any absolute file path (paths are written relative to
   `user://`). The tester is identified only by a moderator-entered code
   matching `^T[0-9]{2,3}$` (for example `T03`), or `T00` if none is entered.
9. **Free text is limited.** Case File notes are never logged as text, only
   their length (Case File rule 19 allows 280 and 2,000 characters; that text
   may hold anything). Two free-text fields are logged verbatim, because the
   pass bar scores them: the optional in-game "Why this share?" field (Public
   History rule 29) and moderator annotations. The consent screen says so.
   Each is cut to `TEL_TEXT_MAX` characters.

**C. Files and format**

10. **One folder.** Everything is under `user://telemetry/`:
    - `consent.json`: the opt-in choice and the tester code;
    - `sessions/<session_id>.jsonl`: the event log of one session;
    - `sealed/<campaign_tag>.jsonl`: hidden truth for one campaign (rule 18);
    - `annotations/<session_id>.jsonl`: moderator annotations added after the
      session by `tools/telemetry/annotate` (rule 22).
11. **JSON lines.** Each file is UTF-8, one JSON object per line, LF endings.
    A line is written whole or not at all. The first line of a session file is
    the header (rule 13). Every other line is an event:
    `{"seq": n, "ev": "<name>", "utc": "<ISO 8601 ms>", "mono_ms": n,
    "ctx": "<context>", "ctick": n, "btick": n|null, "p": {...}}`.
    - `seq` counts from 1 per file, with no gaps.
    - `utc` is the wall clock in UTC; `mono_ms` is monotonic time since the
      session opened. Order is by `seq`, never by `utc`.
    - `ctx` is the Tick context (`CAMPAIGN`, `BATTLE`, `MENU`).
    - `ctick` is the campaign tick; `btick` the battle `tick_index` (Tick
      dependency row), or null outside battle.
    - IDs, hashes and seeds-derived values are strings; counts are integers.
12. **Event names** use `category.object.action` in lower snake case (for
    example `battle.attempt.started`). The emitting GDD's signal name is listed
    beside each event in the event table (rule 15).
13. **Header and identifiers.** The header line is `{"schema": 1, "session_id",
    "tester", "build": {...}, "opened_utc", "session_index"}`.
    - `session_id`: 16 hex characters from `Crypto.generate_random_bytes(8)`.
      This is the OS random source, not a game stream (rule 3).
    - `build`: game version, git short hash, engine version string,
      `TICK_RATE`, content global hash and the active package list (Content
      Data dependency row).
    - `session_index`: 1 + the number of session files already present for this
      tester code, so "same or next session" is a count, not a guess.
    - `campaign_tag`: the first 16 hex characters of SHA-256 over the campaign
      seed string. It appears on every campaign event. It links one campaign's
      attempts across sessions without storing the seed, and is not in the save.
14. **Bounded files.** A session file stops growing at `TEL_MAX_FILE_BYTES`
    (D1). At the cap, Telemetry writes one `telemetry.cap.reached` line and
    stops writing for that session. Retention is rule 25.

**D. What is recorded (Tier 0 event list)**

15. **The Tier 0 event list.** This GDD owns it (concept: "the Tier 0 telemetry
    event list → the Tier 0 test plan"). Events are recorded only if listed.

    | Event | Source | Payload (`p`) | Serves |
    |---|---|---|---|
    | `session.lifecycle.opened` / `closed` | #54 | close reason (`quit`, `consent_off`, `cap`, `crash_recovered`) | All |
    | `campaign.lifecycle.created` | Campaign step | `campaign_tag`, preset id, Ironman flag | Linking |
    | `save.slot.loaded` / `saved` | Save/Load | slot index, `campaign_tag`, campaign tick, `is_suspend` | Reload-retries (Save OQ 4) |
    | `settings.modifier.changed` | Settings `MODIFIER_CHANGE` | key, old, new | Context |
    | `battle.attempt.started` | Battle start | `battle_id`, node id, `attempt_no` for this node, `loadout` snapshot (rule 16) | Pass bar 1, 2 |
    | `battle.attempt.ended` | Battle Resolution | `battle_id`, outcome, win class, `end_cause`, duration ticks, player ships lost | Pass bar 1 |
    | `battle.vigor.summary` | Vigor | per ship: EMPTY count, ticks at FLOOR, end % of `C0` | Vigor AC-15 |
    | `battle.time.summary` | `TelemetrySink` | hold ms by reason, step count, ms at each speed | Research only (rule 20) |
    | `debrief.view.shown` | Debrief | primary cause id, contributing ids, counter named, win class | Debrief AC-24 |
    | `dossier.page.opened` / `closed` | Dossier | node id, open ms | Informed return |
    | `refit.change.committed` | Refit `refit_committed(diff)` | ship id, slot, old, new | Pass bar 2 |
    | `fleet.roster.changed` | Fleet screens | added / removed ship ids and hull ids | Pass bar 2 |
    | `orders.plan.committed` | Fleet Orders | the pre-battle order set | Pass bar 2 |
    | `casefile.view.opened` / `closed` | Case File | open ms | Case File AC-26 |
    | `casefile.aid.changed` | Case File | kind (`pin`, `doubt`, `note`), fragment id or `case`, note length | Case File rule 20 |
    | `belief.action.committed` | #49 / Case File `belief_action_committed` | action kind, target kind, verdict before and after, `casefile_opened_since_grant`, `casefile_opened_since_last_share`, reason text or null | Pass bar 3 |
    | `fragment.find.granted` | Archive Fragments | fragment id, source kind | Context |
    | `poi.site.searched` | POI `PoiSearched` | POI id | POI AC-17 |
    | `escort.loan.changed` | Allied Lending `OwnerChanged`, `LentShipLost` | kind (`joined`, `returned`, `lost`), faction, ship id | Allied Lending AC-19 |
    | `escort.share.linked` | Allied Lending | share or keep that gained or kept an escort | Allied Lending AC-19 |
    | `exposure.player.exposed` | #32 `investigator_found{exposed}` when shown to the player | fragment id, verdict exposed | Exposure AC-23 |
    | `telemetry.time.dropped` | Tick | dropped ms | Data quality |
    | `telemetry.cap.reached` | #54 | bytes | Data quality |
    | `moderator.note.added` | Annotation overlay | kind, text (rule 21) | Pass bar 1, 3 |

16. **Loadout snapshot.** `battle.attempt.started` carries the player side at
    the first tick: each ship's Runtime ID, hull id, owner (`PLAYER` or the
    lending faction), and fitted weapon and module ids by slot; and the
    pre-battle order set. It is built from the battle header, so it costs no
    extra read of live state.
17. **Only what the player could see.** The session log holds only facts the
    player can see or did. Fragment ids appear; fragment class, axis and value
    do not. Verdicts are the player's, not the truth. Rival investigator leads,
    retargets and idles are not in the session log.

**E. Hidden truth (Pillar 2)**

18. **The sealed file.** At campaign creation, Telemetry writes
    `sealed/<campaign_tag>.jsonl` once: the maker, the candidate list, each
    fragment's id, class and axis, and any fallback-build flag (Truth Seeding
    rules 10, 14). During play it appends the hidden #32 signals
    (`investigator_lead`, `investigator_retargeted`, `investigator_idle`,
    `investigator_found`). It reads these from the signals and from the
    `base:truth_case` data once, through a read-only accessor owned by Truth
    Seeding.
19. **Who sees the sealed file.** No game path reads it. No bug-report bundle
    includes it. The moderator does not open it during a session. Only the
    analyst (the owner at MVP) joins it to session logs, offline, after the
    tester's last session on that campaign. `tools/telemetry/summarise` reads
    it only with `--unseal`, and its default output contains no sealed field.

**F. Pause, speed and step**

20. **Recorded, never graded** (Tick rule 18). Hold, speed and step data arrive
    only through `TelemetrySink` and are written only as
    `battle.time.summary`, one line per battle. The summary script prints them
    in a separate "research" block with no ranking, threshold or comparison
    between testers. Nothing in a playtest or release build shows them to the
    player.

**G. Moderators**

21. **Live annotations.** In a playtest build, `TEL_ANNOTATE_KEY` (F9) opens a
    one-line overlay with four kinds: `PROMPT` (the moderator prompted an
    action), `SHARE_REASON` (the tester's spoken reason, typed verbatim),
    `BREAK` (the tester stepped away) and `NOTE`. Enter writes
    `moderator.note.added` with the current stamps. The overlay adds no hold
    and sends no input to the game while it has focus.
22. **Post-session annotations.** For remote sessions, `tools/telemetry/annotate`
    adds lines to `annotations/<session_id>.jsonl` from the moderator's notes,
    each with a `utc` stamp. The session file is never edited.
23. **A prompt is a prompt.** Any `PROMPT` annotation between a loss and the
    next attempt on that node marks that retry "prompted" in the summary. A
    moderator who prompts must log it.

**H. Observations and retention**

24. **Summaries carry observations, never verdicts** (CLAUDE.md; Runner rule 24).
    `tools/telemetry/summarise` writes per-tester tables: attempts by node,
    D2 time to retry with the session gap, the prompted flag, D3 change
    categories, shares with reason present, Case File opened before each
    share, escort events, Vigor counts. It has no `pass`, `fail` or score
    field. The rubric score and the gate verdict are recorded by people in the
    Tier 0 test plan.
25. **Retention.** On session open, Telemetry deletes session and annotation
    files older than `TEL_KEEP_DAYS`, then the oldest beyond
    `TEL_KEEP_SESSIONS`. Sealed files are deleted when no session file names
    their `campaign_tag`. Settings has "Open telemetry folder" and "Delete all
    telemetry", which deletes everything under `user://telemetry/` except
    `consent.json`. Copies the moderator made are covered by the Tier 0 test
    plan, not by the game.

**I. Telemetry UI (playtest builds only)**

26. **Consent screen**, first launch only (rule 6), with the tester code field.
27. **Recording mark.** While recording, a small neutral "REC" mark sits in the
    screen corner. It never changes with anything the player does.
28. **Settings rows**: record on/off, tester code, open folder, delete all.
29. **Annotation overlay** (rule 21).

**J. Save and bug reports**

30. **Not in the save.** Telemetry writes no save section and adds no bytes to a
    save. Loading a save does not restore any Telemetry state.
31. **Bug reports.** A bug-report bundle may include the header and the last
    `TEL_BUNDLE_TAIL` lines of the current session file, plus Runtime IDs
    (Runtime ID dependency row). It never includes the sealed folder (Truth
    Seeding rule 12).
32. **The Runner is separate.** The AI-vs-AI Runner writes its own debug-only
    outputs to `production/qa/runner/` (Runner rule 37). Telemetry does not
    read, write or merge them.

### States and Transitions

| State | Entered when | Does | Exits to |
|---|---|---|---|
| NULL | Non-playtest build | Discards every call | — |
| CONSENT_PENDING | Playtest build, no `consent.json` | Shows the consent screen; records nothing | OFF; RECORDING |
| OFF | Consent declined or turned off | Discards every call; shows no mark | RECORDING when turned on |
| RECORDING | Consent given | Opens the session file, writes the header, buffers and flushes events | OFF; CAPPED; FAILED; CLOSED on quit |
| CAPPED | File reaches `TEL_MAX_FILE_BYTES` | Writes `telemetry.cap.reached`; discards further events this session | CLOSED |
| FAILED | Any file error | Discards events; sets a Settings line "Recording stopped: disk error" | CLOSED |
| CLOSED | Quit or consent off | Flushes, writes `session.lifecycle.closed` if possible | — |

No state changes simulation, campaign or save state.

### Interactions with Other Systems

| System | Direction | Data | Ownership |
|---|---|---|---|
| Simulation Tick & Pause (#1) | #1 → #54 | `TelemetrySink`: hold reasons, speed, steps; `tick_index`; "time dropped" | Tick owns the sink interface; #54 owns the writer |
| Deterministic RNG & Seed Streams | None | #54 draws no stream | RNG owns streams |
| Combat Event Bus & Battle Record (#9) | #9 → #54 | Header (loadout snapshot), battle start and end | #9 owns events |
| Battle Resolution & Retreat | → #54 | Outcome, win class, `end_cause` | BR owns outcomes |
| After-Action Debrief (#24) | #24 → #54 | `DebriefResult` cause ids, counter named | #24 owns causes |
| Refit & Loadout (#35) | #35 → #54 | `refit_committed(diff)` | #35 |
| Port & Fleet Management Screens | → #54 | Roster changes | Screens |
| Fleet Orders (#19) | #19 → #54 | Pre-battle order set | #19 |
| Dossier | → #54 | Page open and close | Dossier |
| Case File & Deduction | → #54 | Open, close, pin, doubt, note length | Case File |
| Public History Screen (#49) | #49 → #54 | `belief_action_committed`; reason text | #49 |
| Faction Belief & Blame (#30) | via #49 | Verdict before and after | #30 |
| Exposure & Rival Investigation (#32) | #32 → #54 | Shown exposure to session log; hidden signals to sealed file | #32 |
| Truth Seeding | Truth → #54 | One read-only read of the case at creation, sealed file only | Truth owns the case |
| Archive Fragments, POI | → #54 | Grant and search ids | Owners |
| Allied Lending (#33) | #33 → #54 | `OwnerChanged`, `LentShipLost`, share-escort link | #33 |
| Vigor | → #54 | Per-battle counters | Vigor |
| Gameplay Settings (#7) | #7 → #54 | `MODIFIER_CHANGE` | #7 |
| Save/Load (#5) | #5 → #54 | Load and save notices | #5; #54 writes nothing to a save |
| Runtime ID Service, Content Data (#4) | → #54 | IDs, package list, global hash | Owners |
| AI-vs-AI Runner (#25) | None | Separate outputs | Runner |

## Formulas

### D1. Session file size

`B_session = B_header + N_events × b_avg`, capped at `TEL_MAX_FILE_BYTES`.
`N_events = E_h × H`.

| Variable | Meaning | Range |
|---|---|---|
| `B_header` | Header bytes | 300 – 1,500 |
| `E_h` | Events per hour of play | 200 – 1,500 (no per-tick events) |
| `H` | Session length, hours | 0.5 – 4 |
| `b_avg` | Mean bytes per line | 150 – 600 (loadout lines are largest) |

Worked example (2-hour session, `E_h` 600, `b_avg` 220, header 1,000):
600 × 2 = 1,200 events; 1,200 × 220 = 264,000; + 1,000 = **265,000 bytes**
(about 259 KiB). The cap of 8,388,608 bytes holds 8,387,608 / 220 = 38,125
lines, 38,125 / 600 = about 63 hours at this rate, so a normal session never caps.

### D2. Disk bound

`B_disk_max = TEL_KEEP_SESSIONS × TEL_MAX_FILE_BYTES` (plus small annotation
and sealed files). With 50 and 8,388,608: **419,430,400 bytes = 400 MiB**,
worst case. Typical: 50 × 265,000 = 13,250,000 bytes, about 12.6 MiB.

### D3. Time to retry

For a loss L on node n and the next `battle.attempt.started` A on node n in the
same `campaign_tag`:
`retry_s = utc(A) − utc(battle.attempt.ended of L)`, in whole seconds;
`session_gap = session_index(A) − session_index(L)`;
`prompted = any PROMPT annotation with utc in (utc(L end), utc(A))`.

Worked example: loss ends `14:02:10.000`, next attempt `14:09:40.000`, same
session, no annotation between. `retry_s` = 9:40 − 2:10 = 7 min 30 s = **450**;
`session_gap` **0**; `prompted` **false**. The summary prints these three
values. Whether 0 or 1 counts as "same or next session" is the test plan's call.

### D4. Change between attempts

For attempts A1 and A2 on one node, from their loadout snapshots:
- `roster_diff = ships(A2) Δ ships(A1)` (symmetric difference of Runtime IDs);
- `refit_diff` = the (ship, slot) pairs present in both whose fitted id differs;
- `orders_diff` = the order set of A2 ≠ the order set of A1.

`changed_categories` = the non-empty ones of {roster, refit, orders}.

Worked example: A1 ships {101, 102, 103}, A2 {101, 102, 104}: `roster_diff` =
{103, 104}. Ship 101 slot 2 goes `mod_ablative` → `mod_insulated`: one refit
pair. Order sets equal. `changed_categories` = **{roster, refit}**. The summary
prints the list; it does not judge whether the change was "informed".

### D5. Write cost and loss window

Events are buffered and flushed on a worker thread every `TEL_FLUSH_MS` or at
`TEL_FLUSH_LINES`, whichever comes first. The most a crash can lose is one
flush window: at `E_h` 600, 2,000 ms holds 600 × 2 / 3,600 = 0.33 events on
average, so **at most a few lines** in a busy burst. Main-thread cost per event
is one serialise and append to the buffer, budgeted at `TEL_FRAME_BUDGET_US`.

## Edge Cases

- **Consent turned off mid-battle**: writing stops at once; `session.lifecycle.closed`
  with `consent_off` is written; the battle is unaffected.
- **Consent turned on mid-campaign**: a new session opens; the first battle has
  no prior attempt in the log, so D3 and D4 begin from the next pair.
- **Crash or force-kill**: the last partial line is dropped on next open (each
  line is whole or absent); the next session writes `session.lifecycle.opened`
  with `crash_recovered` naming the previous `session_id`.
- **Disk full or read-only folder**: state FAILED; the game plays on; Settings
  shows the error line. No retry loop.
- **File cap reached**: CAPPED (rule 14). Later events in that session are lost
  and the summary prints "capped at seq N".
- **Battle restarted from a suspend or save reload**: logged as a new
  `battle.attempt.started` after `save.slot.loaded`. The summary shows the load
  between them; whether it counts as a retry is the test plan's call (Save OQ 4).
- **Two campaigns in one session**: events carry `campaign_tag`, so attempts
  never pair across campaigns.
- **Same seed started twice**: same `campaign_tag`. The summary splits them by
  `campaign.lifecycle.created` lines.
- **Tester code left blank**: `T00`. `session_index` then mixes testers; the
  summary warns "T00 sessions present".
- **Clock change or DST**: `utc` is UTC; a backward jump makes D3 negative, and
  the summary prints the negative value with "clock moved" rather than fixing it.
- **Share with the reason field off**: `reason` is null; the moderator's
  `SHARE_REASON` annotation is the evidence (Public History OQ).
- **Empty reason with the field on**: logged as `""` (Public History edge case).
- **Annotation overlay open when a battle ends**: the overlay stays open; the
  note gets the stamps at Enter.
- **Release build calls the sink**: the null sink discards it at no file cost.
- **Truth fallback build used**: the sealed header flags it; the session log
  does not.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | `TelemetrySink`; `tick_index`; "time dropped" |
| Combat Event Bus & Battle Record (#9) | Hard | Battle header, start and end events |
| Faction Belief & Blame (#30), Public History (#49) | Hard | `belief_action_committed` |
| Exposure & Rival Investigation (#32) | Hard | Investigator signals |
| Refit & Loadout (#35) | Hard | `refit_committed` |
| Deterministic RNG & Seed Streams | Hard (negative) | #54 must not draw; campaign seed string for `campaign_tag` |
| Runtime ID Service | Soft | IDs in snapshots and bug bundles |
| Truth Seeding | Soft | Read-only case accessor for the sealed file |
| After-Action Debrief, Dossier, Case File, Fleet Orders, Fleet Screens, Battle Resolution, Allied Lending, Vigor, Archive Fragments, POI, Settings, Save/Load, Content Data | Soft | Events in rule 15 |
| Menus, Settings & Save UI | Soft | Settings rows (rule 28) |

Reverse: every system above lists #54 or needs a row added (Open Question 6).
Nothing depends on #54 at runtime: removing it changes no game behaviour.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `TEL_MAX_FILE_BYTES` | 8,388,608 | 1 – 64 MiB | Gate | Per-session cap (D1) |
| `TEL_KEEP_SESSIONS` | 50 | 10 – 500 | Gate | Disk bound (D2) |
| `TEL_KEEP_DAYS` | 90 | 14 – 365 | Gate | Retention |
| `TEL_FLUSH_MS` | 2,000 | 250 – 10,000 | Feel | Crash loss window (D5) |
| `TEL_FLUSH_LINES` | 64 | 8 – 512 | Feel | Burst flush |
| `TEL_FRAME_BUDGET_US` | 200 | 50 – 1,000 | Feel | Main-thread cost per frame |
| `TEL_TEXT_MAX` | 500 | 100 – 2,000 | Gate | Reason and note length |
| `TEL_BUNDLE_TAIL` | 500 | 0 – 5,000 | Gate | Lines in a bug bundle |
| `TEL_ANNOTATE_KEY` | F9 | any unbound key | Feel | Moderator overlay |

All live in `assets/data/telemetry/telemetry.json`. None affects gameplay.

## Visual/Audio Requirements

- The "REC" mark is a small, neutral, low-contrast glyph in a corner, the same
  in every context. No colour, pulse or sound tied to player actions.
- The consent screen and annotation overlay use standard menu styling. No audio.

## Game Feel

Invisible. Telemetry must not cause a hitch: no file write on the main thread,
no frame over `TEL_FRAME_BUDGET_US` of Telemetry work. A tester who records and
one who does not play the same game, tick for tick.

## UI Requirements

- **Consent screen** (first launch, playtest builds): what is recorded, where,
  that two free-text fields are kept verbatim, that nothing is uploaded; tester
  code field; "Don't record" is the default focus.
- **Settings rows**: record toggle, tester code, open folder, delete all (with
  a confirm), error line when FAILED.
- **Recording mark** (rule 27).
- **Annotation overlay** (rule 21): kind selector, one text line, Enter writes,
  Esc cancels. Keyboard only is enough.
- No Telemetry data is ever displayed in any game screen.

## Cross-References

| Topic | Document | Section | Use |
|---|---|---|---|
| Pass bar and its definitions | `design/gdd/game-concept.md` | MVP Definition | Source of D3, D4 and rule 15 |
| Pause never graded; `TelemetrySink` | `design/gdd/simulation-tick-and-pause.md` | Rule 18; AC-52, AC-52b | Rule 20 |
| Observations, not verdicts; isolation | `design/gdd/ai-vs-ai-runner-and-ai-debug-tools.md` | Rules 24, 35–37 | Rules 5, 24, 32 |
| Case stored plainly; no shareable path | `design/gdd/truth-seeding-and-candidates.md` | Rules 12, 14 | Rules 18, 19, 31 |
| Share event and reason field | `design/gdd/public-history-screen.md` | Rule 29; AC-21; OQ | Rule 15, 21 |
| Case File aids | `design/gdd/case-file-and-deduction.md` | Rules 19, 20; AC-26 | Rules 9, 15 |
| Exposure signals | `design/gdd/exposure-and-rival-investigation.md` | Interactions; AC-23 | Rules 15, 18 |
| Escort AC | `design/gdd/allied-lending.md` | AC-19 | Rule 15 |
| Vigor counters | `design/gdd/vigor.md` | AC-15 | Rule 15 |
| Debrief causes | `design/gdd/after-action-debrief.md` | Rules 25, 27; AC-24 | Rule 15 |
| Refit diff | `design/gdd/refit-and-loadout.md` | Interactions | Rule 15 |
| Reload retries | `design/gdd/save-load-and-migration.md` | OQ 4 | Edge Cases |

## Acceptance Criteria

- **AC-01 (Logic; rule 3)**: one seed and command log played twice, Telemetry RECORDING then NULL, give identical event-log hashes and final state hashes.
- **AC-02 (Logic; rule 3)**: with Telemetry RECORDING for a full battle, every RNG stream's draw count equals that of a NULL run.
- **AC-03 (Logic; rules 1, 2)**: the import lint fails on a planted read of Telemetry data from `src/` outside `src/telemetry/` and on a planted `user://telemetry/` string, at `tests/fixtures/lint/telemetry/bad_read.gd`; it passes on the clean tree.
- **AC-04 (Logic; rule 5)**: the release export pack contains no recording class; the CI pack listing fails when one is planted.
- **AC-05 (Logic; rule 6)**: on first launch of a playtest build with no `consent.json`, no file is created under `sessions/` until "Record this session" is chosen; choosing "Don't record" creates none.
- **AC-06 (Logic; rule 7)**: a static check finds no `HTTPRequest`, `HTTPClient`, `StreamPeerTCP`, `PacketPeerUDP` or `WebSocketPeer` reference in `src/telemetry/`.
- **AC-07 (Logic; rules 8, 9)**: a session with a Case File note "Alice at 12 Elm St" writes the note length and not the text; no line holds the OS user name or an absolute path (checked against the test machine's values).
- **AC-08 (Logic; rules 11, 13)**: every line of a fixture session parses as JSON; the first is a header with `schema` 1; `seq` runs 1..N with no gaps; `session_id` is 16 hex characters.
- **AC-09 (Logic; rule 13)**: two campaigns from one seed string share a `campaign_tag`; different seeds differ; no file holds the seed string.
- **AC-10 (Logic; rule 14; D1)**: with `TEL_MAX_FILE_BYTES` set to 4,096 in a fixture, the file never exceeds 4,096 bytes, ends with `telemetry.cap.reached`, and the game keeps running.
- **AC-11 (Logic; rule 16; D4)**: the D4 worked example fixture gives `changed_categories` {roster, refit}; identical snapshots give the empty list.
- **AC-12 (Logic; D3)**: the D3 worked example fixture gives `retry_s` 450, `session_gap` 0, `prompted` false; adding a PROMPT annotation at 14:05:00 gives `prompted` true.
- **AC-13 (Logic; rules 17, 18)**: in a fixture campaign, no session-file line contains the maker's race id, any fragment class or axis, or an `investigator_lead` signal; the sealed file contains all of them.
- **AC-14 (Logic; rule 31)**: a bug-report bundle built during a recording session contains no file from `sealed/`.
- **AC-15 (Logic; rule 19)**: `summarise` without `--unseal` prints no sealed field; with it, joins the maker by `campaign_tag`.
- **AC-16 (Logic; rule 24)**: `summarise` output for the fixture set contains no field or column named `pass`, `fail`, `score` or `verdict`.
- **AC-17 (Logic; rule 20)**: hold, speed and step data appear only in `battle.time.summary` lines; the summary prints them only in the research block, unsorted by value.
- **AC-18 (UI; rule 20)**: with recording on, no screen in a playtest build shows a pause, speed or step count or any Telemetry value (screenshot pass of Debrief, port, Case File, Settings, end screens in `production/qa/evidence/`).
- **AC-19 (Logic; rule 30)**: a save written with Telemetry RECORDING is byte-identical to one written with it NULL at the same tick.
- **AC-20 (Logic; rule 25)**: with `TEL_KEEP_SESSIONS` 3 and five session files, opening a new session deletes the oldest files first until three older files remain, plus the new one; sealed files with no referencing session are removed; "Delete all" leaves only `consent.json`.
- **AC-21 (Logic; Edge Cases)**: a session file truncated mid-line is read by `summarise` with the partial line dropped and a warning, and the next session's open line has `crash_recovered`.
- **AC-22 (Integration; rule 15)**: a scripted Tier 0 route (lose at a stronghold, read the Debrief and Dossier, refit, change orders, share with a reason, return) produces every event in rule 15 that the route touches, in order.
- **AC-23 (UI; rules 21, 27)**: the REC mark is visible in every context while recording and absent when OFF; F9 opens the overlay, Enter writes one `moderator.note.added`, and the battle tick count during the open overlay matches a run without it (screenshots retained).
- **AC-24 (Logic; D5)**: in a 10-minute battle fixture, no frame spends more than `TEL_FRAME_BUDGET_US` in Telemetry code on the main thread, and no file write occurs on the main thread.
- **AC-25 (Playtest; concept pass bar)**: for every Tier 0 tester, the moderator can produce from the files alone each attempt pair's `retry_s`, `session_gap`, `prompted` and `changed_categories`, and each share's reason source (field or annotation), without opening the sealed file.
- **AC-26 (Playtest; rule 6)**: every Tier 0 tester can say, after reading the consent screen, what is recorded and that nothing leaves their machine.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **The sealed maker file is acceptable**: it exists only in playtest builds,
  outside every in-game and shareable path (Truth Seeding rule 12 amended), and
  only an analyst opens it offline with `--unseal`.
- **UTC timestamps are kept**: files are local and opt-in, and D3 needs them
  across sessions.
- **A "loss" is any loss-class outcome** (Battle Resolution rule 1: retreat,
  defeat, standoff).
- **A reload is not a retry**: it is logged as its own event, and the test
  plan reports both.
- **Layer**: `Polish`, per the systems index layer table (category Meta).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 5 | **Live or post-session annotations by default?** F9 is fastest in person; remote sessions need the script. | qa-lead | Tier 0 test plan |
| 6 | **Reverse dependency rows** in Debrief, Dossier, Fleet Orders, Fleet Screens, Battle Resolution, Allied Lending, Vigor, Archive Fragments, POI, Settings, Save/Load, Truth Seeding, Menus; and the systems-index deps column. | each owner | `/review-all-gdds` |
| 8 | **Escort–share link.** Allied Lending AC-19 needs "changes or keeps a share to gain or keep the escort". Can #33 emit that link, or must the moderator annotate it? | Allied Lending owner | #33 amendment |
| 9 | **Age and consent.** Are any Tier 0 testers minors, and is a written consent form needed beyond the in-game screen? | owner | Before Tier 0 playtest |
| 10 | **Post-MVP upload.** Any networked telemetry is out of MVP scope and needs its own privacy review and GDD revision. | owner | Early Access planning |
