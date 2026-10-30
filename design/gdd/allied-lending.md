# Allied Lending

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (honest cost of withholding; exposure-caused withdrawal previewed; loan ends at the first stronghold battle; no battle against the lender while escorted; AC and knob fixes)
> **Implements Pillar**: Pillar 2 (The Truth Is Yours to Tell — what you tell decides who lends you ships); Pillar 1 (Every Defeat Is a Lead — an earned escort is one way back, never the only one); Pillar 4 (Plan in the Open — every share previews whether it grants or loses the escort)

## Summary

Allied Lending lets one organic faction (the Orrowen at MVP) lend two of its own ships for a return attempt. It grants the escort when that faction's blame on its rivals passes a threshold and refuses or withdraws it when public blame on its own race passes one, reading Faction Belief's distribution only, never Standing and never the truth. The escort is real ships under Fleet Orders, every share previews whether it grants or loses them, a lost lent ship costs previewed standing with the lender, and the AI-vs-AI Runner still proves every no-ally counter wins without them.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Hulls & Ship Definition, Fleet Coordination, Faction Belief & Blame, Runtime ID Service`

## Overview

Allied Lending turns a faction's belief into ships. A **lender** is a faction
whose content carries a lending package. It becomes **willing** when it blames
one of its rivals strongly (`max_{c≠race(f)} b_f[c] ≥ GRANT_PM`, 600) and the
public does not strongly blame its own race (`P[race(f)] < REFUSE_PM`, 600).
Willingness has hysteresis and is a pure function of Faction Belief & Blame's
numbers. It never reads the seeded maker or the standing value. While a lender
is willing, the player can take its escort at one of its ports: real organic
ships of the lender's race. They join the fleet, take Fleet Orders like any
player ship, travel without slowing the fleet and cost the player no upkeep.
The loan lasts for one return attempt. It ends after the next stronghold
battle, after `LOAN_MAX_DAYS`, or when the lender withdraws. Every share or
accusation previews "this grants / loses the escort" before commit. A lent ship
that does not come home costs standing with the lender, and that cost is shown
before the battle. Allied ships are never required: every stronghold has a
counter that wins without them, and the AI-vs-AI Runner proves it.

## Player Fantasy

*You have spent two days in the Orrowen archive halls, showing them the hull
record that clears them and damns the Halsk. The share preview said one line:
"This share grants the Orrowen escort." Now, at the Orrowen port, a Seedcaller
and a Thornbrood fall in behind your flagship. They are not yours. They are
here because of what you told them. When the Thornbrood breaks off to screen
your carrier and burns out holding the line, the Debrief lists it with your
own losses, and the Orrowen remember.*

- **Pillar 2, *The Truth Is Yours to Tell*:** what you tell a faction decides
  whether it sends ships. Persuasion is a mechanic with a visible payout, not
  flavour (MDA: Narrative and Expression). When the truth points at the
  lender's own race, honesty costs you the escort, and that is your call.
- **Pillar 1, *Every Defeat Is a Lead*:** an earned escort is one way back to
  the stronghold that beat you. It is never the only way (rule 27).
- **Pillar 4, *Plan in the Open*:** every action that changes belief previews
  whether it grants or loses the escort. Every battle previews what a lost lent
  ship will cost (rules 19, 21).
- **SDT:** Autonomy (take the escort, refuse it, or trade it for the truth);
  Competence (the condition is stated in words and the result is previewed);
  Relatedness (named ships that keep their names across loans).

## Detailed Design

### Core Rules

**A. Lenders and the package**

1. **A lender is a faction with a `lend_package`** in content (Content Data &
   Mod Loading). At MVP exactly one faction has one (`LENDERS_MVP` = 1;
   concept MVP item 6, "one faction's lent escort"). Which faction is Open
   Question 1; the recommendation is the Orrowen faction. The text-only third
   race has no faction ships and never lends.
2. **No loan before the opening battle has ended** (Onboarding & Opening Sequence). **The package is organic hulls of the lender's race.** `LEND_PACKAGE`
   defaults to one Seedcaller and one Thornbrood (Hulls rule E) with the
   lender's default loadouts. A package entry that is a machine hull, or a
   hull of another race, is a load error `LEND_HULL_INVALID`. There are no
   machine hulls in the player fleet at MVP (Hulls rule 7, Credits rule 3).
3. **The pool keeps names and IDs.** The first time a lender's escort joins,
   #33 issues one Runtime ID per package ship inside the simulation step and
   stores them in the lender's **pool**. Later loans reuse the same ships and
   IDs, so the *Varrow* that fought beside you last time comes back (Runtime ID
   Service rule 4). A lost ship leaves the pool for good (rule 17).

**B. Willingness** (CD condition a)

4. **Willingness reads Belief only.** For each lender `f`, #33 computes the
   rival blame `R_f` (D1) and the self blame `S_f` (D2) from `belief(f)` and
   `public_blame()`, then the willing flag `W_f` from D3. The only other
   inputs are `W_f`'s previous value and the Hostile veto in rule 6. It never
   reads the maker, the truth, the standing value or the difficulty preset.
5. **It works both ways, with hysteresis** (D3):
   - **Grant:** an unwilling lender becomes willing when `R_f ≥ GRANT_PM`
     (600) and `S_f < REFUSE_PM − LEND_H` (550).
   - **Stay:** a willing lender stays willing while `R_f ≥ GRANT_PM − LEND_H`
     (550) and `S_f < REFUSE_PM` (600).
   - **Refuse or withdraw:** a lender is unwilling whenever `S_f ≥ REFUSE_PM`,
     whatever else holds. Refusal always wins over grant.
6. **The Hostile veto.** A lender whose standing band is Hostile is unwilling
   and its lent ships are recalled (Standing rule 3). This is a veto, not a
   gate: no other band changes lending. Because naming a race sets its faction
   Hostile (#30 rule 11) and naming needs `P[X] ≥ NAME_PM` (600), a named
   lender has already been refused by rule 5. Whether the veto stays is Open
   Question 2.
7. **When it is evaluated.** After every #30 commit (share, accuse, suppress,
   release, lapse, exposure, confirmation) and every Standing band change,
   #33 re-evaluates every lender in ascending Runtime ID. A change emits
   `LendingChanged(f, W_before, W_after, cause_seq)`, where `cause_seq` is the
   #30 log entry or the Standing log entry.
8. **No difficulty scaling.** No threshold, package or cost here changes with
   the preset (Gameplay Settings rule 9; #30 rule 23).

**C. The loan** (CD condition c)

9. **Taking the escort.** While docked at a port whose system's
   `owner_faction` is `f` (Ports rule 2), with `W_f` true and no active loan
   (`MAX_ACTIVE_LOANS` = 1), the port's fleet screen offers "Take the ⟨f⟩
   escort (k ships)". It is free. On confirm, in the simulation step, each
   available pool ship joins the player fleet in ascending Runtime ID, and #33
   emits `OwnerChanged(ship, f → PLAYER)` for each (Runtime ID Service rule 4).
   The ship stores `lender = f`.
10. **Lent ships are player ships under Fleet Orders.** They can be selected,
    grouped and given every Fleet Orders order. With no goal they follow the
    player's default doctrine (Fleet Coordination rule 10). Ship AI runs them
    as player ships: `ALLY_EXEC`, Fleet Orders goals, their race's behaviour
    family (Ship AI edge case "lent by a faction"). A lent ship is never the
    flagship. It cannot be refitted, mothballed, laid up, sold, salvaged or
    renamed.
11. **Travel.** Lent ships escort the fleet and never count toward `v_slow` or
    `n` (Sector Map rule 6).
12. **Rest and care.** Port rest restores lent ships exactly as it restores the
    active roster (Ports rule 10). Care, which is a standing spend, is not
    offered for a lent ship. Hull wounds close in travel like any organic hull
    (Hulls, Travelling state). The player never pays to repair a lent ship.
13. **Upkeep.** The lender pays. A lent ship adds nothing to `U_day`,
    `U_nominal`, `defeat_cap` or any Credits bill (Credits rules 4, 5, 7).
14. **The loan ends** at the first of these:
    - (a) the end of the first battle against a stronghold after the join (a
      roaming fleet or minor contact on the way never uses up the loan),
      whatever the outcome (the return attempt);
    - (b) `LOAN_MAX_DAYS` (20) world days after the join;
    - (c) withdrawal (rule 15);
    - (d) the player dismisses the escort at any port.

    On an end outside battle, the remaining lent ships leave on that tick in
    ascending Runtime ID. #33 emits `OwnerChanged(ship, PLAYER → f)` for each
    and returns it to the pool. Ships disabled in a won battle are recovered
    first (rule 17), then leave.
15. **Withdrawal.** When `W_f` turns false during a loan:
    - **outside battle**, the lent ships leave on that tick (rule 14). A
      player action that causes it was previewed as "loses the escort"
      (rule 21), so nothing vanishes without warning;
    - **inside battle**, the loan enters RECALLING. The lent ships fight on
      under the player's orders until the battle ends, then leave. No ship
      leaves a battle mid-fight because of belief. (Player belief actions are
      committed outside battle, #30 rule B, so only a world event such as an
      exposure can cause this.)

**D. Battle and loss** (BR Open Question 7)

16. **Lent ships count on the player side** for presence, `P` and the end
    check (Battle Resolution rule 2). A battle won by lent ships alone is a
    player victory.
17. **Home or lost.** At battle end, a lent ship that retreated or is still
    present goes home with the loan. A lent ship disabled in a battle the
    player wins is recovered with the player's ships and goes home. A lent
    ship that is destroyed, or disabled and left behind after a loss, is
    **lost**: it leaves the pool, its ID is retired by the usual rules, and
    #33 emits `LentShipLost(ship, f, battle_id)`. Its owner at the moment of
    loss stays PLAYER, so the record reads "the lent *Varrow*, lost".
18. **What a loss costs.** For each lost lent ship, at battle end, #33 calls
    `Standing.penalize(f, LENT_LOSS_STANDING, cause = battle_id)` (40, SLIGHT).
    The player pays no credits for it: Credits' left-behind bill skips lent
    ships. The Debrief lists it as a player loss (Debrief rule 5).
19. **The loss cost is previewed before battle.** The battle-start preview
    (Battle Resolution) shows, when any lent ship is present: "⟨k⟩ lent ⟨f⟩
    ships. Each one lost costs ⟨band⟩ standing with ⟨f⟩", from
    `preview_lent_loss()` (D5). It also shows the band the lender would reach
    if all `k` were lost, from `Standing.preview(ops)`.
20. **Restock.** A lost pool ship is replaced `LEND_RESTOCK_DAYS` (10) world
    days after its loss with the same hull and a new Runtime ID, issued in the
    daily step. A loan taken before then joins with the ships available, and
    the offer says how many.

**E. Previews and the Dossier** (CD condition b)

21. **`preview_lending(belief_after, bands_after)`** runs D1–D4 on #30's
    preview copy and Standing's previewed bands. For each lender it returns
    one of GRANTS, LOSES or UNCHANGED, plus the ship count. #30's preview
    (#30 rule 18) prints: "This ⟨action⟩ grants the ⟨f⟩ escort (k ships)" or
    "This ⟨action⟩ loses the ⟨f⟩ escort", or nothing when UNCHANGED. LOSES
    covers both a willing lender turning unwilling and an active loan being
    withdrawn. It never prints `R_f`, `S_f` or any belief number. The commit
    applies exactly what the preview showed.
22. **The Dossier helper line.** For a node with `helper_faction_id = f`
    (Machine Nodes rule 18), the Dossier shows `helper_line(f)`:
    - the condition in words, with no numbers: "⟨f⟩ lends k ships while it
      strongly blames another race and the public does not strongly blame
      ⟨race(f)⟩";
    - the status now: "would lend", "would not lend", "escort with you" or
      "recalling";
    - while a share or accusation is pending in a planning hold, the same
      GRANTS / LOSES line as rule 21: "This share grants / loses the escort";
    - when an investigation is running against the current verdict, the line
      "If this investigation exposes the public history: loses the ⟨f⟩
      escort", computed with `preview_lending` on #32's projected belief after
      that exposure, also shown on #32's exposure readout, so even a
      withdrawal caused by exposure never arrives unpreviewed.
23. **The Debrief** names the helper faction and states this condition (Debrief
    rule 26). Neither the Debrief nor the Dossier ever suggests which share or
    accusation would unlock it (concept, Unique Hook).

**F. Truth, determinism and proofs** (CD condition d)

24. **No race is special.** The rules read the maker nowhere (Truth Seeding
    rule 2). When the seed lands on the lender's own race, honest reliable
    fragments tend to be consistent with that race and contradict its rivals.
    Shared with the lender, they move its blame onto its own race, so `R_f`
    falls; shared in public, they raise `S_f`. Telling the truth then loses
    the escort. The player can keep it by withholding, by sharing selectively,
    or by lying. Lying carries #30's and #32's visible costs; withholding and
    selective sharing cost only the trust that later confirmations would have
    paid. The
    game never tells the player which case they are in: the lending result is
    a function of the claims on cards the player already holds, so it leaks
    nothing the cards do not.
25. **Determinism.** All maths is integer permille. Lenders are processed in
    ascending Runtime ID, ships in ascending Runtime ID, after the #30 or
    Standing write that triggered them. IDs are issued only inside simulation
    steps (Runtime ID Service rule 3). The preview never issues IDs.
26. **Save section** `base:allied_lending`, version 1. Per lender: `W_f`, the
    loan state, the pool (ship ID, hull, available or restock day), the join
    day, the active loan's ship list and `lent_lost_count`. Every save round
    trip is byte-identical. `W_f` is saved, not recomputed, because the
    hysteresis needs it.
27. **Never required, never in a proof.** The AI-vs-AI Runner never fields lent
    ships or a helper faction (Runner rule 12). Every node lists at least one
    `solo` counter with `requires_allies` false (Machine Nodes rule 19). An
    escort can make a return easier. It is never the only way back.

### States and Transitions

| Entity | State | Entered when | Leaves to |
|---|---|---|---|
| Lender | UNWILLING | Start (`W_f` false); `S_f ≥ REFUSE_PM`; stay condition fails; Hostile | WILLING (grant condition, D3) |
| Lender | WILLING | Grant condition holds and not Hostile | UNWILLING; LENT (player takes the escort at an `f` port) |
| Loan | LENT | Escort joins (rule 9) | RETURNED (end a, b or d); RECALLING (withdrawal in battle); RETURNED (withdrawal outside battle) |
| Loan | RECALLING | `W_f` turns false during a battle | RETURNED at battle end |
| Loan | RETURNED | Loan ends; surviving ships leave | — (lender back to WILLING or UNWILLING by D3) |
| Pool ship | AVAILABLE | Created at first join; restocked | LENT |
| Pool ship | LENT | Joins the player fleet | AVAILABLE (goes home); LOST |
| Pool ship | LOST | Destroyed, or disabled and left behind | — (retired; a replacement is RESTOCKING) |
| Pool ship | RESTOCKING | A ship is lost | AVAILABLE after `LEND_RESTOCK_DAYS` (new ID) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Faction Belief & Blame (#30) | #30 → #33; #33 supplies preview | Reads `belief(f)`, `public_blame()`; supplies `preview_lending(belief_after, bands_after)` for #30 rule 18; re-evaluates after each #30 commit |
| Faction Reputation & Standing (#17) | both | Reads the Hostile band only (rule 6); calls `penalize` for lost lent ships; uses `preview(ops)` for the pre-battle line |
| Hulls & Ship Definition (#10) | #10 → #33 | Organic hull definitions for the package; validator for `LEND_HULL_INVALID` |
| Runtime ID Service | #33 → it | Issues pool IDs in the step; #33 emits `OwnerChanged` on join and leave |
| Fleet Orders (#19), Fleet Coordination, Ship AI | #33 → them | Lent ships are player ships: orders, doctrine, `ALLY_EXEC`; never flagship |
| Sector Map & Travel | #33 → map | Lent ships escort; excluded from `v_slow` and `n` |
| Ports, Rest & Care (#27) | both | Offer and dismiss on the fleet screen of an `f` port; rest includes lent ships; no care |
| Credits, Upkeep & Sinks (#18) | #33 → #18 | Lent ships excluded from upkeep, `U_nominal`, `defeat_cap` and left-behind bills |
| Battle Resolution & Retreat (#22) | both | Lent ships count player-side; battle end tells #33 home or lost; #33 supplies `preview_lent_loss()` |
| After-Action Debrief (#24) | #33 → #24 | Lent losses count as player losses; helper condition text |
| Machine Nodes & Strongholds (#23), Dossier (#47) | #23 → #33 → #47 | `helper_faction_id`; `helper_line(f)` |
| Exposure & Rival Investigation (#32) | via #30 | An exposure can withdraw the escort (rule 15) |
| AI-vs-AI Runner | none | Excluded from proofs (rule 27) |
| Save/Load & Migration (#5) | #33 → #5 | Section `base:allied_lending` |
| World Clock (#8) | #8 → #33 | Daily step for `LOAN_MAX_DAYS` and restock |
| Content Data & Mod Loading (#4) | #4 → #33 | `lend_package` per faction; knobs |

## Formulas

Shared symbols: `f` is a lender. `r = race(f)`. `b_f[c]` and `P[c]` are #30's
(rule 1 and D4), in permille. "Willing" is the boolean `W_f`.

### D1. Rival blame

`R_f = max_{c ∈ candidates, c ≠ r} b_f[c]`

| Variable | Type | Range | Description |
|---|---|---|---|
| b_f[c] | int ‰ | 0 – 1,000 | Lender's blame on candidate `c` |
| R_f | int ‰ | 0 – 1,000 | Strongest blame the lender puts on a rival |

**Output:** at the start (C = 3), `R_f = 450` (#30 D0), below `GRANT_PM`.

### D2. Self blame

`S_f = P[r]` if `r` is a candidate; otherwise `S_f = 0` (a lender outside the
candidate set is never refused by blame).

| Variable | Type | Range | Description |
|---|---|---|---|
| P[r] | int ‰ | 0 – 1,000 | Public blame on the lender's race (#30 D4); the lender's own view is not in it |
| S_f | int ‰ | 0 – 1,000 | Self blame used for refusal |

**Output:** at the start, `S_f = 450`.

### D3. Willingness

```
if hostile(f):                         W' = false
elif S_f ≥ REFUSE_PM:                  W' = false
elif W = false:   W' = (R_f ≥ GRANT_PM) and (S_f < REFUSE_PM − LEND_H)
else (W = true):  W' = (R_f ≥ GRANT_PM − LEND_H)
```

| Variable | Type | Range | Description |
|---|---|---|---|
| GRANT_PM | int ‰ | 500 – 700; **600** | Rival blame that grants |
| REFUSE_PM | int ‰ | 550 – `NAME_PM`; **600** | Self blame that refuses or withdraws |
| LEND_H | int ‰ | 25 – 100; **50** | Hysteresis band |
| W, W' | bool | — | Willing before and after |

**Output:** a boolean. The dead band means a change of under `LEND_H` cannot
flip the flag back and forth.

**Worked example** (C = 3; lender Orrowen `O`; rivals Halsk `H` and the
text-only `T`; one share per step, first chain, so `s_eff = SHIFT_PM`).
Start: `b_O = {O 100, H 450, T 450}`, `P[O] = 450`, `W = false`.

1. RECORD share to Orrowen, contradicting `T` and `O`, consistent with `H`
   (`K = {H}`, #30 D1): `u_T = 450 × 250 div 1,000 = 112`, `u_O = 100 × 250
   div 1,000 = 25`. Now `b_O = {O 75, H 587, T 338}`, sum 1,000. `R = 587 <
   600`: no grant. The preview printed nothing.
2. TESTIMONY share to Orrowen, contradicting `T`, consistent with `H`:
   `u_T = 338 × 120 div 1,000 = 40`. Now `b_O = {O 75, H 627, T 298}`. `R =
   627 ≥ 600`, and `S = P[O] = 450 < 550` (private shares do not move other
   factions' views). **W' = true.** The preview printed "This share grants the
   Orrowen escort (2 ships)".
3. Later an exposure moves `P[O]` to 610. `S ≥ 600`: **W' = false**. If the
   escort is out of battle, it leaves this tick; if in battle, RECALLING.
4. Suppose instead `R` falls to 560 with `S` at 450. `560 ≥ 550`: it stays
   willing. At 549 it withdraws.

### D4. Preview classification

For each lender, `W_now` is the current state and `W_after` is D3 applied to
`belief_after` and `bands_after`, starting from `W_now`.

| `W_now` | `W_after` | Loan active | Line |
|---|---|---|---|
| false | true | — | GRANTS |
| true | false | no | LOSES ("loses the offer") |
| true | false | yes | LOSES ("loses the escort") |
| equal | equal | — | UNCHANGED (no line) |

### D5. Lost-ship standing cost

`cost_f = k_lost × LENT_LOSS_STANDING`, written as `k_lost` separate
`penalize` calls with one cause. The pre-battle preview shows the per-ship band
and `cost_max = k_present × LENT_LOSS_STANDING`.

| Variable | Type | Range | Description |
|---|---|---|---|
| k_present | int | 0 – `|LEND_PACKAGE|` | Lent ships in the battle |
| k_lost | int | 0 – `k_present` | Lost at battle end (rule 17) |
| LENT_LOSS_STANDING | int | 0 – 120; **40** | Standing per lost ship (SLIGHT) |
| cost_f | int | 0 – 240 at MVP | Total standing lost |

**Example:** 2 lent ships, one destroyed, one retreated: `cost = 1 × 40 = 40`.
The preview had shown "each one lost costs SLIGHT; both lost: −80".

## Edge Cases

- **If the seed lands on the lender's own race (case d)**: nothing changes in
  the rules. Honest reliable shares lower `R_f` and raise `S_f`, so the truth
  tends to cost the escort (rule 24). The no-ally counter still wins (rule 27).
  Playtests should check that testers read this as a choice, not a punishment.
- **If the maker is a rival**: honest shares raise `R_f`, and the escort is the
  reward for telling the truth. The rules are the same; only the cards differ.
- **If the lender's race is named**: `P[r] ≥ 600 = REFUSE_PM` already refused
  it, and naming sets Hostile too. Both point the same way.
- **If the lender's race is not a candidate** (mods): `S_f = 0`; only `R_f` and
  the Hostile veto apply.
- **If `R_f` ties between two rivals**: `max` returns the value; which rival
  does not matter.
- **If withdrawal happens while docked at the lender's port before departure**:
  the ships leave on that tick; nothing else happens.
- **If withdrawal happens in battle**: RECALLING; they fight to the end, then
  leave. If they are lost in that battle, rule 18 still charges standing,
  because the cost was previewed at battle start.
- **If the player keeps the escort and never attacks a node**: it goes home
  after `LOAN_MAX_DAYS` (20). Battles against faction fleets on the way do not
  end the loan.
- **If the battle against the node ends in STANDOFF, timeout or retreat**: end
  (a) still applies; the return attempt happened.
- **If the flagship is disabled and only lent ships remain**: the battle goes
  on (Battle Resolution rule 6). If they win, it is a player victory.
- **If every pool ship is lost or restocking**: the offer is not shown; the
  Dossier status reads "would lend, no ships ready until day D".
- **If a second lender becomes willing (post-MVP) while a loan is active**:
  `MAX_ACTIVE_LOANS` (1) blocks a second loan; the offer says why.
- **If the player tries to start a battle against the lender's faction**: it
  cannot start while that faction's escort is with the player; the battle-start
  preview offers "Dismiss the ⟨f⟩ escort first". Lent ships never fight their
  own faction.
- **If a lent ship is the cheapest escort**: it is never the free core (Credits
  rule 5), because it is not in the roster.
- **If a save is made mid-loan or in RECALLING**: the loan state, pool and
  `W_f` reload byte-identical (rule 26).
- **Degenerate: shuttle sharing to farm escorts.** Grant and loss both run
  through #30's actions, which have no undo and finite fragments. The
  hysteresis stops flip-flopping. The escort is two ships, bounded by
  `MAX_ACTIVE_LOANS`.
- **Degenerate: suicide-screening with lent ships to save the player's own
  hulls.** Allowed, and priced: each loss costs standing with the lender
  (rule 18) and appears in the Debrief.
- **Degenerate: lying is optimal for lending.** A lie can buy an escort, but
  #30 good faith, #32 exposure and suppression upkeep price it, and the escort
  is never needed to win (rule 27). The Tier 0 validation checks that no
  tester lies without paying a visible cost.

## Dependencies

| System | Kind | What #33 needs or gives |
|---|---|---|
| Faction Belief & Blame (#30) | Hard | `belief(f)`, `public_blame()`, commit signal; #33 supplies `preview_lending` |
| Faction Reputation & Standing (#17) | Hard | Hostile band, `penalize`, `preview(ops)` |
| Hulls & Ship Definition (#10) | Hard | Organic hull definitions |
| Runtime ID Service | Hard | IDs; `OwnerChanged` emitted by #33 |
| Fleet Orders, Fleet Coordination, Ship AI | Hard | Lent ships handled as player ships |
| Battle Resolution & Retreat (#22) | Hard | Player-side count; battle end; pre-battle preview slot |
| Ports, Rest & Care (#27) | Hard | Offer and dismiss; rest |
| Sector Map & Travel | Soft | Excluded from speed |
| Credits, Upkeep & Sinks (#18) | Soft | Exclusion from upkeep and bills |
| After-Action Debrief (#24), Dossier (#47), Machine Nodes (#23) | Hard (reverse) | Loss count, helper line, `helper_faction_id` |
| World Clock (#8) | Hard | Daily step |
| Save/Load (#5), Content Data (#4) | Hard | Save section; package and knobs |
| AI-vs-AI Runner | None by rule | Excluded |

Bidirectional: #30, #17, #22, #24, Runtime ID, Sector Map and the Runner
already list #33. #17, #18, #27, Fleet Coordination and #24 need the
amendments in Cross-References.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects | Too low | Too high |
|---|---|---|---|---|---|---|
| `GRANT_PM` | 600 | 500 – 700 | Gate | How much persuasion buys the escort | One share grants it; no decision | Unreachable without accusing |
| `REFUSE_PM` | 600 | 550 – `NAME_PM` | Gate | How much public blame refuses | Refuses before any naming threat | A named lender could still lend (Hostile veto catches it) |
| `LEND_H` | 50 | 25 – 100 | Curve | Flip-flop resistance | Escort flickers on small shares | Escort sticks after belief moves away |
| `LEND_PACKAGE` | Seedcaller + Thornbrood | 1 – 2 organic hulls | Curve | Escort strength | Not worth the trip | Makes the no-ally counter feel optional; must stay below the Runner's `REINFORCE_ESCORTS` (3) |
| `LOAN_MAX_DAYS` | 20 | 10 – 40 | Gate | How long an unused escort stays | Lost before reaching the node | Escort becomes a permanent buff |
| `LENT_LOSS_STANDING` | 40 | 0 – 120 | Curve | Price of spending lent ships | Lent ships are free fodder | Players refuse to use them |
| `LEND_RESTOCK_DAYS` | 10 | 5 – 30 | Gate | Time to replace a lost ship | Losses free | One bad fight ends lending |
| `MAX_ACTIVE_LOANS` | 1 | 1 – 2 | Gate | Stacked escorts | — | Ally stacking replaces counters |

## Visual/Audio Requirements

- Lent ships keep the lender's race livery with a player-side command ring, so
  they read as "ours, theirs" at a glance (art-director owns the treatment).
- Join and leave: a short formation fall-in and peel-off on the sector map.
- A distinct cue on withdrawal and on RECALLING (audio-director).
- No cue may differ by the seeded maker.

## Game Feel

- Taking the escort is a moment: the offer names the ships and their names.
- Withdrawal is never a surprise from the player's own action; it was previewed.
- In battle, lent ships answer orders on the same tick as player ships; there
  is no command lag that marks them as second-class.

## UI Requirements

- #30 preview: the GRANTS / LOSES line (rule 21), next to the standing result.
- Port fleet screen: offer, ship count, loan end conditions, dismiss button.
- Fleet roster and HUD: a "lent by ⟨f⟩" tag and the days left on the loan.
- Battle-start preview: the lent-loss line (rule 19).
- Dossier: `helper_line(f)` (rule 22).
- Debrief: lent losses marked "lent by ⟨f⟩".
- Each screen touched has a retained screenshot in `production/qa/evidence/`.

## Cross-References

| Doc | Rule | Amendment needed |
|---|---|---|
| `faction-belief-and-blame.md` | rule 18; Interactions; OQ 2 | Signature becomes `preview_lending(belief_after, bands_after)`; OQ 2 resolved by #33 D3 |
| `faction-reputation-and-standing.md` | rule 3 | Remove "Trusted: eligible to lend"; lending reads Belief, and only Hostile vetoes (#33 rule 6). Add the `penalize` writer for lost lent ships (#33 rule 18) |
| `battle-resolution-and-retreat.md` | OQ 7; rule 2 | Resolved by #33 rules 17–19; add the lent-loss line to the battle-start preview |
| `credits-upkeep-and-sinks.md` | rules 4, 5, 7 | Lent ships are not in the roster: no upkeep, not in `U_nominal` or `defeat_cap`, not billed when left behind |
| `ports-rest-and-care.md` | rules 10, 19 | Rest includes lent ships; care is not offered for them; fleet screen hosts the offer |
| `after-action-debrief.md` | rule 26 (line ~183) | "the lending terms are Faction Reputation's" becomes "Allied Lending's (#33 rule 22)" |
| `fleet-coordination.md` | rule 10 | State that lent ships take the player's default doctrine |
| `machine-nodes-and-strongholds.md` | rules 18–19 | No change; cite #33 rule 27 |
| `ai-vs-ai-runner-and-ai-debug-tools.md` | rule 12 | No change |
| `systems-index.md` | CD note | Conditions a–d map to AC-01–AC-12 |

## Acceptance Criteria

- **AC-01 (Logic; rule 5, D3; CD a)**: from `W = false`, `R_f = 600`, `S_f = 549` gives willing; `R_f = 599` or `S_f = 550` gives unwilling.
- **AC-02 (Logic; rule 5, D3; CD a)**: from `W = true`, `S_f = 600` gives unwilling whatever `R_f` is; `R_f = 550` with `S_f = 599` stays willing; `R_f = 549` withdraws.
- **AC-03 (Logic; rule 4; CD a)**: `W_f` changes when only `b_f` or `P` change, and never when only the standing value changes within a non-Hostile band. A test double that fails on any read of the maker or the standing value passes.
- **AC-04 (Logic; rule 21, D4; CD b)**: for a share that moves `R_f` from 587 to 627, #30's preview includes "grants the ⟨f⟩ escort"; for one that moves `S_f` to 600 during a loan it includes "loses the escort"; the committed result matches the preview in every case of D4.
- **AC-05 (UI; rule 22; CD b)**: with a share pending, the Dossier helper line shows "This share grants / loses the escort" before commit; retained screenshot in `production/qa/evidence/`.
- **AC-06 (Integration; rules 9–10; CD c)**: after taking the escort, each lent ship is a separate ship in Combat Space, accepts Move, Attack, Escort, Hold, Focus Fire and Retreat, and follows the default doctrine with no goal; no stat of any player ship changes.
- **AC-07 (Logic; rule 27; CD c)**: a Runner proof run never contains a ship with `lender` set or a helper faction, and every node's `solo` counter wins in it.
- **AC-08 (Logic; rule 24; CD d)**: two saves whose makers differ (one the lender's race) but whose belief histories are identical give byte-identical `W_f`, previews and `base:allied_lending` sections.
- **AC-09 (Integration; rule 24; CD d)**: with the maker set to the lender's race, sharing a reliable fragment consistent with that race and contradicting both rivals to the lender lowers `R_f`; the preview shows LOSES or UNCHANGED, never GRANTS; a public share of the same fragment raises `S_f` and previews LOSES when it crosses `REFUSE_PM`.
- **AC-10 (Logic; rule 15)**: a withdrawal outside battle removes lent ships on that tick with one `OwnerChanged(PLAYER → f)` each; inside battle the loan is RECALLING and every lent ship stays until battle end.
- **AC-11 (Logic; rules 17–18)**: in a lost battle with two lent ships, one destroyed and one retreated: one `LentShipLost`, one `penalize(f, 40)`, no Credits charge, and the Debrief lists the destroyed ship as a player loss.
- **AC-12 (UI; rule 19; BR OQ 7)**: the battle-start preview shows the lent-loss line whenever `k_present > 0`; retained screenshot.
- **AC-13 (Logic; rules 3, 9, 14)**: a ship lent, returned and lent again keeps its Runtime ID; join and leave each emit one `OwnerChanged` in ascending ID.
- **AC-14 (Logic; rules 11, 13)**: adding the escort changes neither `v_slow`, `n`, `U_day` nor `defeat_cap`.
- **AC-15 (Logic; rule 14)**: the loan ends at the end of the first stronghold battle (any outcome; a roaming-fleet battle does not end it) or after 20 days, whichever is first.
- **AC-16 (Logic; rule 6)**: a lender set Hostile is unwilling and an active loan is recalled under rule 15.
- **AC-17 (Logic; rule 26)**: a save in each loan state round-trips byte-identical, including `W_f` inside the hysteresis band.
- **AC-18 (Logic; rule 2)**: a package entry that is a machine hull or another race's hull fails load with `LEND_HULL_INVALID`.
- **AC-20 (Logic; rule 22)**: with an investigation running whose projected exposure would push `S_f` past `REFUSE_PM`, the Dossier line and the exposure readout both show "If this investigation exposes the public history: loses the ⟨f⟩ escort".
- **AC-21 (Logic; edge cases)**: a battle against the lender's faction cannot start while its escort is with the player; the preview offers dismissal.
- **AC-19 (Playtest; CD validation)**: in Tier 0 playtests at least one tester changes or keeps a share to gain or keep the escort (logged, unscored), testers on a lender-maker seed describe losing the escort as their choice, and no tester lies to gain the escort without paying a visible cost.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **The MVP lender is the Orrowen faction**, so the Halsk-led player fleet
  borrows the other playable race's hulls.
- **The Hostile veto stays**, as a veto only: a Hostile faction engages on
  sight and cannot escort. Standing's Trusted gate is dropped (Standing rule 3
  amended), so lending reads Belief, never Standing (CD condition a).
- **A loan lasts one return attempt** (one machine-node battle, capped at
  `LOAN_MAX_DAYS`).
- **The World Clock runs in battle but no campaign event fires there** (World
  Clock rule 9), so a withdrawal can never start mid-battle at MVP; RECALLING
  stays as a safeguard for later systems.

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Do lent ships count against any battle deployment cap? Not verified. | systems-designer | Battle Resolution review |
| 2 | `LEND_PACKAGE` size against the Runner's Ready band; no balance data exists. | systems-designer | When `assets/data/hulls/` exists |
| 3 | ~~Stub depth~~ **Answered by CD 2026-10-30:** the coupling holds at stub depth if the stub keeps both directions of D3 with hysteresis, the grant / lose preview line, the Runner exclusion (rule 27) and the lent-loss line before battle; the pool, restocking and named ships can wait for the Vertical Slice. A stub that only ever grants breaks condition (a). | creative-director | Closed |
