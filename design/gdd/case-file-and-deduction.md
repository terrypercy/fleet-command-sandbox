# Case File & Deduction

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (no solved banner; statuses shown when the player tests a row; 'may narrow the case' header; learning forgery tells)
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — the player works out the truth from held evidence before deciding what to tell); Pillar 4 (Plan in the Open — what is ruled out, and why, is always readable)

## Summary

The Case File is the player's reasoning board: the candidate rows with their status (not contradicted, contradicted once, ruled out by two independent chains), a fragment-by-candidate evidence matrix and the public attribute table, every reason citing its chains. It never declares the case solved; statuses appear when the player tests a row, and nothing is shown when one candidate remains. It owns the `support` measure, hosts player aids that change no number, and at Tier 0 is the panel where sharing, sealing and accusing are previewed and committed, with no ordering or highlight that could leak the maker.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Truth Seeding & Candidates, Archive Fragments & Evidence`

## Overview

The Case File is the player's reasoning surface for the mystery. It is a
planning screen (`PLANNING:case_file`), so reading it costs no days. It shows
the candidates, the public attribute table, and every held fragment mapped to
the candidates it contradicts or fits. From those, it reports each candidate's
status over the **held set only**: not contradicted, contradicted once, or ruled
out. A candidate is ruled out when `contra ≥ 2` from distinct independent
groups. Truth Seeding rule 8 owns that meaning; the Case File uses it and does
not own it. The Case File **does own the meaning of `support`** (D3), which
Faction Belief's good-faith test reads. It says why each candidate is ruled
out, citing the chains, once the player tests that row. It never says who the
maker is, and when one candidate is left it says nothing more: the conclusion
is the player's. It also holds player aids (one theory pin, doubt marks,
notes) that change no game number. At Tier 0 its text panel is the Public
History stub: the share, accuse and suppress entry points, the first-order
preview (Faction Belief rule 18) and the exposure change (#32). It never reads
the maker.

## Player Fantasy

**My corkboard, and it does not cheat.** The player pins what they found and
sees, in plain words, what it proves. The thrill is the moment two chains from
different sources close on a race: "Ithren: ruled out. Chain A (solvent:
saline), Chain C (script: knotted)." The player did the finding and the
weighing. The File does the bookkeeping and shows its working.

Its texture is *the archive does not lie, but people do*. Relics and records
can rule a race out. Testimony leans, and is marked as leaning. A marked
forgery sits on the board, counted nowhere, so the player sees it and learns
its tell.

*Anchor moment:* a find card closes. The Halsk row reads "New evidence since
you last tested". The player selects "Strike out…", and the File confirms,
citing Chain A and Chain C. Two rows are struck. The File says nothing more.
The player says "Orrowen", or chooses not to.

**MDA aesthetics served:** Discovery (the case narrows as evidence arrives),
Challenge (weighing testimony, learning forgery tells, choosing when the held
case is enough), Expression (what to tell, to whom, in the attached preview).

**SDT:** Competence: every status has a cited reason. Autonomy: the File informs
and never decides; sharing, accusing and keeping quiet stay the player's.

**Pillars served:**
- **Pillar 2, *The Truth Is Yours to Tell*:** the player works out the truth
  from held evidence (rules 7–16), then decides what to tell (rules 21–25).
- **Pillar 4, *Plan in the Open*:** what is ruled out, and why, is always
  readable (rules 12–16); no hidden rule, no wiki.

**This system must never make the player feel:** "the File told me the
answer", "the order or highlight gave it away", "a forgery fooled the File", or
"I lost good faith because I never opened this screen".

## Detailed Design

### Core Rules

**A. What the Case File holds**

1. **The Case File is a planning screen.** Opening it adds `PLANNING:case_file`
   (Simulation Tick & Pause rule 10); closing it removes that reason. No days
   pass while it is open (World Clock). It opens with the Planning action
   (default `K`, Input & Controls) from the sector map, a port or a battle.
2. **Four panels**, all on one screen:
   - **Candidates:** one row per candidate with its status, its contradicting
     chains and its supporting chains (rules 12–16);
   - **Evidence:** one row per held fragment, one column per candidate
     (rules 9–11);
   - **Table:** the public attribute table, the same view the Dossier shows
     (Truth Seeding rule 4);
   - **Text panel:** the header lines (rule 6), the selected item's detail, and
     at Tier 0 the action preview (rules 21–25).
