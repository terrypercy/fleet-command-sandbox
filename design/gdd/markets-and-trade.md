# Markets & Trade

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — trade funds the next attempt); Pillar 4 (Plan in the Open — prices and margins are shown before you commit)

## Summary

Markets & Trade at MVP is stub-depth: at any port with a market (every free port has one) the player sells the salvage hold into the wallet at a fixed, deterministic rate, full at a free port or Neutral and better, 900 ‰ at Wary, never more than full, so standing is never a money source. Goods, prices and a route gate that keeps trading a top-up rather than a career are specified now but stay disabled until the Ledger tier; nothing varies with the seeded maker.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Credits, Upkeep & Sinks, Sector Map & Travel`

## Overview

Markets & Trade turns the **hold** into the **wallet**. Battles put salvage into
the hold (Credits, Upkeep & Sinks rule 2), and Refit spends from the wallet only
(Refit & Loadout rule 16). At MVP this system is **stub depth**: one service,
`market`, at the ports that list it, which sells salvage from the hold at a fixed,
authored rate set by the owner's band. There are no trade goods, no stock, no
randomness and no live prices at MVP. The rules for goods and routes are fixed here
now (schema, price discipline, the route-margin gate) so that the later tier can
switch them on without re-deciding them. Markets leaves stub depth only when the
Ledger (#48) exists to plan routes in the open (Creative Director note). The
living faction economy (Background Faction Economy, #43) writes prices later
through this system's API, never around it. The concept's MVP line is "a basic
market to fund refits" (concept, MVP item 7); "plan trade runs with the Ledger"
is the later tier.

## Player Fantasy

You limp into a free port with a hold full of scorched hull plate. Before you
choose a refit, you sell it: the screen shows the hold, the rate, and the exact
credits you will get. A Wary port pays a little less, and the screen says so and
names the nearest port that pays full. The fantasy is the quartermaster's, not the
merchant's: salvage is the lead you bring home from a fight, and the market is
where it becomes the next attempt (Pillar 1). Nothing is hidden. Every rate is
fixed and shown before you commit (Pillar 4).

*Anchor moment:* after a won fight, the port hub reads "Hold 2,400". One press of
"Sell all" moves it to the wallet, and the Refit screen behind it lights up with
what you can now afford.

## Detailed Design

### Core Rules

**A. Where the market is**

1. **The market needs the `market` service.** The market is open at a docked port
   that lists `market` in `services[]` (Ports, Rest & Care rule 3). This system
   registers the provider at MVP:
   `register_service(market, port_market, trade, available(port))` (Ports rule 22).
   The privilege `trade` is held at band Wary and above (Faction Reputation rule 3)
   and always at a free port.
2. **`available(port)`** returns OK when the hold is above 0, and otherwise the
   reason "Hold empty". At MVP there is nothing else to do at a market.
3. **Every free port has a market.** A free port (owner `none`) that does not list
   `market` fails content load with `MARKET_FREE_PORT_MISSING`. Every region has a
   free port (Sector Map rule 3), so the hold can always be sold at the full rate
   without standing, whatever the player has learned or said about the maker.
4. **Truth-neutral.** No rate, port listing or (later) good, stock or price may
   vary with the seeded maker. The band table (rule 7) is one fixed table. A
   port's band is player-caused standing, read through Faction Reputation; the
   rate it maps to is the same in every seed.

**B. Selling the hold**

5. **The hold is one integer** in credits, owned by Credits (rule 1 there). Its
   value was already scaled by `yield_permille` when the salvage was credited
   (Credits rule 2). A sale is therefore **unscaled**: selling never applies the
   yield twice (matching Refit's edge rule for sell credits).
6. **A sale** takes an amount `a`, 1 ≤ `a` ≤ `hold`, and pays `proceeds(a)` (D1).
   It is one atomic Credits call, `sell_hold(a, proceeds, MARKET_SALVAGE_SALE,
   port_id)`: the hold falls by `a` and the wallet rises by `proceeds` in one log
   entry, or nothing changes. "Sell all" is `a = hold`.
7. **The rate is set by the owner's band** (the Wary "price hook", Faction
   Reputation rule 3):

   | Port | `rate_pm` |
   |---|---|
   | Free port | `SALVAGE_RATE_PM` (1,000) |
   | Allied, Trusted, Neutral | `SALVAGE_RATE_PM` (1,000) |
   | Wary | `SALVAGE_WARY_PM` (900) |
   | Hostile | no docking (Faction Reputation rule 3) |

   No band pays above `SALVAGE_RATE_PM`. Standing is never a money faucet.
8. **No zero sales.** A sale whose `proceeds` would be 0 is refused ("Too little
   to sell here"). The leftover stays in the hold.
9. **Selling is a planning action.** The market screen is `PLANNING:port_market`
   (World Clock rule 3). A sale costs no time and moves no clock.

**C. Goods and routes (defined now, empty at MVP)**

10. **Goods are a content kind, `trade_good`**, schema owned here:
    `id`, `name`, `base_price` (1 – 1,000). A port's market may name a
    `market_list` of `{good, buy_pm, sell_pm}`. **At MVP the base game ships no
    `trade_good` and no `market_list`.** Loading one before the Ledger tier is
    enabled logs `MARKET_GOODS_DISABLED` and ignores it.
11. **Price discipline (any tier).** At every port `sell_pm ≤ buy_pm`, so no
    buy-then-sell at one port gains (error `MARKET_SAME_PORT_GAIN`). Prices are
    fixed authored numbers × `yield_permille`, as in Refit D1, so a route earns
    the same share of income on every preset.
12. **The route-margin gate** (D3). No loop of ports may earn more per day than
    `ROUTE_CAP_PM` of the reference combat income. Content that breaks it fails
    load with `MARKET_ROUTE_MARGIN`. At MVP there are no goods, so the gate holds
    trivially; it is stated now so the later tier inherits it.
13. **Cargo is not defined at MVP.** Hulls & Ship Definition has no cargo field.
    The hold is uncapped credits value, not mass. Goods need a capacity
    (`CARGO_REF` in D3 is a placeholder); Hulls owns that field when it comes.

**D. Determinism, save and hooks**

14. **Deterministic.** All maths is integer, rounding toward zero. No RNG stream,
    no clock read. The same hold, port and band give the same proceeds on every
    machine.
15. **No save section at MVP.** The hold and wallet live in `base:credits`.
    Markets holds no state of its own. The later tier adds `base:markets`
    (price and stock state), registered with Save/Load & Migration.
16. **API** (no engine types): `quote_sale(port, a) → proceeds | reason`,
    `sell(port, a) → OK | REFUSED(reason)`, `rate_pm(port)`; signal
    `salvage_sold(port, a, proceeds)`. Reserved for later tiers, not built at MVP:
    `quotes(port)` (Ledger read), `set_price_pm(port, good, pm, cause)` (the only
    write path for Background Faction Economy, systems index contract), and
    `deliver(good, qty, ref)` for Contracts & Missions.

### States and Transitions

| State | Entered when | Leaves to |
|---|---|---|
| Not listed | the port does not list `market` | (port data) |
| Not yet available | listed, no provider registered (before this system loads) | Open, Hold empty |
| Refused | owner band Hostile (docking refused) | Open, Hold empty (band rises) |
| Hold empty | listed, provider registered, `trade` held, hold = 0 | Open (salvage credited) |
| Open | listed, registered, `trade` held, hold > 0 | Hold empty (sell all) |

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Credits, Upkeep & Sinks (#18) | both | Reads `hold()`; writes through `sell_hold(a, proceeds, cause, ref)` (amendment) |
| Ports, Rest & Care (#27) | #37 → #27 | `register_service(market, port_market, trade, available)`; hub header already shows the hold |
| Faction Reputation & Standing (#17) | #17 → #37 | `band(owner)`, `can(owner, trade)`; the Wary rate is rule 7 here |
| Sector Map & Travel (#26) | #26 → #37 | Port and system IDs, free ports, `travel_time()` for the nearest full-rate port and D3 |
| Refit & Loadout (#35) | peers | Refit owns gear; Markets owns salvage and goods; Refit's header links to the nearest market |
| Gameplay Settings & Modifiers (#7) | #7 → #37 | `yield_permille` scales goods prices (later); never salvage sales |
| World Clock (#8), Simulation Tick (#1) | #37 → them | `PLANNING:port_market` hold |
| Content Data & Mod Loading | #37 → it | `trade_good`, `market_list` schemas; validation errors |
| Ledger (#48), Background Faction Economy (#43), Contracts (#38) | them → #37 | Later: `quotes`, `set_price_pm`, `deliver` |
| Salvage & Recovery (#36) | peers | #36 recovers wrecks into the hold; #37 sells the hold |

## Formulas

All values are integers. `div` rounds toward zero.

### D1. Salvage sale

`proceeds(a, port) = a × rate_pm(port) div 1,000`

- `a`: amount sold, 1 – `hold` (hold up to about 10^6 in play; 64-bit safe).
- `rate_pm`: rule 7, 500 – 1,000.
- Output: 0 – `a`. A result of 0 is refused (rule 8).

Example: hold 4,800 (Credits D5). Free port: **4,800**. Wary:
4,800 × 900 div 1,000 = **4,320**.
Split check: selling 2,401 then 2,399 at Wary gives 2,160 + 2,159 = **4,319**,
not more than 4,320. Since `⌊x⌋ + ⌊y⌋ ≤ ⌊x + y⌋`, splitting a sale never gains.
Because `rate_pm ≤ 1,000` and the hold only fills from battles, no sale can
create credits beyond the salvage that earned them.

### D2. Detour break-even (shown, not enforced)

`cut = a − proceeds(a, port)`
`break_even_s = cut × 86,400 div U_day` (when `U_day` > 0)

- `U_day`: Credits D1, 0 – about 5,000.
- Output: the extra travel time at which going to a full-rate port stops paying.

Example (D5 fleet, `U_day` 420): hold 4,800 at Wary, cut 480;
480 × 86,400 div 420 = **98,742 s** (about 1.1 days). If the nearest full-rate
port is more than about 1.1 days further than staying, selling here is cheaper.
The market screen shows both numbers (UI Requirements).

### D3. Route-margin gate (later tier; vacuous at MVP)

For every directed loop `L` of market ports `p0 → p1 → … → p0`:

`leg_margin(i) = max(0, max_g (sell(p_{i+1}, g) − buy(p_i, g))) × CARGO_REF`
`loop_s = Σ travel_time(p_i, p_{i+1}, SPEED_LIGHT)` (fastest legal fleet: worst case)
`margin_day(L) = Σ leg_margin(i) × 86,400 div loop_s`
Pass when `margin_day(L) ≤ INCOME_REF_DAY × ROUTE_CAP_PM div 1,000`.

| Variable | Default | Range |
|---|---|---|
| `CARGO_REF` | 30 units (placeholder; Hulls owns cargo) | 10 – 200 |
| `INCOME_REF_DAY` | 633 credits/day (Credits D4 worked fleet) | follows Credits |
| `ROUTE_CAP_PM` | 500 | 250 – 1,000 |
| `SPEED_LIGHT` | 1,200 mu/day (Sector Map) | follows Sector Map |

Worked check (illustrative good, not shipped): resin bought at A for 40, sold at
B for 52; lane 1,200 mu. Leg time 1,200 × 86,400 div 1,200 = 86,400 s; loop
A → B → A = 172,800 s. Margins: A → B 12 × 30 = 360; B → A 0.
`margin_day` = 360 × 86,400 div 172,800 = **180**. Cap 633 × 500 div 1,000 =
**316**. 180 ≤ 316: passes. Note that 316 is below the D5 fleet's upkeep (420):
at the default, trading alone never pays a mid fleet's upkeep; it tops up the
trips you make anyway (Open Question 2).

### D4. Effect on the Credits worked economy

`salvage_income_30d = Σ salvage × rate_pm div 1,000`

D5 (Credits) assumes par sale: 4 × 2,400 = 9,600. At par, net stays **+4,000**
(no defeat) and **+800** (one defeat). Worst case, every sale at Wary:
9,600 × 900 div 1,000 = 8,640, so 960 less: **+3,040** and **−160**. Rule 3
guarantees par is always reachable, so Credits OQ 2 (`COUNTER_COST_CAP`, derived at
par) still holds for a player who sells at a free port.

## Edge Cases

- **If the hold is 0**: the service shows "Hold empty"; `sell` returns REFUSED.
- **If `a` > hold or `a` < 1**: REFUSED, nothing changes.
- **If proceeds would be 0** (for example 1 credit at Wary): refused; the 1
  stays in the hold until a full-rate port.
- **If the band changes after the quote**: the screen is a planning hold, so no
  writes arrive while it is open; `sell` still recomputes the rate at confirm.
- **If the owner is Hostile**: docking is already refused; the market is never
  reached.
- **If the player sells before a risky fight**: allowed and intended. Lost salvage
  (Credits D2) only takes what is still in the hold. Banking salvage costs the
  trip to port.
- **If a defeat happens**: the hold loss is Credits' rule; Markets does nothing.
  On an opening loss the hold is untouched.
- **If a port lists `refit` but not `market`**: Refit's header names the nearest
  port with an available market and its travel time (amendment to Refit rule 16).
- **If a mod ships `trade_good` content at MVP**: logged `MARKET_GOODS_DISABLED`,
  ignored, no crash.
- **If `SALVAGE_WARY_PM` is tuned above `SALVAGE_RATE_PM`**: load error
  `MARKET_RATE_ORDER`; Wary never pays more than full rate.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Credits, Upkeep & Sinks (#18) | Hard | `hold()`, `sell_hold(...)` (amendment), log cause `MARKET_SALVAGE_SALE` |
| Sector Map & Travel (#26) | Hard | Port IDs, free ports, `travel_time()` |
| Ports, Rest & Care (#27) | Hard | `register_service`, hub |
| Faction Reputation & Standing (#17) | Hard | `band`, `can(owner, trade)` |
| Content Data & Mod Loading | Hard | Schemas and validation |
| World Clock (#8), Simulation Tick (#1) | Hard | Planning hold |
| Gameplay Settings & Modifiers (#7) | Soft (later) | `yield_permille` for goods |
| Refit & Loadout (#35) | Soft (reverse) | Hold sales; shared hub |
| Salvage & Recovery (#36) | Soft (reverse) | Fills the hold (Vertical Slice) |
| Ledger (#48) | Gate (reverse) | Markets leaves stub depth only with it |
| Background Faction Economy (#43), Contracts (#38) | Hard (reverse, later) | `set_price_pm`, `deliver` |
| Port & Fleet Management Screens (#50) | Hard (reverse) | Market screen |

## Tuning Knobs

| Knob | Default | Safe range | Kind | Affects |
|---|---|---|---|---|
| `SALVAGE_RATE_PM` | 1,000 | 1,000 (fixed at MVP) | Gate | Credits D5 assumes par; changing it re-derives Credits D5 and OQ 2 |
| `SALVAGE_WARY_PM` | 900 | 500 – 1,000, ≤ `SALVAGE_RATE_PM` | Curve | Cost of trading with a wary faction; D2 detour |
| Market privilege | `trade` | `dock`, `trade` | Gate | Lowest band that can sell |
| `ROUTE_CAP_PM` | 500 | 250 – 1,000 | Gate | Trade's ceiling against combat income (D3) |
| `CARGO_REF` | 30 | 10 – 200 | Placeholder | D3 only, until Hulls defines cargo |
| `INCOME_REF_DAY` | 633 | follows Credits D4 | Derived | D3 cap |

## Visual/Audio Requirements

- Sale confirm: a short ledger-tick sound and the wallet figure counting up. No
  coin-shower; the tone is a quartermaster's book, not a casino.
- The Wary rate is shown in the band's colour with its name, never by colour
  alone.

## Game Feel

- One press to sell all. Selling is never a chore between a fight and a refit.
- The cut at a Wary port should read as a fair cost of standing, not a trap: the
  full-rate alternative and its travel time are always on screen.

## UI Requirements

- Header (shared hub): wallet, hold, owner and band (or "Free port").
- Body: rate (for example "Wary: 900 ‰"), the quote for the chosen amount, "Sell
  all", an amount field (1 – hold).
- At a sub-par rate: the cut in credits, the nearest full-rate port, its travel
  time, and D2's break-even ("A free port pays 480 more; worth it within 1.1
  days").
- Refused states name their reason ("Hold empty", "Too little to sell here").

## Cross-References

| Topic | Document | Section | Kind |
|---|---|---|---|
| Wallet, hold, salvage faucet, defeat loss | `design/gdd/credits-upkeep-and-sinks.md` | Rules 1–3, 7, 12; D2; D5; OQ 1–2 | Data dependency |
| Gear buy/sell split, sell-back discipline | `design/gdd/refit-and-loadout.md` | Rules 1, 2a, 16; D1–D2 | Peer rule |
| Service hook, hub header | `design/gdd/ports-rest-and-care.md` | Rules 3, 22 | Interface |
| Wary price hook, `trade` privilege | `design/gdd/faction-reputation-and-standing.md` | Rule 3 | Interface |
| Free ports, travel time, speeds | `design/gdd/sector-map-and-travel.md` | Rule 3; D3; Tuning | Data dependency |
| `yield_permille` | `design/gdd/gameplay-settings-and-modifiers.md` | Preset table | Data dependency |
| MVP market, Ledger trade runs, Starlathe tier | `design/gdd/game-concept.md` | MVP item 7; comparables | Vision |

## Acceptance Criteria

- **AC-01 (Logic; rule 1)**: at a port without `market`, the service is not listed; at a Wary or free port with a hold above 0, `available` returns OK.
- **AC-02 (Logic; rule 2)**: with hold 0, `available` returns "Hold empty" and `sell` returns REFUSED.
- **AC-03 (Logic; rule 3)**: a free port without `market` fails load with `MARKET_FREE_PORT_MISSING`.
- **AC-04 (Logic; rule 4)**: for two seeds with different makers and identical standing, every port's `rate_pm` and listing are identical.
- **AC-05 (Logic; D1)**: selling hold 4,800 credits exactly 4,800 at a free port and 4,320 at a Wary port, with one log entry of cause `MARKET_SALVAGE_SALE`; hold ends at 0.
- **AC-06 (Logic; rule 5)**: proceeds are identical on Admiral, Standard and Chronicler for the same hold (no yield applied at sale).
- **AC-07 (Logic; D1)**: property test: for any hold and any split into sales at one port, total proceeds ≤ one whole sale.
- **AC-08 (Logic; rule 6)**: a sale with `a` > hold, or `a` = 0, changes neither wallet nor hold.
- **AC-09 (Logic; rule 8)**: selling 1 at Wary is refused and the hold stays 1.
- **AC-10 (Logic; rule 7)**: no band yields `rate_pm` above `SALVAGE_RATE_PM`; a config with `SALVAGE_WARY_PM` 1,100 fails with `MARKET_RATE_ORDER`.
- **AC-11 (Logic; rule 9)**: opening the market and selling the whole hold over 600 frames leaves `clock_s` unchanged.
- **AC-12 (Logic; D2)**: for cut 480 and `U_day` 420, the quoted break-even is 98,742 s.
- **AC-13 (Logic; rule 10)**: loading a `trade_good` at MVP logs `MARKET_GOODS_DISABLED` and adds no good.
- **AC-14 (Logic; D3)**: with goods enabled in a test fixture, the resin loop gives `margin_day` 180 and passes; raising B's sell price to 60 gives 600 × 86,400 div 172,800 = 300 (passes) and to 64 gives 720 × 86,400 div 172,800 = 360 (fails `MARKET_ROUTE_MARGIN`, cap 316).
- **AC-15 (Logic; rule 11)**: a fixture with `sell_pm` > `buy_pm` at one port fails `MARKET_SAME_PORT_GAIN`.
- **AC-16 (Logic; rule 14)**: a save round trip after a sale reproduces wallet, hold and log exactly (Credits section only).
- **AC-17 (Integration; D4)**: in the Credits D5 script, selling every hold at a free port gives net +4,000 without the defeat.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **MVP trade is the hold sale only**; goods wait for the Ledger tier (#48).
- **Trade is a top-up at MVP, not a career**: `ROUTE_CAP_PM` 500, so trading
  alone never pays a D5 fleet's upkeep; the living economy may raise it.
- **Wary pays 900 ‰; Neutral and above stay at par**, so standing is never a
  money faucet.

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Cargo capacity: add a hull `cargo` field, or a fleet-wide cap like `STORES_CAP`? Hulls' edge cases say "moves to cargo" where Refit says "stores". | Hulls owner | Before goods are enabled |
| 2 | `INCOME_REF_DAY`: Credits D4 implies 633/day; Credits D5 gross income is 16,600 / 30 = 553/day. Which is the reference? | economy-designer (Credits) | Next Credits review |
| 3 | Credits OQ 1 (late money pile-up): Markets adds no sink at MVP. Should the later tier's goods include a lasting sink (for example, purchasable supplies)? | economy-designer | When Ledger tier is scoped |
| 4 | Boundary with Salvage & Recovery (#36, Vertical Slice): #36 fills the hold and owns the `salvage` service; #37 sells the hold. Confirm. | Salvage owner | When #36 is designed |
