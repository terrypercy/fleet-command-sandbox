# Menus, Settings & Save UI

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 4 (Plan in the Open — every setting says what it changes, and difficulty never touches the explanation); Pillar 1 (Every Defeat Is a Lead — saves never make a defeat the end of the run)

## Summary

Menus, Settings & Save UI is the set of screens around play: the main menu, new-campaign setup, the settings screen, save and load, the mod screen, the pause menu, credits and quit. It draws data owned by other systems (settings store, save headers, binding table, package list) and owns only presentation, flow and the `SYSTEM:menu` hold. Every setting states its effect in one line, no setting reveals or biases the hidden maker, and quitting always keeps the player's place.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Save/Load & Migration, Input & Controls, Gameplay Settings & Modifiers`

## Overview

This system is the frame around the game. It owns screens, not rules. Gameplay
Settings & Modifiers (#7) owns the settings store and its two tiers; Save/Load &
Migration owns slots, the suspend save, migration and refusal reasons; Input &
Controls (#6) owns bindings, conflicts and Esc; Content Data & Mod Loading (#4)
owns packages and the pre-load summary data; Simulation Tick & Pause (#1) owns
holds. This GDD decides what the player sees, in what order, with what words,
and which hold each screen adds. It adds exactly one hold of its own,
`SYSTEM:menu`. At MVP it covers: main menu, new-campaign setup (preset, Custom,
Ironman, comfort suggestions), settings (Tier P live, Tier C per campaign),
accessibility basics, save/load and slots, the suspend save's "Resume battle",
Ironman presentation, migration and missing-mod notices, the mod screen, the
pause menu (including Esc in battle), credits and quit. The full Accessibility
Options UI (#55) and Difficulty Options UI (#56) extend these screens at
Vertical Slice.

## Player Fantasy

The player should feel that the ship's paperwork is honest and out of the way.
Menus are a calm bridge console: every switch is labelled with what it does,
nothing is hidden behind "Advanced", and nothing scolds. Choosing Chronicler
feels like choosing a voyage, not admitting weakness. Quitting mid-battle feels
safe because the game says "Quitting keeps your place" and then keeps it.

*Anchor moment:* a player loses focus mid-battle, the window is closed by a
child, and next evening the main menu's first button reads "Resume battle".
They land paused on the exact tick, with the hold indicator saying so.

**MDA target aesthetics:** Submission (low-friction comfort), Challenge
(chosen, transparent difficulty), Expression (the voyage record). **SDT:**
Autonomy (every comfort and challenge setting is the player's, with no nag),
Competence (settings explain themselves; failures name a cause and an action).

## Detailed Design

### Core Rules

**A. Screens and holds**

1. **This system owns screens only.** Every value it shows or edits belongs to
   another system's store or data. A screen never caches a value past the
   frame it is drawn, and never writes hashed state directly.
2. **One hold of its own.** Any menu opened while a campaign is loaded adds
   `SYSTEM:menu` (Simulation Tick & Pause). Closing the last menu removes it.
   `SYSTEM:save` and `SYSTEM:load` are added by Save/Load, not by this system.
3. **Esc follows Input rule 8.** Esc is *back* on every screen. On the main
   menu root, Esc does nothing. Esc in a text field leaves the field first.
   Esc in a rebind capture cancels the capture.
4. **Esc in battle pauses.** In BATTLE, Esc in Combat-live or Command opens the
   pause menu and adds both `PLAYER_PAUSE` and `SYSTEM:menu`. Closing the menu
   (Esc or *Back to battle*) removes `SYSTEM:menu` only. The battle stays held
   under `PLAYER_PAUSE` until the player resumes with the pause action.
5. **Esc on the campaign map** opens the pause menu with `SYSTEM:menu` only.
   Closing it returns to the speed and pause state the player left.
6. **Every screen works with the keyboard alone.** Focus is always visible.
   Mouse and keyboard reach every control. Menu navigation uses the Menu
   context's bindings (arrows / Enter / Esc by default).
7. **Bad news is specific.** Every refusal or failure shows the owning system's
   named reason and the action the player can take. The words "an error
   occurred" never appear.

**B. Main menu**

8. **Main menu items, top to bottom:** *Resume battle* or *Continue* (rule 9),
   New Campaign, Load, Settings, Mods, Credits, Quit.
9. **The first item.** If the most recently played campaign has a suspend
   save, the first item is *Resume battle*. Otherwise it is *Continue*, which
   loads that campaign's newest valid slot. If no valid save exists, the item
   is absent and New Campaign takes focus.
10. **The active mod list is always visible** on the main menu as one line
    ("Base game only" or "Mods: 2 — Name A, Name B"). Selecting it opens Mods.

**C. New campaign**

11. **One setup screen.** It holds: captain name (text field, default name
    filled in), preset cards, the Custom panel, the Ironman switch, the active
    mod line, and *Begin*.
12. **Preset cards.** Chronicler, Standard and Admiral are shown in that order,
    then Custom, then mod presets after a divider. Each card shows its name
    and its one-line intent from the preset content definition. Standard has
    initial focus. No card is labelled "Easy", "Recommended" or "Hard", and no
    card uses a warning colour (#7 AC-18).
13. **Custom.** Selecting Custom opens a panel listing every registered Tier C
    key, grouped as *Challenge*. Each row shows the key's display name, its
    one-line effect, its current value, and its range. Values start at
    Standard. A value outside the range cannot be entered.
14. **Ironman is a switch, not a preset** (#7 rule 12). It sits beside the
    preset cards with one line: "Only automatic saves. You can turn this off
    later, but never back on." It works with every preset, including Custom.
15. **Comfort suggestions.** On *Begin*, if the chosen preset carries Tier P
    suggestions that differ from the current profile, a modal lists each
    change ("Default speed 1× → 0.5×") with *Apply* and *Not now*. *Not now*
    changes nothing. The offer is made once per preset per profile; the
    profile remembers that it was answered. It is never shown again after a
    defeat (#7 rule 16).
16. **Truth-seeding neutrality.** No control on this screen, or anywhere in
    menus, reveals, previews or biases the seeded truth:
    - no setting, preset, Custom value or the Ironman switch is an input to
      the truth roll (#7 rule 9);
    - there is no seed field at MVP; the campaign seed comes from Save/Load's
      entropy source after *Begin*;
    - no text on any menu varies with the seeded truth, the candidate set or
      the red herring;
    - the captain name is display text only and never feeds any stream;
    - the mod line says which packages are active, never which content can be
      the maker.
17. **Begin creates the campaign.** The modifier snapshot is resolved (#7 D1),
    Ironman is fixed on or off, and the game loads into the campaign under
    `PLAYER_PAUSE`.

**D. Settings**

18. **Groups.** Settings has tabs: *Gameplay*, *Controls*, *Display &
    Accessibility*, *Audio*, and, only while a campaign is loaded,
    *Challenge*. Mods are not in Settings (rule 31).
19. **Every setting shows one line of effect** under its name (table in UI
    Requirements). The line says what changes in play, never a judgement.
20. **Tier P applies live.** A Tier P change takes effect on the next frame,
    everywhere, with no Apply button and no restart (#7 rule 17). Each tab
    has *Reset tab to defaults* (asks first).
21. **Tier C belongs to the campaign.** The *Challenge* tab edits the loaded
    campaign's snapshot only. It is never shown from the main menu. Outside
    BATTLE, a change asks "Change [name] from X to Y? This is logged in the
    voyage record." and applies at the next boundary (#7 rules 7, 8).
22. **Tier C in battle.** In BATTLE the Challenge tab is visible but greyed,
    with "Applies after this battle". A change made there is queued and shown
    as queued (#7 rule 7).
23. **What can change mid-campaign.** Outside battle: any Challenge key within
    its range, *Re-apply preset* (shows every key that will change, then
    asks), and *Turn off Ironman* (rule 29). Never: turning Ironman on, the
    campaign seed, or the active mod set.
24. **Controls tab** is drawn from Input's table: per-context tabs, primary and
    secondary slots, capture prompt, inline conflict with Swap / Replace /
    Cancel, resets per action, per context and all (confirmed), and the three
    binding presets (Input UI Requirements). Input owns all logic.
25. **Auto-pause and tactical settings** sit in *Gameplay*, grouped as
    *Tactical*: each auto-pause toggle (including Battle start), the
    focus-loss pause, and Tactical step (Tick UI Requirement 7). Never grouped
    with debug or assist settings.

**E. Accessibility (MVP basics)**

26. **The MVP accessibility settings**, all Tier P and live:
    - **Text scale** (`ui_scale`, 750–2,000 ‰, step 125): scales all menu and
      HUD text (D1; HUD rule 31).
    - **Palette**: Default (colour-vision-deficiency safe) or High contrast
      (HUD rule 32). Meaning never changes with palette.
    - **Reduce motion**: on removes camera shake, camera glides that are not
      needed to follow the flagship, menu transitions and scrolling credits.
    - **Camera shake** (`CAMERA_SHAKE_PM`, 0–1,000 ‰, step 100, default 500):
      greyed and shown as 0 while Reduce motion is on (Camera rule 20).
    - **Held-tier layer defaults**: order lines, link lines, rings, ghost paths
      (each shown/hidden, default shown). In-battle toggles start from these
      (HUD rule 14).
    - **Telegraph early warning** (`telegraph_early_warning_ticks`).
    - **First-use prompts**: restore (Input UI Requirements).
27. **No standard yet.** `design/accessibility-requirements.md` does not exist.
    These settings are the MVP floor; they must be re-checked against that
    document when it is written (Open Question 1).

**F. Save, load and slots**

28. **Save and load screens** list slots from headers only (Save/Load UI
    Requirements): captain name, in-game day, location, played time (D3),
    saved time, slot kind, and the voyage record (#7 rule 15). Order: suspend
    first ("Resume battle"), then by `save_counter` descending. A damaged slot
    is listed as damaged with its reason; Load is disabled for it and Delete
    is offered.
29. **Manual saving.** Outside battle in a non-Ironman campaign, the pause
    menu offers *Save*, which opens the slot list with *New save* first and up
    to `MANUAL_SLOTS` (20) slots. With all 20 full, the player chooses one to
    overwrite or deletes one; no manual save is deleted without the player.
    An optional slot label is plain text, length-capped.
30. **Saving in battle** is greyed with "Saving is only possible outside
    battle. Quitting keeps your place." (Save/Load UI Requirements).
31. **Load from battle** is greyed with "Quit to the main menu to load another
    save. Quitting keeps your place." This keeps one suspend per campaign and
    one path out of a battle.
32. **Loading a campaign** opens a campaign list (captain name, voyage record,
    newest save time), then that campaign's slots. *Delete campaign* asks
    first and names the slot count.
33. **Import** opens a file picker; the copy, validation and refusals are
    Save/Load's (Core Rule 27). The game never shows a real OS path except
    inside the picker the OS draws.
34. **The save indicator** is a small icon shown while a save is WRITING or
    VERIFYING, for at least `SAVE_INDICATOR_MIN_MS`. It is never a modal, plays
    no sound for autosave or suspend, and never overlaps the HUD's critical
    readouts.

**G. Suspend save and quitting a battle**

35. **Quitting a battle** (Quit to main menu, Quit to desktop, or closing the
    window) needs no confirm beyond "Quit? Your place is kept." The suspend is
    written (Save/Load rule 22); the hold indicator shows "Saving…" until it
    completes; then the game leaves.
36. **Resume battle** loads the suspend and lands under `PLAYER_PAUSE` on the
    last whole tick. The menu shows nothing else about the suspend (no
    countdown, no age) at MVP.

**H. Ironman**

37. **Ironman campaigns show no manual Save** item at all, rather than a greyed
    one (#7 AC-10). The pause menu offers *Save and quit*, which writes an
    autosave (or the suspend in battle) and returns to the main menu.
38. **Ironman load.** The campaign's slot list shows one entry: the suspend if
    it exists, else the newest valid save. Older autosaves and the battle-start
    slot are shown only if that entry is damaged, with the damage reason.
    *(Proposed; Open Question 3.)*
39. **Turning off Ironman** is in the *Challenge* tab, outside battle only. It
    asks "Turn off Ironman for this campaign? This cannot be undone and is
    shown in the voyage record." On confirm, manual Save appears and the
    change is logged (#7 rule 12).

**I. Migration and missing mods**

40. **One confirm summary.** When Save/Load reports content changes, declared
    migration losses or carried-section losses, the load stops on one summary
    screen listing them together, by package, with *Load* and *Cancel*
    (Save/Load UI Requirements; Content Data UI Requirement 2). Cancel changes
    nothing.
41. **Information lines never block.** Build, OS and architecture differences,
    and a format migration with no losses, appear as a separate dim line on
    the summary, or, if nothing else needs confirming, as a notice for
    `NOTICE_MS` after the load with no confirm.
42. **Missing mods.** Sections of a missing package are listed as "Kept for
    when [mod] returns" (carried untouched, Save/Load rule 17). Items kept
    inert, substituted or removed are named with old and new values (Content
    Data UI Requirement 2). "Affects your case" is a separate flag line.

**J. Mods**

43. **The mod screen** is reached from the main menu only, with no campaign
    loaded (Content Data Core Rule 15). It lists every package found: name (or
    namespace), version, enabled switch, status (loaded, or refused with each
    error in plain words plus its stable code).
44. **Risk notice.** The first time any mod is enabled, a one-time notice says
    that mods are community content, loaded at the player's own risk.
45. **Applying changes** reloads content and returns to the mod screen with the
    new statuses. Load order and dependency rules are Content Data's.

**K. Pause menu, credits and quit**

46. **Pause menu items.** Campaign map: Resume, Save (not in Ironman), Load,
    Settings, Controls reference, Quit to main menu, Quit to desktop.
    Battle: Back to battle, Save (greyed, rule 30), Load (greyed, rule 31),
    Settings, Controls reference, Quit to main menu, Quit to desktop.
47. **Quitting the campaign map** writes a campaign save (an autosave in
    Ironman), then leaves. One confirm: "Quit? Your place is kept."
48. **Quit from the main menu** asks once, then exits. No save is needed.
49. **Credits** are a scrolling list; with Reduce motion on they are a paged
    list. Esc or any confirm returns to the main menu.

### States and Transitions

| State | Entered when | Holds added | Leaves to |
|---|---|---|---|
| Boot | game start | — | Main menu (after content load) |
| Main menu | boot; quit to menu completes | — (no campaign) | New-campaign setup, Load, Settings, Mods, Credits, Loading, Exit |
| New-campaign setup | New Campaign | — | Comfort modal (if any); Loading; Main menu (Esc) |
| Comfort modal | Begin with differing suggestions | — | Loading (Apply / Not now) |
| Load / campaign list | Load | — | Confirm summary; Loading; back |
| Confirm summary | Save/Load reports changes or losses | `SYSTEM:load` (Save/Load) if mid-campaign | Loading (Load); previous screen (Cancel) |
| Loading | a load is armed | `SYSTEM:load` (Save/Load) | In campaign or In battle, under `PLAYER_PAUSE` |
| Mods | Mods (no campaign) | — | Main menu |
| Settings (main menu) | Settings | — | Main menu |
| In campaign | load or Begin | — | Pause menu (campaign) |
| Pause menu (campaign) | Esc on map | `SYSTEM:menu` | In campaign (back); Settings; Save; Load; Quitting |
| In battle | battle starts | (Tick's own) | Pause menu (battle) |
| Pause menu (battle) | Esc in Combat-live / Command | `PLAYER_PAUSE` + `SYSTEM:menu` | In battle, still `PLAYER_PAUSE` (back); Settings; Quitting |
| Quitting | any quit or window close | `SYSTEM:save` (Save/Load) | Main menu or Exit after the write |

### Interactions with Other Systems

| System | Direction | What flows |
|---|---|---|
| Simulation Tick & Pause (#1) | #51 → #1 | Adds/removes `SYSTEM:menu`; Esc in battle adds `PLAYER_PAUSE` via Input. #1 → #51: hold set and reasons for the hold indicator and disabled-control reasons |
| Content Data & Mod Loading (#4) | both | #4 → #51: package list, statuses, errors, pre-load summary data, preset definitions. #51 → #4: enable/disable choices, Apply |
| Input & Controls (#6) | both | #6 → #51: binding table, conflicts, presets, Menu context. #51 → #6: capture requests, Swap/Replace/Cancel, resets |
| Gameplay Settings & Modifiers (#7) | both | #7 → #51: Tier P catalogue, Tier C keys with ranges and effect lines, presets, voyage record. #51 → #7: Tier P writes, Tier C change requests, preset choice, Ironman state, comfort-suggestion answer |
| Save/Load & Migration | both | Save/Load → #51: headers, slot kinds, suspend presence, damage reasons, confirm-summary items, refusal and failure messages, indicator state. #51 → Save/Load: save, load, delete, import requests |
| Camera & Combat View (#45) | #7 → #45 (via settings) | `CAMERA_SHAKE_PM`, Reduce motion |
| Combat HUD & Tactical Overlay (#46) | both | #7 → #46: `ui_scale`, palette, Reduce motion, held-tier defaults. #46 ↔ #51: save-indicator placement clear of critical readouts |
| Accessibility Options UI (#55), Difficulty Options UI (#56) | #51 → #55/#56 | MVP screens they extend at Vertical Slice |

## Formulas

### D1. Menu text size

`text_px = max(MENU_TEXT_MIN_PX, base_px × ui_scale div 1000)`

| Variable | Type | Range | Source | Meaning |
|---|---|---|---|---|
| base_px | int | 12 – 32 | theme data | Designed size of a text style at 1000 ‰ |
| ui_scale | int (‰) | 750 – 2,000 | #7 Tier P | Text scale setting |
| MENU_TEXT_MIN_PX | int | 10 – 14; **12** | tuning | Floor so no menu text is unreadable |
| text_px | int | 12 – 64 | output | Rendered size |

**Example:** body text 14 px at 1,250 ‰: 14 × 1,250 = 17,500; div 1,000 = 17 px.
At 750 ‰: 14 × 750 = 10,500 → 10, raised to the floor, 12 px. Largest case:
32 × 2,000 div 1,000 = 64 px. Menus must use the same scaling as HUD D5; if
the two differ, HUD D5 wins and this formula is amended (Open Question 5).

### D2. Manual slots offered

`manual_offered = 0 if ironman else MANUAL_SLOTS`

**Example:** a normal campaign offers 20 manual slots; an Ironman campaign
offers 0; after Ironman is turned off, the same campaign offers 20.

### D3. Played-time display

`hours = played_s div 3600; minutes = (played_s mod 3600) div 60`

Shown as "12 h 34 min"; under one hour, "34 min"; under one minute, "< 1 min".
**Example:** 45,296 s: 45,296 div 3,600 = 12 (43,200); remainder 2,096;
2,096 div 60 = 34 (2,040). Shown "12 h 34 min". `played_s` comes from the
header; this is display only and never rounds up.

## Edge Cases

- **If Esc is pressed while a save is writing from the pause menu**: Esc closes
  the menu; `SYSTEM:save` keeps the game held and the hold indicator says
  "Saving…" until the write ends.
- **If focus is lost with the pause menu open**: Tick adds `SYSTEM:focus_lost`
  (if enabled); in battle it also adds `PLAYER_PAUSE`. Regaining focus removes
  only `SYSTEM:focus_lost`; the menu stays open.
- **If the player rebinds every action**: Esc still opens the pause menu and
  navigates menus (Input rule 8).
- **If the newest campaign's suspend is damaged**: the first item is
  *Continue*; the Load screen lists the suspend as damaged with its reason.
- **If no save is valid at all**: *Continue* is absent; Load lists damaged
  slots so the player can see and delete them.
- **If a preset is removed by a mod change**: a campaign started on it keeps
  its snapshot; the Challenge tab shows the preset name with "(no longer
  installed)"; *Re-apply preset* is disabled with that reason.
- **If a mod preset's intent line is missing or too long**: show the preset
  name alone; text is length-capped and escaped (Content Data Core Rule 14).
- **If the captain name is empty on Begin**: the default name is used.
- **If the captain name contains markup or control characters**: shown as
  plain text with them stripped (Save/Load Core Rule 28).
- **If the player changes a Challenge key in battle, then changes it back**:
  the queue holds the latest value; if it equals the current value, nothing is
  applied or logged.
- **If the window closes during the comfort modal or setup**: no campaign
  exists yet; nothing is saved; the game exits.
- **If the window closes while the confirm summary is shown**: nothing has
  loaded; the current campaign (if any) is saved as for any quit.
- **If all 20 manual slots are full and the player cancels the overwrite
  choice**: nothing is saved and the menu says so.
- **If the profile settings file is missing or corrupt**: defaults load and
  the main menu shows the once-only notice from #7 AC-15.
- **If Text scale makes a screen overflow**: the screen scrolls; no control is
  clipped or hidden (UI AC).
- **Degenerate use — save-scumming in a normal campaign**: allowed; manual
  saves are the player's (Pillar 1 forbids only a run-ending defeat). Ironman
  exists for players who want the restriction.
- **Degenerate use — quitting a losing battle to reload the battle-start
  slot**: allowed outside Ironman; defeat is already never the end of the run,
  and the Debrief is the intended answer. In Ironman, rule 38 hides that slot.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | Hold set and reasons; `SYSTEM:menu` add/remove |
| Content Data & Mod Loading (#4) | Hard | Package list, errors, pre-load summary data, presets, plain-text escaping |
| Input & Controls (#6) | Hard | Binding table, conflict logic, capture, Menu context, Esc rules |
| Gameplay Settings & Modifiers (#7) | Hard | Tier P catalogue, Tier C keys, presets, voyage record, Ironman |
| Save/Load & Migration | Hard | Headers, slot operations, suspend, confirm-summary items, reasons |
| Camera & Combat View (#45) | Soft | Consumes shake and Reduce motion settings |
| Combat HUD & Tactical Overlay (#46) | Soft | Consumes text scale, palette, Reduce motion, held-tier defaults; indicator placement |
| Accessibility Options UI (#55), Difficulty Options UI (#56) | Soft (reverse) | Extend these screens |

All five Hard dependencies already list #51 in their own Dependencies tables.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects | Too low | Too high |
|---|---|---|---|---|---|---|
| `MENU_TEXT_MIN_PX` | 12 | 10 – 14 | Feel | D1 floor | Unreadable at 750 ‰ | Text scale's low end does nothing |
| `MENU_TRANSITION_MS` | 150 | 0 – 300 | Feel | Screen fade (0 with Reduce motion) | Abrupt | Menus feel slow |
| `SAVE_INDICATOR_MIN_MS` | 500 | 250 – 1,500 | Feel | Indicator visibility | Flicker unnoticed | Lingers after the save |
| `NOTICE_MS` | 4,000 | 2,000 – 8,000 | Feel | Non-blocking load notice | Missed | Clutter |
| `TEXT_SCALE_STEP` | 125 ‰ | 50 – 250 | Feel | Text scale slider step | Fiddly | Too coarse |
| `SHAKE_STEP` | 100 ‰ | 50 – 250 | Feel | Shake slider step | Fiddly | Too coarse |
| `CAPTAIN_NAME_MAX` | 24 chars | 12 – 40 | Gate | Name field cap | Names cut | Card layout breaks |
| `QUIT_CONFIRM` | on | on / off | Gate | One quit confirm | Accidental quits | — |

All live in `assets/data/ui/menus/`. Preset intents, setting effect lines and
names are content strings owned by their systems, not knobs here.

## Visual/Audio Requirements

- **Calm, uniform presentation.** Preset cards are visually equal: same size,
  same colour family, no warning colours, no skull or difficulty icons.
- **Failure** uses the standard warning style with icon plus text, never colour
  or sound alone (Save/Load Visual/Audio).
- **Save indicator** in a screen corner clear of HUD critical readouts; exact
  corner set with #46 (Open Question 6).
- **Audio**: standard UI confirm/back sounds; a manual save may use confirm; no
  sound for autosave or suspend refresh.
- **Palettes** apply to menus as well as the HUD.

## Game Feel

- **Instant response.** A menu input is acknowledged on the next frame.
- **Never trapped.** Esc always backs out; every modal has a cancel.
- **Landing paused.** Every load, Begin and Resume battle lands under
  `PLAYER_PAUSE`, so the player gets their bearings.
- **No nag.** No prompt ever suggests lowering difficulty or reconsidering
  Ironman after a defeat.

## UI Requirements

**Setting effect lines (MVP).** Each setting's one line, shown under its name:

| Setting | Tier | Group | One-line effect |
|---|---|---|---|
| Speed steps / Default speed | P | Gameplay | "Which speeds the speed control offers, and where a battle starts." |
| Auto-pause: each trigger | P | Gameplay › Tactical | "Pause when [trigger] happens. The trigger is still tracked when off." |
| Tactical step | P | Gameplay › Tactical | "While paused, step 1 or 10 ticks at a time." |
| Pause on focus loss | P | Gameplay › Tactical | "Pause when the game window loses focus." |
| Aim assist | P | Gameplay | "Nudges the aim cursor toward targets. Off by default." |
| Bindings, presets, hold/toggle, thresholds | P | Controls | per Input's table |
| Text scale | P | Display & Accessibility | "Size of all menu and HUD text." |
| Palette | P | Display & Accessibility | "Colours of ships, markers and readouts. Meaning never changes." |
| Reduce motion | P | Display & Accessibility | "Removes shake, non-essential camera glides and menu animation." |
| Camera shake | P | Display & Accessibility | "Strength of the shake on hits and losses. 0 is none." |
| Held-tier layer defaults | P | Display & Accessibility | "Which planning layers show when you pause a battle." |
| Telegraph early warning | P | Display & Accessibility | "Shows enemy attack warnings earlier. Attacks are not slower." |
| Edge scroll | P | Display & Accessibility | "Pan the paused battle by moving the cursor to the screen edge." |
| Master / Music / Effects volume | P | Audio | "Loudness of [channel]." (key proposed, Open Question 7) |
| Each Challenge key | C | Challenge | from the key's schema (for example `defeat_cost_permille`: "How many days a defeat costs.") |
| Turn off Ironman | C | Challenge | "Allow manual saves for this campaign. Cannot be undone." |

**Screens to build (each needs a UX spec):** main menu; new-campaign setup with
Custom panel and comfort modal; Settings (five tabs); controls screen and
controls reference; save/load slot list and campaign list; confirm summary;
mod screen and risk notice; pause menu (two variants); credits; quit confirm.

📌 **UX Flag — Menus, Settings & Save UI**: run `/ux-design` for each screen
above in Pre-Production, before epics. Stories cite `design/ux/[screen].md`.
Run `/ux-design accessibility` to create `design/accessibility-requirements.md`.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Holds, focus loss, settings entries | `design/gdd/simulation-tick-and-pause.md` | Rule 16; UI Requirements 1–7 | Rule dependency |
| Tiers, presets, Ironman, voyage record, rule 9 | `design/gdd/gameplay-settings-and-modifiers.md` | Rules 7–9, 12, 13, 15–18; UI Requirements | Rule dependency |
| Slots, suspend, import, confirm summary | `design/gdd/save-load-and-migration.md` | Core Rules 2, 17, 22–24, 27, 28; UI Requirements | Data dependency |
| Esc, contexts, rebinding | `design/gdd/input-and-controls.md` | Rules 7, 8, 10; UI Requirements | Rule dependency |
| Shake, Reduce motion | `design/gdd/camera-and-combat-view.md` | Rule 20 | Data dependency |
| Text scale, palettes, held-tier toggles | `design/gdd/combat-hud-and-tactical-overlay.md` | Rules 14, 31, 32 | Data dependency |
| Mod screen, pre-load summary | `design/gdd/content-data-and-mod-loading.md` | Core Rules 13–15; UI Requirements 1–2; OQ 3 | Ownership (resolves OQ 3: #51 owns both) |

## Acceptance Criteria

**Logic — `tests/unit/menus/` (BLOCKING).** Screen controllers run against
injected fakes of the settings store, save service, binding table, package
list and hold set.

- **AC-01 (Logic; rule 2)**: opening any menu with a campaign loaded adds exactly one `SYSTEM:menu`; closing the last menu removes it; this system never adds `SYSTEM:save` or `SYSTEM:load`.
- **AC-02 (Logic; rule 4)**: **GIVEN** BATTLE in Combat-live, **WHEN** Esc is pressed and then the menu is closed, **THEN** `PLAYER_PAUSE` and `SYSTEM:menu` are added, only `SYSTEM:menu` is removed, and the battle is still held.
- **AC-03 (Logic; rule 5)**: on the campaign map running at 2×, opening and closing the pause menu returns to running at 2× with no `PLAYER_PAUSE` added.
- **AC-04 (Logic; rule 9)**: with a suspend present the first main-menu item is "Resume battle"; without one it is "Continue" pointing at the newest valid slot; with no valid save it is absent and New Campaign has focus.
- **AC-05 (Logic; rule 15)**: choosing Chronicler with a profile that differs from its suggestions shows the modal once; *Not now* leaves every Tier P value unchanged; a second Chronicler campaign on the same profile shows no modal.
- **AC-06 (Logic; rule 16)**: **GIVEN** a fixed entropy value, **WHEN** campaigns are created with every preset, Custom at minimums and maximums, Ironman on and off, and two captain names, **THEN** the seeded truth, candidate set and red herring are identical in all of them.
- **AC-07 (Logic; rule 16)**: a string audit finds no menu text that reads the seeded truth, candidate set or red herring.
- **AC-08 (Logic; rules 21, 22)**: a Challenge change outside battle sends one change request after confirm; in BATTLE it is queued, shown as queued, and a change back to the current value sends nothing.
- **AC-09 (Logic; rule 23)**: mid-campaign, "Ironman on", the seed and the mod set are not editable from any screen.
- **AC-10 (Logic; D2, rules 37, 39)**: an Ironman campaign offers 0 manual slots and no Save item; after *Turn off Ironman* outside battle it offers 20 and a Save item; the option is absent in battle.
- **AC-11 (Logic; rule 38)**: an Ironman load list shows one entry (suspend, else newest valid); with that entry damaged, it also lists the older slots with the damage reason.
- **AC-12 (Logic; rules 30, 31)**: in BATTLE, Save and Load are disabled and each shows its exact message.
- **AC-13 (Logic; rule 28)**: the slot list is built without parsing any section; order is suspend first, then `save_counter` descending; a damaged slot is listed with Load disabled.
- **AC-14 (Logic; rule 29)**: with 20 manual slots full, saving requires choosing a slot to overwrite or delete; cancelling saves nothing.
- **AC-15 (Logic; rule 41)**: a load whose only differences are information lines and a lossless migration shows no confirm; a load with any loss shows one combined summary; Cancel changes nothing.
- **AC-16 (Logic; rule 43)**: the mod screen is unreachable with a campaign loaded; the risk notice appears on the first enable only.
- **AC-17 (Logic; D1)**: 14 px at 750, 1,000, 1,250 and 2,000 ‰ gives 12, 14, 17 and 28 px.
- **AC-18 (Logic; D3)**: 45,296 s shows "12 h 34 min"; 2,100 s shows "35 min"; 59 s shows "< 1 min".
- **AC-19 (Logic; rule 26)**: with Reduce motion on, the shake control shows 0 and is disabled, and the camera receives shake 0; turning it off restores the previous shake value.
- **AC-20 (Logic; rule 20)**: every Tier P change from Settings is visible to its consumer on the next frame with no restart.

**Integration — `tests/integration/menus/`.**

- **AC-21 (Integration; rules 35, 36)**: closing the window mid-battle writes the suspend before exit; relaunching shows "Resume battle", which lands on the same `tick_index` under `PLAYER_PAUSE`.

**UI — retained screenshots in `production/qa/evidence/` (BLOCKING).**

- **AC-22 (UI; rules 8, 10)**: main menu with "Resume battle" and the active mod line; and without saves.
- **AC-23 (UI; rules 11–14)**: new-campaign setup with Custom open and Ironman on; no "Easy", "Recommended" or warning colour.
- **AC-24 (UI; rule 15)**: the comfort modal listing each change.
- **AC-25 (UI; rules 18–25)**: each Settings tab, each setting with its effect line; Challenge greyed in battle with "Applies after this battle".
- **AC-26 (UI; rule 26)**: Display & Accessibility at 750 and 2,000 ‰ text scale, each palette; no clipped control.
- **AC-27 (UI; rules 28–31)**: slot list with a damaged slot and "Resume battle"; pause menu (battle) with Save and Load greyed and their messages.
- **AC-28 (UI; rules 40–42)**: confirm summary with a missing mod, a migration loss and an information line.
- **AC-29 (UI; rules 43, 44)**: mod screen with a refused package and its errors; the risk notice.
- **AC-30 (UI; rule 6)**: each AC-22–29 screen operated end to end with the keyboard alone (recorded steps plus screenshot of the focus state).

**Playtest.**

- **AC-31 (Playtest; Player Fantasy)**: 5 of 5 first-time testers, asked "which preset is the easy one?", describe presets by their intent lines rather than ranking them; none reports feeling judged by the setup screen.
- **AC-32 (Playtest; rule 19)**: 5 of 5 testers, shown three random settings, correctly state what each changes from its effect line alone.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **Ironman is a switch, and Tier C settings can change outside battle**, each
  change logged (Gameplay Settings is authoritative).
- **Ironman load list**: one entry; older autosaves and the battle-start save
  appear only if that entry is damaged.
- **The pause menu's button is "Back to battle"** and leaves the battle held
  under `PLAYER_PAUSE`; the player resumes with the pause action (rule 4). A
  menu never unpauses a battle on the player's behalf.
- **#51 owns audio volumes, window mode and display settings** at MVP, as Tier
  P keys added to Gameplay Settings' catalogue.
- **Held-tier toggles changed in battle reset to their defaults each battle.**

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | `design/accessibility-requirements.md` does not exist. Which tier (basic / standard / comprehensive) does the project commit to, and does rule 26 meet it? | owner + ux-designer | Before UX specs |
| 5 | Align D1 with HUD D5 (floor and rounding). | ux-designer | UX spec |
| 6 | Save-indicator corner, clear of HUD critical readouts. | ux-designer + #46 | HUD UX spec |
| 9 | Is a campaign seed field ever wanted (post-MVP)? If so it must not let players preview the maker. | owner | Post-MVP |
