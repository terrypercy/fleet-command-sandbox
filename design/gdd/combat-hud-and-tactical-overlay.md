# Combat HUD & Tactical Overlay

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 4 (Plan in the Open — everything the fight depends on is readable once learned); Pillar 5 (Living Against Made — Vigor and Coherence read differently at a glance); Pillar 3 (Hands on the Helm — the flagship's state is always in view)

## Summary

The Combat HUD & Tactical Overlay is the read-only window onto a battle. It shows a small always-on set while the fight runs, opens the full tactical picture when the simulation is held, and puts the details on hover; it draws only what the simulation has published and never reads hidden state. It hosts the pre-battle panel, carries every HUD obligation other GDDs placed on #46, and makes no signal depend on colour alone.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Gameplay Settings & Modifiers, Vigor, Coherence & Links, Fleet Orders, Ship AI, Camera & Combat View, Runtime ID Service`

## Overview

The Combat HUD & Tactical Overlay is everything drawn over the battlefield that
is not the ships themselves. It has three tiers. The **live tier** is always on:
the flagship's state, the present counts, the battle clock, the speed and hold
state, and the few markers that need an answer within seconds. The **held tier**
opens when the simulation is paused or in the Command context: formations and
phase names, strength ratios, order lines, leash rings, link ETAs. The **hover
tier** gives the numbers for one thing under the cursor or under lock.

The HUD is a **reader**. It takes the published state after each tick's event
batch (Combat Event Bus rule P9), the camera transform, and the settings. It
computes previews only with formulas the owning system names, with no RNG draw,
and labels them "if nothing changes". It never writes simulation state, never
moves the camera, and never shows a fact the simulation has not made public. It
also hosts the **pre-battle panel**, which states how the battle ends and what a
loss costs before the first tick.

## Player Fantasy

**I am on the bridge, and the board is honest.** At speed, the screen is quiet:
my flagship's breath and guns, how many ships each side has left, and the clock.
When I pause, the whole board unfolds: the machine fleet's formation and the
name of what it is doing, how close it is to falling back, which link will snap
next. Nothing on the board lies, and nothing is missing that the fight depends on.

*Anchor moment:* the player pauses. Over the enemy fleet: "Lattice Screen —
ENGAGE", a strength bar at 5:4 with two notches marked "falls back" and "breaks".
A dashed link line carries "2 hits to snap". The player sets Focus on the
relay's link partner, resumes, and watches the bar slide past the first notch as
the tell pulse fires.

**Pillars served:**
- **Pillar 4 (Plan in the Open):** every rule the fight depends on has a readout,
  in the tier where it is used.
- **Pillar 5 (Living Against Made):** Vigor reads as a living ship's breath, on
  the ship; Coherence reads as a mesh between machines, on the lines. They share
  no visual grammar.
- **Pillar 3 (Hands on the Helm):** the flagship's panel never hides, and the
  HUD never takes keys from the helm while the battle runs.

**MDA target aesthetics:** Challenge (readable stakes), Discovery (the held-tier
board rewards study), Sensation is the art's, not the HUD's. **SDT:** Competence
first: the player must always know why a ship did what it did.

**This system must never make the player feel:** "I couldn't see that coming",
"the screen is a wall of numbers", "the HUD knew something the game hid", or "I
can't tell those two states apart without colour".

## Detailed Design

### Core Rules

**A. What the HUD may read**

1. **The HUD is read-only.** It reads (a) published simulation state after the
   tick's P9 batch, (b) Battle Record events, (c) Camera & Combat View's
   transform, `H`, state and flagship-on-screen flag, and (d) Gameplay Settings
   & Modifiers. It writes nothing back. Player input goes to Input & Controls,
   never through the HUD into the simulation.
2. **The HUD never reads hidden state.** It does not read RNG streams or their
   cursors, Ship AI's candidate scores, Truth Seeding & Candidates' hidden
   attributes, undrawn future events, or any field its owner does not list as
   published. A value the HUD shows must exist in the owner's published state or
   be computed from published values by a formula the owner names.
3. **Previews draw nothing.** Shown hit chance, expected damage per hit, "hits to
   dash / hits to snap" and "dry in N s" are computed with no RNG draw, from the
   owner's formula (Weapons & Damage D1–D3; Coherence & Links UI; Vigor rule 13).
   Each is labelled "if nothing changes".
4. **One number, one source.** Where a system publishes a value, the HUD shows
   that value and does not recompute it. Present counts come from Battle
   Resolution D1. Strength ratio comes from Fleet Coordination D2 (an amendment:
   it must publish `sr_pm` per fleet; Open Question 1). The HUD never shows a
   second, differently rounded copy.
5. **Truth-neutral rule.** The HUD shows the same kinds of fact about both sides
   wherever both sides have them (hull, Vigor or Coherence band, weapon state,
   present count). It shows no fact that answers the campaign's whodunnit:
   no maker, lineage or attribute from Truth Seeding & Candidates, and no
   Dossier sentence the Dossier has not yet revealed. Enemy doctrine is shown
   only as its name and its live phase; the rules behind it stay in the Dossier.
6. **No raw IDs.** Ships are named by their display names (Runtime ID Service
   rule on display names); a Runtime ID never appears in a release build.
7. **Reason codes are debug only.** Ship AI's reason codes, candidate scores
   and the debug view (Ship AI rules 14, 16) appear only behind the dev-build
   debug overlay. The release HUD shows what a ship does (its order, its target,
   its band), not why the AI chose it; the Debrief explains why.
8. **The visible list is published.** The HUD publishes `HudVisibleFields`, the
   exact list of fields it can show at each tier. The AI-vs-AI Runner's
   `BotView` is held equal to it (AI-vs-AI Runner rule 2, AC-01b). Adding a
   field to the HUD is a change to that list.

**B. Visibility of enemies**

9. **No fog and no jamming of the view at MVP.** Every ship whose Runtime ID
   status is `LIVE` on the field, and every disabled ship still on the field, is
   **HUD-visible** to the player, on both sides. There are no sensors and no
   area jammers at MVP (Coherence & Links rule 13 and Open Question 5). A
   `jammed` link is a link state, not a hidden ship.
10. **One visibility predicate.** `hud_visible(ship)` is the only test of
    whether the HUD draws a ship. At MVP it is true for every on-field ship. The
    camera's frame sets use the same predicate (Camera & Combat View rule 12),
    so the camera never fits to a ship the HUD does not draw. A later sensor
    system changes only this predicate.

**C. Tiers**

11. **Live tier (always on while running).** Shown at every speed:
    - **Flagship panel**: hull; Vigor bar and band (rule 18) for an organic
      flagship; player weapon groups with cooldown and state (Ready / Starved /
      Silent); ability cooldown; the AUTO-group mark when AUTO mounts fire on
      their own; the EMPTY-slowdown mark; the move-frame indicator (Flagship
      Piloting UI).
    - **Battle bar**: present counts per side (Battle Resolution D1); battle
      time (World Clock); effective speed with "slowed" (Simulation Tick D5);
      the hold indicator whenever held.
    - **Standoff countdown** after the standoff warning, with its one-line
      notice (Battle Resolution rule 5; D6).
    - **On-field markers**: side marker per ship; disabled marker ("out, not
      dead"); flagship lock markers from every ship whose focus is the flagship
      (Fleet Coordination rule 11); the locked target's marker; the "lent by
      ⟨f⟩" tag on lent ships (Allied Lending UI).
    - **Machine fleet band** per enemy machine fleet: WHOLE, FRAYING or BROKEN,
      in words (Coherence & Links UI).
    - **Tells**: the anchor relay pulse and slot ghosts for `TELL_TICKS` (Fleet
      Coordination rule 11).
    - **Arc wedges** for player groups while a fire button is held; out-of-arc
      mounts dimmed by shape (Flagship Piloting).
    - **Off-screen flagship marker** whenever the flagship is not on screen
      (Camera UI; D3), and the camera mode tag ("Chart", "Fleet") when not in
      Follow.
    - **Latched-press and sticky-modifier glyphs** with text (Input & Controls).
    - **Notices** (rule 23) and the end banner (rule 26).
12. **Held tier (paused, or in the Command context).** Adds, over the live tier:
    - formation slots and the **phase name** over each enemy fleet; the tell
      countdown in seconds while one runs (Fleet Coordination UI);
    - each enemy fleet's **strength ratio** against the player's fleet, as a
      ratio ("5:4") and a bar notched at `consolidate_sr` ("falls back") and
      `withdraw_sr` ("breaks"); a stronghold with `withdraw_sr` 0 shows only the
      first notch and "never withdraws";
    - order lines, queue numbers, escort and regroup slot ghosts, the focus
      marker, and the **leash ring** of each selected Hold or Escort ship (Fleet
      Orders UI);
    - link lines with state, and each cut ship's relink ETA or reason (TIMER,
      STRAINED, NO_PROVIDER, CAPACITY) (Coherence & Links UI);
    - queued-order and latched-press markers, each cancellable; step controls
      when "Tactical step" is on (Simulation Tick UI 4, 6);
    - range rings for selected ships (rule 21);
    - the edge line, zones and ghost paths (Combat Space UI);
    - the label budget rises to `LABEL_MAX_HELD` (D2).
13. **Hover tier.** Under the cursor (held, or live for the locked target only):
    - **Ship inspector**: name, hull, Vigor bar with numbers or Coherence link
      state, every active movement multiplier (Combat Space rule 6a), weapon
      states, current order.
    - **Target preview** on the hovered or locked target: shown hit chance and
      expected hull damage per hit for the selected weapon or group, "if
      nothing changes" (Weapons & Damage UI).
    - **Relay hover**: the whole subtree highlighted, capacity used and ports.
    - **Link hover** (held only): "hits to dash / hits to snap" for the selected
      weapon.
    Hover shows after `HOVER_DELAY_MS`; keyboard focus on a ship (rule 30) shows
    the same inspector at once.
14. **A tier adds; it never hides.** Opening the held tier never removes a live
    element. Leaving it removes only held and hover elements.

**D. The pre-battle panel**

15. **The pre-battle panel opens before tick 0** of every battle, as a planning
    hold (Simulation Tick & Pause), whatever the Battle-start auto-pause toggle
    says. No tick runs while it is open. It is the only place the defeat cost is
    shown before a fight, and "bills are never surprises" (Credits Game Feel).
    It needs an amendment to Simulation Tick & Pause (Open Question 2).
16. **The panel shows, in this order:**
    1. "The battle ends when either side has no ship on the field, or at the
       time limit" with the limit in minutes (Battle Resolution UI);
    2. the player's retreat zone, shown on the field behind the panel;
    3. Credits' defeat cap and "plus up to N rest days (≈ X upkeep)", and the
       suppression coverage after a worst-case bill when a lie is held (Credits
       UI);
    4. "STANDOFF counts as a retreat; salvage lost scales with the share of the
       fleet left behind" (Battle Resolution UI);
    5. when `k_present > 0`: "⟨k⟩ lent ⟨f⟩ ships. Each one lost costs ⟨band⟩
       standing with ⟨f⟩", and the band reached if all are lost (Allied Lending
       rule 19);
    6. each enemy fleet: its doctrine name and the Dossier sentences already
       revealed for it, and nothing more (rule 5).
