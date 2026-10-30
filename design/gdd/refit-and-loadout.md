# Refit & Loadout

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (Deep Vein costs ceiling erosion, not flux; MODULE_CHEAP_COST and WEAPON_DOMINATES; 'Kit fitted' not 'Realised'; mothball and clamp shown; truth-neutral stock)
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — the refit is where a named counter becomes a fleet change); Pillar 4 (Plan in the Open — every fit shows what it counters and costs before you commit)

## Summary

Refit & Loadout fits weapons and modules onto ships at ports that offer refit, from a fixed per-port stock, as an instant staged draft committed with one atomic payment and no days. A weapon fits a mount whose family accepts it and whose size is at least as large; modules are trades that always carry a cost, never raw power. Prices scale with `yield_permille`, sell-back can never profit, and the screen shows truthfully which revealed Dossier counters the fleet realises and what the cheapest kit still costs, the same price Machine Nodes uses to keep every counter affordable.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Hulls & Ship Definition, Weapons & Damage, Credits, Upkeep & Sinks`

## Overview

Refit & Loadout is where a counter-fleet is built. At a port that offers the
`refit` service, the player buys gear (weapons and modules), fits it into the
mounts and module slots that Hulls & Ship Definition (#10) defines, sells gear
back, and keeps unfitted gear in the fleet's **stores**. A refit is staged as a
draft inside a `PLANNING:port_refit` hold, so it costs no days, and is
committed as one order with one atomic payment. This system owns the `module`
and `refit_stock` content kinds, the fitting predicate `fits(item, slot)`, the
gear prices that Machine Nodes & Strongholds (#23) D6 and the AI-vs-AI Runner
read as "Refit & Loadout's price", and the screen line that says, truthfully,
which Dossier counters the current fit realises and what the cheapest missing
kit costs. Trade goods and salvage sales stay with Markets & Trade (#37); gear
is bought and sold here only.

## Player Fantasy

*"The Debrief said the relay held. So I docked, sold the thorns off two line
ships, bolted Rootcutters on, and watched the Dossier line turn green: Relay
cut, fitted."* Refit is the moment a defeat becomes a plan. The player should
feel like an engineer answering a question the enemy asked, not a shopper
buying a bigger number.

- **Pillar 1 (readable defeats, counters you work out)**: every fit is shown
  against the counters the Dossier knows, so the link from "what beat me" to
  "what I fit" is one screen.
- **Expression (MDA, rank 5 in the concept)**: weapons of one size cost the
  same and modules are trades, so a fit says what the player believes about a
  fight, not how rich they are.
- **Pillar 5 (living against made)**: organic gear goes on organic hulls only;
  grafts and kits never cross.

SDT: **Autonomy** (several kits realise each counter); **Competence** (the
counter line confirms the reasoning before the fight); **Relatedness** (light:
which ports stock which gear is a property of who owns them).

## Detailed Design

### Core Rules

**A. Where refit happens**

1. **Refit needs the `refit` service.** Refit is open at a docked port that
   lists `refit` in `services[]` (Ports, Rest & Care rule 3). This system
   registers the provider at MVP:
   `register_service(refit, port_refit, trade, available(port))` (Ports rule 22).
   `available` returns OK when the port has a `refit_stock`, and otherwise the
   reason "No yard here". The privilege `trade` is held at band Wary and above
   (Faction Reputation rule 3) and always at a free port.
2. **One content kind, `refit_stock`** (body owned here): `items[]`, a list of
   refs to `weapon` or `module` definitions, 1 – 40 entries, no duplicates. A port
   that lists `refit` names exactly one `refit_stock` (new port field
   `refit_stock`, amendment to Ports rule 1). Stock is fixed: no randomness, no
   quantities, no restocking. Every listed item can be bought any number of
   times.
2a. **Truth-neutral stock.** No stock list, price or gear definition may vary
    with the seeded maker. Machine gear (when it exists) carries no race
    attribute (lore bible §6: the Instrument has no race lineage).
3. **Stock validation** (content load, errors):
   - `REFIT_STOCK_MISSING`: a port lists `refit` with no `refit_stock`, or names
     one without listing `refit`.
   - `REFIT_STOCK_UNFITTABLE`: an item fits no mount or slot of any hull the
     player can own (at MVP: organic hulls only; Hulls rule 6).
   - `REFIT_KIT_UNSTOCKED`: for each solo counter (`requires_allies` false),
     every weapon and module in its cheapest kit (D4) must be in the stock of at
     least one free port, and a counter's kit may not be stocked only at one
     race's ports. A counter that needs no ally must never need standing
     either (Machine Nodes rule 19; Sector Map rule 3 gives every region a free
     port).
4. **Gear unlocks are Alpha.** At MVP everything in a stock is buyable. Loot &
   Crafting (#39) later adds gear to stores and may add items to stocks. It
   must not bypass rule 7, rule 9 or the price bands (D6).

**B. Gear and fitting**

5. **Weapons** are Weapons & Damage's `weapon` definitions. This system reads
   `family`, `size`, `dmg_type`, `feed` and one new field, `base_price`
   (amendment to Weapons rule 1; range in D6).
6. **One content kind, `module`** (body owned here):
   | Field | Type | Range | Notes |
   |---|---|---|---|
   | `name_key` | text key | 1 | |
   | `module_class` | enum | `graft`, `kit` | must match the slot (Hulls rule 5) |
   | `mods[]` | list of `{stat, permille}` | 2 – 4 | `stat` from rule 7's list; `permille` −`MODULE_MOD_MAX_PM` – +`MODULE_MOD_MAX_PM`, never 0 |
   | `base_price` | int | D6 band | |
7. **A module is a trade, never raw power** (concept: gear unlocks a counter).
   - `stat` is one of `armour`, `max_speed`, `accel`, `turn_rate`,
     `vigor_flow`, `vigor_ceiling_erosion` (graft only; scales the erosion
     Vigor charges from spending, Vigor rule 9), `membrane_permille` (graft
     only), `ward_points` (kit only).
   - Every module has at least one positive and at least one negative entry.
     Error `MODULE_NO_COST` otherwise. The sum of its negative permille must be
     at least half the sum of its positive permille (counting an erosion
     increase as negative), or it fails `MODULE_CHEAP_COST`: a token cost
     never hides raw power.
   - One stat appears at most once per module. Error `MODULE_DUP_STAT`.
   - Effects enter the instance's modifier list (Hulls rule 12) and are
     derived on load, never saved as stats (Hulls rule 2). The maths is D7.
8. **The fitting predicate.** `fits(item, slot)` is true when:
   - **weapon in a mount**: `family` is in the mount's `accepts` and
     `size_rank(weapon) ≤ size_rank(mount)` (S 1, M 2, L 3). **Size-down is
     allowed with no penalty**: a smaller gun is its own penalty;
   - **module in a module slot**: `module_class` equals the slot's
     `module_class`;
   - anything else is false.
   Arcs, facings and positions belong to the mount and never change at refit.
   `fits` is the single predicate the Runner uses (rule 22).
9. **No power or slot budget at MVP.** Organic guns already pay Vigor per shot
   (Weapons rule 1, `vigor_per_shot`). Vigor is a living reserve that erodes
   and is restored only at port, not a capacity to vent. A slot holds at most
   one item. A mount or slot may be empty.
10. **Fitted ships must still make sense.** At commit:
    - a non-relay **machine** hull in the player fleet must keep at least one
      unfed mount holding an unfed weapon (`REFIT_NO_UNFED_GUN`; Hulls rule 6,
      Coherence & Links rule 6). No machine hull is in the player fleet at MVP,
      so this rule is dormant until then;
    - a ship with every mount empty is allowed, with the warning "Unarmed".
      The flagship with no PRIMARY weapon gets the warning "No primary guns".
      Warnings never block.

**C. The draft and the commit**

11. **Opening refit.** The Refit screen is `PLANNING:port_refit`: the World
    Clock is held (World Clock rule 3), so nothing in the draft costs days and
    no event can fire while it is open.
12. **The draft.** Every change is staged, not applied: buy into stores, sell
    from stores or from a slot, fit from stores into a slot, unfit to stores,
    move between ships, set a flagship mount's group (rule 18). The draft shows
    the running net cost (D3) and the stores count. Undo and Reset are free.
13. **Eligible ships.** The draft may touch every owned ship travelling with
    the fleet: active and mothballed. It may not touch:
    - **lent ships** (Allied Lending): shown read-only, "Lent by {faction}";
    - ships **laid up at another port** (Ports rule 23): not listed.
    A ship laid up at this port is eligible.
14. **Commit** is one order `refit_commit(diff)`, stamped with its tick. It:
    - re-validates the whole diff (rules 8, 10, 15);
    - if `net > 0`, calls Credits `spend(net, REFIT_BUY, port_id)`, atomic; on
      `REFUSED` nothing changes and the reason "Wallet short by {n}" shows;
    - if `net < 0`, credits `−net` with cause `REFIT_SELL` through an unscaled
      credit (amendment to Credits rule 12, D2 note);
    - applies every loadout, stores and group change in one step, emits
      `refit_committed(diff)` and closes nothing else.
    Commit is disabled, with the reason, while the draft is invalid or the
    wallet is short. Closing the screen with an uncommitted draft asks
    "Discard changes?".
15. **Stores.** One fleet-wide list `{content_id, count}`, capped at
    `STORES_CAP` (48) items in total. Stores travel with the fleet, cost
    nothing to keep, and are only usable at a refit port. A draft that would
    leave stores above the cap cannot commit ("Stores full: sell or fit {n}").
16. **The hold is not the wallet.** Refit spends from the wallet only. Salvage
    in the hold must first be sold through Markets (#37). The Refit header
    shows wallet and hold, and "Sell salvage at the market" when the hold is
    above 0 and the wallet is short.

**D. Prices**

17. **Prices.** Buy at D1, sell at D2, net by D3. Moving, fitting and
    unfitting are free (`FIT_FEE` 0). Prices scale with `yield_permille`, like
    suppression (Credits rule 9), so a counter costs the same share of income
    on every preset. Prices do not change with faction band at MVP. The prices
    Machine Nodes D6 uses are **base prices** (D4), the Standard-yield
    figure.

**E. Groups and counters**

18. **Fire groups.** Each mount on the **flagship** has `weapon_group`
    (PRIMARY, SECONDARY, AUTO; Flagship Piloting rule 6). At refit:
    - the group is set per mount in the draft, free;
    - a mount keeps its group when its weapon is swapped or removed, so a
      player's layout survives a refit;
    - a mount that has never been set takes Flagship rule 6's default when
      it first receives a weapon;
    - if the flagship changes to another ship, that ship's unset mounts take
      the defaults.
    Escort mounts have no group: they fire by Ship AI (Weapons rule 3).
19. **The counter line.** The Refit screen lists every counter the Dossier
    shows for a known node, and for each one state, computed from data only:
    - **Kit fitted**: some kit's weapons and modules are all fitted on eligible
      **active** ships (D5 = 0 with nothing taken from stores), with the
      tooltip "The Dossier's counter is fitted. You still have to win it."
      Orders are not gear: they are listed as "plus order: {order}" and never
      block Kit fitted;
    - **In stores**: D5 is 0 but some items are in stores, not fitted;
    - **Missing**: D5 > 0, shown as "{k} items away ({cost})" with the kit
      named.
    Lent ships' gear counts toward the state, marked "(with lent ships)", and a
    counter fitted only with them is shown as such, never as solo. Mothballed
    ships' gear never counts, and the line says so: "{ship} is mothballed: its
    gear does not count." In the Hull view each module-affected stat shows its
    effective value, with "capped at +500‰" (or −500‰) when D7's clamp
    applies.
    Each line also shows the counter's **cheapest kit cost** (D4 at the
    current yield) — the same figure the Dossier shows (Machine Nodes UI).
    The state updates on every draft change.

**F. Edge rules: the opening, determinism and save**

20. **The opening.** The starting fleet carries the Runner reference fleet's
    default loadouts (Runner rule 10) and empty stores. There is no refit
    before the first docking at a refit port. The opening battle is fought on
    default loadouts.
21. **Determinism.** All prices and states are integer functions of content,
    `yield_permille` and the saved loadouts. Nothing here draws randomness.
    No refit happens in battle, so a weapon's hit stream key
    `base:combat.hit#<ship_id>/<slot>` (Deterministic RNG Core Rule 5) never
    changes mid-battle, and `slot_id` keys stay stable because refit never adds
    or removes slots.