3. **Inputs only.** The Case File reads:
   - `held_fragments()` from #28 (rule 23): ID, `acq_seq`, `acq_tick`, axis,
     value key, class, chain label, source kind;
   - the claim view from Truth Seeding: each held fragment's group, and each
     candidate's attribute row;
   - the sealed flag per fragment from Faction Belief (rule 7);
   - `unfound_count_by_class()` from #28 (rule 24);
   - the verdict and `preview(action)` from Faction Belief (rule 18);
   - the exposure readout from #32;
   - its own player aids (rules 17–20).
   It reads nothing else. It never reads the maker, and never reads Truth
   Seeding's reliable-contradiction flag (that flag exists for the ending
   checks, Truth Seeding rule 15).
4. **The board is derived, never stored.** Statuses, counts and citations are
   recomputed from the inputs on each grant, on load, on any seal, release or
   lapse, and on open. Only player aids are saved (rule 30).
5. **Held only.** A fragment counts only while HELD (#28). A fragment a rival
   exposed but the player does not hold appears in the public history, not on
   the board, and counts in nothing here (concept: "reasons only over fragments
   the player holds").
6. **Header lines** (text panel, always shown, fixed order):
   - "Held h of N" (#28 rule 16);
   - "k reliable fragments are still unfound; any may narrow the case" (from
     `unfound_count_by_class()`, D6). By G1 an unfound fragment can never rule
     out a candidate the held evidence leaves standing as the truth, so the
     line suggests no doubt the rules make impossible;
   - "Relics and records can rule a candidate out. Testimony is weight only.
     Marked forgeries prove nothing and are counted nowhere." (fixed text).

**B. Counting**

7. **Contradicts and fits** (Truth Seeding rule 6). A fragment's claim is "the
   maker's ⟨axis⟩ is ⟨value⟩". It **contradicts** candidate `c` when `c`'s
   value on that axis differs. Otherwise it **fits** `c` (D1). The Case File
   computes this from the claim and the public table, never from the truth.
8. **Classes decide what counts** (Truth Seeding rule 7):

   | Class | Counts toward `contra` | Counts toward `support` | Shown as |
   |---|---|---|---|
   | DIRECT_PHYSICAL | yes | yes | "Relic. Can rule a candidate out." |
   | RECORD | yes | yes | "Machine record. Can rule a candidate out." |
   | TESTIMONY | **never** | yes, as testimony | "Testimony. Weight only." |
   | FORGERY | **never** | **never** | "Marked forgery. Counted nowhere." |

9. **`contra(c)`** is the number of distinct groups holding a held DIRECT or
   RECORD fragment that contradicts `c` (D2). This is Truth Seeding rule 8's
   meaning over the held set, and equals Faction Belief's `contra_held` (D7
   there). Sealed fragments count (Faction Belief rule 7).
10. **`support(c)`** is the number of distinct groups holding a held DIRECT,
    RECORD or TESTIMONY fragment that fits `c` (D3). Forgeries never count.
    Sealed fragments count. It is split for display into `support_rel` (groups
    with a reliable fitting fragment) and `support_tes` (groups whose only
    fitting fragments are testimony), so `support = support_rel +
    support_tes`. **This is the definition Faction Belief D7 uses for
    `support_held`.**
11. **A chain counts once.** Two held fragments of one group that both
    contradict `c` add 1 to `contra(c)`. The same holds for `support`.

**C. Status and reasons**

12. **Status per candidate** (D4), **shown after the player tests the row.**
    Each candidate row offers "Strike out…" and "Test". The File then confirms
    the status and cites the chains, or answers "Not yet: you hold n reliable
    contradiction(s)." Until then, a row whose counts changed since its last
    test reads "New evidence since you last tested", and a tested row keeps
    its last shown status. The deduction is the player's act; the File only
    checks it. Statuses:
    - **Not contradicted:** `contra(c)` = 0. Shown "Not contradicted".
    - **Contradicted once:** `contra(c)` = 1. Shown "Contradicted once; not
      ruled out".
    - **Ruled out:** `contra(c) ≥ 2`. Shown "Ruled out".
    Each row also shows "Fits n independent chains" (n = `support(c)`), with
    the testimony share named ("of which 1 testimony").
13. **Status only moves forward.** The held set only grows, and sealing keeps a
    fragment held. So a status never goes back. A lapse or release changes no
    count.
14. **Why ruled out.** A ruled-out row cites every contradicting chain, in the
    order first held (D5): "Ruled out: Chain A (solvent: saline), Chain C
    (script: knotted)". Per chain it cites the earliest-held contradicting
    fragment; selecting the citation opens that card. A contradicted-once row
    cites its one chain the same way.
15. **No solved banner.** When exactly one candidate is not ruled out, the File
    shows **no extra line, flag or cue**: that row looks the same as any other
    row that is not ruled out. (By G1 that candidate is certainly the maker, so
    any "only X remains" line would be a solved banner in other words.) The
    File **never** uses "maker", "correct", "solved", "guilty" or "true" about
    a candidate, in any state, and plays no special effect for any candidate.
16. **Forgeries and testimony cannot be mistaken for proof.**
    - A **forgery** row shows its value and the full-width band "Marked
      forgery: proves nothing, counted nowhere", with its tell. It has **no
      per-candidate cells**, so it can never look like a contradiction.
    - A **testimony** row shows per-candidate cells in the weight-only style:
      "fits (weight)" or "differs (weight)". It never shows the contradiction
      mark.
    - Only DIRECT and RECORD rows use the contradiction mark ("✕
      Contradicts") and the fit mark ("● Fits").
    - A reliable fragment cannot mislead (Truth Seeding G1). So the player can
      be wrong only by trusting a weight-only fragment, and the File always
      shows which ones those are.

**D. Player aids**

17. **One theory pin.** The player may pin one candidate as "My theory". The
    pin shows a marker on that row and opens its row detail by default. Pinning
    another moves the pin. The pin is the concept's "state a candidate": it is
    free, and any number of changes is allowed.
18. **Doubt marks.** The player may mark any held fragment "I doubt this". The
    mark is a visible tag only. **It removes nothing from any count**, and the
    row says so: "Doubted by you; still counted".
19. **Notes.** One free-text note per held fragment (up to
    `NOTE_MAX_FRAGMENT`, 280 characters) and one case note (up to
    `NOTE_MAX_CASE`, 2,000 characters).
20. **Aids change no game number.** No system reads the pin, doubt marks or
    notes except the Case File's display and Telemetry. Faction Belief, #32,
    the Reckoning, the Debrief, AI and Standing never read them. Whether, when
    or how often the Case File was opened is read by nothing but the planning
    hold and Telemetry (concept: "never querying the Case File is no excuse").

**E. Actions and the Tier 0 Public History stub**

21. **Entry points.** With a fragment row selected: "Share…" and "Seal…". With a
    candidate row selected: "Accuse…". Each opens Faction Belief's dialog
    (rules 5–7 there) inside the Case File's hold. A sealed fragment shows
    "Release" instead of "Seal…". Refusals use Faction Belief's codes and words.
22. **The preview lives in the text panel.** Before any confirm, the text panel
    shows every Faction Belief rule 18 line, in that rule's order, as text,
    including the faith line and the exposure readout from #32 before and after.
    The faith line's counts are this system's `contra` and `support` for the
    named candidate (rule 10).
23. **One hold, preview to commit.** The preview and the commit read the held
    set inside one `PLANNING:case_file` hold, so no grant can land between them
    (#28 rule 24). The commit is applied by Faction Belief's command step
    (Faction Belief OQ 4). There is a confirm step and no undo.
24. **Exposure line.** The text panel header also shows the current exposure
    readout from #32 for the current verdict ("Held reliable contradictions of
    the named race: open 1, sealed 0. Rival investigation: 2 of 5 leads."). The
    wording and figures are #32's; the Case File only places them.
25. **Tier scope.** At Tier 0 these entry points, the preview and the exposure
    line live here. When the Public History Screen (#49) is built, it may take
    the actions over; the board (rules 1–16) and aids stay in the Case File.

**F. Truth-neutrality, battle, save and determinism**

26. **The render is a function of public and held data only:** held fragments,
    the claim view, the public table, seal flags, the verdict, #32's readout,
    the aids and the locale. With the same inputs, the screen is identical
    whoever the maker is.
27. **Fixed order, no nudging.**
    - Candidate rows and columns use the Dossier's table order (content order,
      the same in every seed), never status, support or count order.
    - Evidence rows use ascending `acq_seq` (#28 rule 12). No sorting control
      exists at MVP.
    - No row gets emphasis beyond its status word and glyph. "Most support" is
      never highlighted. The "New since you last looked" marker (rule 28)
      applies to any row whose status or cells changed, whatever the
      candidate.
28. **New since you last looked.** The File stores the `acq_seq` high-water
    mark at last close. "New" tags apply to evidence rows and matrix cells
    only, never to candidate status; a candidate row's only change marker is
    rule 12's "New evidence since you last tested".
29. **In battle, read-only.** In `BATTLE` the File opens with `PLAYER_PAUSE`
    added (Simulation Tick rule 10). The player may read everything. Share,
    Seal, Release, Accuse, the pin, doubt marks and notes are disabled with
    "Not during battle". This answers Simulation Tick OQ 6: reading mid-battle
    gives nothing that reading after the battle does not, because the board has
    no timed element and grants land only at battle end.
30. **Save.** Own section `base:case_file`, version 1: the pin (candidate
    Runtime ID or none), the doubt set (fragment IDs), the notes (fragment ID →
    text, and the case note) and the last-seen `acq_seq`. Ceiling **64 KiB**
    (D7). The section is excluded from the simulation state hash, because no
    simulation system reads it (rule 20). It is not included in the
    bug-report bundle unless the player opts in (player text).
31. **Determinism.** The Case File draws no random numbers. Loops run in
    candidate table order and ascending `acq_seq`. Two runs with the same held
    set give the same board, byte for byte.

### States and Transitions

**Screen states**

| State | Entered when | Leaves to |
|---|---|---|
| Closed | start; File closed | Open (Board), Open (Battle) |
| Open (Board) | opened outside battle; dialog closed or committed | Closed; Open (Action) |
| Open (Action) | Share…, Seal…, Release or Accuse… chosen | Open (Board) on cancel or commit |
| Open (Battle) | opened in `BATTLE` | Closed |

**Candidate status** (per candidate, derived, forward only)

| Status | Condition | Leaves to |
|---|---|---|
| Not contradicted | `contra` = 0 | Contradicted once, Ruled out |
| Contradicted once | `contra` = 1 | Ruled out |
| Ruled out | `contra ≥ 2` | — |

There is no board flag for one candidate remaining (rule 15). A row's *shown*
status updates only when the player tests it (rule 12).

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Truth Seeding & Candidates (#16) | #16 → Case File | Claim view (group, axis, value, class; candidate rows); rule 8's `contra` meaning; G1 (reliable never contradicts the truth) |
| Archive Fragments & Evidence (#28) | #28 → Case File | `held_fragments()`, `unfound_count_by_class()`, chain labels, cards |
| Faction Belief & Blame (#30) | both | Case File → #30: the `support` meaning (D3). #30 → Case File: seal flags, verdict, `preview(action)`, the share / accuse / suppress / release commands |
| Exposure & Rival Investigation (#32) | #32 → Case File | Exposure readout for a verdict, current and in the preview |
| Public History Screen (#49) | Case File → #49 | Tier 0 stub of the actions and preview (rule 25) |
| Simulation Tick & Pause | Case File → it | Adds and removes `PLANNING:case_file`; in battle also `PLAYER_PAUSE` |
| World Clock | — | No days pass while the File is open |
| Input & Controls | Input → Case File | Open action and the Planning-context actions (UI Requirements) |
| Save/Load & Migration (#5) | Case File → #5 | Section `base:case_file` |
| Dossier (#47) | shared view | Attribute table view; codex of tells |
| Reckoning & Endings (#34) | none at MVP | Reads #16 and #30 directly, never the Case File (OQ 5) |
| Telemetry (#54) | Case File → #54 | Open, close, pin and action events |

## Formulas

All maths is integer counting over finite sets. No division.

### D1. Contradicts and fits

`contradicts(f, c) = (value(f) ≠ row(c)[axis(f)])`;
`fits(f, c) = not contradicts(f, c)`.

| Variable | Type | Range | Description |
|---|---|---|---|
| `value(f)` | value key | the axis's values | Claim value |
| `axis(f)` | axis key | 1 of 8 at MVP | Claim axis |
| `row(c)` | map | 8 entries | Candidate's public attribute row |

### D2. Contradictions

`contra(c) = | { group(f) : f ∈ held, class(f) ∈ {DIRECT, RECORD},
contradicts(f, c) } |`

Range 0 – number of held reliable groups. Ruled out when `contra(c) ≥
RULE_OUT_MIN` (2, Truth Seeding rule 8; not a Case File knob).

### D3. Support (owned here)

`support_rel(c) = | { group(f) : f ∈ held, class(f) ∈ {DIRECT, RECORD},
fits(f, c) } |`

`support_tes(c) = | { group(f) : f ∈ held, class(f) = TESTIMONY, fits(f, c) }
∖ { groups counted in support_rel(c) } |`

`support(c) = support_rel(c) + support_tes(c)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `support_rel` | int | 0 – reliable groups held | Reliable chains that fit |
| `support_tes` | int | 0 – testimony groups held | Testimony-only chains that fit |
| `support` | int | 0 – groups held | Equals #30's `support_held`; forgeries never count |

"held" includes sealed fragments in D2 and D3.

### D4. Status

`status(c)` = Ruled out if `contra(c) ≥ 2`; Contradicted once if `contra(c)` =
1; else Not contradicted. `S` = { c : `contra(c) < 2` }. By G1, `contra(truth)` = 0 always, so
`|S| ≥ 1`; nothing is shown when `|S|` = 1 (rule 15).

### D5. Citation order

For a candidate `c`, list each group `g` with a reliable held fragment
contradicting `c`, ordered by `first_acq(g)` = min `acq_seq` of any held
fragment in `g` (this is the chain-label order, #28 D3). Per group, cite the
contradicting fragment with the lowest `acq_seq`.

### D6. Unfound reliable line

`k = unfound_DIRECT + unfound_RECORD`, from `unfound_count_by_class()`. Range 0 –
`R`. Class counts are knobs (Truth Seeding D2), so `k` carries no maker
information.

### D7. Section size

Per held fragment: ID 8 B + doubt flag 1 B + note ≤ `NOTE_MAX_FRAGMENT` × 4 B
(UTF-8 worst case). Plus the case note ≤ `NOTE_MAX_CASE` × 4 B, the pin 8 B and
the high-water mark 2 B.
At `N` = 24, 280 and 2,000: 24 × (9 + 1,120) + 8,000 + 10 = 27,096 + 8,010 =
**35,106 B** (34.3 KiB), under the 64 KiB ceiling.

### Worked example (MVP, C = 3; Truth Seeding fixture, #28 play)

Table rows used (Truth Seeding worked example):

| Axis | Halsk | Orrowen | Ithren |
|---|---|---|---|
| solvent | saline | saline | ammonia |
| command doctrine | consensus | hereditary | rotational |
| script | incised | knotted | incised |
| numbering base | base twelve | base eight | base eight |

Held after day 8 (#28 worked example), in `acq_seq` order:
- f2 RECORD, solvent = saline, g2 → Chain A;
- f5 TESTIMONY, doctrine = hereditary, g5 → Chain B;
- f1 DIRECT, script = knotted, g1 → Chain C.

Cells (D1): f2 fits H and O, contradicts I. f5 fits O, differs from H and I
(weight). f1 fits O, contradicts H and I.

| Candidate | contra (D2) | support_rel | support_tes | support | Status |
|---|---|---|---|---|---|
| Halsk | 1 (C) | 1 (A) | 0 | 1 | Contradicted once |
| Orrowen | 0 | 2 (A, C) | 1 (B) | 3 | Not contradicted |
| Ithren | 2 (A, C) | 0 | 0 | 0 | Ruled out |

**Check:** #28's example states contra(Ithren) = 2 (g1, g2) and contra(Halsk) =
1 (g1). Matches. Ithren's citation (D5): Chain A (`first_acq` 1, f2), then
Chain C (`first_acq` 3, f1): "Ruled out: Chain A (solvent: saline), Chain C
(script: knotted)". `|S|` = 2, so no "only one stands" line. Header: "Held 3 of
6"; reliable unfound `k` = 4 − 2 = 2.

Day 10 the player gains f3 (DIRECT, base eight, g3, `acq_seq` 4 → Chain D). It
contradicts Halsk and fits O and I. Now contra(Halsk) = 2 (C, D): Ruled out.
support(Orrowen) = 3 reliable (A, C, D) + 1 testimony (B) = 4. support(Ithren)
= 1 (D); Ithren stays Ruled out (contra wins). `|S|` = 1, and the File shows
nothing extra (rule 15): the player strikes out Halsk and Ithren and draws the
conclusion. Three reliable fragments were needed, as G2
requires.

**Cross-check with #30 D7:** Accuse Orrowen on this held set gives contra_held
0, support_held 4 ≥ `GF_MIN_SUPPORT` 2: GOOD_FAITH. Accuse Halsk gives
contra_held 2: BAD_FAITH. The faith line shows the same counts as the board.

## Edge Cases

- **If nothing is held**: every candidate is "Not contradicted", support 0.
  The text panel says "You hold no evidence yet. Every candidate stands."
- **If only testimony and forgeries are held**: nothing is ruled out (Truth
  Seeding edge case); testimony may raise `support`.
- **If two held fragments of one chain contradict the same candidate**: they
  add 1 (rule 11). The citation names the earlier one and adds "(2 fragments in
  this chain)".
- **If one chain both fits and contradicts a candidate** (two fragments, two
  axes): the chain counts in `contra` and in `support`. Status follows `contra`.
  The row lists the chain in both columns.
- **If a chain holds a reliable and a testimony fragment that both fit**: it
  counts once, in `support_rel` (D3).
- **If a forgery names a value that fits the only standing candidate**: no
  change; forgeries count nowhere. Its row looks like every other forgery row.
- **If a fragment is sealed, released or lapses**: counts unchanged (rules 9,
  13). The row shows "Sealed" and "Still counts when your good faith is judged".
- **If a rival exposes a fragment the player does not hold**: it is not on the
  board (rule 5). It appears in the public history. If the player later claims
  it (#28 OQ 1), it counts from its grant.
- **If no candidate stands** (impossible by G1; a corrupt save or a content
  error): the board shows "Your held evidence conflicts; report this", logs an
  error at record tier, and offers no actions until reload.
- **If a grant would land while the File is open**: it cannot; the hold stops
  simulation steps. The board updates when the next grant's find card closes.
- **If the File is opened in battle**: read-only (rule 29).
- **If C = 4**: same rules, four columns. "Only one stands" needs three ruled
  out.
- **If the locale changes**: all text re-renders from the string table; values
  use #28's saved fallback when a string is missing. Notes are kept as typed.
- **If a mod candidate's mod is removed**: its fallback name is shown (Truth
  Seeding edge case); counts are unchanged.
- **If the pinned candidate becomes ruled out**: the pin stays. The row shows
  "My theory" and "Ruled out" side by side. Nothing else reacts.
- **If a note exceeds its cap**: input stops at the cap; paste is truncated with
  a notice.
- **Degenerate: reading forever to stall the clock.** Allowed and harmless: the
  world is held, nothing advances, nothing is gained but thinking time.
- **Degenerate: never opening the File to stay deniable.** No effect. Faith is
  judged on the held set (Faction Belief rule 13; rule 20 here).
- **Degenerate: doubting a fragment to escape its contradiction.** Doubt marks
  change no count (rule 18).
- **Degenerate: probing the truth through previews.** The preview is
  truth-blind (Faction Belief rule 16); its faith counts are the board's own.
- **Degenerate: reading the save file.** Out of scope (Truth Seeding rule 12).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Truth Seeding & Candidates (#16) | Hard | Claim view; rule 8 meaning; G1 |
| Archive Fragments & Evidence (#28) | Hard | `held_fragments()`, `unfound_count_by_class()`, cards |
| Faction Belief & Blame (#30) | Hard (both) | Seal flags, verdict, preview, commands; reads D3 |
| Exposure & Rival Investigation (#32) | Soft | Exposure readout (line hidden until #32 exists) |
| Simulation Tick & Pause | Hard | `PLANNING:case_file`, battle read-only |
| Save/Load & Migration (#5) | Hard | Section `base:case_file` |
| Input & Controls | Hard | Open and Planning-context actions |
| Dossier (#47) | Soft | Shared table view |
| Public History Screen (#49) | Hard (reverse) | Takes over the stub |
| Reckoning & Endings (#34) | None at MVP | See OQ 5 |
| Telemetry (#54) | Soft | Events |

Bidirectional check: #16, #28 and #30 already name the Case File. #30 must cite
D3 for `support_held`. Simulation Tick, Save/Load, Input & Controls and #32
need the amendments in the report.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `NOTE_MAX_FRAGMENT` | 280 | 0 – 500 | Feel | Per-fragment note length; 0 disables |
| `NOTE_MAX_CASE` | 2,000 | 0 – 4,000 | Feel | Case note length (D7 holds to 4,000 at N = 24) |
| `THEORY_PINS_MAX` | 1 | 1 – 1 (MVP) | Feel | One stated theory; more needs a UX pass |
| `DOUBT_MARKS` | true | bool | Feel | Doubt tag available |
| `NEW_MARKER` | true | bool | Feel | "New since you last looked" tags |
| `CITE_PER_CHAIN` | 1 | 1 – 3 | Feel | Fragments cited per chain in a reason |
| Section ceiling | 64 KiB | 32 – 128 KiB | — | Save budget (D7) |

Read-only here, owned elsewhere: `RULE_OUT_MIN` 2 (Truth Seeding rule 8),
`GF_MIN_SUPPORT` 2 (Faction Belief D7). In `assets/data/case_file/`. No knob
changes a count or a status.

## Visual/Audio Requirements

- Status glyphs are shapes plus words: "○ Not contradicted", "◐ Contradicted
  once", "✕ Ruled out". Colour may reinforce; it never carries meaning alone.
- Cell marks: "✕ Contradicts" and "● Fits" (reliable only); "fits (weight)" and
  "differs (weight)" in a lighter frame (testimony); a full-width hatched band
  for forgeries.
- No race art, emblem or colour on any row or column (Truth Seeding,
  Visual/Audio; Hulls rule 14). Candidate columns use names only.
- One status-change cue, the same for every candidate and every status. No cue
  or effect for "only one stands".

## Game Feel

- **The click of elimination.** The player selects "Strike out…" and the File
  confirms it with its two chains cited: the elimination is the player's act.
- **Nothing moves under you.** Rows never reorder; the board grows downward in
  find order.
- **Thinking is free.** The clock holds while the File is open.
- **Trust is earned by showing working.** Every count can be expanded to the
  chains behind it.

## UI Requirements

- Layout per rule 2; default focus on the pinned candidate row, else the first
  candidate row.
- **Keyboard:** Tab and Shift+Tab move between panels; arrow keys move within a
  panel and across matrix cells; Enter opens the selected card or citation;
  Esc closes a dialog, then the File. Default binds (Input & Controls to own):
  `P` pin, `D` doubt, `N` note, `S` share, `A` accuse, `E` seal or release.
  Every action is rebindable and reachable from a menu as well.
- **Screen reader:** every cell has an accessible name in words ("Chain A,
  machine record, solvent saline: contradicts Ithren"), through the engine's
  accessibility layer.
- **No colour-only meaning;** text scale follows the global UI scale setting.
- No numeric reliability, raw group IDs or Runtime IDs anywhere (#28 UI
  Requirements).
- 📌 **UX Flag — Case File & Deduction**: board, matrix, text panel and the Tier
  0 action flows belong in `design/ux/case-file.md`, with the Faction Belief
  dialogs.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Contradiction, classes, `contra`, G1, G2, G6, claim view | `design/gdd/truth-seeding-and-candidates.md` | Rules 4, 6, 7, 8, 12, 15; D2; worked example | Rule dependency |
| Held set, chain labels, display order, totals, card, preview inputs | `design/gdd/archive-fragments-and-evidence.md` | Rules 12–17, 23, 24; D3; worked example | Data dependency |
| Preview, faith, seal, commands, command step | `design/gdd/faction-belief-and-blame.md` | Rules 5–9, 13, 16, 18; D7; OQ 1, OQ 4 | Rule dependency |
| Planning hold, battle read-only, OQ 6 | `design/gdd/simulation-tick-and-pause.md` | Rule 10; OQ 6 | Rule dependency |
| Days held during planning | `design/gdd/world-clock.md` | Planning screens list | Rule dependency |
| Open key | `design/gdd/input-and-controls.md` | Planning context | Data dependency |
| Case File answers, held-only, not wiki-dependent | `design/gdd/game-concept.md` | Unique Hook; Pillar 2; anti-pillars; MVP item 6 | Vision |
| #49 stub | `design/gdd/systems-index.md` | CD note | Constraint |

## Acceptance Criteria

- **AC-01 (Logic; rule 7, D1)**: for every axis and candidate in the base table, `contradicts` is true exactly when the values differ.
- **AC-02 (Logic; rules 9, 11, D2)**: the worked example gives contra 1 / 0 / 2 for Halsk / Orrowen / Ithren after f2, f5, f1, and 2 / 0 / 2 after f3.
- **AC-03 (Logic; rule 10, D3)**: the worked example gives support 1 / 3 / 0, then 1 / 4 / 1, with Orrowen's split 3 reliable + 1 testimony.
- **AC-04 (Logic; rule 8)**: a fixture where only testimony and forgeries are held rules nothing out; a forgery fitting a candidate changes no `support`.
- **AC-05 (Logic; rule 10, #30 D7)**: over 10,000 random held subsets of 1,000 seeds, the Case File's `contra` and `support` equal #30's `contra_held` and `support_held` for every candidate.
- **AC-06 (Logic; rule 12, D4)**: status is Ruled out iff `contra ≥ 2`, Contradicted once iff 1, else Not contradicted.
- **AC-07 (Logic; rule 13)**: over random grant, seal, release and lapse sequences, no status ever moves backward.
- **AC-08 (Logic; rule 14, D5)**: Ithren's citation in the worked example reads Chain A then Chain C, and opens f2 then f1.
- **AC-09 (Logic; rule 15)**: with exactly one candidate not ruled out, the rendered File is identical, row for row, to a state with two not ruled out apart from the struck rows (no line, flag or cue);
- **AC-09b (Logic; rule 12)**: an untested row shows no status, only "New evidence since you last tested" when its counts changed; "Strike out…" on a row with `contra` 1 answers "Not yet: you hold 1 reliable contradiction"; "Test" on a row with `contra ≥ 2` confirms and cites both chains;
- **AC-09c (Logic; rules 12, 15)**: a string scan of every Case File string finds none of "maker", "correct", "solved", "guilty", "true" applied to a candidate.
- **AC-10 (Logic; rule 16)**: forgery rows have no per-candidate cells; testimony rows never use the contradiction mark; only DIRECT and RECORD rows do.
- **AC-11 (Logic; rule 26, G6)**: a fixture with fixed held fragments rendered under each of the C makers gives byte-identical screen text, order and glyph keys. The Case File module has no reference to the maker field or #16's reliable-contradiction flag (static check).
- **AC-12 (Logic; rule 27)**: candidate rows follow content table order and evidence rows follow `acq_seq` in every state; no state sorts by status or count.
- **AC-13 (Logic; rules 18, 20)**: toggling pin, doubt marks and notes leaves every simulation hash, #30 result, preview and status unchanged.
- **AC-14 (Logic; rule 20)**: two playthroughs with identical commands, one opening the File 0 times and one 50 times, give identical faith judgements and simulation hashes.
- **AC-15 (Logic; rule 1)**: opening adds `PLANNING:case_file`; no tick advances and no day passes while it is open; closing removes only that reason.
- **AC-16 (Logic; rule 29)**: in `BATTLE`, opening adds `PLAYER_PAUSE`; every action and aid is disabled with "Not during battle"; closing leaves the battle Paused (player).
- **AC-17 (Integration; rules 22, 23)**: preview then commit from the Case File gives exactly the previewed result, and a grant attempted between them is deferred (#28 AC-28, #30 AC-19).
- **AC-18 (Logic; rule 22)**: the text panel shows every #30 rule 18 line in that order for share, accuse and suppress fixtures.
- **AC-19 (Logic; rule 6, D6)**: the header shows "Held h of N" and `k` equals the unfound DIRECT plus RECORD count, identical across makers.
- **AC-20 (Logic; rule 30, D7)**: a save round trip of `base:case_file` is byte-identical; at N = 24 with full notes in 4-byte characters it is ≤ 64 KiB; it is absent from the state hash and from the default bug-report bundle.
- **AC-21 (Logic; edge case)**: a corrupted fixture with zero standing candidates shows the conflict line, logs one error and disables actions.
- **AC-22 (UI; Visual/Audio)**: a greyscale screenshot of the board distinguishes every status and cell mark; retained in `production/qa/evidence/`.
- **AC-23 (UI; UI Requirements)**: every panel, cell and action is reachable and operable by keyboard alone; screenshots of board, matrix, text panel and each dialog retained.
- **AC-24 (Playtest; rules 14, 16)**: in a 5-player playtest, at least 4 of 5 explain a ruled-out status in their own words by naming its two chains, and none counts a forgery as proof.
- **AC-25 (Playtest; rule 27)**: no tester reports that order, highlight or wording "gave away" the maker.
- **AC-26 (Playtest; concept pass bar)**: telemetry records whether each tester opened the Case File before each share (logged, unscored).

## Open Questions

Resolved with the recommended defaults, for the owner to confirm at review:
- **`support` meaning** (Faction Belief OQ 1): distinct fitting groups,
  testimony in, forgeries out, sealed in (D3).
- **Board always on.** Every status is shown without a query. Stating a theory
  is free and unlimited in the concept, so a query step adds clicks, not
  mystery (Pillar 4). The pin is the "state a candidate" act.
- **No solved banner** (CD review reversed the earlier default): nothing is
  shown when one candidate remains; statuses appear when the player tests a
  row ("Board always on" now means always readable on request).
- **Aids at MVP:** one pin, doubt marks, notes; none changes a number.
- **Mid-battle reading** is allowed, read-only (Simulation Tick OQ 6).
- **Testimony counts in `support`** (matches Faction Belief D7).
- **Capped free-text notes stay at MVP** (the producer may cut them to pins and
  doubt marks at sprint planning without changing any rule here).
- **Only held fragments count**; a rival-exposed fragment the player does not
  hold never changes the board.

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 4 | `design/accessibility-requirements.md` does not exist; the keyboard and no-colour rules here are local until it does. | ux-designer | Pre-Production gate |
| 5 | Does the Reckoning (#34) need anything from the Case File? Recommendation: no; it reads #16 and #30 directly. Then the index dependency should be removed. | #34 owner | #34 design |
| 6 | #32's readout wording and API (`exposure_readout(verdict)`), shown in rule 24. | #32 owner | #32 design |