17. **Leaving the panel.** "Begin" (Enter) closes it. If Battle-start auto-pause
    is on, the battle then sits held at tick 0; if off, it runs. The panel can be
    reopened while held with a bound key (default `Tab`-free: `B`, an Input
    amendment); it is then read-only and shows the same lines.

**E. Vigor and Coherence read differently (Pillar 5)**

18. **Vigor is on the ship, continuous and alive.** Per organic ship:
    - one bar: ceiling as the bar's **length**, pool as its **fill**, the floor
      as a tick mark (Vigor UI). The bar **only empties when Vigor is spent**;
      taking hits never fills it, and it has no "overload" or "vent" state;
    - the band word (OK, LOW, EMPTY, FLOOR) beside the bar, and the "dry in N s"
      marker in LOW (Vigor rule 13);
    - on the hull: core brightness `C_k ÷ C_k0` and pulse rate (pool
      emptiness), drawn by art (Vigor Interactions);
    - while ember fire is active, the bar's ceiling end visibly burns back;
      a flow-cap refusal flashes a short cue on the weapon (Vigor UI).
    Vigor's bar is shown live for the flagship and selected ships; for other
    organic ships only a band glyph appears in LOW, EMPTY or FLOOR.
19. **Coherence is between ships, discrete and mechanical.** Per machine fleet:
    - **no bar** of any kind, for a fleet or a link ("strain without a bar";
      Coherence & Links UI);
    - link lines in four patterns: SOLID, DASHED, SNAPPED with a spark, RELAYED
      (solid with a mid-line node);
    - the fleet band as a word: WHOLE, FRAYING, BROKEN;
    - counts, not fills: "2 hits to snap", "relinks in 4 s".
