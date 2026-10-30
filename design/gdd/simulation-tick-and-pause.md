# Simulation Tick & Pause

> **Status**: In Design
> **Author**: owner + agents
> **Last Updated**: 2026-10-28
> **Last Verified**: 2026-10-28
> **Implements Pillar**: Pillar 3 (Hands on the Helm — "pause is always available"); Pillar 1 (Every Defeat Is a Lead — deterministic replay behind a trustworthy Debrief)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-28 — CONCERNS resolved. In battle, planning screens add a player pause; a default-on Battle-start auto-pause was added; rule 18 ("pause is never a crutch") was added; "Tactical step" naming; Settings owns difficulty presets; the 10-tick step is first to cut

## Summary

Simulation Tick & Pause is the fixed 60 Hz (spike-gated) deterministic step that
advances all simulation state, and the pause that freezes it while the screen
and every planning tool stay live. For the player, it means stopping a battle
mid-shot to read and order, with no penalty, and trusting that the battle the
Debrief explains is the battle that happened. It exists because the same seed
and the same orders must replay the same fight, which the headless AI-vs-AI
runner and every system with real-time rules depend on.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None` (upstream); depended on by World Clock, Combat Event Bus & Battle Record, Combat Space, Fleet Orders, AI-vs-AI Runner, and every phase-handler system

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
  specific, actionable cause and counter for this loss?" The Debrief reads its
  causes from the Battle Record, the per-tick log of what actually happened.
  Deterministic replay is how the tests prove that record is right (the
  headless runner replays every scripted loss); an unverified replay never
  changes what the record shows.

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
   - Combat uses no engine physics: no `PhysicsServer2D` bodies, `Area2D` or
     `CharacterBody2D`. They would keep simulating while the simulation is
     held. Combat Space (#11) resolves movement and hits in plain data.
3. **One tick, one fixed phase order.** Every tick runs these phases in this
   order. The order is fixed in code, never data-driven.

   | Phase | What runs |
   |---|---|
   | P0 | Tick begins (hold check already passed) |
   | P1 | Apply queued player orders, in enqueue order, plus the flagship's current command (rule 6) |
   | P2 | AI decisions (Fleet Coordination first, writing goals and focus into Fleet Orders' slots; then Ship AI), written directly into `SimState` |
   | P3 | Movement (Combat Space integrates positions) |
   | P4 | Weapons fire; projectiles advance |
   | P5 | Hit resolution and damage |
   | P6 | Vigor update, then Coherence and link update |
   | P7 | Resolution checks, in order: destruction (with the Coherence & Links **destruction hook**, which snaps the dead ship's links that tick), retreat, battle end (all Battle Resolution #22, rule 14), then **auto-pause trigger evaluation** |
   | P8 | World Clock advance |
   | P9 | Event flush to the Combat Event Bus & Battle Record, stamped with `tick_index`; tick ends |

   *Why this order:*
   - Orders come first, so an order given while paused takes effect on the very
     next tick.
   - AI reads the previous tick's settled **world** state: positions, damage,
     Vigor and links as they stood after the last P9. Every actor's decisions are
     therefore equally one tick stale, which is fair and deterministic. P2 **does**
     see the orders P1 applied this tick, so an escort's AI acts on a fresh order
     immediately.
   - **AI decisions are not orders.** P2 writes each AI intent (heading, target,
     posture) directly into `SimState`, and P3 onward act on it in the same
     tick. AI intents never pass through the order queue and are never written
     to the replay log: a replay regenerates them, because they are a
     deterministic function of state and seed streams.
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
5. **Player orders cross into the simulation only through the order queue.**
   - The queue holds **player commands only**. AI decisions never enter it
     (rule 3).
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
   - **Flagship Piloting (#15) owns what the command does**: the P1 handler
     that applies it, and what move, aim, fire and ability bits mean. This
     system owns when it is sampled, latching, and recording. Input & Controls
     (#6) owns the bindings.
   - Input is sampled every rendered frame. The simulation reads the flagship's
     current command once per tick, in P1. **The value a tick reads is the
     sample from the latest rendered frame before the driver pass that runs
     that tick.** Every tick run in one driver pass reads the same sample.
   - The command is a small struct: move axis, aim, fire bits and ability bits.
   - **Aim is recorded relative to the flagship.** The cursor is converted to
     world space with the camera transform of the frame it was sampled on.
     The flagship's position in the last settled tick is then subtracted. The
     resulting offset is quantized per axis to `AIM_QUANTUM` (1/16 of a world
     unit; Combat Space #11 defines the world unit) before it is recorded. It
     is never stored as a screen position. A replay therefore never depends on
     the camera, and a still cursor under a follow camera gives a constant aim.
     The reticle and any aim preview are drawn from the unquantized point.
   - Held inputs (thrust, fire) are level-triggered.
   - A press that lands between ticks (an ability) is **latched** until the next
     tick consumes it, so no press is lost.
   - The command is recorded to the replay log when it changes. The replay log
     is **per battle**: it starts at `battle_start_tick` and closes when the
     battle context ends. Its encoding and size budget belong to Combat Event
     Bus & Battle Record (#9) and Save/Load (#5).
   - **Precedence.** For movement, aim and fire, the live command always
     governs the flagship. A queued order addressed to the flagship applies
     only to what the command does not cover. Fleet Orders (#19) and Flagship
     Piloting (#15) define that set.
   - **No flagship.** If the flagship is destroyed or absent, P1 ignores the
     command, the command is not recorded, and latched presses are cleared.
7. **Real time enters at exactly one boundary.**
   - In the player's build, one driver feeds frame time into an **integer**
     accumulator (D2). This happens only while the hold set is empty.
   - The driver runs whole ticks while the accumulator holds at least one tick,
     up to `MAX_TICKS_PER_FRAME` per frame and within the wall-time cap
     (rule 8).
   - The remainder gives presentation its interpolation alpha.
   - This driver is the documented, single place where wall-clock time touches
     the simulation. Nothing inside `SimState` reads it.
   - **The driver's frame:**
     - It is an autoload node with `PROCESS_MODE_ALWAYS`, outside every subtree
       that is frozen while held.
     - `frame_delta` is the `delta` of that node's own `_process`.
       `Engine.time_scale` stays 1 and is banned (AC-34), so speed is never
       applied twice.
     - Each frame starts with one explicit `begin_frame()` call. It snapshots
       the input sample, applies queue edits, and reads the hold set, in that
       order, before any tick runs. The order never relies on the engine's
       callback order between nodes.
8. **Catch-up is capped; excess time is discarded.**
   - If a frame would need more than `MAX_TICKS_PER_FRAME` ticks (a hitch, a long
     load, a slow machine at high speed), the extra real time is dropped, not
     banked. The game visibly slows instead of stalling ("spiral of death").
   - **Wall-time cap.** The driver starts no new tick in a frame once the wall
     time it has spent ticking that frame reaches `SIM_BUDGET_MS`. Owed whole
     ticks beyond that are discarded exactly as the tick cap discards them
     (D3), so expensive ticks slow the game visibly and the speed display says
     "slowed" (D5). The simulation never starves rendering. The driver may read
     a monotonic clock for this: it is the one place that does (this rule).
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
      - `PLANNING:<screen_id>` (Dossier, Ledger, Case File, Debrief, every port
        service screen — market, refit, care, contract board — the sector
        map's route planner, and an open encounter offer,
        `PLANNING:encounter_offer`; `PLANNING:dossier` (Dossier #47); `PLANNING:public_history` (Public History Screen #49, Vertical Slice; at Tier 0 its tab sits inside `PLANNING:case_file`); `PLANNING:prebattle` (the pre-battle panel, added before tick 0 of every battle, Combat HUD #46); the port screens are `PLANNING:port_hub`,
        `port_rest`, `port_care`, `port_fleet`, `port_refit`, `port_market`
        and `port_roster` (Ports, Rest & Care; Port & Fleet Management
        Screens #50); World Clock rule 3, Sector Map & Travel)
      - `SYSTEM:<cause>` (menu, loading, save in progress, window focus lost)
    - **In `BATTLE`, opening any planning screen also adds `PLAYER_PAUSE`**, as
      opening the menu or losing focus does (rule 16). Closing the screen
      therefore never restarts a fight on its own: *nothing moves until the
      player chooses*. The Debrief is the exception: its hold is added as the
      battle context ends, so no `PLAYER_PAUSE` is added, because there is no
      battle left to resume.
    - **In `BATTLE`, planning screens are read-only.** The player may read
      weaknesses, counters, prices and evidence. Nothing that changes an
      outcome can be committed until the battle ends: no spending, no loadout
      change, no sharing, no deduction commit. Pause lets the player look;
      planning happens between battles (concept pillar tensions). Each screen's
      GDD enforces this, and this system reports the context (`BATTLE` or
      `CAMPAIGN`) for it to check.
    - **Exposed as an ordered list.** `holds()` returns every active reason
      with its class (`SYSTEM`, `PLANNING`, `AUTO`, `PLAYER`), sorted by
      class precedence **SYSTEM > PLANNING > AUTO > PLAYER**, then by the order
      the reasons were added. `is_held()` is true when the list is non-empty.
      The HUD shows the first entry as the primary cause (States and
      Transitions).
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
    - Each trigger can be toggled, and **re-arms only after its condition has
      cleared**. Firing disarms it, so a trigger never fires twice for one
      crossing. Informational triggers also have a cooldown, measured in
      **simulation ticks**. A trigger **never fires late**: a crossing that
      cannot fire when it happens is dropped, not deferred (D7).
    - MVP triggers (class and per-trigger defaults: D7):

      | Trigger | Class | Default | Threshold owned by |
      |---|---|---|---|
      | **Battle start**: adds `AUTO_PAUSE:battle_start` when a `BATTLE` context begins, before its first tick runs | Context | **ON** | This system |
      | Flagship hull critical | Safety | **ON** | Hulls / Weapons & Damage |
      | First enemy contact (once per enemy fleet per battle) | Per-fleet latch | **ON** | Combat Space |
      | Vigor early warning | Safety | Off | Vigor |
      | Relay cut | Informational | Off | Coherence & Links |
      | Escort lost | Informational | Off | Battle Resolution |

      Few triggers are on by default, so the game stays relaxing rather than
      interrupting.
    - **Battle start** is the "bridge holds its breath" moment: every battle
      opens held, so the player can read the field before acting. Because it is
      added at context start rather than evaluated in P7, it has no cooldown and
      is not affected by the start-unarmed rule (Edge Cases). Headless runs log
      it instead of holding.
    - Difficulty and assist **presets** that turn on more triggers, or set a
      slower default speed, belong to Gameplay Settings & Modifiers (#7). This
      system only exposes the toggles.
12. **Single-step.**
    - While the simulation is held only by `PLAYER_PAUSE` and/or `AUTO_PAUSE`
      reasons, a step command runs **exactly 1 or 10 normal ticks**, including
      P1 orders, and then holds again.
    - Stepping is unavailable while any `PLANNING` or `SYSTEM` reason is present.
    - Players get it as **"Tactical step"**, an ordinary tactical setting, off by
      default. It is never labelled or grouped as a debug, cheat or assist
      option. Dev builds and the headless runner always have it, because it is
      the same `step()` the runner calls.
    - The 1-tick step is the core of the feature. The 10-tick step, and its
      `STEP_LARGE` knob, are the **first thing to cut** if scope shrinks.
13. **Tick rate is a versioned engineering constant.**
    - `TICK_RATE` targets 60 Hz. 30 Hz adds about 33 ms of flagship input
      latency (one more tick of waiting for the boundary, and one more of
      interpolation lag, 16.7 ms each) and doubles the distance a projectile
      moves per tick.
    - The 60 Hz target is gated by a headless spike: 100 ships and 500
      projectiles must pass the D10 gate. **If the spike fails, the fallback is
      30 Hz**, and the fallback **requires presentation-side flagship
      prediction** (Game Feel) so piloting stays inside the latency target.
    - Changing `TICK_RATE` breaks replay compatibility, so it is written into
      every replay and save header. It is not a player setting.
14. **Determinism.**
    - **Same seed, same starting state and same recorded commands give the same
      sequence of states, tick for tick.** This holds on the same build and
      platform, which is the guarantee this game makes.
    - **Platform scope (MVP): verification is same-platform only.** Floating-point
      results can differ across OS and CPU (libm, FMA). A save loads on any
      platform, because it is a complete state. A replay, or a replay check,
      from a different OS or CPU architecture is **"not re-verified"**: the label
      shows in debug views and the AI-vs-AI Runner only, with no player-facing
      badge (Battle Record rule 15), and the Debrief reads the Battle Record,
      never the replay, as its evidence (Edge Cases). A cross-platform hash test is post-MVP (Open Questions).
    - Every replay and save records the engine version, build ID, OS, CPU
      architecture, `TICK_RATE` and a content hash. A mismatch is refused, or
      warned about where Save/Load allows it.
    - **`state_hash`** is a fixed 64-bit non-cryptographic hash over a canonical
      byte serialization of `SimState`. The algorithm is named in the
      Tick/Pause/Determinism ADR. It is never the engine's `hash()`, an Object or
      Callable hash, or an instance ID, because those are not stable across
      versions. The serialization covers:
      - entities in ascending Runtime ID, fields in declared order;
      - floats as their IEEE-754 bit patterns;
      - RNG stream states, the order queue, latches and trigger states;
      - `tick_index`.

      It excludes the hold set and the accumulator, which are cadence rather
      than state, so headless and player runs hash alike.
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
18. **Pause is never a crutch.** Hold, speed, step and auto-pause usage never
    feeds a score, rating, achievement, Debrief grade, difficulty label or any
    other judgement of the player. The data may be logged for telemetry, but is
    never shown back as a verdict (Player Fantasy: "nothing penalises, scores
    against or shames using pause"). *(Numbered 18 though listed last: other
    sections cite it by number.)*

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

**Shown state.** Several rows can match at once (in `BATTLE`, a planning screen
holds both `PLANNING` and `PLAYER_PAUSE`). The state shown to the player, and
named by the resume control, is the highest match in **SYSTEM > PLANNING >
AUTO > PLAYER** precedence: Held (system), then Held (planning), then Paused
(auto), then Paused (player). Stepping and Headless are modes, not hold states.
This is the order `holds()` returns (rule 10).

**Stacking rules:**
- Each reason is a unique key. Adding a reason that is already present changes
  nothing.
- **Resume** removes only `PLAYER_PAUSE` and `AUTO_PAUSE:*` reasons. It is
  unavailable while any `PLANNING` or `SYSTEM` reason remains, and the resume
  control says why.
- A screen closing removes **only its own** `PLANNING` reason. In `BATTLE`,
  opening the screen also added `PLAYER_PAUSE` (rule 10), so closing the Case
  File never resumes a battle, whether or not the player had paused first. They
  return to
  Paused.
- Speed changes and steps never change the set.
- Ending a simulation context (battle over) clears `PLAYER_PAUSE` and
  `AUTO_PAUSE` reasons. `PLANNING` and `SYSTEM` reasons persist across contexts.
  The Debrief that opens after a battle is a `PLANNING` hold.
- **Battle end is one atomic step**, taken after the battle-ending tick's P9 and
  before the next driver pass: the `PLAYER_PAUSE` and `AUTO_PAUSE` reasons
  are cleared, `PLANNING:debrief` is added, and the context switches to
  `CAMPAIGN`. The set is never empty in between.

### Interactions with Other Systems

| System | Flows into this system | Flows out of this system | Interface owner |
|---|---|---|---|
| Deterministic RNG & Seed Streams (#2) | — | `tick_index` (for stream bookkeeping) | RNG owns streams and their state; this system never draws randomness itself |
| Runtime ID Service (#3) | Stable IDs used for processing order | — | ID Service owns IDs; this system owns "ascending ID within a phase" |
| Save/Load & Migration (#5) | State restored at a tick boundary | `tick_index`, the queue, the replay log, header fields (`TICK_RATE`, build ID) | Save owns the format and integer-safe encoding |
| Input & Controls (#6) | The flagship command each frame; pause, resume, step and speed inputs | — | Input owns bindings; this system owns latching and when the command is read |
| Gameplay Settings & Modifiers (#7) | Speed steps, the single-step option, auto-pause toggles and cooldowns, focus-loss option | — | Settings owns values; this system reads them **between ticks only** |
| World Clock (#8) | — | P8 call; `is_held()` | **This system owns the hold-reason set**; World Clock owns day maths and reads `is_held()` |
| Combat Event Bus & Battle Record (#9) | Events emitted during P1-P8 (amended 2026-10-30: P8 covers World Clock and the end-of-tick spawn/retire step) | P9 flush with `tick_index` | The bus owns the record; this system owns when the flush happens and the tick stamp |
| Combat Space (#11), Weapons & Damage (#12), Vigor (#13), Coherence & Links (#14) | Phase handlers for P3-P6; trigger thresholds | Their phases are called in fixed order | Each owns its rules and thresholds; this system owns the phase order and the pause side of triggers |
| Flagship Piloting (#15) | The P1 handler that applies the flagship command | The sampled, latched command once per tick (rule 6) | Piloting owns what the command does; this system owns sampling, latching, recording and the precedence over queued orders |
| Fleet Orders (#19) | Player orders into the queue | Drained orders in P1; the replay log; `OrderRejected` | Fleet Orders owns what an order means; this system owns when it applies |
| Ship AI (#20), Fleet Coordination (#21) | P2 handlers that write AI intents directly into `SimState` | Their phase is called in fixed order | AI owns decisions. AI intents never enter the order queue or the replay log (rule 3) |
| Battle Resolution & Retreat (#22) | P7 end-of-battle and escort-lost signals | Context end, which clears player and auto holds | Battle Resolution owns outcomes |
| AI-vs-AI Runner (#25) | `step(n)` calls | Final state, the per-tick state hash, the event log | The runner owns pacing; this system owns determinism |
| Planning screens: Dossier (#47), Public History / Case File (#49), Ledger (#48), Debrief (#24), port service screens (#27 and the Port screens), route planner (#26) | Add and remove `PLANNING:<screen_id>` | — | Each screen owns its own reason key |
| Camera & Combat View (#45) and all presentation | — | Interpolation alpha; read-only state | Presentation owns drawing. The engine does not pause effects automatically under this design, so each effect class is assigned. **Frozen while held:** ship and projectile visuals, combat VFX and particles, combat tweens and animations, and combat sound one-shots (paused, then resumed). **Running while held:** all UI and planning screens, camera pan and zoom, selection and hover feedback, queued-order and latch markers, and music and ambience. **Mechanism, per class** (driven by one hold-changed signal; the driver lives outside every frozen subtree, rule 7): ship, projectile and VFX nodes, and the AnimationPlayers and node-bound Tweens under them, sit under one `CombatView` root whose `process_mode` is set to `PROCESS_MODE_DISABLED` while held and restored on resume; combat Tweens not bound to that subtree register with `CombatView` and get `pause()`/`play()`; particle nodes also get `speed_scale = 0` while held; combat one-shot players get `stream_paused = true`; combat presentation uses no `Timer` (timed effects are driven by tick events). UI, camera, planning screens and music sit outside `CombatView`. *These engine behaviours are NOT SOURCEABLE in `docs/engine-reference/godot/` (there is no `modules/core.md`); the tick-rate spike verifies them on 4.7.2* |

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
That way the tuning survives a `TICK_RATE` change. The accumulator is an exact
integer (D2). It only decides **how many** ticks run, never **what** a tick
does, so it cannot break determinism. Being an integer, it also cannot drift,
round out of range, or be poisoned by a bad frame.

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

The accumulator counts owed simulation time in exact integer units.
`ACC_UNITS_PER_TICK = 1,000,000` (written `U` below), so one unit is a
millionth of a tick.

The accumulator_update formula is defined as:

`d_us = is_finite(frame_delta) ? max(0, round(frame_delta × 1,000,000)) : 0`
`feed = d_us × TICK_RATE × speed_scale`
`acc_next = held ? acc : ((resumed_this_frame OR d_us > SLEEP_THRESHOLD_US) ? 0 : acc + feed)`

- `TICK_RATE × speed_scale` is an integer for every allowed speed (60 Hz: 30,
  60, 120, 240; 30 Hz: 15, 30, 60, 120), so `feed` is exact. One real second
  at 1× feeds `TICK_RATE × U` units, which is exactly `TICK_RATE` ticks.
- A non-finite `frame_delta` (NaN, ±∞) feeds 0 and is logged. It can never
  reach `acc`.
- A frame longer than `SLEEP_THRESHOLD_S` (sleep, a debugger break, a long
  stall) feeds no time. In `BATTLE`, it also adds `PLAYER_PAUSE`.
  `SLEEP_THRESHOLD_US` is that knob converted to microseconds at load.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| acc | int (units) | 0 to < U between frames | calculated | Simulation time owed but not yet ticked, in millionths of a tick |
| ACC_UNITS_PER_TICK (U) | int | 1,000,000 | constant (engineering) | Units per tick |
| frame_delta | float (s) | any; non-finite or negative values feed 0 | calculated (the driver's own `_process` delta, rule 7) | Real time since the last frame |
| d_us | int (µs) | ≥ 0 | calculated | `frame_delta` in whole microseconds |
| SLEEP_THRESHOLD_S | float (s) | 0.25 – 5 (1.0) | data file (tuning knob) | Frame length above which the frame is treated as an interruption, not a hitch |
| speed_scale | float | {0.5, 1, 2}; 4 in dev builds; `30 × speed_scale` must be an integer (validated at load) | data file (tuning knob) | Selected speed |
| held | bool | — | calculated | The hold-reason set is not empty |
| resumed_this_frame | bool | — | calculated | The hold set became empty this frame |

**Output Range:** 0 upwards before D3 runs; D3 brings it back below `U`.
- While held, `acc` is frozen.
- On the frame play resumes, `acc` resets to 0. Resuming from focus loss (rule
  16) is one such case, and so is every other resume. **Time spent held is never
  caught up.**
- Rounding to whole microseconds is the only inexactness. A 1/60 s frame
  rounds to 16,667 µs and feeds 1,000,020 units at 60 Hz, 1×, which is 20 ppm
  more than one tick. That is one extra tick per 50,000 frames (about 14
  minutes at 60 fps). It affects cadence only, never outcomes.

**Example:** 60 fps at 2×, with `acc = 240,000` (0.24 of a tick):
`d_us = 16,667`, `feed = 16,667 × 120 = 2,000,040`, so
`acc = 2,240,040` units (2.24 ticks) before D3 runs.

### D3. Ticks this frame, and the discarded remainder

The ticks_this_frame formula is defined as:

`n = min(acc div U, MAX_TICKS_PER_FRAME, n_wall)`
`acc_after = acc − n × U`
`discarded_ticks = acc_after div U`
`acc_final = acc_after mod U`
`discarded_sim_s = discarded_ticks × dt_tick`
`discarded_real_s = discarded_sim_s / speed_scale`

`div` and `mod` are integer division and remainder. `discarded_ticks` is
non-zero only when the tick cap or the wall-time cap stopped the frame.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| MAX_TICKS_PER_FRAME | int | 4 – 12; **8** at 60 Hz, **4** at 30 Hz | constant (engineering) | Catch-up cap. Both values cap catch-up at 133.3 ms of simulation time per frame |
| n_wall | int | ≥ 1 when a tick is owed | calculated | Ticks started before the wall time spent ticking this frame reached `SIM_BUDGET_MS` (rule 8). A tick that crosses the budget finishes; no new one starts |
| n | int | 0 – cap | calculated | Ticks the driver runs this frame |
| discarded_ticks | int | ≥ 0 | calculated | Whole ticks of simulation time dropped. Logged outside the Battle Record |
| acc_final | int (units) | 0 to < U | calculated | Fraction of a tick kept for interpolation |

**Output Range:** `n` is 0 to 8. Ticks are discarded only when a cap binds. The
fractional remainder is always kept, so interpolation stays smooth through a
hitch.
**Example:** a 250 ms hitch at 1×, with `acc = 240,000`, feeds
`250,000 × 60 = 15,000,000`, giving `acc = 15,240,000`: 15 ticks owed, so
`n = 8`. That leaves `acc_after = 7,240,000`. The 7 whole ticks are discarded
(0.11667 s), and `acc_final = 240,000`.

### D4. Interpolation alpha

The interpolation_alpha formula is defined as:

`alpha = (held OR no_tick_since_resume) ? 1 : acc_final / U`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| alpha | float | [0, 1) while running; exactly 1 while held | calculated | Presentation's blend from the previous tick's state to the current one. Because `acc_final` is an integer below `U`, it can never leave this range |
| no_tick_since_resume | bool | — | calculated | Play has resumed but no tick has run yet |

**Output Range:** [0, 1) while running, and **exactly 1 while held**.
- While paused, the screen shows the true current tick, so what the player sees
  agrees with inspection and tooltips. *Pause stops everything exactly where it
  is.*
- The cost is a forward snap of at most one tick of motion at the instant of
  pausing.
- Because D2 resets `acc` on resume, alpha restarts from 0 on the next tick. The
  view never jumps backward.

**Example:** `acc_final = 240,000` gives `alpha = 0.24`. Pausing at that moment
snaps alpha to 1.

### D5. Effective speed, and the speed shown

The effective_speed formula is defined as:

`speed_limit = MAX_TICKS_PER_FRAME × fps / TICK_RATE`
`speed_eff = min(speed_scale, speed_limit)`
`speed_shown = ticks_in_window / (TICK_RATE × SPEED_WINDOW_S)`

The UI shows `speed_scale` unless
`speed_shown < speed_scale × (1 − SPEED_TOLERANCE)`. In that case it shows
`speed_shown`, rounded down to 0.1 (never below 0.1) and marked "slowed".

The window counts **unheld real time only**. It restarts on every resume, on
every speed change and after every step, and until one full window of unheld
time has passed, the UI shows `speed_scale`. Held time, step bursts and the
moment after a resume therefore never produce a false "slowed" or an inflated
speed.

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

Every player speed passes the **cap** check at 30 fps and above. The **CPU**
check is stricter below the target frame rate: at 60 Hz, 2× and 30 fps it needs
4 ticks per frame, so `t_tick_ms ≤ 2.0 ms` against D10's 4.0 ms pass line.
`SIM_BUDGET_MS` is a share of the frame at the **target** frame rate (D10).
Below it, the wall-time cap (rule 8) holds the simulation to that budget, and
the game shows "slowed". That trade (frame rate is protected, speed degrades
honestly) is intended.

**An unsustainable speed is still offered and still selectable.** It runs at
`speed_eff`, and the display marks it "slowed" (D5). It is never silently
replaced by another speed, and never hidden from the menu, so the player always
knows what they chose and what they are getting.

### D7. Auto-pause cooldown and re-arm

The trigger_fire formula is defined as:

`cooldown_ticks = ceil(cooldown_s × TICK_RATE − 1e-6)`
`rearm_ticks = max(1, ceil(rearm_s × TICK_RATE − 1e-6))`
`crossing(t) = armed AND condition(t)`
`fires(t) = crossing(t) AND (t − last_fire_tick ≥ cooldown_ticks)`
`holds(t) = fires(t) AND enabled`

- **`enabled` only decides whether a fire adds its `AUTO_PAUSE` hold** (and
  its banner entry). Triggers are evaluated, and their `armed` and
  `last_fire_tick` updated, whether enabled or not, so the hashed trigger state
  never depends on a player setting (Gameplay Settings & Modifiers, Core Rule
  3; amended 2026-10-30).

- **On every crossing, `armed` becomes false**, whether or not it fires. If
  it fires, `last_fire_tick = t`.
- A trigger becomes **armed** again once its condition has been false for
  `rearm_ticks` consecutive ticks. `rearm_ticks` is at least 1, so a condition
  that stays true can never fire twice.
- **No late fire.** A crossing inside the cooldown is **dropped**: the trigger
  disarms and must see the condition clear for `rearm_ticks` before it can
  fire again. A warning is never delivered after the moment it describes.
- **Per battle.** At battle start every trigger is reset:
  `last_fire_tick = battle_start_tick − cooldown_ticks`, so a trigger can fire
  on the first tick. `armed` follows the start-unarmed rule (Edge Cases).
  Nothing carries over between battles.
- The `− 1e-6` keeps float error in `x × TICK_RATE` from rounding a whole
  number of ticks up by one, which would change replays.

**Per-trigger defaults:**
| Trigger | Class | cooldown_s | rearm_s | Notes |
|---|---|---|---|---|
| Battle start | Context | — | — | Added at context start, never evaluated in P7 (rule 11) |
| Flagship hull critical | Safety | 0 | 2 | Debounced by re-arm only |
| First enemy contact | Per-fleet latch | — | — | One latch per enemy fleet (keyed by Runtime ID), used up when it fires. No shared cooldown, so fleet B is never delayed by fleet A. A fleet already in contact at battle start is covered by Battle start, and its latch is used up |
| Vigor early warning | Safety | 0 | 2 | Debounced by re-arm only |
| Relay cut | Informational | 10 | 2 | |
| Escort lost | Informational | 10 | 0 (clamped to 1 tick) | Event-like: true on the tick the escort is lost |

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| cooldown_s | float (simulation s) | 0 – 60 (per-trigger table) | data file (tuning knob, per trigger) | Minimum simulation time between fires. Always 0 for Safety triggers |
| rearm_s | float (simulation s) | 0 – 10 (per-trigger table); at least 1 tick after conversion | data file (tuning knob, per trigger) | How long the condition must stay clear before the trigger re-arms |
| enabled | bool | — | profile setting (Gameplay Settings & Modifiers) | The player's per-trigger toggle; gates only the hold, never the trigger state |
| armed | bool | — | calculated (saved) | Whether the next crossing can fire |
| last_fire_tick | int | ≥ `battle_start_tick − cooldown_ticks` | calculated (saved; reset each battle) | Tick of the last fire in this battle |

**Output Range:** at 60 Hz, 600 cooldown ticks for informational triggers, and
120 re-arm ticks (300 and 60 at 30 Hz). The minimum re-arm is 1 tick.
- Cooldowns are simulation time, so at 2× a 10 s cooldown passes in 5 s of real
  time.
- *First enemy contact* has no cooldown. It fires once per enemy fleet per
  battle.

**Example (safety):** *Flagship hull critical* fires at tick 12,000. The hull
recovers above the threshold at 12,050 and stays there, so the trigger re-arms
at 12,170. The hull drops below again at 12,300, and the trigger **fires at
12,300**.

**Example (informational):** *Relay cut* fires at 12,000. The cut is repaired
at 12,050, and the trigger re-arms at 12,170. A new cut at 12,300 falls inside
the cooldown (300 < 600): it is **dropped**, and the trigger disarms. If the
link is restored at 12,400 and cut again at 12,700, the trigger has re-armed
(12,520) and the cooldown has passed (700 ≥ 600), so it fires at 12,700.

### D8. tick_index range and integer safety

The tick_index_bound formula is defined as:

`hours_to_limit = LIMIT / (TICK_RATE × 3600)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| tick_index | int (64-bit) | 0 – 2^53 − 1 | calculated | Ticks since the campaign started (campaign-monotonic, rule 1) |
| LIMIT | int | 2^53, 2^31, 2^24 | constant | Largest integer each kind of consumer holds exactly |

