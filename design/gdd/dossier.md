# Dossier

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (opening loss cost shown; read-only in battle; a loss always reveals something; honest wiki note; seen-only readiness; truth-blind lines)
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — defeats fill in the Dossier); Pillar 4 (Plan in the Open — per-node weaknesses, counters and readiness are readable before you commit)

## Summary

The Dossier is the planning screen that holds what the player has learned about each machine node: weaknesses, counters, doctrine, readiness, the helper faction and the sites searched. It owns the reveal model: lines start hidden and become visible only from battle facts the Debrief hands over, so defeats fill it in and no wiki is needed. Reading it is a planning hold, `PLANNING:dossier`, and never costs days.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Machine Nodes & Strongholds, After-Action Debrief, Allied Lending`

## Overview

The Dossier is one screen with one page per known machine node, plus two
shared pages: the public attribute table (Truth Seeding rule 4) and the Sites
list (Points of Interest). A node page shows weaknesses, counters, doctrine
sentences, the readiness range, the helper faction line, the defeat-cost quote
and the attempt log. Most of it starts hidden. The Dossier is the only system
that decides when a line becomes visible. It reads `DossierFacts` from the
After-Action Debrief (rule 22) when the Debrief closes and turns those facts
into permanent lines by fixed rules. Every revealed line is generated from
data: counter content, doctrine fields, node data and the player's own
battles. Nothing on a node page depends on the seeded maker (Machine Nodes
rule 1a). The Dossier also owns `known`, the input that narrows the readiness
range (Machine Nodes D4), and the pure presenter the AI-vs-AI Runner's
`BotView` reads.

## Player Fantasy

*"I lost. I open the Dossier and two new lines are waiting: 'Seen on day 14:
links held. Try: cut the relay links.' The range moved. It is still
Outmatched to Contested, but now I know why, and I know what to buy."* The
player should feel like an investigator building a case file on an enemy,
one defeat at a time.

- **Pillar 1, *Every Defeat Is a Lead***: every loss that names a cause adds
  a line. A loss is never empty-handed.
- **Pillar 4, *Plan in the Open***: what you know is on one page, with the
  same numbers the Refit screen and pre-battle panel use.
- **Discovery (MDA)**: lines are earned in play, not looked up. A counter
  that works by accident is still recorded.
- **Competence (SDT)**: the readiness range narrows as you learn, so the
  player sees knowledge turn into certainty.
- **Achievers**: a node page shows how much is still unseen ("2 more counters
  not yet seen").

## Detailed Design

### Core Rules

**A. The screen and the hold**

1. **One screen, three kinds of page.** Node pages (one per node in the
   SIGHTED or later state), the Table page and the Sites page. Node pages are
   sorted by first sighting day, ties to the lower node ID.
2. **Reading never costs days.** Opening the Dossier sets the hold
   `PLANNING:dossier` with Simulation Tick & Pause; closing clears it (World
   Clock rule 3). The Dossier opens from the sector map, a port and the
   pre-battle panel. It opens in battle read-only, as the Case File does,
   adding `PLAYER_PAUSE`; no reveal applies until the Debrief closes.
3. **Reading changes nothing.** Opening, paging and closing never change
   reveal state, the clock, RNG streams or any other system. Only rule 9's
   apply step writes reveal state.

**B. What is known at start**

4. **A node page appears when the node's site is revealed** (Sector Map rule
   23, `is_revealed(node)`). Nodes in systems not yet visited and not named by
   a reveal have no page; the route preview's "unvisited: sites unknown"
   (Sector Map rule 14) stays true in the Dossier.
5. **Shown from the first sighting** (the SIGHTED state):
   - node name, region, keystone hull class and the stronghold's member hull
     classes (authored, seed-independent, Machine Nodes rule 1);
   - **weaknesses**, derived from the members' hull `counters[]` tags
     (Machine Nodes rule 18), one line per distinct tag, worded by the tag's
     text key (e.g. `relay` "fed through relays", `regrowing` "armour
     regrows"). Never authored per node;
   - the fixed line "Strongholds never withdraw" (Machine Nodes rule 3);
   - the counter count: "{n} counters, none yet seen";
   - the readiness range and band (rule 15) at `known` 0;
   - the helper faction line (rule 17), if `helper_faction_id` is set;
   - the defeat-cost quote (rule 18);
   - the patrol line "Patrols: route known" when Sector Map has revealed the
     node's roaming route.
6. **Hidden at start**: every counter's name, action, role and kit cost;
   every doctrine sentence; the doctrine name.
7. **The Table page shows from the start**: the public attribute table, all
   candidates and all 8 axes (Truth Seeding rule 4), in content order. It is
   the same view the Case File uses.
8. **The Sites page** lists every searched POI with its name, kind, system
   and log, in search order (Points of Interest UI). Revealed but unsearched
   POIs are not listed here; the map shows them.

**C. The reveal model**

9. **Apply on hand-off.** When the Debrief closes and hands over
   `DossierFacts` (Debrief rule 22), the Dossier applies it at once, in the
   same held tick, in this order: counters, then doctrine, then node facts.
   Apply is keyed by `(node_id, attempt_index)`; a second hand-off with the
   same key is ignored. A REVIEW of a stored Debrief result sends nothing
   (Debrief States).
10. **Counters.** For each entry in `counters_evidenced[]` whose counter is
    listed in the node's `dossier.counters[]`:
    - polarity **cause** and `named` true: the counter is revealed with the
      mark *seen as cause* on that world day;
    - polarity **worked**: the counter is revealed with the mark *worked* on
      that world day;
    - polarity **cause** and `named` false: nothing is revealed. The fact
      stays in the stored Debrief Timeline (Open Question 3).
    A counter not listed on the node is ignored. A counter already revealed
    gains the missing mark; a mark already set keeps its first day.
10a. **A loss always reveals something.** A loss that reveals no new line
    reveals the first held cause in `counters_evidenced[]` order as *seen as
    cause*. If every counter is already revealed, the log row reads "No new
    counters: all seen."
11. **Doctrine.** For each `doctrine_observations[]` entry
    `{anchor, doctrine_id, event, tick}`, every doctrine sentence of
    `doctrine_id` whose reveal event (Fleet Coordination rule 3) matches
    `event` is revealed. Doctrine sentences are keyed by
    `(doctrine_id, field)` and shared across nodes: once the Anvil is seen
    contracting, every Anvil node shows that sentence. The doctrine name
    shows on a node page once any sentence of that doctrine is revealed.
12. **Node facts.** `node_facts` adds one row to the node's attempt log:
    attempt number, world day, outcome word, and "Keystone fell to {p}%" (D3)
    or "Keystone broken". Node facts never reveal a counter or a sentence.
13. **A win reveals by the same rules, and only by them.** A win's
    `DossierFacts` reveal exactly what its battle evidenced. Breaking a node
    reveals nothing extra. When a node goes BROKEN_UNCLAIMED or INERT its page
    is marked "Broken on day {d}" and freezes (Open Question 1).
14. **Reveals are permanent** and part of the save. Nothing hides a line
    again: not a mod change, not a load, not a retreat.

**D. What a revealed counter shows**

15. **Readiness.** The page shows Machine Nodes D4 computed live with
    `known` from D1 and `k` from D2. It shows the range and the band words
    (Outmatched, Contested, Ready; "Outmatched to Contested" across two).
    When `s` > 1200 the band words are replaced by "uncalibrated above
    Admiral"; the range still shows. Never a single number or a win
    percentage. The range counts only counters you have seen.
16. **The counter line.** Each revealed counter shows, in this order:
    - name (`name_key`) and role words: `solo` "can win on its own";
      `supporting` "helps, not enough alone"; if `requires_allies` true,
      "needs allied ships" and a pointer to the helper line;
    - provenance: *seen as cause* "Seen on day {d}: {cause}" (`cause_key`);
      *worked* "Worked on day {d}"; both marks show both;
    - action: "Try: {action}" (`action_key`);
    - cheapest kit cost, the same figure as Refit rule 19 (Refit D4 at the
      current yield);
    - fitted state, read from Refit rule 19: Kit fitted, In stores, or
      Missing "{k} items away ({cost})", with "(with lent ships)" when it
      applies.
    Unrevealed counters show only as "{n} more not yet seen". Refit's counter
    line lists exactly the counters in the REVEALED state here.
17. **The helper faction line.** For a node with `helper_faction_id = f`,
    the page shows `helper_line(f)` exactly as Allied Lending rule 22 returns
    it: the condition in words, the status now, the pending GRANTS / LOSES
    line, and the exposure line "If this investigation exposes the public
    history: loses the ⟨f⟩ escort". The exposure line is shown whenever an
    investigation is running and the escort is at stake, whether or not the
    public history is true; it never reads unfound fragments. The Dossier
    adds no number and never
    suggests a share or accusation (Allied Lending rule 23).
18. **The defeat-cost quote.** Each node page shows Credits' defeat cap
    (Credits rule 7) "If you lose: up to {X} credits, plus up to {N} rest days
    (≈ {Y} upkeep)", and, while suppression upkeep is active, "suppression
    covered for {N} days after a worst-case bill". On a node with
    `exempt_lasting_cost` true, the opening node included, the line reads
    "A loss here costs nothing" (Credits rule 8) while the exemption is unused
    (Onboarding & Opening Sequence's exactly-once rule); after it is used the
    ordinary defeat-cost line returns. Planning information is
    never withheld.

**E. Truth, determinism and the Runner**

19. **Truth-neutral.** Every node-page line is a pure function of node data,
    counter content, doctrine data, Credits and Allied Lending outputs, and
    the reveal state. The Dossier never reads the seeded maker or any
    Truth Seeding field except the public table.
20. **The presenter is pure.** `present(node_id, reveal_set, fleet_view)`
    returns the node page as data. The screen and the Runner both call it.
21. **The Runner's stated `known`.** `BotView` calls `present` with a stated
    reveal set (Runner rule 2). The **proof reveal set** for counter `c` on
    node `n` is `{c}` alone with no doctrine sentences: the smallest set at
    which the Dossier first shows `c` (D4). Plans may use only weaknesses,
    hull classes and that counter's line.

### States and Transitions

**Node page**

| State | Entered when | Shows | Leaves to |
|---|---|---|---|
| HIDDEN | campaign start | nothing | SIGHTED |
| SIGHTED | `is_revealed(node)` true | rule 5 lines | STUDIED, BROKEN |
| STUDIED | first counter or sentence revealed for the node | rules 5 and 16 lines | BROKEN |
| BROKEN | node enters BROKEN_UNCLAIMED or INERT | frozen page, "Broken on day {d}" | — |

**Line** (counter or doctrine sentence)

| State | Entered when | Leaves to |
|---|---|---|
| UNSEEN | campaign start | REVEALED |
| REVEALED | rule 10 or 11 | — (permanent) |

A line revealed since the screen was last opened carries a **new** marker
until its page is viewed. The marker is display state, saved, and never
counts toward `known`.

**Screen**

| State | Entered when | Hold | Leaves to |
|---|---|---|---|
| CLOSED | default | none | OPEN |
| OPEN | opened (rule 2) | `PLANNING:dossier` | CLOSED |

### Interactions with Other Systems

| System | Direction | What flows |
|---|---|---|
| Simulation Tick & Pause (#1) | Dossier → #1 | Sets and clears `PLANNING:dossier` |
| Machine Nodes & Strongholds (#23) | #23 → Dossier | `dossier.counters[]`, roles, `helper_faction_id`, member hull tags, node state, D4 |
| After-Action Debrief (#24) | #24 → Dossier | `DossierFacts` on close; stored results reopened from the attempt log |
| Fleet Coordination | → Dossier | One generated sentence per doctrine field, each with its reveal event |
| AI-vs-AI Runner (#25) | Dossier → #25 | `present()` at a stated reveal set |
| Refit & Loadout | both | Kit cost and fitted state in; the REVEALED counter list out |
| Allied Lending (#33) | #33 → Dossier | `helper_line(f)` |
| Credits, Upkeep & Sinks (#18) | #18 → Dossier | Defeat cap, rest-day quote, suppression coverage |
| Truth Seeding & Candidates (#16) | #16 → Dossier | Public attribute table |
| Points of Interest (#29) | #29 → Dossier | Searched POIs and logs |
| Sector Map & Travel (#26) | #26 → Dossier | `is_revealed`, roaming-route reveal |
| Case File & Deduction | shared view | Attribute table view |
| Gameplay Settings & Modifiers (#7) | #7 → Dossier | `s` for D4 and the uncalibrated rule |
| Save/Load & Migration (#5) | both | Dossier section (rule 14) |

## Formulas

### D1. Known

```
doc_known(n) = count of REVEALED sentences (d, f) with d in doctrines(n)
ctr_known(n) = count of REVEALED counters on n
known(n)     = min(KNOWN_MAX, doc_known(n) + ctr_known(n))
```

| Variable | Range | Description |
|---|---|---|
| doctrines(n) | 1 – 3 | Distinct `doctrine_id` of n's anchors |
| doc_known | 0 – 27 | Revealed sentences of those doctrines (9 fields each, Fleet Coordination rule 1; Open Question 2) |
| ctr_known | 0 – 6 | Revealed counters on n |
| `KNOWN_MAX` | 12 | Machine Nodes D4 range for `known` |

### D2. Fielded revealed counters

```
k(n) = count of counters c on n with REVEALED(c) and fitted(c)
```

`fitted(c)` is Refit rule 19's **Kit fitted** state; an order-only kit counts
only when its orders are assigned in the pre-battle plan (Machine Nodes D4).
Range 0 – 6. The range counts only counters you have seen. A fitted counter
not yet revealed adds nothing, so probing kits cannot leak unseen counters.

### D3. Keystone line

```
p = lowest_keystone_pm ÷ 10        (integer division, truncates)
```

Range 0 – 100. `lowest_keystone_pm` 357 shows "Keystone fell to 35%".

### D4. Proof reveal set

```
proof_set(n, c) = { counter c }            → known = 1
```

### Worked example (checked)

Opening node, doctrine Anvil. First battle is lost. `DossierFacts`:
`core_exposure` cause, named; `relay_cut` cause, named; `regrowth_stall` cause,
not named; Anvil `on_cut` contraction; one `FocusAssigned`.

- Rule 10: `core_exposure` and `relay_cut` REVEALED (*seen as cause*);
  `regrowth_stall` stays UNSEEN. `ctr_known` = **2**.
- Rule 11: Anvil `on_cut` and `focus_split` sentences REVEALED.
  `doc_known` = **2**. D1: `known` = min(12, 4) = **4**.
- The player fits a Rootcutter kit for `relay_cut`: D2 `k` = **1**.
- Machine Nodes D4 with `str_player` 3,000 and `str_node` 6,000:
  R = 3,000 × 1,000 ÷ 6,000 = **500**; credit = 300 × 1 = 300;
  R_eff = 500 × 1,300 ÷ 1,000 = **650**;
  unc = max(100, 400 − 40 × 4) = **240**;
  low = 650 × 760 ÷ 1,000 = **494**; high = 650 × 1,240 ÷ 1,000 = **806**.
- Bands: high 806 ≥ 600 and low 494 < 600, high < 1,000 → "Outmatched to
  Contested" (494 – 806). Before the battle, at `known` 0 and `k` 0: R_eff 500,
  unc 400, range 300 – 700, also "Outmatched to Contested" but wider.

## Edge Cases

- **`DossierFacts` empty** (no counter held, no observation): only the
  attempt log row is added; the Debrief shows no "Dossier updated" note.
  On a loss with held causes but no new line, rule 10a reveals the first
  held cause. If every counter is already revealed, the row reads "No new
  counters: all seen."
- **Same facts handed twice** (save and load during the Debrief hold): the
  `(node_id, attempt_index)` key ignores the second (rule 9).
- **A counter evidenced that the node does not list**: ignored (rule 10).
- **Worked before ever seen as cause**: revealed with *worked* only; the
  cause line appears if a later loss names it.
- **Both marks in one battle**: both are set with the same day.
- **`known` above 12** (two doctrines, many sentences): clamped by D1;
  `unc` is already at `UNC_MIN` from `known` 8.
- **`s` above 1200**: the range shows; the band reads "uncalibrated above
  Admiral" (rule 15).
- **`s` changed mid-campaign**: the readiness range recomputes on open; reveal
  state is untouched (Settings rule 10 never changes counters).
- **`str_node` 0**: D4's `max(1, …)` holds; nothing special here.
- **Node broken by a loss-class battle**: page goes BROKEN; its reveals from
  that battle still apply first (rule 9 runs before the state change shows).
- **A roaming-fleet battle**: doctrine observations reveal shared sentences;
  counters apply only if `node_facts` names a node (Open Question 6).
- **A mod changes a doctrine field**: the sentence text regenerates from data
  (Fleet Coordination rule 3); its REVEALED state, keyed by field, stays.
- **A mod counter is removed after reveal**: the line shows its stored text
  with "(content removed)"; it no longer counts in `ctr_known`.
- **A helper faction exists but no counter needs allies**: the helper line
  still shows (rule 5). It never hints which counter.
- **No POI searched yet**: the Sites page reads "No sites searched yet."
- **Degenerate: throwing battles to farm reveals.** Each loss costs days and
  credits (Credits rule 7) and reveals only predicates that held. A counter
  you never trigger never reveals, so farming buys no free answers.
- **Degenerate: reading the wiki.** A wiki can name counters early; that
  saves an attempt, not the game. The Dossier never requires it (rule 21),
  and the truth is seeded, so it cannot be looked up.

## Dependencies

| System | Kind | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | `PLANNING:dossier` hold |
| Machine Nodes & Strongholds (#23) | Hard | Dossier block, tags, node state, D4 |
| After-Action Debrief (#24) | Hard | `DossierFacts`, stored results |
| Fleet Coordination | Hard | Doctrine sentences and reveal events |
| Refit & Loadout | Hard | Kit cost, fitted state |
| Allied Lending (#33) | Hard | `helper_line(f)` |
| Credits, Upkeep & Sinks (#18) | Hard | Defeat cap and quotes |
| Truth Seeding & Candidates (#16) | Hard | Public attribute table |
| Points of Interest (#29) | Hard | Searched POIs and logs |
| Sector Map & Travel (#26) | Hard | `is_revealed`, roaming route |
| Gameplay Settings & Modifiers (#7) | Hard | `s` |
| Save/Load & Migration (#5) | Hard | Dossier section |
| AI-vs-AI Runner (#25), Refit & Loadout, Case File & Deduction | Hard (reverse) | `present()`, REVEALED list, table view |

Bidirectional check: Machine Nodes, Debrief, Allied Lending, Credits, Truth
Seeding, Points of Interest, Case File and the Runner already name the
Dossier. Simulation Tick & Pause, Fleet Coordination, Sector Map and Save/Load
need their rows confirmed (Open Questions 7, 8).

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `KNOWN_MAX` | 12 | 8 – 12 | Curve | Cap on `known`; must equal Machine Nodes D4's upper range |
| `REVEAL_UNNAMED_CAUSE` | false | bool | Gate | If true, rule 10 also reveals unnamed held causes; faster learning, noisier pages |
| `DOCTRINE_SHARED` | true | bool | Gate | If false, sentences are keyed per node; later nodes start at lower `known` |
| `SHOW_UNSEEN_COUNT` | true | bool | Feel | "{n} more not yet seen" line |
| `KEYSTONE_LINE` | true | bool | Feel | Attempt-log keystone percentage (D3) |

`UNC_MIN`, `UNC_MAX`, `UNC_STEP`, `COUNTER_CREDIT_PM`, `BAND_LOW` and
`BAND_HIGH` are Machine Nodes' knobs; the Dossier reads them and never
redefines them.

## Visual/Audio Requirements

- A **new** marker on lines revealed since the last open; it clears on view.
- REVEALED and UNSEEN counters must differ by shape or text, not colour alone.
- A short cue when the Dossier opens with new lines. Art and audio direction
  own the look and the sound.

## Game Feel

- Opening is instant and pauses the world; the player never feels the clock.
- After a loss the first page shown is the node just fought, scrolled to its
  new lines.
- A narrowing range should read as progress: the old range is shown faintly
  for one view after it changes.

## UI Requirements

- Node page sections, in order: header and state, readiness, weaknesses,
  counters, doctrine, helper line, defeat-cost quote, attempt log.
- Attempt log rows open the stored Debrief result in REVIEW (Debrief States).
- Counter rows link to the Refit screen when docked at a port with refit.
- Keyboard and pad navigation; text respects `ui_scale`. Detailed layout is
  the Dossier UX spec's (`design/ux/dossier.md`, not yet written).

## Cross-References

| Topic | Document | Section | Use |
|---|---|---|---|
| Truth-neutral nodes, counters, D4 | `design/gdd/machine-nodes-and-strongholds.md` | Rules 1a, 12–13, 18–23; D4 | Rule dependency |
| `DossierFacts` | `design/gdd/after-action-debrief.md` | Rule 22 | Input |
| Doctrine sentences | `design/gdd/fleet-coordination.md` | Rule 3 | Input |
| Helper line | `design/gdd/allied-lending.md` | Rules 22–23 | Input |
| Counter line | `design/gdd/refit-and-loadout.md` | Rule 19 | Shared figures |
| Defeat cap | `design/gdd/credits-upkeep-and-sinks.md` | Rules 7–8, 12; UI | Input |
| Public table | `design/gdd/truth-seeding-and-candidates.md` | Rule 4 | Input |
| Sites | `design/gdd/points-of-interest.md` | UI | Input |
| Unvisited systems | `design/gdd/sector-map-and-travel.md` | Rules 14, 23 | Rule dependency |
| `BotView` | `design/gdd/ai-vs-ai-runner-and-ai-debug-tools.md` | Rule 2 | Consumer |
| Reading never costs days | `design/gdd/world-clock.md` | Rule 3 | Rule dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 3)**: opening, paging and closing the Dossier 100 times leaves the save byte-identical apart from the new markers, and the world day unchanged.
- **AC-02 (Integration; rule 2)**: while the Dossier is open, `PLANNING:dossier` is in the hold list and no tick advances; it is removed on close.
- **AC-03 (Logic; rule 4)**: a node in an unvisited, unnamed system has no page; after `reveal(node)` it is SIGHTED.
- **AC-04 (Logic; rules 5–6)**: a SIGHTED node shows its weaknesses, counter count, readiness at `known` 0 and no counter name, action or doctrine sentence.
- **AC-05 (Logic; rule 5)**: for every MVP node, the weakness lines equal the distinct hull `counters[]` tags of its members.
- **AC-06 (Logic; rule 10)**: a fixture with one named cause, one worked and one unnamed cause reveals exactly the first two.
- **AC-07 (Logic; rule 10)**: a counter not listed on the node in `counters_evidenced` changes nothing.
- **AC-08 (Logic; rule 11)**: an Anvil `on_cut` observation on node A reveals that sentence on every Anvil node.
- **AC-09 (Logic; rule 9)**: handing the same `DossierFacts` twice gives the same reveal state as handing it once.
- **AC-10 (Logic; rule 13)**: a win reveals exactly what its facts evidence; breaking a node reveals nothing more.
- **AC-11 (Logic; D1–D4)**: the worked example's fixture gives `known` 4, `k` 1 and the range 494 – 806, "Outmatched to Contested".
- **AC-12 (Logic; rule 15)**: at `s` 1250 the band reads "uncalibrated above Admiral" and the range still shows.
- **AC-13 (Logic; rule 16)**: Refit's counter line lists exactly the Dossier's REVEALED counters, with the same cheapest kit cost.
- **AC-14 (UI; rule 16)**: a revealed counter shows role words, provenance, action, kit cost and fitted state; retained screenshot in `production/qa/evidence/`.
- **AC-15 (UI; rule 17)**: with an investigation running whose exposure would push `S_f` past `REFUSE_PM`, the node page shows the exposure line, matching Allied Lending AC-20; retained screenshot.
- **AC-16 (UI; rule 18)**: the defeat-cost quote equals the pre-battle panel's figures; the opening node reads "A loss here costs nothing"; retained screenshot.
- **AC-17 (Logic; rule 19)**: two saves with different seeded makers and the same facts give byte-identical node pages for every node, including with an investigation running and suppression active.
- **AC-17a (Logic; rule 10a)**: a loss whose facts reveal no new line reveals the first held cause in `counters_evidenced[]` order as *seen as cause*; with every counter already revealed, the log row reads "No new counters: all seen."
- **AC-18 (Logic; rules 20–21)**: `present(n, proof_set(n, c))` shows counter `c` and no other counter or sentence; `BotView`'s field set at that set equals the presenter's (Runner AC-01b).
- **AC-19 (Logic; rule 7)**: the Table page shows all candidates and 8 axes at campaign start.
- **AC-20 (Logic; rule 8)**: the Sites page lists searched POIs only, in search order.
- **AC-21 (Logic; rule 14)**: reveal state survives save and load unchanged.
- **AC-22 (Playtest; Pillar 1)**: 4 of 5 new players, after losing the opening stronghold, name a counter from the Dossier alone, without outside help (Machine Nodes AC-22).
- **AC-23 (Playtest; rule 15)**: 4 of 5 players say the range "got more certain" after their second attempt.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **Breaking a node reveals nothing extra** (rule 13): what the Dossier holds
  stays earned in battle.
- **The opening node says 'A loss here costs nothing'** (rule 18): planning
  information is never withheld; the lesson is the Debrief's.
- **The Dossier opens in battle read-only**, as the Case File does, with
  `PLAYER_PAUSE` added.
- **Polarity**: each `counters_evidenced[]` entry carries `polarity: cause |
  worked` (Debrief rule 22 amended).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 2 | **Doctrine sentence count.** D1 assumes 9 fields per doctrine (Fleet Coordination rule 1 plus `consolidate_sr`, `withdraw_sr`). Confirm which fields get a sentence, and amend Machine Nodes D4's `known` row to "min(12, …), Dossier D1; doctrine sentences shared by `doctrine_id`". | game-designer, Fleet Coordination owner | Before Dossier review |
| 6 | **Roaming-fleet battles**: does `node_facts` carry the home node ID, so counters can reveal? | Debrief owner | Before Dossier review |
| 7 | **Hold list and save section** not verified: Simulation Tick & Pause must list `PLANNING:dossier`; Save/Load must add the Dossier section. | Tick owner, Save/Load owner | Before implementation |
| 8 | **Cross-doc rows not verified**: Fleet Coordination and Sector Map dependency tables naming the Dossier; Credits' function name for the defeat-cap quote; the weakness text key per hull tag (Hulls). | game-designer | Before Dossier review |
| 9 | **Runner proof `known`**: confirm Runner rule 2 reads "the known at which the Dossier first shows the counter" as Dossier D4's proof set, `known` 1. | Runner owner | Before Runner calibration |
| 10 | **Band words and calibration** (Machine Nodes Open Question 3). | ux-designer | Before Dossier review |