20. **The two never share a widget.** No element shows Vigor as lines or a band
    word over a fleet; no element shows Coherence as a fill or a ship-mounted
    meter. Vigor is read on one ship; Coherence is read across a group. This is
    how the HUD keeps the design test: "if a Starsector player can map Vigor 1:1
    onto flux, Vigor fails" (Game Concept; Vigor rule 11).

**F. Clutter limits**

21. **Rings and arcs.** At most `RING_MAX` (6) range rings at once: the
    flagship's player groups while a fire button is held, and selected ships in
    the held tier, nearest the cursor first. Leash rings count toward it.
22. **Labels.** At most `LABEL_MAX_LIVE` (12) ship labels live and
    `LABEL_MAX_HELD` (24) held, chosen by priority (D2). A ship without a label
    keeps its icon and markers. Overlapping labels drop the lower priority one.
23. **Notices.** Notices (standoff warning, flagship lock gained, BROKEN, order
    rejected with its reason) stack in one column, at most `NOTICE_MAX` (3). A
    notice holds `NOTICE_HOLD_MS` (4,000) of real time and never takes keyboard
    focus. A fourth replaces the oldest; the battle log keeps all of them.
24. **One banner.** At most one banner at a time. The auto-pause banner lists
    every trigger that fired on that tick, each entry linked to its toggle
    (Simulation Tick UI 5). The end banner replaces any other banner.
25. **Off-screen markers.** At most `OFFSCREEN_MAX` (4): the flagship always
    first, then the locked target, the Focus target, and the nearest ship
    holding a flagship lock. Each is clamped inside the screen inset (D3).
    Off-screen markers show only `hud_visible` ships.

**G. Battle end and debug**

26. **The end banner** names the outcome in words: "Victory", "They broke",
    "Withdrawn", "Fleet disabled", "Standoff", and "Pyrrhic victory" when
    `end_cause = MUTUAL` (Battle Resolution UI). It holds for `END_BEAT_MS`
    while the camera ignores input (Camera rule 19), then the Debrief opens.
27. **After the flagship is gone**, while held, the order menu's Retreat stays
    reachable for any selection (Battle Resolution UI; Fleet Orders rule 3).