22. **The Runner's fitting rule** (Runner rule 11) uses `fits` (rule 8).
    Items are taken in kit order, weapons then modules, in list order; ships in
    ascending Runtime ID; slots in ascending `slot_id`. Duplicate entries are
    separate items. The Runner pays nothing and ignores stores and stock.
23. **Save.** Loadouts live on the ship instance (`loadout`, Hulls rule 12);
    groups live on the flagship instance (Flagship rule 6). This system saves
    section `base:refit`, version 1, after `base:credits`, ceiling 2,048
    bytes: stores and the per-mount "group set" flags. A gear definition missing
    on load follows Content Data Core Rule 13: fitted, it leaves the slot
    empty; in stores, the entry is kept inert, shown "Missing content", worth
    0, and may be discarded.
24. **API** (no engine types): `open(port) → OK | reason`, `fits(item, slot)`,
    `price(item)`, `sell_price(item)`, `base_price(item)`,
    `kit_price(kit)`, `cheapest_kit(counter) → {kit_index, base_cost}`,
    `counter_state(counter, fleet) → REALISED | IN_STORES | MISSING(k, cost)`,
    `draft_*` staging calls, `commit() → OK | REFUSED(reason)`; signal
    `refit_committed(diff)`.

### States and Transitions

| State | Meaning | Exits |
|---|---|---|
| Closed | No refit screen open | Drafting (open at a refit port, `available` OK) |
| Drafting | `PLANNING:port_refit` held; changes staged | Committing (Commit, draft valid), Closed (discard) |
| Committing | One order: validate, pay, apply | Drafting (applied; new empty draft) or Drafting (REFUSED; draft kept) |

