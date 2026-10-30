# Gameplay Settings & Modifiers

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on lie/truth price ratio, first-stronghold-still-wins, AI level vs doctrine, shared organic/machine keys, and the pillar header; all five revised
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — difficulty changes how hard, never how readable); Pillar 2 (The Truth Is Yours to Tell — investigators slow, never stop; difficulty never touches evidence, previews or the price of a lie relative to the truth); Pillar 3 (Hands on the Helm — pause, speed and assists are commitments, not polish)

## Summary

Gameplay Settings & Modifiers holds every player-adjustable value and decides
which ones the simulation may see: comfort settings (controls, speed,
auto-pause, assists) stay with the player and never touch the simulation, while
challenge modifiers (stronghold strength, defeat cost, Vigor erosion,
investigator pace) belong to a campaign, are saved and hashed, and change only
outside battle with a log. Presets (Chronicler, Standard, Admiral) change what a
comeback costs, never whether it must be earned (Pillars 1 and 3).

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Content Data & Mod Loading, Save/Load & Migration`; read by Simulation Tick & Pause, Input & Controls, Vigor, Ship AI and the HUD

## Overview

Gameplay Settings & Modifiers is the one place where every player-adjustable
value lives, and the rule that decides **which of those values the simulation
may ever see**. It holds two kinds:

- **Profile settings (Tier P)** are comfort: controls, timing thresholds, UI
  scale, speed steps, auto-pause toggles, assists. They belong to the player,
  live outside every save, and change at any moment. The simulation never
  reads them. They can reach a battle only as recorded commands or as how
  often ticks run, both of which already replay exactly.
- **Campaign modifiers (Tier C)** are challenge: how strong strongholds are,
  what a defeat costs, how fast Vigor erodes, how quickly rival investigators
  move. They belong to one campaign, are saved in it, are part of `state_hash`,
  and are written into every Battle Record header. Simulation systems receive
  them as a frozen, injected set; nothing reads them from a global.

One test sorts every value: **if the simulation reads it directly, it is a
campaign modifier; if it only shapes commands or cadence, it is a profile
setting.**

Difficulty **presets** (Chronicler, Standard, Admiral, or Custom) are a content
kind (Content Data & Mod Loading): choosing one fills the campaign modifiers,
and can suggest comfort settings. This system sits in Foundation so that Vigor,
Ship AI, Battle Resolution and the HUD read their values from here from the
first build, and difficulty is never retrofitted. The option screens (#55, #56)
are Vertical Slice.

## Player Fantasy

**The game meets me where I am, and the stronghold still beats me first.** The
player barely notices this system. Whatever they choose, the rhythm of the game
is the same: lose, read the Debrief, prepare, return, win. Settings change how
much they must handle and what a comeback costs; they never decide whether the
comeback has to be earned.

*Anchor moment:* a player who came for the mystery picks Chronicler. Their
first stronghold still beats them; the Debrief still names the cause; the fix
still takes a return trip, just a shorter one. A Starsector veteran on Admiral
loses to the same stronghold, for the same reason, and pays more for it.

**Pillars served:**
- **Pillar 1, *Every Defeat Is a Lead*:** no setting removes the cost of
  defeat (a floor above zero) or the Debrief's cause and counter.
- **Pillar 2, *The Truth Is Yours to Tell*:** no setting touches the seeded
  truth, the evidence, or the accuracy of sharing previews; investigators can
  slow, never stop.
- **Pillar 3, *Hands on the Helm*:** pause, speed, auto-pause and assists are
  commitments, not polish (concept: pillar-tension resolution).

**Tone:** respectful and quiet. Settings are named plainly; nothing is called
"Easy"; nothing shames a choice.

**This system must never make the player feel:**
- **"The easy mode skipped the game."** (Every preset keeps the loop.)
- **"I'm being judged for my settings."** (Neutral labels, no lock-outs.)
- **"Something changed and nobody told me."** (Every modifier change is logged
  and shown.)

*Framing chosen from `game-designer`'s two ("meets me where I am" over "I set
the terms of my war", which put the settings screen at the centre).*

## Detailed Design

### Core Rules

**A. Two tiers**

1. **Every setting has exactly one tier**, declared in its schema:
   - **Tier P (profile)**: stored in `user://profile/settings`, versioned, outside
     every save. Read by Input, the Tick driver (between ticks only), Camera,
     HUD, Audio and menus.
   - **Tier C (campaign)**: stored in the campaign's save as the required
     section `base:modifiers` (Save/Load & Migration, Core Rule 7). Read only by
     simulation systems, through injection.