28. **The debug overlay** exists only in dev builds. It shows Ship AI's debug
    view, reason codes and draw counts. It is not in `HudVisibleFields`, is
    never in release, and never feeds the Runner's `BotView`.

**H. Accessibility and input**

29. **No colour-only signal.** Every state the HUD shows has a shape, pattern,
    word or number as well as a hue: side (marker shape and outline), damage
    type (icon shape; Weapons & Damage UI), link state (line pattern), band
    (word), weapon state (word or icon), disabled (marker shape). The HUD must
    pass a greyscale read at 32 px (AC-21).
30. **Keyboard focus.** While the battle runs, the HUD never takes keyboard
    focus; every key goes to the helm. While held or a panel is open, `Tab` and
    `Shift+Tab` move focus through the HUD regions in a fixed order: banner,
    hold indicator and resume, speed and step controls, order menu, focused
    ship. Arrow keys cycle the focused ship among `hud_visible` ships by screen
    position. `Esc` returns focus to the field. The focused element always has a
    visible focus ring. A new notice never moves focus.
31. **Text scale.** All HUD text scales with `ui_scale` (D5), from 750 to 2,000
    ‰, and never below `TEXT_MIN_PX`. Layout reflows; nothing is clipped.
32. **Palettes.** The default palette is chosen to be safe for the common forms
    of colour-blindness; a high-contrast palette is offered. Each is a data
    swap; no meaning changes with palette.
33. **Reduce motion.** Pulses become steady markers with the same shape. The
    Vigor pulse-rate channel is replaced by the band word and "dry in N s",
    which are always present, so no information is lost.

### States and Transitions

| State | Entered when | Shows | Leaves to |
|---|---|---|---|
| PRE_BATTLE | battle context created, before tick 0 | pre-battle panel over the field (rule 16) | HELD (Battle-start auto-pause on), LIVE (off) |
| LIVE | simulation running | live tier | HELD, COMMAND, ENDING |
| HELD | any hold active (pause, auto-pause, Case File, saving, unfocused) | live + held + hover tiers; hold reasons | LIVE (resume), COMMAND, ENDING (never while held) |
| COMMAND | Command context opened (Input & Controls) | live + held tiers; order menu | HELD, LIVE |
| ENDING | battle end declared (Battle Resolution) | end banner only, plus the battle bar | — (the Debrief opens after `END_BEAT_MS`) |
| DEBUG (overlay, dev only) | debug toggle | Ship AI debug view over any state | the same state without it |

