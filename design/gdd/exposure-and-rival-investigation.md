# Exposure & Rival Investigation

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (Faction Belief rule 15/AC-13 accept held copies in known(r); naming-to-probe edge and pace target before the Tier 0 playtest; seal preview explains the rival's silence)
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — a public lie can be exposed only by real evidence a rival finds, never by a timer alone); Pillar 4 (Plan in the Open — the rival's progress and target are visible)

## Summary

One truth-neutral rival investigation works the campaign clock: it draws one specific unfound fragment uniformly (blind to class, verdict and maker), earns visible leads on a pace set by `investigator_pace_permille` (10 days per find at Standard, never stopping), and then copies the fragment without taking it. Exposure fires only if that fragment reliably contradicts the current public verdict, never on a timer alone, so the truth holds and a lie can fall. The readout shows held contradictions, leads and the target's site, never its content, and the player can race the rival, seal, or change the verdict.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Deterministic RNG & Seed Streams, World Clock, Archive Fragments & Evidence, Faction Belief & Blame, Runtime ID Service`

## Overview

Exposure & Rival Investigation runs the world's investigators. At MVP there is
one rival, the Inquest (a placeholder name). It works on the World Clock
whether or not the player looks for evidence. The rival always targets **one
specific unfound seeded fragment**. It reaches that fragment through a fixed
number of visible **leads**, then copies what it finds. If the copy reliably
contradicts the current public verdict, #32 calls Faction Belief's
`expose(φ)`. #30 then publishes the fragment and charges the exposure penalty:
SEVERE for a lie, SLIGHT for a good-faith error. If the copy does not
contradict the verdict, nothing public happens. The rival keeps the copy and
re-reads it against any later naming. A timer alone never exposes anything.
The target is drawn uniformly from the unfound fragments. It never depends on
the maker, the verdict or the fragment's class. The **exposure readout** shows
three things at all times: the reliable contradictions the player holds (open
and sealed), the rival's leads, and the rival's target site. It never shows
fragment content or which candidate is true. The player's counterplay is
plain: reach the target first, seal what they hold, or change the verdict.

## Player Fantasy

You are not the only one asking who built the machines. Somewhere on the map
another investigator is three leads from a derelict you have not searched. You
can see the marker and count the days. If your public story is true, nothing it
finds can hurt you. If you lied, it is digging toward the thing that undoes
you, and you know exactly how long you have. Exposure never comes out of
nowhere. The readout said "rising", the rest preview said "find due on day
16.7", and you chose to rest anyway. When the cue lands, it is your own
choice coming due, and the game shows you its whole chain.

## Detailed Design

### Core Rules

**A. The rival**

1. **One rival at MVP.** Content defines investigators of kind
   `investigator`. MVP ships exactly one, `rival.inquest`. It belongs to no
   faction and no candidate race, so a verdict can never name it and it has
   no stake in any race. It gets a Runtime ID of kind `investigator` (Runtime
   ID Service). Its display name is narrative-director's (Open Question 4).
2. **Truth-neutral by construction.** #32 never reads the maker. It reads
   fragments through #28 (`unfound_fragments()`, `is_unfound()`, the host
   site) and claims only through #30 (`verdict()`, `contradicts_public(φ)`,
   `held_reliable_contradictions()`, `suppressed_set()`). The target, the pace,
   the lead times and the readout are identical whoever the maker is, given
   the same player actions (rule 22).
3. **Visible on the map as a site marker.** The rival is shown as a marker on
   its target's host site (a machine node, POI or port, #28 rule 2 `host`),
   with lead pips "2 / 5". At MVP no rival ship moves on the map. A moving
   rival fleet is Vertical Slice (Open Question 11).
4. **The true maker's agents** (concept) are not in the MVP. When they are
   added, they must use rules 5–12 unchanged. That means the same pool, the
   same uniform draw, the same pace and the same readout, with no race
   attribution. This answers Archive Fragments OQ 2. A maker's agent that chose
   targets differently, or carried its race on the marker, would leak G6.

**B. The investigation**

