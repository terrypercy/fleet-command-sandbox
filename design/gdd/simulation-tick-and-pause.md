# Simulation Tick & Pause

> **Status**: In Design
> **Author**: owner + agents
> **Last Updated**: 2026-10-28
> **Last Verified**: 2026-10-28
> **Implements Pillar**: Pillar 3 (Hands on the Helm — "pause is always available"); Pillar 1 (Every Defeat Is a Lead — deterministic replay behind a trustworthy Debrief)

## Summary

[To be designed]

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

Simulation Tick & Pause is the fixed-rate, deterministic step that advances
every piece of simulation state. That covers ships, fleets, Vigor, Coherence
links, projectiles and the world clock. Each step is equal in size,
independent of the frame rate and of the scene tree. Pause freezes that step
while rendering, input and every planning screen stay live. The simulation
holds no scene nodes, so it runs headless: the AI-vs-AI battle runner and the
test suite drive exactly the same steps the player's game does. All randomness
comes from named seed streams (Deterministic RNG & Seed Streams), and nothing in
the simulation reads wall-clock time. As a result, **the same seed and the same
recorded orders always replay the same battle.**

The player never sees the tick, but feels what it guarantees:
- Pausing mid-battle stops everything exactly where it is.
- An order given while paused takes effect on the very next step.
- The battle the After-Action Debrief explains is the battle that actually
  happened.

