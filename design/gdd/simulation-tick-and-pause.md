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
   - A tick is one atomic, equal-size step, indexed by an integer `tick_index`
     that starts at 0 for each simulation session.
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
    This is a player option. On resume, the first frame's time is clamped, so
    unfocused time is never caught up.
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

[To be designed]

## Edge Cases

[To be designed]

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
