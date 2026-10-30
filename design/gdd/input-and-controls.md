# Input & Controls

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS on Esc double-booking (pause path), P4 framing, and the ship-relative facing contract; all three revised
> **Implements Pillar**: Pillar 3 (Hands on the Helm — the flagship is flown directly, the fleet is commanded, and pause is always one key away); Pillar 4 (Plan in the Open — the controls are never wiki knowledge: every prompt and the controls reference show the live bindings)

## Summary

Input & Controls turns keys, mouse buttons and the cursor into named actions,
and those into the flagship's live command and the player's requests (orders,
pause, camera, screens). Every action can be rebound from day one, with
hold-or-toggle and a keyboard-only path for everything, so the flagship answers
at once and the fleet answers to gestures (Pillar 3). Mouse and keyboard first;
no gamepad at MVP, but the action layer is device-neutral.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Simulation Tick & Pause` (hard); contracts with Gameplay Settings & Modifiers, Flagship Piloting, Fleet Orders, Camera & Combat View, Menus/Settings/Save UI

## Overview

Input & Controls turns the player's keys, mouse buttons and cursor into **named
actions**, and turns actions into the only two things the game ever accepts from
a player: the flagship's **live command** (move, aim, fire, abilities) and
**requests** (fleet orders, queue edits, pause, resume, step, speed, camera, and
screen navigation). It owns the binding table, the input contexts and their
priority, remapping, hold-or-toggle behaviour, and the gestures for selecting
ships and giving orders.

It deliberately owns very little else. The fixed boundaries are:
- **Simulation Tick & Pause** decides *when* input is read. It snapshots the
  input sample once per rendered frame in `begin_frame()`, latches presses
  between ticks, and records the command (its rules 6 and 7).
- **Flagship Piloting (#15)** decides what the command's move, aim, fire and
  ability bits *do*. **Fleet Orders (#19)** decides what an order means.
- **The simulation core never reads input.** It sees only the command struct
  and requests, which a replay or a test can supply directly. Bindings never
  enter a save, a replay or `state_hash`.

Mouse and keyboard are first (concept: PC, MKB first). There is **no gamepad
at MVP**, but every binding is device-neutral, so a gamepad or Steam Deck layout
(post-launch) is a new device table, not a rewrite.

The player feels three guarantees:
- **The flagship answers at once** (Tick's ≤ 83 ms end-to-end target).
- **Every action can be bound to any key or button**, from the first build, with
  hold-or-toggle for every held action and a keyboard-only path for everything.
- **Pause is always one key away**, in every context except text entry.

## Player Fantasy

**A captain's hands, never a puppeteer's.** The player flies one ship directly
and commands every other with a few deliberate gestures. The flagship answers
the instant they touch it; the fleet answers to orders, not to strings. After an
hour, the bindings disappear into their hands.

*Anchor moment:* mid-fight, the player is dodging a lance volley with the
flagship. They tap a key and the escorts break to screen the carrier, without
the flagship ever leaving their hands. Then they hit pause, and with the board
frozen they drag a box around the frigates and queue a flanking run.

**Pillars served:**
- **Pillar 3, *Hands on the Helm*:** the flagship is never abstracted (its
  command is live, not queued); the fleet is commanded, not puppeted (orders are
  gestures to ships, never direct piloting of them); pause is always available.
- **Pillar 4, *Plan in the Open*:** the controls are never wiki knowledge. Every
  prompt, the context strip and the searchable controls reference show the live
  bindings (rule 21, UI Requirements).
- **Accessibility commitment** (not a pillar): every action, order and planning
  screen is reachable from the keyboard and while paused, so planning is never a
  dexterity test (rules 6–9, 17).

**Feel target:** *the wheel answers.* Piloting must feel immediate.

**Tone:** a calm bridge. Controls are quiet and predictable; nothing surprises
the hands.

**This system must never make the player feel:**
- **"I gave an order and the flagship lurched"** (mode errors between helm and
  command).
- **"I can't play this with my hands"** (an action that can't be rebound, needs
  a chord, needs mashing, or needs a mouse with no alternative).
- **"The game ate my input"** (a lost press, a stuck key after alt-tab).

*Framing chosen from `game-designer`'s three ("A captain's hands" over "The
wheel answers" and "Yours to arrange"); "The wheel answers" became the feel
target and "Yours to arrange" became Core Rules 6–9.*

## Detailed Design

### Core Rules

**A. Actions and bindings**

1. **Everything is an action.** Gameplay code never asks about a physical key.
   It asks about a named action (a `StringName` such as `&"flight_fire_primary"`).
   Each action has:
   - a **context** (rule 10);
   - a **kind**: *press* (fires once on press), *hold* (level-triggered while
     down) or *axis* (a pair or quad of holds combined into a vector);
   - a **primary** and a **secondary** binding slot. A binding is one key, one
     mouse button (left, right, middle, side buttons, wheel up/down), or a
     modifier (Shift, Ctrl, Alt) plus a key or button.
2. **Keys bind by physical position.** Default bindings use the key's physical
   location, so WASD sits in the same place on QWERTY, AZERTY and QWERTZ. Every
   prompt and the binding screen show the key's label on the player's current
   layout. *Engine support for physical vs logical keycodes is NOT SOURCEABLE
   (input ADR).*
3. **Default bindings (MKB)**, all data in `assets/data/input/default_bindings`
   and all rebindable except rule 8:

   | Context | Action | Kind | Default |
   |---|---|---|---|
   | Flight | move (thrust/strafe) | axis | W A S D |
   | Flight | turn left / right (optional) | hold | Q / E |
   | Flight | aim | cursor | mouse position |
   | Flight | fire primary / secondary | hold | LMB / RMB |
   | Flight | ability 1–4 | press | 1 – 4 |
   | Flight | target next / previous | press | T / Shift+T (secondary: G) |
   | Flight | aim at locked target (toggle) | press | V |
   | Fleet (live) | order hotkeys 1–5 (to selection, at cursor or target) | press | F1 – F5 (names owned by #19) |
   | Fleet (live) | command cursor (rule 15) | hold | Left Ctrl |
   | Fleet | control group recall 5–9 / assign | press | 5 – 9 / Ctrl+5 – 9 |
   | Fleet | select all | press | Ctrl+A (secondary: Home) |
   | Fleet | cycle selection next / previous | press | Tab / Shift+Tab |
   | Fleet | open order menu | press | R |
   | Fleet | cancel queued orders of selection / deselect | press | X / Shift+X (also: click empty space in Command) |
   | Command (held, or command cursor) | select / box-select | press / drag | LMB |
   | Command | add/remove from selection | press | Shift+LMB |
   | Command | issue order (context-sensitive) | press | RMB |
   | Command | append to queue | press | Shift+RMB (secondary: hold Z then RMB) |
   | Camera | pan | axis / drag | arrow keys; middle-mouse drag |
   | Camera | zoom in / out | press | wheel up / down; = / − on numpad |
   | Camera | recentre on flagship | press | C |
   | Camera | edge scroll | — | **off** by default (rule 18) |
   | Time | pause / resume | press | Space |
   | Time | step one tick | press | . (period) |
   | Time | speed down / up | press | , / / (comma, slash) |
   | Planning | open Dossier / Ledger / Case File | press | J / L / K |
   | Planning | next / previous tab | press | ] / [ |
   | Menu | navigate / confirm / back | press | arrows / Enter / Esc |
   | Global | system menu | press | Esc |
   | Global | screenshot | press | F12 |
   | Global | fullscreen | press | Alt+Enter (secondary: F11) |

   Abilities on 1–4 and control groups on 5–9 never share a key. Every
   default that uses a modifier has a single-input secondary binding or an
   alternative path (rule 9).
4. **The binding table is player data, not game state.** It is stored in
   `user://input_bindings` with a `schema_version` and its own migrations,
   separate from every save (Save/Load & Migration is for simulation state).
   A missing, unreadable or invalid file loads the shipped defaults and tells
   the player once. A binding file never enters a save, a replay or
   `state_hash`.