**The integer `tick_index` is the only authoritative time.** Every duration,
cooldown and timestamp in the simulation is a tick count. Float seconds exist
only for display.

**Output Range** (at 60 Hz, 216,000 ticks per hour):
- **2^53** (doubles, so it survives a JSON float parse exactly): about
  4.17 × 10^10 hours. This is a hard assert on save.
- **2^31** (any 32-bit consumer): 9,942 hours, which is 414 days of continuous
  simulation. This is a warning threshold. **Storing `tick_index` in 32 bits is
  banned.**
- **2^24, the raw tick count in a float32**: **77.7 hours**
  (2^24 / 216,000). Beyond it, a float32 tick count can no longer hold every
  tick.
- **Float32 seconds** (`tick_index × dt_tick`, for example shader time) fail
  sooner. Their precision step reaches 1/64 s at 2^17 s (about 36 hours) and
  1/32 s at 2^18 s (about 73 hours), so between those two points a float32 can
  no longer tell one tick from the next.
- **Rule:** presentation receives time as `(tick_index mod period_ticks)`,
  computed **on the integer** and only then converted to float for the
  uniform. It never receives the raw count, or seconds derived from it.

**Example:** a 200-hour campaign at 1× is 43.2 million ticks, about 2.0% of
2^31. It is already **2.6× past 2^24**, and past the float32-seconds limit,
so a float32 consumer of raw campaign time would break inside a normal
campaign. That is why the rule above is a hard rule. Playing at 2× reaches
these limits in half the real time.

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
while paused.
- **A step is atomic from the input side.** The step command stamps every
  queued order before its first tick. Input arriving while the step runs is
  queued for the tick after the step ends.
