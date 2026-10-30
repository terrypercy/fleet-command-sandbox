# Faction Reputation & Standing

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on the preview leaking the truth (hostility now keyed on accusation), care for machine ships, hidden hysteresis, and pillar-list mismatch; all four revised
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — the truth costs standing now; a lie costs standing to keep up); Pillar 4 (Plan in the Open — every change is logged with its cause); Pillar 1 (Every Defeat Is a Lead — standing earns care and allies for a return attempt); Pillar 5 (care is the living races' side)

## Summary

Faction Reputation & Standing is a plain ledger: one integer per faction toward
the player, five bands (Hostile, Wary, Neutral, Trusted, Allied) that decide
docking, care and lending eligibility, and a log in which every change carries
its cause. Belief and blame write it; care and suppression spend it; naming the
true maker sets that race Hostile and locks it. It is the currency of the
truth's cost and a lie's upkeep (Pillars 2, 4, 1 and 5).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Content Data & Mod Loading, Save/Load & Migration`

## Overview

Faction Reputation & Standing is a plain **ledger**: one integer per faction
saying how that faction regards the player, five bands that turn the number into
what the faction will do (dock, trade, care, lend), and an append-only log in
which every change carries its cause. It never decides anything itself: belief
and blame (Faction Belief & Blame) write most of it, other systems spend it, and
it records and enforces the bands.

Standing is the currency of the game's central bargain (concept): **the truth
costs now and pays later; a lie is cheap now and costs upkeep.** Naming the true
maker makes that race hostile and locks it there; every confirming fragment
later compounds trust with the others; a lie is kept up by suppression, which
spends standing (and money) for as long as it stands. Care at a race's port
(Vigor rule 17) is the main thing standing buys.

## Player Fantasy

**Your word is your account.** Standing is credit the player builds with each
race and spends on their care; a lie is a loan that keeps charging upkeep. Every
gain and loss is written in the faction's ledger with its cause, so allegiances
feel earned and readable.

*Anchor moment:* the player opens the Halsk ledger: "+120, shared the base twelve
relic (day 31); −10, suppression upkeep (day 40); −21, care for the Spiralward
(day 44)". They see exactly what keeping their lie is costing them.

**Pillars served:**
- **Pillar 2:** the truth's cost (hostility, locked) and a lie's upkeep are both
  standing (rules 5, 8).
- **Pillar 4:** every change is logged with its cause; no hidden modifier
  (rule 10).
- **Pillar 1:** standing earns care and lending eligibility for a return attempt.
- **Pillar 5, *Living Against Made*:** care is the living races' side of the
  asymmetry; it restores Vigor, never Coherence.

**This system must never make the player feel:** "they hate me and I don't know
why" or "I can keep a lie forever for free".

## Detailed Design

### Core Rules

**A. The ledger**

1. **One standing value per faction** toward the player, an integer
   `s ∈ [−1,000, +1,000]`; the start value is per-faction content (default 0).
   Every write is clamped, and any clipped amount is logged.
2. **Bands** with boundaries −500, −150, +150, +500 give **Hostile**, **Wary**,
   **Neutral**, **Trusted** and **Allied**. Hysteresis `H` = 50: rising across a
   boundary needs `s ≥ b`; falling needs `s < b − H`. The band is saved, and is
   re-evaluated until stable, so one large change can cross several bands.
3. **What each band allows** (each keeps everything below it, from Wary up):
   - **Hostile**: docking refused (no rest, trade, care or refit); not eligible
     to lend; `engages_on_sight` for Sector Map and fleet AI; lent ships of that
     race are recalled by their lending owner (Allied Lending's Hostile veto);
   - **Wary**: dock, rest and trade (Markets owns prices; this band is a price
     hook);
   - **Neutral**: care offered at 1,500 ‰ of the base price;
   - **Trusted**: care at 1,000 ‰ (lending does not read Standing: Allied
     Lending decides from Faction Belief alone, with only the Hostile veto
     above);
   - **Allied**: care at 750 ‰.

**B. Writes**

4. **Every write goes through the API with a cause.** This system never invents
   a change. Shared magnitudes: SLIGHT 40, MARKED 120, SEVERE 300. Writers:
   - Faction Belief & Blame: reactions to shared fragments, compounding trust
     from confirming fragments, exposure turning factions against the player;
   - Contracts & Missions (Alpha): +SLIGHT or +MARKED on completion, −SLIGHT on
     failure;
   - combat: a player-initiated battle against a faction costs −MARKED; winning
     alongside a faction against machines earns +SLIGHT.
5. **Spends** (care; suppression purchase and upkeep, whose amounts and target
   faction Faction Belief & Blame and Exposure decide) are **atomic**: a spend
   is refused if `s − price < SPEND_FLOOR` (0); it never applies part.
6. **Drift, toward a belief target, one way.** Faction Belief & Blame sets each
   faction's `target`. Every `DRIFT_DAYS` (10) a World Clock event (priority
   100) moves each faction in ID order (Formulas D3): above the target it drifts
   down ("goodwill fades"); below `min(target, 0)` it drifts up to that
   ("grudges fade"); otherwise it holds. **Drift never raises standing above 0**,
   so it never creates spendable standing.
7. **Difficulty never scales standing.** Standing is not income: no standing
   value changes with the preset, so the standing side of a lie costs the same on
   every preset (Gameplay Settings & Modifiers rule 9). The money side of
   suppression scales with `yield_permille` and belongs to Credits, Upkeep &
   Sinks (#18).

**C. The truth's consequence**

8. **Publicly naming a race as the maker sets that race Hostile and locks it.**
   The trigger is keyed on the **public verdict entering NAMES(X), from any
   cause** (an accusation, shares or an exposure; Faction Belief & Blame D3), **never on the hidden truth**: a race named as the maker is
   hostile whether or not it is the true maker, so nothing about the
   consequence reveals the answer (Pillar 2; the sharing preview is
   truth-blind). The truth and a lie differ later, not here: a true accusation
   compounds trust as confirming fragments surface; a false one must be kept up
   by suppression and risks exposure. Faction Belief & Blame calls
   `set_hostile(f, cause)`, a **set**, not a delta: `s` becomes
   `min(s, HOSTILE_SET)` (−600), the band is forced to Hostile, and
   `enmity_lock` is set. Under the lock, positive changes still apply but `s` is
   capped at −501. Only Faction Belief & Blame may release the lock; at MVP
   nothing does.
9. **A non-hostile port is always reachable, guaranteed by Ports, Rest & Care
   (#27)** through unaligned free ports (no ledger row), at least one reachable
   from every node. This ledger never refuses a write for geographic reasons, so
   the truth's consequence is never softened.

**D. Visibility and saving**

10. **The transaction log.** Every change appends `{seq, tick, faction, op,
    requested, applied, clipped, before, after, band_before, band_after,
    cause_kind, cause_ref}`. The newest 128 entries per faction are kept; older
    ones fold into per-cause totals. The log is shown in the faction panel (the
    Ledger). No write skips it.
11. **Preview.** `preview(ops)` returns the band changes and lost privileges a
    set of operations would cause, without applying them. It receives only the
    first-order, **truth-blind** operations Faction Belief & Blame supplies;
    changes that depend on the truth (compounding trust, exposure) are never
    previewed; results are shown as band names and lost privileges, never
    numbers. The sharing preview
    uses it, including the loss of scar care Hulls & Ship Definition rule 8
    requires.
12. **Save section** `base:faction_standing` (Save/Load & Migration Core Rule 7):
    `s`, band, lock, target, log and `seq` per faction; loads after Content Data.
13. **API** (no engine types, unit-testable): queries `get(f)`, `band(f)`,
    `can(f, privilege)`, `quote_care(f, ship) → price | UNAVAILABLE`; writes
    `earn`, `penalize`, `spend → OK | REFUSED`, `set_hostile`, `set_target`;
    `preview(ops)`; signal `standing_changed(entry)`.

### States and Transitions

| State (per faction) | Entered when | Leaves to |
|---|---|---|
| Allied / Trusted / Neutral / Wary / Hostile | `s` crosses a band boundary (with hysteresis) | adjacent bands |
| Hostile (locked) | `set_hostile` | — at MVP (only Faction Belief & Blame may release) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Vigor (#13) | #17 → #13 | Care price (`quote_care`); `restore(source = care)` after a successful spend |
| Ports, Rest & Care (#27) | both | Reads `can`; owns the always-reachable port (rule 9) |
| Faction Belief & Blame (#30) | #30 → #17 | Reaction deltas, targets, `set_hostile`, lock; suppression spends |
| Exposure & Rival Investigation (#32) | via #30 | Exposure consequences |
| Credits, Upkeep & Sinks (#18) | — | Money side of suppression |
| Contracts & Missions (#38), Colonies (#42), Background Faction Economy (#43), Markets | both | Read bands; write with a cause |
| Hulls & Ship Definition (#10) | #17 → sharing preview | Scar-care loss via `preview` |
| World Clock (#8) | #8 → #17 | Drift event every `DRIFT_DAYS` |
| Save/Load & Migration (#5) | #17 → #5 | Section |
| Gameplay Settings & Modifiers (#7) | — | No scaling (rule 7) |

## Formulas

### D1. Missing Vigor share

`m = ((C0 − C) × 1,000 + C0 − 1) div C0` (‰, rounded up; 0 – 1,000), with `C0`
and `C` from Vigor (rule 1).

### D2. Care price

`p = max(CARE_MIN, (m × CARE_FULL × w × band_pm + 999,999) div 1,000,000)`; UNAVAILABLE if `m` = 0 or the band is Wary or Hostile.

| Variable | Range | Description |
|---|---|---|
| CARE_FULL | 15 – 60; **30** | Standing for a full restore at weight 1 |
| w | 1 – 4 | Size class: light 1, line 2, heavy 3, capital 4 |
| band_pm | 1,500 / 1,000 / 750 | Neutral / Trusted / Allied |
| CARE_MIN | 1 | Minimum price |

**Example:** `C0` 600,000 mV, `C` 420,000 mV → m = 300 ‰. A heavy ship (w = 3) at
Allied: (300 × 30 × 3 × 750 + 999,999) div 1,000,000 = **21 standing**, against 2
rest days (Vigor D4). A six-ship line fleet (w = 2) at m = 300 and Trusted costs
6 × 18 = 108, taking a fresh Trusted faction (150) down to 42, below 150 − 50 =
100, so it drops to **Neutral**: care is a real price.

### D3. Drift

`t' = target` if `s > target`; `t' = min(target, 0)` if `s < min(target, 0)`;
`step = min(|s − t'|, max(5, |s − t'| × 100 div 1,000))`.
**Examples:** s 400, target 150: step 25 → 375. s −300, target +200: t' = 0,
step 30 → −270.

### D4. Clamp

`after = clamp(before + d, −1,000, lock ? −501 : 1,000)`; `clipped = before + d −
after`.

## Edge Cases

- **If a spend happens on the tick a band drops**: it uses the band before the
  drop.
- **If `set_hostile` is called on a faction already Hostile**: it still sets the
  lock and logs.
- **If drift and reactions fall due at the same instant**: reactions first
  (World Clock priority), then drift.
- **If a hostile faction is the only one in reach**: Ports, Rest & Care's free
  port applies (rule 9).
- **If a faction ID is unknown**: programmer error.
- **If a mod faction has no start value**: 0.
- **If care is asked for a ship without Vigor** (a machine hull): `quote_care`
  returns UNAVAILABLE (not applicable). Standing never restores Coherence.
- **If suppression upkeep can no longer be paid**: the spend is refused and
  Faction Belief & Blame resolves the lapsed lie; standing never goes below its
  floor through a spend.
- **If contracts are absent** (MVP: Contracts & Missions is Alpha): the
  repeatable faucets are combat aid and belief reactions; care may be scarce,
  which is a balance concern, not a soft-lock (rest is always available).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Content Data & Mod Loading (#4) | Hard | Faction definitions, start values |
| Save/Load & Migration (#5) | Hard | Section |
| World Clock (#8) | Soft | Drift event |
| #13, #27, #30, #32, #38, #42, #43, Markets | Hard (reverse) | Ledger API |

Bidirectional check: Vigor (rule 17) and Hulls (rule 8) name this system; the
systems index lists it under #27, #30, #38, #42 and #43.

## Tuning Knobs

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| Band boundaries | −500 / −150 / +150 / +500 | ±100 each | Thresholds |
| `H` | 50 | 25 – 100 | Band stability |
| SLIGHT / MARKED / SEVERE | 40 / 120 / 300 | 20 – 60 / 80 – 200 / 200 – 400 | Event weight |
| `CARE_FULL` | 30 | 15 – 60 | Care price |
| `band_pm` | 1,500 / 1,000 / 750 | 750 – 2,000 | Band price differences |
| `DRIFT_DAYS` | 10 | 5 – 30 | Drift cadence |
| Drift rate | 100 ‰, min 5 | 50 – 200 ‰ | Drift speed |
| `HOSTILE_SET` | −600 | −1,000 – −550 | Hostility depth |
| `SPEND_FLOOR` | 0 | 0 – +150 | Lowest standing a spend may leave |

All in `assets/data/factions/`.

## Visual/Audio Requirements

None of its own. The faction panel shows the band, the value and the log.

## Game Feel

- **Every change has a reason you can read.**
- **Care is a decision**: its price is shown before it is paid.

## UI Requirements

- Faction panel (Ledger): band, value, recent log with causes, folded totals,
  lock indicator, the band boundaries and the current drop point ("drops to
  Neutral below 100").
- The care quote shows how the spend changes the band (via `preview`).
- Port screens: care price quote, or why care is unavailable.
- Sharing preview: band changes and lost privileges from `preview` (owned by
  Faction Belief & Blame's UI).
- 📌 **UX Flag — Faction Reputation & Standing**: include the faction panel and
  care quote in the Ledger and port UX specs.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Care restores Vigor; price from missing share | `design/gdd/vigor.md` | Rules 1, 16, 17; D4 | Formula dependency |
| Scar-care loss in the preview | `design/gdd/hulls-and-ship-definition.md` | Rule 8 | Rule dependency |
| No difficulty scaling | `design/gdd/gameplay-settings-and-modifiers.md` | Rules 9, 13 | Rule dependency |
| Drift event | `design/gdd/world-clock.md` | Rule 6 | Rule dependency |
| Section | `design/gdd/save-load-and-migration.md` | Core Rule 7 | Data dependency |

## Acceptance Criteria

- **AC-01 (Logic; rules 1, D4)**: every write clamps to [−1,000, 1,000] and the log entry records `clipped`.
- **AC-02 (Logic; rule 2)**: hysteresis: 150 → Trusted; falling to 120 → still Trusted; 99 → Neutral.
- **AC-03 (Logic; rule 2)**: one −700 change from +400 lands in Wary (−300), resolved in a single re-evaluation; a −1,000 change from +400 (−600) lands in Hostile.
- **AC-04 (Logic; D2)**: the worked example quotes 21; `m` = 0 or a Wary or Hostile band quotes UNAVAILABLE.
- **AC-05 (Logic; rule 5)**: a spend that would leave `s` below `SPEND_FLOOR` is refused and `s` is unchanged.
- **AC-06 (Logic; rule 8)**: `set_hostile` from +900 gives −600, Hostile, lock on; under the lock, +300 from −600 gives −501.
- **AC-07 (Logic; D3)**: drift matches the worked values and never takes `s` above 0 from below.
- **AC-08 (Logic; economy)**: with no play, a suppression upkeep stream drives spendable standing to refusal within the computed number of days.
- **AC-09 (Logic; rule 10)**: every change of `s` has exactly one log entry with a cause (a test walks every writer).
- **AC-10 (Logic; rule 11)**: `preview` lists the loss of care, scar care included, before a share that would make a faction Hostile; the preview is identical whether or not the named race is the true maker, and shows no numbers.
- **AC-15 (Logic; rule 8)**: naming a race that is not the true maker sets it Hostile and locked exactly as naming the true maker does.
- **AC-16 (Logic; Edge Cases)**: `quote_care` for a machine hull returns UNAVAILABLE.
- **AC-11 (Logic; rule 12)**: a save round trip is byte-identical; the section is registered with a ceiling and version 1.
- **AC-12 (Logic; rule 7)**: standing values are identical on Chronicler, Standard and Admiral for the same inputs.
- **AC-13 (Logic; rule 6)**: drift results do not depend on tick size or game speed.
- **AC-14 (UI)**: the faction panel and care quote have retained screenshots when their stories close.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Releasing the enmity lock** (a later reconciliation). | game-designer | 1.0 |
| 2 | **MVP faucets without contracts** may make care scarce; check in playtest. | economy-designer | First campaign playtest |
| 3 | ~~**Free unaligned ports**~~ **Resolved 2026-10-30:** one per region (Sector Map & Travel rule 3); a free port always docks the player (Ports, Rest & Care rule 5). | #27 | Closed |
| 4 | ~~**Reaction magnitudes**~~ **Resolved 2026-10-30:** each faction reacts to the change in public blame on its own race, banded SLIGHT / MARKED / SEVERE at 20 / 80 / 200 ‰ (Faction Belief & Blame D5). | #30 | Closed |
| 5 | ~~**Accusation-keyed hostility**~~ **Resolved 2026-10-30:** confirmed and generalised: the verdict entering NAMES(X) from any cause sets X Hostile (Faction Belief & Blame D3; rule 8 amended). | #30 | Closed |
