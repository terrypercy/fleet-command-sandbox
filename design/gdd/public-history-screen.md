# Public History Screen

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — the screen where the player shapes what the world believes, with every consequence shown before commit); Pillar 4 (Plan in the Open)

## Summary

The Public History Screen shows what the galaxy believes: the verdict, one blame bar per candidate race with a naming line and a Named / Leading / Contested label, and the public record of shares, accusations, exposures and namings. It owns the single dialog contract for share, accuse, seal and release, which renders Faction Belief's rule 18 preview word for word and commits exactly what was previewed. At Tier 0 it adds only a read-only Public History panel inside the Case File, which keeps the action stub. The screen of its own, the action takeover and the private ledger come at the Vertical Slice.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Faction Belief & Blame, Case File & Deduction, Exposure & Rival Investigation`

## Overview

The Public History Screen is the player's view of the public story. Faction
Belief & Blame (#30) owns every number in it. This system owns how that story
is shown and how the player changes it. It shows three things. First, the
**verdict**: NAMES(X) or UNRESOLVED. Second, a **blame bar** per candidate race
for public blame `P`. Bars carry no numbers. Each has a fixed naming line at
`NAME_PM` and a label. Third, the **public record**: public shares,
accusations, exposures and namings, in the order they happened. It also owns
the **dialog contract** for the four actions: share, accuse, seal and release.
Each dialog shows #30's rule 18 preview, including #32's exposure readout and
#33's escort line, before a confirm step. The commit applies exactly what was
shown (#30 AC-08). At Tier 0 the Case File hosts the dialogs and the exposure
line (Case File rules 21–25). #49 adds one thing at MVP: a read-only Public
History panel in the Case File's hold, because no other screen shows the
verdict and the bars. At the Vertical Slice #49 becomes its own planning
screen and takes the actions over. It is truth-blind: it never reads the maker,
and it shows nothing a different maker would change.

## Player Fantasy

**The court of public opinion, with the transcript open.** The player stands
before the galaxy with a case file in one hand and a public record in the
other. They can see who the galaxy blames, how close it is to naming a race,
and what every past statement did. Before speaking, they see the consequences
in plain words: who will turn, who will lend, and how exposed they will be.
Then they sign.

*Anchor moment:* the Halsk bar sits just under the naming line, labelled
Leading. The player opens "Share…" on a relic, picks Public, and reads: "This
names Halsk. Halsk will turn Hostile. This share grants the Orrowen escort (3
ships). Held reliable contradictions of Halsk: open 1, sealed 0." They hold
one fragment that says otherwise. They close the dialog and open the Case File
instead.

**MDA aesthetics served:** Expression (the public story is the player's
authored act), Challenge (weighing first-order consequences against what is
still unfound), Narrative (the record reads as a history the player wrote).

**SDT:** Autonomy: the screen never recommends a share, a target or a race.
Competence: every consequence is shown before commit and every later change
has its cause in the record. Relatedness: factions are named in every line
and react as people would.

**Pillars served:**
- **Pillar 2, *The Truth Is Yours to Tell*:** this is the screen where the
  telling happens (rules 14–22), and the verdict is the result (rules 5–9).
- **Pillar 4, *Plan in the Open*:** every action is previewed in full before
  commit, and the preview is never wrong (rules 16–19).

**This system must never make the player feel:** "the preview lied", "the
bar order or a label gave the maker away", "I could not tell how close the
galaxy was to naming", or "something changed and I don't know why".

## Detailed Design

### Core Rules

**A. Scope by tier**

1. **What #49 is.** #49 presents #30's public state and hosts #30's four
   actions. It owns no belief, standing, lending or exposure value. Every
   figure and every sentence about consequences comes from #30, #17, #32 or
   #33. #49 only places them.
2. **Tier 0 (MVP).** #49 adds the **Public History panel** (section B) as a
   read-only tab of the Case File. It opens inside the Case File's
   `PLANNING:case_file` hold. The share, seal, release and accuse entry points
   stay in the Case File (Case File rules 21–25). They follow the dialog
   contract in section C, rendered as text in the Case File's text panel. #49
   adds no action, no preview line and no exposure line of its own at Tier 0.
   The systems-index CD note holds: the stub keeps the first-order share
   preview and the exposure change.
3. **Vertical Slice.** #49 becomes its own planning screen
   (`PLANNING:public_history`). It hosts the four dialogs as dialogs (rule
   14), adds the player's private ledger (rule 13) and adds the exposure
   readout to its header (rule 12). The Case File keeps the board and aids
   (Case File rule 25). Its entry points open #49's dialogs (rule 23).
4. **Never.** #49 never shows a belief number, a per-faction belief value or
   a projected bar. It never ranks, sorts or highlights candidates by `P`,
   support or status. It never suggests an action, a target or a race.

**B. The Public History panel**

5. **Verdict headline.** The top line is #30's `verdict()` in words: "The
   galaxy names Halsk as the makers." or "The galaxy has named no one." A
   race named before, now locked but no longer named, gets a second line:
   "Named before: Halsk (still Hostile)." (#30 rule 11).
6. **One bar per candidate.** Each candidate race has one horizontal bar for
   its `P[c]` (#30 D4). Bars are listed in the Dossier's candidate table order
   (content order, the same in every seed). They never reorder. The fill is
   D1. No number, tick label or percentage is shown on or near a bar.
7. **The naming line.** Every bar shows the same fixed vertical line at
   `NAME_PM`, with the caption "Naming line" once above the bars. D1
   guarantees a bar reaches the line exactly when `P[c] ≥ NAME_PM`.
8. **Labels.** Each bar carries at most one label, from D2:
   - **Named** on X while the verdict is NAMES(X);
   - **Leading** on the top race while the verdict is UNRESOLVED and its
     lead is at least `LEADING_PM`;
   - **Contested** on every race within `LEADING_PM` of the top while the
     verdict is UNRESOLVED and the lead is below `LEADING_PM`.

   Under the bars one fixed caption explains the labels: "A race is named
   when its bar crosses the line and stands well clear of the next. Once
   named, it stays named until it falls back a little." The caption is the
   same in every state.
9. **Faction names.** Each bar is titled with the race name, then its
   faction's name, then the faction's standing band word from #17 ("Halsk —
   the Halsk Compact — Hostile"). A candidate with no faction reads "No
   faction" (#30 edge case).
10. **The public record.** Below the bars is #30's log, filtered to the
    public kinds: SHARE_PUBLIC, ACCUSE, EXPOSE and NAMING (#30 rule 19). Each
    entry is one sentence with the day, from the names stored in the entry
    (#30 rule 20):
    - SHARE_PUBLIC: "Day 12. You shared *Relic: solvent saline* with
      everyone.";
    - ACCUSE: "Day 14. You accused the Halsk.";
    - NAMING: "Day 14. The galaxy named the Halsk." A naming caused by an
      exposure reads "…named the Halsk, after an exposure.";
    - EXPOSE: "Day 20. The Inquest made *Record: script knotted* public.".

    The card title and class label are #28's (#28 rule 24). The record never
    shows the faith judgement, because it is the world's record and not the
    player's. IDs are never shown.
11. **Record order and folding.** Entries are listed in ascending `seq`, the
    newest at the bottom. The list opens scrolled to the newest entry. When
    #30 has folded old entries (`LOG_KEEP`), one line at the top reads
    "Earlier: 12 public shares, 3 accusations." NAMING and EXPOSE are never
    folded (#30 rule 22). An empty record reads "No public statements yet."
12. **Exposure readout.** At Tier 0 the readout stays in the Case File header
    (Case File rule 24). At the Vertical Slice #49's header shows the same
    `exposure_readout(verdict())` line, with #32's wording and figures and
    the level as shape and text (#32 rule 20).
13. **Private ledger (Vertical Slice).** A second list, headed "Your own
    record", shows the non-public kinds: SHARE_PRIVATE, SUPPRESS, RELEASE,
    LAPSE and CONFIRM, plus each active seal with its keeper, its daily cost
    and its unpaid-day count. CONFIRM lines carry no amount: "A find
    confirmed the Halsk naming; trust grew with everyone else." (#30 rule
    14). The NAMING line here adds the faith line as it was recorded at
    commit, as counts over held fragments (#30 D7).

**C. The dialog contract** (one contract, rendered by the Case File at Tier 0
and by #49 from the Vertical Slice)

14. **Four dialogs.** Share, Accuse, Seal and Release, entered as in Case File
    rule 21. Each dialog has three parts, top to bottom: inputs, the preview,
    and the commit strip.
15. **Inputs.**
    - **Share:** the fragment (preselected from the entry point) and the
      target: one faction or Public. Factions that already have the fragment
      are greyed with "Already shared" (`ALREADY_SHARED`). The card shows
      #28's "Shared with" and "Sealed" lines.
    - **Accuse:** the candidate, in table order. A race already named is
      greyed with "Already named" (`ALREADY_NAMED`).
    - **Seal:** the fragment and the keeper. The keeper picker lists
      non-Hostile factions in content order. Each row shows its band after
      the purchase, from `Standing.preview`. A faction that cannot pay
      `SUPPRESS_STANDING_BUY` is greyed with "Cannot keep this secret". The
      dialog also shows the money cost, the daily upkeep, Credits' coverage
      line and the fixed line "Sealed fragments still count when your good
      faith is judged." (#30 UI Requirements).
    - **Release:** the fragment only. The fixed line "Upkeep stops. Nothing
      is refunded." (#30 rule 8).
16. **The preview is #30's, verbatim.** Whenever the inputs are complete, #49
    calls `preview(action)` and renders every line it returns, in #30 rule
    18's order. #49 never computes, rounds, merges, drops or reorders a line.
    Lines from #17 (bands, lost privileges, lost evidence sites per #28 rule
    24), #32 (readout before and after, retest line) and #33 (escort line)
    are rendered with their owners' wording. Belief changes appear as "⟨f⟩
    blames ⟨c⟩ more: marked" (#30 D11), never as bars.
17. **The preview is always current.** Any change to an input discards the
    shown preview and requests a new one. The Commit button is enabled only
    while the shown preview was produced for the current inputs. Each preview
    carries the inputs it was made for. The commit sends exactly those
    inputs.
18. **Confirm step, no undo.** "Commit…" opens the commit strip. It repeats
    the action in one sentence and the verdict after ("Share *Relic: solvent
    saline* with everyone. This names Halsk."). "Confirm" commits. "Back"
    returns to the inputs. The preview stays on screen throughout. There is
    no undo.
19. **Commit equals preview.** The commit is #30's command for the previewed
    action, applied by #30's command step (#30 OQ 4). After it, the dialog
    closes, the panel shows the new record entry, and the bars redraw from
    the new `P`. #49 asserts in debug builds that #30's applied result equals
    the preview it showed (AC-08).
20. **Refusals.** A refusal from #30 is shown in #30's words in the commit
    strip, and nothing changes. Codes: `ALREADY_SHARED`, `ALREADY_NAMED`,
    `PUBLIC_ALREADY`, `SEALED`, plus the keeper refusal of #30 rule 7. Inputs
    that would be refused are greyed before the player picks them, where the
    reason is known in advance.
21. **The release preview.** A release moves no belief. Its preview shows
    every rule 18 line that applies: the readout before and after (a sealed
    contradiction becomes open), and "No faction changes its view." If #30
    does not support `preview(release)`, #49 shows only the readout before
    and after from `exposure_readout` (OQ 2).
22. **No action without a preview.** No control on any #49 surface commits an
    action without passing rules 16–18. There are no shortcuts that skip the
    preview.

**D. Holds, battle, truth-blindness and save**

23. **One hold, preview to commit.** The preview and the commit happen inside
    one planning hold, so no grant can land between them (#28 rule 24).
    At Tier 0 this is `PLANNING:case_file`. At the Vertical Slice it is
    `PLANNING:public_history`. When a Case File entry point opens a #49
    dialog, #49 adds its reason before the Case File removes its own, in the
    same frame, so the clock never runs between them.
24. **In battle, read-only.** In `BATTLE` the panel opens with `PLAYER_PAUSE`
    added (Simulation Tick rule 10). The player may read everything. All
    dialogs are disabled with "Not during battle" (as Case File rule 29).
25. **Truth-blind render.** The render is a function of public and held data
    only: `verdict()`, `public_blame()`, the public log entries, the
    previews, #32's readout, #17's bands, the held cards and the locale. #49
    never reads the maker or Truth Seeding's reliable-contradiction flag.
    With the same inputs, the screen is identical whoever the maker is.
26. **No belief numbers.** No string on any #49 surface contains a value of
    `P`, `b_f`, `doubt`, a shift or a threshold. Digits appear only in
    counts the owners already print: days, ships, leads, held and unfound
    fragment counts, money.
27. **Save.** At Tier 0 #49 has no save section; everything it shows is read
    from its owners. At the Vertical Slice it adds `base:public_history`,
    version 1: the last-seen record `seq`, for a "New since you last looked"
    marker on record entries. It is excluded from the simulation state hash,
    because no simulation system reads it.
28. **Determinism.** #49 draws no random numbers. Bars loop in table order.
    The record loops in ascending `seq`. Two renders of the same state are
    identical, byte for byte.
29. **Telemetry.** On each commit, #49 (or the Case File at Tier 0) sends
    `belief_action_committed` to #54 with the action kind, the target kind
    (faction or Public), the verdict before and after, and whether the Case
    File was opened since the last grant. If `SHARE_REASON_PROMPT` is on
    (playtest builds only), the commit strip adds an optional one-line "Why
    this share?" field. Its text goes only to Telemetry. No game system reads
    it, and leaving it empty changes nothing (OQ 3).

### States and Transitions

**Screen states**

| State | Entered when | Leaves to |
|---|---|---|
| Closed | Start; panel or screen closed | Open (Read), Open (Battle) |
| Open (Read) | Opened outside battle; dialog closed or committed | Closed; Open (Dialog) (Vertical Slice) |
| Open (Dialog) | Share…, Accuse…, Seal… or Release chosen | Open (Read) on Back-out, cancel, refusal dismissed or commit |
| Open (Battle) | Opened in `BATTLE` | Closed |

At Tier 0, Open (Dialog) is the Case File's Open (Action) state (Case File
States), following section C.

**Dialog states**

| State | Entered when | Leaves to |
|---|---|---|
| Editing | Dialog opened; any input changed | Previewed (inputs complete and preview returned) |
| Previewed | `preview(action)` returned for the current inputs | Editing (input changed); Confirming ("Commit…") |
| Confirming | Commit strip open | Previewed ("Back"); Committed; Refused |
| Refused | #30 returned a refusal code | Editing (dismiss) |
| Committed | #30 applied the action | Dialog closes; Open (Read) |

**Bar label** (per candidate, derived each render from D2)

| Label | Condition |
|---|---|
| Named | Verdict is NAMES(c) |
| Leading | Verdict UNRESOLVED, c is top, `lead ≥ LEADING_PM` |
| Contested | Verdict UNRESOLVED, `lead < LEADING_PM`, `P[top] − P[c] < LEADING_PM` |
| (none) | Otherwise |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Faction Belief & Blame (#30) | both | #30 → #49: `verdict()`, `naming()`, `public_blame()`, the log (public and private kinds, folded counts), seal state, `preview(action)`, refusal codes. #49 → #30: the share, accuse, suppress and release commands, with the previewed inputs |
| Exposure & Rival Investigation (#32) | #32 → #49 | `exposure_readout(verdict)` in the header (Vertical Slice) and inside #30's preview; EXPOSE entries arrive through #30's log |
| Allied Lending (#33) | #33 → #49 via #30 | The GRANTS / LOSES escort line inside the preview (#33 rule 21), rendered verbatim |
| Faction Reputation & Standing (#17) | #17 → #49 | Band words on bar titles; `Standing.preview` results inside the preview and in the keeper picker |
| Archive Fragments & Evidence (#28) | #28 → #49 | Share cards (rule 24 there), `held_fragments()` for pickers, "Shared with" and "Sealed" lines |
| Case File & Deduction | both | Tier 0: hosts the #49 panel as a tab and renders the dialog contract in its text panel. Vertical Slice: its entry points open #49 dialogs with the hold handoff (rule 23) |
| Credits, Upkeep & Sinks (#18) | #18 → #49 | Seal money cost, upkeep and coverage line, inside the seal dialog |
| Simulation Tick & Pause | #49 → it | `PLANNING:case_file` (Tier 0, via the Case File) or `PLANNING:public_history` (Vertical Slice); `PLAYER_PAUSE` in battle |
| Dossier (#47) | shared view | Candidate table order |
| Runtime ID Service | via #30 | Stored names in log entries; IDs never shown |
| Input & Controls | Input → #49 | Open action and dialog actions in the Planning context |
| Telemetry (#54) | #49 → #54 | `belief_action_committed`; optional share reason |
| Save/Load & Migration (#5) | #49 → #5 | `base:public_history` (Vertical Slice only) |
| Audio (#52) | #30 → #52 | NAMING and EXPOSE cues are #30's; #49 adds none |

## Formulas

All maths is integer. `div` truncates toward zero on non-negative operands
(#30 rule 21).

### D1. Bar fill

`fill[c] = (P[c] × BAR_UNITS) div 1,000`
`line = (NAME_PM × BAR_UNITS) div 1,000`

The bar is drawn as `fill[c]` of `BAR_UNITS` equal segments. The naming line
sits after segment `line`.

| Variable | Type | Range | Description |
|---|---|---|---|
| P[c] | int ‰ | 0 – 1,000 | Public blame on `c` (#30 D4) |
| BAR_UNITS | int | 20 – 100; **40** | Segments in a full bar |
| NAME_PM | int ‰ | 550 – 750; **600** | #30's naming threshold (read only) |
| fill[c] | int | 0 – BAR_UNITS | Segments filled |
| line | int | — | Segment after which the naming line sits |

**Constraint:** `(NAME_PM × BAR_UNITS) mod 1,000 = 0`. Then a bar reaches the
line exactly when `P[c] ≥ NAME_PM`. Proof: if `P ≥ NAME_PM`, then `P × U ≥
NAME_PM × U`, so `fill ≥ line`. If `P < NAME_PM`, then `P × U ≤ NAME_PM × U −
1`, so `fill ≤ line − 1`. At `BAR_UNITS` 40 this holds for every `NAME_PM`
that is a multiple of 25 (25 × 40 = 1,000). A content check refuses a pair
that breaks it (`PH_BAR_LINE_MISALIGNED`).

**Output:** bounded in [0, `BAR_UNITS`]. The mapping is linear, so equal
blame always draws equal bars.

**Worked example** (C = 3, `BAR_UNITS` 40, `NAME_PM` 600, so `line` = 24000
div 1,000 = **24**; values from #30's examples):

| State | P (H / O / I) | fill (H / O / I) | Halsk vs line |
|---|---|---|---|
| Start (#30 D4) | 450 / 450 / 450 | 18 / 18 / 18 | below |
| After the D1 public share (#30 AC-02) | 338 / 484 / 484 | 13 / 19 / 19 | below |
| Bare accusation of Halsk (#30 AC-03) | 587 / 394 / 394 | 23 / 15 / 15 | below (one segment short) |
| Accusation with `s_pub` 1 (#30 AC-03) | 670 / — / — | 26 | above |
| Hysteresis hold (#30 D3) | 560 / 380 (next) | 22 / 15 | below, still Named |

Checks: 450 × 40 = 18,000 → 18. 338 × 40 = 13,520 → 13. 484 × 40 = 19,360 →
19. 587 × 40 = 23,480 → 23. 394 × 40 = 15,760 → 15. 670 × 40 = 26,800 → 26.
560 × 40 = 22,400 → 22. 380 × 40 = 15,200 → 15. 599 × 40 = 23,960 → 23, and
600 × 40 = 24,000 → 24, so the line is crossed at exactly 600.

### D2. Bar label

Sort candidates by `P` descending, then by Runtime ID (as #30 D3). Let `top`
be the first and `lead = P[top] − P[second]`.

- If the verdict is NAMES(X): X is **Named**. No other label is shown.
- Else if `lead ≥ LEADING_PM`: `top` is **Leading**.
- Else every `c` with `P[top] − P[c] < LEADING_PM` is **Contested** (this
  always includes `top` and at least one other race).

The sort is used only to choose labels. It never orders the bars (rule 6).

| Variable | Type | Range | Description |
|---|---|---|---|
| LEADING_PM | int ‰ | 50 – (`LEAD_PM` − `NAME_H`); **100** | Lead that earns "Leading" |
| LEAD_PM / NAME_H | int ‰ | #30 knobs, read only | 200 / 50 |

**Constraint:** `0 < LEADING_PM ≤ LEAD_PM − NAME_H` (150). Then a named race
that falls to UNRESOLVED with a lead still at least `LEADING_PM` reads
Leading, not Contested, so the label never jumps past a state.

**Worked example** (same states as D1):
- Start, lead 0: all three Contested.
- 338 / 484 / 484: tie at the top, lead 0. Orrowen and Ithren are Contested
  (0 < 100). Halsk is 146 behind, so it has no label.
- 587 / 394 / 394: lead 193 ≥ 100, verdict UNRESOLVED (#30 D3). Halsk
  Leading.
- 670, lead 310: NAMES(Halsk). Halsk Named.
- 560 / 380: hold holds (#30 D3). Halsk Named, bar 22 below line 24.
- 540 / 380: UNRESOLVED (540 < 550), lead 160 ≥ 100. Halsk Leading.

### D3. Spoken bar position

The screen reader cannot see length, so each bar has an accessible name in
words, with no digits:
- `fill ≥ line`: "at or above the naming line";
- `line − SR_NEAR_UNITS ≤ fill < line`: "just below the naming line";
- otherwise: "well below the naming line".

The label from D2 follows. Example: "Halsk, the Halsk Compact, Wary: just
below the naming line. Leading." for fill 23 at `SR_NEAR_UNITS` 2 (22 ≤ 23 <
24). A sighted player reads the same proximity from the bar, so the words add
nothing the bar does not show.

| Variable | Type | Range | Description |
|---|---|---|---|
| SR_NEAR_UNITS | int | 1 – 5; **2** | Segments that count as "just below" |

## Edge Cases

- **If C = 4**: four bars, same rules. At the start all four are Contested
  (300 each, fill 12).
- **If the named race falls under the line but the hold holds** (550 – 599):
  the bar is below the line and labelled Named. The fixed caption (rule 8)
  explains it. Nothing extra is shown.
- **If two races tie at the top**: the verdict is UNRESOLVED (#30 D3). Both are
  Contested. The Runtime ID tie-break picks `top` for the maths only. It
  never shows, because the tied races get the same label.
- **If the verdict moves from NAMES(X) to NAMES(Y)**: Y is Named. X shows its
  bar normally, and the headline adds "Named before: X (still Hostile)".
- **If a candidate has no faction**: the bar title reads "No faction". The
  preview line "No faction to turn hostile" comes from #30.
- **If the log has folded entries**: the "Earlier: …" line counts only public
  kinds. If no public entry was folded, the line is absent.
- **If the record is empty**: "No public statements yet." The bars still show.
- **If #32 is not yet built**: the readout lines are absent from the header
  and the preview, as in Case File's dependency row. No placeholder is shown.
- **If no faction can keep a secret** (all Hostile or too low): the keeper
  picker shows every faction greyed with its reason, and Commit stays
  disabled. The Seal entry point is not hidden.
- **If a seal lapses while the panel is open**: it cannot, because the hold
  stops the clock. Lapses arrive on the next daily step after the panel
  closes, and appear in the private ledger (Vertical Slice).
- **If the player changes an input after "Commit…"**: the strip closes, the
  dialog returns to Editing and requests a new preview (rule 17).
- **If #30 refuses a commit whose preview showed no refusal**: this is a bug.
  The refusal is shown in #30's words, nothing changes, and one error
  `PH_PREVIEW_COMMIT_MISMATCH` is logged with both results.
- **If a grant is attempted while a dialog is open**: it is deferred by the
  hold (#28 rule 24). It lands after the panel closes.
- **If opened in battle**: read-only (rule 24). Dialogs already open cannot
  exist, because battle cannot start inside a planning hold.
- **If a mod adds a candidate whose name is long**: bar titles wrap. Bars
  keep the same length and the naming line stays aligned across bars.
- **If `BAR_UNITS` and `NAME_PM` break the D1 constraint**: content load
  error `PH_BAR_LINE_MISALIGNED`; the default values are used.
- **If `LEADING_PM` breaks the D2 constraint**: content load error
  `PH_LEADING_RANGE`; the default is used.
- **If the share reason field is on and the player types nothing**: the commit
  proceeds. An empty reason is logged as empty.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Faction Belief & Blame (#30) | Hard | Verdict, `P`, log, seal state, `preview(action)`, commands, refusal codes |
| Case File & Deduction | Hard (both) | Tier 0 host of the panel and the dialog contract; Vertical Slice hold handoff |
| Exposure & Rival Investigation (#32) | Soft | `exposure_readout(verdict)`; lines hidden until #32 exists |
| Simulation Tick & Pause | Hard | Planning hold reasons; battle read-only |
| Faction Reputation & Standing (#17) | Hard | Band words; `Standing.preview` |
| Archive Fragments & Evidence (#28) | Hard | Share cards, held set for pickers |
| Allied Lending (#33) | Soft (via #30) | Escort line in the preview |
| Credits, Upkeep & Sinks (#18) | Soft (via #30) | Seal costs and coverage line |
| Dossier (#47) | Soft | Candidate table order |
| Input & Controls | Hard | Open and dialog actions |
| Telemetry (#54) | Soft | Commit event, optional reason |
| Save/Load & Migration (#5) | Hard (Vertical Slice only) | `base:public_history` |

Bidirectional check: #30, #32, #28 and the Case File already name #49.
Simulation Tick lists #49's planning hold. #17, #33, #18, Dossier, Input &
Controls, Telemetry and Save/Load need rows naming #49 (see the report).

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `BAR_UNITS` | 40 | 20 – 100, with `(NAME_PM × BAR_UNITS) mod 1,000 = 0` | Feel | Bar resolution. Lower hides small moves; higher shows near-numeric detail |
| `LEADING_PM` | 100 | 50 – (`LEAD_PM` − `NAME_H`) | Curve | When a race reads Leading rather than Contested |
| `SR_NEAR_UNITS` | 2 | 1 – 5 | Feel | Screen-reader "just below the naming line" band |
| `SHARE_REASON_PROMPT` | false | bool (playtest builds only) | Gate | Optional "Why this share?" field for the pass-bar rubric |
| Section ceiling (Vertical Slice) | 1 KiB | 1 – 4 KiB | — | Save budget for the last-seen `seq` |

Read only here, owned by #30: `NAME_PM`, `LEAD_PM`, `NAME_H`, `LOG_KEEP`,
`REACT_T1/T2/T3` (preview bands). Knobs live in `assets/data/public_history/`.
No knob changes a belief, a verdict or a preview line. None scales with
difficulty.

## Visual/Audio Requirements

- Bars use one neutral fill for every race. No race art, emblem or colour on
  any bar, title or record entry (as Case File, Visual/Audio).
- The naming line is a solid vertical rule, the same on every bar.
- Labels are shapes plus words: "■ Named", "▲ Leading", "◆ Contested".
  Colour may reinforce; it never carries meaning alone. The Named bar also
  gets a hatched fill, so a greyscale screenshot tells it apart.
- Bars redraw after a commit with a short fill tween (≤ 0.3 s). The tween has
  the same length and curve for every race and every direction.
- #49 adds no sound. The NAMING and EXPOSE cues are #30's and do not vary with
  race or faith (#30 Visual/Audio).

## Game Feel

- **Signing, not clicking.** Two steps, the preview on screen while you
  confirm, and no undo (#30 Game Feel).
- **The line is the stake.** The player always sees how far each race is from
  the naming line, without a number.
- **Nothing moves under you.** Bars never reorder. The record only grows at
  the bottom.
- **The preview never lies.** What the dialog said is what happens, every
  time (AC-08).
- **Thinking is free.** The clock holds while the panel or a dialog is open.

## UI Requirements

- **Layout (Tier 0 panel):** verdict headline; bars with the naming line,
  titles and labels; the label caption; the public record. It is a tab of the
  Case File, next to the board.
- **Layout (Vertical Slice screen):** the same, plus the exposure readout in
  the header and the "Your own record" list as a second tab.
- **Dialogs:** inputs, preview and commit strip, top to bottom. The preview
  scrolls; the commit strip never scrolls off screen.
- **Keyboard:** Tab and Shift+Tab move between bars, record and dialog parts;
  arrow keys move within a list; Enter opens a record entry's card; Esc backs
  out of the commit strip, then the dialog, then the panel. Default open bind
  `H` (Input & Controls to own). Every action is rebindable and reachable from
  a menu.
- **Screen reader:** every bar has the D3 name. Every preview line and record
  entry is read as its sentence.
- **No colour-only meaning;** text scale follows the global UI scale setting.
- No belief numbers, Runtime IDs or raw codes on screen (rule 26).
- 📌 **UX Flag — Public History Screen**: the panel, the four dialogs and the
  commit strip go into `design/ux/public-history.md`, shared with
  `design/ux/case-file.md` for the Tier 0 text rendering.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Verdict, `P`, record, preview, commands, refusals | `design/gdd/faction-belief-and-blame.md` | Rules 4–9, 11, 18–22; D3, D4, D11; UI Requirements; AC-08, AC-20 | Rule dependency |
| Tier 0 stub, entry points, exposure line, battle read-only | `design/gdd/case-file-and-deduction.md` | Rules 21–25, 27, 29 | Rule dependency |
| Exposure readout, where it appears | `design/gdd/exposure-and-rival-investigation.md` | Rules 18–20; D7; UI Requirements | Interface |
| Escort preview line | `design/gdd/allied-lending.md` | Rules 21–22 | Interface |
| Share card, unfound counts, one hold | `design/gdd/archive-fragments-and-evidence.md` | Rule 24 | Data dependency |
| Planning hold, battle pause | `design/gdd/simulation-tick-and-pause.md` | Rule 10; planning screens row | Rule dependency |
| First-order, truth-blind preview; pass bar item 3 | `design/gdd/game-concept.md` | Unique Hook; MVP Definition, pass bar | Vision |
| #49 stub and combined screen | `design/gdd/systems-index.md` | CD note; UI layer notes | Constraint |

## Acceptance Criteria

- **AC-01 (Logic; D1)**: the D1 worked example gives fills 18 / 13 / 19 / 23 / 15 / 26 / 22 for P 450 / 338 / 484 / 587 / 394 / 670 / 560, and `line` 24. P 599 gives 23 and P 600 gives 24.
- **AC-02 (Logic; D1 constraint)**: for every `P` in 0 – 1,000 and every `NAME_PM` multiple of 25 in 550 – 750, `fill ≥ line` exactly when `P ≥ NAME_PM` at `BAR_UNITS` 40. A content file with `BAR_UNITS` 30 and `NAME_PM` 610 is refused with `PH_BAR_LINE_MISALIGNED`.
- **AC-03 (Logic; D2)**: the D2 worked example gives all Contested; Orrowen and Ithren Contested with Halsk unlabelled; Halsk Leading; Halsk Named; Halsk Named at 560; Halsk Leading at 540.
- **AC-04 (Logic; rule 6)**: in every state of a 200-action random fixture, bars follow the Dossier table order and never reorder.
- **AC-05 (Logic; rule 10, 11)**: the record lists exactly the SHARE_PUBLIC, ACCUSE, EXPOSE and NAMING entries in ascending `seq`; a fixture past `LOG_KEEP` shows the "Earlier:" line with the folded public counts, and every NAMING and EXPOSE entry.
- **AC-06 (Logic; rule 25)**: a fixture with fixed claims and actions rendered under each of the C makers gives byte-identical panel text, bar fills, labels, record and previews. The #49 module has no reference to the maker field or #16's reliable-contradiction flag (static check).
- **AC-07 (Logic; rules 4, 26)**: a string scan of every rendered #49 string over a 200-action fixture finds no value of `P`, `b_f`, `doubt`, a shift or a threshold, and no Runtime ID. The D3 accessible names contain no digits.
- **AC-08 (Logic; rules 16, 19; #30 AC-08)**: for share, accuse, seal and release fixtures, the lines rendered equal `preview(action)` line for line, in rule 18 order, and the state after commit equals the preview's belief bands, verdict, `Standing.preview` result, escort line and readout after.
- **AC-09 (Logic; rule 17)**: changing any input after a preview disables Commit until a new preview returns; the committed inputs always equal the inputs of the shown preview.
- **AC-10 (Logic; rule 22)**: no #49 or Case File control path calls a #30 command without a preview for the same inputs (static check plus test).
- **AC-11 (Logic; rules 15, 20)**: each refusal code fires on its fixture, is shown in #30's words, and leaves state unchanged. Greyed inputs match the refusals #30 would return.
- **AC-12 (Integration; rule 23)**: a grant attempted while a dialog is open is deferred; the commit's held snapshot equals the preview's (#30 AC-19, #28 AC-28). At the Vertical Slice, the Case File → #49 handoff leaves no tick between the two holds.
- **AC-13 (Logic; rule 24)**: in `BATTLE`, opening adds `PLAYER_PAUSE`; every dialog entry is disabled with "Not during battle"; closing leaves the battle Paused (player).
- **AC-14 (Logic; rule 2)**: at Tier 0, opening the panel adds no planning reason of its own (the Case File's `PLANNING:case_file` is active) and no day passes while it is open.
- **AC-15 (Logic; rules 27, 28)**: at Tier 0 no `base:public_history` section exists; two renders of the same state are byte-identical.
- **AC-16 (Logic; rule 29)**: each commit sends exactly one `belief_action_committed` event; with `SHARE_REASON_PROMPT` off no reason field is shown; with it on, an empty or filled reason changes no simulation hash.
- **AC-17 (UI; Visual/Audio)**: a greyscale screenshot distinguishes Named, Leading and Contested and shows the naming line aligned on every bar; retained in `production/qa/evidence/`.
- **AC-18 (UI; rules 5–11)**: screenshots of the Tier 0 panel in the start state, a Leading state, a Named state below the line (hysteresis) and a Named-before state are retained in `production/qa/evidence/`.
- **AC-19 (UI; section C; #30 AC-20)**: screenshots of the share, accuse, seal and release dialogs (or their Tier 0 text renderings) with a full preview and the commit strip open are retained in `production/qa/evidence/`.
- **AC-20 (UI; UI Requirements)**: every bar, record entry and dialog control is reachable and operable by keyboard alone; a screen reader reads each bar's D3 name; evidence retained in `production/qa/evidence/`.
- **AC-21 (Playtest; concept pass bar item 3)**: in Tier 0 playtests, at least 4 of 5 testers give a reason for their share that the written rubric accepts, and every tester can say, from the panel alone, which race leads and whether their next share would name it.
- **AC-22 (Playtest; rule 6, 25)**: no tester reports that a bar, order, label or animation "gave away" the maker; no tester reports a commit that differed from its preview.

## Open Questions

Resolved with the recommended defaults, for the owner to confirm at review:
- **Tier 0 scope:** #49 adds only the read-only panel (verdict, bars,
  record) inside the Case File. The alternative, adding nothing at MVP,
  leaves the verdict and bars unseen, which breaks #30's UI Requirements and
  Pillar 4.
- **No projected bars in the preview.** Showing "after" bars would show
  magnitudes, which the concept rules out ("no magnitudes"). The preview
  shows the verdict after and #30's band words only.
- **The public record hides faith.** It is the world's record. The faith
  line appears only in the private ledger (Vertical Slice).
- **One dialog contract, two hosts.** The Case File renders it as text at
  Tier 0, so the Vertical Slice takeover changes layout, not rules.
- **Label rule**: `LEADING_PM` 100 (D2); a top race leads only by that
  margin, so "Leading" never names a statistical tie.
- **Share reason for the pass bar**: moderators record it in playtests; the
  optional in-game "Why this share?" field stays off by default.

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 2 | **`preview(release)`.** Does #30's `preview` accept a release? Rule 21 needs the readout before and after. Recommended: yes, with "No faction changes its view". | #30 owner | #30 amendment |
| 4 | **Per-faction views.** Should the Vertical Slice show each faction's lean in words ("Orrowen blames Halsk most")? It adds Relatedness but shows more of `b_f` than #30's UI Requirements allow. | owner / #30 owner | Vertical Slice planning |
| 5 | **Preview token.** Rule 17 binds Commit to the previewed inputs. Is a debug-build equality assert (rule 19) enough, or should #30's command return its applied effects for a release-build check? | lead-programmer | ADR on commands (#30 OQ 4) |
| 6 | `design/accessibility-requirements.md` does not exist; the keyboard, screen-reader and no-colour rules here are local until it does (as Case File OQ 4). | ux-designer | Pre-Production gate |