- The driver may spread the ticks of a step over frames (up to 8 per frame),
  because no order can enter between them. The result is identical either way.

### D10. Simulation time budget per frame (the spike's pass line)

The sim_frame_cost formula is defined as:

`sim_ms = ceil(tpf) × t_tick_ms ≤ SIM_BUDGET_MS`

This gives the spike's pass line:

`t_tick_ms ≤ SIM_BUDGET_MS / ceil(TICK_RATE × max_player_speed / target_fps)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| SIM_BUDGET_MS | float (ms) | 5 – 10 (**8, provisional**) | constant (engineering; needs technical-director sign-off) | The simulation's share of a 16.67 ms frame **at `target_fps`**. Also the wall-time cap per frame (rule 8) |
| t_tick_ms | float (ms) | measured | calculated | Cost of one tick, headless, on the reference machine (gate below) |
| max_player_speed | float | 2 | constant | Highest player-selectable speed |
| target_fps | int | 60 | constant | Frame-rate target |
| reference machine | — | named in the Tick/Pause/Determinism ADR | technical-director (Open Questions) | The minimum-spec hardware class the gate is measured on, never the developer's PC |

Write the pass line as `L = SIM_BUDGET_MS / ceil(TICK_RATE × max_player_speed / target_fps)`.

**The gate.** This GDD fixes what the gate measures. The numbers come from the
spike, and technical-director signs them off.
- **Where:** headless, on the reference machine, after a warm-up of 600 ticks.
  At least 3,600 measured ticks per run, 3 runs, taking the median of each
  statistic.
- **Steady scene:** exactly 100 ships and 500 projectiles, from a pinned seed
  fixture.
- **Steady scene passes when:** `p95(t_tick) ≤ L`, `p99(t_tick) ≤ 2 × L`, and
  `max(t_tick) ≤ SIM_BUDGET_MS`.
- **Worst-case scenes**, scripted from the same fixture:
  - a mass kill (20 ships destroyed on one tick);
  - a relay cut that splits the largest machine fleet;
  - a full retarget (every ship picks a new target on one tick).

  Each passes when its worst tick is `≤ SIM_BUDGET_MS`.
- **Recorded, not gated:**
  - per-phase p95 and p99 (P2, P5, P6 and P9 named), to show where to
    optimize. Sub-budgets belong to the spike and the ADR;
  - a 2× stress load (200 ships, 1,000 projectiles).

**Output Range:** at 60 Hz, 2× and 60 fps the simulation needs 2 ticks per
frame, so **`L` = 4.0 ms per tick**. On the 30 Hz fallback it needs 1 tick per
frame, so `L` = 8.0 ms. That doubled headroom is what the fallback buys. Below
`target_fps`, the wall-time cap enforces the budget instead (D6).
**Example:** the spike measures p95 = 3.2 ms, p99 = 6.0 ms, max = 7.5 ms, and
worst-case scenes at most 7.9 ms. 3.2 ≤ 4, 6.0 ≤ 8, 7.5 ≤ 8 and 7.9 ≤ 8, so
60 Hz passes. If p95 measures 5.1 ms, 60 Hz fails, and the fallback is judged
against `L = 8.0` with the same statistics. An occasional frame that runs one
extra tick (from frame-time jitter) is absorbed by the wall-time cap: the tick
that crosses the budget finishes, and no new one starts.

*Specialist consulted: `systems-designer`. Decisions taken in guided mode, all
on the specialist's recommendation:*
- *Alpha is 1 while held.*
- *~~A condition still true after its cooldown fires late.~~ Superseded by the
  design review (2026-10-28, owner decision): a crossing inside the cooldown is
  dropped, and safety triggers have no cooldown (D7).*
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
  eligible triggers combine into one pause that lists every reason. The one in
  cooldown is not listed: its crossing is **dropped**, and it disarms until its
  condition clears for `rearm_ticks` (D7). It never fires late. Cooldowns do
  not elapse while held, because they count ticks.
- **If two enemy fleets are first contacted on the same tick**: one pause names
  both, and each fleet's once-per-battle flag is used up. Fleets are keyed by
  Runtime ID. What counts as "contact", and how a fleet that splits is treated,
  belongs to Combat Space (#11).
- **If a trigger's condition is already true when the battle starts, or when the
  player enables the trigger mid-battle**: the trigger starts **unarmed**. It
  must see the condition clear for `rearm_ticks` before it can fire, because the
  player already knows about a condition that existed before they could act.
  Disabling a trigger never removes a hold that already exists. *Battle start*
  is the exception: it is added at context start and is never evaluated (rule
  11). That matters, because fleets usually start already in contact, so the
  first-contact trigger begins unarmed and cannot be the opening pause.

### Catch-up, speed and frame time

- **If the speed changes while catch-up is under way**: the new speed applies
  from the frame in which the change is processed. Simulation time already owed
  in `acc` is not rescaled. Only cadence changes, so outcomes are unaffected.
- **If `frame_delta` is 0, negative or non-finite (NaN, ±∞)**: it feeds 0
  (D2). No ticks run, and alpha is unchanged. A non-finite value is logged.
- **If `frame_delta > SLEEP_THRESHOLD_S`** (sleep, a debugger break, a long
  stall): the frame feeds no time (D2). In `BATTLE`, `PLAYER_PAUSE` is added.
  Waking from sleep never jumps the battle forward while the player was away.
- **If the frame rate is above 240 fps** (no frame cap): many frames run 0
  ticks, and alpha carries the motion. The speed display counts ticks, so it
  stays correct. This system enforces no minimum or maximum frame rate.
- **If frame-time jitter makes a 60 fps, 1× frame run 0 or 2 ticks**: this is
  accepted, because it affects cadence only, never outcomes. The accumulator
  itself adds no jitter: it is an exact integer (D2), and its only rounding is
  20 ppm of microsecond truncation.

### Saves, replay and determinism

- **If a save is requested while a tick is running**: the save waits for the
  tick boundary, and never captures a state in the middle of a tick (rule 17).
- **If a save or replay has a different `TICK_RATE`**: a mid-battle save is
  refused for that battle. The player is offered the battle's pre-battle state
  instead, which is campaign state kept in World Clock days and does not depend
  on the tick rate. A mismatched replay is refused. These checks belong to
  Save/Load (#5) and the AI-vs-AI Runner (#25).
- **If a save or replay has a different build ID, OS or CPU architecture**: a
  save warns where the build differs, then goes through migration (Save/Load
  #5). A save from another OS or CPU loads normally, because it is a complete
  state. A replay is **"not re-verified"** (rule 14).
- **What the Debrief shows for a replay that is not re-verified**: the Battle
  Record, unchanged and with no player-facing badge (Battle Record rule 15;
  the label is shown in debug views and the Runner only). The Debrief never
  presents a replay as proof, and never re-derives a cause from one.
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

*Whether a battle starts paused was resolved by CD-GDD-ALIGN (Open Questions #1).*
*Design-review revisions (2026-10-28, owner decisions): no late trigger fire
(D7); same-platform verification for MVP (rule 14); read-only planning screens
in battle (rule 10).*

## Dependencies

### Upstream (what this system needs)

**Hard dependencies: none.** The tick core (`SimState`, `step()`, the phase
order and the hold-reason set) runs with nothing else designed. That is why it
sits first in the Foundation layer.

**Interface contracts** (soft). Each is consumed through the driver, or as data
handed in, never as a call back into another system's logic:

| System | Hard / soft | Interface | Notes |
|---|---|---|---|
| Runtime ID Service (#3) | Soft | Entities arrive with stable integer IDs; this system sorts by them within each phase | Without it, processing order falls back to creation order, which is still deterministic. IDs make it stable across save and load |
| Input & Controls (#6) | Soft (driver only) | The flagship command struct each frame; pause, resume, step and speed actions | The headless path has no input. The core never reads input directly |
| Gameplay Settings & Modifiers (#7) | Soft (driver only) | Speed steps, the single-step option, `STEP_LARGE`, auto-pause toggles, cooldowns and re-arm times, the focus-loss option, `SLEEP_THRESHOLD_S`, `SPEED_WINDOW_S`, `SPEED_TOLERANCE` | Read between ticks only. Defaults apply when Settings is absent (Tier 0 constants provider) |
| Deterministic RNG & Seed Streams (#2) | None | — | This system draws no randomness. It only guarantees that phase consumers call their streams in a fixed order |
| Save/Load & Migration (#5) | Soft (reverse) | This system *provides* its section: `tick_index`, the order queue, latches, trigger states, the current battle's replay log and the header (engine version, build ID, OS, CPU architecture, `TICK_RATE`, content hash) | Save owns the format, integer-safe encoding and migration |

### Downstream (what depends on this system)

**Listed in the systems index:**

| System | Hard / soft | What it relies on |
|---|---|---|
| World Clock (#8) | Hard | The P8 call each tick, and `is_held()`. **This system owns the hold-reason set; the World Clock only reads it.** That replaces the index's earlier "hold-reasons API on the World Clock" contract (owner decision, 2026-10-28) |
| Combat Event Bus & Battle Record (#9) | Hard | The P9 flush, stamped with `tick_index`, plus `battle_start_tick` |
| Combat Space (#11) | Hard | P3 and P5 phase calls; ascending-ID order; the first-contact signal for auto-pause |
| Fleet Orders (#19) | Hard | The order queue (player orders only), the apply-tick stamp, `OrderRejected`, and `cancelled_by_context_end` |
| AI-vs-AI Runner & AI Debug Tools (#25) | Hard | `step(n)` with no driver; the per-tick state hash; `TriggerWouldFire` logging |
| Camera & Combat View (#45) | Soft | The interpolation alpha and read-only state. It never drives or pauses the tick |

**Also listed in the index.** The systems index already names this system as a
dependency of each of these. Each must also list it in its own GDD's
Dependencies:

| System | Hard / soft | What it relies on |
|---|---|---|
| Weapons & Damage (#12) | Hard | P4 and P5 phase calls; the hull-critical threshold signal |
| Vigor (#13) | Hard | P6 phase call; the Vigor early-warning signal |
| Coherence & Links (#14) | Hard | P6 phase call; the relay-cut signal |
| Ship AI (#20), Fleet Coordination (#21) | Hard | P2 phase call. AI writes its intents directly into `SimState`; they never enter the order queue or the replay log (rule 3) |
| Battle Resolution & Retreat (#22) | Hard | P7 battle-end check (runs before trigger evaluation); ends the context; escort-lost signal. **Constraint (rule 18):** must never grade or penalise hold, speed or step usage |
| After-Action Debrief (#24), Dossier (#47), Ledger (#48), Public History Screen (#49) | Soft | Add and remove `PLANNING:<screen_id>`. In `BATTLE`, opening also adds `PLAYER_PAUSE` (rule 10). The Debrief's hold must be added on the frame the battle ends. **Constraint (rule 18):** the Debrief never grades pause, speed or step usage |
| Menus, Settings & Save UI (#51) | Soft | Adds `SYSTEM:menu`, `SYSTEM:save`, `SYSTEM:load` |
| Combat HUD & Tactical Overlay (#46) | Soft | Alpha, the speed display (D5), queued-order and latched-press markers, and the reasons behind each hold |
| Telemetry & Playtest Logging (#54) | Soft | `tick_index` stamps; "time dropped" notes |

**Missing from the index.** The index does not yet list this system for:

| System | Hard / soft | What it relies on |
|---|---|---|
| Flagship Piloting (#15) | Hard | Owns the P1 handler that applies the flagship command. Relies on this system's sampling, latching, recording and precedence rules (rule 6). The index row for #15 should add Simulation Tick & Pause |

**Bidirectional check.** No other GDD exists yet, so each of the systems above
must list Simulation Tick & Pause in its own Dependencies when it is designed.
`/design-system` raises this for each of them through the systems index.

## Tuning Knobs

Player-facing knobs live in Gameplay Settings & Modifiers (#7). Designer knobs
live in this system's data file. Engineering constants are listed separately:
they are not knobs, and changing one is a versioned, replay-breaking change.

### Designer and player knobs

| Knob | Default | Safe range | Affects | Too low | Too high | Interacts with |
|---|---|---|---|---|---|---|
| `SPEED_STEPS` (player) | {0.5, 1, 2} | any steps in 0.25 – 2 where `30 × step` is an integer, so the integer accumulator stays exact at both tick rates (D2) | How fast battles play out; relaxation vs tension | Below 0.25×, battles drag and steps between speeds feel arbitrary | Above 2×, the D6 cap and CPU checks fail at 30 fps, and the "slowed" display triggers often | `MAX_TICKS_PER_FRAME`, `SIM_BUDGET_MS` (D6, D10) |
| `DEFAULT_SPEED` | 1× | one of `SPEED_STEPS` | First impression of pace | — | — | `SPEED_STEPS` |
| "Tactical step" (player setting) | Off | on / off | Fine-grained reading of a fight | — | — | `STEP_LARGE` |
| `STEP_LARGE` (first to cut; becomes a fixed value) | 10 ticks | 2 – 30 | Size of the coarse step | At 2, it is barely different from `STEP_SMALL` | Above 30 (0.5 s at 60 Hz), a step is too coarse to read and causes a visible hitch (D9) | `TICK_RATE` |
| `AUTO_PAUSE_ENABLED[trigger]` | Battle start **on**, hull critical **on**, first contact **on**; Vigor warning, relay cut, escort lost **off** | on / off each | Interruptions vs safety net (Pillar 3; "relaxing") | All off: fights can run away from a new player | All on: pause spam, which breaks flow | `cooldown_s`, `rearm_s` |
| `cooldown_s[trigger]` | Per-trigger table (D7): 10 s for informational triggers, 0 for safety triggers | 0 – 60 (simulation seconds); always 0 for safety triggers | Minimum gap between pauses from one informational trigger. A crossing inside it is dropped, never deferred | Near 0: frequent pauses when the event repeats | Above 30: a second real event is dropped | `rearm_s`, speed (cooldowns run faster at 2×) |
| `rearm_s[trigger]` | Per-trigger table (D7): 2 s for most | 0 – 10 (simulation seconds); never less than 1 tick after conversion | How firmly a condition must clear before re-firing. The only debounce for safety triggers | At 1 tick, the trigger can re-fire on value jitter | Above 5, a genuine second crossing is missed | `cooldown_s` |
| Focus-loss auto-pause | On | on / off | Safety when the player alt-tabs | — | — | rule 16 |
| `SLEEP_THRESHOLD_S` | 1.0 s | 0.25 – 5 | Where a long frame counts as an interruption rather than a hitch | Below 0.25 s, ordinary hitches pause the battle | Above 5 s, waking from sleep lets the catch-up cap advance the battle without the player | `MAX_TICKS_PER_FRAME` |
| `SPEED_WINDOW_S` | 1.0 s | 0.5 – 2 | How quickly the speed display reacts | Below 0.5 s, the display flickers | Above 2 s, it reports a slowdown late | `SPEED_TOLERANCE` |
| `SPEED_TOLERANCE` | 0.05 | 0.02 – 0.10 | When the display says "slowed" | At 0.02, it says "slowed" on normal jitter | At 0.10, it hides a real 10% slowdown | `SPEED_WINDOW_S` |

### Engineering constants (versioned; not tuning knobs)

| Constant | Value | Why it is fixed |
|---|---|---|
| `TICK_RATE` | 60 Hz target; 30 Hz fallback, decided by the spike | Changes every tick's content, so replays and mid-battle saves are incompatible across values. Written into every header |
| `MAX_TICKS_PER_FRAME` | 8 at 60 Hz, 4 at 30 Hz | Sets the catch-up ceiling (about 133 ms of simulation time per frame). Affects cadence only, never outcomes |
| `SIM_BUDGET_MS` | 8 ms (provisional) | The simulation's share of a 16.67 ms frame at the target frame rate, and the per-frame wall-time cap (rule 8). Sets the spike's pass line (D10). Needs technical-director sign-off |
| `ACC_UNITS_PER_TICK` | 1,000,000 | Resolution of the integer accumulator (D2). Affects cadence only |
| `STEP_SMALL` | 1 tick | By definition |
| `AIM_QUANTUM` | 1/16 world unit (unit defined by Combat Space #11) | Quantizes the recorded flagship-relative aim offset (rule 6). Changing it changes replays |
| 2^53 save assert; 2^31 − 1 hour warning; integer-modulo presentation time | — | Integer safety (D8) |

**Knobs owned elsewhere** (referenced, not duplicated):
- the hull-critical threshold (Hulls / Weapons & Damage)
- the Vigor early-warning threshold (Vigor)
- how many game days a tick is worth, in battle and out (World Clock)
- what counts as first contact (Combat Space)

## Visual/Audio Requirements

This system has no art of its own. It sets the rules that combat visuals and
audio must follow while the simulation is held or sped up:

- **Freezing while held** follows the effect-class list in Interactions.
  - Ship and projectile visuals, combat VFX and particles, combat tweens and
    animations freeze.
  - Combat sound one-shots pause and resume where they left off.
  - UI, the camera, hover and selection feedback, queued-order and latch markers,
    and music and ambience keep running.
- **A held battle reads as held at a glance.** The planning chart language (art
  bible: "planning tools are drawn on the captain's chart") may tint or overlay
  the paused field. It must never hide hull glow or link patterns, because the
  player pauses precisely to read them.
- **At 0.5× and 2×**, combat visuals play at simulation speed: they are driven
  by the tick plus alpha. Whether combat sound **pitch-shifts** or only
  **time-scales** at 2× is open (see Open Questions). Music never changes speed.
- **No visual may depend on a raw `tick_index` in float32** (D8). Shader time is
  passed modulo a period.

*`art-director` and `audio-director` were not consulted: Visual/Audio is optional
for `Core` systems. Review this section when the art bible and audio direction
exist.*

## Game Feel

- **Pause responds on the press, within one rendered frame.** The next frame the
  player sees is frozen: alpha snaps to 1 and no further tick runs. There is no
  fade-in to the pause, because the fantasy is that "everything stops mid-shot".
- **Resume is equally immediate.** The first tick after resume runs on the next
  frame where `acc ≥ U` (one whole tick, D2), which is at most one tick, 16.7 ms
  at 60 Hz.
- **Flagship input latency target: ≤ 83 ms worst case, end to end**, from the
  input event to the first displayed frame that shows its effect. At 60 Hz it
  is built from:

  | Stage | Worst case | Note |
  |---|---|---|
  | Wait for the next frame's sample | 16.7 ms | |
  | Wait for the next tick boundary | 16.7 ms | Rule 6 |
  | One tick of interpolation lag | 16.7 ms | D4 |
  | Display pipeline (vsync, compositor) | up to 33.3 ms | Two frames |

  The typical figure is about 40–50 ms.
- **30 Hz fallback: presentation-side flagship prediction is required.** At
  30 Hz the same chain reaches about 133 ms. While the fallback is in force,
  presentation does three things:
  - extrapolates the flagship's transform from the live command;
  - starts its fire cue on input;
  - draws the reticle at the unquantized aim.

  This brings piloting back inside the ≤ 83 ms target. Prediction is visual
  only. The simulation never reads it, and presentation converges on the
  simulated state within one tick. Aiming alone was never enough, because
  thrust and fire also need prompt feedback (rule 13).
- **Orders given while paused feel committed, not pending.** A queued order shows
  its marker the moment it is issued. On resume, it visibly takes effect on the
  first tick (framing C of the Player Fantasy, "my orders, exactly").
- **Auto-pause must feel like a hand on the shoulder, not a slammed door.** It
  lands on a tick boundary, names its reasons in one banner, and never fires
  twice for one crossing.
- **Slowdowns are honest.** When the catch-up cap binds, the game slows visibly,
  and the speed display says "slowed". It never stalls and then lurches.

## UI Requirements

This system contributes these elements to the Combat HUD & Tactical Overlay
(#46) and to Menus, Settings & Save UI (#51):

1. **Hold indicator.** It shows "Paused" whenever the simulation is held, with
   every active reason in plain words: paused by you; auto-pause (hull critical,
   contact…); Case File open; saving; window unfocused.
2. **Resume control.** When resume is not possible, it is disabled and names the
   blocking hold (for example "Saving…" or "Close the Case File to resume"). It
   never accepts a press it cannot act on (Edge Cases).
3. **Speed control and display.** It offers 0.5×, 1× and 2×, plus 4× in dev
   builds, shows the effective speed, and adds "slowed" per D5.
4. **Step controls** (when "Tactical step" is on): step 1 tick, and step 10
   ticks (first to cut). They are disabled under planning and system holds, with
   the reason shown.
5. **Auto-pause banner.** One banner per pause lists every trigger that fired on
   that tick. Each entry links to its toggle.
6. **Queued-order and latched-press markers.** These are visible while held, and
   each can be cancelled (AC-48).
7. **Settings entries** (in #51): each auto-pause toggle, including Battle
   start; the focus-loss pause; and "Tactical step", grouped with the tactical
   settings, never with debug or assist settings.

The hold indicator's wording ("Paused", or a bridge-style "Holding") goes to
`narrative-director` together with the UX spec. Its tone is naval-bridge calm
(Player Fantasy).

Every element must be usable from the keyboard alone. Pause must be bindable to
any key (Input & Controls; accessibility requirements). Meaning must never rely
on colour alone.

> **📌 UX Flag — Simulation Tick & Pause**: this system has UI requirements. In
> Phase 4 (Pre-Production), run `/ux-design` to create UX specs for the combat
> HUD's pause, speed and auto-pause elements, and for the settings entries,
> **before** writing epics. Stories that reference this UI should cite
> `design/ux/[screen].md`, not this GDD.

## Cross-References

| This GDD references | Document | Section | What is relied on |
|---|---|---|---|
| Pillar 3, *Hands on the Helm*; pillar tensions | `design/gdd/game-concept.md` | Game Pillars | "Pause is always available"; pause and difficulty options are pillar commitments |
| Pillar 1, *Every Defeat Is a Lead* | `design/gdd/game-concept.md` | Game Pillars | The Debrief's cause must be trustworthy, which deterministic replay supports |
| World clock behaviour | `design/gdd/game-concept.md` | Core Mechanics (Vigor: defeat-cost bounds) | The clock runs in battle and in travel, and stops while paused, while planning screens are open, and while the game is closed |
| Architecture direction | `design/gdd/game-concept.md` | Technical Considerations | Simulation/view split; fixed tick; headless AI-vs-AI runner; versioned saves |
| System boundaries, layer, priority | `design/gdd/systems-index.md` | Systems Enumeration; Technical Director Note; Circular Dependencies | Foundation layer; no scene nodes in the simulation; the hold-reason contract, now **owned here** |
| Tier 0 boundary test | `design/gdd/systems-index.md` | Technical Director Note | "The headless runner reproduces the same battle twice from one seed" (AC-39) |
| Prototype pause | `prototypes/vigor-coherence-concept/REPORT.md` | Results | Pause and fleet orders were not in the build, so there is no tested design to inherit |
| Engine facts | `docs/engine-reference/godot/` | `VERSION.md`; `current-best-practices.md` (Command Line); `deprecated-apis.md` | 4.7.2 headless; CLI flags; `Time.get_ticks_*`. There is **no `modules/core.md`**, so this domain is unchecked against the pinned engine |

No other system GDD exists yet. Each system in Dependencies → Downstream must
cross-reference this GDD when it is written.

## Acceptance Criteria

**How tests stay isolated.** No criterion reads the wall clock. The fixtures:
- **`FakeFrameSource`** feeds the driver a scripted `frame_delta[]`, plus a fake
  `now` for D5's window.
- **`FixtureSimState`** has stub phase handlers that append
  `(tick_index, phase, entity_id)` to a call log, and a stub trigger whose
  `condition(t)` is scripted per tick.
- **`ConstantsProvider`** injects `TICK_RATE`, `MAX_TICKS_PER_FRAME`,
  `SIM_BUDGET_MS` and the knobs.
- **`EventBusSpy`** and **`WorldClockSpy`** record calls.
- **`state_hash(SimState)`** hashes the simulation state as rule 14 defines it.
  AC-53 proves it can fail.
- `FakeFrameSource` and the fake wall clock are injected into the driver
  adapter, which never constructs its own time source.

Unit tests do no file I/O: saves round-trip through an in-memory buffer. Test
files are named `sim_tick_[feature]_test.gd`, with functions named
`test_[scenario]_[expected]`. Floats are compared with `is_equal_approx`; tick
counts are compared as exact integers.

### Logic: unit tests, `tests/unit/sim_tick/` (BLOCKING)

- **AC-01 (rule 1, D1)**: **GIVEN** a new game with `TICK_RATE = 60`, **WHEN**
  `step(5)` runs, **THEN** `tick_index == 5`, `dt_tick ≈ 1/60`, and
  battle-relative time equals `tick_index − battle_start_tick`.
- **AC-02 (rule 1)**: **GIVEN** a save at `tick_index = N`, with a battle ending
  after it, **WHEN** the save is reloaded and a new battle starts, **THEN**
  `tick_index` continues from N and never resets.
- **AC-03 (rule 3)**: **GIVEN** `BATTLE`, and entities with IDs {7, 2, 5}
  inserted in that order, **WHEN** one tick runs, **THEN** the call log shows
  P1…P9 in order, and within each phase the IDs come in the order 2, 5, 7.
- **AC-04 (rule 3)**: **GIVEN** an order applied in P1 of tick T, **WHEN** P2 of
  tick T runs, **THEN** the stub AI sees the order applied, and sees positions
  and damage as they stood at the end of tick T−1.
- **AC-05 (rule 4)**: **GIVEN** `CAMPAIGN`, **WHEN** one tick runs, **THEN**
  P2–P6 are absent from the call log, P1, P7, P8 and P9 run in order, and
  `WorldClockSpy` records one P8 call.
- **AC-06 (rule 5)**: **GIVEN** the simulation is held at `tick_index = T`, and
  orders A, B and C are enqueued in that order (A and C for the same ship),
  **WHEN** play resumes and one tick runs, **THEN** all three are stamped T+1,
  P1 applies them in the order A, B, C, the replay log holds all three at T+1,
  and C's effect wins.
- **AC-07 (rule 5)**: **GIVEN** a queued order, **WHEN** it is cancelled before
  its tick, **THEN** P1 does not apply it. **WHEN** it is instead edited after P1
  has drained it, **THEN** the edit is a new order stamped for the next tick.
- **AC-08 (rule 6)**: **GIVEN** the simulation is held, **WHEN** one ability is
  pressed and released, then pressed three more times, and one tick runs,
  **THEN** P1 sees exactly one press, and the latch is clear afterwards. A fire
  tap shorter than `dt_tick` fires for exactly one tick.
- **AC-09 (rule 6)**: **GIVEN** the same world aim point under two different
  camera positions, and the flagship at world position `F`, **WHEN** the command
  is recorded, **THEN** both recorded aims equal
  `round((world − F) / AIM_QUANTUM) × AIM_QUANTUM`. **GIVEN** a still cursor and
  a camera that follows the flagship as it moves for 60 ticks, **THEN** the
  recorded aim is the same on all 60 ticks and is recorded once.
- **AC-10 (rule 7, D2)**: **GIVEN** `acc = 240,000` at 2× and 60 Hz, **WHEN** one
  frame of 1/60 s is fed, **THEN** `acc == 2,240,040` exactly, before D3 runs.
  **WHEN** the same frame is fed while held, **THEN** `acc` is unchanged.
- **AC-11 (D2)**: **GIVEN** `frame_delta` of 0, −0.01, NaN, +∞ and −∞ in turn,
  **WHEN** each frame is fed, **THEN** no tick runs, `acc` and alpha are
  unchanged, and each non-finite value is logged once.
- **AC-12 (rule 8, D3)**: **GIVEN** `acc = 240,000` at 1× with the cap at 8,
  **WHEN** a 0.25 s frame is fed, **THEN** `n == 8`, `discarded_ticks == 7`,
  `acc_final == 240,000`, and one "time dropped" note is logged outside the Battle
  Record.
- **AC-13 (D2, boundary)**: **GIVEN** `BATTLE` with `SLEEP_THRESHOLD_S = 1.0`:
  - **WHEN** a 1.0 s frame is fed, **THEN** time is fed.
  - **WHEN** a 1.001 s frame is fed, **THEN** 0 ticks run, `acc == 0`, and
    `PLAYER_PAUSE` is present.
  - **WHEN** a 1.001 s frame is fed in `CAMPAIGN`, **THEN** 0 ticks run and no
    `PLAYER_PAUSE` is added.
- **AC-14 (D4)**: **GIVEN** `acc_final = 240,000`:
  - **WHEN** running, **THEN** `alpha == 0.24`.
  - **WHEN** held, **THEN** `alpha == 1`.
  - **WHEN** play resumes, **THEN** alpha stays at 1 until the first tick, and
    is below 1 after it.
- **AC-15 (rule 9)**: **GIVEN** the simulation is held, **WHEN** the speed is
  changed, **THEN** the hold set is unchanged.
- **AC-16 (D5)**: **GIVEN** 2× selected, `fps = 12` and the cap at 8, **WHEN**
  `speed_limit` is computed and the fake window counts ticks, **THEN**
  `speed_limit ≈ 1.6`, and the display model reports `1.6`, `slowed = true`.
  **GIVEN** `speed_shown == speed_scale × (1 − SPEED_TOLERANCE)` exactly,
  **THEN** `slowed = false`.
- **AC-17 (D6)**: **GIVEN** each cell of the D6 table, **WHEN** `tpf` is
  computed, **THEN** it matches the table to 2 decimal places, and only the
  60 Hz, 4×, 30 fps cell equals the cap. **GIVEN** a speed whose `tpf` exceeds
  the cap, **THEN** it is still selectable and runs at `speed_eff`.
- **AC-18 (rule 10, stacking)**: **GIVEN** `PLAYER_PAUSE`, `PLANNING:case_file`
  and `SYSTEM:focus_lost`, **WHEN** they are removed by their own causes in each
  of the 6 possible orders, **THEN** ticks resume only after the last one goes,
  and closing the Case File never removes `PLAYER_PAUSE`. Adding a reason that is
  already present leaves the set's size unchanged.
- **AC-19 (resume rejected)**: **GIVEN** a `SYSTEM` or `PLANNING` reason is
  present, **WHEN** resume is pressed and that reason is later removed, **THEN**
  the press did not change the set, the press returned a rejection naming the
  reason, and it was not remembered: the game is still held by the player
  reason.
- **AC-20 (same-frame toggle)**: **GIVEN** the game is running, **WHEN** pause is
  added and then removed in the same frame, before the driver reads the hold
  set, **THEN** `acc` is not reset, alpha does not snap, and the tick count is
  unaffected.
- **AC-21 (rule 11, D7)**: Every hold is added after P7 of a tick, never mid-tick.
  - **Safety:** **GIVEN** a hull-critical trigger with cooldown 0 and a re-arm
    of 120 ticks, **WHEN** its condition is scripted true at 12,000, false from
    12,050 to 12,299, and true from 12,300 on, **THEN** it fires at 12,000,
    re-arms at 12,170, and fires again at 12,300.
  - **Informational:** **GIVEN** a relay-cut trigger with a cooldown of 600
    ticks and a re-arm of 120, **WHEN** its condition is true at 12,000, false
    12,050–12,299, true 12,300–12,399, false 12,400–12,699 and true from
    12,700, **THEN** it fires at 12,000, does not fire at 12,300 or at any tick
    up to 12,699 (the crossing is dropped, not deferred), and fires at 12,700.
- **AC-22 (rule 11, D7)**: **GIVEN** two eligible triggers and one in cooldown on
  the same tick, **WHEN** P7 runs, **THEN** there is one pause listing exactly
  the two eligible reasons, and the one in cooldown is disarmed. **GIVEN** a
  condition already true at battle start, or when the trigger is enabled,
  **THEN** the trigger does not fire until the condition has been clear for
  `rearm_ticks`. Cooldowns do not elapse while held.
- **AC-22b (D7 boundaries)**: **GIVEN** `cooldown_s = 0` and `rearm_s = 0`,
  **WHEN** the condition stays true for 100 ticks, **THEN** the trigger fires
  exactly once. **GIVEN** a fire in battle N at its last tick, **WHEN** battle
  N+1 starts and the condition crosses on its first tick, **THEN** the trigger
  fires on that tick. **GIVEN** `cooldown_s = 10` at 60 Hz and at 30 Hz,
  **THEN** `cooldown_ticks` is exactly 600 and 300.
- **AC-23 (battle-end tick)**: **GIVEN** a trigger condition that is true on the
  battle-ending tick, **WHEN** P7 runs, **THEN** the battle-end check runs before
  the trigger, the trigger is logged, and no `AUTO_PAUSE` is added.
- **AC-24 (first contact)**: **GIVEN** two enemy fleets contacted on one tick,
  **WHEN** P7 runs, **THEN** one pause names both fleets, and neither fires again
  in that battle.
- **AC-25 (rule 12, D9)**: **GIVEN** the simulation is held only by player and
  auto reasons, **WHEN** `step(STEP_SMALL)` or `step(STEP_LARGE)` runs, **THEN**
  exactly 1 or `STEP_LARGE` ticks run, P1 orders apply, and the original hold set
  is restored. **GIVEN** any `PLANNING` or `SYSTEM` reason, **THEN** the step is
  rejected and 0 ticks run.
- **AC-26 (step interrupted)**: **GIVEN** a 10-tick step, **WHEN** the battle ends
  at tick k, or a trigger fires at k, or a `SYSTEM` reason arrives during tick k,
  **THEN** exactly k ticks run in each case.
- **AC-27 (rule 16)**: **GIVEN** `BATTLE` with the focus option on, **WHEN** focus
  is lost and then regained, **THEN** `SYSTEM:focus_lost` and `PLAYER_PAUSE` are
  both added, and only `SYSTEM:focus_lost` is removed. **GIVEN** `CAMPAIGN`,
  **THEN** only the `SYSTEM` reason is added.
- **AC-28 (rule 17, boundary)**: **GIVEN** a `FixtureSimState` whose P4 stub
  calls `save_request()` during tick T, **WHEN** tick T completes, **THEN** the
  save buffer's `tick_index == T` (the tick just completed), its hash equals
  `state_hash` after tick T, and the call log shows P5–P9 of tick T ran before
  the save was taken.
- **AC-28b (rule 17, contents)**: **GIVEN** a save taken at a tick boundary,
  **THEN** it includes the queue, latches, trigger states, RNG stream states,
  the current battle's replay log and the header fields of rule 14, and
  excludes `acc` and the hold set.
- **AC-28c (rule 17, load)**: **GIVEN** a save taken mid-battle (including by
  quitting), **WHEN** it is loaded, **THEN** the hold set equals
  `{PLAYER_PAUSE}`, and the first tick after resume is `T + 1`.
- **AC-29 (lost subject, context end)**: **GIVEN** an order whose subject is
  destroyed before P1, **THEN** the order is dropped and
  `OrderRejected(subject_lost)` is emitted. **GIVEN** the context ends with
  queued orders and latches, **THEN** the orders are logged
  `cancelled_by_context_end`, and the latches are cleared.
- **AC-30 (D8, boundary)**: **GIVEN** `tick_index = 2^31 − 216,000`, **WHEN** one
  tick runs, **THEN** exactly one warning is logged, and play continues. **GIVEN**
  `tick_index = 2^53` on save, **THEN** the save asserts. Encoding and decoding
  `2^53 − 1` is exact.
- **AC-31 (context end)**: **GIVEN** a battle ends, **THEN** player and auto
  reasons are cleared, and `PLANNING` and `SYSTEM` reasons persist.
- **AC-32 (accumulator exactness)**: **GIVEN** 600 frames of 1/60 s at 1× and
  60 Hz, **WHEN** they are fed, **THEN** exactly 600 ticks run and
  `acc_final == 12,000`. **GIVEN** each of 0.5×, 1× and 2× at 60 Hz and 30 Hz,
  fed 3,600 frames from 30, 60 and 144 fps sources, **THEN** the tick count
  equals `floor(total feed / U)` exactly, and `0 ≤ acc_final < U` after every
  frame.
- **AC-33 (rule 2)**: **GIVEN** the simulation is held, **WHEN** 600 frames of
  rendering, inspection and tooltip queries run, **THEN** `state_hash` is
  unchanged.
- **AC-53 (rule 14, `state_hash` can fail)**: **GIVEN** a fixture state,
  **WHEN** exactly one of these is changed in turn — one ship's position by
  the smallest float step, one hull value, one RNG stream state, one queued
  order, one latch, one trigger's `armed` flag, `tick_index` — **THEN** the
  hash changes every time. **WHEN** only the hold set or `acc` changes, **THEN**
  the hash is unchanged. **GIVEN** the same state built with its entities
  inserted in two different orders, **THEN** the hashes are equal.
- **AC-54 (rule 6, precedence and no flagship)**: **GIVEN** a live command
  that thrusts forward and a queued order for the flagship to move elsewhere,
  **WHEN** one tick runs, **THEN** the flagship's movement follows the live
  command. **GIVEN** the flagship is destroyed at tick T, **WHEN** ticks T+1
  onward run with input changing every frame, **THEN** P1 applies no command,
  nothing is recorded to the replay log for it, and latched presses are
  cleared.
- **AC-55 (rule 6, sampling)**: **GIVEN** an input change sampled on frame k,
  **WHEN** the driver passes run, **THEN** the command is applied in P1 of the
  first tick run in the driver pass of frame k or later, never a later tick.
  **GIVEN** a driver pass that runs 3 ticks, **THEN** all 3 read the same sample.
- **AC-56 (rule 8, wall-time cap)**: **GIVEN** a stub tick that costs 5 ms of
  fake wall time, `SIM_BUDGET_MS = 8`, 2× at 60 Hz, and a fake frame rate of 30
  fps (4 ticks owed per frame), **WHEN** one frame is fed, **THEN** exactly 2
  ticks run (the second crosses the budget and finishes), 2 ticks are
  discarded, and the speed display model reports `slowed = true` once a full
  window has passed.
- **AC-57 (rule 10, ordered holds)**: **GIVEN** `PLAYER_PAUSE`,
  `AUTO_PAUSE:hull_critical`, `PLANNING:dossier` and `SYSTEM:save` added in that
  order, **THEN** `holds()` returns them as SYSTEM, PLANNING, AUTO, PLAYER, and
  the shown state is Held (system). **GIVEN** a battle-ending tick, **WHEN** the
  battle-end step runs, **THEN** at no observable point between it and the next
  driver pass is the hold set empty.
- **AC-58 (rule 10, read-only in battle)**: **GIVEN** `BATTLE`, **WHEN** a
  stub planning screen asks the context whether a committing action is allowed,
  **THEN** the answer is no, and in `CAMPAIGN` it is yes.
- **AC-59 (rules 3, 5, AI path)**: **GIVEN** stub AI handlers that set an
  intent in P2 of tick T, **THEN** P3 of tick T sees that intent, the order
  queue never contains it, and the replay log for the battle contains only
  player orders and flagship commands.

### Static checks, CI lint (BLOCKING)

- **AC-34 (rules 1, 7, 14)**: **GIVEN** the simulation code in `src/sim/**`
  (excluding the driver adapter and the RNG system), **WHEN** CI lints it,
  **THEN** it fails on any of:
  - wall-clock and frame time: `Time.`, `OS.get_ticks`, `OS.get_unix_time`,
    `Engine.get_frames_drawn`, `Engine.get_physics_frames`,
    `Engine.time_scale`, a `delta` parameter, `_process` or `_physics_process`,
    `create_timer`, `Timer`;
  - randomness outside the RNG system: `randi`, `randf`, `randi_range`,
    `randf_range`, `randomize`, `rand_from_seed`, `seed(`, `shuffle`,
    `pick_random`, `RandomNumberGenerator` (any use);
  - unstable ordering: `get_instance_id`, `hash(`, and iterating a
    `Dictionary` (`for … in <dict>`, `.keys()`, `.values()`) outside the
    sorted-keys helper.

  **Shown to fail:** one planted violation per banned item lives in
  `tests/fixtures/lint/sim_tick/bad_<item>.gd`. CI runs the lint over each
  fixture and must exit non-zero for every one. The production scan of
  `src/sim/**` excludes the fixtures and must exit 0. A GDScript-aware check is
  preferred over text matching (Tick/Pause/Determinism ADR).
- **AC-35 (D8)**: **GIVEN** `tick_index = 2^24 + 1`, **WHEN** presentation sets
  its shader time inputs, **THEN** every time uniform equals
  `(tick_index mod period_ticks)` computed on the integer and then converted,
  and is less than its declared period. **GIVEN** `tick_index = 43,200,000`
  (200 hours), **THEN** the same holds.

### Integration: `tests/integration/sim_tick/` (BLOCKING)

- **AC-36 (World Clock)**: **GIVEN** each hold category in turn, **WHEN** 600
  frames are fed, **THEN** `WorldClock.is_held()` is true and game days are
  unchanged. **WHEN** the game is running, **THEN** P8 is called once per tick.
- **AC-37 (Event Bus)**: **GIVEN** events emitted in P1–P7 across 3 ticks,
  **THEN** there are exactly 3 flushes, each stamped with its own `tick_index`,
  and no event carries a later tick's stamp.
- **AC-38 (Debrief hold)**: **GIVEN** a battle-ending tick, **WHEN** the next
  driver pass runs, **THEN** `PLANNING:debrief` is already present, 0 `CAMPAIGN`
  ticks run, and the World Clock does not advance until the Debrief closes.

### Determinism and replay: `tests/integration/sim_tick/` (BLOCKING)

- **AC-39 (Tier 0 boundary test)**: **GIVEN** one seed, one starting state and one
  recorded command log, **WHEN** the headless runner plays the battle twice,
  **THEN** the two per-tick `state_hash` sequences are identical and the same
  length.
- **AC-40 (rules 9, 15)**: **GIVEN** one seed and log, **WHEN** the battle is run
  through `FakeFrameSource` at 0.5×, 1× and 2×, each with a scripted
  `frame_delta[]` holding at least 5 frames of 0.25 s and 3 frames of 0.9 s
  (hitches below `SLEEP_THRESHOLD_S`, so no pause is added), plus one run that
  changes speed from 1× to 2× and back mid-battle, and once through headless
  `step(n)`, **THEN** all five hash sequences are identical. (A frame above
  `SLEEP_THRESHOLD_S` pauses the battle and is covered by AC-13.)
- **AC-41 (replay divergence)**: **GIVEN** a replay with a gap in the order
  sequence at tick T, or a state hash altered at T, **THEN** the replay stops at
  T−1, reports "diverged at tick T", and fills nothing in. **GIVEN** a flagship
  command missing from the log, **THEN** it is treated as unchanged, with no
  divergence.
- **AC-42 (headless triggers)**: **GIVEN** a headless run that meets a trigger
  condition, **THEN** `TriggerWouldFire(tick, id)` is logged at the same ticks as
  AC-21, the hold set stays empty, and the hash sequence equals that of the
  player-path run.
- **AC-43 (rules 13, 14: headers)**: **GIVEN** a replay with a different
  `TICK_RATE`, **THEN** it is refused. **GIVEN** a different build ID, OS or CPU
  architecture, **THEN** it is "not re-verified" in debug views and the Runner,
  and the player-facing Debrief view model carries no badge (Battle Record
  rule 15). **GIVEN** a different content
  hash, **THEN** it is handled as Save/Load (#5) specifies, and never plays
  as verified.

### Performance: `tests/performance/sim_tick/` (BLOCKING for the tick-rate decision)

- **AC-44 (D10)**: **GIVEN** a headless run on the reference machine named in the
  ADR, at 60 Hz, the 2× player maximum, a 60 fps target, the pinned seed fixture
  with exactly 100 ships and 500 projectiles, and `SIM_BUDGET_MS` read from
  `ConstantsProvider` (never a literal), **WHEN** 3 runs each discard 600
  warm-up ticks and then measure at least 3,600 ticks:
  - **THEN** 60 Hz passes if the medians satisfy `p95 ≤ L`, `p99 ≤ 2 × L` and
    `max ≤ SIM_BUDGET_MS`, with `L = SIM_BUDGET_MS / ceil(60 × 2 / 60)` (4.0 ms
    at the current value of 8), **and** each scripted worst-case scene (mass
    kill, relay cut, full retarget) has its worst tick `≤ SIM_BUDGET_MS`.
  - On a fail, the 30 Hz fallback is judged the same way with `L = SIM_BUDGET_MS / 1`.
  - The report records every statistic, per-phase p95 and p99, the 2× stress
    load result (not gated), the machine and the build.
- **AC-45**: **GIVEN** `SIM_BUDGET_MS` is flagged `provisional: true` in the
  constants data, **WHEN** AC-44 passes, **THEN** its report's status is
  `PROVISIONAL`, not `PASS`. **GIVEN** the flag is set to false without a
  sign-off reference in the same data entry, **THEN** CI fails. The test needs
  no edit once the value is signed off.

### Feel and UI: manual, retained screenshot in `production/qa/evidence/` (BLOCKING)

- **AC-46 (Visual/Feel)**: **GIVEN** a battle in motion with ships, projectiles,
  particles, a combat tween and combat sound playing, **WHEN** it is paused at
  0.5×, at 1× and at 2× in turn, and once more after a speed change while held,
  **THEN**:
  - **Visual:** two captures of the battlefield viewport (HUD masked, camera
    still) taken 2 s apart are byte-identical;
  - **Nodes:** `CombatView.process_mode` is disabled, every registered combat
    Tween reports paused, every combat particle node has `speed_scale == 0`,
    and no combat `Timer` exists;
  - **Audio:** an audio spy records 0 new sim-sourced playbacks during the 2 s,
    and every combat one-shot is `stream_paused`;
  - **Running classes:** UI, camera pan and zoom, hover and markers still
    respond (one scripted pan and one hover, each captured).

  The captures are retained in `production/qa/evidence/sim_tick/`, and a lead
  signs off on the look.
- **AC-47 (UI)**: **GIVEN** 2× with the frame rate capped at 12 fps, **THEN** the
  speed display reads "1.6× (slowed)". When held, it reads "Paused".
- **AC-48 (UI)**: **GIVEN** the simulation is held with two queued orders and one
  latched ability, **THEN** markers for all three are visible and each can be
  cancelled.
- **AC-49 (UI)**: **GIVEN** `SYSTEM:save` or `PLANNING:case_file` is holding the
  simulation, **THEN** the resume control names the hold (for example
  "Saving…").

### Pillar alignment (CD-GDD-ALIGN revisions; BLOCKING)

- **AC-50 (rule 10)**: **GIVEN** a `BATTLE` that is Running, **WHEN** the player
  opens the Case File and then closes it, **THEN** the battle is Paused (player),
  0 ticks run until the player resumes, and the same holds for the Dossier and
  the Ledger. Unit test, `tests/unit/sim_tick/`.
- **AC-51 (rule 11, Battle start)**: **GIVEN** Battle start is enabled, **WHEN** a
  `BATTLE` context begins, including one whose fleets start already in contact,
  **THEN** `AUTO_PAUSE:battle_start` is present before tick 1 of that battle, and
  0 combat ticks run until the player resumes. **GIVEN** it is disabled, **THEN**
  the first tick runs on the next driver pass. **GIVEN** a headless run, **THEN**
  it is logged and no hold is added. Unit test.
- **AC-52 (rule 18, static)**: Hold-reason history, the speed selection and step
  counts are written only through a write-only `TelemetrySink` interface in
  `src/telemetry/`. **GIVEN** the codebase, **WHEN** CI runs the import lint,
  **THEN** it fails on any read of that data from outside `src/telemetry/`. It
  must be shown to fail on a planted violation at
  `tests/fixtures/lint/sim_tick/bad_reads_hold_history.gd`, as in AC-34.
- **AC-52b (rule 18, player-facing)**: **GIVEN** one seed and command log, played
  twice — once straight through at 1×, once with 20 pauses, 2 speed changes and
  30 single steps — **WHEN** each battle ends, **THEN** the Debrief text, any
  grade, the achievements awarded and the difficulty label are identical. The
  telemetry log of the second run does record the pauses. Integration test,
  `tests/integration/sim_tick/`.

*Specialist consulted: `qa-lead`. It flagged rules that were not independently
testable as written. The fixes:*
- *Rule 3 now says what P2 sees (AC-04).*
- *`AIM_QUANTUM` is defined (AC-09).*
- *The outcome of an unsustainable speed is specified in D6 (AC-17).*
- *The effect classes that freeze while held are listed in Interactions
  (AC-46).*
- *The jitter tolerance is stated (AC-32).*
- *Lint and render-purity checks cover rules 1, 2, 7 and 14 (AC-33, AC-34).*
- *The shader-time period check covers D8 (AC-35).*

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | ~~Does a battle start paused?~~ **Resolved 2026-10-28 (CD-GDD-ALIGN):** yes, through the default-on *Battle start* auto-pause (rule 11). The first-contact trigger could not cover it, because a trigger already true at battle start begins unarmed. | — | — |
| 2 | **Is `SIM_BUDGET_MS = 8` signed off, and which reference machine is the gate measured on?** It sets the spike's 4.0 ms-per-tick pass line (D10, AC-44/45). The machine is the minimum-spec hardware class, never the developer's PC. | technical-director | Before the tick-rate spike runs |
| 3 | **Does the tick-rate spike pass at 60 Hz?** About 100 ships and 500 projectiles, headless; if it fails, the 30 Hz fallback applies. | engine-programmer + performance-analyst | Pre-production, alongside the Combat Space GDD (#11) |
| 4 | **ADR-level choices:** the state-hash algorithm (the integer accumulator is decided, D2); our own small PRNG vs pinning `RandomNumberGenerator` per engine version; fixed-point vs float for the critical path; the Dictionary-iteration rule (insertion order is NOT SOURCEABLE in the engine reference). | technical-director | Tick/Pause/Determinism ADR, before any Core-layer implementation |
| 5 | **Combat audio at 2×:** pitch-shift, time-scale only, or neither? | audio-director | Audio Direction GDD (#52) |
| 6 | ~~**Is reading the Case File mid-battle a free puzzle?**~~ **Resolved 2026-10-30:** reading is allowed mid-battle, read-only; aids and actions are disabled in battle (Case File & Deduction). The hold key is `PLANNING:case_file`, owned by #31 at Tier 0. | Case File (#31) | Closed |
| 7 | **Cross-platform determinism after MVP.** MVP verifies same-platform only (rule 14). Should a CI hash test across Windows, Linux and the handheld target be added, with the transcendental-math and fixed-point choices it implies? | technical-director | Post-MVP, Tick/Pause/Determinism ADR revision |
| 8 | **Engine behaviours behind "frozen while held"** (`process_mode` on AnimationPlayer, Tween and particles; focus notifications on Steam Deck Game Mode) are NOT SOURCEABLE in the engine reference. | engine-programmer | Tick-rate spike |
| 6 | **Godot behaviour on focus loss and in low-processor mode:** what frame time arrives on resume? NOT SOURCEABLE; the driver clamps regardless (D2). | engine-programmer | Tick/Pause/Determinism ADR spike |
