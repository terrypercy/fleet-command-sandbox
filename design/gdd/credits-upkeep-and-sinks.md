# Credits, Upkeep & Sinks

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — defeat costs resources, bounded, never the run); Pillar 2 (a lie costs money to keep up)

## Summary

Credits, Upkeep & Sinks is the campaign's money: one wallet that never goes
negative, a hold of unsold salvage, fleet upkeep charged every game day
(including rest days), a defeat bill with a cap shown before the fight, and the
money side of suppression, the upkeep of every lie. An empty wallet mothballs
ships but never ends the run, and a free core of two ships can always try again
(Pillars 1, 2 and 4).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Save/Load & Migration, World Clock`

## Overview

Credits, Upkeep & Sinks is the campaign's money. It holds one integer **wallet**
and a **hold** of unsold salvage, charges **fleet upkeep** every game day,
bills a **defeat** up to a visible cap, keeps the **bankruptcy floor** that
means a run never ends for lack of money, and is the money side of
**suppression**, the in-world cost of keeping a lie. Every change is logged
with its cause.

Its design guarantees come from Pillar 1: **defeat costs time and resources,
bounded, never the run.** A defeat's bill has a cap the player can see before
they fight; an empty wallet mothballs ships but never ends the campaign; and a
free core of two ships can always attempt a retry. The design review found no
money sink, so this system also provides them: upkeep that runs every day,
including rest days; refits; and the upkeep of every lie.

## Player Fantasy

**Quartermaster of a fleet in the field, paying for the lies you choose.**
Every ship has a daily price; every rest day is paid in upkeep; a defeat sends
a bill whose maximum is known in advance. And money is how the player pays for
choices: ships, refits and, above all, lies, which keep charging upkeep for as
long as they stand.

*Anchor moment:* after a defeat, the Debrief shows the bill: 2,400 salvage lost,
800 to recover a disabled frigate, six days of upkeep; 5,720 in all, under the
6,300 cap shown before the battle. In the ledger below it, a quieter line: "60,
suppression upkeep, day 40". The lie is still costing.

**Pillars served:**
- **Pillar 1:** a defeat's cost is capped and shown; a run never ends for money
  (rules 6–8).
- **Pillar 2:** a lie costs money to keep up, the same share of income on every
  preset (rule 9).
- **Pillar 4:** every cost is quoted before it lands and logged after.

**This system must never make the player feel:** "one loss bankrupted my run",
"I have to grind before I can try again", or "money vanished and I don't know
where".

## Detailed Design

### Core Rules

**A. The wallet**

1. **One wallet**, an integer `wallet ≥ 0` in credits (64-bit); it never goes
   negative. Salvage goes into a separate **hold** until sold at a port.
2. **Faucets**, each scaled by `yield_permille` (Gameplay Settings & Modifiers
   D2):
   - **salvage**: `destroyed_DP × SALVAGE_CR_PER_DP` (20) per won battle, into
     the hold;
   - **bounties**: `BOUNTY_BASE` (4,000) per machine node broken;
   - **loot sales** (Loot & Crafting) and **contracts** (Contracts & Missions,
     Alpha).
3. **Sinks**: fleet upkeep (rule 4); the defeat bill (rule 7); refit (prices from
   Refit & Loadout); machine repair (post-MVP: no player machine hulls at MVP);
   suppression purchase and upkeep (rule 9). **No docking or rest fee**: rest
   costs days, and upkeep runs during them, so port is never free; the
   bankruptcy floor keeps it from being a money trap.

**B. Upkeep and the bankruptcy floor**

4. **Fleet upkeep** is charged per ship per day by size class: light 60, line
   120, heavy 240, capital 480. A daily World Clock event (priority 100) charges
   it; the charge is all or nothing per ship. It fires inside rests and skips;
   during a **defeat skip** it is held, and those days are billed in the defeat
   bill instead (rule 7).
5. **The free core.** The flagship and the cheapest escort (`FREE_CORE_SHIPS` =
   1) cost no upkeep and are never mothballed.
6. **Mothball at zero.** If the wallet cannot cover a day's charge, ships are
   mothballed one at a time, highest upkeep first, until the rest is paid. A
   mothballed ship stays in the roster, cannot deploy, and costs nothing. It is
   reactivated free at any non-hostile port; upkeep simply resumes. There is no
   debt and no interest. A warning shows when the wallet falls below 3 days of
   upkeep.

**C. The defeat bill**

7. **A defeat bills, at most, its cap.** `defeat_bill` = lost salvage + recovery
   of disabled ships + upkeep for the defeat's days (Formulas D2), scaled by
   `defeat_cost_permille`, with `DEFEAT_COST_FLOOR` = 1 credit whenever the base
   is above 0. It is capped at `defeat_cap`; any excess is forgiven and logged
   (`DEFEAT_FORGIVEN`). The wallet part is a forced charge clamped at the
   wallet; any shortfall is forgiven, never turned into debt. The cap is quoted
   before a battle (Dossier, pre-battle panel) and in the Debrief.
8. **The opening loss is exempt** (concept): Battle Resolution flags it
   `opening_loss`; the bill is 0 and the hold is untouched.

**D. Suppression**

9. **The money side of a lie.** Faction Belief & Blame and Exposure decide what
   is suppressed and when; this system charges it: purchase
   `D2(SUPPRESS_BUY_BASE, yield_permille)` (5,000 base) and upkeep
   `D2(SUPPRESS_UPKEEP_BASE, yield_permille)` (60 base) per day per suppressed
   fragment, both atomic spends. Because both scale with `yield_permille`, a
   lie costs the same share of income on every preset (Gameplay Settings &
   Modifiers rule 9). **Suppression upkeep is charged before fleet upkeep** each
   day; if it cannot be paid, the suppression lapses and Faction Belief & Blame
   handles what follows. It never ends the run.

**E. Log, save and API**

10. **The transaction log**: append-only `{seq, campaign_tick, day, delta,
    balance_after, cause, ref_id}`; the newest 512 entries plus lifetime totals
    per cause. Every change goes through it.
11. **Save section** `base:credits` (Save/Load & Migration Core Rule 7), version
    1, loads after `base:world_clock`, ceiling 20,480 bytes: wallet, hold, log,
    mothball flags.
12. **API** (no engine types): `balance()`, `hold()`, `credit_yield(base, cause,
    ref)`, `spend(amount, cause, ref) → OK | REFUSED` (atomic), `charge(amount,
    cause, ref) → paid` (forced, clamped), `quote_upkeep()`,
    `quote_defeat_cap()`, `apply_defeat(report)`, `mothball(id)`,
    `reactivate(id)`; signals `wallet_changed`, `ship_mothballed`,
    `upkeep_warning`.

**F. The defeat-cost gate (Hulls & Ship Definition, Open Question 1)**

13. **Signed off, with three conditions.** Travel heals an organic ship only to
    its scar line; the rest needs port rest, which costs days of upkeep.
    Numerically (D5), a Standard defeat costs about 10 days and 6,600 credits for
    a 6-ship fleet, and even on Chronicler at least 2.5 days and about 1,050
    credits plus Vigor erosion. The conditions: (a) `scar_line_permille` stays ≥
    200; (b) Ports, Rest & Care offers no instant scar clearing paid only in
    credits (care costs standing); (c) no rest fee is ever added.

### States and Transitions

| State | Entered when | Leaves to |
|---|---|---|
| Solvent | wallet ≥ 3 days of upkeep | Short |
| Short | wallet < 3 days of upkeep (warning) | Solvent, Laid-up |
| Laid-up | at least one ship mothballed | Short / Solvent (reactivated at a port) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| World Clock (#8) | #8 → #18 | Daily upkeep event (priority 100; held during a defeat skip); contract payouts register at priority 90 so they land before upkeep at the same instant |
| Gameplay Settings & Modifiers (#7) | #7 → #18 | `yield_permille`, `defeat_cost_permille`, `DEFEAT_COST_FLOOR` (1 credit) |
| Faction Belief & Blame (#30), Exposure (#32) | → #18 | Suppression purchases and upkeep; lapses |
| Faction Reputation & Standing (#17) | — | The standing side of suppression |
| Battle Resolution | → #18 | Salvage, defeat report, `opening_loss` |
| Refit & Loadout, Loot & Crafting, Contracts & Missions, Markets | both | Prices and payouts |
| Hulls & Ship Definition (#10) | #10 → #18 | Size classes; scar line (gate, rule 13) |
| Vigor (#13), Ports, Rest & Care (#27) | — | Rest days (cost upkeep); care costs standing |
| After-Action Debrief, Dossier | #18 → them | Bill, cap and quotes |
| Save/Load & Migration (#5) | #18 → #5 | Section |

## Formulas

### D1. Daily upkeep

`U_day = Σ upkeep[size_s]` over active ships outside the free core (0 – about 5,000).

### D2. Defeat bill and cap

`bill_base = D2(hold × LOST_SALVAGE_PM ÷ 1,000 + Σ hull_value × RECOVER_PM ÷ 1,000, dcp)`
`eff = max(DEFEAT_COST_FLOOR, bill_base)` when `bill_base` > 0
`bill = eff + days_defeat × U_day` (days already scaled by the World Clock skip)
`defeat_cap = D2(DEFEAT_CAP_DAYS × U_day, dcp)`; `final = min(bill, defeat_cap)`

| Variable | Default | Range |
|---|---|---|
| LOST_SALVAGE_PM | 500 | 250 – 750 |
| RECOVER_PM | 100 | 50 – 200 |
| DEFEAT_CAP_DAYS | 15 | 15 – 30 (must stay above the 14-day `DEFEAT_MAX_S`) |
| dcp | `defeat_cost_permille` | 250 – 2,000 |

### D3. Bankruptcy

While `wallet < U_day`: mothball the active non-core ship with the highest upkeep.

### D4. Suppression share

`share = D2(SUPPRESS_UPKEEP_BASE, yield) ÷ income_day`; equal on every preset
because both scale with `yield_permille` (≈ 95 ‰ in the worked fleet: 60 ÷ 633,
51 ÷ 538, 75 ÷ 792).

### D5. Worked example: 30 days on Standard, one defeat

Fleet: heavy flagship and one light (free core), one light (60) and three line
(3 × 120): `U_day` = **420**. Income: four won battles at 120 DP = 4 × 2,400;
one bounty 4,000; loot 3,000.
- **The defeat** (6 days): hold 4,800 → 2,400 lost; one disabled line ship (hull
  value 8,000) → 800 recovery; 6 × 420 = 2,520 upkeep. **Bill 5,720**, under the
  **cap 15 × 420 = 6,300**.
- **Totals:** income 16,600 − 2,400 lost = 14,200; sinks 24 × 420 = 10,080 +
  3,320 = 13,400; **net +800**. Without the defeat: 16,600 − 12,600 = **+4,000**.
- **On Admiral** (yield 850, dcp 1,500): salvage 2,040 per battle; lost 3,060;
  recovery 1,200; 9 × 420 = 3,780; bill **8,040** under a cap of **9,450**; net
  −2,750, recovered by about two winning expeditions.
- **The healing gate** (rule 13): a line organic at 600 / 2,400 after the defeat
  travel-heals to 1,680 (scar line 300 leaves 720 hp); resting about 4 days
  costs 1,680 more in upkeep. On Chronicler: the defeat skip is still ≥ 1 day,
  rest `D2(259,200 s, 500)` = 1.5 days.

## Edge Cases

- **If a contract payout and upkeep fall at the same instant**: the payout
  (priority 90) lands first.
- **If the wallet cannot cover suppression upkeep**: suppression is charged
  before fleet upkeep (rule 9); if still unpaid it lapses.
- **If a defeat happens with an empty wallet**: the hold loss is capped, the
  wallet charge is forgiven, nothing goes negative.
- **If only the flagship is left**: it is never mothballed.
- **If a mothballed ship is sold**: no refund of past upkeep.
- **If a second defeat happens during the rest**: it is a separate defeat with
  its own cap.
- **If a mod tries to bill past the cap**: `apply_defeat` refuses it.
- **If an amount would overflow D2's base limit**: refused as a programmer error.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Save/Load & Migration (#5) | Hard | Section |
| World Clock (#8) | Hard | Daily event, defeat skip |
| Gameplay Settings & Modifiers (#7) | Hard | Yield, defeat cost |
| Battle Resolution, #30, #32, Refit, Loot, Contracts, Markets, Debrief, Dossier | Hard (reverse) | API |

Bidirectional check: Settings, Standing, Hulls and Vigor name this system.

## Tuning Knobs

| Knob | Default | Safe range |
|---|---|---|
| Upkeep per size class | 60 / 120 / 240 / 480 | ±50 % |
| `SALVAGE_CR_PER_DP` | 20 | 10 – 40 |
| `BOUNTY_BASE` | 4,000 | 2,000 – 8,000 |
| `LOST_SALVAGE_PM` | 500 | 250 – 750 |
| `RECOVER_PM` | 100 | 50 – 200 |
| `DEFEAT_CAP_DAYS` | 15 | 15 – 30 |
| `FREE_CORE_SHIPS` | 1 | 0 – 2 |
| `SUPPRESS_BUY_BASE` | 5,000 | 2,500 – 10,000 |
| `SUPPRESS_UPKEEP_BASE` | 60 | 30 – 120 |
| Warning threshold | 3 days | 1 – 7 |

All in `assets/data/economy/`.

## Visual/Audio Requirements

None of its own; a soft cue on mothballing and on the upkeep warning.

## Game Feel

- **Bills are never surprises**: the cap is shown before a fight.
- **Broke is a setback, not an ending.**

## UI Requirements

- Wallet and hold always visible on campaign screens; daily upkeep shown.
- Pre-battle panel and Dossier: the defeat cap.
- Debrief: the itemised bill, the cap and any forgiven excess.
- Ledger: transaction log by cause.
- 📌 **UX Flag — Credits, Upkeep & Sinks**: include wallet, upkeep, cap and log in
  the campaign and Debrief UX specs.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Yield, defeat cost, floor | `design/gdd/gameplay-settings-and-modifiers.md` | Rules 9, 13; D2, D3 | Formula dependency |
| Daily event, defeat skip | `design/gdd/world-clock.md` | Rules 6, 13 | Rule dependency |
| Standing side of suppression | `design/gdd/faction-reputation-and-standing.md` | Rules 5, 7 | Boundary |
| Scar line gate | `design/gdd/hulls-and-ship-definition.md` | Rule 8; Open Question 1 (signed off here) | Gate |
| Rest days | `design/gdd/vigor.md` | D4; Open Question 5 | Data dependency |

## Acceptance Criteria

- **AC-01 (Logic; rule 1)**: the wallet never goes below 0 after any API call (property test over 10,000 random operations).
- **AC-02 (Logic; D1)**: the D5 fleet gives `U_day` = 420.
- **AC-03 (Logic; rule 6)**: with wallet 300 and a bill of 420, the highest-upkeep line ship is mothballed and 300 is charged.
- **AC-04 (Logic; rule 5)**: the flagship and the core escort are never charged or mothballed.
- **AC-05 (Logic; D2)**: the D5 defeat gives bill 5,720 and cap 6,300 on Standard; 8,040 and 9,450 on Admiral.
- **AC-06 (Logic; rule 7)**: a bill above the cap is charged at the cap and the excess logged as `DEFEAT_FORGIVEN`.
- **AC-07 (Logic; rule 7)**: a defeat with base 1 at dcp 250 costs at least 1 credit.
- **AC-08 (Logic; rule 8)**: an opening loss bills 0 and leaves the hold unchanged.
- **AC-09 (Logic; rule 4)**: no daily upkeep fires during a defeat skip, and the bill includes days × `U_day`.
- **AC-10 (Logic; D4)**: suppression upkeep as a share of income is equal within ±1 ‰ on all three presets (Gameplay Settings & Modifiers AC-19).
- **AC-11 (Logic; rule 12)**: a `spend` that cannot be covered changes nothing and returns REFUSED.
- **AC-12 (Logic; rule 10)**: the log keeps 512 entries, and lifetime totals per cause equal the sum of all deltas.
- **AC-13 (Logic; rule 11)**: a save round trip reproduces wallet, hold, log and mothball flags exactly.
- **AC-14 (Logic; rule 13)**: on Chronicler a defeat costs at least 1 day plus a rest of at least 1 day, and leaves 30 % of a line ship's hull scarred until that rest.
- **AC-15 (Integration; rule 5)**: from wallet 0, the free core wins a skirmish and reactivates a ship within one battle.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Late-game money pile-up**: once the refit catalogue runs out (estimated near hour 60), the wallet grows ~1,200/hour. Lasting sinks: fleet growth, suppression, colonies (post-MVP). | economy-designer | When Refit & Loadout and Loot & Crafting have price lists |
| 2 | **Counter affordability**: every Dossier counter must have a version costing ≤ one expedition's Standard income (~16,000). | Machine Nodes & Strongholds, Refit & Loadout | When designed |
| 3 | **All figures** are starting values; no balance data yet. | economy-designer, `/balance-check` | When `assets/data/economy/` exists |