The panel can reopen in HELD as a read-only overlay (rule 17); it does not
change the state.

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | #1 → #46 | Hold state and reasons, alpha, speed (D5), auto-pause triggers per tick, queued and latched markers |
| Gameplay Settings & Modifiers (#7) | #7 → #46 | `ui_scale`, `telegraph_early_warning_ticks`, palette, reduce motion |
| Input & Controls (#6) | both | HUD regions are focus targets; glyphs for latched presses; `B` reopens the panel (amendment) |
| Combat Event Bus & Battle Record (#9) | #9 → #46 | Read-only batches after P9 |
| Vigor (#13) | #13 → #46 | Pool, ceiling, floor, band, dry-in, ember and flow-cap events |
| Coherence & Links (#14) | #14 → #46 | Line states, cause codes, relink ETAs, fleet band, strain preview formula |
| Weapons & Damage (#12) | #12 → #46 | Ranges, arcs, cooldowns, states, shown hit chance and expected damage formula, type icons |
| Combat Space (#11) | #11 → #46 | Interpolated positions, ghost paths, edge line, zones, active multipliers |
| Flagship Piloting | → #46 | Group arcs, cooldowns, lock, move frame, AUTO and EMPTY marks |
| Fleet Orders (#19) | #19 → #46 | Order lines, queue, slot ghosts, focus, leash radii (D4, D5), rejection reasons |
| Fleet Coordination (#21) | #21 → #46 | Slots, phase, tells (declared and effective tick), `sr_pm` per fleet (amendment), flagship locks |
| Ship AI (#20) | #20 → #46 (debug only) | Debug view; nothing in release |
| Battle Resolution & Retreat | → #46 | Present counts, warning, end outcome and cause, pre-battle lines |
| Credits, Upkeep & Sinks (#18) | #18 → #46 | Defeat cap, rest-day quote, suppression coverage |
| Allied Lending (#33) | #33 → #46 | `preview_lent_loss()`, lent tags, days left |
| Dossier | Dossier → #46 | Revealed doctrine sentences for the panel |
| Camera & Combat View (#45) | #45 → #46 | Transform, `H`, state, flagship-on-screen; uses `hud_visible` for frame sets |
| Runtime ID Service (#3) | #3 → #46 | Spawn and despawn events, display names |
| World Clock | → #46 | Battle time |
| Save/Load & Migration | — | Save indicator has a reserved corner the HUD never uses |
| AI-vs-AI Runner (#25) | #46 → #25 | `HudVisibleFields` (rule 8) |

## Formulas

The HUD is presentation. Its maths runs in floating point per frame and is not
part of the simulation hash. Results are rounded to whole pixels.

### D1. World to screen, and the on-screen test

`s = (V_h ÷ 2) ÷ H` (pixels per world unit);
`x_px = V_w ÷ 2 + (x_w − c_x) × s`; `y_px = V_h ÷ 2 + (y_w − c_y) × s`.
A ship is **on screen** when `M ≤ x_px ≤ V_w − M` and `M ≤ y_px ≤ V_h − M`,
with `M = OFFSCREEN_INSET_PX`. Elements of off-screen ships are culled; only
D3's marker remains, if the ship qualifies (rule 25).

| Variable | Range | Description |
|---|---|---|
| `V_w`, `V_h` | 1,280 – 7,680 / 720 – 4,320 px | Viewport size |
| `H` | `ZOOM_MIN_H` – `ZOOM_MAX_H` | Camera half-height in world units (Camera D3) |
| `c` | field | Camera centre |
| `M` | 24 – 96 px; 48 | Inset |

### D2. Label priority

`P = 100 + 1,000·flagship + 500·selected + 400·(locked or Focus target) +
300·anchor_relay + 200·warn_state + 150·hull_low`, where `warn_state` is Vigor
LOW / EMPTY / FLOOR or a cut machine ship, and `hull_low` is hull below
`HULL_LOW_PM` (300 ‰). Sort by `P` descending, ties to the lower Runtime ID;
label the first `LABEL_MAX` (live 12, held 24) on-screen ships; then drop any
label that overlaps a higher-priority one. The flagship's label is never dropped.

| Variable | Range | Description |
|---|---|---|
| `P` | 100 – 2,650 | Priority score |
| `LABEL_MAX` | 6 – 40 | Budget by tier |

### D3. Off-screen marker position

From the screen centre `o = (V_w ÷ 2, V_h ÷ 2)` toward the ship's `(x_px, y_px)`,
with `d = (x_px − o_x, y_px − o_y)`:
`t = min( (V_w ÷ 2 − M) ÷ |d_x| , (V_h ÷ 2 − M) ÷ |d_y| )` (a term with a zero
denominator is skipped); marker at `o + t × d`, pointing along `d`, with the
distance in world units as text.

### D4. Icon mode

`ICON_ZOOM_H = ZOOM_MAX_H × ICON_ZOOM_PM ÷ 1,000`. When `H ≥ ICON_ZOOM_H`, ships
draw as constant-size icons of `ICON_PX`, and labels keep the same pixel size
(Camera UI).

### D5. Text size

`text_px = max(TEXT_MIN_PX, round(TEXT_BASE_PX × ui_scale ÷ 1,000))`.

### D6. Standoff countdown

`remaining_s = ceil((BATTLE_LIMIT_S × 60 − tick) ÷ 60)`, shown as m:ss from the
warning (`sim_s ≥ BATTLE_LIMIT_S − STANDOFF_WARN_S`, Battle Resolution D3) until
the end. The HUD never shows a countdown before the warning has been emitted.

### Worked example (checked)

Viewport 1,920 × 1,080, `H` = 1,080, `c` = (0, 0), `M` = 48.
- **D1:** `s = 540 ÷ 1,080 = 0.5`. The flagship at world (3,000, 400) is at
  `x_px = 960 + 1,500 = 2,460`, `y_px = 540 + 200 = 740`. 2,460 > 1,872, so it is
  **off screen**.
- **D3:** `d = (1,500, 200)`. `t = min(912 ÷ 1,500, 492 ÷ 200) = min(0.608,
  2.46) = 0.608`. Marker at `(960 + 912, 540 + 121.6)` = **(1,872, 662)**, inside
  the inset (48 ≤ 662 ≤ 1,032). Check: 1,500 × 0.608 = 912 ✓; 200 × 0.608 =
  121.6 ✓.
- **D2** with an illustrative `LABEL_MAX` of 3 and five on-screen ships:
  flagship A = 100 + 1,000 = **1,100**; selected escort B in LOW Vigor = 100 + 500
  + 200 = **800**; enemy Focus target D = 100 + 400 = **500**; enemy anchor relay
  C = 100 + 300 = **400**; plain enemy E = **100**. Labels: A, B, D. C and E keep
  icons and markers.
- **D5:** `ui_scale` 750 → round(16 × 0.75) = 12 = `TEXT_MIN_PX` ✓; 2,000 → 32.
- **D6:** tick 102,001 with `BATTLE_LIMIT_S` 1,800: `(108,000 − 102,001) ÷ 60 =
  99.98`, ceil **100 s**, shown "1:40". The warning fired at `sim_s` 1,680 (tick
  100,800) ✓.

## Edge Cases

- **If a value the HUD needs is not published**: the element shows "—" and
  logs a dev warning. It never computes the value from unpublished state.
- **If a ship spawns or despawns between frames**: views are created and freed
  only on Runtime ID spawn and despawn events; a despawned ship's labels and
  markers go the same frame.
- **If the flagship is lost while held**: the off-screen marker points at the
  loss position until resume (Camera rule 17); the flagship panel shows
  "Flagship disabled" and the Retreat order stays reachable (rule 27).
- **If more ships qualify for labels than `LABEL_MAX`**: D2 decides; at most one
  "+N" chip per screen quadrant shows the unlabelled count.
- **If two off-screen markers would overlap**: the lower-priority one slides
  along the edge by its own width; if it still overlaps, it is dropped.
- **If several auto-pause triggers fire on one tick**: one banner lists all of
  them (Simulation Tick UI 5).
- **If a notice arrives while a banner shows**: the notice goes to the column;
  the banner keeps its place.
- **If a tell is cancelled by BROKEN** (Fleet Coordination Edge Cases): the
  pulse and countdown stop at once and the BROKEN notice shows.
- **If `consolidate_sr` and `withdraw_sr` notches coincide**: both labels show,
  stacked; a stronghold shows one notch and "never withdraws".
- **If the strength ratio exceeds the bar**: the bar clamps at 2,000 ‰ and the
  ratio text still states the true value.
- **If `ui_scale` makes the flagship panel wider than a third of the screen**:
  the panel wraps to two rows; no element is hidden.
- **If the viewport is 21:9 or wider**: the live tier stays inside a 16:9 safe
  frame centred on the screen; only markers use the full width.
- **If the window loses focus**: the "window unfocused" hold shows its reason
  (Simulation Tick UI 1); hover clears.
- **If `telegraph_early_warning_ticks` > 0**: the HUD cannot warn before a tell
  is declared without reading hidden state (rule 2). Until Open Question 3 is
  answered, the HUD extends only the visible tell, never starts it early.
- **If no enemy fleet has a revealed Dossier sentence**: the panel shows the
  doctrine name and "Not yet observed".
- **If `k_present` is 0**: the lent-loss line is omitted, not shown as zero.
- **If the debug overlay is toggled in a release build**: the key does nothing.
- **Degenerate use — pausing every tick to read the held tier**: allowed and
  intended (Pillar 4); the held tier shows no fact that is hidden live, only
  more of them. The Runner's `BotView` matches it, so no tool gets more.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | Hold, speed, triggers, markers; pre-battle planning hold (amendment) |
| Gameplay Settings & Modifiers (#7) | Hard | `ui_scale`, palette, reduce motion, `telegraph_early_warning_ticks` |
| Vigor (#13) | Hard | Bar, band, dry-in |
| Coherence & Links (#14) | Hard | Lines, band, ETAs, strain preview |
| Fleet Orders (#19) | Hard | Order visuals, leash rings |
| Ship AI (#20) | Soft | Debug overlay only |
| Camera & Combat View (#45) | Hard | Transform, `H`, state; shares `hud_visible` |
| Runtime ID Service (#3) | Hard | Spawn and despawn, display names |
| Combat Event Bus & Battle Record (#9) | Hard | Batches after P9 |
| Weapons & Damage (#12), Combat Space (#11), Flagship Piloting | Hard | Readouts per their UI sections |
| Fleet Coordination (#21) | Hard | Slots, phase, tells, `sr_pm` (amendment), locks |
| Battle Resolution & Retreat | Hard | Counts, warning, outcome, panel lines |
| Credits (#18), Allied Lending (#33), Dossier | Hard | Pre-battle panel lines |
| Input & Controls (#6) | Hard | Focus, bindings |
| World Clock, Save/Load | Soft | Battle time; reserved corner |
| AI-vs-AI Runner (#25) | Hard (reverse) | `HudVisibleFields` |
| After-Action Debrief (#24) | Soft (reverse) | Shares outcome wording with the end banner |

Bidirectional check: Simulation Tick, Settings, Vigor, Coherence, Fleet Orders,
Fleet Coordination, Weapons, Combat Space, Flagship Piloting, Battle Resolution,
Allied Lending, Credits, Camera, Runtime ID and the Runner name #46. The
systems index's dependency list for #46 must add Fleet Coordination, Battle
Resolution, Weapons, Combat Space, Flagship Piloting, Credits, Allied Lending,
Dossier and the Event Bus.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `LABEL_MAX_LIVE` | 12 | 6 – 20 | Feel | Live clutter. Too high hides the fight; too low hides names |
| `LABEL_MAX_HELD` | 24 | 12 – 40 | Feel | Held-tier density |
| `RING_MAX` | 6 | 3 – 10 | Feel | Rings and arcs at once |
| `NOTICE_MAX` | 3 | 2 – 5 | Feel | Notice column height |
| `NOTICE_HOLD_MS` | 4,000 | 2,500 – 8,000 | Feel | Real-time notice life |
| `OFFSCREEN_MAX` | 4 | 1 – 6 | Feel | Edge markers |
| `OFFSCREEN_INSET_PX` | 48 | 24 – 96 | Feel | D1, D3 inset |
| `HOVER_DELAY_MS` | 250 | 0 – 600 | Feel | Inspector delay |
| `HULL_LOW_PM` | 300 | 200 – 500 | Curve | D2 low-hull bonus |
| D2 weights | 1,000 / 500 / 400 / 300 / 200 / 150 | each 0 – 1,000; flagship highest | Curve | Label order |
| `ICON_ZOOM_PM` | 600 | 400 – 900 | Gate | Icon mode threshold (D4) |
| `ICON_PX` | 24 | 16 – 40 | Feel | Icon size at max zoom |
| `TEXT_BASE_PX` | 16 | 14 – 20 | Feel | D5 base |
| `TEXT_MIN_PX` | 12 | 10 – 14 | Gate | D5 floor |
| `SR_BAR_MAX_PM` | 2,000 | 1,500 – 4,000 | Feel | SR bar clamp |

All in `assets/data/ui/hud/`. Palettes in `assets/data/ui/palettes/`. Values
owned elsewhere (`TELL_TICKS`, `END_BEAT_MS`, `STANDOFF_WARN_S`, `ui_scale`) are
read, never copied.

## Visual/Audio Requirements

- Side identity by marker shape and outline style; art-director chooses the
  shapes. Hue is a second channel only.
- Damage types by icon shape (Weapons & Damage UI).
- Vigor art: core brightness and pulse; a struck dark core goes out (Vigor V/A).
  Coherence art: the four line patterns; snaps spark (Coherence V/A).
- Disabled player ships go dark and drift; their marker reads "out", distinct
  from a destroyed enemy (Battle Resolution V/A).
- The HUD adds sound only for: the standoff warning (once), the BROKEN sting
  (Fleet Coordination), the first ember shot per EMPTY band (Vigor UI), and the
  outcome stinger (Audio #52). Notices are otherwise silent.
- The rendering of glows and per-instance shader state is NOT SOURCEABLE for
  4.7.2 (systems index risk); the HUD must not depend on glow for meaning.

## Game Feel

- **Quiet at speed, full when held**: the live tier fits in a glance.
- **The board answers questions**: every held-tier element answers "what
  happens next?" or "what does it cost?".
- **The helm is never interrupted**: no HUD element takes a key while running.
- **Nothing pops without a cause**: every notice names its cause in words.

## UI Requirements

- The four regions: flagship panel (bottom left), battle bar (top centre),
  notice column (right), banner (top centre, under the bar). Save indicator
  corner reserved (Save/Load UI). Final layout belongs to `/ux-design` in
  `design/ux/hud.md`.
- Every element in this GDD's tiers is keyboard-reachable while held (rule 30).
- Wording for the hold indicator, notices and the panel goes to
  `narrative-director` with the UX spec (naval-bridge calm).
- Each screen and state touched has a retained screenshot in
  `production/qa/evidence/`.
- 📌 **UX Flag — Combat HUD & Tactical Overlay**: run `/ux-design` for
  `design/ux/hud.md` and the pre-battle panel before epics. It absorbs the UX
  flags of Simulation Tick, Vigor, Coherence, Fleet Orders, Fleet Coordination,
  Weapons, Flagship Piloting, Combat Space, Camera and Battle Resolution, and
  the HUD lines of Allied Lending and Credits.

## Cross-References

| Source | Section | Obligation honoured here |
|---|---|---|
| `simulation-tick-and-pause.md` | UI Requirements 1–6 | Rules 11, 12, 24; States |
| `gameplay-settings-and-modifiers.md` | Interactions (#7 → #46) | Rules 31–33; D5; OQ 3 |
| `vigor.md` | UI; rule 13; Interactions | Rules 18, 20, 33 |
| `coherence-and-links.md` | UI; V/A | Rules 12, 13, 19, 20 |
| `fleet-orders.md` | UI | Rule 12 |
| `fleet-coordination.md` | UI; rule 11; D2 | Rules 11, 12; OQ 1 |
| `weapons-and-damage.md` | UI | Rules 3, 13, 29 |
| `flagship-piloting.md` | UI; V/A | Rule 11 |
| `combat-space.md` | rule 6a; UI | Rules 12, 13 |
| `battle-resolution-and-retreat.md` | UI; rule 5 | Rules 11, 16, 26, 27; D6 |
| `camera-and-combat-view.md` | rule 12; UI | Rules 10, 25; D3, D4 |
| `ship-ai.md` | rules 14, 16 | Rules 7, 28 |
| `allied-lending.md` | rule 19; UI | Rules 11, 16 |
| `credits-upkeep-and-sinks.md` | UI | Rule 16 |
| `runtime-id-service.md` | Presentation | Rule 6; Edge Cases |
| `ai-vs-ai-runner-and-ai-debug-tools.md` | rule 2; AC-01b | Rule 8 |
| `input-and-controls.md` | latched glyphs | Rules 11, 30 |
| `save-load-and-migration.md` | indicator placement | UI Requirements |

## Acceptance Criteria

- **AC-01 (Logic; rules 1–2)**: a static check finds no HUD code path that reads an RNG stream, Ship AI candidate scores, Truth Seeding state or any field outside each owner's published list; the simulation hash of a scripted battle is identical with the HUD on and off.
- **AC-02 (Logic; rule 3)**: shown hit chance, expected damage, hits-to-snap and dry-in values equal their owner formulas on fixtures, and no RNG cursor advances while they are computed.
- **AC-03 (Logic; rule 4)**: the present counts and SR shown equal Battle Resolution D1 and Fleet Coordination's published `sr_pm` on every tick of a scripted battle.
- **AC-04 (Logic; rule 8)**: the schema of `HudVisibleFields` equals the Runner's `BotView` field set (shared with Runner AC-01b); the debug overlay's fields are not in it.
- **AC-05 (Logic; rules 9–10)**: with every ship on the field, `hud_visible` is true for all; Camera frame sets and the HUD's drawn set are equal.
- **AC-06 (Logic; D1, D3)**: the worked example gives off-screen and a marker at (1,872, 662) ±1 px; a ship directly above centre gives a marker with x = 960.
- **AC-07 (Logic; D2)**: the five-ship fixture with budget 3 labels A, B, D; ties break to the lower Runtime ID; the flagship label survives every overlap.
- **AC-08 (Logic; D5)**: `ui_scale` 750, 1,000, 2,000 give 12, 16, 32 px.
- **AC-09 (Logic; D6)**: no countdown before the warning; at tick 102,001 it reads "1:40".
- **AC-10 (Logic; rule 7)**: a release build contains no reason-code string in any HUD-visible text.
- **AC-11 (Logic; rules 21–25)**: a 40-ship fixture never exceeds `RING_MAX`, `LABEL_MAX_*`, `NOTICE_MAX`, `OFFSCREEN_MAX` or one banner.
- **AC-12 (UI; rule 11)**: live tier at 1×: flagship panel, battle bar, lock markers, band words, off-screen marker; retained screenshot.
- **AC-13 (UI; rule 12)**: held tier: phase names, SR bar with both notches, order lines, a leash ring, link ETAs; retained screenshot.
- **AC-14 (UI; rule 13)**: ship inspector and target preview labelled "if nothing changes"; retained screenshot.
- **AC-15 (UI; rules 15–16)**: the pre-battle panel before tick 0 shows all six line groups, including the lent-loss line with `k_present` 2 and the defeat cap; the tick counter reads 0; retained screenshot.
- **AC-16 (UI; rule 26)**: each of the six end banners, in words; retained screenshots.
- **AC-17 (UI; rule 24)**: an auto-pause banner with two triggers from one tick, each linked to its toggle; retained screenshot.
- **AC-18 (UI; rules 18–20)**: one screen showing an organic ship's Vigor bar in LOW with "dry in N s" beside a machine fleet with a DASHED and a SNAPPED link and the band word; no Coherence bar exists; retained screenshot.
- **AC-19 (UI; rule 31)**: at `ui_scale` 2,000 at 1,280 × 720 nothing is clipped; retained screenshot.
- **AC-20 (UI; rule 30)**: while held, `Tab` reaches every region in order with a visible focus ring; while running, no key press is consumed by the HUD; retained screenshot of the focus ring.
- **AC-21 (UI; rule 29)**: a greyscale capture of AC-12 and AC-18; testers name side, link state, band and damage type in ≥ 90 % of cases at 32 px; screenshots retained.
- **AC-22 (UI; rule 32)**: each palette applied to the AC-13 scene; retained screenshots.
- **AC-23 (Playtest; Pillar 5)**: at least 4 of 5 Starsector-literate testers, shown the HUD only, say Vigor and Coherence are different kinds of resource and do not call the Vigor bar "flux" (shared with Vigor AC-16).
- **AC-24 (Playtest; rules 11–12)**: 4 of 5 testers, after one paused look, can say which enemy fleet is nearest to falling back and why.
- **AC-25 (Playtest; rule 15)**: 4 of 5 testers can state the defeat cost of a battle they are about to fight; none says a bill surprised them.
- **AC-26 (Playtest; rule 11)**: no tester reports losing track of the flagship, and 4 of 5 call the live tier "readable at 2×".

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review), with the matching
amendments made in the same change:
- **The pre-battle panel always holds before tick 0**, whatever the
  Battle-start auto-pause toggle says: battle costs are quoted before a battle
  (Simulation Tick & Pause hold list amended: `PLANNING:prebattle`).
- **`telegraph_early_warning_ticks` makes a declared tell stay visible
  longer**; it never warns before a tell is declared, so it reads no hidden
  state.
- **MVP palettes**: a colour-vision-deficiency-safe default plus a
  high-contrast palette; per-type presets later.
- **Fleet Coordination publishes `sr_pm` per fleet and each tell's declared
  and effective ticks** for the HUD (Fleet Coordination rule 12 amended).
- **Camera frame sets use `hud_visible`** (Camera rule 12 amended).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 5 | Is "no fog of war" the right MVP choice, or does the fantasy want sensor range later? | creative-director | Vertical Slice |
| 7 | Default key to reopen the pre-battle panel (`B` proposed). | game-designer (Input) | UX spec |
| 8 | Hold-indicator, notice and banner wording. | narrative-director | UX spec |
| 9 | Icon threshold and chart-margin look (Camera OQ 7); `ICON_ZOOM_PM` 600 is a placeholder. | art-director, ux-designer | UX spec |
