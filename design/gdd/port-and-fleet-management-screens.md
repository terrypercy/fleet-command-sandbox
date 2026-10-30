# Port & Fleet Management Screens

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 4 (Plan in the Open — every port action shows its days, price and consequence before commit); Pillar 1 (Every Defeat Is a Lead — the port is where a loss becomes a plan)

## Summary

The Port & Fleet Management Screens are the presentation layer for everything a
docked fleet can do: the port hub, rest, care, fleet service, refit, market sale
and the fleet roster. Every screen is a `PLANNING:<screen_id>` hold, so nothing
on it costs days. Every number on it comes from the owning system's quote
function, so the whole economy, including the full defeat cost, is visible at
Tier 0.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Ports, Rest & Care, Refit & Loadout, Markets & Trade`

## Overview

This system owns no rules about money, Vigor, hulls, gear or standing. It
presents the rules of Ports, Rest & Care (#27), Refit & Loadout (#35), Markets &
Trade (#37), Credits, Upkeep & Sinks, Vigor, Hulls & Ship Definition, Allied
Lending (#33) and Sector Map & Travel. It defines the screens, their layout
contracts, the navigation between them, the keyboard map and the accessibility
rules. Docking opens the hub (Ports rule 22). The hub is the root. Each service
is one tab, one level below it. Each tab shows a preview before any order, and
each order goes through the owning system's API as one stamped order. The UI
calls quote functions and formats their results. It never adds, divides,
multiplies or caches a gameplay number. If a value the screen needs has no quote
function, the owning GDD needs one (see Open Questions); the UI does not derive
it.

## Player Fantasy

You are the quartermaster at the desk after the fight. The Wren is at a quarter
ceiling, the Bastion is scarred to its line, and the hold is full of salvage
from a battle you lost. One screen tells you what you have, what it costs per
day, what another loss would cost at most, and how many days it takes to be
whole again. Nothing is wiki knowledge. You choose between days and standing,
between banking salvage and refitting for the counter the Dossier named, and
you see each consequence before you sign.

Target aesthetics (MDA): **Challenge** as planning, not reflex; **Expression**
through loadouts and lay-up choices; **Submission** in the calm of a held clock.
SDT: **Competence** comes from readable previews (the player knows why a rest
takes 3 days); **Autonomy** from real alternatives (rest, care, sell, refit,
leave) with no hidden best answer. Pillar 4 is served by the preview-before-
commit rule (rules 5, 6). Pillar 1 is served by the fallback arrival (rule 12),
which turns the Debrief's bill into a rest plan on one screen.

## Detailed Design

### Core Rules

**A. Ownership of numbers**

1. **The UI never computes a gameplay number.** Every number shown (credits,
   days, seconds, per-mille, hull, ceiling, standing, counts, prices) is the
   return value of the owning system's quote or query function. The UI may
   only format it (Formulas F1, F2). It never sums two quotes, never divides
   wallet by upkeep, never derives a share of maximum, and never estimates a
   value while a quote is pending.
2. **Fresh on every change.** A screen re-queries its quotes on open, on every
   draft or selection change, and on every signal from an owning system
   (`wallet_changed`, `ship_mothballed`, `upkeep_warning`, `rest_ended`,
   `care_bought`, `refit_committed`, `docked`, `undocked`). A quote result is
   never reused after any of these events.
3. **A reason is never a zero.** When a quote returns a reason instead of a
   value (`UNAVAILABLE`, `REFUSED`, a validation reason), the UI shows the
   reason text in place of the value. It never shows 0, a dash or a blank for
   a refused quote.
4. **Required quote sources.** The table below is the contract. A value with
   "amendment" in its source does not yet have a function in the owning GDD;
   until it has, the field shows "Not yet quoted" and the story is blocked
   (Open Questions 1 – 4).

   | Field | Screen | Source |
   |---|---|---|
   | Wallet, hold | all headers | Credits `balance()`, `hold()` (rule 12) |
   | Daily upkeep (fleet) | hub | Credits `quote_upkeep()` (rule 12) |
   | Days of upkeep covered | hub | Credits — amendment (OQ 1) |
   | Defeat line: cap, rest days, rest upkeep | hub | Credits `quote_defeat_cap()`; the rest part from Ports — amendment (OQ 2) |
   | Suppression cover in days | hub | Credits rule 9 — amendment (OQ 1) |
   | Owner and band, or "Free port" | hub, refit, market | Ports `services(port)` / Faction Reputation band query |
   | Hold at risk on defeat | hub | Credits D2 via Markets UI — amendment (OQ 3) |
   | Service states and reasons | hub tabs | Ports `services(port)` (rule 22) |
   | Rest preview | rest | Ports `quote_rest(L)` (rule 13) |
   | Care quote | care | Ports `quote_care(ship)` (rules 18 – 20) |
   | Upkeep per ship | roster, fleet | Credits — amendment (OQ 1) |
   | Ceiling per core, rest days needed | roster | Vigor query; `need_s` from Ports `quote_rest` |
   | Hull, scar line, DP | roster, hull card | Hulls query (UI Requirements) |
   | Draft net cost, stores, counter states | refit | Refit `draft_*`, D3, rule 19 |
   | Sale quote, rate, detour | market | Markets `quote_sale(port, a)` (rule 16), D2 |
   | Loan offer, days left | fleet, roster | Allied Lending — amendment (OQ 4) |

**B. The hub and navigation**

5. **Docking opens the hub,** `PLANNING:port_hub` (Ports rule 22). The hub is a
   header plus a tab bar. The tabs, in this fixed order, are: Overview, Rest,
   Care, Fleet, Refit, Market, Roster. Rest, Care and Fleet are Ports' base
   services. Refit and Market are services registered through
   `register_service` (Ports rule 22). Roster is not a service and is always
   available.
6. **Every tab is a `PLANNING:<screen_id>` hold.** The screen IDs are
   `port_hub` (Overview), `port_rest`, `port_care`, `port_fleet`, `port_refit`,
   `port_market` and `fleet_roster`. Switching tabs swaps the hold; the World
   Clock stays held throughout (World Clock rule 3). No tab ever lets time
   pass except by an explicit Rest order.
7. **Every tab shows its service state.** A tab is one of: available;
   unavailable, with the reason from `services(port)` ("Free port: no care",
   "Wary: care refused", "Fleet fully restored"); or not yet available ("No
   provider"). Unavailable tabs stay focusable and open to a page that shows
   the reason. A greyed control always has its reason beside it, never only
   in a tooltip.
8. **The header** (Ports rule 22; Markets UI; Credits UI) shows, in this
   order:
   - wallet and hold;
   - daily upkeep and days of upkeep covered;
   - "Defeat: at most {cap} billed, then up to {d} days of rest ({upkeep})";
   - "Hold at risk on defeat: {n}";
   - suppression cover in days, or "No suppression held";
   - owner name and band, or "Free port";
   - "Docked time restores nothing. Rest to restore."
   The header is the same on every tab. Refit adds net draft cost and stores
   count / cap (Refit UI); Market adds the rate. The low-wallet warning
   (Credits rule 6) shows in the header as text plus an icon.
9. **One modal at most.** Tabs are pages, not stacked dialogs. The only modal
   is a confirm dialog (Discard changes?, a commit confirm, a notice). A
   confirm dialog never opens a second dialog. Every dialog has a Cancel
   that returns to the page it came from, bound to Esc.
10. **Leaving.** The Overview tab has Undock, Plan route and Close.
    - **Undock** issues Ports `undock()` (rule 7) and closes all port screens.
    - **Plan route** opens Sector Map's route planner (a Sector Map PLANNING
      hold); Commit there issues Depart (Ports rule 7); Back returns to the hub.
    - **Close** returns to the map while still DOCKED. The clock runs at the
      CAMPAIGN rate (Ports rule 8). A map badge reads "Docked at {port} —
      time is passing; docked time restores nothing." Selecting the port
      reopens the hub.
    If a refit draft is uncommitted, any of the three asks "Discard changes?"
    first (Refit rule 14).
11. **The refit draft survives tab switches.** Within one docking, leaving the
    Refit tab for another tab suspends the draft; it is not closed. The draft
    is discarded only by Discard, by Undock, Plan route commit or Close after
    the prompt (rule 10), or by losing docking rights (rule 25). On return to
    Refit, every quote and validation is re-run (rule 2). This lets "Sell
    salvage at the market" (Refit rule 16) send the player to Market and back
    without losing work. This reads Refit rule 14's "closing the screen" as
    leaving the docking, and needs Refit's sign-off (OQ 5).
12. **Fallback arrival** (Ports rule 24). After a defeat skip, the hub opens on
    the Rest tab with "Until full" selected, and the header carries the
    Debrief's bill line (Credits rule 7) until the player undocks. No rest
    starts on its own. The opening loss (Ports rule 25) opens the same way;
    the Rest tab shows only hull damage, if any.

**C. Rest panel (`PLANNING:port_rest`)**

13. **Length selector** (Ports rule 12): "Until full" (default) and "Days", a
    stepper in `REST_STEP_S` steps from one step to `L_full`, the last step
    clipped. The UI takes the list of legal lengths from Ports; it never
    offers a length Ports did not. If Ports returns "Fleet fully restored",
    the panel shows that reason and no selector.
14. **Preview** (Ports rule 13), all from `quote_rest(L)`:
    - a row per ship (active roster and mothballed ships travelling with the
      fleet, lent ships included per Allied Lending): Vigor ceiling and hull,
      now and after, as values and as the share of maximum the quote gives;
    - `L` in days and hours (F1) and the day it ends;
    - upkeep: fleet upkeep and suppression upkeep inside the rest, and whether
      the wallet covers them; if not, the ships that would be mothballed,
      named in lay-up order, with "mothballed ships still rest" (Ports rule
      17);
    - visible World Clock events due inside the rest, in queue order;
    - "May be interrupted by: hostility, exposure, case events";
    - "Investigator progress due inside this rest:" with each known step.
15. **Rest** issues `rest(L)` (Ports rule 14). The tab closes and a rest
    progress strip shows on the map: day now, target day, and "Resting at
    {port}". It is not a hold and takes no input except Pause, which the World
    Clock owns.
16. **Interrupt hold** (Ports rule 15; Ports UI): the event, the restoration so
    far (from Ports, not computed), Resume and End rest. Rule 9's forced end
    shows the same panel with only Continue and the reason ("Spiralward ports
    closed to you"). Its screen ID is World Clock's interrupt hold (OQ 6).
17. **Rest ended.** On `rest_ended`, the hub reopens on Overview, and changed
    values on the roster are marked "restored" for that visit.

**D. Care screen (`PLANNING:port_care`)**

18. **One row per organic ship** (Ports UI): the quote from `quote_care(ship)`
    (the standing price), standing before and after, and the band change from
    Faction Reputation's `preview` (Ports rule 20). Or the reason care is not
    offered: ceiling full, band Wary or Hostile, machine hull, below
    `SPEND_FLOOR`, already bought this expedition, or lent ship (Ports rule
    19; Allied Lending amendment to Ports rule 19).
19. **Care is full or nothing.** The row has one button, "Restore to full".
    It costs no days and no credits; the row says so ("No days. No credits.
    Standing: {price}"). Confirm issues `buy_care(ship)`. On `REFUSED`, the
    row shows the reason.
20. **Care restores Vigor only.** Each row with hull damage shows "Hull and
    scars need rest" (Ports rule 19) with a link to the Rest tab.

**E. Fleet service (`PLANNING:port_fleet`)**

21. **Three lists** (Ports rule 23; Ports UI): ships travelling with the fleet
    (active and mothballed), ships laid up at this port, and ships laid up
    elsewhere, grouped by port, read-only.
22. **Actions per ship,** each with its reason when unavailable:
    - **Mothball** an active non-core ship (Credits `mothball(id)`); the free
      core shows "Free core: never mothballed" (Credits rule 5);
    - **Lay up here** a mothballed ship travelling with the fleet (Ports rule
      23);
    - **Reactivate** a mothballed ship travelling with the fleet or laid up
      here (Credits `reactivate(id)`), with "Free. Upkeep resumes: {upkeep}/day";
      a ship laid up elsewhere shows "Laid up at {port}".
    Each action shows the new daily upkeep and days covered before confirm,
    from the quotes, not from adding the ship's upkeep in the UI.
23. **Lay-up order** is shown read-only as each ship's position, with a link to
    the Ledger, where Credits lets the player set it (Credits rule 6, UI).
24. **Loan offer** (Allied Lending UI): when an ally offers ships, a panel
    shows the offer, the ship count, the loan end conditions, Accept and
    Dismiss. Accepting and dismissing are Allied Lending orders.

**F. Refit screen (`PLANNING:port_refit`)**

25. **Layout** (Refit UI; Hulls UI): the header (rule 8 plus net draft cost
    and stores count / cap); a ship list; the hull view for the selected ship
    (mounts with size, arc, group for the flagship, fitted item; module slots
    with class); stock and stores lists filtered to items that `fits` the
    selected slot; the counter panel.
26. **The draft** (Refit rules 12 – 15): every change is staged and shown as
    staged (a "Draft" tag and a changes list). Undo, Reset and Commit are
    always on screen. Commit is disabled with its reason ("Wallet short by
    {n}", "Stores full: sell or fit {n}", the invalid rule). When the hold is
    above 0 and the wallet is short, the header shows "Sell salvage at the
    market" as a link to the Market tab (Refit rule 16; rule 11).
27. **Eligible ships** (Refit rule 13): lent ships are listed read-only and
    marked "Lent by {faction}"; ships laid up elsewhere are not listed; ships
    laid up here are eligible.
28. **Counter panel** (Refit rule 19), one line per counter the Dossier shows:
    the state "Kit fitted", "In stores" or "Missing — {k} items away
    ({cost})", the kit named, the cheapest kit cost, "plus order: {order}"
    where present, "(with lent ships)" where it applies. The Kit fitted
    tooltip reads "The Dossier's counter is fitted. You still have to win
    it." The state updates on every draft change.
29. **Mothball notice:** for each mothballed eligible ship with gear, the
    counter panel shows "{ship} is mothballed: its gear does not count."
30. **Stat clamp notice:** in the hull view each module-affected stat shows its
    effective value from Refit, with "capped at +500‰" or "capped at −500‰"
    when Refit's D7 clamp applies.
31. **Missing content** in stores shows "Missing content" with the value Refit
    returns (Refit rule 23).

**G. Market sale (`PLANNING:port_market`)**

32. **Body** (Markets UI): the rate as the band and per-mille ("Wary: 900 ‰"),
    an amount field (1 – hold), "Sell all", and the quote from
    `quote_sale(port, a)` for the chosen amount.
33. **Sub-par rate:** the cut in credits, the nearest full-rate port, its
    travel time (F1), and the break-even as an observation, from Markets D2.
    It is never phrased as advice.
34. **Refused states** show Markets' reason ("Hold empty", "Too little to sell
    here"). Sell issues Markets' sell order (rule 16); the header updates from
    `wallet_changed`.

**H. Fleet roster (`PLANNING:fleet_roster`)**

35. **One row per owned or lent ship,** grouped: active, mothballed with the
    fleet, laid up (by port), lent. Columns:
    - name (organic) or designation (machine) (Hulls UI), class and size;
    - status: Active, Mothballed, Laid up at {port}, Recovered, Disabled, or
      "Lent by {faction} — {n} days left" (Allied Lending UI);
    - hull now / max and the scar line as text ("Scarred to 72%") (Hulls rule
      8; Ports rule 21);
    - Vigor ceiling per core for organic ships, with rest days needed (Vigor
      UI);
    - upkeep per day, "Free core" for the free core, "0 (lent)" for lent ships
      (Credits rules 4, 5).
36. **Expanding a row** shows the hull card inline (Hulls UI): class, role,
    size, mounts with arcs, counter tags with meanings, DP base and authored
    adjustment on separate lines, scar state. It is not a dialog.
37. **The roster issues no orders.** Its row buttons jump to the Fleet, Care or
    Refit tab with that ship selected.

**I. Keyboard and accessibility**

38. **Keyboard map** (defaults; rebinding per the input settings, OQ 7):

    | Key | Action |
    |---|---|
    | 1 – 7 | Overview, Rest, Care, Fleet, Refit, Market, Roster |
    | Ctrl+Tab / Ctrl+Shift+Tab | next / previous tab |
    | Tab / Shift+Tab, arrows | move focus; arrows within lists and steppers |
    | Enter / Space | activate the focused control |
    | Ctrl+Enter | the tab's commit (Rest, Commit, Sell), only when enabled |
    | Ctrl+Z / Ctrl+Shift+Z | refit draft Undo / Redo |
    | Esc | close dialog; else go to Overview; on Overview, Close (rule 10) |

    Every action reachable by mouse is reachable by keyboard. Focus is always
    visible. Commit never fires from a key without focus on its tab.
39. **No colour-only signal.** Every state carries a text label and an icon of
    distinct shape; colour is third. This covers service states, counter
    states, ship status, refused quotes, warnings, the scar line and damage
    types (Refit UI; Weapons UI).
40. **Text scale.** All port screens reflow at text scales from 100% to 200%
    (`design/accessibility-requirements.md`). Names may truncate with the full
    name on focus; numbers and reasons never truncate. Each control exposes its
    label and value to the platform accessibility layer.

### States and Transitions

| State | Meaning | Clock | Exits |
|---|---|---|---|
| MAP_DOCKED | docked, no port screen open | CAMPAIGN | HUB (select port), UNDOCKED (Undock order elsewhere) |
| HUB | `PLANNING:port_hub` | held | TAB (1 – 7), MAP_DOCKED (Close), UNDOCKED (Undock), ROUTE (Plan route) |
| TAB | one of `port_rest`, `port_care`, `port_fleet`, `port_refit`, `port_market`, `fleet_roster` | held | HUB (Esc), TAB (switch), CONFIRM, RESTING (Rest) |
| CONFIRM | one dialog over a TAB or HUB | held | the page it came from (Cancel, Confirm) |
| ROUTE | Sector Map route planner | held | HUB (Back), UNDOCKED (Commit: Depart) |
| RESTING | one skip running (Ports rule 14) | skipping | INTERRUPT (interrupts_skip event), HUB (`rest_ended`) |
| INTERRUPT | interrupt hold (Ports rule 15) | held | RESTING (Resume), HUB (End rest), MAP_UNDOCKED (rule 9 Continue) |
| UNDOCKED | fleet IN_SYSTEM | CAMPAIGN | HUB (Dock) |

The refit draft is a sub-state of the docking: NONE, ACTIVE, SUSPENDED (another
tab open). It goes NONE on commit, discard, or any exit from HUB to MAP_DOCKED,
ROUTE commit or UNDOCKED.

### Interactions with Other Systems

| System | Reads | Orders issued |
|---|---|---|
| Ports, Rest & Care (#27) | `services`, `quote_rest`, `quote_care`, rest record, laid-up list | `undock`, `rest`, `resume_rest`, `end_rest`, `buy_care`, `lay_up` |
| Credits, Upkeep & Sinks | `balance`, `hold`, `quote_upkeep`, `quote_defeat_cap`, lay-up order, signals | `mothball`, `reactivate` |
| Refit & Loadout (#35) | `open`, `fits`, draft state, counter states, effective stats | `draft_*`, `commit` |
| Markets & Trade (#37) | `quote_sale`, rate, D2 detour | sell (Markets rule 16) |
| Vigor | ceiling per core, `C0` | none |
| Hulls & Ship Definition | hull card, scar line, names | none |
| Allied Lending (#33) | offer, loan terms, days left | accept, dismiss |
| Sector Map & Travel | port, free port, route planner, travel time | Plan route, Depart (through the planner) |
| Faction Reputation | band, `preview` for care | none |
| World Clock | holds, interrupt hold, day labels | none (holds only) |

## Formulas

This system defines no gameplay maths (rule 1). It defines two display
formats. Both are pure integer functions of a quoted value.

### F1. Duration in days and hours

```
days  = s div 86,400
hours = (s mod 86,400) div 3,600
text  = "{days} d {hours} h"; "{hours} h" when days = 0; "{days} d" when hours = 0
```

| Variable | Meaning | Range |
|---|---|---|
| `s` | a quoted duration in seconds | 0 – `SKIP_MAX_S` for rests; 0 – any for travel |
| `days`, `hours` | display parts, floored | 0 – …; 0 – 23 |

Floored, never rounded up: the screen never shows a rest as shorter in whole
hours than its quote's remainder suggests is complete, and the exact end day is
shown separately from the quote (rule 14). When `s` is under 3,600 and above 0,
the text is "under 1 h".

### F2. Number grouping

Integers are shown with a thousands separator per locale ("1,260"). Per-mille
values are shown as given with "‰" ("900 ‰"); they are never converted to
percent in the UI unless the quote returns a percent.

### Worked example (checked)

- Ports AC-05's worked ship: `need_s` 259,200 → 259,200 div 86,400 = 3; mod =
  0 → **"3 d"**. At 1,250: 324,000 → 3 d (259,200); 64,800 div 3,600 = 18 →
  **"3 d 18 h"**. At 500: 129,600 → 1 d (86,400); 43,200 div 3,600 = 12 →
  **"1 d 12 h"**.
- One rest step, 21,600 → 0 d; 21,600 div 3,600 = 6 → **"6 h"**.
- Markets D2 break-even, 98,742 s → 1 d (86,400); 12,342 div 3,600 = 3 →
  **"1 d 3 h"**. (Markets UI phrases this "1.1 days"; see OQ 8.)
- Ports AC-07's rest upkeep, 1,260 → **"1,260"** (F2).

## Edge Cases

- **Daily upkeep is 0** (only the free core active): days covered comes from
  Credits as a sentinel; the header shows "No upkeep due". The UI never
  divides by zero because it never divides.
- **Wallet 0:** the header shows 0 and the low-wallet warning (text and icon).
  The rest preview names the ships that would be mothballed.
- **Hold 0:** "Hold at risk on defeat: 0"; Market shows "Hold empty"; Refit
  hides the "Sell salvage" link.
- **No suppression held:** the header shows "No suppression held", never "0
  days".
- **Fleet fully restored:** the Rest tab shows the reason and no selector (Ports
  rule 12).
- **`L_full` capped at `SKIP_MAX_S`:** the preview's after values show ships
  still below maximum. The UI adds nothing; the quote is the truth.
- **A quote returns a reason:** the reason replaces the value (rule 3).
- **Docking rights lost mid-rest** (Ports rule 9): the interrupt panel shows
  only Continue and the reason. All port screens close; any refit draft is
  discarded with the notice "Refit draft discarded: port closed". The fleet
  is shown IN_SYSTEM.
- **Laid-up ships moved by hostility** (Ports rule 29): a notice names them;
  the Fleet and Roster tabs show their new port on next open.
- **Save during an interrupt hold:** loading restores the same panel with the
  same Resume / End choice (Ports rule 32).
- **Save while a port screen is open:** loading reopens the hub on Overview.
  A refit draft is not saved (Refit save holds no draft); the notice reads
  "Uncommitted refit changes were not saved." (OQ 9)
- **Lent ship:** Care row shows "Lent ship: care not offered"; Refit lists it
  read-only; upkeep "0 (lent)"; it appears in the rest preview (Allied
  Lending amendment to Ports rule 10).
- **Free core:** no Mothball button; "Free core: never mothballed".
- **Ship laid up elsewhere:** visible in Fleet and Roster under its port;
  hidden in Refit; Reactivate shows "Laid up at {port}".
- **Free port:** owner shows "Free port"; Care shows its reason.
- **Missing content in stores:** shown as "Missing content" with Refit's
  value.
- **Opening loss:** the bill line reads the Debrief's would-be bill as
  Credits rule 8 reports it; the Rest tab shows hull only.
- **Text scale 200% with a long ship name:** the name truncates with the full
  name on focus; hull, ceiling and upkeep never truncate; the roster scrolls
  horizontally if needed.
- **Many ships:** lists scroll; the header and tab bar never scroll away.
- **Esc pressed with an uncommitted draft on Overview:** "Discard changes?"
  opens; Esc again cancels it (rule 9). There is no path that discards a
  draft without a prompt except losing docking rights.
- **Degenerate use:** the held clock means a player can study the port for any
  real time at no game cost. This is intended (Pillar 4). Close returns to a
  running clock, and the map badge says so, so no one mistakes a closed hub
  for a held one.

## Dependencies

| System | Direction | Nature | Contract |
|---|---|---|---|
| Ports, Rest & Care (#27) | #27 → #50 | Hard | Hub, services, rest and care quotes and orders; needs the defeat-line quote (OQ 2) |
| Credits, Upkeep & Sinks | Credits → #50 | Hard | Wallet, hold, upkeep, cap, mothball; needs days-covered, suppression-cover, per-ship upkeep quotes (OQ 1) |
| Refit & Loadout (#35) | #35 → #50 | Hard | Draft API, counter states, effective stats; draft-suspension reading (OQ 5) |
| Markets & Trade (#37) | #37 → #50 | Hard | `quote_sale`, D2, sell; hold-at-risk source (OQ 3) |
| Vigor | Vigor → #50 | Hard | Ceiling per core |
| Hulls & Ship Definition | Hulls → #50 | Hard | Hull card, names, scar line |
| Allied Lending (#33) | #33 → #50 | Soft | Offer, terms, days left (OQ 4) |
| Sector Map & Travel | both | Soft | Route planner from the hub; map badge for docked state |
| Faction Reputation & Standing | → #50 | Soft | Band and care `preview` |
| World Clock | → #50 | Hard | PLANNING holds; interrupt hold (OQ 6) |
| Simulation Tick & Pause | → #50 | Hard | Hold list must include the seven screen IDs (amendment) |
| Gameplay Settings / accessibility requirements | → #50 | Soft | Text scale, input rebinding (OQ 7) |

## Tuning Knobs

All are feel knobs in `assets/data/ui/port_screens` (path to confirm with the
UI programmer). None changes a gameplay number.

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `TEXT_SCALE_MIN` / `MAX` | 100% / 200% | 100% – 250% | feel | readability, layout reflow |
| `TOOLTIP_DELAY_MS` | 400 | 0 – 1,000 | feel | how fast detail appears; 0 for accessibility |
| `CHANGED_VALUE_MARK_S` | until next undock | 2 s – visit | feel | how long "restored" / "changed" marks stay |
| `QUOTE_REFRESH_BUDGET_MS` | 50 | 16 – 100 | feel | max time from input to refreshed quote shown; above it, a "Quoting…" label (never a stale number) |
| `REST_STRIP_VISIBLE` | on | on / off | feel | rest progress strip on the map |

## Visual/Audio Requirements

- Art direction owns look and palette. This GDD requires only: distinct icon
  shapes per state (rule 39); a visible "Draft" treatment in Refit; a visible
  "restored" mark after a rest.
- Audio direction owns cues. Required events: commit accepted, order refused,
  rest started, rest interrupted, rest ended. A refused order is never silent
  and never only a sound: the reason text shows too.

## Game Feel

- The desk is calm. No animation blocks input; a value change can mark itself
  but never delays the next action.
- A quote refreshes within `QUOTE_REFRESH_BUDGET_MS` of any change, so the
  preview feels like the truth, not a calculation.
- Undo is free and instant in Refit, so experiments cost nothing.
- Fallback arrival lands on the Rest tab with the plan already drafted: the
  loss reads as a list of next steps, not a penalty screen (Pillar 1).

## UI Requirements

Collected from the owning GDDs. Each is implemented by the rule cited.

| Requirement | Source | Rule here |
|---|---|---|
| Hub header: wallet, hold, daily upkeep, days covered, defeat cap with longest recovery rest, suppression cover, owner band, "Docked time restores nothing" | Ports rule 22; Ports UI | 8 |
| Hub service rows with state and reason | Ports rule 22; Ports UI | 7 |
| Rest panel: selector, per-ship before/after, length, upkeep, mothball warnings, visible events, interrupt line, investigator steps | Ports rules 12, 13; Ports UI | 13, 14 |
| Interrupt hold: event, Resume, End, restoration so far | Ports rule 15; Ports UI | 16 |
| Care: quote, standing before/after, band change, or reason | Ports rules 18 – 20; Ports UI | 18 – 20 |
| Fleet panel: mothball, lay up, reactivate; laid-up ships by port | Ports rule 23; Ports UI | 21 – 22 |
| Wallet and hold always visible; daily upkeep shown | Credits UI | 8 |
| Lay-up order (Ledger) | Credits rule 6; Credits UI | 23 |
| Low-wallet warning under 3 days | Credits rule 6 | 8 |
| Refit header: wallet, hold, net cost, stores / cap, owner band | Refit UI | 25 |
| Hull view, filtered stock and stores, counter panel, lent greyed, laid-up elsewhere hidden | Refit UI; rules 13, 19 | 25 – 28 |
| "Kit fitted", mothball notice, clamp notice | Refit rule 19 | 28 – 30 |
| "Sell salvage at the market" link | Refit rule 16 | 26 |
| Damage types by icon and shape | Refit UI; Weapons UI | 39 |
| Market header with "Hold at risk on defeat" | Markets UI | 8 |
| Rate, quote, Sell all, amount field; sub-par detour; refused reasons | Markets UI | 32 – 34 |
| Ceiling per ship and rest days needed | Vigor UI | 35 |
| Hull card; names vs designations | Hulls UI | 35, 36 |
| Fleet screen loan offer; "lent by" tag and days left | Allied Lending UI | 24, 35 |
| Retained screenshot per screen | Ports, Allied Lending UI; coding standards | ACs |

📌 **UX Flag — Port & Fleet Management Screens**: run `/ux-design` for
`port_hub`, `port_rest`, `port_care`, `port_fleet`, `port_refit`,
`port_market` and `fleet_roster` before epics. This GDD fixes the contracts;
the UX specs fix layout.

## Cross-References

| Topic | Document | Section |
|---|---|---|
| Hub, rest, care, fleet service, fallback | `design/gdd/ports-rest-and-care.md` | Rules 5 – 9, 12 – 25, 29, 32, 33; UI Requirements |
| Wallet, upkeep, mothball, cap, suppression, API | `design/gdd/credits-upkeep-and-sinks.md` | Rules 4 – 9, 12; UI Requirements |
| Draft, commit, stores, counters | `design/gdd/refit-and-loadout.md` | Rules 11 – 19, 23, 24; UI Requirements |
| Sale quote, detour | `design/gdd/markets-and-trade.md` | Rule 16; D2; UI Requirements |
| Ceiling bar, rest days | `design/gdd/vigor.md` | UI Requirements |
| Hull card, fleet list | `design/gdd/hulls-and-ship-definition.md` | Rule 8; UI Requirements |
| Loan offer, lent tag | `design/gdd/allied-lending.md` | UI Requirements; Cross-References |
| Route planner, docked state | `design/gdd/sector-map-and-travel.md` | Rules 6, 26, 33; UI Requirements |
| Port screen shows credits, upkeep, defeat cap | `design/gdd/systems-index.md` | #50 CD note |

## Acceptance Criteria

- **AC-01 (Logic; rules 1, 4)**: with every quote function replaced by a fake returning a distinct sentinel (for example 7,777,001 for wallet, 7,777,002 for upkeep), every port screen shows each sentinel verbatim (after F2) in its field, and no field shows a value not returned by a fake.
- **AC-02 (Logic; rule 1)**: a static check of the port UI scripts finds no arithmetic on values returned by quote functions other than F1 and F2.
- **AC-03 (Logic; rule 2)**: after `wallet_changed`, `ship_mothballed`, `rest_ended`, `care_bought` or `refit_committed`, every visible field is re-queried before the next frame shown; a counting fake records one new call per field.
- **AC-04 (Logic; rule 3)**: a fake quote returning `UNAVAILABLE` with reason "Wary: care refused" shows that text, and the field contains no digit.
- **AC-05 (Logic; F1)**: F1 gives "3 d" for 259,200, "3 d 18 h" for 324,000, "1 d 12 h" for 129,600, "6 h" for 21,600, "1 d 3 h" for 98,742, and "under 1 h" for 1.
- **AC-06 (Logic; rules 5 – 7)**: the tab list matches `services(port)` in the fixed order; each unavailable tab shows the reason string from Ports; Roster is always present.
- **AC-07 (Logic; rule 6)**: opening each of the seven screens sets the matching `PLANNING:<screen_id>` hold; across 100 random tab switches `clock_s` changes by 0.
- **AC-08 (Logic; rule 9)**: no sequence of inputs produces two open dialogs; from any dialog, Esc returns to the page it came from.
- **AC-09 (Logic; rules 10, 11)**: a refit draft survives a switch to Market and back with identical staged changes; Undock, Close and Plan route commit each prompt "Discard changes?" first; Cancel keeps the draft.
- **AC-10 (Logic; rule 12)**: after a defeat skip ends, the hub opens on the Rest tab with "Until full" selected and the bill line in the header, and no `rest` order has been issued.
- **AC-11 (Logic; rule 13)**: the Days stepper offers exactly the lengths Ports returns and none above `L_full`.
- **AC-12 (Logic; rule 22)**: the free core has no Mothball action and shows "Free core: never mothballed"; a ship laid up at another port shows "Laid up at {port}" and no Reactivate.
- **AC-13 (Logic; rules 27 – 30)**: a lent ship is read-only in Refit with "Lent by {faction}"; a mothballed ship with gear produces the mothball notice; a stat at D7's clamp shows "capped at +500‰".
- **AC-14 (Logic; rule 38)**: every action on every screen can be completed with keyboard only (scripted input test); Ctrl+Enter does nothing while the commit is disabled.
- **AC-15 (Logic; Edge Cases)**: losing docking rights during a rest closes all port screens, discards the draft with the notice, and leaves the fleet IN_SYSTEM.
- **AC-16 (UI; rule 8)**: a retained screenshot in `production/qa/evidence/` of the hub header with a non-zero hold, a held lie and a low-wallet warning shows all seven header lines.
- **AC-17 (UI; rules 13 – 16)**: retained screenshots of the Rest panel with a mothball warning and a visible event inside the rest, and of the interrupt hold.
- **AC-18 (UI; rules 18 – 20)**: a retained screenshot of the Care screen with one available row and one row showing each of two different reasons.
- **AC-19 (UI; rules 21 – 24)**: a retained screenshot of the Fleet tab with ships in all three lists and a loan offer.
- **AC-20 (UI; rules 25 – 31)**: retained screenshots of Refit with a staged draft, the counter panel showing all three states, the mothball notice and a clamp notice.
- **AC-21 (UI; rules 32 – 34)**: retained screenshots of Market at a full rate and at a sub-par rate with the detour line.
- **AC-22 (UI; rules 35 – 37)**: a retained screenshot of the Roster with an active, a mothballed, a laid-up, a recovered and a lent ship, and one expanded hull card.
- **AC-23 (UI; rules 39, 40)**: retained screenshots of the hub and Roster at 200% text scale and in a greyscale capture; every state is still distinguishable by text and shape, and no number is truncated.
- **AC-24 (Playtest; rules 8, 12)**: at least 4 of 5 testers, after a defeat, can say from the port screen alone how many days and credits a full recovery costs (shared with Ports AC-25).
- **AC-25 (Playtest; rules 11, 26)**: at least 4 of 5 testers who are short of credits in Refit sell salvage and return to finish the refit without rebuilding the draft, and none reports losing work.
- **AC-26 (Playtest; rule 10)**: at least 4 of 5 testers, asked after closing the hub, correctly say whether time is passing.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **One duration format everywhere**: "1 d 3 h" (F1); Markets' break-even line
  amended to match.
- **An uncommitted refit draft is not saved**; it lives only for the docking.
- **No roster ship shows "Disabled" in port**: recovery resolves at battle end
  (Battle Resolution rule 11; Credits forgives shortfalls), so a docked ship
  is active, mothballed, laid up or lent.
- **The roster also opens from the map** as a read-only hold
  (`PLANNING:port_fleet`).
- **The screen IDs** join the Simulation Tick & Pause hold list (amended).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Credits rule 12 lists no function for days of upkeep covered, suppression cover in days, or upkeep per ship. Add `quote_days_covered()` (with a no-upkeep sentinel), `quote_suppression_cover_days()` and `quote_upkeep_of(ship)`? | Credits owner (economy-designer) | Before #50 epics |
| 2 | Ports rule 22 requires the defeat line's rest part (`L_full` from the floor and its upkeep), but rule 33's API has no function for it. Add `quote_defeat_line() → {cap, d_s, upkeep}`, and an interrupt "restoration so far" query? | Ports owner | Before #50 epics |
| 3 | Markets UI cites "Hold at risk on defeat: N (Credits D2)". Which function returns N? Not verified in this pass. | Credits / Markets owners | Before #50 epics |
| 4 | Allied Lending's API for the offer, loan terms and days left was not verified. | Allied Lending owner | Before #50 epics |
| 5 | Rule 11 keeps a refit draft across tab switches within a docking. Refit rule 14 says closing the screen asks "Discard changes?". Accept the reading that "closing" means leaving the docking? | Refit owner + creative director | Design review |
| 6 | Screen ID of the interrupt hold and the rule-9 forced-end notice: World Clock's, or `port_rest_interrupt` here? | World Clock owner | Before #50 epics |
| 7 | Input rebinding and the text-scale setting: which GDD owns them, and do the default keys clash with campaign-map keys? | UX designer | UX spec |
