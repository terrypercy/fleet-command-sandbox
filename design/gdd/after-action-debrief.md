# After-Action Debrief

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — every loss names a cause and a counter, with an honest "unknown"); Pillar 4 (Plan in the Open — the Debrief feeds the Dossier from recorded evidence)

## Summary

The After-Action Debrief opens on the frame a battle ends and names one primary cause of the player's losses, plus up to two contributing causes, each with a counter-action and the record evidence that proves it, or an honest "Cause unknown". Classification is one pure integer function of the closed Battle Record, so the AI-vs-AI Runner can verify it. The Debrief also defines the bounded defeat day cost (1–7 days at Standard), hands the Dossier what the battle showed, never grades pause, and never touches the hidden truth.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Combat Event Bus & Battle Record, Battle Resolution & Retreat, Machine Nodes & Strongholds, Simulation Tick & Pause, Runtime ID Service`

## Overview

The After-Action Debrief opens on the frame a battle ends. It reads the closed
Battle Record and the Battle Outcome report, and nothing else. It names one
primary **cause** of the player's losses and at most two contributing causes.
Each cause comes with a **counter-action**, or with the plain statement that no
counter is known yet. A cause is drawn from two pools. The first is the
node's counters (Machine Nodes & Strongholds rule 12), each named only when its
evidence predicate held. The second is five engine causes: outmatched, flagship
struck from an uncovered arc, Vigor ran dry, retreat too late, and (STANDOFF
only) no contact. When no cause clears its threshold, the Debrief says
"Cause unknown" and lists the facts it does have. Classification is one pure
integer function of the record, so the AI-vs-AI Runner (#25) can check it. The
Debrief also computes the defeat's day cost (D5), which the World Clock (#8)
applies and Credits (#18) bills. It hands the Dossier (#47) what the battle
showed. The result is computed once, saved, and re-shown identically. It never
grades pause or speed, and it never reads or hints at the seeded maker. Several
GDDs call this system "Defeat & Debrief"; it is the same system.

## Player Fantasy

*"Varrow was cut off from the line at 3:12. Their links held: cut the relay
links."* The player lost, and now they know why. The Debrief is the voice of a
fleet's after-action clerk: dry, exact and on the player's side. It points at
one thing to change, says what that thing is, and shows the marks in the record
that prove it. When it does not know, it says so and shows the evidence it has.
It never guesses and never blames luck.

Target aesthetics (MDA): **Challenge** (the loss becomes a solvable problem),
**Discovery** (the enemy's pattern is revealed by fighting it) and a little
**Narrative** (the record tells the battle back in names and times).

- **Pillar 2, The Truth Is Yours to Tell (top pillar):** the Debrief explains
  battles, never the case. Nothing it reads, says or hands on varies with the
  seeded maker (rule 26).
- **Pillar 1, Every Defeat Is a Lead:** the design test is "can the Debrief name
  at least one specific, actionable cause and counter for this loss?" Rules 7–15
  answer it, and rule 21a of Machine Nodes guarantees a cause on every
  unprepared stronghold loss. The second test: defeat costs time or resources,
  never the run or understanding. D5 bounds the time.
- **Pillar 5:** "links held" and "Vigor ran dry" are the two made-vs-organic
  lessons, and both are first-class causes.
- **Pillar 4, Plan in the Open:** every cause cites record evidence by tick and
  name, and the Dossier fills in from it.
- **Pillar 3:** the flagship's blind side is a named cause, from Flagship
  Piloting's loss context.

What the player must never feel: graded ("C rank"), blamed for pausing, told
"bad luck", or misled by a confident wrong cause. A wrong cause is worse than
"unknown" (concept, risk register).

## Detailed Design

### Core Rules

**A. Inputs and timing**

1. **Inputs are fixed.** The Debrief reads exactly: the closed Battle Record
   (header, roster, record-tier events, end-of-battle aggregates; Combat Event
   Bus & Battle Record rules 10–14), the Battle Outcome report (Battle
   Resolution & Retreat rule 17), the battle node's `dossier.counters[]` and
   those counters' content (Machine Nodes rules 9–12, 18), and the frozen
   `ModifierSet` in the record header. It reads no live simulation state, no
   command log, no campaign state other than these, and no Truth Seeding,
   Archive Fragment or Case File data.
2. **When it runs.** Battle Resolution delivers the report in ascending system
   number (Battle Resolution rule 16). The Debrief's slot is after Machine
   Nodes (#23). By then the record is closed, the World Clock has queued the
   defeat skip and Credits has applied the bill. The Debrief computes its
   result in that slot, in the same atomic battle-end step, before any frame
   is drawn.
3. **The hold.** `PLANNING:debrief` is added by Simulation Tick & Pause's
   atomic battle-end step, on the frame the battle ends (Tick rule for
   planning holds; Battle Resolution rule 16). The Debrief owns removing it. No
   campaign tick runs and the World Clock does not advance while it stands
   (Tick AC-38).
4. **The classifier is pure.** `classify(record, report, node_counters,
   content) → DebriefResult` uses integers only, draws no random numbers, and
   iterates ships in ascending Runtime ID and events in log order. The same
   inputs give a byte-identical result. The Runner calls the same function
   headless.

**B. Losses and causes**

5. **A loss** is a player-side ship (lent ships included) with a hull-zero `Disabled` event in the record,
   whether recovered or left behind (Battle Resolution rule 22; player ships are
   disabled, never destroyed). A ship that left by retreat is not a loss. `L` is
   the set of losses; `loss_DP` is their summed DP (D1).
6. **Two scoring bases.** If `loss_DP > 0`, causes are scored against the
   losses (**loss basis**). If `loss_DP = 0` on a loss-class battle (a STANDOFF,
   or a retreat before any ship fell), causes are scored against the enemy DP
   still present at the end (**survival basis**; D2b).
7. **Counter causes.** Each counter in the node's `dossier.counters[]` is a
   candidate (a roaming fleet uses its home node's list). It is **eligible**
   only if its `evidence` predicate (the cause-polarity predicate, Machine
   Nodes rule 12) held in the
   record (Machine Nodes rule 11) and its score (D2) is at least
   `CAUSE_MIN_PM` (150). A counter with a predicate the engine does not know is
   never a candidate (it fails validation first).
8. **Kill-window linkage.** A loss is linked to a counter cause when the
   attackers in its `KillWindow` that **match** the counter dealt at least
   `LINK_SHARE_PM` (500) of the window's damage. An attacker matches if its
   hull's counter tags, its anchor's doctrine fields, or the tags of the weapon
   that hit share an entry with the counter's `affects[]`. For `focus_screen`,
   the loss must also be the flagship with a `FocusAssigned` on it inside the
   window (Fleet Coordination rule 12).
9. **Engine causes.** Five causes need no counter content. Each has a fixed
   predicate and score (D3):
   | ID | Cause shown | Predicate | Counter-action |
   |---|---|---|---|
   | `outmatched` | "outmatched" | start strength ratio `R0 < OUTMATCHED_PM` | "return with more strength", plus the node's first `solo` counter if any |
   | `flagship_uncovered` | "flagship struck from the uncovered {sector}" | flagship in `L` with loss context `covered = false` (Flagship Piloting rule 13) | "cover the flagship's {sector} with a group arc" |
   | `vigor_dry` | "Vigor ran dry" | a loss whose ship's `VigorBand → EMPTY` precedes its `Disabled` by at most `KILL_WINDOW` (Battle Record rule 14) | from the largest erosion source (rule 13) |
   | `retreat_late` | "retreat came too late" | outcome DEFEAT or PLAYER_RETREATED, and at least one loss after the retreat deadline (D4) | "order the retreat by {M:SS}" |
   | `no_contact` | "the fleets never closed" | STANDOFF and zero damage dealt and taken by player ships | "close inside weapon range, or leave" |
   `{sector}` is bow, flank or rear from the bearing (D3c). `vigor_dry` is
   suppressed when `core_exposure` is eligible, because that counter already
   names "Vigor ran dry" with a sharper action.
10. **Ranking.** Eligible causes sort by score, highest first. Ties break by
    a fixed order: counter causes in `dossier.counters[]` order, then
    `flagship_uncovered`, `vigor_dry`, `retreat_late`, `outmatched`,
    `no_contact`. The first is the **primary** cause. The next, up to
    `CAUSE_MAX_CONTRIB` (2), are **contributing** causes (D4b).
11. **Unknown.** If no cause is eligible, the primary cause is `unknown`. The
    Debrief says "Cause unknown" and shows facts only: the three attackers with
    the most damage on player losses (by name from the roster), the damage-type
    mix they dealt, and the Coherence band the enemy anchor spent most time in.
    It infers nothing from these. `unknown` is a valid result, never an error.
12. **Every cause cites evidence.** Each named cause carries at most
    `EVIDENCE_LINES_MAX` (3) evidence lines: an event, its battle time
    `(tick − battle_start_tick) ÷ TICK_RATE` as M:SS, and the names involved,
    from the roster (Battle Record rule 11). Example: "Links held: *Varrow* cut
    off at 3:12; the keystone's band stayed full to the end."

**C. Counter-actions**

13. **Every cause is paired.** A counter cause shows its `action_key`. An engine
    cause shows its action from rule 9. `vigor_dry` takes its action from the
    largest `VigorCeilingEroded.by_source` summed over its linked ships (Vigor
    rule 14), and names the core that lost the most:
    | Largest source | Action |
    |---|---|
    | spend | "ration fire before the push" |
    | ember | "hold ember fire" |
    | membrane | "keep the membrane out of the breaker's reach" (wording: OQ 7) |
    | core strike | "turn a fresh flank; the {core} took every hit" |
    If Ship AI's rationing counters show held fire at LOW or EMPTY for at least
    `RATION_NOTE_PM` (250) of the linked ships' time alive, one evidence line
    says so ("your line held fire 40 % of the engagement at LOW Vigor"; Ship AI
    rule 14).
14. **What the fleet already carries.** For a counter cause, the Debrief checks
    the roster's slot → weapon content against the counter's `exploited_by[]`
    damage types (Battle Record rule 14, `dmg_type_mask`). It adds one line:
    "*Kestrel*'s battery is ENERGY" or "No ship carried ENERGY". This is a fact,
    not a shop link.
15. **Honest gaps.** If a cause has no action (a mod counter whose
    `action_key` resolves to nothing at display), the Debrief shows "No known
    counter yet". If the counter has `requires_allies` true, it names the
    node's `helper_faction_id`; the lending terms are Faction Reputation's.
16. **Odds.** If an evidence event of a named cause records a roll whose stream
    declares an `odds_surface`, the odds are cited next to the counter as
    `p / 10` percent (Deterministic RNG, UI Requirements 2). The Debrief never
    names luck as a cause.

**D. Outcome classes**

17. **Loss class** (PLAYER_RETREATED, DEFEAT, STANDOFF): header, primary cause,
    contributing causes, costs (day cost, bill, Vigor erosion), and the
    Dossier note (rule 22). STANDOFF names the stalemate's cause the same way,
    usually on the survival basis (Battle Resolution rule 5).
18. **Win class** (VICTORY, ENEMY_WITHDREW): header, then "What it cost": the
    top-ranked cause over the player's losses, if any is eligible, labelled
    "Costliest" not "Cause", with its action. If `L` is empty: "No ships lost".
    If a `NodeBroken` event exists, one line names its `cause_counter`
    ("Broken by: relay cut") or "Broken" when none. No day cost; no bill.
19. **MUTUAL** (win class by `MUTUAL_TO_PLAYER`): the banner reads "Pyrrhic
    victory" (Battle Resolution AC-24) and the Debrief shows the full loss-class
    cause block, because the whole fleet fell.
20. **The opening loss** (`opening_loss` true): the full loss-class Debrief,
    under the line "Nothing was lost". The costs block becomes "What this would
    have cost": the D5 day cost computed as if `opening_loss` were false, the
    Credits bill Credits reports it would have charged, and the Vigor erosion
    reported with `restored = true` (Vigor rule 18), naming its largest source.
    Each figure is struck through. Onboarding (#53) owns any tutorial copy around
    it.

**E. Costs**

21. **The day cost.** The Debrief defines `defeat_skip_s(report, ModifierSet)`
    (D5), a pure function. It does not apply it. The World Clock calls it in its
    own delivery slot (#8) and queues one skip of that length, which runs when
    the Debrief closes (World Clock rule 13; never chained, never above
    `DEFEAT_MAX_S`). Credits calls the same function in its slot (#18) for the
    upkeep part of the bill. Because both call one pure function, delivery
    order does not matter. The Debrief shows the queued skip and Credits'
    final bill; it never recomputes the bill.

**F. Hand-offs**

22. **To the Dossier.** The result carries a `DossierFacts` block, handed to the
    Dossier (#47) when the Debrief closes:
    - `counters_evidenced[]`: every node counter whose predicate held, with
      the tick it first held and whether it was named as a cause;
    - `doctrine_observations[]`: each `DoctrinePhase` transition and
      `FocusAssigned` seen, as `{anchor, doctrine_id, event, tick}` (Fleet
      Coordination rule 3: every field has a reveal event);
    - `node_facts`: node ID, `attempt_index`, outcome, whether the keystone
      broke, and the lowest keystone hull share reached (permille).
    The Dossier owns which of these become visible lines and when. The Debrief
    reveals nothing by itself.
23. **To the Runner.** The Runner reads `DebriefResult` for each fixture battle.
    The Debrief owes it: the primary cause ID, the contributing IDs, the scores,
    and the evidence ticks.

**G. Screen, determinism and save**

24. **Flow.** End banner for `END_BEAT_MS` (Battle Resolution) → the Debrief
    opens on the primary cause. One page. **Continue** (or Esc/B) closes it at
    any time; there is no minimum read time. Closing removes `PLANNING:debrief`
    and hands `DossierFacts` on. A **Timeline** toggle lists every evidence
    line of every named cause in tick order. An animated chart replay is not
    MVP; the Timeline list is the Tier 0 form of the concept's "annotated
    chart marks", and a static chart with evidence marks is Vertical Slice.
25. **Computed once, stored, re-shown.** The `DebriefResult` is stored in the
    save under `battle_id`, with names, numbers and display keys resolved to
    text at compute time (Runtime ID Service rule 8: names are labels kept at
    the time). Reopening it, from the Dossier or after a load, shows the stored
    result. It is never recomputed, even if content or mods change. The save
    keeps the last `DEBRIEF_KEEP` (30) results; older ones drop, and their
    Dossier facts are already handed on. A save made while the hold stands
    restores with the Debrief open.
26. **Truth-neutrality guarantee (Pillar 2).** The Debrief reads no Truth
    Seeding, fragment, Case File, exposure or blame data. It never mentions
    fragments; Archive Fragments (#28) owns any grant notice. Its text uses only
    roster names and counter or engine keys. Two saves with different seeded
    makers, the same battle seed and the same command log give byte-identical
    results.
27. **Pause is never graded** (Simulation Tick & Pause rule 18). The Debrief
    reads no hold, speed or step data. No score, rating, grade, star, achievement
    or label comes from it.
28. **Difficulty never touches the explanation** (Gameplay Settings rule 9).
    The settings key `defeat_cost_permille` (accepted here: presets 500 / 1000 /
    1500, range 250 – 2000, floor above 0) scales only the day cost (D5) and,
    through Credits, the bill. No modifier changes candidates, predicates,
    thresholds, scores, ranking, evidence, actions or `DossierFacts`.
    `rest_days_permille` is handed off: it scales rests, which the World Clock
    and Ports, Rest & Care (#27) own. `DEFEAT_COST_FLOOR` is measured per cost:
    1 day (`DEFEAT_FLOOR_S`, 86,400 s) for the day cost, 1 credit for the bill.

### States and Transitions

**Debrief screen**

| State | Entered when | Leaves to |
|---|---|---|
| CLOSED | default; or Continue pressed | COMPUTING (a battle ends) |
| COMPUTING | Battle Resolution delivers the report to #24 (same atomic step) | OPEN |
| OPEN | result stored; first frame after the end banner | CLOSED (Continue); TIMELINE (toggle) |
| TIMELINE | Timeline toggled | OPEN (toggle back); CLOSED (Continue) |
| REVIEW | a stored result opened from the Dossier (no hold, no hand-off) | CLOSED |

The hold `PLANNING:debrief` stands through COMPUTING, OPEN and TIMELINE. REVIEW
adds its own ordinary planning hold and never re-sends `DossierFacts`.

**Result**

| State | Meaning |
|---|---|
| NAMED | primary cause is a counter or engine cause |
| UNKNOWN | no cause eligible (rule 11) |
| CLEAN | win class with `L` empty |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | both | Tick adds `PLANNING:debrief` on the end frame; #24 removes it on close; never reads pause data (rule 27) |
| Deterministic RNG (#2) | #2 → #24 | `odds_surface` of streams for rule 16; the classifier draws nothing |
| Gameplay Settings (#7) | #7 → #24 | `defeat_cost_permille` via the frozen `ModifierSet` |
| World Clock (#8) | #24 → #8 | `defeat_skip_s` (D5); #8 queues and applies the skip |
| Combat Event Bus & Battle Record (#9) | #9 → #24 | Roster, record-tier events, kill windows, aggregates, `CoherenceSummary`, `DoctrineSummary` |
| Vigor (#13) | #13 → #24 (via #9) | `VigorBand`, `VigorCeilingEroded(by_source, by_core, restored)` |
| Flagship Piloting (#15) | #15 → #24 (via #9) | Loss context `(bearing, covered)` |
| Credits (#18) | both | #18 calls D5 for upkeep days; #24 shows the final bill and the opening's would-be bill |
| Ship AI (#20) | #20 → #24 (via #9) | Rationing counters; `TargetChosen` never needed (rule 12 uses record-tier events only) |
| Fleet Coordination (#21) | #21 → #24 (via #9) | `DoctrinePhase`, `FocusAssigned`, `DoctrineSummary` |
| Battle Resolution (#22) | #22 → #24 | The report: outcome, `end_cause`, `retreated_pm`, lists, `last_player_loss`, `opening_loss` |
| Machine Nodes (#23) | #23 → #24 | `dossier.counters[]`, counter content, `NodeBroken.cause_counter` |
| Runtime ID Service | → #24 | IDs and tombstones; names kept at the time |
| AI-vs-AI Runner (#25) | #24 → #25 | `classify` headless; `DebriefResult` for checks |
| Dossier (#47) | #24 → #47 | `DossierFacts` on close; reopen stored results |
| Audio (#52) | #24 → #52 | Open event with outcome class and result state |
| Onboarding (#53) | #24 → #53 | The opening-loss presentation (rule 20) |
| Save/Load | both | Stored results (rule 25) |

## Formulas

All maths is integer. `div` truncates. Permille values run 0 – 1,000.

### D1. Losses

```
L       = { player ships with Disabled(cause_code = hull_zero) }
loss_DP = Σ DP(s) for s in L
```

| Variable | Range | Description |
|---|---|---|
| DP(s) | 1 – 60 | Ship's deployment points (Battle Resolution) |
| loss_DP | 0 – `deployed_DP` | Basis for D2a and D3 |

### D2. Counter-cause score

**D2a. Loss basis** (`loss_DP > 0`):

```
match_pm(s, c) = matched_dmg(s, c) × 1,000 div max(1, window_dmg(s))
linked(s, c)   = match_pm(s, c) ≥ LINK_SHARE_PM
score(c)       = (Σ DP(s) for s in L where linked(s, c)) × 1,000 div loss_DP
```

**D2b. Survival basis** (`loss_DP = 0`, loss class):

```
score(c) = (Σ DP(e) for e in enemy_present_at_end matching c) × 1,000
           div max(1, Σ DP(e) for e in enemy_present_at_end)
```

| Variable | Range | Description |
|---|---|---|
| window_dmg(s) | 0 – any | All damage in `s`'s `KillWindow` |
| matched_dmg(s, c) | 0 – window_dmg | Damage by attackers matching `c` (rule 8) |
| LINK_SHARE_PM | 300 – 700 | Share needed to link a loss |
| score(c) | 0 – 1,000 | Eligible if ≥ `CAUSE_MIN_PM` and the predicate held |

Example (loss basis): losses of DP 20, 30, 30, 40; `loss_DP` = **120**.
Network-fed attackers dealt ≥ 500 ‰ in the windows of the 20, 30 and 30
ships: `relay_cut` = 80 × 1,000 div 120 = **666**. Warded attackers dealt
≥ 500 ‰ in the windows of one 30 ship and the 40 ship: `ward_break` = 70,000
div 120 = **583**. Both predicates held, both ≥ 150: both eligible.

### D3. Engine-cause scores

**D3a. `outmatched`.** `R0 = str_player0 × 1,000 div max(1, str_enemy0)`,
strengths at battle start by Machine Nodes D3 (`Σ hull_max × dps_rating div
1,000`, from the roster's content). Predicate `R0 < OUTMATCHED_PM`.
`score = (OUTMATCHED_PM − R0) × 1,000 div OUTMATCHED_PM`.
Example: 3,000 vs 6,000 → R0 = **500**; score = 100,000 div 600 = **166**.

**D3b. `flagship_uncovered`.**
`score = min(1,000, DP(flag) × 1,000 div loss_DP + FLAGSHIP_BONUS_PM)`.
Example: flagship DP 40 of 120: 40,000 div 120 = 333; + 250 = **583**.

**D3c. Sector.** Bearing `b` in 0 – 65,535 relative to heading (Flagship
Piloting AC-14 uses 32,768 for dead astern). `bow` if `b ≤ 8,192` or
`b ≥ 57,344`; `rear` if `24,576 ≤ b ≤ 40,960`; else `flank`.
Example: `b` = 32,768 → **rear**.

**D3d. `vigor_dry`.** `score = (Σ DP(s) for linked s) × 1,000 div loss_DP`,
where `s` is linked if `VigorBand → EMPTY` at tick `t_e` and `Disabled` at
`t_d` with `0 ≤ t_d − t_e ≤ KILL_WINDOW`.

**D3e. `no_contact`.** Score **1,000** when its predicate holds.

### D4. Retreat deadline and ranking

**D4a. Deadline.**

```
T_half   = first tick where Σ DP of losses so far × 1,000 ≥ LATE_LOSS_PM × deployed_DP
deadline = T_half + RETREAT_GRACE_S × TICK_RATE
score    = (Σ DP(s) for s in L with t_d(s) > deadline) × 1,000 div loss_DP
```

If `T_half` never occurs, the predicate fails.
Example: `deployed_DP` 166, `LATE_LOSS_PM` 500 → threshold 83,000 ‰·DP.
Losses reach 90 DP at tick 10,800 (`battle_start_tick` 0): 90,000 ≥ 83,000, so
`T_half` = **10,800**. Deadline = 10,800 + 30 × 60 = **12,600** (3:30). A
40-DP ship disabled at tick 13,000 is linked: score = 40,000 div 120 = **333**.
Shown: "order the retreat by 3:30".

**D4b. Ranking.** Sort eligible causes by `score` descending, then by rule 10's
order. Primary = first. Contributing = next `CAUSE_MAX_CONTRIB`.
Worked example, combining D2–D4a on one battle: `relay_cut` 666, `ward_break`
583, `flagship_uncovered` 583, `retreat_late` 333, `outmatched` 166. The tie at
583 goes to the counter cause. Primary **relay_cut**; contributing
**ward_break**, **flagship_uncovered**. The other two are not shown as causes;
their evidence stays in the Timeline only if a named cause cites it.

### D5. Defeat day cost

```
if outcome is win class or opening_loss:   skip_s = 0
else:
  base_s = DEFEAT_BASE_S + DEFEAT_SPAN_S × (1,000 − retreated_pm) div 1,000
  eff_s  = (base_s × dcp + 500) div 1,000                 (Settings D2)
  skip_s = min(DEFEAT_MAX_S, max(DEFEAT_FLOOR_S, eff_s))
```

| Variable | Default | Range | Description |
|---|---|---|---|
| retreated_pm | report | 0 – 1,000 | Share of the fleet brought home (Battle Resolution D4; STANDOFF counts those present) |
| DEFEAT_BASE_S | 86,400 (1 day) | 0 – 172,800 | Cost of any loss, even a clean retreat |
| DEFEAT_SPAN_S | 518,400 (6 days) | 0 – 518,400 | Extra cost scaled by the share left behind |
| dcp | 1,000 | 250 – 2,000 | `defeat_cost_permille` |
| DEFEAT_FLOOR_S | 86,400 (1 day) | fixed | `DEFEAT_COST_FLOOR` in days |
| DEFEAT_MAX_S | 1,209,600 (14 days) | World Clock | Hard ceiling |
| skip_s | — | 0 – `DEFEAT_MAX_S` | Requested skip, seconds |

Load-time check: `(DEFEAT_BASE_S + DEFEAT_SPAN_S) × 2,000 div 1,000 ≤
DEFEAT_MAX_S`, so the clamp never bites at legal settings. Defaults: 604,800 × 2
= 1,209,600, exactly the ceiling.

Example (Battle Resolution AC-17: PLAYER_RETREATED, `retreated_pm` 481), dcp
1,000: base = 86,400 + 518,400 × 519 div 1,000 = 86,400 + 269,049 =
**355,449 s** (4.11 days). eff = (355,449,000 + 500) div 1,000 = **355,449**.
skip = **355,449 s**. Credits' upkeep part at `U_day` 600: 355,449 × 600 div
86,400 = **2,468** credits.
Full DEFEAT at dcp 1,000: 604,800 s (**7 days**); at dcp 2,000: **1,209,600** =
`DEFEAT_MAX_S`.
Full retreat at dcp 250: base 86,400; eff = 21,600 → floored to **86,400**.
A clean full retreat at dcp 1,000 costs exactly **1 day**: scouting a
stronghold you expect to lose stays cheap (concept: players attack a
stronghold they know they might lose).

## Edge Cases

- **Loss class with no losses** (early full retreat): survival basis (D2b).
  If nothing is eligible, `unknown`, with the facts of rule 11.
- **`deployed_DP` 0 or `loss_DP` 0 in a divisor**: every divisor is
  `max(1, …)` or guarded by the basis switch; no division by zero.
- **A loss with no `KillWindow`** (record overflow): it links to no counter
  cause and still counts in `loss_DP`. The Debrief never infers a link.
  Record-tier events are not dropped (Battle Record rule 17), so this is a
  defect signal; the Runner flags it.
- **Two causes tie on score**: rule 10's fixed order (D4b example).
- **Battle with no node** (faction fight, ambush): no counter candidates; engine
  causes only.
- **Roaming fleet battle**: counter candidates come from its home node's list
  (OQ 2).
- **Flagship retreated or present**: not a loss; `flagship_uncovered` cannot
  hold.
- **Flagship disabled by a hit inside a group arc**: `covered = true`; no
  cause. The flagship's DP still counts in other causes.
- **`core_exposure` and `vigor_dry` both hold**: `vigor_dry` is suppressed
  (rule 9).
- **Keystone broken but loss class**: loss-class Debrief; a "Broken by" line
  appears too (rule 18 line), so the player sees the node fell.
- **Opening loss with a win**: cannot happen; `opening_loss` is false on a win
  (Battle Resolution rule 19). The Debrief is an ordinary win Debrief.
- **Mod removes a counter after the battle**: the stored result shows its stored
  text (rule 25).
- **Save during the hold, then load**: the Debrief reopens with the stored
  result; `DossierFacts` is handed on once, on close.
- **A day-cost request above `DEFEAT_MAX_S`**: impossible at legal settings
  (load check); the clamp makes it impossible anyway. World Clock refuses one as
  a programmer error (World Clock AC-17b).
- **Skip interrupted** by an `interrupts_skip` event: World Clock keeps the
  remaining target; the cost is unchanged.
- **Unverified replay environment**: irrelevant to the MVP Debrief, which never
  replays; it reads the recorded log. Badge wording conflict: OQ 5.
- **Degenerate: "always retreat at once"**. A clean retreat still costs
  `DEFEAT_BASE_S` (1 day) and still yields a Debrief, often on the survival basis.
  Fleeing early is cheaper than a wipe, which is intended (Battle Resolution
  rule 18), but never free.
- **Degenerate: farming Dossier facts by suicide runs.** Each attempt costs at
  least 1 day and a bill; the node fully resets (Machine Nodes rule 6). Facts
  repeat, so a second identical loss reveals nothing new.
- **Degenerate: "outmatched" as a catch-all.** Its score scales with the gap
  and ties lose to counter causes, so it is primary only when the gap is the
  biggest story.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | `PLANNING:debrief` hold; rule 18 |
| Deterministic RNG (#2) | Soft | `odds_surface` for rule 16 |
| Gameplay Settings (#7) | Hard | `defeat_cost_permille`; rule 9 |
| World Clock (#8) | Hard (reverse) | Calls D5; applies the skip |
| Combat Event Bus & Battle Record (#9) | Hard | Roster, events, kill windows, aggregates |
| Vigor (#13) | Soft | Band and erosion events |
| Flagship Piloting (#15) | Soft | Loss context |
| Credits (#18) | Hard (both) | Calls D5; final and would-be bill |
| Ship AI (#20) | Soft | Rationing counters |
| Fleet Coordination (#21) | Soft | Doctrine events and summary |
| Battle Resolution (#22) | Hard | The report and delivery order |
| Machine Nodes & Strongholds (#23) | Hard | Counters, predicates, `NodeBroken` |
| Runtime ID Service | Hard | IDs, tombstones, names kept at the time |
| Save/Load | Hard | Stored results |
| AI-vs-AI Runner (#25), Dossier (#47), Audio (#52), Onboarding (#53) | Hard (reverse) | `classify`, `DossierFacts`, open event, opening presentation |

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `CAUSE_MIN_PM` | 150 | 50 – 300 | Curve | How strong evidence must be to name a cause. Too low names noise; too high says "unknown" too often |
| `CAUSE_MAX_CONTRIB` | 2 | 1 – 3 | Feel | Contributing causes shown. More than 3 buries the lead |
| `LINK_SHARE_PM` | 500 | 300 – 700 | Curve | Damage share that links a loss to a counter |
| `OUTMATCHED_PM` | 600 | 400 – 800 | Curve | Strength gap that counts; mirrors Machine Nodes `BAND_LOW` |
| `FLAGSHIP_BONUS_PM` | 250 | 0 – 500 | Curve | Extra weight of losing the flagship |
| `LATE_LOSS_PM` | 500 | 300 – 700 | Curve | Loss share that starts the retreat clock |
| `RETREAT_GRACE_S` | 30 sim s | 10 – 90 | Feel | Time allowed to order a retreat after `T_half` |
| `RATION_NOTE_PM` | 250 | 100 – 500 | Feel | Held-fire share that earns an evidence line |
| `EVIDENCE_LINES_MAX` | 3 | 2 – 5 | Feel | Evidence per cause |
| `DEFEAT_BASE_S` | 86,400 (1 d) | 0 – 172,800 | Gate | Floor cost of any loss |
| `DEFEAT_SPAN_S` | 518,400 (6 d) | 0 – 518,400 | Gate | Extra cost for ships left behind |
| `DEBRIEF_KEEP` | 30 | 10 – 100 | Gate | Stored results per save (save size) |

Constraint: `(DEFEAT_BASE_S + DEFEAT_SPAN_S) × 2 ≤ DEFEAT_MAX_S` (D5 load
check). All knobs live in `assets/data/`. None is a difficulty modifier.

## Visual/Audio Requirements

- Ink-on-dark-paper chart language, as the concept's Debrief and tactical
  overlay (art bible owns the look).
- The primary cause is the largest text on the page; contributing causes are
  smaller, under it.
- Evidence lines show battle time (M:SS) and ship names; struck-through costs on
  the opening loss.
- No grade, star, rank or warning-red verdict anywhere.
- Audio (#52) gets one open event: `{outcome_class, result_state}` (NAMED,
  UNKNOWN, CLEAN, OPENING). Audio owns the cues; no cue may imply a grade.

## Game Feel

- The Debrief arrives on the beat: banner `END_BEAT_MS`, then the cause.
- The first thing read is the cause and the action, in one line each. Facts
  come second.
- "Cause unknown" reads as calm and honest, not as an error.
- Continue is always one press away. Reading it is the player's choice.

## UI Requirements

1. **Header**: outcome banner ("Pyrrhic victory" on MUTUAL), `end_cause`,
   "N of M brought home" from `retreated_pm`, flagship status.
2. **Cause card**: cause text, action text, up to `EVIDENCE_LINES_MAX`
   evidence lines, the carried-weapon fact (rule 14), odds if any (rule 16).
3. **Contributing**: up to `CAUSE_MAX_CONTRIB` compact cards.
4. **Costs**: day cost in days and hours (World Clock), final bill and any
   forgiven excess (Credits rule 7), Vigor erosion and its largest source.
5. **Dossier note**: "Dossier updated" when `DossierFacts` is non-empty; the
   Dossier owns the wording of what changed.
6. **Timeline** toggle and **Continue**. Keyboard and pad both work; text
   respects `ui_scale`.
7. UX spec: `design/ux/debrief.md` (to be authored with `/ux-design`).

## Cross-References

| Topic | Document | Section | Use |
|---|---|---|---|
| Debrief contract, aggregates, kill windows | `design/gdd/combat-event-bus-and-battle-record.md` | Rules 11, 13, 14, 17 | Data dependency |
| Report, delivery order, opening loss | `design/gdd/battle-resolution-and-retreat.md` | Rules 5, 16–19, 22; D4 | Data dependency |
| Counters, predicates, `NodeBroken`, rule 21a | `design/gdd/machine-nodes-and-strongholds.md` | Rules 9–13, 16, 18, 21a; D3 | Data dependency |
| Hold, pause never graded | `design/gdd/simulation-tick-and-pause.md` | Rule 18; AC-38 | Rule dependency |
| Defeat skip, `DEFEAT_MAX_S` | `design/gdd/world-clock.md` | Rule 13; OQ 6 | Resolves OQ 6 |
| Defeat bill | `design/gdd/credits-upkeep-and-sinks.md` | Rule 7; D2 | Interface |
| `defeat_cost_permille`, floor, rule 9 | `design/gdd/gameplay-settings-and-modifiers.md` | Rule 9; D2; AC-17; OQ 6 | Accepts key |
| Erosion by source, opening restore | `design/gdd/vigor.md` | Rules 14, 18; AC-17 | Data dependency |
| Loss context | `design/gdd/flagship-piloting.md` | Rule 13; AC-14 | Data dependency |
| Reason codes, rationing | `design/gdd/ship-ai.md` | Rule 14 | Data dependency |
| Doctrine events | `design/gdd/fleet-coordination.md` | Rules 3, 12 | Data dependency |
| Odds citing | `design/gdd/deterministic-rng-and-seed-streams.md` | UI Requirements 2 | Rule dependency |
| Pillar 1 test | `design/gdd/game-concept.md` | Game Pillars | Design test |

## Acceptance Criteria

- **AC-01 (Logic; rule 4)**: `classify` run twice on the same record gives a
  byte-identical `DebriefResult`.
- **AC-02 (Logic; rule 26, Pillar 2)**: two saves with different seeded makers,
  the same battle seed and command log give byte-identical results and
  `DossierFacts`.
- **AC-03 (Logic; rule 27)**: the same battle played unpaused, with 200 pauses,
  at 0.5× and with 30 single steps gives identical results (Tick AC on
  pause-blindness).
- **AC-04 (Logic; rule 7)**: a counter whose score is ≥ 150 but whose predicate
  did not hold is never named.
- **AC-05 (Logic; D2a)**: the D2 fixture gives `relay_cut` 666 and `ward_break`
  583.
- **AC-06 (Logic; D3a, D3b)**: the fixtures give `outmatched` 166 and
  `flagship_uncovered` 583.
- **AC-07 (Logic; D3c)**: bearings 0, 8,192, 8,193, 24,576, 32,768, 40,961 and
  57,344 give bow, bow, flank, rear, rear, flank, bow.
- **AC-08 (Logic; D4a)**: the fixture gives `T_half` 10,800, deadline 12,600,
  score 333 and the text "3:30".
- **AC-09 (Logic; D4b, rule 10)**: the combined fixture names `relay_cut`
  primary, then `ward_break` and `flagship_uncovered`, in that order.
- **AC-10 (Logic; rule 11)**: a fixture where no cause reaches 150 gives
  UNKNOWN with the three top attackers by damage and no cause text.
- **AC-11 (Logic; rule 9)**: when `core_exposure` is eligible, `vigor_dry` is
  never shown.
- **AC-12 (Logic; rule 13)**: a `vigor_dry` fixture whose linked ships' largest
  erosion source is ember shows "hold ember fire".
- **AC-13 (Logic; rule 6, D2b)**: a STANDOFF with no losses scores on the
  survival basis; with zero damage both ways it names `no_contact`.
- **AC-14 (Logic; D5)**: `retreated_pm` 481 at dcp 1,000 gives 355,449 s; a clean full retreat at dcp 1,000 gives 86,400 s; full
  DEFEAT at dcp 2,000 gives 1,209,600 s; full retreat at dcp 250 gives 86,400 s;
  any win or `opening_loss` gives 0.
- **AC-15 (Logic; D5 load check)**: data with `DEFEAT_BASE_S + DEFEAT_SPAN_S` >
  604,800 fails load.
- **AC-16 (Integration; rule 21)**: after a loss, the World Clock's queued skip
  and Credits' upkeep days both equal `defeat_skip_s(report)`, and the skip runs
  only after the Debrief closes.
- **AC-17 (Logic; rule 28, Settings AC-17)**: for a fixed record, changing
  `defeat_cost_permille` and every other modifier changes only the day cost and
  bill; causes, scores, evidence and `DossierFacts` are identical.
- **AC-18 (Logic; rule 20)**: an opening loss shows "Nothing was lost", a
  would-be day cost from D5 with `opening_loss` treated as false, and the Vigor
  erosion with `restored = true`.
- **AC-19 (Logic; rule 25)**: a stored result, reloaded after its counter's mod
  is removed, shows the same text.
- **AC-20 (Integration; rule 22)**: `DossierFacts` is handed on exactly once per
  battle, on close, including after a save and load during the hold.
- **AC-21 (Integration; Runner, Machine Nodes rule 21a)**: for every MVP node,
  each unprepared reference loss over `PROOF_SEEDS` names a counter cause as
  primary, never UNKNOWN.
- **AC-22 (Integration; Runner)**: for each engine cause, a scripted fixture
  built to produce it names it primary in 10 of 10 seeds.
- **AC-23 (UI)**: a loss, a win, a MUTUAL, a STANDOFF, an UNKNOWN and the
  opening loss each have a retained screenshot in `production/qa/evidence/`.
- **AC-24 (Playtest; Pillar 1)**: 4 of 5 testers, after one stronghold loss, can
  state the cause and the action the Debrief named, and change their fleet or
  plan accordingly.
- **AC-25 (Playtest; experiential)**: no tester describes the Debrief as a
  grade or as blaming luck.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **Predicate polarity**: each MVP counter now carries a cause-polarity
  `evidence` predicate (true when the cause operated) and a separate
  success-polarity `worked` predicate for the Dossier (Machine Nodes rules 11–12
  amended).
- **Roaming fleets** use their home node's `dossier.counters[]` (rule 7).
- **A clean full retreat costs 1 day**, not 3 (`DEFEAT_BASE_S` 86,400,
  `DEFEAT_SPAN_S` 518,400): 1 – 7 days at Standard, at most 14 at dcp 2,000.
- **Replay**: the Timeline list is MVP; a static evidence chart is Vertical
  Slice (rule 24).
- **"4–6 loss causes"** (concept) counts the cause types a player meets in the
  MVP region: the region's counters as listed by its nodes, with the five
  engine causes and "unknown" as the always-available frame.
- **Lent ships** count as player losses (rule 5).
- **The opening's would-be bill**: Credits reports it (Credits rule 8 amended).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Battle Record rule 15 says an unverified replay shows the log "with no player-facing badge"; Simulation Tick & Pause says "recorded, not re-verified". The Debrief never replays, but the two GDDs must agree. | lead-programmer | Next review of #1 or #9 |
| 2 | Player-facing wording of every cause, action and the membrane line. | narrative-director, ux-designer | Debrief UX spec |
| 3 | Does any battle stream declare an `odds_surface`, and do record events carry the roll? If none, rule 16 is dormant at MVP. | lead-programmer | Before implementation |
| 4 | Calibrate `CAUSE_MIN_PM`, `LINK_SHARE_PM` and `RETREAT_GRACE_S` against the Runner's fixtures (AC-21, AC-22). | systems-designer | Runner tuning |