5. **Device-neutral actions; no gamepad at MVP.** Bindings name a device class
   and an input, never a device index. Gamepad and Steam Deck layouts are
   post-launch: adding them adds a device table and prompts, and changes no
   gameplay code.

**B. Remapping**

6. **Every action can be rebound, from day one.** Rebinding is: choose an
   action and a slot, "Press a key or button… (Esc cancels)", capture, done.
   Modifier+input bindings and mouse buttons are capturable.
7. **Conflicts are never silent.** Two bindings conflict only if they are the
   same input in the same context or in contexts that can be active together
   (rule 10). A conflict offers **Swap**, **Replace** (unbinds the other) or
   **Cancel**. Sharing an input across contexts that are never active together
   (Menu confirm and Flight fire) is legal and shown in both views. Reset
   exists per action, per context and for everything; reset-all asks first.
8. **Two things are never rebindable**, so the player can never lock themselves
   out: **Esc** always works as *back* and opens the system menu (which offers
   Resume, Settings and Controls), and **Esc** always cancels a capture. Every
   other action, pause included, can be rebound (Simulation Tick & Pause, UI
   Requirements). Removing the last binding of *pause*, *system menu* or
   *confirm* warns first. **In BATTLE, Esc in Combat-live or Command always
   opens the system menu, which adds `PLAYER_PAUSE`** (Simulation Tick & Pause
   rule 16); no gameplay action in those contexts is bound to Esc. So whatever
   the player rebinds, Esc pauses a live battle.
