# Camera & Combat View

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (shake 500‰; Escort follow after loss; frame sets only visible ships; no shake/glide while held)
> **Implements Pillar**: Pillar 3 (Hands on the Helm — the camera keeps the flagship central while the fleet stays readable); Pillar 4 (Plan in the Open — pause and zoom let the player read the whole field)

## Summary

Camera & Combat View is the battle's north-up, top-down window. It locks onto the flagship while the battle runs, lets the player pan and zoom freely while it is held, frames the whole field at battle start and the surviving fleet after the flagship is lost. It is presentation only. It draws interpolated positions and adds a reducible shake, and it never changes the simulation, the recorded command or the replay.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Simulation Tick & Pause, Input & Controls, Combat Space, Runtime ID Service`

## Overview

Camera & Combat View owns one thing: the **view transform** of the battle
scene. That is a centre point in field units, a zoom (the half-height of the
view in field units) and a small screen-space shake offset. The camera never
rotates. It has four working modes. **Follow** keeps the flagship's drawn
position at a fixed point on screen, so a still cursor gives a constant aim.
**Free** anchors the view to the field while the battle is held, so the player
can read and plan anywhere. **Frame** fits a set of ships to the screen, used at
battle start and after the flagship is lost. **Glide** is a short eased move
between the others. Ships are drawn between ticks by interpolation from the
last two settled ticks. All camera state is floating point, lives in scene
nodes, is never saved and is never read by `SimState`. The only path from the
camera into the simulation is the aim conversion that Simulation Tick & Pause
(rule 6) already owns and quantizes. There is no camera in a headless run.

## Player Fantasy

**I am at the helm, and the chart is in my hands.** While the battle runs, the
flagship sits at the centre of the world and the stars slide past it: the
player is flying. When the player pauses, the view comes loose, and the battle
turns into a chart the player can pull, zoom and read edge to edge. Resume, and
the view slides back to the helm.

*Anchor moment:* the flagship takes a broadside and the screen kicks, once,
small. The player pauses. The view stops still. They wheel out to see the
whole field, drag over to the enemy relay, zoom in on the cursor to read its
escorts, and queue an order. They press Space. The view glides back to the
flagship in a quarter-second and the battle runs on.

**Pillars served:**
- **Pillar 3 (Hands on the Helm):** a hard follow lock and a constant aim under
  a still cursor make the flagship feel directly flown.
- **Pillar 4 (Plan in the Open):** while held, nothing hides; the whole field
  fits on one screen.
- **Pillar 1 (Every Defeat Is a Lead):** when the flagship is lost, the camera
  shows where and then shows what the fleet does next, rather than cutting away.

**This system must never make the player feel:** "the camera moved my aim",
"I lost my flagship off-screen", "I can't see the fight I'm planning", or
"the shake made me sick".

## Detailed Design

### Core Rules

**A. What the camera is**