| Counter state | Condition | Exits |
|---|---|---|
| Missing | D5 > 0 | In stores, Kit fitted |
| In stores | D5 = 0, some kit item in stores | Kit fitted (fit), Missing (sell) |
| Kit fitted | a kit fully fitted on active ships | In stores, Missing (unfit, sell, mothball) |

### Interactions with Other Systems

| System | Direction | What |
|---|---|---|
| Hulls & Ship Definition (#10) | #10 → #35 | Mounts, module slots, `loadout`, modifier list |
| Weapons & Damage (#12) | #12 → #35 | `family`, `size`, `dmg_type`, `feed`, `base_price` |
| Credits, Upkeep & Sinks (#18) | #35 → #18 | `spend(REFIT_BUY)`, unscaled credit `REFIT_SELL`; reads `yield_permille` |
| Ports, Rest & Care (#27) | #35 → #27 | `register_service(refit, …)`; reads docking, lay-up port |
| Faction Reputation | #35 reads | `can(owner, trade)` |
| Machine Nodes & Strongholds (#23) | #35 → #23 | `kit_price`, `cheapest_kit` for rule 20, D6 and the Dossier |
| AI-vs-AI Runner | #35 → Runner | `fits`, fitting order (rule 22) |
| Flagship Piloting (#15) | #35 → #15 | `weapon_group` per mount |
| Allied Lending | reads | Lent flag (read-only ships) |
| Markets & Trade (#37) | peers | Markets owns goods and salvage; #35 owns gear |
| Loot & Crafting (#39, Alpha) | #39 → #35 | Adds gear to stores and stocks |
| Telemetry (#54) | #35 → #54 | `refit_committed(diff)` |

## Formulas

All values are integers. `÷` is integer division rounding toward zero.

### D1. Buy price

`price(i, y) = max(1, modifier_compose(base_price(i), y))` = `max(1, (base_price(i) × y + 500) div 1,000)`
(Gameplay Settings & Modifiers D2, rounding half up)

- `base_price(i)`: D6 band, 1 – 10,000.
- `y`: `yield_permille`, 500 – 1,500.
- Output: 1 – 15,000 credits.

Example: Rootcutter, base 1,800. Standard (1,000): **1,800**. Admiral (850):
1,800 × 850 ÷ 1000 = **1,530**. Chronicler (1,250): **2,250**.

### D2. Sell-back price

`sell(i, y) = price(i, min(y, 1,000)) × SELL_BACK_PM ÷ 1000`

Sell-back is computed at a yield of at most 1,000 ‰, so no change of setting
can make a buy-then-sell cycle profitable.

- `SELL_BACK_PM`: 500 (300 – 700).
- Output: 0 – 14,000.

Example: Thornspitter, base 800. Standard: 800 × 500 ÷ 1000 = **400**.
Admiral: price 680, sell **340**. Chronicler (1,250): price 1,000, sell
800 × 500 ÷ 1,000 = **400** (capped at yield 1,000).
Arbitrage check: buying at `y1` costs at least `base × 500 ÷ 1,000` (`y1` ≥
500); selling returns at most `base × 1,000 ÷ 1,000 × 500 ÷ 1,000` = the same
amount. So a cycle never gains, across the whole 500 – 1,500 range.

### D3. Draft net cost

`net = Σ_{bought} price(i, y) − Σ_{sold} sell(i, y)`

- Moves, fits and unfits add 0 (`FIT_FEE` 0).
- `net > 0`: one `spend(net)`. `net < 0`: one credit of `−net`. `net = 0`:
  no Credits call.

Example (Standard): buy one Rootcutter (1,800), sell one Thornspitter (400):
net = **1,400**, one spend. Admiral: 1,530 − 340 = **1,190**.

### D4. Kit price ("Refit & Loadout's price", Machine Nodes D6)

`kit_price(k) = Σ_{w in k.weapons} base_price(w) + Σ_{m in k.modules} base_price(m)`

`cheapest_kit(c) = min over c.kits of kit_price(k)`; a tie goes to the kit
listed first.

- Orders cost 0. Duplicate entries count once each.
- An item with no `base_price` fails `REFIT_NO_PRICE` (error for `base`,
  warning for mods), and the kit is unpriced, not cheap.
- At yield `y`, the shown cost is `Σ price(i, y)` over the same items.

Example: `relay_cut` kits A = {Rootcutter, Rootcutter} and B = {Rootcutter,
Long Fronds}. A = 1,800 + 1,800 = 3,600. B = 1,800 + 1,000 = 2,800.
Cheapest is **B, 2,800 ≤ 4,800** (`COUNTER_COST_CAP`): pass.

### D5. Cost to complete a counter

For each kit `k`: `missing(k)` = the multiset `k.weapons + k.modules` minus the
multiset of items fitted on eligible active ships, minus items in stores.

`complete(c, y) = min over kits of Σ_{i in missing(k)} price(i, y)`; ties go to
the kit listed first. `items_away = |missing(k*)|` for the chosen kit.

Example (Standard): the fleet has one Rootcutter fitted, nothing in stores.
A: missing {Rootcutter} = 1,800. B: missing {Long Fronds} = 1,000. Shown:
"**1 item away (1,000)** — kit B".

### D6. Price bands (validation)

`base_price` must sit in its band (error `REFIT_PRICE_BAND`):

| Item | Band | MVP default |
|---|---|---|
| S weapon | 600 – 1,000 | Thornspitter 800 |
| M weapon | 1,400 – 2,200 | Glowlance 2,000; Rootcutter 1,800 |
| L weapon | 3,000 – 4,200 | Seedmortar 3,600 |
| Module | 800 – 1,600 | Thick Rind 1,200; Long Fronds 1,000; Deep Vein 1,400 |

The M ceiling keeps two M guns (4,400) under `COUNTER_COST_CAP` (4,800), so
any two-gun M kit is affordable. Machine weapons need no price until a machine
hull can join the player fleet.

### D7. Module effect

`stat_eff = max(stat_min, stat_base × (1000 + Σ permille) ÷ 1000)`

- `Σ permille` over all fitted modules on the ship for that stat, clamped to
  −500 – +500.
- `stat_min`: the field's lower bound in Hulls rule 1 (0 where that is 0).

Example: Thick Rind (armour +200, max_speed −100) on a ship with armour 400,
speed 120: armour 400 × 1,200 ÷ 1000 = **480**; speed 120 × 900 ÷ 1000 = **108**.

MVP modules (placeholder names for the narrative team): **Thick Rind**
(armour +200, max_speed −100); **Long Fronds** (turn_rate +250, armour −150);
**Deep Vein** (vigor_flow +200, vigor_ceiling_erosion +200): the ship lives
faster and wears faster (not a flux distributor: its cost is lasting erosion
of the ceiling, restored only at port).

## Edge Cases

- **If the wallet is short at commit**: `spend` is refused, nothing applies,
  the draft stays open with "Wallet short by {n}".
- **If a draft sells more than it buys**: the credit is unscaled (D2 already
  applied the yield), so selling never earns yield twice.
- **If `yield_permille` changes between visits**: prices are recomputed when the
  screen opens. D2's check shows no buy-low, sell-high loop.
- **If the player sells the starting gear**: allowed. It is a one-off at 500 ‰,
  bounded by the starting fleet's value; there is no repeat.
- **If a weapon is larger than every mount** (Hulls edge case): `fits` is false
  everywhere; it stays in stores.
- **If an S gun is put in an L mount**: allowed, no penalty, no warning.
- **If stores would exceed `STORES_CAP`**: commit is disabled until the player
  sells or fits enough.
- **If a lent ship carries kit gear**: it counts toward the counter line only
  as "(with lent ships)". It can never be sold or moved.
- **If a ship is mothballed by upkeep after a refit**: its gear stays fitted;
  counters that relied on it drop to In stores or Missing on the next check.
- **If docking rights are lost**: the hold stops the clock, so no hostility
  event can fire while the Refit screen is open. A committed refit is final.
- **If the flagship has no PRIMARY weapon**: warning only; Flagship Piloting
  handles an empty group (nothing fires on that bit).
- **If a gear definition disappears (mod removed)**: rule 23.
- **If a counter has no priced kit**: it is not shown as affordable; Machine
  Nodes rule 20 fails it (`COUNTER_UNAFFORDABLE`), and the line reads
  "No kit available".
- **If a counter's kit has orders only**: D4 = 0, always Kit fitted for gear; the
  line lists the orders.
- **If two kits tie on D5**: the first listed is shown.
- **Degenerate: stacking one module type to max a stat.** Each module carries a
  cost, and D7 clamps the sum to ±500 ‰, so stacking trades as much as it gains.
- **Degenerate: buying the strongest gun everywhere.** Price is set by size
  band, not quality, and types counter each other (Weapons rule 6). There is no
  top-tier gun to buy: weapons of one size and family must differ in
  `dmg_type` or `feed`, and a weapon better than another in every field fails
  `WEAPON_DOMINATES`.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Hulls & Ship Definition (#10) | Hard | Mounts, module slots, instance `loadout`, modifier list |
| Weapons & Damage (#12) | Hard | `weapon` fields incl. new `base_price` |
| Credits, Upkeep & Sinks (#18) | Hard | `spend`, unscaled credit, `yield_permille` |
| Ports, Rest & Care (#27) | Hard | `register_service`, docked state, lay-up port, `refit_stock` field |
| Content Data & Mod Loading | Hard | Kind registration for `module`, `refit_stock` |
| World Clock | Hard | `PLANNING:port_refit` hold |
| Faction Reputation & Standing | Soft | `can(owner, trade)` |
| Machine Nodes & Strongholds (#23) | Soft (reverse) | Reads `kit_price`, `cheapest_kit` |
| AI-vs-AI Runner | Soft (reverse) | Reads `fits` and rule 22 |
| Flagship Piloting (#15) | Soft (reverse) | Reads `weapon_group` |
| Allied Lending | Soft | Lent flag |
| Markets & Trade (#37) | Soft | Hold sales; shared hub |
| Loot & Crafting (#39) | Soft (reverse, Alpha) | Writes stores and stocks |
| Port & Fleet Management Screens (#50) | Soft (reverse) | Hosts the screen |
| Telemetry (#54) | Soft (reverse) | `refit_committed` |

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `SELL_BACK_PM` | 500 | 300 – 700 | Curve | Cost of changing your mind; above 700 swaps become nearly free and the sink weakens |
| `FIT_FEE` | 0 | 0 – 200 | Curve | Per-fit charge; 0 keeps experiments cheap (Pillar 1) |
| `STORES_CAP` | 48 | 24 – 96 | Gate | How much spare gear the fleet can hoard |
| `MODULE_MOD_MAX_PM` | 300 | 100 – 400 | Curve | Strength of a single module entry |
| `MODULE_SUM_CLAMP_PM` | 500 | 300 – 600 | Curve | Stacking ceiling (D7) |
| Price bands (D6) | see D6 | must keep 2 × M max ≤ `COUNTER_COST_CAP` | Curve | Counter affordability, sink size |
| Refit privilege | `trade` | `dock`, `trade` | Gate | Lowest band that can refit |

## Visual/Audio Requirements

- Fitting a part plays a short, side-specific cue: organic grafting is wet and
  growing; machine fitting is a clean clamp. Owned by audio-director and
  art-director.
- A counter line turning Kit fitted gets one distinct confirmation cue, never
  repeated on reopen.

## Game Feel

- Every draft change updates the net cost and counter line within one frame.
- Commit feels like one decision: one sound, one log entry, one payment.
- Mount arcs are drawn on the hull outline when a mount is hovered, so a
  player sees where a gun will fire before buying it.

## UI Requirements

- Header: wallet, hold, net draft cost, stores count / cap, owner and band (or
  "Free port").
- Hull view per ship: mounts with size, arc, group (flagship) and fitted item;
  module slots with class.
- Stock and stores lists filtered to items that fit the selected slot.
- Counter panel per rule 19, with cheapest kit cost and "items away".
- Lent ships greyed with the lender's name; laid-up ships elsewhere hidden.
- Damage types shown by icon and shape, not colour alone (Weapons UI).
- 📌 **UX Flag — Refit & Loadout**: run `/ux-design` for `port_refit` before
  implementation.

## Cross-References

- Hulls & Ship Definition rules 4, 5, 6, 12, 13
- Weapons & Damage rules 1, 2, 6; MVP weapon table
- Credits, Upkeep & Sinks rules 3, 9, 12; Open Questions 1, 2
- Machine Nodes & Strongholds rules 9, 19, 20, 21; D6; Open Question 4
- AI-vs-AI Runner rules 10, 11
- Ports, Rest & Care rules 1, 3, 22, 23
- Flagship Piloting rule 6
- Deterministic RNG & Seed Streams Core Rule 5; Open Question 3

## Acceptance Criteria

- **AC-01 (Logic; rule 1)**: at a port without `refit`, `open` returns the not-listed reason; at a Hostile-band port docking is already refused; at a free port with stock, `open` returns OK.
- **AC-02 (Logic; rule 3)**: a solo counter whose cheapest kit names an item in no free port's stock fails `REFIT_KIT_UNSTOCKED`.
- **AC-03 (Logic; rule 7)**: a module with only positive entries fails `MODULE_NO_COST`; one with +300 armour and −1 turn_rate fails `MODULE_CHEAP_COST`; one with a stat twice fails `MODULE_DUP_STAT`.
- **AC-04 (Logic; rule 8)**: an S spine weapon fits an L mount accepting `spine`; an L weapon in an M mount, a `photic` weapon in a `spine`-only mount, and a graft in a kit slot are all refused.
- **AC-05 (Logic; rule 10)**: a test machine hull in the player fleet with its only unfed mount emptied cannot commit (`REFIT_NO_UNFED_GUN`).
- **AC-06 (Logic; rule 11)**: the World Clock's campaign time is identical before opening and after committing a refit.
- **AC-07 (Logic; rule 13)**: draft calls on a lent ship are refused; a ship laid up at another port is not listed.
- **AC-08 (Logic; rule 14)**: with wallet 1,000 and net 1,400, commit returns REFUSED and no loadout, stores or wallet value changes.
- **AC-09 (Logic; rule 14, D3)**: the D3 example commits with exactly one `spend(1,400, REFIT_BUY)` on Standard and one `spend(1,190)` on Admiral.
- **AC-10 (Logic; D2)**: selling a Thornspitter at Standard credits exactly 400, unscaled, with cause `REFIT_SELL`.
- **AC-11 (Logic; rule 15)**: a draft leaving 49 items in stores cannot commit.
- **AC-12 (Logic; D4)**: `cheapest_kit(relay_cut)` returns kit B, 2,800; with A and B tied, A is returned.
- **AC-13 (Logic; D5)**: the D5 example shows "1 item away (1,000)", kit B.
- **AC-14 (Logic; rule 19)**: a kit fitted only on a mothballed ship is not Kit fitted; fitted on an active ship it is; fitted partly on a lent ship it shows "(with lent ships)".
- **AC-15 (Logic; rule 18)**: swapping the weapon in a PRIMARY mount keeps PRIMARY; a never-set mount takes Flagship rule 6's default.
- **AC-16 (Logic; D6)**: an M weapon priced 2,300 fails `REFIT_PRICE_BAND`.
- **AC-17 (Logic; D7)**: Thick Rind on armour 400 / speed 120 gives 480 / 108; three Thick Rinds clamp armour at +500 ‰ (600).
- **AC-18 (Logic; rule 21)**: replaying a save with the same `refit_commit` orders gives byte-identical `base:refit` and loadouts.
- **AC-19 (Integration; rule 22)**: the Runner fits `relay_cut` kit B on the reference fleet with `fits` in the stated order and gets the same loadout as a hand trace; an unfittable kit gives `RUNNER_KIT_UNFIT`.
- **AC-20 (Logic; rule 23)**: loading a save whose stored item's definition is gone keeps it inert, worth 0; a fitted missing item leaves its slot empty.
- **AC-21 (Logic; D2)**: property test over every preset pair: no buy-then-sell sequence ends with more credits.
- **AC-22 (Playtest)**: after a scripted loss, 4 of 5 players reach a Kit fitted counter line within 3 minutes of opening Refit, and can say which counter it is.
- **AC-23 (Playtest)**: 4 of 5 players describe modules as trade-offs, not upgrades.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **No faction-band pricing for gear at MVP.**
- **Flagship groups can also be changed free in the pre-battle panel.**
- **The counter line shows only counters the Dossier has revealed** (the
  Dossier owns reveal timing; Fleet Coordination rule 3).
- **Rounding and range**: D1 uses `modifier_compose` (half up), with
  `yield_permille` 500 – 1,500.

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Is `trade` the privilege name in Faction Reputation, and is Wary the right floor for refit (Faction Reputation rule 3 refuses refit only at Hostile)? | Faction Reputation owner | Before Refit implementation |
| 2 | Re-derive `COUNTER_COST_CAP` with these price bands, and close Credits OQ 1 (catalogue run-out near hour 60) with the D6 totals. | economy-designer | Before MVP balance pass |
| 3 | Machine repair at `repair_facility` ports (Ports OQ 4): days and price. | Refit & Loadout | Post-MVP |
| 4 | Final names for modules and stock lists per port. | narrative-director, level-designer | Before content lock |
