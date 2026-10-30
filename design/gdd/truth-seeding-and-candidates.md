# Truth Seeding & Candidates

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on the G6 surface-leak contradiction, testimony's false branch, the anchor example, and the pillar header; all revised; Open Question 4 resolved with a concept edit
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — one fixed hidden truth per save, seeded so it cannot be looked up, provable only from evidence); Pillar 4 (Plan in the Open — the attribute table is public)

## Summary

Truth Seeding & Candidates picks, once per campaign, which candidate race
secretly built the Instrument, and generates the finite set of evidence
fragments that can prove it, from a public attribute table and claim templates.
Every case is guaranteed fair: no fragment decides alone, every false candidate
can be ruled out by two independent reliable fragments, red herrings and
testimony cannot be read backwards, and nothing in a fragment's surface leaks
the answer. The case is written into the save and never changes (Pillar 2).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Deterministic RNG & Seed Streams, Content Data & Mod Loading, Save/Load & Migration`

## Overview

Truth Seeding & Candidates decides, at new game, which candidate race secretly
built the Instrument, and seeds the **finite set of evidence fragments** that
lets the player prove it. It runs once per campaign, from the campaign's seed
streams, and writes the whole case into the save, materialised (Content Data &
Mod Loading, Core Rule 18). From then on the case never changes: no difficulty,
mod, update or free play can alter it.

The case is built from three content kinds, so a solo developer never authors a
mystery per seed (concept, production bounds):
- **candidate races**, each with a row in a shared **attribute table** (solvent,
  script, numbering base, motif, region, era, doctrine, material);
- **claim templates**, one per axis: "the maker's ⟨axis⟩ is ⟨value⟩";
- **provenance classes**, which decide what a claim can prove.

The system's job is a **guarantee**: every case is fair and solvable. No single
fragment decides it; the truth is provable only by combining reliable
fragments; every false candidate can be ruled out by at least two independent
reliable fragments; at least one red herring exists and can never make the case
unsolvable; and nothing in a fragment's surface (its order, wording, or
provenance) leaks the answer.

It does **not** own where fragments are found (Archive Fragments & Evidence
#28), how the Case File presents reasoning, what factions believe (Faction
Belief & Blame), or sharing and exposure (#32).

## Player Fantasy

**A case built for my save, and it plays fair.** The player never sees this
system. They feel what it guarantees: the mystery is theirs, seeded once and
fixed, solvable by elimination like a detective's case, with no trick ending.
Its texture is *the archive does not lie, but people do*: stamped relics and
machine logs can be trusted; testimony and forgeries are marked, and the player
learns to weigh them.

*Anchor moment:* the player holds a relic inscribed in incised script and, from
a different archive, a machine log in the same script. Neither names anyone; two
races share that script. Together, two independent sources, they rule the third
race out. The Case File says so, and only so.

**Pillars served:**
- **Pillar 2, *The Truth Is Yours to Tell*:** one fixed hidden truth per save,
  provable only from evidence (rules 1–13).
- **Pillar 4, *Plan in the Open*:** the attribute table is public; players
  deduce from fragments, not hidden lore (rule 4).

**This system must never make the player feel:** "the answer was decided by a
hidden rule", "one fragment gave it away", or "the evidence was rigged".

## Detailed Design

### Core Rules

**A. Candidates**

1. **Each save has `C` candidates** (`C_MAX` = 3 at MVP, 4 from Tier 1): at MVP
   the two playable organic races and one text-only race. **The Instrument is
   never a candidate** (the question is which organic race built it), and there
   is no "no race" outcome.
2. **Every candidate can be the maker**, with weight `maker_weight` (default 1,
   so 1/3 each at MVP, stated to players). No race is special-cased, including
   the race that lends the player ships.
3. **Mod races** join the candidate pool at new game only if they pass the table
   rule (rule 5). If more than `C_MAX` are eligible, the set is drawn on
   `base:truth.candidates`; the two playable races always stay in, and the
   rest of the set is drawn from every other eligible race, base or mod. The
   table rule (rule 5) is checked on **every candidate set that can be
   drawn**, not on the whole pool (with 8 axes, rule 5 cannot hold across five
   or more races at once). Mods may add axes. A mod never joins an existing
   campaign's case (Content Data Core Rule 18).

**B. The attribute table and claims**

4. **The attribute table is public.** Each candidate has one value on each of
   the MVP's 8 axes (solvent, script, numbering base, building motif, star
   region, founding era, command doctrine, material signature). The Dossier
   shows the table from the start (Pillar 4). Values are written truth-neutrally
   (rule 13).
5. **The table rule** (checked at content load): for every pair of candidates,
   at least 2 axes exist on which that pair shares a value and every other
   candidate differs; and at least 2 axes exist on which all candidates differ.
   **Strength symmetry:** in every drawable candidate set, each candidate has
   the same count of axes at each contradiction strength (how many false
   candidates a true claim on that axis contradicts when that candidate is the
   maker). The base table has it (lore bible §5: at C = 3, four axes of
   strength 1 and four of strength 2 for every maker; at C = 4, six of strength
   2 and two of strength 3). Without it, G2's rejection rate and the strength
   mix of accepted cases would point to the maker.
   A base table that breaks it is a content error; a mod race that breaks it is
   left out of the pool with a warning.
6. **A claim** is "the maker's ⟨axis⟩ is ⟨value⟩". It **contradicts** every
   candidate whose value on that axis differs.
7. **Provenance classes** decide what a claim can prove:

   | Class | Can rule a candidate out? | Truth relation |
   |---|---|---|
   | DIRECT_PHYSICAL (relic) | yes | always consistent with the truth |
   | RECORD (machine log) | yes | always consistent with the truth |
   | TESTIMONY (eyewitness) | **never**; weight only | consistent with the truth with probability `TESTIMONY_TRUE_PM` (700 ‰); otherwise its value is drawn uniformly from the non-maker candidates' values on an all-different axis. The Dossier describes testimony as "often right, never proof", not with the figure |
   | FORGERY (red herring) | **never**; weight only | its value is drawn **without regard to the truth** (uniform over the candidates' values on an all-different axis), so it may name the true maker |

   A FORGERY's tell is its provenance (a wrong seal, an anachronism in the chain
   of custody), never its content. Because forgeries and testimony are not tied
   to the truth either way, **neither can be read backwards**: a forgery that
   names a race says nothing about whether that race is innocent (narrative
   risk). Every fragment is consistent with the truth except fragments of these
   two marked classes (concept).
8. **Independence groups.** Each fragment belongs to a group (a source chain); a
   chain counts once. `contra(c)` is the number of distinct groups holding a
   reliable (DIRECT_PHYSICAL or RECORD) fragment that contradicts `c`. A
   candidate is **ruled out when `contra(c) ≥ 2`** (concept: "at least two
   reliable, independent contradictions"). The Case File uses these meanings; it
   does not own them.

**C. Generation**

9. **Guarantees** checked on every case (Formulas D3):
   - **G1** every reliable fragment is consistent with the truth;
   - **G2 no fragment decides alone**: a reliable fragment contradicts at least
     1 false candidate and never the truth, and **no two reliable fragments
     from different groups together rule out every false candidate**, so at
     least three must be combined. (One fragment can never rule anything out,
     because ruling out needs two groups; rule 8.) The earlier form, "contradicts
     at most `C − 2`", was dropped: at `C` = 3 it allowed only axes where the
     maker shares a value with one other candidate, so *which axes appear*
     would have pointed to the maker (a G6 leak);
   - **G3** each false candidate is contradicted by reliable fragments from at
     least 2 different groups;
   - **G4** at least `H` (1) FORGERY fragments exist (rule 7);
   - **G5** `T` (1) TESTIMONY fragments exist (rule 7);
   - **G6 no surface leak**: no feature of a fragment *other than its claim
     content* (display order, template wording, string length, provenance
     stamp, group ID, package, location) carries information about the maker.
     Display order is acquisition order (set by #28), never generation order.
     Reliable claims naturally favour the maker's values; that skew is the
     solution, not a leak. Testimony and forgery values are never chosen to
     balance mentions (rule 7).
10. **Generate, check, retry.** The case is generated on `base:truth.fragments`,
    checked against G1–G6, and regenerated up to `MAX_ATTEMPTS` (32) times on the
    same stream (deterministic). **Each reliable fragment's axis is drawn
    uniformly over every axis of the table**, whatever the maker: every axis
    yields a true claim that contradicts at least one false candidate, so axis
    frequency carries nothing about the maker (G6). If none passes, a **fixed fallback build** is
    used: one fixed template case, mapped onto the actual maker through the
    table's symmetry (rule 5, strength symmetry), so its axes and strengths are
    the same for every maker; no draws. A fallback is logged, never shown, and
    its rate is asserted near zero (AC-04).
11. **Seeding** happens once, at new game, in the campaign step, on three
    separate streams so a template change never changes the maker:
    `base:truth.candidates`, `base:truth.maker` and `base:truth.fragments`
    (Deterministic RNG & Seed Streams naming rules). Difficulty has no effect
    (Gameplay Settings & Modifiers rule 9).
12. **"Cannot be looked up", honestly.** The case is stored in plain form in the
    save: encrypting only the maker would be theatre, since the filled claims
    identify the maker by deduction anyway. The guarantee is that **no in-game or
    shareable path reveals it**: not the save header, not the slot summary, not a
    bug-report bundle. Reading one's own save file is out of scope.
13. **Truth-neutral writing** (binding on #28's templates and the writer): every
    race has a motive, a means and an innocent gap in the shared backstory, true
    in every seed; templates have identical wording per race with only the value
    slot changing; slot values per axis are matched in length and register; no
    villain-coded words are tied to one race; attribution verbs are spread
    evenly. Narration never says "the makers did"; it uses the slot.

**D. Materialisation**

14. **The save holds the case** in section `base:truth_case` (Save/Load &
    Migration): the maker; each candidate's attribute row, display key and a
    fallback name; and each fragment's template, axis, value, class, group,
    package and content ID, and fallback text in the source language; plus the
    attribute-table version. Worst case (C = 4, N = `FRAGMENT_CAP`, longest
    strings) is about 50 KiB; the declared ceiling stays **1 MiB** (headroom for
    mod candidates and fallback text; Save/Load D1 unchanged).
15. **Free play adds no fragments.** The case is read-only after seeding. Found,
    shared and suppressed state belong to #28, Faction Belief & Blame and #32;
    this system exposes per fragment its class, group, contradictions and a
    reliable-contradiction flag for the ending checks (truth confirmed, lie
    exposed, lie that stands).

### States and Transitions

| State | Entered when | Leaves to |
|---|---|---|
| Unseeded | new-game setup | Seeding |
| Seeding | campaign created | Seeded (a case passes G1–G6, or the fallback) |
| Seeded | case written to the save; or loaded | — (read-only for the campaign) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Deterministic RNG & Seed Streams (#2) | #2 → #16 | Three campaign streams (rule 11) |
| Content Data & Mod Loading (#4) | both | Truth kinds (candidates, attribute table, claim templates, provenance classes); table rule at load; Core Rule 18 |
| Save/Load & Migration (#5) | #16 → #5 | `base:truth_case` section |
| Archive Fragments & Evidence (#28) | #16 → #28 | The fragment list. **Split:** #16 owns what a claim means and how the case is generated (schema, class reliability, generation, solvability); #28 owns template text, the provenance stamp, placement and how a discovery is shown |
| Case File | #16 → Case File | `contra` and `support` meanings (rule 8) |
| Faction Belief & Blame; Exposure & Rival Investigation (#32) | #16 → them | Per-fragment class, group and contradiction flags |
| Dossier | #16 → Dossier | Public attribute table |
| Gameplay Settings & Modifiers (#7) | — | No effect (rule 11) |

## Formulas

### D1. The maker

`maker = weighted_pick(candidates, maker_weight)`; P(c) = `w_c ÷ Σ w`. At MVP,
1/3 each.

### D2. Fragment count

`R_min` = **3** reliable fragments at both C = 3 and C = 4: G2 forbids any two
from solving the case, and three can (worked example).
`R = R_min + R_SLACK`; `N = R + T + H`, capped at `FRAGMENT_CAP`.
These per-class counts (`R`, `T`, `H`) are knobs, identical for every maker for a
given content set (Faction Belief & Blame rule 16 relies on this).
**MVP:** R = 3 + 1 = 4; N = 4 + 1 + 1 = **6** (the worked example). A slack
fragment's axis is drawn **uniformly**, like every reliable fragment (rule 10),
never aimed at the false candidate with the fewest contradictions (that would
make its axis depend on the maker); it may repeat an axis only from a new group,
and G3 retries handle coverage.

### D3. Solvability check

A case is valid when G1–G6 hold, `contra(truth)` = 0 over the reliable set, and
`contra(c) ≥ 2` for every false candidate. Then, once every fragment is held,
exactly the truth survives, whatever the order of discovery; and no single
reliable fragment rules anything out.

### Worked example (C = 3, truth = Orrowen)

Candidates Halsk, Orrowen and Ithren; values from the lore bible
(`design/narrative/lore-bible.md` §5).

| Axis | Halsk | Orrowen | Ithren | A true claim contradicts |
|---|---|---|---|---|
| solvent | saline | saline | ammonia | Ithren |
| script | incised | knotted | incised | Halsk, Ithren |
| numbering base | base twelve | base eight | base eight | Halsk |
| building motif | spiralled | spiralled | branching | Ithren |
| star region | rimward | coreward | rimward | Halsk, Ithren |
| founding era | Early Tide | Late Tide | Late Tide | Halsk |
| command doctrine | consensus | hereditary | rotational | Halsk, Ithren |
| material signature | cobalt | copper | barium | Halsk, Ithren |

Every axis yields a usable true claim, so axes are drawn uniformly (rule 10).

Fragments: f1 script = knotted (DIRECT, g1, contradicts Halsk and Ithren); f2
solvent = saline (RECORD, g2, contradicts Ithren); f3 numbering base = base eight
(DIRECT, g3, contradicts Halsk); f4 era = Late Tide (RECORD, g4, slack,
contradicts Halsk); f5 TESTIMONY doctrine (weight only); f6 FORGERY material
(value drawn uniformly, weight only).
**Check:** contra(Halsk) = 3 (g1, g3, g4), contra(Ithren) = 2 (g1, g2),
contra(Orrowen) = 0. **G2:** f1 + f2 rules out Ithren only; f1 + f3 Halsk only;
f1 + f4 Halsk only; f2 + f3, f2 + f4 and f3 + f4 rule out at most one. No two
fragments solve the case; f1, f2 and f3 together do.

## Edge Cases

- **If mod races make more than `C_MAX` candidates eligible**: the set is drawn
  on `base:truth.candidates`; base races always stay (rule 3).
- **If a mod that supplied a candidate is removed mid-campaign**: the case loads
  unchanged with its fallback names and text, and the pre-load summary warns
  (Content Data Core Rule 13); placement is #28's.
- **If no valid case is found in `MAX_ATTEMPTS`**: the fallback build (rule 10).
- **If two saves share a master seed and identical content**: they share a case;
  accepted at 2⁶⁴ seeds.
- **If the attribute table is changed by an update**: existing campaigns keep
  their materialised case and table version; new games use the new table.
- **If a forgery happens to name the true maker**: allowed (rule 7); it still
  never counts as a contradiction or confirmation.
- **If the player holds only testimony and forgeries**: nothing is ruled out.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Deterministic RNG & Seed Streams (#2) | Hard | Streams |
| Content Data & Mod Loading (#4) | Hard | Truth kinds, Core Rule 18 |
| Save/Load & Migration (#5) | Hard | Case section |
| #28, Case File, Faction Belief & Blame, #32, Dossier | Hard (reverse) | Read the case |

Bidirectional check: Content Data (Core Rule 18) and Settings (rule 9) already
name Truth Seeding; the systems index lists #16 under #28's dependencies.

## Tuning Knobs

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `C_MAX` | 3 (Tier 1: 4) | 3 – 4 | Candidates per save |
| `maker_weight` | 1 | 1 – 10 | Maker odds (keep equal; rule 2) |
| `R_SLACK` | 1 | 0 – 3 | Spare reliable fragments |
| `T` | 1 | 0 – 4 | Testimony fragments |
| `TESTIMONY_TRUE_PM` | 700 | 500 – 900 | How much testimony can be trusted |
| `H` | 1 | 1 – 3 | Red herrings |
| `FRAGMENT_CAP` | 16 | 8 – 24 | Case size |
| `MAX_ATTEMPTS` | 32 | 8 – 128 | Generation retries |

In `assets/data/truth/`.

## Visual/Audio Requirements

None of its own. #28 presents fragments; the Dossier shows the attribute table.
Race-specific art never appears on fragment visuals or machine assets (Hulls
rule 14).

## Game Feel

- **Deduction, not luck**: no fragment decides; combining them does.

## UI Requirements

- The Dossier shows the public attribute table.
- The Case File (its own GDD) uses `contra` and `support`.
- 📌 **UX Flag — Truth Seeding & Candidates**: the attribute table view belongs
  in the Dossier UX spec.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Seeded case in the save; truth kinds | `design/gdd/content-data-and-mod-loading.md` | Core Rules 13, 17, 18 | Rule dependency |
| Stream naming, `weighted_pick` | `design/gdd/deterministic-rng-and-seed-streams.md` | Core Rules 4, 6; D-formulas | Rule dependency |
| Case section ceiling | `design/gdd/save-load-and-migration.md` | D1 (1 MiB, unchanged) | Data dependency |
| Difficulty never touches the truth | `design/gdd/gameplay-settings-and-modifiers.md` | Rule 9 | Rule dependency |
| No lineage on machine art | `design/gdd/hulls-and-ship-definition.md` | Rules 6, 14 | Rule dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 11)**: the same seed and content give a byte-identical case.
- **AC-02 (Logic; rule 2, D1)**: over 30,000 seeds each MVP candidate is the maker in 33 % ± 1.5 %.
- **AC-03 (Logic; D3; fuzz)**: over 1,000,000 seeds, at C = 3 and C = 4, with base content and a fixture mod race, every case passes D3.
- **AC-04 (Logic; rule 10)**: on the same run the fallback rate is ≤ 0.1 %, and every fallback case passes D3.
- **AC-05 (Logic; G2)**: in every case no single reliable fragment rules a candidate out, every reliable fragment contradicts at least one false candidate and never the truth, and no two reliable fragments from different groups together rule out every false candidate.
- **AC-05b (Logic; rule 10, G6)**: over 30,000 seeds at C = 3 and C = 4, the axis distribution of reliable fragments is the same for every maker (each axis within 1 ÷ 8 ± 1 %).
- **AC-05c (Logic; rule 5 strength symmetry, G6)**: over 10,000 seeds per maker, the distribution of contradiction strengths among accepted reliable fragments, and the G2 rejection rate, match across makers within ± 1 %; a fixture mod race that breaks strength symmetry is excluded at load.
- **AC-09b (Logic; rule 3)**: with four base races and one fixture mod race, every drawable candidate set passes the table rule; a mod race that fails for some drawable set is excluded with a warning.
- **AC-06 (Logic; G3)**: every false candidate has `contra ≥ 2` from different groups; the truth has `contra` = 0.
- **AC-07 (Logic; rule 7)**: over 30,000 seeds, the candidate a FORGERY's value points to is the maker in 1 ÷ C ± 1.5 % of cases, and testimony matches the truth in 700 ‰ ± 15 ‰, with its false values spread uniformly over the non-maker candidates (neither can be read backwards).
- **AC-08 (Logic; G6)**: over 30,000 seeds, a classifier given only non-content features (display order, template wording, string length, provenance stamp, group ID, package, location) predicts the maker no better than chance (≤ 1 ÷ C + 2 %); and with claim values hidden, which axes appear predicts the maker no better than chance by the same threshold.
- **AC-09 (Logic; rule 5)**: a base table that breaks the table rule fails at load with a named reason; a mod race that breaks it is excluded with a warning.
- **AC-10 (Logic; rule 11)**: changing claim-template content leaves the maker unchanged for a fixed seed.
- **AC-11 (Logic; rule 11)**: every difficulty preset gives an identical case.
- **AC-12 (Logic; rule 14)**: after load, adding or removing a mod leaves the case section byte-identical.
- **AC-13 (Logic; rule 15)**: no fragment is created after Seeded, free play included.
- **AC-14 (Logic; rule 14)**: the worst case (C = 4, N = `FRAGMENT_CAP`, longest strings) is ≤ 64 KiB, well within the 1 MiB ceiling.
- **AC-15 (Logic; rule 12)**: the maker does not appear in the save header, the slot summary or a bug-report bundle (text search).
- **AC-16 (Review; rule 13)**: a writing review confirms every claim template is identical per race except the value slot, values per axis are length-matched within 20 %, and no villain-coded word is tied to one race.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | ~~**A truth-neutral lore bible**~~ **Drafted 2026-10-30:** `design/narrative/lore-bible.md` (pending review and the clean-room check). Original text: **A truth-neutral lore bible** (shared backstory; each race's motive, means and innocent gap; the attribute table values) is needed before #28 and the writer start. | narrative-director, writer, world-builder; scope by producer | Before #28 is designed |
| 2 | **Race names and attribute values** are placeholders. | narrative-director | Lore bible |
| 3 | **`TESTIMONY_TRUE_PM`** value: testimony must feel worth weighing without being proof. | game-designer | Mystery playtest |
| 4 | ~~**Testimony and the concept's wording**~~ **Resolved 2026-10-30**: creative-director approved the intent; the concept's Unique Hook now reads "except the marked red herrings and testimony" (concept edit, owner's standing instruction). | creative-director | Resolved |
| 5 | **Localisation**: grammar-neutral value slots so gender or case agreement cannot leak (G6). | localization-lead | Before localisation |