2. **The sorting test.** A value the simulation reads directly is Tier C. A
   value that only changes *what commands the player produces* (move frame,
   aim assist, hold/toggle) or *how often ticks run* (speed, pause, auto-pause,
   focus-loss pause) is Tier P. Commands are recorded and cadence is outside
   `state_hash` (Simulation Tick & Pause, rule 14), so Tier P never breaks a
   replay.
3. **No setting may change hashed state through the back door.** Example: an
   auto-pause toggle only decides whether a trigger's fire adds a hold; the
   trigger itself is evaluated either way (Simulation Tick & Pause D7, amended
   2026-10-30). Every new Tier P setting must show the same separation, or it
   is Tier C.
   Presentation keys added by later GDDs are Tier P: `CAMERA_SHAKE_PM` (0 –
   1,000 ‰, default 500; Camera & Combat View), `RESUME_RECENTRE` (on), the
   palette, Reduce motion (zeroes shake and replaces full-screen flashes with a
   tint), held-tier layer defaults (Combat HUD), `onboarding_hints`
   (Onboarding), window mode, resolution, VSync and audio volumes (Menus,
   Settings & Save UI). None reaches the simulation, the save's sim state or
   the replay.
4. **Simulation systems receive a frozen `ModifierSet`** (integer values keyed by
   name) when they are constructed or when a context starts. No simulation code
   reads the profile store, an autoload or a global for a gameplay value. A test
   enforces both.

**B. Campaign modifiers**

5. **The campaign stores a resolved snapshot.** The `base:modifiers` section
   holds: the preset ID chosen, the player's per-key overrides, the **resolved
   value of every key** (Formulas D1), and the change log (rule 8). The snapshot
   is the truth: once a campaign starts, editing a preset's definition in a
   newer build changes nothing in that campaign until the player re-applies it
   (Edge Cases).
6. **Every Tier C value is an integer.** Multipliers are permille (1000 = no
   change) and compose with integer arithmetic (Formulas D2), so a modifier
   never introduces floats into the simulation.
7. **When modifiers may change.** Outside BATTLE, at a tick boundary, from the
   Settings screen or at a port. In BATTLE the set is frozen; a change requested
   there is queued and applied at the first boundary after the battle ends, and
   the screen says so. Costs already paid at the old values are never refunded.
8. **Every change is logged.** A change writes `MODIFIER_CHANGE {campaign_tick,
   key, old, new}` to the campaign log and the next save. The Debrief and the
   save's voyage record (rule 15) read the log. A battle replay is
   self-contained, because its header carries the frozen set it ran with.