5. **Target pool.** `pool = unfound_fragments() \ known(r)`, in ascending
   Runtime ID. `unfound_fragments()` holds PLACED and RESERVED fragments (#28
   rule 25), so a RESERVED fragment can be a target. `known(r)` is the set
   of fragments this rival has already found. The pool is **class-blind,
   verdict-blind and maker-blind**. It never filters by provenance class,
   claim or contradiction. Filtering by class would show which slot holds a
   reliable fragment (#28 rule 30). Filtering by contradiction would let the
   rival's idleness reveal that the verdict is true.
6. **Target choice.** The rival draws one uniform index into the pool from
   its own campaign stream, `base:exposure.target` (D5; Open Question 3). It
   makes exactly one draw per targeting, at the targeting instant. If the
   pool is empty, the rival goes IDLE (rule 12).
7. **Leads.** A target takes `LEADS_PER_FIND` (5) leads. On targeting, #32
   registers the next lead as a World Clock event at
   `due_s = t + lead_s` (D2), priority 200, `visible = true`, kind
   `investigator_lead`. Each lead event adds 1 to `leads` and registers the
   next one. The lead that reaches `LEADS_PER_FIND` is the **find**, kind
   `investigator_find`. The rival's pace comes only from
   `investigator_pace_permille`, never from distance, class or verdict.
8. **Pace.** `investigator_pace_permille` is accepted here as a Tier C † key
   with presets 600 / 1000 / 1250 and range 500 – 1500 (Gameplay Settings
   rule 11 and its preset table). #32 clamps it to at least
   `INVESTIGATOR_PACE_FLOOR` (500) before use (D1). Investigators slow down
   but never stop. Rule 9 of Gameplay Settings binds here: difficulty changes
   only how fast leads come. It never changes the readout, the pool, the
   find test or the penalty. A lead already registered keeps its `due_s`
   if the key changes. The next lead uses the new pace.
9. **The find.** At the find, #32 first checks `is_unfound(target)`. If the
   target is now HELD, it applies rule 10 instead. Otherwise:
   - the rival **copies** the fragment: `target` joins `known(r)`. The
     fragment stays PLACED or RESERVED in #28 and the player can still claim
     it. This answers Archive Fragments OQ 1: the rival copies, it does not
     take;
   - if `verdict()` is NAMES(X) and `contradicts_public(target)` is true,
     #32 calls `expose(target)` once. #30 decides. It accepts only if the
     fragment is reliable, contradicts X and is not suppressed (#30 rule 15),
     so an exposure **never fires on a timer alone**;
   - if the verdict is UNRESOLVED, or the claim does not contradict X, or #30
     refuses, there is no public effect at MVP. A `RIVAL_FIND` notice names
     the site only ("The Inquest finished at the Drowned Archive"), never
     the content (Open Question 2);
   - in the same instant, the rival retargets (rule 6) with `leads = 0`.
10. **The player gets there first.** On `FragmentHeld` for the current
    target, #32 cancels the pending lead event. It keeps
    `leads_kept = leads × RETARGET_KEEP_PM div 1000` (D4), draws a new
    target, and registers the next lead at `t + lead_s`. The fragment does
    not join `known(r)`, so the rival never learned it. This is the main
    counterplay: claim the target, read it yourself, and set the rival back.
11. **Re-reading old finds.** A copy that did not expose at the find is not
    wasted. #32 registers one `investigator_retest` event at
    `t + RETEST_DELAY_S` (1 day), priority 200, `visible = true`, when:
    - the verdict enters a new NAMES(X) (any cause) and `known_open(r) ≥ 1`;
    - or `suppression_lapsed(φ)` arrives for a `φ ∈ known(r)` while the
      verdict NAMES(X).

    At most one retest is pending per rival. A second trigger moves nothing.
    When it fires, if the verdict NAMES(X), #32 walks `known(r)` in ascending
    ID. It skips fragments that are already EXPOSED or that
    `contradicts_public` rejects. It calls `expose` on the first one left,
    and on that one only. Then it stops, whether the call is accepted or
    refused. This closes the "lie after the rival has found everything"
    exploit. The fragment was still a targeted unfound fragment when the
    rival found it, and it must still reliably contradict the current
    verdict. **This needs a #30 amendment** (see Dependencies): `expose` must
    accept a HELD fragment that is in `known(r)` and is not suppressed and
    not shared. Without the amendment, a player could make every rival find
    safe by claiming its copy. Open Question 1.
12. **IDLE.** When the pool is empty, the rival is IDLE. It registers no lead
    events, and its retests (rule 11) still run. If a later event makes the
    pool non-empty again, the rival retargets at that instant. At MVP no
    event adds a fragment, so IDLE is final, apart from retests.
13. **Start.** The rival makes its first targeting at
    `t = RIVAL_START_S` (0) after seeding, in the campaign step that follows
    Truth Seeding rule 11.

**C. Exposure and its costs** (owned by #30, called only from here)

14. **Only #32 calls `expose(φ)`** (#30 rule 15). #32 calls it from exactly
    two handlers: the find (rule 9) and the retest (rule 11). It is never
    called from a player command, a preview or a load.
15. **Penalties are #30's.** On the first accepted exposure of a naming,
    every non-locked faction whose race is not X gets `penalize(EXPOSE_LIE)`
    (SEVERE 300) for a BAD_FAITH naming, or `penalize(EXPOSE_ERROR)` (SLIGHT
    40) for a GOOD_FAITH or WORLD naming. The fragment's D1 shift then
    applies as a PUBLIC share (#30 D9). #32 adds no penalty of its own and
    scales nothing.
16. **Truth asymmetry is intended.** "Contradicts" is judged on the claim
    against the verdict, never on the truth. But reliable fragments never
    contradict the truth (Truth Seeding G1), so a verdict that names the true
    maker can never be exposed. A false verdict can be exposed once the rival
    finds one of its reliable contradictions. The truth holds and the lie
    does not. The rival's choices and pace are the same in both cases.
17. **No deadline.** Exposure is never a loss condition, and #32 owns no
    campaign deadline. A defeat's day cost (one skip, at most `DEFEAT_MAX_S`)
    can add at most `ceil(DEFEAT_MAX_S ÷ lead_s)` leads (D6). That is a
    visible cost, never a broken run. This answers After-Action Debrief OQ 6
    for #32.

**D. The readout**

18. **`exposure_readout(verdict)`** returns, for the verdict passed in:
    - `held_open`, `held_sealed`: the number of held reliable fragments whose
      claim contradicts the named race, split by seal, from #30's
      `held_reliable_contradictions()` and `suppressed_set()`;
    - per rival: display name, target site and system label, `leads` of
      `LEADS_PER_FIND`, the next lead's `due_s`, the projected find `due_s`
      (D3), `known_open`, and any pending retest's `due_s`;
    - the `level`: NONE, LOW, RISING or HIGH (D7).

    Under UNRESOLVED, `level` is NONE ("Nothing is named; nothing can be
    exposed"). The rival lines are still shown.
19. **The readout never shows** a target's class, claim, axis or chain. It
    never says whether a target or a known copy would contradict anything,
    and it never shows any maker or truth field. The site is shown because
    location carries nothing about the maker (Truth Seeding G6). Difficulty
    never changes the readout (Gameplay Settings rule 9).
20. **Where it appears.** The readout appears in four places:
    - the Case File header (Case File rule 24), for the current verdict;
    - the share and accusation preview, before and after, for the verdict
      after the action (#30 rule 18). Rival progress shows as unchanged,
      because a commit takes no time. When the action would schedule a
      retest, the preview adds the fixed line "The Inquest will re-read its
      k findings against this verdict in 1 day." It is the same line whatever
      the findings hold;
    - the sector map marker (rule 3);
    - the rest and search previews (rule 21).
21. **Steps due inside a window.** `steps_due(t0, t1)` lists, in
    `(due_s, priority, seq)` order:
    - every registered visible #32 event with `t0 < due_s ≤ t1`;
    - the cadence after the current find ("then a new target, a lead every
      2.00 days"), because the time is known and the target is not.

    Ports, Rest & Care rule 13 ("Investigator progress due inside this rest")
    and Points of Interest rule 14 ("visible investigations only") read this
    function. It never says what a find will do.

**E. Clock, determinism and save**

22. **Determinism.** All maths is integer, with `div` truncating on
    non-negative operands. Handlers act at `t_event = due_s` (World Clock
    rule 7). The only randomness is one draw on `base:exposure.target` per
    targeting. The number of draws depends only on finds and player claims,
    never on whether an exposure was accepted. Rivals and pools are walked
    in ascending Runtime ID.
23. **Nothing fires in battle.** Accepted (World Clock rule 9, OQ 1). Leads
    that fall due during a battle wait, and fire in order in the catch-up
    pass after the Debrief closes (World Clock rule 10). An exposure can
    therefore land just after a battle. It is shown with a notice, never
    inside the battle.
24. **Skip interrupts** (World Clock rule 14, OQ 9):
    - `investigator_find` and `investigator_retest` are `interrupts_skip`.
      A find always interrupts, whether or not it exposes, so the
      interruption itself tells the player nothing;
    - `investigator_lead` clears the flag. Stated reason: a lead changes
      progress only, never exposure state, the case or hostility, and every
      lead inside the window was already listed by the rest or search preview
      (rule 21).
25. **Save section `base:exposure`, version 1.** Per rival it saves:
    `{runtime_id, state, target_id, leads, lead_seq, retest_seq, known (IDs,
    ascending)}`. The stream state belongs to the RNG service. Nothing here
    copies claims or classes. Every save round trip is byte-identical. On
    load, a `target_id` that is no longer unfound is treated as rule 10.

### States and Transitions

| Entity | State | Entered when | Leaves to |
|---|---|---|---|
| Rival | DORMANT | New game, before `RIVAL_START_S` | INVESTIGATING (first targeting), IDLE (empty pool) |
| Rival | INVESTIGATING(φ, leads) | Targeting (rules 6, 9, 10) | INVESTIGATING(φ′) after a find or a pre-emption; IDLE |
| Rival | IDLE | Pool empty at targeting | INVESTIGATING (pool grows; not possible at MVP) |
| Fragment (#32 view) | TARGETED | Drawn | KNOWN (find); untargeted (player claim, rule 10) |
| Fragment (#32 view) | KNOWN | Find (copy) | EXPOSED (#30 accepts, at the find or a retest) |
| Fragment | EXPOSED | `expose` accepted (#30 state) | — |
| Retest | PENDING | Rule 11 trigger | fired (at most one `expose` call) |
| Readout level | NONE / LOW / RISING / HIGH | Recomputed on demand (D7) | — (derived, not stored) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Archive Fragments & Evidence (#28) | #28 → #32 | `unfound_fragments()` (PLACED and RESERVED, ascending ID), `is_unfound(id)`, the host site label, `FragmentHeld`. #32 never moves a fragment's state |
| Faction Belief & Blame (#30) | both | #32 reads `verdict()`, `contradicts_public(φ)`, `held_reliable_contradictions()`, `suppressed_set()`, `suppression_lapsed(φ)`, and the naming-entered signal. #32 calls `expose(φ)` (rules 9, 11). #30's preview calls `exposure_readout(verdict_after)` |
| Case File & Deduction | #32 → Case File | `exposure_readout(verdict())` for the header line (rule 24) |
| World Clock | #32 → clock | Registers `investigator_lead`, `investigator_find` and `investigator_retest` at priority 200, `visible`; accepts "nothing fires in battle"; interrupt flags per rule 24 |
| Gameplay Settings & Modifiers (#7) | #7 → #32 | `investigator_pace_permille` † (600 / 1000 / 1250; 500 – 1500); `INVESTIGATOR_PACE_FLOOR` 500; rule 9 limits |
| Deterministic RNG & Seed Streams | RNG → #32 | Stream `base:exposure.target`, one uniform draw per targeting |
| Runtime ID Service | ID → #32 | Investigator IDs (kind `investigator`); fragment IDs |
| Ports, Rest & Care (#27), Points of Interest (#29) | #32 → each | `steps_due(t0, t1)` for the rest and search previews |
| Sector Map & Travel (#26) | #32 → #26 | Target marker and lead pips on the host site |
| Reckoning & Endings (#34) | #32 → #34 | Reads `known(r)` and the readout. Read only |
| Public History screen (#49) | #32 → #49 | `exposure_readout` and the EXPOSE entries (via #30) |
| Audio (#52), Telemetry (#54) | #32 → each | Signals `investigator_lead`, `investigator_found{exposed}`, `investigator_retargeted`, `investigator_idle` |

## Formulas

### D1. Effective pace

`pace_eff = max(investigator_pace_permille, INVESTIGATOR_PACE_FLOOR)`

| Variable | Type | Range | Description |
|---|---|---|---|
| investigator_pace_permille | int ‰ | 500 – 1,500 (presets 600 / 1,000 / 1,250) | Tier C † key, frozen in the `ModifierSet` |
| INVESTIGATOR_PACE_FLOOR | int ‰ | 250 – 1,000; **500** | Gameplay Settings' constant |
| pace_eff | int ‰ | 500 – 1,500 | Pace used by D2 |

**Output:** bounded in [500, 1,500]. The clamp is a safeguard, because #7
already enforces the floor. **Example:** an override of 400 gives 500.

### D2. Lead interval

`lead_s = max(LEAD_MIN_S, (LEAD_BASE_S × 1,000) div pace_eff)`

| Variable | Type | Range | Description |
|---|---|---|---|
| LEAD_BASE_S | int game s | 86,400 – 518,400; **172,800** (2 days) | Lead interval at pace 1,000 |
| LEAD_MIN_S | int game s | 21,600 – 86,400; **43,200** (half a day) | Safeguard against a modded pace |
| lead_s | int game s | 115,200 – 345,600 at the defaults | Game seconds (`clock_s` units, 86,400 per day) per lead |

**Output:** bounded. The minimum is 172,800,000 div 1,500 = **115,200** (1.33
days, at the highest pace). The maximum is 172,800,000 div 500 = **345,600** (4
days, at the floor). There is no division by zero, because `pace_eff ≥ 500`.

### D3. Time to a find

`find_s = LEADS_PER_FIND × lead_s`. After a pre-emption it is
`(LEADS_PER_FIND − leads_kept) × lead_s`.

| Variable | Type | Range | Description |
|---|---|---|---|
| LEADS_PER_FIND | int | 3 – 8; **5** | Leads per target |
| find_s | int game s | 576,000 – 1,728,000 at the defaults | From a fresh target to the find |

**Worked example (checked):**

| Preset | pace_eff | lead_s | find_s | Days (÷ 86,400) |
|---|---|---|---|---|
| Chronicler | 600 | 172,800,000 div 600 = 288,000 | 1,440,000 | 16.67 |
| Standard | 1,000 | 172,800 | 864,000 | 10.00 |
| Admiral | 1,250 | 172,800,000 div 1,250 = 138,240 | 691,200 | 8.00 |
| Floor | 500 | 345,600 | 1,728,000 | 20.00 |
| Max | 1,500 | 115,200 | 576,000 | 6.67 |

With the 6 MVP slots (#28) and no player claims, the rival at Standard would
know every fragment by day 60. A player who claims fragments shrinks the pool
and delays that (Open Question 5).

### D4. Pre-emption carry

`leads_kept = leads × RETARGET_KEEP_PM div 1,000`

| Variable | Type | Range | Description |
|---|---|---|---|
| leads | int | 0 – LEADS_PER_FIND − 1 | Leads on the claimed target |
| RETARGET_KEEP_PM | int ‰ | 0 – 1,000; **400** | Share of progress the rival keeps |
| leads_kept | int | 0 – 3 at the defaults | Leads on the new target |

**Output:** bounded in [0, LEADS_PER_FIND − 1], so a pre-emption can never
cause an instant find. **Examples:** 4 × 400 div 1,000 = **1**; 2 × 400 div
1,000 = **0**.

### D5. Target draw

`index = uniform_int(base:exposure.target, 0, |pool| − 1)`. The target is
`pool[index]`, with the pool in ascending Runtime ID.

| Variable | Type | Range | Description |
|---|---|---|---|
| pool | list of IDs | 0 – total fragments | Rule 5 |
| index | int | 0 – |pool| − 1 | Uniform; no weights |

**Output:** if `|pool| = 0`, no draw is made and the rival goes IDLE. The
draw uses no weights at all, so the 4.7.2 rule that `rand_weighted` forbids
negative weights does not apply. **Example:** pool = {f2, f4, f6}, index 1 →
**f4**.

### D6. Leads per defeat

`max_leads_per_defeat = ceil(DEFEAT_MAX_S ÷ lead_s) = (DEFEAT_MAX_S + lead_s −
1) div lead_s`

**Output:** an upper bound for the Debrief and World Clock check (rule 17).
**Example** at Standard (`lead_s` 172,800): the largest legal defeat skip at
`defeat_cost_permille` 1,000 is 604,800 (7 days; Debrief D5), giving (604,800 +
172,799) div 172,800 = **4** leads; the hard ceiling `DEFEAT_MAX_S` 1,209,600
(14 days, only at `defeat_cost_permille` 2,000) gives **7** leads, enough for
one find plus two leads on the next target.

### D7. Readout level

`S = 2 × min(H, 2) + (3 × leads) div LEADS_PER_FIND + min(known_open, 1)`

`level` = NONE if the verdict is UNRESOLVED. Otherwise it is LOW if
`S ≤ LOW_MAX` (1), RISING if `S ≤ RISING_MAX` (3), and HIGH otherwise.
`leads` is the highest across rivals.

| Variable | Type | Range | Description |
|---|---|---|---|
| H | int | 0 – groups held | Distinct groups among held open and sealed reliable fragments contradicting the named race |
| leads | int | 0 – 4 | Current leads (a find resets to 0) |
| known_open | int | 0 – fragments | Fragments in `known(r)` that are neither EXPOSED nor suppressed |
| S | int | 0 – 7 | Score |
| LOW_MAX / RISING_MAX | int | 0 – 2 / 2 – 5; **1 / 3** | Band edges |

**Output:** bounded in [0, 7]. Every input is either held-only evidence (H)
or a quantity that does not depend on the truth (leads, `known_open`). So the
level is truth-blind for the player's knowledge. Without a held
contradiction (H = 0), S ≤ 3, so the readout can say RISING but never HIGH.
**Examples:** H = 2, leads 2, `known_open` 0 gives 4 + 1 + 0 = **5, HIGH**.
H = 0, leads 4, `known_open` 1 gives 0 + 2 + 1 = **3, RISING**.

### D8. Worked campaign (Standard, checked)

The fixture is Truth Seeding's: f1 DIRECT g1 contradicts H and I; f3 DIRECT g3
contradicts H. The derelict D1 holds a RECORD fragment, fD, that contradicts H.

- Day 0: the pool is the 6 slots. The draw picks fD. Leads are due at
  172,800, 345,600, 518,400, 691,200 and 864,000 (days 2, 4, 6, 8, 10).
- Day 5: the player, holding f1 and f3, accuses Halsk, and the verdict
  NAMES(Halsk). D7 judges BAD_FAITH (contra_held = 2). The preview's readout
  after the action: open 2, sealed 0, leads 2 of 5 → S = 4 + 1 + 0 = 5,
  HIGH.
- Day 7: the player rests for 4 days at a port. The preview lists leads at
  days 8 and 10, with "find at the Derelict D1 on day 10.00", and the cadence
  after. The player rests.
- Day 10 (864,000): the find interrupts the rest. fD is still unfound, a
  RECORD whose claim contradicts Halsk. `expose(fD)` is accepted. Every
  non-locked non-Halsk faction takes SEVERE 300, then fD's D1 shift applies
  as a PUBLIC share. The rival retargets at 864,000, and its next lead is due
  at 1,036,800.
- Counterfactual: on day 9 the player claims fD first. At that point leads =
  4, so leads_kept = 1. The new target's find falls at 777,600 + 4 × 172,800 =
  1,468,800 (day 17), and the lie has bought 7 days.

## Edge Cases

- **If the player claims the target in the same instant the find is due**:
  rival events fire at priority 200, before player completions at 300 (World
  Clock rule 6). A claim at an earlier tick has already run rule 10. A grant
  deferred by a planning hold lands after the find. In every order, the find
  handler's `is_unfound` check decides.
- **If the target is RESERVED** (its node broke in a loss): it stays a valid
  target (#28 rule 25), and the player's arrival claim pre-empts it.
- **If the rival finds a forgery or testimony**: `contradicts_public` may be
  true, but #30 refuses with `NOT_CONTRADICTING`, because the fragment is not
  reliable. It joins `known(r)`, and a retest cannot expose it either.
- **If the verdict is UNRESOLVED at the find**: no call to `expose`. The copy
  joins `known(r)`, and a later naming schedules a retest.
- **If the player shares a fragment in `known(r)` publicly before a retest**:
  #30 refuses the exposure (already public). The retest stops after that
  call (rule 11).
- **If the player seals a held fragment in `known(r)`**: #30 refuses
  `SUPPRESSED`, and `known_open` falls. The seal preview says so in the
  fiction: "Sealing this also buys the Inquest's silence on its copy"
  (wording owned by narrative-director, Open Question 4).
- **Naming to probe**: a retest that finds nothing is accepted as evidence for
  the verdict. It costs the naming (X turns Hostile) and its exposure risk,
  and it is never cheaper than a Case File check; the pace target in Open
  Question 5 keeps the rival from knowing every fragment before the player
  has claimed half of them. If the seal lapses, a retest is
  scheduled (rule 11).
- **If an exposure moves the verdict into NAMES(Y)** (WORLD naming): the
  naming-entered signal schedules a retest for Y if `known_open ≥ 1`. Each
  retest makes at most one call, so exposures cannot chain within one
  instant.
- **If the verdict changes twice before a retest fires**: the one pending
  retest tests the verdict current at its `due_s`.
- **If a retest fires with the verdict UNRESOLVED**: it does nothing.
- **If a battle spans a find**: the find waits and fires in the post-battle
  catch-up, after the Debrief closes (rule 23).
- **If the pace key changes mid-campaign**: the pending lead keeps its
  `due_s`, and the next lead uses the new `lead_s`. The change is logged by
  #7 rule 8.
- **If every fragment is held or known**: the rival goes IDLE. The readout
  says "The Inquest has no leads left". Retests still run.
- **If a save is loaded with a `target_id` no longer unfound** (mod or
  migration): rule 10 applies at load time with `leads_kept` per D4. The
  draw happens in load order before the first tick.
- **If a fragment is removed by a content change**: #28 rule 28 keeps placed
  fragments, so this cannot happen in a campaign. A missing ID in `known` is
  dropped with the log entry `EXPOSURE_UNKNOWN_FRAGMENT`.
- **Degenerate: claim every target first.** This is allowed and costs
  travel. Each pre-emption keeps 40 % of the leads, and the player gains the
  evidence. The lie still faces retests on every copy the rival made before.
- **Degenerate: lie once the rival has found everything.** Closed by rule 11,
  given the #30 amendment.

## Dependencies

| System | Kind | Why |
|---|---|---|
| Archive Fragments & Evidence (#28) | Hard | Pool, `is_unfound`, host site, `FragmentHeld` |
| Faction Belief & Blame (#30) | Hard (both) | Verdict, claim tests, held contradictions, seals, lapses; `expose` |
| World Clock | Hard | Event queue, priority 200, battle rule, skips |
| Deterministic RNG & Seed Streams | Hard | `base:exposure.target` |
| Runtime ID Service | Hard | Investigator and fragment IDs |
| Gameplay Settings & Modifiers (#7) | Hard | `investigator_pace_permille`, floor |
| Case File, #27, #29, #26, #34, #49, #52, #54 | Hard (reverse) | Read the readout, `steps_due` or signals |

**Amendments other GDDs need** (bidirectional):

- `faction-belief-and-blame.md`:
  - in Edge Cases "expose on a fragment the player holds", add: "unless it is
    in #32's `known(r)` and is neither suppressed nor shared (the rival found
    it while unfound)";
  - in the Interactions row for #32, rename `preview_readout(verdict_after)`
    to `exposure_readout(verdict)`, and add the naming-entered signal;
  - in rule 18, add the retest line.
- `archive-fragments-and-evidence.md` OQ 1 and OQ 2: mark them resolved by
  #32 rules 9 and 4. Expose a host-site label accessor if one is not already
  present.
- `world-clock.md`:
  - OQ 1: resolved by #32 rule 23;
  - OQ 9: resolved by #32 rule 24.
- `gameplay-settings-and-modifiers.md`: the † on `investigator_pace_permille`
  is accepted by #32 rule 8, which satisfies AC-17 for #32.
- `ports-rest-and-care.md` rule 13 and `points-of-interest.md` rule 14: read
  `steps_due(t0, t1)`.
- `after-action-debrief.md` OQ 6: #32 sets no deadline (rule 17, D6).
- `case-file-and-deduction.md` OQ 6: resolved by #32 rules 18–20.

## Tuning Knobs

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `LEAD_BASE_S` | 172,800 (2 days) | 86,400 – 518,400 | Rival speed at pace 1,000 | Lies exposed before players can react | Lies are safe for most of a run |
| `LEADS_PER_FIND` | 5 | 3 – 8 | Readout granularity and warning time | Few warnings; finds feel sudden | Pips crawl; no tension |
| `RETARGET_KEEP_PM` | 400 | 0 – 1,000 | Value of reaching the target first | Racing is dominant and can stall the rival | Racing is pointless |
| `RETEST_DELAY_S` | 86,400 (1 day) | 0 – 259,200 | Time between a naming and the re-read | Feels like an instant trap | Lets a player act before the re-read |
| `RIVAL_START_S` | 0 | 0 – 1,036,800 (12 days) | Opening pressure | — | Early lies go unchecked |
| `LOW_MAX` / `RISING_MAX` | 1 / 3 | 0 – 2 / 2 – 5 | Readout bands | Always HIGH | Never HIGH |
| `LEAD_MIN_S` | 43,200 | 21,600 – 86,400 | Safeguard only | — | Caps the fastest pace |
| `investigator_pace_permille` † | 1,000 | 500 – 1,500 (#7) | Difficulty | Clamped at 500 | — |

No knob changes the find test, the pool or the penalties. Penalty knobs
(`EXPOSE_LIE`, `EXPOSE_ERROR`) are #30's.

## Visual/Audio Requirements

- The map marker is a neutral investigator glyph with lead pips. It never
  takes a race's colour.
- A lead gives a soft tick. A find gives one neutral "finished" cue whether
  or not it exposes. If #30 accepts the exposure, its sharp EXPOSE cue
  follows (#30, Audio #52). The find cue never varies with class or outcome.
- The readout level uses shape and text as well as colour (LOW / RISING /
  HIGH), for accessibility.

## Game Feel

The pressure should be slow and legible, like a fuse. Every lead is
announced, and every find is due on a known day. The player should feel
cornered, never ambushed. A find that changes nothing should feel like
relief, not like a non-event. The notice names the site, and the player can
go and read the fragment.

## UI Requirements

- **Case File header** (Case File rule 24): "Held reliable contradictions of
  Halsk: open 2, sealed 0. The Inquest: 2 of 5 leads at the Derelict D1, next
  day 6.00. Exposure: HIGH." Under UNRESOLVED it reads "Nothing is named."
- **Share and accuse preview**: the readout before and after (#30 rule 18),
  plus the retest line when relevant.
- **Rest and search previews**: "Investigator progress due inside this rest:"
  followed by each `steps_due` entry, then the cadence line.
- **Notices** (priority 900):
  - "The Inquest picked up a lead (3 / 5)";
  - "The Inquest finished at ⟨site⟩";
  - "The Inquest has a new target: ⟨site⟩";
  - "The Inquest has no leads left".
- No screen ever shows a target's class or content. No screen shows fragment
  IDs.

## Cross-References

| Topic | Document | Section | Kind |
|---|---|---|---|
| CD condition for #32 | `design/gdd/systems-index.md` | CD Note (MVP) | Constraint |
| Tier 0 stub depth | `design/gdd/systems-index.md` | Producer Note | Scope |
| `expose`, D9 penalties, preview | `design/gdd/faction-belief-and-blame.md` | Rules 13, 15, 17, 18; D7, D9 | Rule dependency |
| Unfound set, copy rule | `design/gdd/archive-fragments-and-evidence.md` | Rule 25, rule 30, OQ 1–2 | Rule dependency |
| Readout display | `design/gdd/case-file-and-deduction.md` | Rule 24, OQ 6 | Interface |
| Scheduler, battle, skips | `design/gdd/world-clock.md` | Rules 6–10, 14; OQ 1, 9 | Rule dependency |
| Pace key and floor | `design/gdd/gameplay-settings-and-modifiers.md` | Rules 9, 11; presets | Constraint |
| G1, G6 | `design/gdd/truth-seeding-and-candidates.md` | Rules 7–9 | Constraint |
| Rest and search previews | `ports-rest-and-care.md` rule 13; `points-of-interest.md` rule 14 | — | Interface |
| No deadline | `design/gdd/after-action-debrief.md` | OQ 6 | Constraint |
| Rival concept | `design/gdd/game-concept.md` | "Who exposes a lie" | Vision |

## Acceptance Criteria

- **AC-01 (Logic; rules 5, 6)**: across 10,000 seeds per maker, the first
  target's distribution over slots and over classes is the same for every
  maker (within ± 1 %). It is also unchanged by the verdict.
- **AC-02 (Logic; rule 5)**: the pool never contains a HELD or `known`
  fragment, and does contain RESERVED ones.
- **AC-03 (Logic; D2, D3)**: at paces 600, 1,000, 1,250, 500 and 1,500,
  `lead_s` is 288,000, 172,800, 138,240, 345,600 and 115,200, and finds fall at
  1,440,000, 864,000, 691,200, 1,728,000 and 576,000 game seconds (16.67, 10,
  8, 20 and 6.67 days). A pace of 400 behaves as 500.
- **AC-04 (Logic; rule 9, CD condition)**: a find under UNRESOLVED, or of a
  fragment that does not contradict the verdict, or of a forgery, leaves
  every belief, standing and the record unchanged, apart from the
  `RIVAL_FIND` notice.
- **AC-05 (Logic; rule 9)**: a find of an unfound RECORD fragment
  contradicting NAMES(X) calls `expose` once. For BAD_FAITH the result is
  SEVERE 300 per eligible faction; for GOOD_FAITH it is SLIGHT 40 (#30 D9).
- **AC-06 (Logic; rule 9)**: after a find, the fragment is still PLACED or
  RESERVED in #28, and the player can claim it.
- **AC-07 (Logic; rule 10, D4)**: claiming the target at 4 leads cancels the
  pending lead and retargets with 1 lead. The claimed fragment is not in
  `known`.
- **AC-08 (Logic; rule 11)**: a naming with `known_open ≥ 1` schedules
  exactly one retest at +86,400 (1 day). The retest makes at most one `expose` call,
  on the lowest eligible ID.
- **AC-09 (Logic; rule 11, needs #30 amendment)**: a held, unsealed,
  unshared fragment in `known` is exposed by a retest. A sealed one is
  refused.
- **AC-10 (Logic; rule 14)**: no code path other than the find and retest
  handlers calls `expose` (static check plus test).
- **AC-11 (Logic; rule 22)**: with the same seed and the same player orders,
  two runs with different makers produce identical targets, lead times and
  draw counts until the first accepted exposure.
- **AC-12 (Logic; rule 23)**: a lead due during a battle fires only in the
  post-battle catch-up, in `(due_s, priority, seq)` order.
- **AC-13 (Logic; rule 24)**: a find interrupts a rest whether or not it
  exposes; a lead does not.
- **AC-14 (Logic; rule 21)**: `steps_due(t0, t1)` returns exactly the
  visible #32 events in the window, plus the cadence line, and contains no
  class or claim field (schema check).
- **AC-15 (Logic; D7)**: the two D7 examples return HIGH (S = 5) and RISING
  (S = 3). With H = 0, the level is never HIGH. Under UNRESOLVED it is NONE.
- **AC-16 (Logic; rules 18, 19)**: the readout schema has no class, claim,
  axis, chain, maker or "would expose" field.
- **AC-17 (Logic; rule 20)**: #30's preview shows the readout before and
  after for the verdict after the action. The leads are equal in both, and
  commit then preview gives the same readout.
- **AC-18 (Logic; rule 8, Settings rule 9)**: changing presets changes only
  `lead_s`. The pool, the find test, D7 and the penalties are identical.
- **AC-19 (Logic; rule 25)**: a save and load round trip of
  `base:exposure` is byte-identical, and resuming gives the same next
  target and the same `due_s`.
- **AC-20 (Logic; rule 12)**: with every fragment held or known, the rival
  is IDLE, registers no leads, and still runs retests.
- **AC-21 (Logic; D6, rule 17)**: no #32 state ends the run. A maximum
  defeat skip adds at most D6's leads.
- **AC-22 (UI; rule 20)**: the Case File header, the map marker and the rest
  preview each show the readout's site and leads. Evidence is a retained
  screenshot in `production/qa/evidence/`.
- **AC-23 (Playtest; CD condition)**: in Tier 0 playtests, every exposure
  logged is against a verdict that its fragment contradicts. Testers can
  state the rival's target site and its next lead day from the UI.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **`expose` on a held copy**: Faction Belief accepts `expose` on a HELD
  fragment that is in the rival's `known(r)` and is neither sealed nor shared
  (Faction Belief edge case amended), so claiming a rival's copy never makes a
  lie safe. The target was still one specific unfound fragment when the rival
  drew it, so the CD condition holds.
- **D7's H counts distinct groups**, as ruling out does.
- **The pace setting may change mid-campaign**; the change is logged and
  applies from the next lead (rule 8).
- **`DEFEAT_MAX_S`** is 1,209,600 (14 days; World Clock); D6 uses it.

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 2 | **A find that does not expose**: nothing at MVP (recommended), or a public confirmation in the Vertical Slice? | game-designer | Vertical Slice |
| 3 | **Stream registration** `base:exposure.target` and the uniform-int API name. | RNG owner | ADR on streams |
| 4 | Rival name, fiction and notice wording ("the Inquest" is a placeholder). | narrative-director | Before Tier 0 content lock |
| 5 | **Pace against fragment count**: at Standard, the rival must not know every MVP fragment before the median tester has claimed at least half of them; if it does, raise `LEAD_BASE_S` or `LEADS_PER_FIND`. (6 MVP slots are all known by about day 60 at Standard with no player claims.) Otherwise a late naming becomes a cheap truth test. | systems-designer; economy pass | Before Tier 0 playtest |
| 6 | **The true maker's agents** (Vertical Slice): presentation without attribution, and whether there is more than one rival at once. | game-designer; creative-director | Vertical Slice |
| 9 | Should the ±1-day `RETEST_DELAY_S` be previewed as a day number? | ux-designer | UX spec for Case File |
| 11 | A moving rival fleet on the map (interceptable?) instead of a site marker. | game-designer | Vertical Slice |
