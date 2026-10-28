# Prototype: Vigor vs Coherence (concept prototype)

**PROTOTYPE - NOT FOR PRODUCTION.** Throwaway code. Never import from or into the game.

**Status:** concluded 2026-10-28 — **PROCEED**, creative-director CONCERNS accepted with 4 conditions (see [REPORT.md](REPORT.md))

## Hypothesis

If the player flies a flagship through 3 back-to-back skirmishes against a linked
machine formation, they will target the relay ships first and see why the fight got
easier after the cut. True if: relay-first in at least 2 of the 3 skirmishes, AND the
Vigor ceiling after skirmish 3 is between 25% and 70% (near 0% = erosion feels
punishing; near 100% = Vigor has no cost).

Riskiest assumptions tested together: (1) the cut is satisfying and readable;
(2) Vigor ceiling erosion feels like rationing, not punishment.

## How to run

1. Open the Godot 4.7.2 Project Manager, click **Import**, choose
   `prototypes/vigor-coherence-concept/project.godot`, then press **F5**.
2. Controls: WASD move · mouse aim · left-click fire · Shift boost · Space pause ·
   R retry after a defeat · N new run from the summary screen.

Headless smoke run (code loads, loop completes; says nothing about feel):
`godot --headless --path prototypes/vigor-coherence-concept --fixed-fps 60 --quit-after 40000 -- --bot`

## What to watch for (and tell me)

- Did the link lines tell you the fight state without reading text? (solid / dashed / snapped)
- When you cut a relay, did you know why the fight got easier?
- Did the Vigor ring shrinking feel like a choice, or like being punished?
- Did you change how you fought in skirmish 2 and 3 because of the ceiling?
- Where were you confused?

## Cut on purpose

Escorts and fleet orders, Debrief, Dossier, economy, loot, saves, menus, audio, art,
the mystery, procedural content. Hull is restored between skirmishes; only the Vigor
ceiling carries over.

## Findings

One internal playtester (the owner), one full run. Full detail in [REPORT.md](REPORT.md).

- **Signals met:** relay-first 2/3 (target ≥ 2), final Vigor ceiling 58% (band 25–70%).
- **Best moment:** the formation breaking when the link was cut.
- **Worst moment:** the hard EXHAUSTED lockout on running dry ("not being able to shoot
  or really do anything"). The GDD should add a warning and make exhaustion change
  behaviour instead of disabling the ship.
- **Surprise:** movement and bullet feel were good even with placeholder shapes.
- **Caveats:** relay-first came from genre intuition, not from the link lines alone;
  whether the ceiling changed behaviour in later fights was not asked.
