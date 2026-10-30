# AI-vs-AI Runner & AI Debug Tools

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (aim error and order-rate cap; human win-rate match; worked-gated proof wins; BotView bound to HUD/Dossier at a stated known; mixed-cause fixtures; one-band cell rule; no mystery state)
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — proves every Dossier counter can win and every Debrief cause is right); Pillar 4 (Plan in the Open — calibrates the readiness range so the Dossier tells the truth)

## Summary

The AI-vs-AI Runner is Tier 0 headless test tooling. A deterministic captain bot flies the flagship and gives orders only through the player's own command path, and it proves what other GDDs promise: every no-ally counter wins, every unprepared loss names a cause, the readiness range is calibrated, and Debrief causes are right. Verdicts live only in GdUnit4 cases named after the owning GDD's acceptance criteria, and output files hold observations. Debug builds add an AI overlay, a record scrubber and a fixture loader; none of it ships to players or touches a save.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Deterministic RNG & Seed Streams, Combat Event Bus & Battle Record, Flagship Piloting, Ship AI, Fleet Coordination, Machine Nodes & Strongholds, Runtime ID Service`

## Overview

The AI-vs-AI Runner is the game's headless test bench, plus a small set of AI
debug tools for designers. It sets up a stronghold battle from data. A stand-in
**captain bot** flies the player's flagship and gives the player's fleet orders.
The bot uses only the player's command interface: the flagship's live command
(Simulation Tick & Pause rule 6) and the Fleet Orders queue (Tick rule 5). The
Runner drives `step(n)` with no frame clock (Tick rule 15), closes the Battle
Record, calls the Debrief's `classify` (After-Action Debrief rule 4), and writes
numbers to files. It hosts the gates other GDDs have placed on it: every solo
counter on every node wins (Machine Nodes rules 13, 21, 21a, 22). The
readiness band tells the truth (Machine Nodes D4, AC-17). Every Debrief cause
is the right one (Debrief AC-21, 21b, 21c, 22). The same seed gives the same
battle (Tick rule 14; Battle Record rules 15–16). It also produces the tuning
data that several Open Questions are waiting for. These are battle length and
STANDOFF kiting (Battle Resolution OQ 5), doctrine values and the "Spear leaves
gaps" check (Fleet Coordination OQ 3, AC-10), Ship AI weights and `ExecParams`
(Ship AI OQ 4), and Debrief thresholds (Debrief OQ 4). The Runner and its debug
tools are never in a player build and never touch a save.

## Player Fantasy

The player never sees the Runner, but they get what it promises. When the
Dossier says "cut the relay links", that plan has already won seven fights in
ten against this exact stronghold, flown by a captain no better than the
player. When the Debrief says "Vigor ran dry", a scripted fight built to run
the fleet dry has named that cause ten times out of ten. When the readiness
band says "Contested", fights at that band were won about half the time. Pillar
1 (every defeat is a lead) and Pillar 4 (plan in the open) are only true if
they are checked. The Runner is the check.

For the designer, the fantasy is **"show me why"**. Load a fixture and a seed,
watch the bot fight it, pause on any tick, and read every ship's reason code,
the link graph, the doctrine phase, the focus target, and the scores behind
them. Then change one value and run the suite again overnight.

## Detailed Design

### Core Rules

**A. The captain bot**

1. **The bot is a command source, not a cheat.** It implements the same
   `CommandSource` interface as the Input & Controls (#6) sampler. Each tick it
   gives the flagship one live command: move axis, aim, fire bits and ability
   bits (Tick rule 6; Flagship Piloting #15 owns what they mean). It gives fleet
   orders only through the Fleet Orders (#19) enqueue call, with the same
   validation and the same `OrderRejected` results as the player. It sets the
   pre-battle plan through the same planning call the player's screen uses.
   It has no other way into the simulation.
2. **The bot sees what the player sees.** It reads a read-only `BotView`,
   built from the HUD and Dossier presenters at a stated `known` (Machine
   Nodes D4). It holds the player's own ships in full, and enemy ships only
   through those presenters. Proofs use the `known` at which the Dossier first
   shows the counter being proven; plans may pick ships only by tags visible at
   that `known`. It never reads `SimState`, AI intents, enemy Vigor, or hidden
   doctrine fields. A static check enforces this (AC-01), and a schema test
   holds `BotView`'s fields equal to the HUD-visible list (AC-01b). Link bands
   (Coherence & Links' drawn links) and the flagship lock marker (Fleet
   Coordination rule 11) are HUD-visible, so `link_band` and `flagship_locked`
   stay in the condition set.
3. **The bot draws no random numbers.** All its choices are pure integer
   functions of `BotView`, its plan and the tick. So it never moves a battle
   stream's draw count. The only variation between seeds is the battle seed
   itself (Deterministic RNG Core Rule 2).
4. **Its commands are recorded like a player's.** Flagship commands go to the
   replay log when they change. Drained orders go to the command log (Tick
   rules 5–6; Battle Record rule 12). A Runner battle therefore replays in
   the player build's replay path, with no bot present.
5. **Skill: a steady, average captain.** The bot is not an expert. It acts on
   the world as it stood `BOT_REACT_TICKS` (12, 200 ms) ago (D7). It aims at
   that delayed position with a straight-line lead, so its aim is off against
   a target that turns. Its aim also carries a deterministic error of up to
   ±`BOT_AIM_ERR` (1,500 angle units), derived from the battle key and tick by
   hash, never from a battle stream (rule 3 holds). It reviews its plan every
   `BOT_THINK_TICKS` (30, 0.5 s), gives at most `BOT_ORDERS_PER_THINK` (2)
   orders at once, and at most `BOT_ORDERS_PER_10S` (6) in any 600 ticks.
   The `BOT_*` knobs are tuned against AC-23's human win-rate match, never by
   feel. A proof flown by a superhuman bot
   would pass counters a person cannot carry out.
6. **Headless pausing.** No pause holds are added headless (Tick rule 15). The
   bot's think cadence plays the part of the player's pauses. Triggers are
   logged, not paused.
7. **Taking the helm (debug builds only).** In a debug build a designer may
   take over from the bot at any tick. From that tick the `CommandSource` is
   the input sampler. The record notes `command_source_changed` at that tick as
   a debug-tier event. Battles where this happens are never counted by a suite.

**B. Plans and fleets are data**

8. **A plan is a data file**, `assets/data/runner/plans/<plan_id>.tres`, and
   never code. It is an ordered list of steps `{when, do, until}`. Steps are
   checked in order on each think tick, and the first step whose `when` holds
   and whose `until` does not is the active one.
   - `when` and `until` come from a closed set of conditions over `BotView`:
     `tick_ge(n)`, `enemy_seen(tag)`, `in_range(tag)`, `own_hull_share_le(pm)`,
     `flagship_locked`, `link_band(anchor, band)`, `target_dead(tag)`,
     `losses_dp_ge(pm)`.
   - `do` comes from a closed set of actions: the Fleet Orders verbs (Move,
     Hold, Escort, Focus, Retreat, at a tag, a group or a map point), plus
     flagship behaviours made of live commands: `pilot_to(point | tag)`,
     `orbit(tag, range)`, `keep_out_of_arc(tag)`, `fire_at(tag)`,
     `hold_fire`, `use_ability(id, tag)`.
   - A tag picks out ships by the counter tags, roles and weapon tags the
     player could read in the Dossier. Ties go to the lowest Runtime ID.
   - An unknown condition or action, or a reference to a counter that is not
     on the node, fails the load with `RUNNER_PLAN_INVALID`.
9. **One plan per counter, and one per engine cause.** The MVP set:
   | Plan | Used for | Gist |
   |---|---|---|
   | `default` | Unprepared fleet (rules 21a, 22) | Default doctrine; close and fight the nearest enemy; retreat at `own_hull_share_le(300)` |
   | `relay_cut` | Counter | Focus SEVERING on the nearest relay link, then the keystone |
   | `regrowth_stall` | Counter | Keep KINETIC on `regrowing` targets without a break, then burst |
   | `ward_break` | Counter | ENERGY on warded targets first, then switch |
   | `core_exposure` | Counter | Hold and Escort; flagship `keep_out_of_arc(core_breaker)` |
   | `focus_screen` | Counter | Escort the flagship; a decoy hull goes ahead when `flagship_locked` |
   | `flank_arc` | Counter | Move a group to the flank of the screen's front arc, then engage |
   | `fx_outmatched` | Debrief AC-22 | Half the reference fleet; fight to the end |
   | `fx_flagship_uncovered` | Debrief AC-22 | Flagship flies ahead alone into the rear arc of the enemy |
   | `fx_vigor_dry` | Debrief AC-22 | Organic ships fire without pause; never retreat |
   | `fx_retreat_late` | Debrief AC-22 | Order the retreat only at `losses_dp_ge(900)` |
   | `fx_no_contact` | Debrief AC-22 | Hold outside weapon range until the battle limit |
   | `kite_standoff`, `ordered_retreat` | Battle Resolution OQ 5 | Kite at max range to STANDOFF; or engage, then retreat at `losses_dp_ge(300)` |
   A mod counter brings its own plan. A mod counter without a plan cannot be
   proven, so its node gets `RUNNER_NO_PLAN`. Content validation reports this as
   a warning for mods, and as an error for `base`.
10. **The MVP reference fleet** is one data file,
    `assets/data/runner/reference_fleet.tres`. It is the player's Tier 0
    starting fleet: the flagship and escorts, the default loadouts and the
    default doctrine, with every hull and Vigor pool full and no kit and no lent
    ships. It must be the same fleet that Credits and Machine Nodes D6 price
    against (Open Question 1). It lists authored Runtime IDs and a starting
    `next_id`, so IDs match across runs (Runtime ID Service, Runner row).
11. **The counter fleet** (Machine Nodes rule 21) is the reference fleet plus
    the counter's cheapest kit by Machine Nodes D6 price. Ties go to the kit
    listed first. The kit is fitted by a fixed rule. Each item goes to the
    first ship, in ascending Runtime ID, that has a free compatible slot. If
    there is none, it replaces the default item in the first compatible slot.
    Order-only kits add their orders to the pre-battle plan. If a kit cannot be
    fitted, the counter's proof fails with `RUNNER_KIT_UNFIT`, so a counter that
    cannot be fielded never passes.
12. **No allies, ever, in a proof.** Counter fleets and reference fleets carry
    no lent ships and no helper faction. The Runner proves every no-ally
    counter wins without them (systems index, CD note on #33 Allied Lending).

**C. Battles and seeds**

13. **A battle key** is `(suite, node_id, plan_id, fleet_variant, s,
    enemy_ai_level, seed_index)`. The battle seed is
    `RUNNER_SEED_TABLE[seed_index]`, a fixed table of 64-bit seeds in data.
    Seeds are stored as decimal strings, never as JSON numbers (Tick rule 14).
    The table never changes order. Adding nodes or plans does not shift any
    other battle's seed.
14. **A battle runs to its normal end** (Battle Resolution), including
    `BATTLE_LIMIT_S`. A watchdog stops a battle that passes `RUNNER_TICK_CAP` =
    `BATTLE_LIMIT_S × TICK_RATE + RUNNER_TICK_MARGIN` (600). That is a harness
    error, not an outcome (Edge Cases).
15. **A win** is an outcome in Battle Resolution's win class. Anything else is
    a non-win. The Runner never makes up its own outcome. **In a proof (S2), a
    win counts only if the counter's `worked` predicate held** (Machine Nodes
    rule 12); a win without it is recorded as `won_without_counter` and counts
    as a non-win, so the Dossier's advice is never proven by an irrelevant
    win.
16. **After every battle**, the Runner keeps the outcome report, the record's
    event-log hash, the final `state_hash`, the per-stream draw counts, and the
    `DebriefResult` from `classify(record, report, node_counters, content)`. It
    calls the same function the game calls, headless (Debrief rules 4, 23).
17. **Workers.** Battles run in up to `RUNNER_WORKERS` (8) separate headless
    processes. Each battle is independent and built from its key alone.
    Results are merged sorted by battle key, so the output files are
    byte-identical for any worker count (AC-05).

**D. The suites**

18. **Six suites.** Each one says what it outputs, and which gate it serves.
    | Suite | Battles | What it checks | Output |
    |---|---|---|---|
    | **S1 Determinism** | `DET_FIXTURES` (6) × 3 runs | The same key run twice gives an identical per-tick `state_hash` sequence, event-log hash and `DebriefResult` bytes. A replay from the record header and command log rebuilds a byte-identical event log (Battle Record AC-09). | `determinism.json` |
    | **S2 Proofs** | D1 | Machine Nodes rules 13, 21, 21a, 22 (D5; AC-19, AC-20) | `proofs.json` |
    | **S3 Calibration** | D1 | Machine Nodes D4 / AC-17 (D2, D3) | `calibration.csv` |
    | **S4 Debrief** | 50 engine-cause fixtures and 120 mixed-cause battles, plus S2 and S3 reused | Debrief AC-21, 21b, 21c, 22 | `debrief.csv` |
    | **S5 Telemetry** | D1 | No gate. Data for Battle Resolution OQ 5, Fleet Coordination OQ 3 and AC-10, Ship AI OQ 4, Debrief OQ 4 | `telemetry/*.csv` |
    | **S6 Regression** | S1 fixtures | Golden record hashes (rule 25) | `regression.json` |
19. **Proof levels.** Proofs at `s` 1000 and 1200 use the `enemy_ai_level` of
    the Settings preset with that `s` (Open Question 2). The inverse proof uses
    `s` 500 and level 0 (Machine Nodes rule 22). Rule 21a's unprepared battles,
    and the `relay_cut` sufficiency check, use `s` 1000 at its preset level.
20. **Calibration grid** (S3). For each node, the grid covers every `s` ∈
    {500, 750, 1000, 1200} × every `enemy_ai_level` × each fleet variant ×
    `CAL_SEEDS` (10) seeds. The fleet variants are: unprepared; each listed
    counter fielded alone; all solo counters together; and `reinforced`, which
    is the reference fleet plus `REINFORCE_ESCORTS` (3) escorts, so the Ready
    band has battles in it. The battle outcome does not depend on `known`, so
    each battle is scored against the range shown at every `known` value from 0
    to 12 (D3).
21. **Degenerate checks** (S2 and S5, observations).
    - **Too easy**: the unprepared fleet wins ≥ `PROOF_WIN_MIN` at `s` 1000 on a
      node that is not the opening.
    - **One counter everywhere**: a counter that passes the proof on every node
      that lists it, including nodes where it is `supporting`.
    `NODE_RELAY_CUT_SUFFICIENT` (Machine Nodes rule 13) and the `worked` rule
    (rule 15) are gates. The others are reported; making them gates is Open
    Question 3.
22. **Debrief checks** (S4). AC-22 runs the five `fx_*` plans on the opening
    node at 10 seeds each, and each fixture states `expected_primary`. S4 also
    runs `MIXED_FIXTURES` (12) mixed-cause fixtures (two causes operating at
    once, e.g. a late retreat into held links) with a stated `expected_primary`,
    so a confidently wrong cause fails a gate (AC-24). AC-21
    reads S2's unprepared battles. AC-21b reads S2's counter-fleet battles for
    the node's first listed counter; if that counter is `supporting`, S4 runs it
    for 10 extra seeds. AC-21c counts every loss-class battle in S2, S3, S4 and
    S5 (D4).

**E. Where pass and fail live**

23. **Every verdict belongs to the GDD that owns the AC.** The Runner hosts each
    gate as one GdUnit4 test case, named after the owner's AC (for example
    `test_machine_nodes_ac_19`). That test case is the only place a verdict is
    computed. It reads the threshold from the owner's data (`PROOF_WIN_MIN`,
    `PROOF_SEEDS`, the band edges, `CAUSE_MIN_PM`), never from a copy.
24. **Files carry observations, never verdicts.** The Runner's output files and
    any summary script hold counts, rates, hashes and keys. They have no
    `pass`, `fail` or score field (CLAUDE.md: helpers emit observations, never
    verdicts). The only file with verdicts is the GdUnit4 report.
25. **The Runner's own ACs** cover only the harness: the command path,
    determinism, isolation, budgets and file formats (Acceptance Criteria).

**F. Determinism, regression and tick rate**

26. **Goldens.** Each S1 fixture has a golden entry in
    `tests/fixtures/runner/golden.json`. The entry is `{key, content_hash, os,
    arch, TICK_RATE, event_log_hash, final_state_hash}`, with hashes as hex
    strings.
    - If the build, OS, arch, `TICK_RATE` and content hash all match and a hash
      differs, the fast tier fails. The behaviour changed with no data change.
    - If the content hash differs, the golden is stale. The run reports
      `stale` and writes a candidate. `--bless` replaces the goldens, in a
      commit that references the task.
    - Goldens are kept per OS and arch, because verification is same-platform
      only (Tick rule 14).
27. **Cross-platform records** are never compared. The Runner marks them "not
    re-verified" (Battle Record rule 15; AC-10) and skips their replay check.
28. **Tick rate.** The Runner runs at the build's `TICK_RATE` and writes it to
    every manifest. There is no 60 Hz vs 30 Hz hash comparison, because a
    `TICK_RATE` change breaks replay compatibility by design (Tick rule 13).
    If the 30 Hz fallback is adopted, every golden goes stale, and S2 and S3
    must be re-run at 30 Hz before release.

**G. CI tiers and budgets**

29. **Fast tier**, on every push and PR. It runs S1, S6 and S4's AC-22
    fixtures (68 battles). Budget `FAST_BUDGET_S` (600). Its suites live in
    `tests/integration/runner/fast/` and run with the project's GdUnit4
    headless command (coding standards, CI/CD rules).
30. **Full tier**, nightly and as a release gate. It runs all six suites.
    Budget `FULL_BUDGET_S` (3,600) (D5). Its suites live in
    `tests/integration/runner/full/`, and the push job excludes that path
    (Open Question 5). A full-tier test that was not run is reported as
    "not run", never as passed.
31. **A failing proof blocks release of that node** (Machine Nodes rule 21).
    The release gate needs a green full tier on the release build and content
    hash.

**H. Debug tools (debug builds only)**

32. **AI overlay**, toggled per layer on the battle view. It shows:
    - **Reason**: each ship's latest `TargetChosen` reason code, and its top 3
      candidates with scores (Ship AI debug data);
    - **Links**: the link graph with each link's band, and snapped links
      dashed (Coherence & Links);
    - **Doctrine**: each fleet's `DoctrinePhase`, its cause, and the
      `FocusAssigned` target with a line to it (Fleet Coordination debug data);
    - **Vigor and rationing**: Vigor band, held-fire ticks and ember shots
      (Ship AI rule 14);
    - **Draws**: tie-break draw counts per stream this tick.
    Ship AI and Fleet Coordination own their debug data. The overlay only draws
    it.
33. **Scrubber.** It opens any record: live, archived or a Runner output. It
    scrubs by tick. Playback comes from `Track` samples and events, never from
    re-simulation (Battle Record rule 15), so every record plays back. For a
    verified record, **Re-simulate to here** runs headless from the header and
    command log to the chosen tick, then shows the full overlay at that tick.
    For an unverified record it reads "not re-verified" and offers playback
    only.
34. **Load.** A debug menu loads a fixture by battle key, or by a node plus a
    plan, fleet variant, `s`, `enemy_ai_level` and seed. It then runs at play
    speed with the bot, or with the designer at the helm. A loaded key gives
    the same event-log hash as the Runner's run of that key (AC-19).

**I. Isolation**

35. **Never in a player build.** Runner and debug-tool code lives under
    `src/debug/`. The release export preset excludes `res://src/debug/*` and
    `res://tests/*`. A CI check lists the release pack and fails if any Runner
    class or plan file is present (AC-10). The debug menu entry is compiled
    only in debug builds.
36. **Never touches a save.** The Runner builds battles from data and needs no
    campaign. It never calls Save/Load's write path. Its `user://` is moved to
    a temporary run folder. A CI check hashes the real `user://` saves before
    and after a run (AC-11).
36a. **No mystery state.** The Runner, the overlay and every record it writes
    never read or contain Truth Seeding, Mystery or Blame state. A static check
    finds that `src/debug/` imports no such module (AC-25). Committed records
    are readable by anyone with the repo, so this holds for them too.
37. **Outputs.** Every run writes to `production/qa/runner/<run_id>/`, where
    `run_id` is `<date>-<build>-<tier>`:
    - `manifest.json`: build, engine version, OS, arch, `TICK_RATE`, content
      hash, tier, worker count and the seed table, with seeds as strings;
    - `battles.csv`: one row per battle, holding the key, outcome, ticks,
      `end_cause`, the start-strength `R`, the primary and contributing causes
      with scores, `worked` counters, and the event-log hash;
    - the suite files from rule 18;
    - `records/`: the full Battle Record of every battle that a hosted AC
      counted against.
    CI keeps nightly runs as artifacts for `RUNNER_KEEP_RUNS` (14). Each
    release-gate run's folder is committed and kept.

### States and Transitions

| State | Entered when | Does | Exits to |
|---|---|---|---|
| IDLE | Process start | Parses arguments (suite, tier, workers, out) | LOADING |
| LOADING | Start | Loads content through Content Data validation, plans, the reference fleet and the seed table; builds and sorts the battle-key list | RUNNING; ABORTED on any validation or plan error |
| RUNNING | Keys ready | Hands keys to workers; each battle goes SETUP → FIGHTING → CLASSIFYING → STORED | REPORTING when every key is STORED; ABORTED on harness error |
| SETUP (battle) | Key assigned | Builds the fleets from the key; writes the header; runs the pre-battle plan | FIGHTING |
| FIGHTING (battle) | Battle start | `step(1)` loop; the bot acts on think ticks | CLASSIFYING at battle end; harness error at `RUNNER_TICK_CAP` |
| CLASSIFYING (battle) | Record closed | Calls `classify`; gathers hashes and draw counts | STORED |
| REPORTING | All stored | Merges by key; writes the files; GdUnit4 cases compute verdicts | DONE |
| DONE | Files written | Exit code 0 if every hosted case passed, else 1 | — |
| ABORTED | Harness error | Writes the manifest with `aborted_reason`; no suite file is written; every hosted case reports "not run" | — |

### Interactions with Other Systems

| System | Direction | Data | Ownership |
|---|---|---|---|
| Simulation Tick & Pause (#1) | Runner → #1 | `step(n)`; the per-tick `state_hash`; logged triggers | Runner owns pacing; Tick owns determinism |
| Deterministic RNG & Seed Streams | Runner → RNG | Injected battle seeds; per-stream draw counts | Runner owns seed sweeps |
| Runtime ID Service | Runner → IDs | Authored roster IDs and starting `next_id` | Runner owns scenarios |
| Combat Event Bus & Battle Record (#9) | #9 → Runner | Header, command log, event log, aggregates, event-log hash | Record owns format and verification |
| Input & Controls (#6) | Shared interface | `CommandSource`; the bot is a second implementation | Input owns the interface |
| Flagship Piloting (#15) | Runner → #15 | Live flagship command | #15 owns what a command does |
| Fleet Orders (#19) | Runner → #19 | Enqueue and pre-battle plan calls; `OrderRejected` | #19 owns order meaning and validation |
| Ship AI (#20), Fleet Coordination (#21) | #20, #21 → Runner | Debug data, reason codes, draw counts, rationing counters | They own decisions and debug data |
| Gameplay Settings & Modifiers (#7) | #7 → Runner | `s`, `enemy_ai_level`, presets | #7 owns values |
| Machine Nodes & Strongholds (#23) | #23 → Runner | Nodes, counters, kits, D4, D5, D6, gate knobs | #23 owns pass/fail of rules 13, 21, 21a, 22, AC-17 |
| After-Action Debrief (#24) | #24 → Runner | `classify`, `DebriefResult` | #24 owns pass/fail of AC-21, 21b, 21c, 22 |
| Battle Resolution & Retreat | → Runner | Outcome report, win class, `BATTLE_LIMIT_S` | BR owns outcomes |
| Content Data & Mod Loading (#4) | #4 → Runner | Validated content, content hash; `RUNNER_NO_PLAN` | #4 owns validation |
| Save/Load (#5) | None | — | The Runner never calls it (rule 36) |

## Formulas

### D1. Battles per suite

```
N_proof = Σ_nodes ( solo_n × PROOF_SEEDS × 2 + PROOF_SEEDS + PROOF_SEEDS )
N_cal   = Σ_nodes ( |S_CAL| × LEVELS × V_n × CAL_SEEDS ),  V_n = 3 + counters_n
N_fx    = ENGINE_CAUSES × FX_SEEDS
N_mix   = MIXED_FIXTURES × FX_SEEDS
N_tel   = nodes × 2 × TEL_SEEDS + DOCTRINES × TEL_SEEDS
N_det   = DET_FIXTURES × 3
```

The two lone `PROOF_SEEDS` terms in `N_proof` are rule 21a's unprepared
battles, and then either the inverse proof (first encounter) or the `relay_cut`
sufficiency check (every other node).

| Variable | Default | Range | Description |
|---|---|---|---|
| solo_n | 2 | 1 – 6 | Solo counters on node n |
| counters_n | 3 | 1 – 6 | Listed counters on node n |
| PROOF_SEEDS | 10 | 10 – 50 | Machine Nodes knob |
| \|S_CAL\| | 4 | fixed | {500, 750, 1000, 1200} |
| LEVELS | 5 | fixed | `enemy_ai_level` 0 – 4 |
| CAL_SEEDS | 10 | 5 – 30 | Seeds per calibration cell |
| ENGINE_CAUSES | 5 | fixed | Debrief rule 9 |
| FX_SEEDS | 10 | fixed | Debrief AC-22 needs 10 of 10 |
| TEL_SEEDS | 10 | 5 – 30 | Seeds per telemetry plan |
| DOCTRINES | 3 | — | Anvil, Lattice Screen, Spear |

Output: each count is ≥ 0 and grows linearly with nodes. Example, with 3 MVP
nodes of 2 solo counters and 3 listed counters each:
- `N_proof` = 3 × (2 × 10 × 2 + 10 + 10) = 3 × 60 = **180**;
- `N_cal` = 3 × (4 × 5 × 6 × 10) = 3 × 1,200 = **3,600**;
- `N_fx` = **50**;
- `N_mix` = 12 × 10 = **120**;
- `N_tel` = 3 × 2 × 10 + 3 × 10 = **90**;
- `N_det` = **18**.
The full tier totals **4,058** battles. The fast tier runs `N_det + N_fx` =
**68**.

### D2. Pooled band win rates (AC-17, first clause)

```
win_pm(band) = wins(band) × 1,000 div max(1, n(band))
```

`band` is the single D4 band of the battle at the given `known`
(Outmatched, Contested or Ready). `n(band)` counts the S3 battles that showed
that band. The output runs from 0 to 1,000. Machine Nodes AC-17 wants Ready ≥
700, Contested from 300 to 700, and Outmatched ≤ 300. An empty band gives 0
with `n = 0`. The Runner reports it as `band_empty`, and the hosted case treats
it as not met (Edge Cases). Example: 412 Contested battles with 197 wins give
197,000 div 412 = **478**, which is inside 300 – 700.

### D3. In-range check (AC-17, second clause)

The D4 range is a strength ratio, not a win rate, so the Runner maps it onto
win-rate bands before it compares. In addition, **no cell may be more than one
band outside its shown range** (a Ready-only range on a cell that wins ≤ 300 ‰
fails outright):

```
span      = { band(low), …, band(high) }        bands the shown range touches
lo_pm     = min over span of BAND_WIN_LO[b]
hi_pm     = max over span of BAND_WIN_HI[b]
cell_pm   = cell_wins × 1,000 div CAL_SEEDS
in_range  = lo_pm ≤ cell_pm ≤ hi_pm
share_pm(known) = in_range_cells × 1,000 div cells
```

| Variable | Default | Range | Description |
|---|---|---|---|
| BAND_WIN_LO / HI | Outmatched 0 / 300; Contested 300 / 700; Ready 700 / 1,000 | from AC-17 | Win-rate interval each band promises |
| low, high | D4 | 0 – 9,999 | Shown range at this `known` |
| cell_pm | — | 0 – 1,000 | Win rate of one grid cell |
| share_pm | — | 0 – 1,000 | AC-17 wants ≥ 800 at each `known` |

Example: Machine Nodes' D4 example shows 442 – 858, "Outmatched to
Contested". The span is {Outmatched, Contested}, so the interval is 0 – 700. If
the cell wins 4 of 10, `cell_pm` is 400, which is **in range**. If it wins 8 of
10, `cell_pm` is 800, which is **out of range**. This mapping is the Runner's
reading of AC-17, adopted by Machine Nodes AC-17.

### D4. UNKNOWN share (Debrief AC-21c)

```
unknown_pm = unknown_losses × 1,000 div max(1, loss_class_battles)
```

The output runs from 0 to 1,000. AC-21c wants ≤ 100. If the corpus has no
losses, the result is 0 with `n = 0`, which counts as not met. Example: 1,820
loss-class battles with 131 UNKNOWN give 131,000 div 1,820 = **71**, which
meets AC-21c.

### D5. Wall-clock budget

```
ticks_total = Σ over battles ticks_b
wall_s      = ticks_total div (HEADLESS_TPS × workers) + battles × SETUP_S_PM div 1,000
```

| Variable | Default | Range | Description |
|---|---|---|---|
| ticks_b | measured | 1 – `RUNNER_TICK_CAP` | Ticks one battle ran |
| HEADLESS_TPS | 6,000 (assumed) | measured | Ticks per second per worker on the CI machine (Open Question 4) |
| workers | 8 | 1 – 32 | `RUNNER_WORKERS` |
| SETUP_S_PM | 200 | measured | Setup and classify cost per battle, in thousandths of a second |
| wall_s | — | ≥ 0 | Must be ≤ `FULL_BUDGET_S` (3,600) or ≤ `FAST_BUDGET_S` (600) |

Example, for the full tier with a mean of 20,000 ticks (5:33 per battle):
- `ticks_total` = 4,058 × 20,000 = 81,160,000;
- that is 81,160,000 div 48,000 = 1,690 s, plus 4,058 × 200 div 1,000 = 811 s;
- `wall_s` = **2,501 s** (42 min), inside 3,600.

The worst case is every battle at the 30-minute limit, 108,600 ticks. That
gives 9,181 + 811 = **9,992 s**, which is over budget. It can only happen if
most battles stall, and that is itself a balance finding.

### D6. Kiting vs ordered retreat (Battle Resolution OQ 5)

```
cost_s(plan) = Σ over seeds skip_s(report) div TEL_SEEDS     (Debrief D5, dcp 1,000)
kite_gap_s   = cost_s(ordered_retreat) − cost_s(kite_standoff)
```

A positive `kite_gap_s` means kiting to STANDOFF is cheaper than an ordered
retreat. The Runner writes both costs, and their mean `retreated_pm`, per node.
Battle Resolution OQ 5 owns the decision ("if it does, STANDOFF is cut").
Example: the kite plan averages 86,400 s and the retreat plan 190,080 s, so
`kite_gap_s` = **103,680** (1.2 days cheaper to kite).

### D7. Bot reaction

```
view_tick(t) = max(battle_start_tick, t − BOT_REACT_TICKS)
aim(t)       = pos(target, view_tick) + vel(target, view_tick) × lead_ticks
               − pos(flagship, t − 1)
lead_ticks   = dist(flagship, target) × 1,000 div max(1, proj_speed_pm)
```

`aim` is in world units, quantized to `AIM_QUANTUM` by the normal command path
(Tick rule 6). `proj_speed_pm` is the weapon's projectile speed in thousandths
of a world unit per tick. Example: `BOT_REACT_TICKS` 12, at `t` 5,000. The bot
uses the target as seen at tick **4,988**. A target 300 units away, with
projectile speed 6,000 ‰ (6 units per tick), gets `lead_ticks` = 300,000 div
6,000 = **50**.

### D8. Proof power (tuning reference, not computed in game)

The chance that a counter with true win rate `p` passes `PROOF_WIN_MIN` (7) of
10 at one `s`, in permille: `p` 600 → **382**; `p` 700 → **650**; `p` 800 →
**879**; `p` 900 → **987**. Seeds are fixed, so a result never flakes. But a
counter with a true win rate of 80% fails one `s` about 12% of the time, and
one of the two about 23% of the time. Raise `PROOF_SEEDS` before tightening
`PROOF_WIN_MIN` (Open Question 6).

## Edge Cases

- **A kit cannot be fitted on the reference fleet**: `RUNNER_KIT_UNFIT`. The
  proof is recorded as 0 wins, and the node is blocked (rule 11).
- **A plan names a counter, tag or action the node does not have**:
  `RUNNER_PLAN_INVALID` at LOADING, and the run aborts. No partial verdicts.
- **A `base` counter has no plan**: `RUNNER_NO_PLAN` is a content error. A mod
  counter without a plan gives a warning; its node cannot be proven, and the
  run says so.
- **A battle reaches `RUNNER_TICK_CAP`**: Battle Resolution should have ended it
  at `BATTLE_LIMIT_S`. It is a harness error, and the run aborts with
  the key.
- **A battle ends in STANDOFF at the limit**: a non-win, scored like any other
  battle.
- **MUTUAL**: it counts as a win only if Battle Resolution puts it in the win
  class.
- **A worker crashes**: the key is re-run once in a fresh process. A second
  crash aborts the run. A crash is never counted as a loss.
- **The command log is truncated** (Battle Record rule 17): the replay check is
  skipped for that battle and marked `replay_truncated`. An S1 fixture that
  truncates fails S1.
- **The record is from another OS or content hash**: "not re-verified". No
  replay check runs, and it is never compared to a golden.
- **A calibration band has no battles**: `band_empty`, which counts as not met.
  The fix is more fleet variants, never a pass by default.
- **A cross-band range at the band edge** (`low` exactly 600 or `high` exactly
  1,000): `band()` follows D4's edges exactly. 600 is Contested, and 999 is
  Contested.
- **The bot's order is rejected**: it gets `OrderRejected` like a player, and it
  re-plans on the next think tick. Rejections are counted in `battles.csv`.
- **The flagship is disabled**: the bot keeps giving fleet orders. Live
  commands to a disabled flagship do nothing, as for a player.
- **The designer took the helm** (rule 7): the battle is excluded from every
  suite, even if it was loaded by key.
- **The content hash changes mid-run** (a file edited during a run): the run
  aborts, because the manifest hash must match every battle header.
- **`TICK_RATE` differs from a golden**: `stale`, not a failure (rule 28).
- **Fewer than 8 cores**: `workers` comes down. The output is unchanged
  (rule 17), and only the wall clock grows.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | `step(n)` with no driver; `state_hash`; logged triggers; `TICK_RATE` |
| Deterministic RNG & Seed Streams | Hard | Injected battle seeds; replay from a battle seed (Core Rule 2); draw counts |
| Combat Event Bus & Battle Record (#9) | Hard | Header, logs, aggregates, event-log hash, rule 15 verification |
| Runtime ID Service | Hard | Authored roster IDs, starting `next_id` (Core Rule 10) |
| Flagship Piloting (#15) | Hard | Live flagship command semantics |
| Fleet Orders (#19) | Hard | Enqueue, pre-battle plan, `OrderRejected` |
| Input & Controls (#6) | Hard | `CommandSource` interface |
| Ship AI (#20) | Hard | Reason codes, debug data, draw counts, rationing counters |
| Fleet Coordination (#21) | Hard | `DoctrinePhase`, `FocusAssigned`, debug data |
| Machine Nodes & Strongholds (#23) | Hard | Nodes, counters, kits, D4–D6, gate knobs |
| After-Action Debrief (#24) | Hard | `classify`, `DebriefResult` |
| Battle Resolution & Retreat | Hard | Outcome report, win class, `BATTLE_LIMIT_S` |
| Gameplay Settings & Modifiers (#7) | Hard | `s`, `enemy_ai_level`, preset pairings |
| Content Data & Mod Loading (#4) | Hard | Validation, content hash, plan kind |
| Coherence & Links | Soft | Link graph for the overlay |
| Save/Load (#5) | None (by rule) | Never called |
| Allied Lending (#33) | None (by rule) | Excluded from proofs |

Reverse: nothing in the game depends on the Runner at runtime. Machine Nodes,
Debrief, Battle Resolution, Fleet Coordination and Ship AI depend on it for
gates and tuning data.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `BOT_REACT_TICKS` | 12 (200 ms) | 6 – 30 | Gate | Bot skill. Lower makes proofs easier than a person would find them |
| `BOT_THINK_TICKS` | 30 (0.5 s) | 15 – 120 | Gate | How often the bot re-plans and gives orders |
| `BOT_ORDERS_PER_THINK` | 2 | 1 – 4 | Gate | Micro limit per think |
| `BOT_ORDERS_PER_10S` | 6 | 3 – 12 | Gate | Sustained order rate, human-like |
| `BOT_AIM_ERR` | 1,500 angle units | 0 – 4,000 | Gate | Aim error, so execution is not superhuman |
| `MIXED_FIXTURES` | 12 | 6 – 30 | Gate | Mixed-cause Debrief fixtures |
| `CAL_SEEDS` | 10 | 5 – 30 | Gate | Calibration noise vs CI time |
| `REINFORCE_ESCORTS` | 3 | 1 – 6 | Gate | Puts battles in the Ready band |
| `TEL_SEEDS` | 10 | 5 – 30 | Gate | Telemetry noise |
| `DET_FIXTURES` | 6 | 4 – 12 | Gate | Determinism coverage vs fast-tier time |
| `RUNNER_WORKERS` | 8 | 1 – 32 | Engineering | Wall clock only |
| `RUNNER_TICK_MARGIN` | 600 | 60 – 3,600 | Engineering | Watchdog slack |
| `FAST_BUDGET_S` | 600 | 300 – 900 | Engineering | Push CI time |
| `FULL_BUDGET_S` | 3,600 | 1,800 – 7,200 | Engineering | Nightly time |
| `RUNNER_KEEP_RUNS` | 14 | 7 – 60 | Engineering | Artifact storage |
| `RUNNER_SEED_TABLE` | 50 fixed seeds | append-only | Gate | Never reorder; only append |

The gate thresholds (`PROOF_SEEDS`, `PROOF_WIN_MIN`, the band edges and the
Debrief thresholds) are not Runner knobs. They belong to Machine Nodes and the
Debrief, and the Runner reads them from there (rule 23). All Runner knobs live
in `assets/data/runner/`.

## Visual/Audio Requirements

- Debug only. The overlay uses plain debug colours and labels, not the art
  bible's chart language, so no one mistakes it for player UI.
- Reason codes and scores are drawn as text next to each ship, and focus is
  drawn as a line. Information is never carried by colour alone.
- No audio. The Runner runs muted, headless.

## Game Feel

- For designers: load a key, see the fight within 5 seconds, and pause on any
  tick with the overlay readable.
- A full-tier failure points straight at a battle key and its saved record, so
  the bad fight can be opened in the scrubber in one step.

## UI Requirements

1. **Overlay panel**: one toggle per layer (Reason, Links, Doctrine, Vigor,
   Draws), and a ship picker that shows the top-3 score breakdown.
2. **Scrubber**: a tick slider, step ±1 and ±60, the M:SS display, a
   "not re-verified" label when it applies, and **Re-simulate to here** for
   verified records.
3. **Load menu**: battle key text field, or node, plan, fleet variant, `s`,
   level and seed pickers; **Bot** or **Helm** start.
4. Debug builds only. Keyboard and mouse are enough. No UX spec is needed
   beyond this list.

## Cross-References

| Topic | Document | Section | Use |
|---|---|---|---|
| Proofs, readiness, degenerate counter | `design/gdd/machine-nodes-and-strongholds.md` | Rules 12, 13, 21, 21a, 22; D4–D6; AC-17, 19, 20 | Hosted gates |
| `classify`, Runner ACs, calibration | `design/gdd/after-action-debrief.md` | Rules 4, 9, 23; AC-21, 21b, 21c, 22; OQ 4 | Hosted gates, tuning |
| Order queue, live command, headless, determinism | `design/gdd/simulation-tick-and-pause.md` | Rules 5, 6, 13, 14, 15 | Rule dependency |
| Header, logs, replay verification, hash | `design/gdd/combat-event-bus-and-battle-record.md` | Rules 10, 12, 15, 16, 17; AC-09, AC-10 | Data dependency |
| `BATTLE_LIMIT_S`, STANDOFF | `design/gdd/battle-resolution-and-retreat.md` | OQ 5 | Telemetry |
| Doctrine probes | `design/gdd/fleet-coordination.md` | AC-10; OQ 3 | Telemetry |
| `ExecParams`, rationing, draw counts | `design/gdd/ship-ai.md` | Rules 13, 14; OQ 4 | Telemetry, overlay |
| Seeds | `design/gdd/deterministic-rng-and-seed-streams.md` | Core Rule 2 | Rule dependency |
| Roster IDs | `design/gdd/runtime-id-service.md` | Core Rule 10 | Rule dependency |
| Allied Lending exclusion | `design/gdd/systems-index.md` | CD note on #33 | Rule 12 |
| CI command | `.claude/docs/coding-standards.md` | CI/CD Rules | Rules 29–30 |

## Acceptance Criteria

- **AC-01 (Logic; rules 1, 2)**: a static check finds that the bot module calls
  only `CommandSource`, the Fleet Orders enqueue and plan calls, and `BotView`,
  and never reads `SimState` or any AI module.
- **AC-02 (Integration; rule 4)**: a bot battle's command log, replayed in the
  player build's replay path with no bot, gives an equal event-log hash.
- **AC-03 (Logic; rule 3)**: a bot battle and the same key with the bot's
  commands fed back from the log give identical per-stream draw counts.
- **AC-04 (Logic; rule 18 S1)**: each `DET_FIXTURES` key run twice gives
  identical `state_hash` sequences, event-log hashes and `DebriefResult` bytes.
- **AC-05 (Logic; rule 17)**: the full-tier key list run with 1 worker and with 8
  workers gives byte-identical `battles.csv`, `proofs.json` and
  `calibration.csv`.
- **AC-06 (Logic; D1)**: with 3 nodes of 2 solo and 3 listed counters each, the
  key list holds 180 proof, 3,600 calibration, 50 fixture, 120 mixed-cause,
  90 telemetry and 18 determinism battles.
- **AC-07 (Logic; D3)**: range 442 – 858 with 4 of 10 wins is in range; with 8
  of 10 it is out of range; `low` 600 is Contested.
- **AC-08 (Logic; rule 24)**: a schema check finds no `pass`, `fail`, `verdict`
  or score field in any Runner output file.
- **AC-09 (Logic; rule 26)**: a changed event-log hash with matching build,
  platform, `TICK_RATE` and content hash fails the fast tier. With a changed
  content hash it reports `stale` and does not fail.
- **AC-10 (Logic; rule 35)**: the release export's pack listing contains no
  file under `res://src/debug/` or `res://tests/`.
- **AC-11 (Integration; rule 36)**: a full Runner run leaves the hashes of every
  file in the real `user://` unchanged.
- **AC-12 (Logic; rule 13)**: a seed above 2^53 survives a round trip through
  `manifest.json` unchanged, written as a decimal string.
- **AC-13 (Logic; rule 11)**: the kit-fit fixture places each item on the
  expected ship and slot. An unfittable kit gives `RUNNER_KIT_UNFIT` and 0
  wins.
- **AC-14 (Integration; edge cases)**: a worker killed mid-battle is re-run
  once. Killed twice, the run is ABORTED and every hosted case reports "not
  run".
- **AC-15 (Integration; rule 29, D5)**: the fast tier finishes within
  `FAST_BUDGET_S` on the CI reference machine.
- **AC-16 (Integration; rule 30, D5)**: the full tier finishes within
  `FULL_BUDGET_S` on the CI reference machine at `RUNNER_WORKERS`.
- **AC-17 (UI; rule 32)**: retained screenshots in `production/qa/evidence/`
  show each overlay layer on the opening stronghold fixture.
- **AC-18 (Logic; rule 33)**: an unverified record scrubs from `Track` and shows
  "not re-verified" with no re-simulate option. A verified record re-simulated
  to tick t matches the logged `state_hash` at t.
- **AC-19 (Integration; rule 34)**: a key loaded from the debug menu and run
  with the bot gives the Runner's event-log hash for that key.
- **AC-20 (Logic; D7)**: at `t` 5,000 the bot reads tick 4,988. In the D7
  fixture, `lead_ticks` is 50.
- **AC-21 (Logic; rule 12)**: no proof or calibration roster contains a lent
  ship or helper-faction ship.
- **AC-22 (Logic; rule 23)**: every hosted AC (Machine Nodes AC-17, 19, 20,
  rules 13 and 21a; Debrief AC-21, 21b, 21c, 22; Battle Record AC-09) has
  exactly one GdUnit4 case named after it. Each case reads its threshold from
  the owner's data.
- **AC-01b (Logic; rule 2)**: a schema test finds `BotView`'s field set equal to the HUD- and Dossier-visible field list at the stated `known`.
- **AC-23 (Playtest; rule 5)**: on every MVP node, the human win rate at `s` 1000 with the counter plan given as Dossier text is within ±150 ‰ of the bot's S2 win rate for that key set. The `BOT_*` knobs are tuned until it is.
- **AC-24 (Integration; rule 22)**: each mixed-cause fixture names its `expected_primary` in ≥ 9 of 10 seeds; in playtest, testers agree with the named cause in ≥ 7 of 10 human losses.
- **AC-25 (Logic; rule 36a)**: a static check finds no import of Truth Seeding, Mystery or Blame modules under `src/debug/`, and no such field in any Runner output.
- **AC-26 (Logic; rule 15)**: a proof win whose counter's `worked` never held is recorded `won_without_counter` and counted as a non-win.
- **AC-27 (Logic; D3)**: a cell more than one band outside its shown range fails S3 regardless of the 800 ‰ share.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | The exact MVP reference fleet: hulls, loadouts and doctrine. It must match the fleet Credits and Machine Nodes D6 price against ("the D5 fleet"). | game-designer, systems-designer | Before Runner implementation |
| 2 | ~~Proof `enemy_ai_level`~~ **Resolved 2026-10-30:** the preset level for that `s` (2 at 1000, 3 at 1200); rule 21a runs at `s` 1000, level 2 (Machine Nodes rules 21, 21a amended). | systems-designer | Closed |
| 3 | Should "too easy" and "one counter everywhere" become gates? ("Won without the counter" is now a gate, rule 15.) Until then they stay observations, reviewed on each full-tier run. | owner, game-designer | First full-tier run |
| 10 | Calibration covers bot fleets only (reference, counter, reinforced), not refitted player fleets. Add a `looted` fleet variant once Loot & Crafting exists. | systems-designer | When Loot & Crafting is designed |
| 11 | Art and content owners confirm that machine reason codes and doctrine fields carry no race lineage (committed records are readable). | art-director, narrative-director | Before the first committed release-gate run |
| 4 | `HEADLESS_TPS` on the CI machine is assumed (6,000). Measure it with the Tick D10 spike; if it is low, cut `CAL_SEEDS` before cutting proofs. | lead-programmer | Tick D10 spike |
| 5 | How the push job excludes `tests/integration/runner/full/` from the GdUnit4 `-a res://tests` run (an ignore flag in 4.7.2's GdUnit4 is unverified). The fallback is an environment-gated case that reports "not run". | lead-programmer | CI setup |
| 6 | D8: a true-80% counter fails a 7-of-10 proof at one `s` in 2 of 9 cases. Raise `PROOF_SEEDS` to 20 for release gates? | systems-designer, owner | Before first release gate |
| 7 | ~~Replay label~~ **Resolved 2026-10-30:** Tick rule 14 now reads "not re-verified", debug views and the Runner only (Battle Record rule 15). | lead-programmer | Closed |
| 8 | Fleet Coordination AC-10 probes ("Spear leaves gaps") need each Dossier sentence's measurable metric over `Track` (for example, an uncovered flank-arc share). Fleet Coordination should name the metric and threshold per sentence. | ai-programmer, game-designer | Before #21 approval |
| 9 | ~~Layer~~ **Resolved 2026-10-30:** Feature, as the systems index's layer table lists it (Category Meta). | producer | Closed |