9. **No action requires a chord, a double-tap, rapid tapping or a held input.**
   - Every held action (fire, thrust, turn, camera drag, box-select, command
     cursor) has a per-action **hold or toggle** setting, plus a global default
     (#7).
   - Every modifier binding has a single-input alternative, and **sticky
     modifiers** (#7) latch a modifier on tap until the next action.
   - Every drag has a click-click alternative (box-select: click a corner,
     click the opposite corner).
   - No action uses a double-tap or a press-and-hold timer unless its
     threshold is a #7 setting and a single-press alternative exists.
   - Destructive confirmations may be hold-to-confirm only with a visible
     progress ring and a single-press alternative.

**C. Contexts**

10. **Contexts and priority.** Input contexts form a stack. An event goes to the
    top active context first; it either consumes the event or passes it down.
    **Global** is checked last and always. A **modal** consumes everything
    except its own actions and Esc. The contexts, top to bottom:

    | Priority | Context | Active when |
    |---|---|---|
    | 1 | Text entry | a text field has focus: only text, Enter and Esc |
    | 2 | Modal / rebind capture | a dialog or capture is open |
    | 3 | Menu | the system menu or a settings screen is open |
    | 4 | Planning screen | Dossier, Ledger, Case File or Debrief is open |
    | 5 | Command | the simulation is held in BATTLE, or the command cursor is active |
    | 6 | Combat-live | BATTLE with an empty hold set: Flight, Fleet (live), Camera, Time |
    | 7 | Campaign | outside BATTLE (map and port screens; owned by their GDDs) |
    | — | Global | always (system menu, screenshot, fullscreen) |

    Time actions (pause, resume, step, speed) and Camera actions stay live in
    priorities 4–6. Pause is reachable in every context except text entry and
    a rebind capture.
11. **While the simulation is held, the flight command is discarded.** In the
    Command context the sampler still runs but the flight command it produces
    is neutral and is not recorded. A press latched *before* the hold stays
    latched, shown and cancellable (Simulation Tick & Pause, UI item 6); new
    flight presses during a hold are not latched. On resume, held actions are
    re-read from the keys actually down; nothing pressed during the hold is
    replayed.
12. **Focus loss releases everything held.** When the window loses focus, every
    held and toggled flight input is released, sticky modifiers are cleared, any
    drag is cancelled, and the next sample is neutral. Latched presses stay, as
    in rule 11 (losing focus adds `SYSTEM:focus_lost` and, in BATTLE,
    `PLAYER_PAUSE`; Simulation Tick & Pause rule 16). On return, nothing resumes
    by itself, and held actions need a fresh press.

**D. From input to the game**

13. **Input produces two outputs, and the core reads neither directly.**
    - **The flight command**, sampled once per rendered frame when
      `begin_frame()` asks for it: a move axis (rule 16), the aim (converted
      and quantized per Simulation Tick & Pause rule 6), fire bits, ability
      bits (edge-latched, one press per bit per tick) and the move-frame flag
      (rule 16).
    - **Requests**: order and queue edits for Fleet Orders, selection changes,
      pause/resume/step/speed for the Tick driver, camera actions for Camera,
      and screen navigation. Requests made during a frame are applied in
      `begin_frame()` step 2, never mid-tick.
    The sampler is a plain class with an injected input source; tests and the
    headless runner replace it with scripted frames. No simulation code reads
    `Input`, `InputMap` or an autoload that does.
14. **Order gestures** (proposed here; Fleet Orders #19 owns what each does).
    In the Command context: LMB selects a ship; LMB-drag (or click-click) box-
    selects; Shift+LMB adds or removes; RMB issues the context-sensitive order
    (empty space, enemy, ally — semantics in #19); Shift+RMB appends to the
    queue; X cancels the selection's queued orders; Shift+X, or a click on empty
    space, deselects. A queued
    order's marker can be dragged or clicked to edit it until the tick that
    applies it (Simulation Tick & Pause rule 5). The keyboard path: Tab cycles
    selection, R opens the order menu, arrow keys move its cursor, Enter
    confirms.
15. **The helm and the command never share the mouse at once.** In Combat-live
    the mouse is the helm: LMB/RMB fire, the cursor aims. Live fleet orders
    use the order hotkeys F1–F5 (issued to the current selection, at the cursor
    or the locked target) and need no mode switch. For a pointed order while
    live, the player holds (or toggles) the **command cursor**: the cursor
    changes shape, mouse buttons become Command gestures, and while it is
    active **the flight command's fire bits are forced off and its aim is held
    at the last value**. Movement keys still fly. The cursor change never
    relies on colour alone.
16. **Move axis and move frame.** The move axis is two integers in −1000…1000
    (permille), with the diagonal clamped to length 1000 (Formulas D1). The
    player chooses a **move frame** (#7): *ship-relative* (default; W thrusts
    along the flagship's facing) or *screen-relative* (W moves up the screen,
    the flagship turns toward the aim). The flag travels in the command, and
    Flagship Piloting (#15) does the conversion inside the simulation from the
    settled facing, so a replay never depends on the camera. **Facing source:** in
    ship-relative mode, Flagship Piloting (#15) decides whether the mouse aim,
    Q/E, or both turn the flagship; Q/E are always the keyboard-only turn path.
    In screen-relative mode the flagship turns toward the aim. *Screen-relative
    assumes the combat camera never rotates (Camera & Combat View #45).*
17. **Keyboard-only aim.** Every flight action has a keyboard path. Aim, the one
    pointer action, has two: **target next/previous** locks an enemy, and **aim
    at locked target** makes the aim follow it (the sampler aims at the locked
    target's last settled position, quantized as any aim). With no lock, aim
    holds straight ahead. Aim-assist strength beyond this is a #7 option
    (off by default). *Mouse-only play is not supported at MVP (stated limit,
    Open Questions); left-hand-only and keyboard-only are.*

**E. Camera, cursor and timing**

18. **Camera input never touches the simulation.** Pan is arrow keys or
    middle-drag; zoom is the wheel; recentre is C. Edge scroll is off by
    default, and when on it works only with the window focused. Camera
    position never enters the command except through the aim conversion
    (Simulation Tick & Pause rule 6).
19. **Timing thresholds are settings.** Click-vs-drag distance, box-select
    delay, double-click window, hold-to-confirm time and menu key-repeat are
    #7 values (Formulas D2–D4), take effect without a restart, and scale with
    UI scale where they are distances.
20. **Rebinding pauses the battle.** The binding screen is reached from the
    system menu, so the simulation is held while it is open. New bindings take
    effect when the screen closes; latched presses are cleared at that moment.
21. **Prompts read the live table.** Every on-screen prompt shows the current
    primary binding (or the secondary when the primary is unbound), as the
    player's keyboard layout labels it, and updates the moment a binding
    changes.

### States and Transitions

| State (context on top) | Entered by | Live actions | Masked | Leaves to |
|---|---|---|---|---|
| Campaign | not in BATTLE | campaign screens' own, Camera, Global | Flight, Command | Combat-live (battle starts), Menu, Planning |
| Combat-live | BATTLE with empty hold set | Flight, Fleet (live), Camera, Time, Global | Command (until command cursor) | Command (any hold, or command cursor), Planning, Menu |
| Command | a hold in BATTLE, or command cursor active | Command gestures, Fleet, Camera, Time, Planning hotkeys, Global; in command-cursor mode also movement | fire, aim (held), new flight presses | Combat-live (hold set empties / cursor released) |
| Planning screen | J / L / K, Debrief | the screen's own, Time, Camera (where shown), Esc | Flight, Command | the context below (Esc / close) |
| Menu | Esc, focus loss in BATTLE adds pause | Menu navigation, Esc | all game actions | the context below (back / Resume) |
| Modal / capture | dialog or rebind capture | the modal's own, Esc | everything else | the context below (confirm / cancel) |
| Text entry | a text field focused | text, Enter, Esc | every game action, pause | the context below (Enter / Esc / unfocus) |

Opening a planning screen in BATTLE adds a `PLANNING:*` hold (Simulation Tick &
Pause), so Combat-live never sits under a planning screen.

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | Input → Tick | The flight command, sampled when `begin_frame()` asks; pause, resume, step and speed requests. Tick owns latching, recording, the hold set and when the command is read |
| Gameplay Settings & Modifiers (#7) | #7 → Input | Hold/toggle per action, sticky modifiers, move frame, timing thresholds, cursor sensitivity, aim-assist strength, edge scroll. Input stores only bindings |
| Flagship Piloting (#15) | Input → #15 | The command bits and the move-frame flag; #15 defines their meaning and does the frame conversion |
| Fleet Orders (#19) | Input → #19 | Selection, order and queue-edit requests, cancels, order hotkeys; #19 owns semantics and order names |
| Camera & Combat View (#45) | both | Camera actions → #45; #45 supplies the frame's camera transform for aim conversion and must not rotate (rule 16) |
| Menus, Settings & Save UI (#51) | both | #51 draws the binding screen, controls reference and prompts from Input's table; Input owns conflict logic, capture and reset |
| Combat Event Bus & Battle Record (#9) | none | Only the command is recorded (by Tick), never raw input or bindings |
| Planning screens (Dossier, Ledger, Case File, Debrief) | Input → screens | Open/close and tab actions; each screen's own actions are named in its GDD and live in the Planning context |
| Accessibility requirements | both | Rules 6–9, 17; `design/accessibility-requirements.md` (not yet written) must cite them |

## Formulas

### D1. Move axis

`raw = (right − left, up − down)` for keys (each 0 or 1), or the analogue value
when a device provides one.

`axis = round_half_away(1000 × raw / max(1, |raw|))` per component when
`|raw| > 1`, else `round_half_away(1000 × raw)`.

| Variable | Type | Range | Description |
|---|---|---|---|
| raw | 2-vector | each component −1…1 | Combined key state |
| \|raw\| | float | 0 – √2 | Euclidean length |
| axis | 2 × int | −1000 … 1000 | Recorded permille move axis; length ≤ 1000 (± rounding) |

**Output Range:** each component −1000…1000. **Example:** W+D gives raw (1, 1),
|raw| = 1.414, axis = (707, 707) — diagonal speed equals straight speed. W
alone gives (0, 1000). Integers keep the recorded command exact on replay.

### D2. Click vs drag

`is_drag ⇔ distance(press_pos, current_pos) ≥ DRAG_THRESHOLD_PX × ui_scale`
**and** `time_held ≥ BOX_SELECT_DELAY_MS`.

| Variable | Type | Range | Description |
|---|---|---|---|
| DRAG_THRESHOLD_PX | int | 2 – 20; **6** | #7 setting |
| ui_scale | float | 0.75 – 2.0 | #7 UI scale |
| BOX_SELECT_DELAY_MS | int | 50 – 150; **100** | #7 setting |

**Example:** at UI scale 1.5 a press must travel 9 px and last 100 ms to start a
box; a 5-px wobble on a click still selects the ship under it.

### D3. Hold and double-click

`is_hold ⇔ time_down ≥ HOLD_THRESHOLD_MS`; `is_double ⇔ t₂ − t₁ ≤
DOUBLE_CLICK_MS` with the second press within `DRAG_THRESHOLD_PX` of the first.

| Variable | Range | Default | Description |
|---|---|---|---|
| HOLD_THRESHOLD_MS | 150 – 1500 | 400 | Used only by hold-to-confirm (rule 9) |
| DOUBLE_CLICK_MS | 200 – 800, or off | 300 | Used only for "select all of this type"; single-press alternative: Ctrl+A then filter |

### D4. Menu key repeat

`repeat_times = { REPEAT_DELAY_MS + k × REPEAT_INTERVAL_MS : k = 0, 1, 2, … }`
after the initial press, while held. Never applied to confirm or back.

| Variable | Range | Default |
|---|---|---|
| REPEAT_DELAY_MS | 100 – 1000 | 400 |
| REPEAT_INTERVAL_MS | 50 – 120 | 80 |

**Example:** holding ↓ for 1 s in a list moves 1 + 8 = 9 rows (press, then at
400, 480, … 960 ms).

### D5. Latency budget share

Input's share of Simulation Tick & Pause's ≤ 83 ms target is the sampling stage
only: `t_sample ≤ 1 frame` (16.7 ms at 60 Hz), plus `begin_frame()` sampler
cost ≤ `SAMPLER_BUDGET_MS` = 0.1 ms. Input adds no buffering beyond one frame.

## Edge Cases

- **If two presses of one ability land between two ticks**: one is latched;
  the second is ignored (one press per bit per tick, rule 13). Abilities are
  one-shot per tick, so nothing is lost that could have acted.
- **If a press and release both happen within one rendered frame**: the press
  is still latched, because presses are taken from input events, not from
  polling. Held (level) actions see only frames where the key is down.
- **If the player alt-tabs while holding thrust and fire**: both are released
  (rule 12); the battle is paused by `SYSTEM:focus_lost`; returning needs a
  fresh press.
- **If the player holds a key through a pause**: on resume, it acts only if it
  is still physically down; nothing pressed during the pause is replayed
  (rule 11).
- **If the flagship is destroyed**: the command is ignored and latched presses
  are cleared (Simulation Tick & Pause rule 6). Fleet and Camera actions keep
  working, and a prompt shows the fleet can still be ordered.
- **If the player unbinds every action**: Esc still opens the system menu (and
  pauses a live battle, even with ships selected), and from there Settings →
  Controls → Reset (rule 8).
- **If a rebind would leave pause, system menu or confirm unbound**: a warning
  asks first; Esc keeps menu access in any case.
- **If the same key is bound in two contexts that are never active together**:
  the active context consumes the press; the other never fires on it.
- **If a binding file is from an older version**: it migrates; unknown actions
  get their defaults; removed actions are dropped; the player is told once.
- **If a binding file names a key the current layout lacks**: the binding is
  kept and shown as unavailable; the action falls back to its secondary or its
  default, and the player is told.
- **If a text field has focus**: no game action fires, including pause (rule
  10); Esc leaves the field first.
- **If the command cursor is held when a hold begins**: Command context takes
  over unchanged; releasing the cursor while still held does nothing.
- **If the command cursor is released mid-drag**: the drag is cancelled.
- **If the mouse leaves the window during a drag or held fire**: the drag is
  cancelled; fire continues only while the window keeps focus and the button
  is down.
- **If the player switches move frame mid-battle**: it takes effect on the
  next sample; the flag change is recorded like any command change, so the
  replay matches.
- **If aim at locked target is on and the target dies or leaves sensors**: the
  lock clears, aim holds straight ahead, and the next target press locks again.
- **If "screen-relative" is chosen and the camera ever rotates** (a future
  camera feature): not allowed; Camera & Combat View must keep north up or this
  rule must change first.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | `begin_frame()` sampling, latching, recording, hold set, focus-loss hold, step/speed rules |
| Gameplay Settings & Modifiers (#7) | Hard (reverse) | Reads Input's action list; supplies hold/toggle, sticky modifiers, move frame, thresholds, sensitivity, aim assist, edge scroll |
| Flagship Piloting (#15) | Hard (reverse) | Consumes the command and move-frame flag |
| Fleet Orders (#19) | Hard (reverse) | Consumes selection and order requests |
| Camera & Combat View (#45) | Hard (reverse) | Consumes camera actions; supplies the camera transform; north-up |
| Menus, Settings & Save UI (#51) | Hard (reverse) | Draws binding, controls-reference and prompt UI |
| Combat Event Bus & Battle Record (#9) | Soft | Records the command (via Tick), never input |

Bidirectional check: Simulation Tick & Pause already lists Input & Controls (its
Interactions and Dependencies). #7, #15, #19, #45 and #51 already list Input &
Controls in the systems index; their GDDs must state these contracts.

## Tuning Knobs

| Knob | Default | Safe range | Owner | Affects | Too low | Too high |
|---|---|---|---|---|---|---|
| `DRAG_THRESHOLD_PX` | 6 | 2 – 20 | #7 | Click vs drag | Clicks become boxes | Small boxes impossible |
| `BOX_SELECT_DELAY_MS` | 100 | 50 – 150 | #7 | Box start | Accidental boxes | Box feels sluggish |
| `HOLD_THRESHOLD_MS` | 400 | 150 – 1500 | #7 | Hold-to-confirm | Accidental confirms | Slow confirms |
| `DOUBLE_CLICK_MS` | 300 (or off) | 200 – 800 | #7 | Select-by-type | Hard to double-click | Two clicks merge |
| `REPEAT_DELAY_MS` | 400 | 100 – 1000 | #7 | Menu repeat start | Overshoot | Slow lists |
| `REPEAT_INTERVAL_MS` | 80 | 50 – 120 | #7 | Menu repeat rate | Overshoot | Slow lists |
| `CURSOR_SENSITIVITY` | 1.0 | 0.25 – 4.0 | #7 | Cursor speed | Slow aim | Twitchy aim |
| `EDGE_SCROLL` | off | on/off; band 2 – 8 px, dwell 150 ms | #7 | Camera | — | — |
| `AIM_ASSIST` | off | off – strong | #7 | Keyboard/assisted aim | — | Aim becomes automatic |
| `MOVE_FRAME` | ship-relative | ship / screen | #7 | Flight model | — | — |
| `SAMPLER_BUDGET_MS` | 0.1 | 0.05 – 0.5 | engineering | Frame cost | — | Latency budget eaten |

Default bindings are data (`assets/data/input/default_bindings`), not knobs.

## Visual/Audio Requirements

- **Cursor shapes**: aim reticle (Combat-live), command cursor (Command), and
  menu pointer differ in **shape**, not only colour.
- **Selection and box**: a box outline while dragging; selected ships marked by
  shape (brackets) plus colour.
- **Latched-press and sticky-modifier indicators**: small HUD glyphs with text,
  not colour alone (matches Simulation Tick & Pause UI item 6).
- **No input sounds** beyond standard UI clicks; failed actions (e.g. order to an
  unreachable point) use #19's feedback, not a buzzer.

## Game Feel

- **Raw aim**: no smoothing or acceleration added by the game; sensitivity is
  the only scaling. The reticle is drawn at the unquantized point.
- **One frame to the sample**: the sampler adds no buffering (D5); the rest of
  the latency chain belongs to Simulation Tick & Pause.
- **No mode surprises**: the mouse is the helm unless the player explicitly
  holds the command cursor or the battle is held (rule 15).
- **Forgiving clicks**: the drag threshold and box delay (D2) stop a sloppy
  click turning into a box.

## UI Requirements

Owned by Menus, Settings & Save UI (#51); Input supplies the table and logic.
- **Controls screen**: per-context tabs (Flight, Fleet, Command, Camera, Time,
  Planning, Menu, Global); primary and secondary slots; capture prompt; inline
  conflict marker with icon + text; Swap / Replace / Cancel; reset per action,
  per context, all (confirmed). Fully keyboard-navigable.
- **Presets**: Default, Left-hand-only, Keyboard-only (rule 17). Applying a
  preset asks first.
- **Controls reference**: searchable, reachable from the pause menu and
  Settings, showing current bindings.
- **Context strip**: while held in battle, a compact strip lists select, order,
  queue and resume with current bindings.
- **First-use prompts**: shown the first time an action matters (fly, fire,
  pause, order), fading after 3 uses; restorable in Settings.
- 📌 **UX Flag — Input & Controls**: this system has UI requirements. In Phase 4
  (Pre-Production), run `/ux-design` for the controls screen, presets and
  prompts **before** writing epics. Stories should cite `design/ux/[screen].md`.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Sampling, latching, recording, aim quantization | `design/gdd/simulation-tick-and-pause.md` | Rules 5, 6, 7, 9, 16; latency target; UI item 6 | Rule dependency |
| Binding file vs saves | `design/gdd/save-load-and-migration.md` | Core Rules 1, 4 (saves are simulation state only) | Boundary |
| Command bits meaning; frame conversion; **facing source in each move frame** | Flagship Piloting (#15) — not yet designed | — | Contract to be accepted |
| Order semantics and names | Fleet Orders (#19) — not yet designed | — | Contract to be accepted |
| North-up camera, transform | Camera & Combat View (#45) — not yet designed | — | Contract to be accepted |

## Acceptance Criteria

- **AC-01 (Logic; rule 13)**: a static check finds no `Input.`, `InputMap.` or input-reading autoload reference in simulation code. A headless run with an empty command gives the same `state_hash` across 100 runs.
- **AC-02 (Logic; rules 4, 13; determinism)**: **GIVEN** a scripted input source, **WHEN** the same battle runs once with default bindings and once with every action rebound (scripted to press the new inputs), **THEN** the recorded command stream and final `state_hash` are identical, and no binding data appears in the replay or save.
- **AC-03 (Logic; rule 1, 6)**: a script over the full action list binds each action to an unused key, then to an unused mouse button (left, right, middle, side 1/2, wheel up/down), then to a modifier+key; each capture succeeds and the action fires from it.
- **AC-04 (Logic; rule 4)**: bindings survive a restart; a missing file, a corrupt file and a file of `schema_version` N−1 each load (defaults, defaults, migrated) without a crash, and the player is told once.
- **AC-05 (Logic; rule 7)**: binding an input already used in the same context offers Swap, Replace and Cancel, and each does exactly that; binding Flight fire and Menu confirm to the same input is accepted with no prompt.
- **AC-06 (Logic; rule 8)**: in a live battle with ships selected and Space unbound, Esc opens the system menu and adds `PLAYER_PAUSE`. After unbinding every rebindable action, Esc opens the system menu and Reset restores defaults; Esc cancels a capture; removing the last binding of pause, system menu or confirm shows a warning first.
- **AC-07 (Logic; rule 9)**: an audit over the action list finds no action whose only path is a chord, double-tap, hold timer or drag; with every hold/toggle set to toggle, no action needs a continuously held input; with sticky modifiers on, Shift+RMB queues via Shift-tap then RMB.
- **AC-08 (Logic; rule 10)**: with a text field focused, pressing every bound key fires no game action; with a modal open, only its actions and Esc fire; pause fires in the Campaign, Combat-live, Command and Planning contexts.
- **AC-09 (Logic; rule 11)**: with the simulation held, flight presses produce a neutral, unrecorded command; a press latched before the hold stays latched and cancellable; a key pressed and released during the hold has no effect after resume; a key still down at resume acts from the first resumed sample.
- **AC-10 (Logic; rule 12)**: a simulated focus-out while thrust, fire and a sticky modifier are active releases all of them within one frame, cancels any drag, and the next sample is neutral; latched presses remain.
- **AC-11 (Logic; rule 13, latching)**: an ability press injected between two ticks is consumed by exactly one tick; ten presses of the same ability within one frame latch exactly one; a press and release inside one frame still latch.
- **AC-12 (Logic; rule 15)**: while the command cursor is active, the recorded fire bits are 0 and the aim equals its value at activation, while movement still changes the axis; releasing it restores live aim on the next sample.
- **AC-13 (Logic; rule 16, D1)**: W+D records (707, 707); W records (0, 1000); no key records (0, 0); switching move frame records the flag change on the next sample, and a replay of a frame switch matches.
- **AC-14 (Logic; rule 17)**: with only the keyboard, target next locks the nearest enemy in sensor order, aim at locked target records an aim equal to the target's settled offset quantized to `AIM_QUANTUM`, and the lock clears when the target dies.
- **AC-15 (Logic; rule 18)**: panning, zooming and recentring change no recorded command and no `state_hash`; a still cursor under a moving camera gives a constant recorded aim (Simulation Tick & Pause rule 6).
- **AC-16 (Logic; rule 19, D2–D4)**: at `DRAG_THRESHOLD_PX` 6 and UI scale 1.5, a 8-px move does not start a box and a 9-px move held 100 ms does; changing each threshold to its minimum and maximum takes effect without a restart and breaks no action; holding ↓ for 1 s with defaults moves 9 rows.
- **AC-17 (Logic; rule 21)**: rebinding fire primary updates every prompt that shows it on the next frame; with the primary unbound, prompts show the secondary.
- **AC-18 (Integration; rule 20)**: opening Controls in battle holds the simulation; closing it applies new bindings and clears latched presses; the next tick reads only the new bindings.
- **AC-19 (Integration; rule 2)**: with the default scheme on QWERTY and AZERTY layouts, the movement keys are the same physical keys, and prompts show each layout's labels (manual test, both layouts).
- **AC-20 (Integration; playtest; rules 9, 17)**: a full battle (fly, target, fire, select, order, queue, pause, step, change speed) is completed with the keyboard only, and again with the Left-hand-only preset, by a tester following only on-screen prompts.
- **AC-20b (Playtest; rule 16, feel target)**: in a first-session playtest, a tester flies the default scheme for 5 minutes; none of their "wrong direction" comments concern the move frame.
- **AC-21 (Performance; D5)**: `begin_frame()` sampling takes ≤ `SAMPLER_BUDGET_MS` (0.1 ms) at the 95th percentile over 10,000 frames on the minimum-spec machine; input-to-sample delay is ≤ 1 frame (measured with an injected timestamped event).
- **AC-22 (UI; UI Requirements)**: the controls screen, conflict prompt, preset prompt, controls reference and held-battle context strip each have a retained screenshot in `production/qa/evidence/` when their #51 story closes, and each is operated with the keyboard alone.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Engine input behaviour on 4.7.2** — `_input` vs `_unhandled_input` order with GUI, polling from the driver's `_process`, accumulated input, focus-out auto-release, physical vs logical keycodes, IME, runtime `InputMap` changes and serialising events. The engine reference (`modules/input.md`) covers only device IDs, SDL3, VirtualJoystick and dual focus; the rest is NOT SOURCEABLE and needs a spike. | gameplay-programmer, godot-specialist | Input ADR |
| 2 | **Mouse-only play** is a stated limit at MVP. Revisit with accessibility testing. | accessibility-specialist | Polish |
| 3 | **Gamepad and Steam Deck** layouts (fleet command on a pad needs a radial or cursor mode). | game-designer, ux-designer | Post-launch |
| 4 | **Hold-to-pause / slow-time** as an optional second pause path. | game-designer | Post-MVP |
| 5 | ~~**Live order hotkey set**~~ **Resolved 2026-10-30** by Fleet Orders rule 3: F1 Attack, F2 Move, F3 Hold, F4 Regroup, F5 Focus Fire; Retreat never on a single key. | Fleet Orders (#19) | Resolved |
| 6 | **North-up camera** is assumed by screen-relative movement (rule 16). | Camera & Combat View (#45) | When #45 is designed |
| 7 | **`design/accessibility-requirements.md`** does not exist; the Pre-Production gate checks it. It must cite rules 6–9 and 17. | ux-designer, accessibility-specialist | Before Pre-Production |