Without this system three things would break. Pause would freeze the planning
screens along with the fight. The outcome of a battle would depend on frame
rate. And the Debrief's "why you lost" could not be checked by replaying it,
which is the foundation Pillar 1 (*Every Defeat Is a Lead*) and the headless
runner stand on. The system also carries the two pause-related commitments the
concept treats as pillar features rather than polish: a **simulation-speed
scale** and **auto-pause triggers** (Pillar 3, *Hands on the Helm*: "pause is
always available"; and "challenge should feel relaxing").

*How the step is driven inside Godot* (an accumulator fed by frame time versus
the engine's physics tick, and how presentation interpolates between steps) is
an implementation choice → **becomes the Tick/Pause/Determinism ADR**. This GDD
specifies behaviour only.

## Player Fantasy

**The bridge holds its breath.** The player experiences this system
**indirectly**. They never think about the tick. What they feel is composure
under fire, and trust that the battle was fair.

Pause is the admiral's moment of clarity. When the line breaks, the player can
stop the war mid-shot, read every telegraph, and give orders with a steady hand.
Nothing moves until they choose, and nothing they ordered is lost when the fight
resumes. The battle is fast, but the admiral is never rushed into a mistake they
didn't choose. Every fight the player loses happened exactly as they remember
it. They leave a defeat certain of what went wrong, with nothing to blame on
luck or lag.

*Anchor moment:* the machine line starts to fall apart, the flagship's Vigor is
running low, and the player pauses. Everything stops mid-shot. They read the
field, give three orders, and resume. The orders take effect on the very next
step, exactly as given.

**Pillars served:**
- **Pillar 3, *Hands on the Helm*:** "the fleet is commanded, never puppeted;
  pause is always available".
- **The pillar-tension resolution:** "pause, readable telegraphs and difficulty
  options are pillar commitments, not polish".
- **Pillar 1, *Every Defeat Is a Lead*:** "Can the Debrief name at least one
  specific, actionable cause and counter for this loss?" A cause can only be
  trusted if the loss can be replayed exactly.

**Tone:** naval-bridge calm. The player is a commander pausing to think, not a
time wizard. The verbs are *hold, read, order, resume*, never "time-stop" power
language.

**This system must never make the player feel:**
- **That the loss wasn't really theirs.** No outcome may seem to depend on frame
  rate, a dropped order, or a replay that doesn't match their memory. Any of
  those turns "every defeat is a lead" into "the game cheated me".
- **That pausing is a crutch or a lesser way to play.** Nothing penalises,
  scores against or shames using pause, a slower speed, or auto-pause.

*Shaped by `creative-director` (framing A with framing B's closing line).
Framing C, "My Orders, Exactly", was judged an input-latency promise; it is
carried into Game Feel and Acceptance Criteria instead.*

## Detailed Design

### Core Rules

1. **A tick is the only way simulation state changes.**
   - A tick is one atomic, equal-size step, indexed by an integer `tick_index`.
   - `tick_index` is **campaign-monotonic**: it starts at 0 on a new game, is
     saved and restored, and never resets per battle. Each battle's record also
     stores `battle_start_tick`, so battle-relative time is
     `tick_index − battle_start_tick`.
   - Its length is `dt_tick = 1 / TICK_RATE`, and `TICK_RATE` targets
     **60 Hz** (see rule 13).
   - No simulation rule reads a frame delta, `Time.*` or any wall clock.
2. **The simulation is plain data.**
   - All simulation state lives in one `SimState` made of plain-data objects
     that hold no scene nodes.
   - Scene nodes only render that state and collect input.
   - Rendering never writes simulation state. Inspection, tooltips and selection
     are read-only queries.
3. **One tick, one fixed phase order.** Every tick runs these phases in this
   order. The order is fixed in code, never data-driven.

   | Phase | What runs |
   |---|---|
   | P0 | Tick begins (hold check already passed) |
   | P1 | Apply queued orders, in enqueue order, plus the flagship's current command (rule 6) |
   | P2 | AI decisions (Ship AI, then Fleet Coordination) |
   | P3 | Movement (Combat Space integrates positions) |
   | P4 | Weapons fire; projectiles advance |
   | P5 | Hit resolution and damage |
   | P6 | Vigor update, then Coherence and link update |
   | P7 | Resolution checks: destruction, retreat, battle end, and **auto-pause trigger evaluation** |
   | P8 | World Clock advance |
   | P9 | Event flush to the Combat Event Bus & Battle Record, stamped with `tick_index`; tick ends |

   *Why this order:*
   - Orders come first, so an order given while paused takes effect on the very
     next tick.
   - AI reads the previous tick's settled state, so every actor's decisions are
     equally one tick stale. That is fair and deterministic.
   - Movement comes before fire, so shots use current positions.
   - Damage comes before Vigor and Coherence, so erosion and link cuts react to
     this tick's hits.
   - Resolution reads final state.
   - One flush per tick keeps the Battle Record a clean per-tick log.

   **Within any phase, entities are processed in ascending Runtime ID order**,
   never in dictionary or hash order. A phase with no active participants (for
   example, combat phases outside battle) is skipped, and the order of the rest
   is unchanged.
4. **Simulation contexts select phases, not clocks.**
   - In `BATTLE`, every phase runs.
   - In `CAMPAIGN` (travel, port, sector map), the combat phases P2-P6 are
     skipped, and travel and port time advance the World Clock in P8.
   - The tick, the tick rate and the pause machinery are identical in both
     contexts.
   - How many game days a tick is worth is the World Clock's rule, in battle and
     out.
5. **Orders cross into the simulation only through the order queue.**
   - Orders given while paused or between ticks are appended to a queue.
   - Each order is stamped with the `tick_index` it will apply on, which is the
     next tick.
   - P1 drains the queue, and every drained order is written to the replay log
     with that index.
   - Orders for the same ship apply in enqueue order, so the last order wins.
     Fleet Orders defines what each order means.
   - Queued orders are shown to the player, and can be edited or cancelled until
     the tick that applies them.
6. **The flagship's piloting is a live command, not a queued order.**
   - Input is sampled every rendered frame. The simulation reads the flagship's
     current command once per tick, in P1.
   - The command is a small struct: move axis, aim point, fire bits and ability
     bits. The aim point is converted to **world space and quantized** before it
     is recorded, never stored as a screen position, so a replay never depends on
     the camera.
   - Held inputs (thrust, fire) are level-triggered.
   - A press that lands between ticks (an ability) is **latched** until the next
     tick consumes it, so no press is lost.
   - The command is recorded to the replay log when it changes.
7. **Real time enters at exactly one boundary.**
   - In the player's build, one driver feeds frame time into an accumulator:
     `accumulator += frame_delta × speed_scale`. This happens only while the hold
     set is empty.
   - The driver runs whole ticks while `accumulator ≥ dt_tick`, up to
     `MAX_TICKS_PER_FRAME` per frame.
   - The remainder gives presentation its interpolation alpha.
   - This driver is the documented, single place where wall-clock time touches
     the simulation. Nothing inside `SimState` reads it.
8. **Catch-up is capped; excess time is discarded.**
   - If a frame would need more than `MAX_TICKS_PER_FRAME` ticks (a hitch, a long
     load, a slow machine at high speed), the extra real time is dropped, not
     banked. The game visibly slows instead of stalling ("spiral of death").
   - Determinism is unaffected, because what a tick does never depends on how
     many ticks ran in a frame.
   - A "time dropped" note is logged outside the Battle Record.
9. **Speed changes how many ticks run, never what a tick is.**
   - Players choose **0.5×, 1× or 2×**. Dev builds add **4×**.
   - The speed scale multiplies the accumulator feed only, so the same battle has
     the same result at every speed.
   - Choosing a speed never unpauses.
   - If the catch-up cap binds at the chosen speed, the effective speed is lower,
     and the speed display shows the real speed.
10. **Pause is a set of hold reasons owned by this system.**
    - The simulation ticks only when the set is empty.
    - The reasons are:
      - `PLAYER_PAUSE`
      - `AUTO_PAUSE:<trigger_id>`
      - `PLANNING:<screen_id>` (Dossier, Ledger, Case File, Debrief)
      - `SYSTEM:<cause>` (menu, loading, save in progress, window focus lost)
    - **The World Clock reads `is_held()`** and never keeps a separate pause.
      Closing the game holds everything by definition.
    - Pause is the simulation's own state, **not the engine's scene-tree pause**.
      Rendering, input, camera and every planning screen keep running while it
      is held.
11. **Auto-pause is evaluated after the tick and acts before the next one.**
    - Triggers are checked in P7. A trigger only adds a hold reason; it never
      aborts the tick in progress. A pause therefore always lands on a tick
      boundary.
    - Several triggers firing on the same tick are combined into one pause, which
      lists every reason.
    - Each trigger can be toggled, has a cooldown measured in **simulation ticks**,
      and **re-arms only after its condition has cleared**. A trigger never fires
      twice for one crossing.
    - MVP triggers:

      | Trigger | Default | Threshold owned by |
      |---|---|---|
      | Flagship hull critical | **ON** | Hulls / Weapons & Damage |
      | First enemy contact (once per enemy fleet per battle) | **ON** | Combat Space |
      | Vigor early warning | Off | Vigor |
      | Relay cut | Off | Coherence & Links |
      | Escort lost | Off | Battle Resolution |

      Few triggers are on by default, so the game stays relaxing rather than
      interrupting.
12. **Single-step.**
    - While the simulation is held only by `PLAYER_PAUSE` and/or `AUTO_PAUSE`
      reasons, a step command runs **exactly 1 or 10 normal ticks**, including
      P1 orders, and then holds again.
    - Stepping is unavailable while any `PLANNING` or `SYSTEM` reason is present.
    - Players get it **behind an off-by-default option**. Dev builds and the
      headless runner always have it, because it is the same `step()` the runner
      calls.
13. **Tick rate is a versioned engineering constant.**
    - `TICK_RATE` targets 60 Hz. Lower rates add up to about 33-50 ms of
      flagship input latency and double the distance a projectile moves per
      tick.
    - The 60 Hz target is gated by a headless spike: about 100 ships and 500
      projectiles must fit the simulation's share of the frame budget. **If the
      spike fails, the fallback is 30 Hz**, with the aim reticle drawn in
      presentation so aiming still feels immediate.
    - Changing `TICK_RATE` breaks replay compatibility, so it is written into
      every replay and save header. It is not a player setting.
14. **Determinism.**
    - **Same seed, same starting state and same recorded commands give the same
      sequence of states, tick for tick.** This holds on the same build and
      platform, which is the guarantee this game makes.
    - Every replay and save records the engine version, build ID, `TICK_RATE`
      and a content hash. A mismatch is refused, or warned about where
      Save/Load allows it.
    - All randomness comes from Deterministic RNG & Seed Streams. Engine-global
      random calls are banned in simulation code.
    - Integers that can exceed 2^53 (seeds, stream states, hashes) never pass
      through JSON as numbers. The serialization rule belongs to Save/Load and the
      RNG system.
15. **Headless mode.**
    - The runner and tests call `step(n)` directly, with no driver, no
      accumulator, no frame time and no catch-up cap.
    - There is no player, so `PLAYER_PAUSE` and `AUTO_PAUSE` are never added.
      Triggers are **logged instead of pausing**.
    - The headless path calls exactly the same `step()`, with exactly the same
      inputs, as the player's build. Only the cadence differs.
16. **Window focus.** By default, losing window focus adds `SYSTEM:focus_lost`.
    This is a player option.
    - In `BATTLE`, it also adds `PLAYER_PAUSE`, and so does opening the menu.
      Regaining focus therefore leaves the battle paused.
    - On resume, held time is never caught up (D2).
17. **Saves happen on tick boundaries.**
    - A save captures the complete simulation state between ticks: `tick_index`,
      RNG stream states, the queue, and the replay log so far. It never captures
      state mid-step. The accumulator remainder is not saved.
    - Quitting during a live battle resumes it at the last whole tick, under a
      `PLAYER_PAUSE` hold.

### States and Transitions

The state below is **derived** from the hold-reason set and the mode. It is
never stored as a separate enum, so it cannot disagree with the set.

| State | When | Simulation ticks? | World Clock advances? | Leaves when |
|---|---|---|---|---|
| **Running** | Hold set empty | Yes | Yes (per World Clock rate) | Any reason is added |
| **Paused (player)** | `PLAYER_PAUSE` present (others may also be) | No | No | The player resumes, which removes `PLAYER_PAUSE` and all `AUTO_PAUSE` reasons |
| **Paused (auto)** | Only `AUTO_PAUSE:*` reasons present | No | No | The player resumes. A trigger's condition clearing **never** resumes by itself |
| **Held (planning)** | Any `PLANNING:*` present | No | No | That screen closes, removing its own reason only |
| **Held (system)** | Any `SYSTEM:*` present | No | No | The cause ends (menu closed, load or save done, focus regained) |
| **Stepping** | Step command while held only by player or auto reasons | Exactly 1 or 10 ticks | Yes, for those ticks only | Automatically, back to the same held state |
| **Headless** | Runner or test drives `step(n)` | As fast as the CPU allows | Per its rate | The runner stops |

**Stacking rules:**
- Each reason is a unique key. Adding a reason that is already present changes
  nothing.
- **Resume** removes only `PLAYER_PAUSE` and `AUTO_PAUSE:*` reasons. It is
  unavailable while any `PLANNING` or `SYSTEM` reason remains, and the resume
  control says why.
- A screen closing removes **only its own** `PLANNING` reason. Closing the Case
  File therefore never resumes a battle the player had paused. They return to
  Paused.
- Speed changes and steps never change the set.
- Ending a simulation context (battle over) clears `PLAYER_PAUSE` and
  `AUTO_PAUSE` reasons. `PLANNING` and `SYSTEM` reasons persist across contexts.
  The Debrief that opens after a battle is a `PLANNING` hold.

### Interactions with Other Systems

| System | Flows into this system | Flows out of this system | Interface owner |
|---|---|---|---|
| Deterministic RNG & Seed Streams (#2) | — | `tick_index` (for stream bookkeeping) | RNG owns streams and their state; this system never draws randomness itself |
| Runtime ID Service (#3) | Stable IDs used for processing order | — | ID Service owns IDs; this system owns "ascending ID within a phase" |
| Save/Load & Migration (#5) | State restored at a tick boundary | `tick_index`, the queue, the replay log, header fields (`TICK_RATE`, build ID) | Save owns the format and integer-safe encoding |
| Input & Controls (#6) | The flagship command each frame; pause, resume, step and speed inputs | — | Input owns bindings; this system owns latching and when the command is read |
| Gameplay Settings & Modifiers (#7) | Speed steps, the single-step option, auto-pause toggles and cooldowns, focus-loss option | — | Settings owns values; this system reads them **between ticks only** |
| World Clock (#8) | — | P8 call; `is_held()` | **This system owns the hold-reason set**; World Clock owns day maths and reads `is_held()` |
| Combat Event Bus & Battle Record (#9) | Events emitted during P1-P7 | P9 flush with `tick_index` | The bus owns the record; this system owns when the flush happens and the tick stamp |
| Combat Space (#11), Weapons & Damage (#12), Vigor (#13), Coherence & Links (#14) | Phase handlers for P3-P6; trigger thresholds | Their phases are called in fixed order | Each owns its rules and thresholds; this system owns the phase order and the pause side of triggers |
| Fleet Orders (#19), Ship AI (#20), Fleet Coordination (#21) | Orders into the queue; P2 decisions | Drained orders in P1; the replay log | Fleet Orders owns what an order means; this system owns when it applies |
| Battle Resolution & Retreat (#22) | P7 end-of-battle and escort-lost signals | Context end, which clears player and auto holds | Battle Resolution owns outcomes |
| AI-vs-AI Runner (#25) | `step(n)` calls | Final state, the per-tick state hash, the event log | The runner owns pacing; this system owns determinism |
| Planning screens: Dossier (#47), Public History / Case File (#49), Ledger (#48), Debrief (#24) | Add and remove `PLANNING:<screen_id>` | — | Each screen owns its own reason key |
| Camera & Combat View (#45) and all presentation | — | Interpolation alpha; read-only state | Presentation owns drawing. **Presentation decides, per effect, whether it freezes while held**: combat VFX, tweens and animation freeze; UI keeps running. The engine does not pause them automatically under this design |

**What the player cannot do:**
- change the tick rate, or what a tick does
- use speed to change an outcome
- make an order act mid-tick or skip the queue
- resume while a planning screen or system hold is open
- resume an auto-pause by "fixing" its condition
- single-step during a planning hold
- rewind or undo ticks (replay is a tool, not a player feature)

**The player's decisions:**
- when to pause or step
- which speed to run at
- whether to issue an order now (it applies next tick) or step first to see an
  effect
- which auto-pause triggers to enable
- when to open a planning screen, knowing that doing so mid-battle costs no game
  time (*Pillar 3*: "pause is always available")

*Specialists consulted:*
- `systems-designer` (primary: rules, phase order, hold set)
- `gameplay-programmer` (input latency, latching, interpolation, auto-pause spam
  limits)
- `engine-programmer` (single driver, headless `step()`, determinism hazards,
  save boundary)

*Owner decisions:*
- 60 Hz, gated by a spike
- this system owns the hold set
- 0.5/1/2× speeds, with player single-step behind an option
- default-on auto-pause for flagship hull critical and first contact

## Formulas

All tick-count quantities are integers. Every quantity that a player or designer
tunes is stored in seconds, or as a multiplier, and converted to ticks at load.
That way the tuning survives a `TICK_RATE` change. The accumulator is a float,
but it only decides **how many** ticks run, never **what** a tick does, so it
cannot break determinism.

### D1. Tick length

The dt_tick formula is defined as:

`dt_tick = 1 / TICK_RATE`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| TICK_RATE | int | {30, 60} (target 60) | constant (engineering, versioned) | Ticks per second of simulation time |
| dt_tick | float (s) | 1/60 – 1/30 | calculated | Simulation time one tick covers |

**Output Range:** 0.01667 s at 60 Hz, or 0.03333 s on the 30 Hz fallback. It is
fixed for a build and never changes at runtime.
**Example:** at 60 Hz, `dt_tick = 1/60 = 0.016667 s` (16.67 ms).

### D2. Accumulator update (once per rendered frame, driver only)

The accumulator_update formula is defined as:

`d = clamp_low(frame_delta, 0)`
`acc_next = held ? acc : ((resumed_this_frame OR d > SLEEP_THRESHOLD_S) ? 0 : acc + d × speed_scale)`

A frame longer than `SLEEP_THRESHOLD_S` (sleep, a debugger break, a long
stall) feeds no time. In `BATTLE`, it also adds `PLAYER_PAUSE`.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| acc | float (s) | 0 to < dt_tick between frames | calculated | Simulation time owed but not yet ticked |
| frame_delta | float (s) | any; values below 0 are treated as 0 | calculated (engine frame time, read only by the driver) | Real time since the last frame |
| SLEEP_THRESHOLD_S | float (s) | 0.25 – 5 (1.0) | data file (tuning knob) | Frame length above which the frame is treated as an interruption, not a hitch |
| speed_scale | float | {0.5, 1, 2}; 4 in dev builds | data file (tuning knob) | Selected speed |
| held | bool | — | calculated | The hold-reason set is not empty |
| resumed_this_frame | bool | — | calculated | The hold set became empty this frame |

**Output Range:** 0 upwards before D3 runs; D3 brings it back below `dt_tick`.
- While held, `acc` is frozen.
- On the frame play resumes, `acc` resets to 0. Resuming from focus loss (rule
  16) is one such case, and so is every other resume. **Time spent held is never
  caught up.**

**Example:** 60 fps at 2×, with `acc = 0.004`, gives
`acc = 0.004 + 0.016667 × 2 = 0.037333 s`.

### D3. Ticks this frame, and the discarded remainder

The ticks_this_frame formula is defined as:

`n = min(floor(acc / dt_tick), MAX_TICKS_PER_FRAME)`
`acc_after = acc − n × dt_tick`
`discarded_sim_s = (acc_after ≥ dt_tick) ? acc_after − fmod(acc_after, dt_tick) : 0`
`acc_final = acc_after − discarded_sim_s`
`discarded_real_s = discarded_sim_s / speed_scale`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| MAX_TICKS_PER_FRAME | int | 4 – 12; **8** at 60 Hz, **4** at 30 Hz | constant (engineering) | Catch-up cap. Both values cap catch-up at about 133 ms of simulation time per frame |
| n | int | 0 – cap | calculated | Ticks the driver runs this frame |
| discarded_sim_s | float (s) | ≥ 0 | calculated | Whole ticks of simulation time dropped. Logged outside the Battle Record |
| acc_final | float (s) | 0 to < dt_tick | calculated | Fraction of a tick kept for interpolation |

**Output Range:** `n` is 0 to 8. Ticks are discarded only when the cap binds. The
fractional remainder is always kept, so interpolation stays smooth through a
hitch.
**Example:** a 250 ms hitch at 1×, with `acc = 0.004`, gives `acc = 0.254`, and
`floor(0.254 / 0.016667) = 15`, so `n = 8`. That leaves
`acc_after = 0.12067`, which is 7.24 ticks. The 7 whole ticks are discarded
(0.11667 s), and `acc_final = 0.004`.

### D4. Interpolation alpha

The interpolation_alpha formula is defined as:

`alpha = (held OR no_tick_since_resume) ? 1 : acc_final / dt_tick`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| alpha | float | [0, 1] | calculated | Presentation's blend from the previous tick's state to the current one |
| no_tick_since_resume | bool | — | calculated | Play has resumed but no tick has run yet |

**Output Range:** [0, 1) while running, and **exactly 1 while held**.
- While paused, the screen shows the true current tick, so what the player sees
  agrees with inspection and tooltips. *Pause stops everything exactly where it
  is.*
- The cost is a forward snap of at most one tick of motion at the instant of
  pausing.
- Because D2 resets `acc` on resume, alpha restarts from 0 on the next tick. The
  view never jumps backward.

**Example:** `acc_final = 0.004` gives `alpha = 0.24`. Pausing at that moment
snaps alpha to 1.

### D5. Effective speed, and the speed shown

The effective_speed formula is defined as:

`speed_limit = MAX_TICKS_PER_FRAME × fps / TICK_RATE`
`speed_eff = min(speed_scale, speed_limit)`
`speed_shown = ticks_in_window / (TICK_RATE × SPEED_WINDOW_S)`

The UI shows `speed_scale` unless
`speed_shown < speed_scale × (1 − SPEED_TOLERANCE)`. In that case it shows
`speed_shown`, rounded down to 0.1 and marked "slowed".

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| fps | float | 1 upward (no maximum is enforced) | calculated | Measured frame rate |
| ticks_in_window | int | ≥ 0 | calculated | Ticks run in the last `SPEED_WINDOW_S` of real time |
| SPEED_WINDOW_S | float (s) | 0.5 – 2 (1.0) | data file (tuning knob) | Measurement window |
| SPEED_TOLERANCE | float | 0.02 – 0.10 (0.05) | data file (tuning knob) | How far below the selected speed before the UI says "slowed" |

**Output Range:** 0 up to `speed_scale`. While held, the UI shows "Paused" rather
than a number.
**Example:** 2× selected and the frame rate drops to 12 fps:
`speed_limit = 8 × 12 / 60 = 1.6`, so the UI shows "1.6× (slowed)".

### D6. Sustainable speed check

The ticks_per_frame_needed formula is defined as:

`tpf = TICK_RATE × speed_scale / fps`

A speed is sustainable when it passes two checks:
- **Cap check:** `tpf ≤ MAX_TICKS_PER_FRAME`
- **CPU check:** `ceil(tpf) × t_tick_ms ≤ SIM_BUDGET_MS` (see D10)

**Variables:** `TICK_RATE`, `speed_scale` and `fps` as above. `tpf` is a float,
calculated.
**Output Range:** 0.10 to 8 across the table below. A value above the cap means
D3 discards time.
**Example:** ticks needed per frame, with the cap at 8 (at 60 Hz) or 4 (at 30 Hz):

| Rate / speed | 30 fps | 60 fps | 144 fps |
|---|---|---|---|
| 60 Hz 0.5× | 1 | 0.5 | 0.21 |
| 60 Hz 1× | 2 | 1 | 0.42 |
| 60 Hz 2× | 4 | 2 | 0.83 |
| 60 Hz 4× (dev) | **8 (at cap)** | 4 | 1.67 |
| 30 Hz 0.5× / 1× / 2× / 4× | 0.5 / 1 / 2 / 4 | 0.25 / 0.5 / 1 / 2 | 0.10 / 0.21 / 0.42 / 0.83 |

Every player speed passes the cap check at 30 fps and above.

### D7. Auto-pause cooldown and re-arm

The trigger_fire formula is defined as:

`cooldown_ticks = ceil(cooldown_s × TICK_RATE)`
`rearm_ticks = ceil(rearm_s × TICK_RATE)`
`fires(t) = enabled AND armed AND condition(t) AND (t − last_fire_tick ≥ cooldown_ticks)`

A trigger becomes **armed** once its condition has been false for `rearm_ticks`
consecutive ticks. A condition that is still true when its cooldown expires
**fires then, late**, rather than being dropped.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| cooldown_s | float (simulation s) | 0 – 60 (10) | data file (tuning knob, per trigger) | Minimum simulation time between fires |
| rearm_s | float (simulation s) | 0 – 10 (2) | data file (tuning knob, per trigger) | How long the condition must stay clear before the trigger re-arms |
| enabled | bool | — | data file (Gameplay Settings) | The player's per-trigger toggle |
| last_fire_tick | int | ≥ 0 | calculated | Tick of the last fire |

**Output Range:** 600 cooldown ticks and 120 re-arm ticks at 60 Hz (300 and 60 at
30 Hz).
- Cooldowns are simulation time, so at 2× a 10 s cooldown passes in 5 s of real
  time.
- *First enemy contact* has no cooldown. It fires once per enemy fleet per
  battle.

**Example:** *Flagship hull critical* fires at tick 12,000. The hull recovers
above the threshold at 12,050 and stays there, so the trigger re-arms at 12,170.
The hull drops below again at 12,300, which is still inside the cooldown
(300 < 600). The trigger waits, and fires at 12,600 if the hull is still below
the threshold.

### D8. tick_index range and integer safety

The tick_index_bound formula is defined as:

`hours_to_limit = LIMIT / (TICK_RATE × 3600)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| tick_index | int (64-bit) | 0 – 2^53 − 1 | calculated | Ticks since the simulation session started |
| LIMIT | int | 2^53, 2^31, 2^24 | constant | Largest integer each kind of consumer holds exactly |

**Output Range** (at 60 Hz, 216,000 ticks per hour):
- **2^53** (doubles, so it survives a JSON float parse exactly): about
  4.17 × 10^10 hours. This is a hard assert on save.
- **2^31** (any 32-bit consumer): 9,942 hours, which is 414 days of continuous
  simulation. This is a warning threshold. **Storing `tick_index` in 32 bits is
  banned.**
- **2^24** (a float32 value such as shader time, `tick_index × dt_tick`):
  **77.7 hours**. Presentation must pass time *modulo a period*, never the raw
  value.

**Example:** a 200-hour campaign at 1× is 43.2 million ticks, about 2.0% of 2^31.

### D9. Single-step

The step formula is defined as:

`sim_s_advanced = n_step × dt_tick`, with `n_step ∈ {STEP_SMALL, STEP_LARGE}`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| STEP_SMALL | int | 1 | constant | The fine step |
| STEP_LARGE | int | 2 – 30 (10) | data file (tuning knob) | The coarse step, in ticks, as the owner decided |

**Output Range:** 16.7 ms or 166.7 ms of simulation time at 60 Hz (33.3 or
333 ms at 30 Hz).
**Example:** 10 ticks at 4 ms each is 40 ms of compute, about a two-frame hitch
while paused. The driver may instead spread them at up to 8 per frame. The result
is identical either way.

### D10. Simulation time budget per frame (the spike's pass line)

The sim_frame_cost formula is defined as:

`sim_ms = ceil(tpf) × t_tick_ms ≤ SIM_BUDGET_MS`

This gives the spike's pass line:

`t_tick_ms ≤ SIM_BUDGET_MS / ceil(TICK_RATE × max_player_speed / target_fps)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| SIM_BUDGET_MS | float (ms) | 5 – 10 (**8, provisional**) | constant (engineering; needs technical-director sign-off) | The simulation's share of a 16.67 ms frame |
| t_tick_ms | float (ms) | measured | calculated | 95th-percentile cost of one tick, headless, with about 100 ships and 500 projectiles |
| max_player_speed | float | 2 | constant | Highest player-selectable speed |
| target_fps | int | 60 | constant | Frame-rate target |

**Output Range:** at 60 Hz, 2× and 60 fps the simulation needs 2 ticks per
frame, so **each tick must cost ≤ 4.0 ms**. On the 30 Hz fallback it needs 1
tick per frame, so a tick may cost ≤ 8.0 ms. That doubled headroom is what the
fallback buys.
**Example:** the spike measures `t_tick = 3.2 ms`. `2 × 3.2 = 6.4 ≤ 8`, so 60 Hz
passes. If it measures 5.1 ms, 60 Hz fails, and the fallback holds because
`5.1 ≤ 8`.

*Specialist consulted: `systems-designer`. Decisions taken in guided mode, all
on the specialist's recommendation:*
- *Alpha is 1 while held.*
- *A condition still true after its cooldown fires late.*
- *`STEP_LARGE` stays in ticks.*
- *`SIM_BUDGET_MS = 8` is provisional until the technical-director signs it off
  (Open Questions).*

## Edge Cases

### Holds and resume

- **If pause is pressed and released, or toggled twice, within one frame**: the
  driver reads the hold set once per frame, just before D2. Changes that cancel
  out within a frame have no effect: the accumulator is not reset, alpha does
  not snap, and no tick is affected. Pause acts on the press; the release does
  nothing.
- **If `PLAYER_PAUSE`, `PLANNING:case_file` and `SYSTEM:focus_lost` are stacked
  and then removed in any order**: each reason is removed only by its own cause,
  and ticks resume on the frame the last one goes. For example, if focus returns
  and then the Case File closes, the game is still Paused (player) and the
  player resumes it.
- **If the player presses resume while any `SYSTEM` or `PLANNING` reason is
  present**: the press is rejected, the set is unchanged, and the press is **not
  remembered**. The resume control names the hold (for example "Saving…"). A
  remembered press would unpause later, at a moment the player did not choose.
- **If the window loses focus, or the menu opens, during `BATTLE`**:
  `PLAYER_PAUSE` is added alongside the `SYSTEM` reason (rule 16). The battle
  never restarts while the player's hand is off the mouse. In `CAMPAIGN`, only
  the `SYSTEM` reason is added.

### Orders and input

- **If an order's subject ship is destroyed before P1 applies the order** (the
  UI was showing a state one tick old): P1 drops the order, emits
  `OrderRejected(order_id, reason = subject_lost)` to the Event Bus, and logs the
  drop. A replay reruns the same check and gets the same result. If the order's
  *target* is gone instead, Fleet Orders (#19) decides what happens.
- **If an order is edited or cancelled on the same frame its tick runs**: input
  is processed before the driver every frame, so the edit lands before P1 reads
  the queue. Once P1 has drained an order it is history, and a later edit
  becomes a new order for the next tick. Moving the simulation off the main
  thread must preserve this ordering (Tick/Pause/Determinism ADR).
- **If two orders for the same ship apply on one tick**: both apply and both are
  logged, ordered by a monotonic enqueue sequence number, never by timestamp.
  Where they conflict, the later order wins. Whether an order replaces or
  appends (queued waypoints) belongs to Fleet Orders (#19).
- **If an ability press and its release both land between two ticks**: the latch
  keeps the press, so the next P1 sees exactly one press. Several presses of the
  same ability between ticks count as one. Different abilities apply in a fixed
  bit order. Fire bits use *held OR pressed-since-last-tick*, so a tap shorter
  than one tick (16.7 ms) still fires for one tick.
- **If an ability is pressed while the game is held**: the latch is **kept**. It
  is shown as a queued action, can be cancelled, and is consumed by the first
  tick after resume or step.

### Stepping

- **If a 10-tick step reaches a battle-ending tick at tick k of 10**: the step
  stops after tick k, and the remaining ticks never run. The context ends, which
  clears player and auto reasons, and the Debrief `PLANNING` hold applies.
- **If an auto-pause trigger fires during a step**: the step stops after that
  tick, so the player sees the moment the trigger fired.
- **If a `SYSTEM` reason arrives mid-step** (autosave, quit): the current tick
  finishes, because ticks are atomic, and the rest of the step is cancelled.
  Stepping is unavailable under `SYSTEM`.

### Auto-pause

- **If a trigger fires on the tick the battle ends**: within P7, the battle-end
  check runs before trigger evaluation. Triggers are still evaluated and logged,
  but they add no hold, so a hull-critical pause never lands on top of the
  Debrief.
- **If several triggers fire on one tick while another is in cooldown**: the
  eligible triggers combine into one pause that lists every reason, and the one
  in cooldown is not listed. It fires late, at the first tick where
  `t − last_fire_tick ≥ cooldown_ticks`, if it is still armed and its condition
  is still true (D7). Cooldowns do not elapse while held, because they count
  ticks.
- **If two enemy fleets are first contacted on the same tick**: one pause names
  both, and each fleet's once-per-battle flag is used up. Fleets are keyed by
  Runtime ID. What counts as "contact", and how a fleet that splits is treated,
  belongs to Combat Space (#11).
- **If a trigger's condition is already true when the battle starts, or when the
  player enables the trigger mid-battle**: the trigger starts **unarmed**. It
  must see the condition clear for `rearm_ticks` before it can fire, because the
  player already knows about a condition that existed before they could act.
  Disabling a trigger never removes a hold that already exists.

### Catch-up, speed and frame time

- **If the speed changes while catch-up is under way**: the new speed applies
  from the frame in which the change is processed. Simulation time already owed
  in `acc` is not rescaled. Only cadence changes, so outcomes are unaffected.
- **If `frame_delta` is 0 or negative**: it is treated as 0. No ticks run, and
  alpha is unchanged.
- **If `frame_delta > SLEEP_THRESHOLD_S`** (sleep, a debugger break, a long
  stall): the frame feeds no time (D2). In `BATTLE`, `PLAYER_PAUSE` is added.
  Waking from sleep never jumps the battle forward while the player was away.
- **If the frame rate is above 240 fps** (no frame cap): many frames run 0
  ticks, and alpha carries the motion. The speed display counts ticks, so it
  stays correct. This system enforces no minimum or maximum frame rate.
- **If float jitter in the accumulator makes a 60 fps, 1× frame run 0 or 2
  ticks**: this is accepted, because it affects cadence only, never outcomes.
  An integer-microsecond accumulator is an option for the ADR.

### Saves, replay and determinism

- **If a save is requested while a tick is running**: the save waits for the
  tick boundary, and never captures a state in the middle of a tick (rule 17).
- **If a save or replay has a different `TICK_RATE`**: a mid-battle save is
  refused for that battle. The player is offered the battle's pre-battle state
  instead, which is campaign state kept in World Clock days and does not depend
  on the tick rate. A mismatched replay is refused. These checks belong to
  Save/Load (#5) and the AI-vs-AI Runner (#25).
- **If a save or replay has a different build ID**: a save warns, then goes
  through migration (Save/Load #5). A replay plays as **"unverified"**, and the
  Debrief must not treat it as proof.
- **If the replay log is missing an entry**:
  - A flagship command absent from the log means "unchanged", which is valid.
  - A gap in the order sequence numbers, or a mismatch with the per-tick state
    hash, stops the replay at the last verified tick and reports "diverged at
    tick T".
  - Nothing is ever filled in.
- **If `tick_index` passes 2^31 − 216,000** (one hour of ticks before the 32-bit
  limit): a warning is logged. Gameplay is unaffected, because the counter is
  64-bit. At 2^53, the save asserts (D8). Presentation never passes the raw
  tick count to float32 shader inputs.

### Headless

- **If a headless run meets an auto-pause condition**: the trigger runs its full
  cooldown and re-arm logic and logs `TriggerWouldFire(tick, trigger_id)`, but
  adds no hold. Trigger bookkeeping never feeds back into ship state, so headless
  and player runs stay identical tick for tick.

### Context changes

- **If `BATTLE` ends with orders still queued or a press latched**: unapplied
  orders are discarded and logged as `cancelled_by_context_end`, and latches are
  cleared. Orders never cross into a new context.
- **If the Debrief's `PLANNING` hold is still present when `CAMPAIGN` starts**:
  no campaign ticks run, and the World Clock does not advance, until the Debrief
  closes. Battle Resolution (#22) and the Debrief (#24) must add the hold on the
  frame the context ends, before the next driver pass, so not a single campaign
  tick slips through.

*Specialist consulted: `systems-designer`. Decisions taken in guided mode:*
- *keep a press latched while held*
- *a trigger already true starts unarmed*
- *add `SLEEP_THRESHOLD_S` (D2 amended)*
- *`tick_index` is campaign-monotonic (rule 1 amended)*

*Whether a battle starts paused is left to Open Questions.*

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## Game Feel

[To be designed]

## UI Requirements

[To be designed]

## Cross-References

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
