# Archive Fragments & Evidence

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (medium-neutral tells; honest fantasy; unfound count and lost sites in the share preview; witness race never implied)
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — fragments are the evidence the player weighs and chooses what to share); Pillar 1 (Every Defeat Is a Lead — breaking a stronghold yields a fragment); Pillar 4 (Plan in the Open — provenance and reliability are readable)

## Summary

Archive Fragments & Evidence turns Truth Seeding's case into evidence the player finds and holds. Fragments are placed by a maker-blind shuffle into authored slots (stronghold nodes, a derelict, an archive and a port witness), granted on discovery in acquisition order, and shown with one value-only template per axis, a provenance block and learnable forgery tells. It hands the held set to the Case File, the share card to Public History and Faction Belief, and unfound fragments to Exposure, and nothing on a card, a slot or an ID order carries the maker.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Runtime ID Service, Content Data & Mod Loading, Truth Seeding & Candidates`

## Overview

Archive Fragments & Evidence turns the seeded case into things the player can
hold. Truth Seeding (#16) decides which claims exist. This system decides where
each one waits, how it is found, and how it reads. At new game it places every
seeded fragment into an authored **fragment slot** (a broken stronghold, a
derelict, an archive or a witness), with a maker-blind shuffle on its own
stream. A fragment is **found** when its source grants it: a stronghold win, a
claim at a broken node, a search at a derelict or archive, a witness on first
docking. It then sits in the player's **evidence locker** in acquisition order,
as a card: one filled template, a provenance block (class, source, custody,
chain) and, for forgeries, a learnable tell. It hands the Case File, Faction
Belief & Blame (#30), the sharing preview (#49) and Exposure (#32) what they
need, and never computes `contra`. Its own save section holds placement and
found state. Nothing it shows, orders or places carries information about the
maker (G6).

## Player Fantasy

You are a detective with a locker of evidence. Each card has a story of how it
got to you: a relic sealed where it was dug up, a machine log with an unbroken
chain, an account kept at a port, or a copy dated before its own source. The
card never names a race: you turn its value into suspects yourself, from the
Dossier. A forgery is always marked, and its tell shows you how copies give
themselves away, a vocabulary you carry from one campaign to the next. Testimony feels like a real witness: sure of
itself, often right, never proof. The fragments come in the order you found
them, so your locker is a record of your own campaign.

MDA: **Discovery** first (finding, reading, learning the tells), **Narrative**
second (the custody story on each card), **Challenge** third (weighing classes
and chains). SDT: **Competence** (tells are readable and learnable; Pillar 4),
**Autonomy** (which leads to chase, what to share; Pillar 2).

The player should never feel "the card's wording gave it away", "it was placed
there because of who did it" or "the game tricked me with a hidden label".

## Detailed Design

### Core Rules

**A. Slots and placement**

1. **A fragment slot is a `fragment_slot` content kind** (base kind; envelope by
   Content Data Core Rule 7; body schema owned here). It is authored and
   seed-independent, and is **not** a truth kind. Body fields:

   | Field | Type | Range | Notes |
   |---|---|---|---|
   | `slot_kind` | enum | `document`, `account` | `document` hosts DIRECT_PHYSICAL, RECORD or FORGERY; `account` hosts TESTIMONY only |
   | `source_kind` | enum | `node`, `derelict`, `archive`, `witness` | `node`, `derelict`, `archive` need `document`; `witness` needs `account` |
   | `host` | ref → `machine_node`, `poi` or `port` | 1 | `node` → a machine node's `fragment_slot`; `derelict`, `archive` → a POI (#29); `witness` → a port or a POI |
   | `site_name` | string key | 1 | Shown on the card. Authored, truth-neutral (lore bible §1.1). A witness's `site_name` and testimony card never state or imply the speaker's race: the host port is where the account is kept, not whose it is |

2. **Load validation** (content load, all errors): `SLOT_KIND_MISMATCH`
   (`source_kind` and `slot_kind` disagree); `SLOT_HOST_UNKNOWN`;
   `SLOT_HOST_SHARED` (two slots name one host); `FRAGMENT_SLOTS_SHORT`
   (document slots < `R + H`, or account slots < `T`, Truth Seeding D2);
   `SLOT_NONSTRONGHOLD_SHORT` (fewer than `NONSTRONGHOLD_DOC_MIN` document slots
   whose `source_kind` is not `node`).
3. **Placement happens once**, at new-game setup, in the campaign step, right
   after Truth Seeding reaches Seeded. It runs on its own stream,
   `base:truth.placement`, so placement never shares draws with the case and a
   slot change never changes the maker.
4. **Placement is maker-blind.** Its only inputs are each fragment's class, the
   slot list and the stream. It never reads a fragment's axis, value, group or
   the maker. The number of draws depends only on counts fixed by knobs
   (Formulas D1), so stream use is the same in every seed.
5. **The algorithm** (Formulas D1): document fragments are shuffled uniformly
   onto chosen document slots; testimony is shuffled onto chosen account slots.
   At least `NONSTRONGHOLD_DOC_MIN` (1) document fragments go to non-node slots,
   so there is evidence to find before the first return (concept). Unchosen
   slots stay **empty** (surplus).
6. **Each forgery gets a tell**, drawn uniformly from the shared tell set
   `FORGERY_TELLS` on the same stream, after the shuffle. The tell never depends
   on the forgery's value, on any race or on the maker. A forger is **never
   named or implied** on a fragment, at MVP or later (answers lore bible OQ 5).
7. **Runtime IDs** (Runtime ID Service rule 2): one per seeded fragment, issued
   at new-game setup after placement, in ascending slot content ID. ID order is
   therefore authored slot order, never generation order. Empty slots get no ID.
8. **Generation order is never observable.** No view, list, event or system
   iterates fragments in `base:truth_case` order. Every iteration is by Runtime
   ID (slot order) or by acquisition sequence.

**B. Finding and holding**

9. **A find is a grant.** `grant(slot_id, source)` is called only inside a
   simulation step, by the slot's host:
   - `node`: Machine Nodes rule 17, on a win-class break (`source = node_win`),
     or on arrival at a BROKEN_UNCLAIMED node (`source = node_claim`; Sector Map
     rule 29);
   - `derelict`, `archive`: Points of Interest (#29), when its search completes;
   - `witness`: Ports, Rest & Care on first docking at the host port, after the
     rumours (Ports rule 27); or #29, for a witness hosted by a POI.
10. **What a grant does**, in one tick: the fragment goes HELD; it takes
    `acq_seq = next_acq_seq` and `acq_tick`; `FragmentHeld(fragment_id, acq_seq,
    tick, source)` is logged at record tier; the find card opens as a planning
    hold (no days pass). A grant on an empty slot shows "Nothing legible
    survived here" and changes no state. A grant on a slot already HELD is a
    no-op.
11. **The grant path is the same whatever the content.** A host's time, cost,
    notice and map marker for a search or claim must not vary with the slot's
    class, content or emptiness. Only the card that opens differs.
12. **Acquisition order is display order.** The locker, the Case File list, the
    share picker and the Debrief show held fragments by ascending `acq_seq`.
    Two grants in one tick take `acq_seq` in call order, which is the tick's
    deterministic handler order.
13. **The class is shown on find.** Every card shows its class from the first
    look (concept: "red herrings and testimony are marked as such"). The tell
    explains *why* a forgery is marked; it is not a hidden test.
14. **Chain labels.** A card shows its independence group as a chain label:
    "Chain A" for the first group the player holds, "Chain B" for the next new
    group, and so on (Formulas D3). The raw group ID is never shown. Two cards
    with one label are one source chain; the Case File counts it once.
15. **Read state.** A card is unread until opened. `read` is presentation only:
    no simulation system reads it.
16. **The total is public.** The locker header shows "Held h of N". `N` is fixed
    by knobs (Truth Seeding D2), so it carries no maker information.

**C. Presentation**

17. **The card.** In this order: source line (`source_kind` icon + `site_name`);
    class label; the claim text; the provenance block; the found line ("Found
    day d"). No numeric reliability appears anywhere.
18. **One template per axis per class.** The claim text is the template for
    (axis, class) with only the value slot filled. All 8 axes × 4 classes (32)
    must exist (`TEMPLATE_MISSING`, load error). Templates are written to
    Truth Seeding rule 13 and lore bible §1.1. Templates name **values only,
    never races**: the player maps a value to races through the Dossier's
    attribute table. Illustrative, writer owns the final wording:
    - DIRECT_PHYSICAL: "Recovered in place. The builders' script on it: {value}."
    - RECORD: "A machine log gives the builders' script as: {value}."
    - TESTIMONY: "An elder's account of the builders' script: {value}."
    - FORGERY: "A copy gives the builders' script as: {value}."
19. **The provenance block** has three lines: **Class** (fixed line per class),
    **Custody** (a stamp), **Chain** (rule 14).

    | Class | Class line | Custody stamp |
    |---|---|---|
    | DIRECT_PHYSICAL | "Relic. Can rule a candidate out." | "Sealed at recovery. Unbroken." |
    | RECORD | "Machine record. Can rule a candidate out." | "Log intact. Chain unbroken." |
    | TESTIMONY | "Testimony. Often right, never proof." | "Spoken, remembered, retold." |
    | FORGERY | "Marked forgery. Weight only; proves nothing." | the drawn tell (rule 20) |

    The stamp depends on class only (and, for a forgery, the drawn tell).
20. **Forgery tells** come from one shared set, used for every race (lore bible
    §7.1). MVP set of 4 (illustrative):
    - "The copy is dated before its source."
    - "Its mark of origin is newer than the work."
    - "The custody chain skips a keeper."
    - "Two keepers claim to have held it at once."
    Each tell must fit every race's forging medium in lore bible §7.1 (house
    seals, strand-books, spar-charts, ore cords); no tell names a seal, ledger,
    tally, knot or incision, so no tell implies which race forged the copy.

    Tells never use attribute vocabulary (no era names, scripts, numbering
    bases, metals), never a race's seal, house, script or name. The Dossier's
    codex page "How copies give themselves away" lists every tell, so the
    player can learn them.
21. **Testimony reads the same right or wrong.** A testimony card is a function
    of its axis, its value and its stamp only. Nothing in wording, tone, hedging
    or detail level depends on whether it matches the truth (lore bible §7.2).
22. **No art depicts a value.** Card art is chosen by `source_kind` and class
    only. No picture shows a script, motif, metal or any race's art (Truth
    Seeding, Visual/Audio; Hulls rule 14).

**D. Hand-offs**

23. **To the Case File.** On each grant, and on load, #28 provides
    `held_fragments()`: per fragment, in `acq_seq` order, `{fragment_id,
    acq_seq, acq_tick, axis, value_key, class, chain_label, source_kind}`. The
    Case File asks Truth Seeding for groups and contradictions over the held
    set. **#28 never computes `contra`, support or ruled-out state.**
24. **To the sharing preview (#49) and Faction Belief (#30).** The share card is
    the player's own card (rules 17–19): fragment ID, claim text, class label,
    custody, chain label. It carries no maker field and no contradiction field.
    #30 snapshots `held_fragments()` itself when a share is committed (good
    faith is judged on the held set at share time). Shared and suppressed state
    belong to #30; the card shows a "Shared with ⟨faction⟩" line read from #30.
    For the preview, #28 also provides `unfound_count_by_class()`, so it can
    state "k reliable fragments are still unfound; any may contradict this"
    (class counts are knobs, so this is maker-neutral). If a share would make a
    host port Hostile, the preview lists that port's unclaimed evidence site as
    lost. #49's preview and #30's commit read `held_fragments()` inside one
    planning hold, so no grant can land between them.
25. **To Exposure (#32).** `unfound_fragments()` returns every fragment in
    PLACED or RESERVED, in ascending Runtime ID. A RESERVED fragment counts as
    unfound until claimed (Machine Nodes rule 17). `is_unfound(id)` answers for
    one. #32 owns which fragment a rival targets and what a rival find does.
    When a targeted fragment goes HELD, `FragmentHeld` is #32's signal.
26. **To Faction Reputation and Audio (#52).** They read `FragmentHeld`.
    Whether a fragment "confirms" is decided by #30 through Truth Seeding, never
    here. Audio may vary a find cue by class and `source_kind` only.

**E. Save and determinism**

27. **Own section `base:archive_fragments`** (Save/Load section registry):
    per fragment `{fragment_id, slot content ID, state, acq_seq, acq_tick, read,
    tell_id, tell fallback text}`, plus `next_acq_seq` and the set of empty
    slots. Ceiling **64 KiB**. Claims, classes and groups stay in
    `base:truth_case` (Truth Seeding rule 14); this section never copies them.
28. **Placement is materialised.** After new game it is read from the save,
    never re-derived. A content update or mod change that adds, moves or
    retires slots does not move a placed fragment.
29. **`provenance_stamp` is a truth kind** (Content Data Core Rule 18): class
    lines, custody stamps and tells are never substituted mid-campaign. The
    fallback tell text is saved with the fragment.
30. **No surface path reveals placement content.** The save header, slot
    summary and bug-report bundle list neither which slot holds what class nor
    any unfound claim (Truth Seeding rule 12).

### States and Transitions

| State | Entered when | Leaves to |
|---|---|---|
| PLACED | placement at new game (rule 3) | HELD (grant), RESERVED (host node broken on a loss-class battle) |
| RESERVED | its node goes BROKEN_UNCLAIMED (Machine Nodes rule 17) | HELD (arrival claim) |
| HELD | grant (rule 10) | — (permanent; shared or suppressed flags belong to #30) |

Read is a flag on HELD, not a state. An empty slot has no fragment and no state.

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Truth Seeding & Candidates (#16) | #16 → #28 | Materialised fragments: class, axis, value, group, template; #28 never reads the maker |
| Runtime ID Service (#3) | #28 → #3 | Kind `fragment`, issued at setup in slot order (rule 7) |
| Content Data & Mod Loading (#4) | both | Kinds `fragment_slot` (not truth), `provenance_stamp` (truth); templates; rule 2 validation |
| Deterministic RNG & Seed Streams (#2) | #2 → #28 | Stream `base:truth.placement` |
| Save/Load & Migration (#5) | #28 → #5 | Section `base:archive_fragments`, 64 KiB |
| Machine Nodes & Strongholds (#23) | #23 → #28 | `grant` on win-class break or BROKEN_UNCLAIMED claim |
| Sector Map & Travel (#26) | #26 → #23 → #28 | Arrival claims a RESERVED fragment |
| Points of Interest (#29) | #29 → #28 | `grant` on derelict, archive and POI-witness search; same path whatever the content (rule 11) |
| Ports, Rest & Care | Ports → #28 | `grant` for a port-hosted witness on first docking |
| Case File & Deduction | #28 → Case File | `held_fragments()`; Case File gets `contra` from #16 |
| Faction Belief & Blame (#30) | both | Share card; `FragmentHeld`; #30 owns shared and suppressed state |
| Public History / sharing (#49) | #28 → #49 | Share card for the preview |
| Exposure & Rival Investigation (#32) | #28 → #32 | `unfound_fragments()`, `is_unfound()`, `FragmentHeld` |
| Faction Reputation & Standing | #28 → it | `FragmentHeld` (confirmation judged by #30) |
| Dossier | #28 → Dossier | Codex page of tells; the testimony line |
| Audio (#52) | #28 → #52 | Find cue by class and source kind |

## Formulas

### D1. Placement

Inputs: `F_doc` = the seeded DIRECT_PHYSICAL, RECORD and FORGERY fragments, in
materialised order, `n_d = R + H`; `F_acc` = TESTIMONY fragments, `n_a = T`;
`S_doc`, `S_acc` = document and account slots sorted by ascending content ID,
sizes `m_d ≥ n_d`, `m_a ≥ n_a`; `S_non ⊂ S_doc` = non-node document slots,
`|S_non| ≥ NONSTRONGHOLD_DOC_MIN`. All draws use `rand_int(lo, hi)` on
`base:truth.placement`.

1. **Choose document slots.** `k = NONSTRONGHOLD_DOC_MIN`. If `m_d > n_d`: pick
   `k` slots from `S_non` by repeated `rand_int(0, |pool| − 1)` without
   replacement, then `n_d − k` more from the rest of `S_doc` the same way.
   If `m_d = n_d`: every slot is chosen, no draws. Sort the chosen slots by
   content ID.
2. **Shuffle fragments.** Fisher–Yates on `F_doc`: for `i = n_d − 1` down to 1,
   `j = rand_int(0, i)`, swap `a[i]`, `a[j]`. Assign `a[0..]` to the chosen
   slots in order.
3. **Accounts.** Steps 1–2 on `F_acc` and `S_acc`, with `k = 0`.
4. **Tells.** For each forgery, in Runtime ID order after step 7 of the Core
   Rules is applied to the result, `tell = rand_int(0, |FORGERY_TELLS| − 1)`.

Draw count: `(m_d > n_d ? n_d : 0) + (n_d − 1) + (m_a > n_a ? n_a : 0) +
max(n_a − 1, 0) + H`. Every term is a knob or an authored count, so it is the
same for every maker. Because the shuffle is uniform, P(fragment f in slot s) =
1 ÷ n_d over chosen document slots, whatever f's claim (G6).

Range: `n_d` 2 – 27, `m_d` ≥ `n_d`; at MVP `n_d` = 5, `n_a` = 1.

### D2. Acquisition sequence

`acq_seq = next_acq_seq`; then `next_acq_seq += 1`. Starts at 1. Range 1 – `N`.

### D3. Chain label

Over held fragments in `acq_seq` order, a group's label is the letter at index
`g` = the number of distinct groups first held before it (0 → A, 1 → B, …,
25 → Z, 26 → AA). With `N ≤ FRAGMENT_CAP` (24 max), labels stay in A – X.

### D4. Section size

Per fragment: ID 8 B + slot content ID ≤ 128 B + state 1 B + `acq_seq` 2 B +
`acq_tick` 8 B + read 1 B + `tell_id` ≤ 64 B + tell fallback ≤ 512 B ≈ 724 B.
At `N` = 24 and 24 surplus slot IDs (128 B each): 24 × 724 + 24 × 128 ≈ 20.4 KB,
under the 64 KiB ceiling.

### Worked example (MVP, C = 3, truth = Orrowen)

The case is Truth Seeding's worked example: f1 DIRECT script = knotted (g1);
f2 RECORD solvent = saline (g2); f3 DIRECT numbering base = base eight (g3);
f4 RECORD era = Late Tide (g4); f5 TESTIMONY doctrine = hereditary (g5);
f6 FORGERY material = cobalt (g6). `n_d` = 5, `n_a` = 1.

Authored slots, by content ID: A1 archive, D1 derelict, N1, N2, N3 (nodes); W1
witness at a port. `m_d` = 5 = `n_d`, so no slot draws; `|S_non|` = 2 ≥ 1.

Shuffle `[f1, f2, f3, f4, f6]` with draws 2, 0, 2, 1:
- i = 4, j = 2 → `[f1, f2, f6, f4, f3]`;
- i = 3, j = 0 → `[f4, f2, f6, f1, f3]`;
- i = 2, j = 2 → unchanged; i = 1, j = 1 → unchanged.

So A1 ← f4, D1 ← f2, N1 ← f6, N2 ← f1, N3 ← f3. W1 ← f5 (no draws). Tell for f6:
draw 0 → "The copy is dated before its source." Draws used: 0 + 4 + 0 + 0 + 1 = 5,
matching D1. Runtime IDs go in slot order: A1's f4, D1's f2, N1's f6, N2's f1,
N3's f3, W1's f5.

Play: day 3 the player searches D1 → f2, `acq_seq` 1, Chain A. Day 4 first
docking at W1's port → f5, `acq_seq` 2, Chain B. Day 6 N2 breaks but the
battle is lost → f1 RESERVED, still in `unfound_fragments()`. Day 8 arrival
claims f1 → `acq_seq` 3, Chain C. The locker reads f2, f5, f1, "Held 3 of 6".
The Case File (via #16) gets contra(Ithren) = 2 (g1, g2): Ithren is ruled out.
Halsk has contra 1 (g1). No fragment's slot or ID order said anything about
the maker; the first find was a RECORD only because D1 drew it.

## Edge Cases

- **If a grant names an empty slot**: "Nothing legible survived here"; no ID, no
  `FragmentHeld`, no `acq_seq` used.
- **If a grant names a HELD fragment's slot**: no-op, logged at debug tier.
- **If two grants land in one tick** (e.g. arrival claims a node and docks at a
  witness port): `acq_seq` follows handler order (rule 12); deterministic.
- **If a node with a slot is broken on a win-class battle**: grant at once,
  PLACED → HELD; it never enters RESERVED.
- **If a rival targets a RESERVED fragment**: allowed; it is unfound (rule 25).
- **If the content has too few slots at new game**: content load fails with
  `FRAGMENT_SLOTS_SHORT`; no campaign can start on it.
- **If a mod that supplied a slot or its host is removed mid-campaign**: the
  fragment stays PLACED with its saved slot ID, unreachable; the pre-load
  summary flags "affects your case" (Content Data Core Rule 18); it is reachable
  again if the mod returns.
- **If an update retires a slot**: placement is materialised (rule 28); the
  fragment keeps its slot, rebound through `retired_ids` like any non-truth ID.
- **If Truth Seeding used its fallback build**: placement is identical (D1
  reads class counts only).
- **If a forgery names the true maker**: its card is identical to any other
  forgery's, value apart.
- **If testimony is wrong**: its card is identical to a right one, value apart.
- **If the locale changes**: templates, class lines and tells re-render from the
  current string table under the saved keys; missing strings use the saved
  source-language fallback.
- **If every fragment is HELD**: `unfound_fragments()` is empty; slots are inert.
- **Degenerate: reloading to re-roll placement.** Placement is fixed by the seed
  and materialised; a reload changes nothing.
- **Degenerate: inferring classes by counting.** Class counts are public knobs
  and carry no maker information; allowed.
- **Degenerate: not looking, to stay deniable.** Not a #28 defence: rivals find
  fragments anyway (#32) and good faith is judged on the held set (#30).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Runtime ID Service (#3) | Hard | Fragment IDs |
| Content Data & Mod Loading (#4) | Hard | Slot and stamp kinds; templates; Core Rule 18 |
| Truth Seeding & Candidates (#16) | Hard | The case |
| Deterministic RNG & Seed Streams (#2) | Hard | Placement stream |
| Save/Load & Migration (#5) | Hard | Own section |
| Machine Nodes (#23), Sector Map (#26), Ports, Points of Interest (#29) | Soft (callers) | `grant` |
| Case File, Faction Belief (#30), Public History (#49), Exposure (#32), Faction Reputation, Dossier, Audio (#52) | Hard (reverse) | Read held and unfound fragments |

Bidirectional check: #16, #23 and #26 already name #28; #2, #3, #5 and Ports
need the amendments in the report. #29, #30, #31, #32 and #52 list #28 in the
systems index.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `NONSTRONGHOLD_DOC_MIN` | 1 | 0 – 3 | Gate | Evidence before the first return |
| `FORGERY_TELLS` (set size) | 4 | 3 – 12 | Curve | Variety of learnable tells |
| `TEMPLATE_VARIANTS` | 1 | 1 (MVP only) | — | Reserved; >1 needs a G6-safe variant rule |
| `FIND_CARD_AUTO_OPEN` | true | bool | Feel | Card opens on find as a planning hold |
| Section ceiling | 64 KiB | 32 – 256 KiB | — | Save budget (D4) |
| MVP slots (authored) | 3 node, 1 derelict, 1 archive, 1 witness | doc ≥ R + H; acc ≥ T | Gate | Placement pool |

In `assets/data/truth/fragments/`. `R`, `T`, `H` and `FRAGMENT_CAP` stay
Truth Seeding's knobs.

## Visual/Audio Requirements

- Card art by `source_kind` and class only; never a value, never race art
  (rule 22).
- Map marker on a revealed site with an unclaimed slot ("evidence here"), the
  same for every class; witness sites use the witness icon.
- Find cue by class and source kind only; identical for right and wrong
  testimony, and for every forgery.

## Game Feel

- **The find is a small reward beat**: the card opens at once, the clock holds.
- **Learnable tells**: the second time a tell appears, the player recognises it.
- **No tell-by-timing**: a search takes the same time whether it yields a relic,
  a forgery or nothing.

## UI Requirements

- Evidence locker: cards in `acq_seq` order, "Held h of N", unread badge.
- Card layout per rule 17; "Shared with" line from #30.
- Dossier codex page listing every tell and the testimony line.
- No numeric reliability, no raw IDs, no group IDs anywhere.
- 📌 **UX Flag — Archive Fragments & Evidence**: locker, card and find overlay
  belong in the UX spec.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Classes, groups, G6, rule 13, materialisation | `design/gdd/truth-seeding-and-candidates.md` | Rules 7, 8, 9, 13, 14, 15; D2 | Rule dependency |
| Neutrality, tells, testimony | `design/narrative/lore-bible.md` | §1.1, §5.2, §7 | Rule dependency |
| Slot, grant, BROKEN_UNCLAIMED | `design/gdd/machine-nodes-and-strongholds.md` | Rules 1, 1a, 17 | Rule dependency |
| Reveal, arrival claim | `design/gdd/sector-map-and-travel.md` | Rules 23, 25, 29 | Rule dependency |
| First docking | `design/gdd/ports-rest-and-care.md` | Rule 27 | Rule dependency |
| Truth kinds | `design/gdd/content-data-and-mod-loading.md` | Core Rule 18 | Rule dependency |
| Section ceiling | `design/gdd/save-load-and-migration.md` | D1 table | Data dependency |
| ID issue order | `design/gdd/runtime-id-service.md` | Rules 2, 3, 8 | Rule dependency |
| Sources, marked classes, preview | `design/gdd/game-concept.md` | Core fantasy; MVP | Source |

## Acceptance Criteria

- **AC-01 (Logic; rules 3, 28)**: the same seed and content give a byte-identical `base:archive_fragments` section.
- **AC-02 (Logic; rule 4, D1)**: with the claim values of every fragment altered and the maker changed, a fixed seed gives the same slot for every fragment index of each class and the same tell draws.
- **AC-03 (Logic; D1)**: the draw count on `base:truth.placement` equals D1's formula for every seed, and is identical across makers.
- **AC-04 (Logic; rule 4, G6)**: over 30,000 seeds per maker, for every slot, the distribution of class, axis and contradiction strength of its fragment matches across makers within ± 1.5 %.
- **AC-05 (Logic; rule 5)**: in every seed at least `NONSTRONGHOLD_DOC_MIN` document fragments sit in non-node slots.
- **AC-06 (Logic; rule 2)**: fixtures with too few slots, a kind mismatch, an unknown or shared host, or no non-node document slot each fail load with the named error.
- **AC-07 (Logic; rule 7)**: fragment Runtime IDs ascend in slot content-ID order; empty slots have none.
- **AC-08 (Logic; rules 8, 12)**: the locker, Case File list, share picker and Debrief list held fragments in `acq_seq` order; a fixture whose generation order is the reverse of acquisition order shows acquisition order everywhere.
- **AC-09 (Logic; rule 10)**: a grant sets HELD, `acq_seq`, `acq_tick` and logs one `FragmentHeld`; a repeated grant and an empty-slot grant change no state.
- **AC-10 (Logic; rule 17 of #23)**: a loss-class break sets RESERVED; the fragment is in `unfound_fragments()` until the arrival claim, then HELD with no battle.
- **AC-11 (Logic; D3)**: chain labels follow first-held group order; two held fragments of one group share a label.
- **AC-12 (Logic; rule 23)**: `held_fragments()` exposes no `contra`, support, ruled-out or maker field (schema check).
- **AC-13 (Logic; rule 24)**: the share card carries no maker or contradiction field and equals the player's card text.
- **AC-14 (Logic; rule 25)**: `unfound_fragments()` returns exactly PLACED and RESERVED fragments in ascending Runtime ID.
- **AC-15 (Logic; G6 on presentation)**: over 30,000 seeds, every held card is rendered in English; with the value slot masked, a classifier on the rendered text, its length, the stamp, chain label, `source_kind`, site, art key, audio cue and `acq_seq` predicts the maker no better than 1 ÷ C + 2 %.
- **AC-16 (Logic; rule 21)**: for every testimony axis, a true and a false testimony card are byte-identical once the value is masked.
- **AC-17 (Logic; rules 6, 20)**: for every forgery, the card is byte-identical across makers and across which race its value names, value masked; the tell distribution matches across makers within ± 1.5 %.
- **AC-18 (Logic; rule 18)**: removing any of the 32 (axis, class) templates fails load with `TEMPLATE_MISSING`.
- **AC-19 (Logic; rule 11)**: a POI search and a node claim take the same ticks and cost, and show the same notice, for a relic, a forgery, testimony and an empty slot.
- **AC-20 (Logic; rule 30)**: no slot class, unfound claim or placement appears in the save header, slot summary or bug-report bundle (text search).
- **AC-21 (Logic; rule 28)**: after load, adding, removing or moving a slot in content leaves every placed fragment's slot unchanged.
- **AC-22 (Logic; D4)**: at `N` = 24 with longest strings, the section is ≤ 64 KiB.
- **AC-23 (Logic; rule 15)**: toggling `read` on every card leaves every simulation hash unchanged.
- **AC-24 (Review; rules 18–20)**: a writing review confirms templates name values only, never races; wording per (axis, class) is fixed with only the value slot changing; tells use no attribute vocabulary and no race seal or name; the lore bible §1.1 checklist passes.
- **AC-25 (Playtest; rules 13, 18)**: in a 5-player playtest, at least 4 of 5 map a held reliable fragment to the candidate it contradicts before opening the Case File, and none reports that wording, order or location "gave away" the maker.
- **AC-27 (Review; rule 20, lore bible §7.1)**: no tell names or implies a race's forging medium (seal, ledger, tally, knot, incision).
- **AC-28 (Logic; rule 24)**: the share preview states the unfound reliable count from `unfound_count_by_class()`, lists evidence sites lost to a share's new hostility, and a grant attempted between preview and commit is deferred until the hold ends.
- **AC-26 (Playtest; rule 5)**: every tester holds at least one fragment before the first stronghold return.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **MVP slots**: 3 node slots (one on each MVP stronghold, the opening one
  included), 1 derelict, 1 archive and 1 witness, matching N = 6 with no
  surplus.
- **Class shown on find** (the concept calls forgeries "marked").
- **"Held h of N"** is shown.
- **Witness hosts** are ports at MVP (granted on first docking, after the
  rumours); POIs may host witnesses later (#29).
- **Forgers are never named** on a fragment (lore bible OQ 5).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Does a rival find remove the fragment, or can the player still claim it? Recommendation: still claimable (the rival copies, does not take). | #32 owner | #32 design |
| 2 | The true maker's agents (#32) target unfound fragments: their visible choice must be maker-blind, or it leaks G6. | #32 owner | #32 design |
| 3 | Suppression of a HELD fragment ("destroying or sealing"): does it leave the locker? #28 assumes it stays HELD with a #30 flag. | #30 owner | #30 design |
| 4 | Final template, class-line and tell text, and the codex page. | writer, narrative-director | Before content lock |
| 5 | Grammar-neutral value slots and per-language length matching (Truth Seeding OQ 5; lore bible OQ 7). | localization-lead | Before localisation |
