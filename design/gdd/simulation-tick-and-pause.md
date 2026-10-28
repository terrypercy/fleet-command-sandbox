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

[To be designed]

## Detailed Design

### Core Rules

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

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