1. **The view is three values.** A centre `c` (field units, float), a zoom `H`
   (half the view's height in field units, float) and a shake offset `s`
   (pixels, float). Floats are allowed: this is presentation only.
2. **North is always up.** The camera never rotates, rolls or tilts. Input &
   Controls rule 16 (screen-relative move frame) depends on this.
3. **The camera never touches the simulation.** No camera value is in
   `SimState`, the save, the Battle Record or the replay log. No camera code
   reads a simulation RNG stream. A battle run headless (no camera) and the same
   battle run with any camera moves give the same `state_hash` every tick.
4. **The one crossing is the aim.** Each frame the camera supplies its
   **unshaken** transform to the aim conversion (Simulation Tick & Pause rule
   6). Shake is applied after that, to drawing only. Tick quantizes the result.
5. **The camera resets each battle.** It is not saved. A battle always opens in
   Frame (rule 12) at the field centre.

**B. Drawing between ticks**

6. **Interpolate, never extrapolate.** Every moving thing is drawn at its
   position between the last two settled ticks, using the alpha the Tick
   driver gives presentation (Formulas D1). It is never drawn ahead of the
   newest settled tick.
7. **While held, draw the settled tick.** When any hold begins, alpha is set to
   1 and stays there until the hold set empties. The drawn ships then match
   the tactical overlay and the settled state exactly. The jump is at most one
   tick of motion (6.7 u for a 400 u/s hull).
8. **Step draws settled.** After a Tactical step, alpha is 1.
9. **Spawns and departures do not interpolate.** A ship's first tick draws at
   its settled position. A ship that departs or is removed is not drawn after
   its last settled tick (the wreck is a separate visual).

**C. Follow, pan and zoom**

10. **Follow is a hard lock.** In Follow, `c = p_draw(flagship) + o`, where
    `o` is the pan offset (D2). There is no lag, damping or look-ahead. Reason:
    a still cursor must give a constant aim (Tick rule 6); any lag would make
    the aim drift while the player's hand is still.
11. **Pan.** Arrow keys, middle-drag and edge scroll (when on; Input rule 18)
    pan the view.
    - **While the battle runs**, pan changes the Follow offset `o`. It is
      clamped so the flagship stays inside `LIVE_PAN_MAX_PM` of the view's
      half-extent (D2). The flagship can never leave the screen while flown.
    - **While held**, the first pan input enters **Free**. Free keeps `c`
      fixed in the field and pans it there. `c` is clamped to within
      `FIELD_R` of the field centre (D2).
    - Key pan speed scales with zoom (D8). Middle-drag moves the field 1:1
      with the cursor.
12. **Frame.** Frame fits a set of points to the screen (D5), clamped to the
    zoom range. It is used:
    - at battle start: every ship on both sides;
    - after the flagship is lost: the player's surviving ships (rule 17);
    - on the **frame all** action (Home, an Input amendment): every ship.
    Frame is fitted once on entry, not re-fitted every frame, except in Fleet
    frame (rule 17).
    - Frame sets include only ships the player's view currently shows; the
      camera never fits to a position the HUD does not display.
13. **Zoom.** Each wheel notch multiplies `H` by `ZOOM_STEP_PM` (in or out),
    clamped to `ZOOM_MIN_H` … `ZOOM_MAX_H` (D3). The change eases over
    `ZOOM_EASE_MS`.
    - **In Follow**, zoom is about the view centre, so the lock holds.
    - **In Free and Frame**, zoom is **to the cursor**: the field point under
      the cursor stays under the cursor (D4). Zooming a Frame view enters Free.
14. **Recentre (C).** Glides to Follow with `o = 0`. In No flagship it re-fits
    Fleet frame instead.
15. **Resume.** When the hold set empties in Free or Frame, the camera glides
    to Follow over `RECENTRE_MS` (D6). If `RESUME_RECENTRE` (a #7 setting) is
    off, the camera instead keeps its centre: it enters Follow with `o` set to
    the current gap between the centre and the flagship, clamped (D2).
16. **Zoom carries over.** Glide changes the centre only. The zoom the player
    chose is kept, except a Glide out of battle-start Frame, which eases to
    `ZOOM_DEFAULT_H`.

**D. Flagship loss, edges and the end**

17. **When the flagship is lost** (disabled or departed; Flagship Piloting rule
    13), the camera:
    - clears any shake and adds the loss shake once (rule 20);
    - holds still on the loss position for `LOSS_HOLD_MS`, then
    - glides into **Fleet frame**: Frame of the player's surviving ships,
      re-fitted every `FLEET_REFIT_MS`, with the zoom only easing, never
      jumping. Pan or zoom enters Free (live or held); C returns to Fleet frame.
      Fleet frame is the default after Loss hold.
    - From Fleet frame, selecting a surviving player ship enters **Escort
      follow**: the same as Follow (rule 10), but it does not feed the aim
      conversion and issues no command. If that ship is lost, glide back to
      Fleet frame. C returns to Fleet frame.
    - If the flagship is lost while held, the camera does not shake or glide.
      Loss hold begins on resume. Until then the off-screen marker points at
      the loss position.
    - If no player ship survives on the field, Fleet frame fits every ship left.
      Frame sets include only ships the player's view currently shows; the
      camera never fits to a position the HUD does not display.
18. **The edge is shown, not hidden.** Follow never clamps the centre, so the
    lock holds at the edge. Outside `FIELD_R` the view shows the chart margin
    (art: Visual/Audio). Free clamps `c` to `FIELD_R`, so the view centre is
    never off the field. `ZOOM_MAX_H` fits the whole field (D3),
    so every retreat arc can be seen at once.
19. **The end beat holds still.** When the battle ends (Battle Resolution, end
    banner), the camera stops where it is for `END_BEAT_MS`. Shake is cleared,
    camera input is ignored, and nothing glides. The Debrief owns any view after
    that.

**E. Feel**

20. **Shake is small, rare and reducible.** Only two events shake: a hit on the
    flagship, and the flagship's loss. Shake is screen-space translation only:
    no rotation, no zoom punch, no flash. Its size is multiplied by
    `CAMERA_SHAKE_PM` (a #7 setting, 0 – 1,000 ‰, default 500 ‰). At 0, or
    with Reduce motion on, there is no shake. No shake starts while held, and a hold clears it.
21. **Shake reads events, not state.** Shake triggers come from the Combat
    Event Bus (#9) presentation feed. Its noise uses a presentation-only random
    source, never a simulation stream.
22. **Glides are short and eased.** Every automatic camera move is a Glide of
    `RECENTRE_MS` with an ease-in-out curve (D6). The camera never snaps more
    than `SNAP_MAX_U` without a Glide, except on battle start.

### States and Transitions

| State | Entered when | Behaviour | Leaves to |
|---|---|---|---|
| Frame (start) | battle start | All ships fitted (D5); start auto-pause usually holds | Free (pan/zoom while held), Glide → Follow (resume) |
| Follow | Glide ends; resume; C | `c = p_draw(flagship) + o`; zoom about centre; live pan changes `o` | Free (pan while held), Frame (Home), Loss hold |
| Free | pan or Frame-zoom while held; pan in No flagship | `c` fixed in field, clamped to `FIELD_R`; zoom to cursor | Glide → Follow (resume, C), Frame (Home), Loss hold |
| Glide | resume from Free/Frame; C; end of Loss hold | Eased move over `RECENTRE_MS` (D6); input pans cancel it into the target mode | Follow, Fleet frame |
| Loss hold | flagship disabled or departed; resume after a loss while held | Still on loss position for `LOSS_HOLD_MS`; loss shake | Glide → Fleet frame; Free (pan/zoom) |
| Fleet frame | after Loss hold (default); C in No flagship; Escort ship lost | Re-fit visible survivors every `FLEET_REFIT_MS` | Escort follow (select a ship), Free (pan/zoom), End beat |
| Escort follow | a surviving player ship selected in Fleet frame | As Follow (rule 10) on that ship; no aim conversion; issues no command | Glide → Fleet frame (that ship lost, C), Free (pan while held), End beat |
| End beat | battle ends | Still; input ignored; shake cleared | — (Debrief) |

Any state goes to End beat when the battle ends.

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Simulation Tick & Pause (#1) | #1 → #45 | Hold set; interpolation alpha from the driver remainder (rule 7); step done. #45 → #1: the unshaken transform for the aim conversion (rule 6) |
| Input & Controls (#6) | #6 → #45 | Pan, zoom, recentre, edge scroll, frame all. #45 → #6: the transform; north-up guaranteed (Input rule 16, OQ 6) |
| Gameplay Settings & Modifiers (#7) | #7 → #45 | `CAMERA_SHAKE_PM`, Reduce motion, `RESUME_RECENTRE`, `EDGE_SCROLL` |
| Combat Space (#11) | #11 → #45 | Settled Q16.16 positions of the last two ticks; `FIELD_R`; edge line and retreat arcs are drawn by their owners in the camera's view |
| Flagship Piloting (#15) | #15 → #45 | Follow target (Runtime ID); loss signal and loss position |
| Runtime ID Service (#3) | #3 → #45 | Stable ship IDs for the follow target and Frame sets |
| Combat Event Bus & Battle Record (#9) | #9 → #45 | Presentation feed: flagship hit, flagship lost |
| Battle Resolution & Retreat | → #45 | Battle end; `END_BEAT_MS` |
| Combat HUD (#46, not yet designed) | #45 → #46 | Transform, zoom `H`, current state, flagship-on-screen flag (hooks only) |
| After-Action Debrief (#24) | — | May reuse Free and Frame for the replay view; owns that view |

## Formulas

All formulas here are presentation floats. None of them run inside `SimState`.

### D1. Interpolated draw position

`x_u = x_q ÷ 65,536` (Q16.16 to field units, float).
`p_draw = p_prev + (p_curr − p_prev) × α`, `α = remainder ÷ tick_length` from
the Tick driver (D2 there); `α = 1` while held (rule 7).

| Variable | Range | Description |
|---|---|---|
| p_prev, p_curr | within `FIELD_R + EDGE_W` | Settled positions at ticks T−1 and T |
| α | 0 – 1 | Fraction of the next tick accumulated |

**Example:** p_prev x = 65,536,000 q (1,000 u), p_curr x = 65,972,906 q
(1,006.667 u, a 400 u/s hull), α = 0.25 → x = 1,000 + 6.667 × 0.25 = **1,001.667 u**.

### D2. Follow centre and pan clamps

Follow: `c = p_draw(flagship) + o`, with `|o_x| ≤ L × H × aspect` and
`|o_y| ≤ L × H`, where `L = LIVE_PAN_MAX_PM ÷ 1,000`.
Free: if `|c| > FIELD_R`, `c = c × FIELD_R ÷ |c|`.

| Variable | Range | Description |
|---|---|---|
| o | per clamp | Live pan offset |
| aspect | 1.0 – 2.4 | Viewport width ÷ height |
| L | 0.3 – 0.8 | Share of the half-extent the flagship may drift |

**Example:** `H` 900, aspect 16/9, L 0.6 → `|o_x| ≤ 960 u`, `|o_y| ≤ 540 u`.
The flagship then sits at least 40 % of the half-extent inside the edge.

### D3. Zoom steps and range

`H' = clamp(H × s^k, ZOOM_MIN_H, ZOOM_MAX_H)`, `s = ZOOM_STEP_PM ÷ 1,000`, k = +1
per notch out, −1 per notch in. `ZOOM_MAX_H = FIELD_R × FRAME_MAX_PM ÷ 1,000`.

**Example:** `FIELD_R` 3,000, `FRAME_MAX_PM` 1,100 → `ZOOM_MAX_H` **3,300 u**
(the whole field plus 10 % on the short axis). From `ZOOM_MIN_H` 300 at s 1.25:
300 × 1.25¹⁰ = 2,794, 300 × 1.25¹¹ = 3,492 → clamped to 3,300. **11 notches**
span the range. From the default 900: 5 notches out give 2,747 and the 6th
clamps to 3,300; 5 notches in give 294.9, clamped to 300.

### D4. Zoom to cursor

`c' = P + (c − P) × H' ÷ H`, where P is the field point under the cursor.

**Example:** c = (0, 0), P = (400, 0), H 900 → 720 (one notch in). c' = 400 +
(−400 × 0.8) = **(80, 0)**. Check: P sat (400 − 0) ÷ 900 = 0.444 half-heights
right of centre before, and (400 − 80) ÷ 720 = 0.444 after. The point stays
under the cursor.

### D5. Frame fit

Over the set's drawn positions: box `[x_min, x_max] × [y_min, y_max]`; `c` = box
centre; `H = clamp(max(h_y, h_x ÷ aspect) + FRAME_PAD_U, ZOOM_MIN_H,
ZOOM_MAX_H)`, with `h_x = (x_max − x_min) ÷ 2`, `h_y = (y_max − y_min) ÷ 2`. An
empty set keeps the current view; a single ship gives `ZOOM_DEFAULT_H`. The set
holds only ships the player's view currently shows (rule 12); jammed or
undetected ships are left out.

**Example:** ships span x −1,700 … 1,400 and y −200 … 500; aspect 16/9;
`FRAME_PAD_U` 200. c = (−150, 150); h_x = 1,550, h_y = 350; 1,550 ÷ 1.778 =
871.9; H = 871.9 + 200 = **1,071.9 u**, inside the range.

### D6. Glide

`c(t) = c0 + (c1 − c0) × e(t ÷ T)`, `e(u) = 3u² − 2u³`, `T = RECENTRE_MS`. The
target c1 is re-read every frame (the flagship moves during the Glide).

**Example:** c0 = (0, 0), c1 = (500, 0), t = 125 ms of 250 → e(0.5) = 0.5 → c =
(250, 0); at t = 62.5 ms, e(0.25) = 0.15625 → (78.1, 0).

### D7. Shake

`trauma = min(1, trauma + add)` per event; it falls by `SHAKE_DECAY_PER_S` per
second to 0. `s = SHAKE_MAX_PX × (CAMERA_SHAKE_PM ÷ 1,000) × trauma² × n(t)`,
where n(t) is presentation noise in −1 … 1 per axis.

**Example:** flagship hit (`add` 0.5), `SHAKE_MAX_PX` 6, setting 1,000 →
peak 6 × 0.25 = **1.5 px**; at decay 2.5/s it is gone in 200 ms. Flagship loss
(`add` 1.0) → **6 px**, gone in 400 ms. At the default 500 ‰: hit peaks at
0.75 px, loss at 3 px.

### D8. Key pan speed

`v = H × PAN_RATE_PM ÷ 1,000` field units per second.

**Example:** H 900, `PAN_RATE_PM` 1,200 → 1,080 u/s: the view crosses its own
half-height in 0.83 s at any zoom.

## Edge Cases

- **If the flagship is lost while held**: the camera does not shake or glide;
  Loss hold begins on resume; the off-screen marker points at the loss position.
- **If the player pans during Loss hold**: Free; the hold is abandoned.
- **If the flagship departs by retreat**: the same as loss (rule 17), but no
  loss shake.
- **If there is no flagship at battle start** (not expected): start in Frame,
  then Fleet frame on resume.
- **If the window is resized**: `H` is kept (half-height), so the width shown
  changes; the D2 clamp is re-applied.
- **If the frame rate drops below 60**: α still comes from the driver; the
  camera follows `p_draw`, so ship and camera stay together and the aim stays
  constant.
- **If the speed is 2× or 4×**: nothing changes here; α comes from the
  remainder at any speed.
- **If the player zooms during a Glide**: zoom applies at once; the Glide goes on.
- **If the flagship is pushed into the edge band**: Follow does not clamp
  (rule 18); the chart margin shows beyond `FIELD_R`.
- **If the cursor is outside the window when zooming in Free**: zoom about the
  centre.
- **If the camera transform is not ready on the first frame**: the aim
  conversion uses the battle-start Frame transform; no command is sent until a
  frame has drawn (Tick samples the latest rendered frame).
- **If a Frame set is all within `ZOOM_MIN_H`**: clamped to `ZOOM_MIN_H`.
- **Degenerate: panning to make the aim drift**: live pan moves the cursor's
  field point, so it changes aim. That is the player's input, recorded like any
  aim, so replays still match.
- **Degenerate: zooming out to see everything all the time**: allowed. Max zoom
  shows the field; ships are small but readable by icon (UI Requirements). No
  information is hidden at close zoom that max zoom reveals, or the reverse.

## Dependencies

| System | Type | Interface |
|---|---|---|
| Simulation Tick & Pause (#1) | Hard | Hold set, α, step; aim conversion (rule 6) |
| Input & Controls (#6) | Hard | Camera actions; north-up contract |
| Combat Space (#11) | Hard | Settled positions, `FIELD_R` |
| Runtime ID Service (#3) | Hard | Follow target and Frame IDs |
| Flagship Piloting (#15) | Hard | Follow target, loss signal |
| Gameplay Settings & Modifiers (#7) | Soft | Shake, Reduce motion, resume recentre, edge scroll |
| Combat Event Bus & Battle Record (#9) | Soft | Shake triggers |
| Battle Resolution & Retreat | Soft | End beat |
| Combat HUD (#46), After-Action Debrief (#24) | Soft (reverse) | Transform, zoom, state |

Bidirectional check: Input & Controls, Flagship Piloting, Combat Space and
Gameplay Settings name #45. Tick, #9 and Battle Resolution need the amendments
listed in Open Questions.

## Tuning Knobs

| Knob | Default | Safe range | Category | Affects |
|---|---|---|---|---|
| `ZOOM_MIN_H` | 300 u | 200 – 500 | Feel | Closest view |
| `ZOOM_DEFAULT_H` | 900 u | 600 – 1,400 | Feel | Flying view |
| `FRAME_MAX_PM` | 1,100 ‰ | 1,000 – 1,300 | Curve | `ZOOM_MAX_H` (D3) |
| `ZOOM_STEP_PM` | 1,250 ‰ | 1,100 – 1,500 | Feel | Notch size |
| `ZOOM_EASE_MS` | 120 ms | 0 – 250 | Feel | Zoom smoothness |
| `PAN_RATE_PM` | 1,200 ‰ | 600 – 2,000 | Feel | Key pan speed (D8) |
| `LIVE_PAN_MAX_PM` | 600 ‰ | 300 – 800 | Gate | How far the flagship may drift live |
| `RECENTRE_MS` | 250 ms | 150 – 500 | Feel | Glide length |
| `SNAP_MAX_U` | 50 u | 0 – 100 | Feel | Largest unglided jump |
| `FRAME_PAD_U` | 200 u | 100 – 400 | Feel | Frame margin |
| `LOSS_HOLD_MS` | 1,500 ms | 800 – 3,000 | Gate | Time on the loss point |
| `FLEET_REFIT_MS` | 500 ms | 250 – 1,000 | Feel | Fleet frame refresh |
| `SHAKE_MAX_PX` | 6 px | 0 – 10 | Feel | Loss shake peak |
| `SHAKE_DECAY_PER_S` | 2.5 | 1.5 – 5 | Feel | Shake length |
| shake `add` (hit, loss) | 0.5, 1.0 | 0.2 – 1.0 | Feel | Per-event trauma |
| `CAMERA_SHAKE_PM` (#7) | 500 ‰ | 0 – 1,000 | Player setting | Shake scale |
| `RESUME_RECENTRE` (#7) | on | on/off | Player setting | Rule 15 |

All in `assets/data/camera/camera.tres`, except the #7 player settings.

## Visual/Audio Requirements

- Beyond `FIELD_R`: a chart margin, clearly not playable space (art-director
  owns the look; it must not read as more field).
- The camera adds no audio. Shake has no sound of its own.
- Reduce motion turns off shake and sets `ZOOM_EASE_MS` to 0; Glides stay
  (they keep orientation) but are capped at 150 ms.
- With Reduce motion on, the Fleet frame refit snaps zoom changes under 5 %
  instead of easing them.

## Game Feel

- **The helm is steady**: the flagship never slides on screen while flown.
- **The chart is in hand**: zoom-to-cursor and 1:1 drag while held.
- **Back in a beat**: resume returns to the helm in a quarter-second.
- **Shake is punctuation**: two events only, a few pixels, gone in under half a
  second.

## UI Requirements

Hooks for Combat HUD (#46):
- an off-screen marker for the flagship whenever it is not on screen (Free);
- a mode tag when the view is not Follow ("Chart", "Fleet");
- ship icons at constant screen size above a zoom threshold
  (`ICON_ZOOM_H`, HUD-owned), so max zoom stays readable;
- the camera exposes the transform, `H`, the state and the flagship-on-screen
  flag; the HUD draws in screen space and never moves the camera.
- 📌 **UX Flag — Camera & Combat View**: include the off-screen flagship marker,
  mode tag and icon threshold in the Combat HUD UX spec.

## Cross-References

| This document references | Target GDD | Specific element | Nature |
|---|---|---|---|
| Aim conversion, α, holds, step | `design/gdd/simulation-tick-and-pause.md` | Rules 6, 7, 12 | Rule dependency |
| Camera actions, north-up | `design/gdd/input-and-controls.md` | Rules 16, 18; OQ 6 | Contract |
| Positions, `FIELD_R`, edge, arcs | `design/gdd/combat-space.md` | Rules 2, 10, 12 | Data dependency |
| Follow target, loss | `design/gdd/flagship-piloting.md` | Rule 13; No flagship | Rule dependency |
| End banner, `END_BEAT_MS` | `design/gdd/battle-resolution-and-retreat.md` | Rule 6; Tuning | Rule dependency |
| Settings keys | `design/gdd/gameplay-settings-and-modifiers.md` | Camera keys | Data dependency |
| Chart language | `design/gdd/game-concept.md` | Art direction item 4 | Source |

## Acceptance Criteria

- **AC-01 (Logic; rule 3)**: the same seed and command log, run headless and run with a scripted camera (pan, zoom, Frame, Glide, shake), give identical `state_hash` on every tick.
- **AC-02 (Logic; rules 4, 10)**: in Follow with the cursor still, the recorded aim is constant across 300 ticks of flagship motion, with shake at 1,000 ‰.
- **AC-03 (Logic; rule 3)**: no camera value appears in the save, the Battle Record or the replay log (schema check).
- **AC-04 (Logic; D1, rule 7)**: the D1 example gives 1,001.667 u ±0.001; when a hold begins every ship draws at its settled position.
- **AC-05 (Logic; D3)**: from `ZOOM_DEFAULT_H`, 6 notches out reach 3,300 (the 5th gives 2,747 ±1) and 5 in reach 300; no notch passes either bound.
- **AC-06 (Logic; D4)**: in Free, the field point under the cursor moves less than 0.5 px across any zoom.
- **AC-07 (Logic; D2, rule 11)**: live pan never puts the flagship's drawn position outside `LIVE_PAN_MAX_PM` of the half-extent; Free never puts `c` beyond `FIELD_R`.
- **AC-08 (Logic; D5)**: the D5 fixture gives c (−150, 150) and H 1,071.9 ±0.1.
- **AC-09 (Logic; rule 15)**: resuming from Free reaches Follow with o = 0 in `RECENTRE_MS` ±1 frame; with `RESUME_RECENTRE` off, the centre does not jump.
- **AC-10 (Logic; rule 17)**: on flagship loss the view stays still for `LOSS_HOLD_MS`, then fits the surviving player ships; C re-fits them.
- **AC-11 (Logic; rule 20)**: with `CAMERA_SHAKE_PM` 0 or Reduce motion on, `s` is 0 for every event; no shake is active while held.
- **AC-12 (Logic; rule 2)**: the transform has zero rotation in every state.
- **AC-13 (UI; rule 19)**: on battle end the view does not move for `END_BEAT_MS` and ignores camera input; retained screenshot of the banner.
- **AC-14 (UI; rule 18, D3)**: at `ZOOM_MAX_H` the whole field edge and every retreat arc are on screen at 16:9 and 21:9; retained screenshots.
- **AC-15 (UI; UI Requirements)**: in Free with the flagship off screen, the off-screen marker points to it; retained screenshot.
- **AC-16 (Playtest; rules 10, 13)**: 4 of 5 testers say the flagship "feels flown, not chased", and none reports the camera moving their aim.
- **AC-17 (Playtest; rule 20)**: no tester reports discomfort from shake at the default (500 ‰); every tester can find the shake setting from the Settings screen.
- **AC-18 (Playtest; rule 17)**: 4 of 5 testers who lose the flagship can say where it was lost and what the fleet did next.
- **AC-19 (Logic; rule 17)**: in Fleet frame, selecting a surviving player ship enters Escort follow on it; across 300 ticks no command is issued and the recorded aim does not change; when that ship is lost the camera glides to Fleet frame; C returns to Fleet frame.
- **AC-20 (Logic; rule 12, D5)**: with a jammed or undetected enemy on the field, battle-start Frame, frame all and Fleet frame each give the same c and H as a fixture without that ship; no Frame fits a position the HUD does not display.

## Open Questions

Resolved with the recommended defaults (the owner may revisit at review): hard
follow lock; live pan as a clamped offset; Free only while held; zoom about
centre in Follow and to cursor elsewhere; Loss hold then Fleet frame; two-event
shake; α = 1 while held. Shake default (was OQ 4): half, 500 ‰. After flagship
loss (was OQ 5): Fleet frame by default, with optional Escort follow (rule 17).

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Tick rule 6 amendment**: in Follow the aim offset is the cursor's field point minus the flagship's **drawn** position (not the last settled one), using the unshaken transform. Otherwise the aim jitters by up to one tick of motion and "a still cursor gives a constant aim" fails. | Tick owner, lead-programmer | Tick re-review |
| 2 | **Input amendment**: add **frame all** (Home) to the Camera row; C re-fits the fleet in No flagship; close Input OQ 6 (north-up accepted). | Input owner | Input re-review |
| 3 | **Settings amendment**: add `CAMERA_SHAKE_PM` (0 – 1,000, default 500) and `RESUME_RECENTRE` (on) to #7; Reduce motion zeroes shake. | Settings owner | #7 re-review |
| 6 | **Presentation feed** (flagship hit, lost) must exist on the Event Bus (#9); Battle Resolution should name the camera's still end beat. | #9 owner, Battle Resolution owner | Next re-review |
| 7 | **Icon threshold and chart margin look** for max zoom. | art-director, ux-designer | Combat HUD (#46) |
| 8 | **Zoom range vs weapon ranges**: `ZOOM_DEFAULT_H` 900 assumes engagements within ~900 u; confirm when Weapons & Damage sets ranges. | Weapons & Damage (#12) | When #12 is designed |
