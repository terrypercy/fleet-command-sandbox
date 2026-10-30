# Faction Belief & Blame

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (accusation strength grows with the shown case; the text-only faction owns a real port; preview adds drift, seal-lapse, faith and the confirmation line; per-class totals maker-blind; naming line on bars)
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — what each faction believes about the makers is shaped by what the player shares, suppresses and accuses, never by the hidden truth); Pillar 4 (Plan in the Open — every share's consequences are previewed before commit)

## Summary

Faction Belief & Blame holds what each faction believes about who built the machines: a per-faction blame distribution over the candidate races, starting symmetric and seed-independent. Sharing a fragment moves blame by its claim's contradiction pattern and printed class, accusing moves blame onto the accused, and sealing a held fragment buys silence at a money and standing price; the public verdict names a race only past a clear threshold and lead, and hostility follows that verdict. Every number is a function of claims and actions, never of the hidden maker, and every first-order consequence is previewed before commit.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Truth Seeding & Candidates, Faction Reputation & Standing, Credits, Upkeep & Sinks, Archive Fragments & Evidence, Runtime ID Service`

## Overview

Faction Belief & Blame holds what each faction believes about who built the
machines, and the public history that follows from those beliefs. Each faction
keeps a **blame distribution** over the candidate races, in integer permille.
The player changes it in three ways. They can **share** a held fragment with one
faction or with everyone. They can **accuse** a race in public. They can
**suppress** a held fragment, which seals it and costs money and standing every
day. The public history is a **verdict**, UNRESOLVED or NAMES(X), worked out
from the beliefs. When a verdict first names a race, that race turns Hostile
(Faction Reputation & Standing rule 8). Every number here is a function of
fragment **claims**, player actions and authored starting beliefs. None reads
the hidden maker, so a lie and the truth cost the same at the moment of commit.
The difference shows up later. Exposure (#32) tests the verdict against
fragments rivals find. Suppression upkeep (#18) charges for every sealed
contradiction. The Reckoning (#34) reads the record. Every share and accusation
is previewed first, showing first-order effects only: who moves, in which
direction, roughly how far, and what the move does to standing, lending and
exposure.

## Player Fantasy

You hold the only honest account of what happened, and nobody else knows it
yet. Every fragment you hand over moves someone. Hand a relic to the Orrowen
and you watch them start to doubt the Halsk. Say "the Halsk built them" in
public and the Weir agrees, and the Halsk close their ports to you. Whether you
were right is your problem, not the game's: the preview treats both cases the
same, and so does the moment you commit. The truth costs you now and pays back
as confirming evidence surfaces. A lie pays now and then sends a bill every day.
A sealed record has its upkeep, a keeper has to stay friendly, and somewhere a
rival is digging toward the one fragment that would undo you. This is the
detective who has to decide what to say in court, not the one who solves the
case. The fantasy is authorship under scrutiny: *the history is mine to write,
and I can see exactly what each sentence will cost.*

## Detailed Design

### Core Rules

**A. The belief model**

1. **Each faction holds one blame distribution.** For every faction `f` and
   every candidate `c` (Truth Seeding rule 1), `b_f[c]` is an integer in
   permille. Each faction also holds a residual `doubt_f ≥ 0`, and
   `Σ_c b_f[c] + doubt_f = 1,000` always. Doubt is only a rounding remainder
   (rule 2). No action moves it.
2. **Starting beliefs are authored, symmetric and seed-independent** (Formulas
   D0). A faction whose race is a candidate starts at `SELF_START` (100) on its
   own race and splits the rest evenly over the other candidates: 450 / 450 at
   C = 3, and 300 / 300 / 300 at C = 4. A faction whose race is not a candidate
   splits 1,000 evenly, and the remainder goes to doubt. This is lore bible
   §3.6, "every race suspects the others". It replaces the blame cycle in lore
   bible OQ 3, which breaks at C = 3. Nothing in the start depends on the seed
   or the maker.
3. **The public blame on a race is what the others say about it.** `P[c]` is
   the mean of `b_f[c]` over every faction whose race is not `c` (D4). A
   faction's view of itself never enters `P`. This keeps `P` equal for every
   candidate at the start (450 at C = 3, 300 at C = 4), whichever races have a
   faction at MVP.
4. **The verdict** is the public history's headline (D3): **NAMES(X)** when
   `P[X]` reaches `NAME_PM` (600) and leads the next race by `LEAD_PM` (200),
   with hysteresis `NAME_H` (50). Otherwise it is **UNRESOLVED**. The start is
   UNRESOLVED. Concept §Pillar 2 leaves "names" and "split" to this GDD; these
   are those thresholds.

**B. Actions** (each a player command, committed in a planning hold outside
battle; each has a preview, a confirm step and no undo)

5. **Share** `share(φ, target)`, where `target` is one faction or PUBLIC (every
   faction). `φ` must be HELD (#28), not suppressed, and not yet shared with
   that faction. The share moves each receiving faction's blame by the
   **claim's contradiction pattern only** (D1). Blame leaves the candidates the
   claim contradicts (Truth Seeding rule 6) and goes evenly to the candidates
   it is consistent with. The size depends on the provenance class, which is
   printed on the card (`SHIFT_PM`): DIRECT_PHYSICAL 250, RECORD 250, TESTIMONY
   120, FORGERY 40. A fragment from a source chain the faction has already
   received moves blame at `CHAIN_ECHO_PM` (500 ‰) of normal, because a chain
   counts once. A PUBLIC share is applied to each faction in faction ID order,
   and factions that already received `φ` are skipped.
6. **Accuse** `accuse(X)` names candidate `X` in public. Every faction whose
   race is not `X` moves `ACCUSE_PM` of its blame on every other candidate onto
   `X` (D2). `ACCUSE_PM` grows with the case the player has **shown**:
   `s_pub`, the distinct reliable groups consistent with `X` already shared
   PUBLIC. `X`'s own faction does not move, because it denies the charge. An
   accusation is refused while the verdict already NAMES(X). A bare accusation
   from the symmetric start does **not** name (D2): naming takes one act of
   showing evidence and one of speaking, as in a courtroom. The preview always
   says whether this accusation names.
7. **Suppress** `suppress(φ, keeper)` seals a HELD fragment that is not shared
   and not exposed. The fragment **stays HELD** in #28 with a #30 flag (this
   answers Archive Fragments OQ 3). A sealed fragment cannot be shared. It is
   out of play for the Reckoning while its upkeep is paid. It still counts in
   the held set when good faith is judged (rule 13), so it cannot be used to
   launder an accusation. The cost has two parts (D8):
   - **Money:** Credits rule 9 charges the purchase and the daily upkeep.
   - **Standing:** the player picks a **keeper**, a non-Hostile faction that
     agrees to keep the secret. The keeper pays `SUPPRESS_STANDING_BUY` (120)
     at once and `SUPPRESS_STANDING_DAY` (2) per day through
     `Standing.spend`.

   Both purchase spends are checked before either is applied. If either would
   be refused, the action is refused and neither is charged.
8. **Release** `release(φ)` ends a suppression at once. Upkeep stops, nothing
   is refunded, and `φ` is back in play.
9. **Lapse.** A suppression lapses after `SUPPRESS_GRACE_DAYS` (3, Credits'
   knob) unpaid days in a row. Unpaid days on the money side are counted by
   Credits (its `suppression_at_risk` and lapse). Unpaid days on the standing
   side are counted here: a refused keeper spend is an unpaid day. On a lapse
   from either side, `φ` becomes unsealed. A LAPSE entry is written and
   `suppression_lapsed(φ)` is emitted for #32. The run never ends because of a
   lapse. A lapsed fragment can be suppressed again at full price.

**C. Consequences**

10. **Reactions** (this answers Standing OQ 4). After each action, every
    faction whose race is a candidate reacts to the change in public blame on
    its own race, `ΔP` (D5). Less blame earns standing and more blame
    penalises it, in the bands SLIGHT, MARKED or SEVERE. Each faction gets one
    write per action, with the action's history entry as the cause. A faction
    that the action newly names gets no reaction, because rule 11 applies to
    it instead.
11. **Naming sets Hostile** (this confirms Standing rule 8 and answers Standing
    OQ 5). When the verdict changes into NAMES(X) and `X` has a faction, #30
    calls `Standing.set_hostile(f_X, cause = naming entry)` after the
    reactions. This happens whatever caused the change: an accusation, a share
    or an exposure. Hostility follows the public verdict and never the truth.
    The enmity lock is never released at MVP. A race named before keeps its
    lock if the verdict later moves to another race.
12. **Targets.** After every action, #30 sets each faction's drift target with
    `Standing.set_target` (D6). The target rises as public blame on the
    faction's own race falls below the start, and falls as that blame rises.
13. **Good faith** is judged when a naming starts (D7), on the held set
    snapshotted at commit (#28 rule 24). Suppressed fragments are included. The
    naming is GOOD_FAITH when the held fragments do not rule `X` out
    (`contra_held(X) < 2`) and give it enough support (`support_held(X) ≥
    GF_MIN_SUPPORT`, 2). Otherwise it is BAD_FAITH, a **lie**. A naming that no
    player action caused (an exposure moved it) is marked WORLD and treated as
    good faith. Later finds never change the judgement. One player act does:
    suppressing a held reliable fragment that contradicts the current named
    race sets the naming to BAD_FAITH, because a cover-up is not good faith.
14. **Compounding trust** (concept, "every later confirming fragment
    compounds trust"). While the verdict NAMES(X), each `FragmentHeld` of a
    DIRECT_PHYSICAL or RECORD fragment whose claim is consistent with `X`
    earns standing with every faction whose race is not `X` (D10). The amount
    grows with each confirmation. It is judged on the claim only, and it is
    **never previewed** (Standing rule 11), because it depends on what is
    still unfound. A lie can earn confirmations from fragments consistent
    with it; the truth earns more, because more reliable fragments are
    consistent with it.
15. **Exposure** (this answers the #32 CD condition). Only #32 calls
    `expose(φ)`. #30 accepts the call only if the verdict NAMES(X), `φ` is
    DIRECT_PHYSICAL or RECORD, its claim contradicts `X`, and `φ` is not
    suppressed. Otherwise it returns `NOT_CONTRADICTING` and nothing changes,
    so an exposure never fires on a timer alone. When accepted:
    - `φ` becomes a public record entry (EXPOSED) and is applied as a PUBLIC
      share (D1);
    - the first exposure of a naming penalises every non-locked faction whose
      race is not `X` (D9): SEVERE for a BAD_FAITH naming, SLIGHT for
      GOOD_FAITH or WORLD;
    - later exposures of the same naming move belief only.

**D. Truth-blindness**

16. **#30 never reads the maker.** Truth Seeding guarantees per-class fragment
    totals are identical across makers for a given content set, so
    `unfound_count_by_class()` in the preview leaks nothing. It reads fragments through a claim view
    from Truth Seeding: the axis, value, class, group, and each candidate's
    attribute row. It reads nothing else. "Contradicts" and "consistent" are
    computed from the claim against the public attribute table (Truth Seeding
    rule 6), not from Truth Seeding's reliable-contradiction flag. #30 draws no
    random numbers. With the same claims, actions and content, every belief,
    verdict, reaction, target, faith judgement and preview is identical
    whoever the maker is.
17. **A lie is defined against existing fragments, not the truth.** #30
    records the faith judgement and the verdict. Whether a reliable fragment
    that contradicts the verdict exists, and whether a rival finds it, is for
    #32 and #34 to evaluate.

**E. Preview**

18. **`preview(action)`** runs D1–D7 on a copy of the state inside the same
    planning hold as the commit (#28 rule 24). It returns these
    first-order effects:
    - each faction's blame change per candidate, as a direction and a band
      (D11), with no numbers;
    - the verdict before and after ("This names Halsk");
    - the standing result from `Standing.preview(ops)`, where `ops` are the
      reactions, any `set_hostile` and the suppression spends (band changes
      and lost privileges, scar care included);
    - the lending result from #33 (`preview_lending(belief_after)`: "this
      share grants / loses the escort");
    - each faction's drift target direction (rises / falls / unchanged; rule 12);
    - seals whose keeper this action turns Hostile, and their lapse day;
    - for a suppression, whether it turns the current naming to bad faith
      (rule 13);
    - on any action that changes the verdict to NAMES(X), the same fixed line
      in every case: "While X stands named, each confirming find earns trust
      with everyone else, growing with each find." (identical for a lie and the
      truth, so it leaks nothing);
    - the exposure readout from #32 for the verdict after the action: held
      reliable contradictions (open / sealed) before and after, plus the
      rival's progress, unchanged;
    - "k reliable fragments are still unfound; any may contradict this", from
      `unfound_count_by_class()`;
    - the faith line (D7), as counts over held fragments;
    - for a suppression, the coverage line from Credits and the keeper's band
      after the purchase.

    It never shows compounding trust, exposure outcomes, or any number about
    beliefs. The commit applies exactly what the preview showed.

**F. Record, save and determinism**

19. **The public history record** is an append-only log. Each entry is
    `{seq, tick, kind, actor, fragment, target, race, held_snapshot (IDs),
    verdict_before, verdict_after, faith}`, where `kind` is SHARE_PRIVATE,
    SHARE_PUBLIC, ACCUSE, SUPPRESS, RELEASE, LAPSE, EXPOSE, NAMING or
    CONFIRM. The **public history** has three parts: the current verdict,
    `P`, and the entries that are public (shares made PUBLIC, accusations,
    exposures, namings). The other entries are the player's own ledger. A
    `naming` record holds `{X, entered_seq, faith, exposed}`.
20. **IDs.** Factions, candidates and fragments are referenced by Runtime ID.
    The display name and kind are stored when an entry is written (Runtime ID
    Service rule 6, and its dependency row for #30). IDs are never shown.
21. **Order.** Every loop runs in ascending Runtime ID (factions, candidates),
    and actions run in commit order. All maths is integer, with `div`
    truncating toward zero on non-negative operands. The standing upkeep for
    suppression runs in the daily step straight after Credits' suppression
    charge.
22. **Save section** `base:faction_belief`, version 1. It holds:
    - `b_f` and `doubt_f` for every faction;
    - the verdict and the naming record;
    - per fragment: who it was shared with, the received chains per faction,
      and `{suppressed, keeper, since_tick, standing_unpaid_days}`, exposed and
      confirmed flags;
    - the confirmation count `k`;
    - the log and `next_seq`.

    The newest `LOG_KEEP` (512) entries are kept. Older entries other than
    NAMING and EXPOSE fold into counts per kind. Every save round trip is
    byte-identical.
23. **No difficulty scaling.** No belief, threshold or standing amount here
    changes with the preset (Gameplay Settings rule 9). Only Credits' money
    side scales, by `yield_permille`.

### States and Transitions

| Entity | State | Entered when | Leaves to |
|---|---|---|---|
| Verdict | UNRESOLVED | Start; or NAMES(X) stops meeting the hold condition (D3) | NAMES(X) |
| Verdict | NAMES(X) | `P[X] ≥ NAME_PM` and lead `≥ LEAD_PM` | UNRESOLVED; NAMES(Y) |
| Naming | GOOD_FAITH / BAD_FAITH / WORLD | Naming starts (D7) | BAD_FAITH (suppressing a held contradiction, rule 13); replaced at the next naming |
| Naming | exposed | First accepted `expose` | — (stays exposed for that naming) |
| Fragment (#30 view) | UNSHARED | Grant (#28) | SHARED, SUPPRESSED |
| Fragment | SHARED (per faction or public) | `share` | — (permanent) |
| Fragment | SUPPRESSED | `suppress` | UNSHARED, via release or lapse |
| Fragment | EXPOSED | `expose` accepted (an unfound fragment found by a rival) | — |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Truth Seeding & Candidates (#16) | #16 → #30 | Claim view: candidates, attribute table, per-fragment axis, value, class, group. **Never the maker** |
| Archive Fragments & Evidence (#28) | both | Reads `held_fragments()`, `unfound_count_by_class()`, `FragmentHeld`. Supplies the "Shared with ⟨faction⟩" and "Sealed" lines for the card |
| Faction Reputation & Standing (#17) | #30 → #17 | `earn` / `penalize` (reactions, confirmations, exposure), `set_hostile`, `set_target`, `spend` (keeper), `preview(ops)` |
| Credits, Upkeep & Sinks (#18) | both | Suppression purchase and upkeep charges; `suppression_at_risk` and lapse back to #30; coverage line |
| Exposure & Rival Investigation (#32) | both | #32 reads `verdict()`, `contradicts_public(φ)`, `held_reliable_contradictions()`, `suppressed_set()`, `suppression_lapsed`. #32 calls `expose(φ)` and `preview_readout(verdict_after)` |
| Allied Lending (#33) | #30 → #33 | Reads `belief(f)` and `public_blame()`; supplies `preview_lending(belief_after)` |
| Reckoning & Endings (#34) | #30 → #34 | Reads `verdict()`, `naming()`, `suppressed_set()`, the log. Read only |
| Public History screen (#49) | #30 → #49 | `preview(action)`, the commit commands, the record, `P` as bars |
| Runtime ID Service | #30 → it | Keys and stored names (rule 20) |
| World Clock (#8) | #8 → #30 | Daily step for standing upkeep |
| Save/Load & Migration (#5) | #30 → #5 | Section `base:faction_belief` |
| Content Data & Mod Loading (#4) | #4 → #30 | The faction → race map; knobs |
| Sector Map & Travel | via #17 | Hostility reaches the map only through bands |

## Formulas

Shared symbols: `C` is the number of candidates (3 at MVP). `b_f[c]` is
faction `f`'s blame on `c` (‰). `race(f)` is the faction's race. "Reliable"
means DIRECT_PHYSICAL or RECORD.

### D0. Starting beliefs

If `race(f)` is a candidate: `b_f[race(f)] = SELF_START`, `b_f[c] = (1,000 −
SELF_START) div (C − 1)` for each other `c`, and `doubt_f` is the remainder.
Otherwise: `b_f[c] = 1,000 div C`, and `doubt_f = 1,000 − C × (1,000 div C)`.

| Variable | Type | Range | Description |
|---|---|---|---|
| SELF_START | int ‰ | 0 – 200; **100** | A faction's starting blame on itself |
| C | int | 3 – 4 | Candidates |
| `p0` | int ‰ | 266 – 500 | Start blame on others, `(1,000 − SELF_START) div (C − 1)` |
| doubt_f | int ‰ | 0 – 3 | Remainder |

**Output:** at C = 3, 100 / 450 / 450 (doubt 0). At C = 4, 100 / 300 / 300 / 300.
A non-candidate faction at C = 3 gets 333 each with doubt 1. Every `P[c]`
starts equal to `p0` (D4).

### D1. Share shift

```
s_eff = SHIFT_PM[class] × e div 1,000          (e = CHAIN_ECHO_PM if f already holds φ's group, else 1,000)
u_c   = b_f[c] × s_eff div (1,000 × |K|)       for each c ∈ X
b_f'[c] = b_f[c] − u_c × |K|                   for c ∈ X
b_f'[k] = b_f[k] + Σ_{c ∈ X} u_c                for k ∈ K
```

| Variable | Type | Range | Description |
|---|---|---|---|
| X | set | 1 – C−1 candidates | Candidates the claim contradicts (value differs) |
| K | set | 1 – C−1 candidates | Candidates the claim is consistent with; `|X| + |K| = C` |
| SHIFT_PM | int ‰ | 0 – 400 | DIRECT 250, RECORD 250, TESTIMONY 120, FORGERY 40 |
| CHAIN_ECHO_PM | int ‰ | 0 – 1,000; **500** | Shift for a repeat chain |
| u_c | int ‰ | 0 – 200 | Blame moved from `c` to each `k` |

**Output range:** the total is conserved exactly (each `c` loses `u_c × |K|`,
and the `K` side gains `|K| × Σ u_c`). Every value stays in [0, 1,000], since
`u_c × |K| ≤ b_f[c] × 400 div 1,000`. If `X` or `K` is empty, nothing moves (rule
`EMPTY_PATTERN`, Edge Cases).

**Worked example** (C = 3, start, f3 "numbering base = base eight", DIRECT,
contradicts Halsk only, so X = {H}, K = {O, I}, shared PUBLIC):

- Orrowen: u_H = 450 × 250 div 2,000 = 56. H 450 − 112 = **338**, O 100 + 56 =
  **156**, I 450 + 56 = **506** (sum 1,000).
- Ithren: H **338**, O **506**, I **156**.
- Halsk: u_H = 100 × 250 div 2,000 = 12. H **76**, O **462**, I **462**.

D4 then gives P[H] = (338 + 338) div 2 = **338**, P[O] = (462 + 506) div 2 =
**484**, and P[I] = **484**. The verdict stays UNRESOLVED (484 < 600). D5:
ΔP[H] = −112 is MARKED, so Halsk gains +120. ΔP[O] = ΔP[I] = +34 is SLIGHT, so
Orrowen and Ithren each lose −40.

### D2. Accusation shift

`ACCUSE_PM = min(ACCUSE_BASE + ACCUSE_PER_SUPPORT × s_pub, ACCUSE_MAX)`.
For every faction `f` with `race(f) ≠ X`: `a_c = b_f[c] × ACCUSE_PM div 1,000`
for each `c ≠ X`. Then `b_f'[c] = b_f[c] − a_c`, and `b_f'[X] = b_f[X] + Σ a_c`.

| Variable | Type | Range | Description |
|---|---|---|---|
| ACCUSE_BASE | int ‰ | 150 – 350; **250** | A bare accusation's strength |
| ACCUSE_PER_SUPPORT | int ‰ | 100 – 250; **150** | Added per publicly shared supporting group |
| ACCUSE_MAX | int ‰ | 500 – 800; **700** | Cap |
| s_pub | int | 0 – groups shared | Distinct reliable groups consistent with X, shared PUBLIC |
| a_c | int ‰ | 0 – 700 | Moved from `c` |

**Output:** conserved, and every value stays in [0, 1,000].

**Worked example 1, a bare accusation** (C = 3, start, `s_pub` 0, so
`ACCUSE_PM` 250; accuse Halsk):

- Orrowen: a_O = 25, a_I = 112, giving H **587**, O **75**, I **338**.
- Ithren: H **587**, O **338**, I **75**.
- Halsk is unchanged.

P[H] = 587, P[O] = (450 + 338) div 2 = **394**, P[I] = **394**. 587 < 600, so
the verdict stays **UNRESOLVED**: shouting is not a case. ΔP[O] = ΔP[I] = −56
is SLIGHT, so Orrowen and Ithren each gain +40.

**Worked example 2, with one shared supporting group** (`s_pub` 1, so
`ACCUSE_PM` 400). Even from the symmetric start (a lower bound, since the
supporting share itself already raised blame on Halsk): Orrowen H = 450 + (40 +
180) = **670**, O 60, I 270; Ithren likewise. P[H] = 670, P[O] = (450 + 270) div
2 = 360, lead 310, so the verdict is **NAMES(Halsk)** and `set_hostile(Halsk)`
is called. At `s_pub` 3 the cap (700) applies.

At C = 4 from the start, `s_pub` 1 gives P[H] = 300 + 700 × 400 div 1,000 =
580 (not named) and `s_pub` 2 gives 300 + 385 = **685** (named): a wider field
needs a stronger shown case.

### D3. Verdict

Sort the candidates by `P` (descending, then by Runtime ID). Let `top` be the
first and `lead = P[top] − P[second]`.

- Enter NAMES(top) if `P[top] ≥ NAME_PM` and `lead ≥ LEAD_PM`.
- Hold NAMES(X) while `P[X] ≥ NAME_PM − NAME_H` and `P[X] − max_{c≠X} P[c] ≥
  LEAD_PM − NAME_H`.
- Otherwise the verdict is UNRESOLVED. A tie at the top always gives lead 0.

| Variable | Type | Range | Description |
|---|---|---|---|
| NAME_PM | int ‰ | 550 – 750; **600** | Public blame needed to name. Must exceed `p0` (500 at most) |
| LEAD_PM | int ‰ | 100 – 300; **200** | Margin over the next race |
| NAME_H | int ‰ | 0 – 100; **50** | Hysteresis |

**Example:** the D1 state (484 / 484 / 338) is UNRESOLVED. D2's example 1 (587)
is UNRESOLVED; example 2 (670, lead 310) is NAMES(Halsk). If P[H] later falls to 560 with the next race at 380
(lead 180), the verdict holds: 560 ≥ 550 and 180 ≥ 150. At 540 it becomes
UNRESOLVED.

### D4. Public blame

`P[c] = (Σ_{f ∈ F_c} b_f[c]) div |F_c|`, where `F_c` = the factions with
`race(f) ≠ c`.

| Variable | Type | Range | Description |
|---|---|---|---|
| F_c | set | ≥ 1 faction (content rule) | Everyone except `c`'s own faction |
| P[c] | int ‰ | 0 – 1,000 | Public blame on `c` |

**Output:** bounded in [0, 1,000]. Truncation may make `Σ P` less than 1,000,
which is fine because `P` is only compared. **Example:** at the start, P[H] =
(450 + 450) div 2 = 450.

### D5. Reaction to an action

`ΔP_f = P'[race(f)] − P[race(f)]`. The band is set by `|ΔP_f|`:

| `|ΔP_f|` | Result |
|---|---|
| < `REACT_T1` (20) | none |
| < `REACT_T2` (80) | SLIGHT (40) |
| < `REACT_T3` (200) | MARKED (120) |
| otherwise | SEVERE (300) |

The write is `earn` if `ΔP_f < 0` and `penalize` if `ΔP_f > 0`. Magnitudes are
Standing rule 4's. The range runs from −300 to +300 standing per action per
faction. Examples are in D1 and D2.

### D6. Drift target

`target_f = clamp((p0 − P[race(f)]) × TARGET_PM div 1,000, −TARGET_CAP,
+TARGET_CAP)`. The target is 0 for a faction whose race is not a candidate.

| Variable | Type | Range | Description |
|---|---|---|---|
| TARGET_PM | int ‰ | 500 – 1,500; **1,000** | Gain |
| TARGET_CAP | int | 150 – 500; **300** | Limit |

**Output:** [−300, +300], and 0 at the start (matching Standing's default).
**Example (D2 example 2):** Orrowen (450 − 360) = **+90**. Halsk (450 − 670) =
**−220** (inside the cap). A Halsk at P 800 would give −350, clamped to
**−300**.

### D7. Good faith

`contra_held(X)` = the number of distinct groups among held reliable fragments
(suppressed included) whose claim contradicts `X`. `support_held(X)` = the
number of distinct groups among held DIRECT_PHYSICAL, RECORD or TESTIMONY
fragments whose claim is consistent with `X`. Faith is `GOOD_FAITH` iff
`contra_held(X) < 2` and `support_held(X) ≥ GF_MIN_SUPPORT`.

| Variable | Type | Range | Description |
|---|---|---|---|
| contra_held | int | 0 – groups held | Uses Truth Seeding rule 8's meaning, over the held set |
| support_held | int | 0 – groups held | Forgeries excluded |
| GF_MIN_SUPPORT | int | 1 – 3; **2** | Minimum support |

**Worked example.** This uses the Truth Seeding fixture: f1 script, DIRECT, g1,
contradicts H and I; f3 base eight, DIRECT, g3, contradicts H; f5 testimony,
assumed consistent with Ithren. #30 never reads the fixture's maker. The player
holds f1, f3 and f5.

- Accuse Halsk: contra_held = 2 (g1, g3), so **BAD_FAITH**.
- Accuse Ithren: contra 1 (g1), support 2 (g3, f5), so **GOOD_FAITH** (a
  good-faith error in that fixture).
- Accuse Orrowen: contra 0, support 2 (g1, g3), so **GOOD_FAITH**.

### D8. Suppression cost

- Money: `D2(SUPPRESS_BUY_BASE, yield_permille)` at purchase and
  `D2(SUPPRESS_UPKEEP_BASE, yield_permille)` per day. Both are Credits'.
- Standing, from the keeper: `SUPPRESS_STANDING_BUY` at purchase and
  `SUPPRESS_STANDING_DAY` per day. Each is an atomic `spend` (Standing rule 5).

| Variable | Type | Range | Description |
|---|---|---|---|
| SUPPRESS_STANDING_BUY | int | 40 – 300; **120** | Keeper's one-off cost |
| SUPPRESS_STANDING_DAY | int | 1 – 10; **2** | Keeper's daily cost |
| SUPPRESS_GRACE_DAYS | int | Credits' knob; 3 | Unpaid days before a lapse |

**Example** (Standard, assuming `D2` returns the base at a yield of 1,000 ‰;
Open Question 8): one seal for 30 days costs 5,000 + 30 × 60 = **6,800 cr** and
120 + 30 × 2 = **180 standing**. A keeper at 300 drops to 180, Trusted to
Trusted. A keeper that turns Hostile has its spends refused, and the seal lapses
on day 3.

### D9. Exposure penalty

On the first accepted `expose` of a naming, every faction with `race(f) ≠ X`
that is not locked receives `penalize(EXPOSE_LIE)` (SEVERE 300) if the naming
is BAD_FAITH, or `penalize(EXPOSE_ERROR)` (SLIGHT 40) if it is GOOD_FAITH or
WORLD. The exposed fragment's D1 shift and D5 reactions then follow as a PUBLIC
share. The range per faction is the penalty plus at most one D5 band.

### D10. Compounding confirmation

`gain_k = min(CONFIRM_BASE × k, CONFIRM_MAX)`, where `k` is the confirmations
since the naming started, this one included.

| Variable | Type | Range | Description |
|---|---|---|---|
| CONFIRM_BASE | int | 20 – 80; **40** | First confirmation |
| CONFIRM_MAX | int | 80 – 300; **120** | Cap per confirmation |

**Example:** confirmations 1, 2, 3 and 4 give 40, 80, 120 and 120, a total of
360 for each non-`X` faction. This is not previewed.

### D11. Preview band

For each `(f, c)`, `|b_f'[c] − b_f[c]|` maps to none / slight / marked / severe
with the D5 thresholds. The direction is "blames c more" or "blames c less". No
numbers are shown.

## Edge Cases

- **If a claim's `X` or `K` is empty** (cannot happen under Truth Seeding G2
  and rule 7): no shift, and a log entry `EMPTY_PATTERN` is written. The share
  is still recorded.
- **If `φ` is shared again with a faction that already has it**: refused with
  `ALREADY_SHARED` (grey in the picker). A PUBLIC share skips those factions;
  if all of them have it, it is refused.
- **If the player shares or accuses a Hostile or locked faction**: allowed.
  Reactions apply, and the lock caps standing at −501 (Standing D4).
- **If the player accuses while the verdict already NAMES(X)**: refused with
  `ALREADY_NAMED`. Accusing Y instead is allowed. If Y is named, Y turns
  Hostile and X stays locked.
- **If the accused race has no faction** (for example a text-only race): the
  beliefs move and the verdict can name it. No `set_hostile` is called, because
  there is no ledger row. The preview says "No faction to turn hostile".
- **If a share pushes the verdict into NAMES(X)** without an accusation: it is
  a naming like any other. Rule 11 applies, D7 judges faith, and the preview
  showed it.
- **If an exposure moves the verdict into a new NAMES(Y)**: Y turns Hostile,
  and the naming is WORLD.
- **If the player suppresses a fragment they have shared, or one that is
  exposed**: refused with `PUBLIC_ALREADY`.
- **If the player shares a suppressed fragment**: refused with `SEALED`. They
  must release it first.
- **If the keeper turns Hostile** (for example through a later naming):
  standing upkeep is refused, and the seal lapses after 3 days. The naming's
  preview lists "Seal on ⟨fragment⟩ lapses in 3 days".
- **If money and standing upkeep both fail on the same day**: one lapse, one
  entry.
- **If #32 calls `expose` on a fragment that does not contradict the verdict,
  is not reliable or is suppressed, or while the verdict is UNRESOLVED**: it
  returns `NOT_CONTRADICTING` and nothing changes.
- **If `expose` is called on a fragment the player holds**: it is refused with
  `HELD`. A held contradiction is the player's to show or seal, and #34 reads
  it.
- **If a grant is attempted between preview and commit**: it is deferred
  (#28 rule 24).
- **If a confirmation arrives while the verdict is UNRESOLVED**: no gain, and
  `k` is not counted.
- **If two candidates tie at the top**: lead 0, so the verdict is UNRESOLVED.
- **If the log reaches `LOG_KEEP`**: the oldest non-NAMING, non-EXPOSE entries
  fold into counts. NAMING and EXPOSE are never dropped.
- **If a mod changes the faction set on an existing save**: factions missing
  from the save start at D0. Removed factions keep their tombstoned entries
  (Runtime ID rule 6). The candidate set never changes in a campaign (Truth
  Seeding rule 3).
- **If no candidate has a faction except one**: `F_c` is still non-empty for
  every `c` (content rule: at least 2 factions). Otherwise it is a load error,
  `BELIEF_FACTIONS_SHORT`.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Truth Seeding & Candidates (#16) | Hard | Claim view (rule 16); no maker query |
| Faction Reputation & Standing (#17) | Hard | Ledger API, `preview(ops)` |
| Credits, Upkeep & Sinks (#18) | Hard | Suppression charges, lapse signal, coverage |
| Archive Fragments & Evidence (#28) | Hard | `held_fragments()`, `unfound_count_by_class()`, `FragmentHeld`, planning hold |
| Runtime ID Service | Hard | Keys, stored names |
| World Clock (#8) | Hard | Daily step |
| Save/Load & Migration (#5) | Hard | Section |
| Content Data & Mod Loading (#4) | Hard | Faction → race map, knobs |
| #32, #33, #34, #49, Case File, Dossier, Debrief | Hard (reverse) | Queries and preview (Interactions table) |

Bidirectional check: #16, #17, #18, #28 and the Runtime ID Service already name
#30. #32, #33, #34 and #49 must list it (they are stubs). Sector Map rule 25
needs a wording amendment (Open Question 6).

## Tuning Knobs

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `SELF_START` | 100 | 0 – 200 (must make `1,000 − SELF_START` divisible by 6) | Starting self-blame |
| `SHIFT_PM` DIRECT / RECORD / TESTIMONY / FORGERY | 250 / 250 / 120 / 40 | 150 – 400 / 150 – 400 / 50 – 200 / 0 – 80 | How far a share persuades. Above about 330, one public reliable share can name a race |
| `CHAIN_ECHO_PM` | 500 | 0 – 1,000 | Repeat-chain weight |
| `ACCUSE_BASE` / `ACCUSE_PER_SUPPORT` / `ACCUSE_MAX` | 250 / 150 / 700 | 150–350 / 100–250 / 500–800 | Accusation strength from a bare charge, per shown support, and its cap |
| `NAME_PM` / `LEAD_PM` / `NAME_H` | 600 / 200 / 50 | 550 – 750 / 100 – 300 / 0 – 100 | When the public history names a race |
| `REACT_T1/T2/T3` | 20 / 80 / 200 | ±50 % | Reaction bands, also preview bands |
| `TARGET_PM` / `TARGET_CAP` | 1,000 / 300 | 500 – 1,500 / 150 – 500 | Long-run goodwill |
| `GF_MIN_SUPPORT` | 2 | 1 – 3 | Bar for good faith |
| `SUPPRESS_STANDING_BUY` / `_DAY` | 120 / 2 | 40 – 300 / 1 – 10 | Standing side of a lie |
| `EXPOSE_LIE` / `EXPOSE_ERROR` | 300 / 40 | 200 – 400 / 20 – 120 | The cost of being caught |
| `CONFIRM_BASE` / `CONFIRM_MAX` | 40 / 120 | 20 – 80 / 80 – 300 | Truth's payback |
| `LOG_KEEP` | 512 | 256 – 4,096 | Save size |

All knobs live in `assets/data/belief/`. None scales with difficulty.

## Visual/Audio Requirements

None of its own. A NAMING commit uses a distinct, weighty cue, and an accepted
EXPOSE uses a sharp one (Audio #52). Neither cue varies with the named race or
the faith judgement, so sound reveals nothing.

## Game Feel

- **Commit feels like signing.** A confirm step, no undo, and the preview stays
  on screen while you confirm.
- **Every move has a reason you can read.** Each standing change shows its
  history entry ("Orrowen: relieved, Halsk named").
- **A lie keeps ticking.** Seals show their daily cost and keeper, and the
  pre-battle panel shows seal coverage (Credits rule 9).

## UI Requirements

- **Blame bars:** each bar shows a fixed naming line at `NAME_PM`, and the
  leader is labelled Named, Leading or Contested by the D3 conditions.
- **Share picker:** held fragments in `acq_seq` order, with "Shared with" and
  "Sealed" lines. Target: one faction or Public.
- **Preview panel:** every rule 18 line. The Case File text panel (#49 stub)
  keeps the first-order preview and the exposure change at Tier 0.
- **Accuse dialog:** the candidate list, the same preview, and the faith line
  as plain counts ("Your held fragments: 2 independent contradictions").
- **Suppress dialog:** the keeper picker (non-Hostile factions, each with its
  band after the purchase), money and standing costs, coverage, and "Sealed
  fragments still count when your good faith is judged".
- **Public history view:** the verdict, a bar for `P` per race without numbers,
  and the public entries.
- 📌 **UX Flag — Faction Belief & Blame**: the share, accuse and suppress
  flows and the preview go into the Public History and Case File UX specs.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Hostile on naming, enmity lock, `preview`, magnitudes | `design/gdd/faction-reputation-and-standing.md` | Rules 4, 5, 6, 8, 11; AC-10, AC-15 | Rule dependency |
| Suppression money, grace, lapse | `design/gdd/credits-upkeep-and-sinks.md` | Rule 9 | Rule dependency |
| Held set, share card, planning hold, OQ 3 | `design/gdd/archive-fragments-and-evidence.md` | Rules 23–26; OQ 3 | Data dependency |
| Claims, contradiction, `contra`, classes | `design/gdd/truth-seeding-and-candidates.md` | Rules 1, 6, 7, 8, 15; G2, G6 | Formula dependency |
| Seed-independent start bands | `design/gdd/sector-map-and-travel.md` | Rule 25 | Rule dependency |
| Stored names with IDs | `design/gdd/runtime-id-service.md` | Rule 6 | Data dependency |
| "Every race suspects the others"; OQ 3 | `design/narrative/lore-bible.md` | §3.6; §9 OQ 3 | Lore |
| Lies, good faith, endings, preview | `design/gdd/game-concept.md` | Unique Hook; Pillar 2 | Vision |
| CD conditions for #32, #33, #34, #49 | `design/gdd/systems-index.md` | CD notes (MVP, VS) | Constraint |

## Acceptance Criteria

- **AC-01 (Logic; rule 2, D0)**: at C = 3 and C = 4, start beliefs match D0. All `P[c]` are equal (450 / 300). Two seeds with different makers give byte-identical belief sections.
- **AC-02 (Logic; D1)**: the D1 worked example gives 338 / 156 / 506, 338 / 506 / 156 and 76 / 462 / 462, with P = 338 / 484 / 484. Every share conserves `Σ b + doubt = 1,000`, which a property test checks over 10,000 random claims and states.
- **AC-03 (Logic; D2, D3)**: a bare accusation of Halsk from the start gives P = 587 / 394 / 394 and UNRESOLVED; with `s_pub` 1 from the start it gives P[H] 670 and NAMES(Halsk); at C = 4, `s_pub` 1 gives 580 (UNRESOLVED) and `s_pub` 2 gives 685 (NAMES).
- **AC-03b (Logic; rule 18)**: every preview lists drift-target directions, seals whose keeper would turn Hostile with their lapse day, a suppression's effect on faith, and the fixed confirmation line on any action that names.
- **AC-03c (Content; Open Questions, scapegoat)**: the text-only candidate's faction owns at least one port with care and trade on the MVP map; naming it loses that port in the preview.
- **AC-04 (Logic; D3)**: the hysteresis example holds at 560 / lead 180 and drops to UNRESOLVED at 540. A top tie is UNRESOLVED.
- **AC-05 (Logic; rules 10, D5)**: the D1 public share writes +120 to Halsk and −40 to Orrowen and Ithren, one entry each with a cause.
- **AC-06 (Logic; rule 11)**: entering NAMES(X) calls `set_hostile(X)` once, after the reactions, whether the cause is an accusation, a share or an exposure. A race named earlier stays locked when the verdict moves on.
- **AC-07 (Logic; rule 16)**: a fixture with the same claims and actions under each of the C makers gives identical beliefs, verdicts, standing writes, faith, targets and previews, and identical per-class fragment totals. The #30 module has no reference to the maker field (static check).
- **AC-08 (Logic; rule 18)**: `preview` then commit gives exactly the previewed belief bands, verdict and `Standing.preview` result. The preview has no numeric belief values, no confirmation line and no exposure outcome.
- **AC-09 (Logic; rule 18)**: the preview includes #33's escort line and #32's readout before and after for the verdict after the action.
- **AC-10 (Logic; D7)**: the D7 worked example gives BAD / GOOD / GOOD. Suppressing a held reliable contradiction of the named race turns GOOD_FAITH into BAD_FAITH.
- **AC-11 (Logic; rule 7)**: a suppression with a keeper below the price is refused. Neither money nor standing is charged.
- **AC-12 (Logic; rule 9)**: three standing-refused days in a row lapse a seal. Two days followed by a paid day do not. A money-side lapse from Credits unseals it and emits `suppression_lapsed`.
- **AC-13 (Logic; rule 15)**: `expose` on a non-contradicting, testimony, suppressed or held fragment, or under UNRESOLVED, returns its refusal and changes nothing. An accepted one applies D9 once per naming (SEVERE for a lie, SLIGHT for a good-faith or WORLD naming).
- **AC-14 (Logic; D10)**: four confirmations give 40 / 80 / 120 / 120 to each non-X faction, and none while UNRESOLVED.
- **AC-15 (Logic; edge cases)**: every refusal code (`ALREADY_SHARED`, `ALREADY_NAMED`, `PUBLIC_ALREADY`, `SEALED`, `NOT_CONTRADICTING`, `HELD`) fires on its fixture, and state is unchanged.
- **AC-16 (Logic; rule 22)**: a save round trip is byte-identical. The section is registered with version 1 and a ceiling.
- **AC-17 (Logic; rule 23)**: identical inputs give identical belief and standing results on all three presets.
- **AC-18 (Logic; rule 21)**: outcomes do not depend on tick size, game speed or the order of commits within a frame (commands are applied in commit order).
- **AC-19 (Integration; #28 rule 24)**: a grant attempted between preview and commit is deferred, and the commit's held snapshot equals the preview's.
- **AC-20 (UI)**: the share, accuse and suppress dialogs and the Case File preview have retained screenshots when their stories close.
- **AC-21 (Playtest; CD note)**: in Tier 0 playtests, every lie a tester tells shows a visible cost (seal upkeep or an exposure entry).

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **The text-only third candidate has a faction** (a standing row, reactions
  and a voice in public blame, but no playable ships at MVP), and it owns at
  least one port with care and trade on the MVP map, reached through the same
  band privileges, so naming it always loses something real (lore bible §1.1:
  absence is not guilt). Without one,
  naming it would cost nothing: a free scapegoat that would hollow out
  Pillar 2.
- **Suppressing unfound fragments** waits for the Vertical Slice; MVP seals
  held fragments only (rule on suppression).
- **Self-denial** (a faction resisting shares about its own race) is not at
  MVP; revisit at the first mystery playtest.
- **Credits D2 at yield 1,000 ‰** returns the base exactly (`(b × 1,000 +
  500) div 1,000 = b`), so the D8 example stands.
- **Sector Map rule 25** now reads "before the first committed share or
  naming" (amended with this GDD).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **`support` meaning.** Truth Seeding names `support` for the Case File but rule 8 defines only `contra`. D7 assumes support = distinct consistent groups, with testimony in and forgeries out. | Case File owner, game-designer | Case File GDD |
| 2 | **Lending thresholds.** Recommended: grant when `max_{c≠race(f)} b_f[c] ≥ 600`, refuse or withdraw when `P[race(f)] ≥ 600`. #33 owns them and case (d), the seed landing on the escort's race. | #33 | #33 GDD |
| 3 | **"In play" for the Reckoning.** Proposed: a reliable contradiction of the verdict is in play unless it is sealed and paid. Unfound ones count. | #34 | #34 design |
| 4 | **Command step.** Commits happen in a planning hold. Confirm that a zero-duration simulation step applies them (Runtime ID rule 3 requires one for any issue). | World Clock owner | ADR on commands |
| 5 | **Releasing the enmity lock** (Standing OQ 1). Nothing releases it at MVP. | game-designer | 1.0 |