9. **Difficulty never touches** (each a hard rule for the owning GDD):
   - the seeded truth, the fragment set, the red herring, or the Case File's
     reasoning;
   - the accuracy of sharing previews and the exposure readout;
   - the clarity of telegraphs, link lines, hull glow or any readout;
   - the Debrief's cause and counter, and the Dossier's accuracy (Dossier
     readiness is computed against the active modifiers);
   - the Vigor no-lockout floor, the reachable rest port, the cost-free opening
     loss, and the rule that lent ships are never required;
   - the defeat-cost floor (above zero) and the defeat-cost cap ("never the
     run");
   - **the price of a lie relative to the truth**: suppression purchase and
     upkeep scale with `yield_permille`, so a lie costs the same share of income
     on every preset (Pillar 2).
10. **Strongholds scale by numbers, never by composition.** `stronghold_strength`
    scales defensive stats and ship count within the same doctrine (Machine
    Nodes & Strongholds D1, D2), never the keystone, relay tree or weapons, so the Dossier's
    counter-fleet stays correct on every preset. **`enemy_ai_level` scales
    execution only** (reaction delay, focus-fire accuracy, retreat discipline),
    never doctrine or which tactics are available: a Debrief counter valid at
    one level is valid at every level (Ship AI must accept this with the key).
10a. **The first stronghold still wins first.** First-encounter strongholds are
    tuned so that a fleet without Dossier or Debrief preparation loses at
    Chronicler values, and at the Custom minimums. Stronghold and Battle
    Resolution must accept this as a constraint on the minimums of
    `stronghold_strength_permille` and `enemy_ai_level`.
11. **Investigators slow, never stop.** `investigator_pace_permille` has a
    floor of `INVESTIGATOR_PACE_FLOOR` (500): a lie always carries risk
    (Pillar 2).
12. **Ironman is a switch, not a preset.** When on, the campaign keeps only its
    autosaves, battle-start and suspend slots (no manual saves). It can be
    switched off at any time outside battle, which turns the campaign into a
    normal one and is shown in the voyage record. It can never be switched on
    after the campaign starts. (Concept anti-pillar: permadeath only as an
    optional mode.)

**C. Presets**

13. **A preset is a content definition** of kind `difficulty_preset`: a partial
    map from Tier C key to value, plus optional Tier P *suggestions* (extra
    auto-pause triggers, a slower default speed; Simulation Tick & Pause rule
    11). Choosing a preset copies its values into the snapshot; player overrides
    win per key; a key the preset omits takes the schema default. Tier P
    suggestions are offered once ("Apply these comfort suggestions?") and never
    forced. **Organic and machine resource models never share one modifier
    key**: a Coherence-side modifier, if added, is its own key with its own
    range, so no setting flattens the Living-against-Made asymmetry (Pillar 5).
    The shipped presets are:

    | Key (Tier C) | Chronicler | Standard | Admiral | Range |
    |---|---|---|---|---|
    | `stronghold_strength_permille` (accepted by Machine Nodes & Strongholds rule 4) | 750 | 1000 | 1200 | 500 – 1500 |
    | `defeat_cost_permille` (accepted by After-Action Debrief rule 28) | 500 | 1000 | 1500 | 250 – 2000 (floor above 0) |
    | `vigor_erosion_permille` † | 600 | 1000 | 1250 | 250 – 2000 |
    | `rest_days_permille` † (owner: World Clock and Ports, Rest & Care #27) | 500 | 1000 | 1250 | 250 – 2000 |
    | `yield_permille` † (loot, contracts) | 1250 | 1000 | 850 | 500 – 1500 |
    | `investigator_pace_permille` (accepted by Exposure & Rival Investigation D1–D2) | 600 | 1000 | 1250 | 500 – 1500 |
    | `enemy_ai_level` † | 1 | 2 | 3 | 0 – 4 |
    | Tier P suggestions | more auto-pause triggers, 0.5× default | none | none | — |

    † Provisional until the owning GDD (Stronghold/Battle Resolution, Defeat &
    Debrief, Vigor, Ports & Rest, Loot & Contracts, Rival Investigators, Ship AI)
    accepts the key and its range. **Custom** starts from Standard and lets the
    player set every key in its range. Preset names, intents and values are
    starting points for balance.
14. **Mods** may add presets, patch a base preset through the normal content
    override path, and register namespaced keys (`<ns>:key`) with a schema
    (type, range, default, composition). A mod can never change a `base` key's
    range or composition rule. Content validation checks every mod key at load.

**D. Labels and profile settings**

15. **The voyage record.** The save card and the end-of-campaign screen show,
    in plain neutral text, the presets and Ironman state a campaign was played
    on, with the days of each ("Charted on Chronicler, days 1–140; Standard
    from day 141. Ironman."). Assists (Tier P) are never listed. No ending, no
    Dossier content and no achievement is gated by difficulty; any mark for
    Admiral or Ironman only adds.
16. **No difficulty nag.** The game never suggests lowering difficulty after a
    defeat; the Debrief is the answer.
17. **Profile settings apply live.** Every Tier P value takes effect on the next
    frame without a restart (Input & Controls rule 19). The starter catalogue:

    | Key | Type | Range | Default | Consumer |
    |---|---|---|---|---|
    | `speed_steps` | set | from 0.25×–2× (dev 4×) | {0.5×, 1×, 2×} | Tick rule 9 |
    | `default_speed` | enum | a step | 1× | Tick |
    | `auto_pause.<trigger>` | bool | — | per Tick D7 table | Tick D7 (hold only) |
    | `tactical_step` | bool | — | off | Tick rule 12 |
    | `focus_loss_pause` | bool | — | on | Tick rule 16 |
    | `hold_toggle.<action>` + global default | enum | hold / toggle | hold | Input rule 9 |
    | `sticky_modifiers` | bool | — | off | Input rule 9 |
    | `move_frame` | enum | ship / screen | ship | Input rule 16 |
    | `drag_threshold_px` | int | 2 – 20 | 6 | Input D2 |
    | `box_select_delay_ms` | int | 50 – 150 | 100 | Input D2 |
    | `hold_threshold_ms` | int | 150 – 1500 | 400 | Input D3 |
    | `double_click_ms` | int / off | 200 – 800 | 300 | Input D3 |
    | `repeat_delay_ms` / `repeat_interval_ms` | int | 100 – 1000 / 50 – 120 | 400 / 80 | Input D4 |
    | `cursor_sensitivity` | permille | 250 – 4000 | 1000 | Input |
    | `aim_assist` | enum | off / light / strong | off | Input rule 17 |
    | `edge_scroll` (+ band px) | bool (+ int) | band 2 – 8 | off | Input rule 18 |
    | `ui_scale` | permille | 750 – 2000 | 1000 | HUD, menus, Input D2 |
    | `telegraph_early_warning_ticks` | int | 0 – 60 | 0 | HUD (presentation only: an earlier warning, never a slower attack) |

    Cooldowns and re-arm times are designer data in Tick D7, shown read-only.
18. **Assists and Challenge are two groups in one store.** The settings screens
    show *Assists* (Tier P values that reduce what the player must handle) and
    *Challenge* (Tier C values that change the opposition and costs) separately.
    An assist never changes an outcome on its own.

### States and Transitions

**Campaign modifiers**

| State | Entered when | Changes allowed | Leaves to |
|---|---|---|---|
| Unset | new-campaign setup | preset, overrides, Ironman on/off — freely, unlogged | Editable (campaign created; snapshot resolved) |
| Editable | CAMPAIGN context | per-key changes, re-apply preset, Ironman off — each logged | Frozen (battle starts) |
| Frozen | BATTLE context | none; requests queue | Editable (battle ends; queued changes apply and log at that boundary) |

**Profile settings** have no states: they apply live, everywhere.

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | #7 → Tick | Tier P: speed steps, default speed, auto-pause toggles (hold only, D7 amended), tactical step, focus-loss pause. Tick reads them between ticks only |
| Content Data & Mod Loading (#4) | #4 → #7 | `difficulty_preset` kind; mod keys validated against their schema; enabled mod set |
| Save/Load & Migration (#5) | #7 → #5 | Registers `base:modifiers` (required); migrations add new keys at schema default. Ironman restricts the slot kinds offered (rule 12) |
| Input & Controls (#6) | #7 → #6 | Tier P input values (rule 17 table). Input stores bindings itself |
| Vigor (#13), Ship AI (#20), Battle Resolution, Ports & Rest, Loot & Contracts, Rival Investigators, Defeat & Debrief | #7 → each | Frozen `ModifierSet` with their † keys; each GDD must accept its key, range and rule 9 limits |
| Combat Event Bus & Battle Record (#9) | #7 → #9 | The frozen set in every Battle Record header |
| Combat HUD (#46) | #7 → #46 | `ui_scale`, `telegraph_early_warning_ticks` |
| Menus, Settings & Save UI (#51); Accessibility Options UI (#55); Difficulty Options UI (#56) | both | Screens over this store; voyage record on the save card |
| Dossier | #7 → Dossier | Readiness computed against the active modifiers (rule 9) |

## Formulas

### D1. Resolving a campaign modifier

`v_k = clamp( first_defined( override_k, preset_k ⊕ mod_patch_k, default_k ), min_k, max_k )`

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| override_k | int or none | any | player | Per-key Custom value |
| preset_k ⊕ mod_patch_k | int or none | any | content | The chosen preset's value after mod patches |
| default_k | int | [min_k, max_k] | key schema | Always defined |
| min_k, max_k | int | per key | key schema | Range (rule 13 table) |
| v_k | int | [min_k, max_k] | — | Stored in the snapshot |

**Output Range:** always within the key's range; an out-of-range input is
clamped and flagged, never refused. **Example:** Admiral sets
`vigor_erosion_permille` 1250; the player overrides 1100; v = 1100. A mod's
preset says 2500 for the same key with no override: v = clamp(2500, 250, 2000)
= 2000, and the clamp is logged.

### D2. Applying a modifier to a base value

Permille modifier: `eff = (base × m + 500) div 1000` (integer, rounds half up
for non-negative values).

Absolute modifier: `eff = clamp(base + delta, lo, hi)`.

| Variable | Type | Range | Description |
|---|---|---|---|
| base | int | ≥ 0, ≤ 2^53 ÷ 2000 | The consumer's unmodified value |
| m | int | the key's range (250 – 2000 at most) | Permille modifier |
| delta | int | the key's range | Absolute offset |
| eff | int | 0 – 2 × base | Effective value |

**Output Range:** non-negative; at most twice the base. A consumer whose base
could exceed 2^53 ÷ 2000 must widen its type (refused by review otherwise).
**Example:** a defeat that costs 7 days at Standard (604,800 s, the most a
Standard defeat can cost; After-Action Debrief D5) costs (604,800 × 500 + 500)
div 1000 = 302,400 s (3.5 days) on Chronicler and (604,800 × 1500 + 500) div
1000 = 907,200 s (10.5 days) on Admiral, both under `DEFEAT_MAX_S` (14 days).
Chronicler never reaches 0 here because of D3.

### D3. Floors that no setting can cross

`defeat_cost_eff = max(DEFEAT_COST_FLOOR, D2(base, defeat_cost_permille))` when
`base > 0`.

`investigator_pace_permille ≥ INVESTIGATOR_PACE_FLOOR` (500), enforced by the
key's minimum.

| Variable | Value | Owner | Description |
|---|---|---|---|
| DEFEAT_COST_FLOOR | 1 unit of the cost's own measure (provisional) | Defeat & Debrief | A defeat that costs anything costs at least this |
| INVESTIGATOR_PACE_FLOOR | 500 | this GDD | Investigators move at least half speed |

**Example:** a minor defeat that costs 1 day at Standard costs (1 × 500 + 500)
div 1000 = 1 day on Chronicler, not 0.

## Edge Cases

- **If a preset omits a key**: the key takes its schema default; content
  validation lists it as a warning.
- **If an override or an edited save holds an out-of-range value**: it is
  clamped (D1), the UI shows the clamped value with a note, and a load log line
  is written (Save/Load & Migration, Core Rule 25 treats it as data, not an
  attack).
- **If a mod that added keys is removed**: its keys are dropped from the
  snapshot at load, listed in the pre-load summary, and logged as changes.
  Base keys it patched keep their snapshot values.
- **If a newer build changes a shipped preset's values**: existing campaigns
  keep their snapshot. The Settings screen shows "This preset was updated since
  your campaign began" with a logged "Re-apply preset" action.
- **If a newer build adds a key**: an old save gains it at the schema default
  through a section migration.
- **If the player changes Challenge mid-battle**: the change is queued and the
  screen says "Applies after this battle"; it applies and logs at the first
  boundary after BATTLE ends.
- **If the player changes an assist mid-battle**: it applies on the next frame;
  nothing is logged in the campaign and the replay is unchanged (commands
  record its effect).
- **If the player switches Ironman off**: allowed outside battle; logged; the
  voyage record shows the day. Manual slots become available.
- **If the player tries to switch Ironman on mid-campaign**: not offered.
- **If a profile settings file is missing or corrupt**: defaults load, the
  player is told once; no campaign is affected.
- **If two profiles exist on one machine** (OS user accounts): each has its own
  `user://`; nothing is shared. Multiple in-game profiles are not at MVP.
- **If a modifier value would push a consumer's result negative**: D2 can't
  produce one (non-negative base, non-negative modifier).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Content Data & Mod Loading (#4) | Hard | `difficulty_preset` kind; key schema validation; enabled mod set |
| Save/Load & Migration (#5) | Hard | `base:modifiers` section, migrations |
| Simulation Tick & Pause (#1) | Hard (reverse) | Reads Tier P cadence settings; D7 amended so toggles gate only the hold |
| Input & Controls (#6) | Hard (reverse) | Reads Tier P input settings |
| Vigor (#13), Ship AI (#20), Battle Resolution, Ports & Rest, Loot & Contracts, Rival Investigators, Defeat & Debrief, Dossier | Hard (reverse) | Read their Tier C keys via `ModifierSet`; must honour rule 9 |
| Combat Event Bus & Battle Record (#9) | Soft (reverse) | Header carries the frozen set |
| Combat HUD (#46), Menus/Settings/Save UI (#51), #55, #56 | Soft (reverse) | UI over this store |

Bidirectional check: Simulation Tick & Pause and Content Data & Mod Loading
already list this system; Input & Controls lists it. The systems index lists
#7 under Vigor, Ship AI, HUD, Menus, #55 and #56. Undesigned owners must state
their keys.

## Tuning Knobs

The preset table (rule 13) and the Tier P catalogue (rule 17) are the knobs,
with their ranges. Additional designer knobs:

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `INVESTIGATOR_PACE_FLOOR` | 500 | 250 – 1000 | Pillar 2 risk on easiest settings | Lying becomes free | Chronicler barely differs |
| `DEFEAT_COST_FLOOR` | 1 unit | ≥ 1 | Pillar 1 on easiest settings | (0 is forbidden) | Small defeats feel heavy |
| Permille key bounds | per key | within 250 – 2000 | Width of Custom | Custom pointless | Degenerate campaigns |

All values live in data files (`assets/data/settings/`), never in code.

## Visual/Audio Requirements

None of its own. Screens belong to #51, #55 and #56. The voyage record uses
neutral styling: no warning colours, no "Easy" wording.

## Game Feel

- **Settings respond at once.** Profile changes apply on the next frame.
- **Challenge changes feel deliberate.** They happen at a port or between
  battles, and the screen says when they take effect.
- **Nothing nags.** No post-defeat prompts.

## UI Requirements

Owned by #51 (MVP basics) and #55/#56 (Vertical Slice screens):
- New-campaign setup: preset choice with one-line intents, a Custom panel
  (Challenge keys with ranges), Ironman switch, and the "Apply comfort
  suggestions?" offer.
- In-campaign Settings: *Assists* and *Challenge* groups; Challenge greyed in
  battle with "Applies after this battle"; "preset updated" notice and
  Re-apply.
- Save card and end screen: the voyage record (rule 15).
- 📌 **UX Flag — Gameplay Settings & Modifiers**: run `/ux-design` for the
  new-campaign setup and settings screens in Pre-Production, before epics.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Cadence settings; D7 hold-only toggles | `design/gdd/simulation-tick-and-pause.md` | Rules 9, 11, 12, 14, 16; D7 | Rule dependency (D7 amended here) |
| Presets as content; mod keys | `design/gdd/content-data-and-mod-loading.md` | Kinds, override path, validation | Data dependency |
| `base:modifiers` section | `design/gdd/save-load-and-migration.md` | Core Rules 7, 10, 25 | Data dependency |
| Input thresholds | `design/gdd/input-and-controls.md` | Rules 9, 16–19; D2–D4 | Data dependency |

## Acceptance Criteria

- **AC-01 (Logic; rules 1, 4)**: a static check finds no simulation code that reads the profile store, an autoload or a global for a gameplay value; simulation systems receive a `ModifierSet` by injection.
- **AC-02 (Logic; rules 2, 3)**: **GIVEN** a battle run twice with identical commands, once with every Tier P setting at its minimum and once at its maximum (speed, auto-pause toggles, focus-loss, input thresholds), **THEN** the final `state_hash` and replay are identical.
- **AC-03 (Logic; rule 3, Tick D7)**: with an auto-pause trigger disabled, a crossing still updates `armed` and `last_fire_tick` exactly as when enabled, and adds no hold; enabling it mid-battle gives the same trigger state as a run where it was always enabled.
- **AC-04 (Logic; rules 5, 6)**: every value in `base:modifiers` is an integer; the snapshot holds a resolved value for every registered key; `state_hash` changes when any Tier C value changes and does not when any Tier P value changes.
- **AC-05 (Logic; D1)**: Admiral with override 1100 resolves `vigor_erosion_permille` to 1100; a preset value of 2500 resolves to 2000 with a logged clamp; a preset omitting a key resolves to its default with a validation warning.
- **AC-06 (Logic; D2)**: 12 days at 500, 1000 and 1500 permille give 6, 12 and 18; base 240 at 750 gives 180; no input in range gives a negative result.
- **AC-07 (Logic; D3, rule 11)**: a 1-day defeat on Chronicler costs 1 day; `investigator_pace_permille` below 500 in a preset or override resolves to 500.
- **AC-08 (Logic; rules 7, 8)**: a Challenge change in BATTLE is queued, applies at the first boundary after the battle ends, and writes one `MODIFIER_CHANGE` with the correct tick, key, old and new; a change outside battle applies at the next boundary and logs; no change refunds a cost already paid.
- **AC-09 (Logic; rule 8)**: a Battle Record header contains the frozen set, and replaying it with a campaign whose current modifiers differ reproduces the original result.
- **AC-10 (Logic; rule 12)**: with Ironman on, manual save slots are not offered; switching it off outside battle offers them and logs the change; switching it on mid-campaign is not offered.
- **AC-11 (Logic; rule 13)**: choosing Chronicler fills every Tier C key with its table value; its Tier P suggestions are offered once and change nothing unless accepted.
- **AC-12 (Logic; rule 14)**: a mod key with a schema loads and resolves; a mod trying to change a `base` key's range or composition is refused by content validation; removing the mod drops its keys at load and lists them in the pre-load summary.
- **AC-13 (Logic; Edge Cases)**: a campaign started before a preset's values changed keeps its snapshot after the update; "Re-apply preset" changes the snapshot and logs every changed key.
- **AC-14 (Logic; Edge Cases)**: an old save without a newly added key loads with the key at its schema default via migration.
- **AC-15 (Logic; rule 17)**: every Tier P value takes effect on the next frame without a restart; a missing or corrupt profile file loads defaults and tells the player once.
- **AC-16 (Logic; rule 15)**: the voyage record of a campaign played on Chronicler for days 1–140, then Standard, with Ironman, reads exactly "Charted on Chronicler, days 1–140; Standard from day 141. Ironman." and lists no assists.
- **AC-17 (Logic; rule 9, cross-GDD audit)**: a review checklist confirms each consuming GDD (Vigor, Ship AI, Battle Resolution, Ports & Rest, Loot & Contracts, Rival Investigators, Defeat & Debrief, Dossier) states its key, range and the rule 9 limits before that GDD is approved.
- **AC-19 (Logic; rule 9, Pillar 2)**: suppression purchase and upkeep, as a share of income at the same campaign state, are equal (±1 permille) on Chronicler, Standard and Admiral.
- **AC-20 (Playtest; rule 10a)**: a fresh fleet with no Dossier or Debrief preparation loses its first stronghold attempt on Chronicler and at the Custom minimums, in 5 of 5 attempts.
- **AC-21 (Logic; rule 10)**: for a fixed battle, the set of tactics each enemy ship uses is identical at every `enemy_ai_level`; only execution parameters differ.
- **AC-18 (UI)**: the new-campaign setup, the Assists/Challenge settings, and the voyage record each have a retained screenshot in `production/qa/evidence/` when their #51/#55/#56 story closes; no screen uses the word "Easy" or a warning colour for a preset.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Every † key and range** must be accepted by its owning GDD, together with rules 9, 10 and 10a (Rival Investigators, Loot & Contracts, Stronghold/Battle Resolution, Ship AI first); the preset values are starting points. | each owning GDD; economy-designer for yield and costs | As each is designed; balance pass |
| 2 | **Preset names** (Chronicler / Standard / Admiral) need a naming pass with the world's voice. | narrative-director | Vertical Slice |
| 3 | **Simulation Tick & Pause D7 amendment** (toggles gate only the hold) must be confirmed in Tick's re-review. | Tick owner | Tick re-review |
| 4 | **In-game profiles** (several players on one OS account) are not at MVP. | producer | Post-MVP |
| 5 | **Achievements** (if any) must follow rule 15: difficulty may add marks, never remove them. | release-manager | Before store submission |
| 6 | ~~**`DEFEAT_COST_FLOOR` unit**~~ **Resolved 2026-10-30:** measured per cost: 1 day for the day cost (Debrief `DEFEAT_FLOOR_S`), 1 credit for the bill (Credits rule 7). | After-Action Debrief (#24) | Closed |
