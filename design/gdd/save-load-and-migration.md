# Save/Load & Migration

> **Status**: In Design
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — defeat costs time or resources, never the run, and the save policy keeps that true); Pillar 2 (The Truth Is Yours to Tell — one fixed truth per save, kept intact across every save, load and update)

## Summary

[To be designed]

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Runtime ID Service`

## Overview

Save/Load & Migration is the framework that writes a campaign to disk and reads
it back exactly. It is not one big save routine. **Every stateful system
registers its own versioned save section** (the systems index's contract), and
this system orchestrates them:
- it writes all sections together, at a tick boundary, into one file;
- it reads them back in a fixed order, validating each, with the Runtime ID
  section first;
- when a save is older than the game, it migrates each section forward through
  that section's own registered migrations.

A save is plain data: a versioned document of primitive values, content IDs
and Runtime IDs. It never contains engine objects, node trees, scripts or
resource paths (concept: "never save node trees").

Every save carries a **header** that says exactly what made it: the save format
version, the game build, the engine version, the OS and CPU architecture, the
tick rate, and the loaded content (the package list and content hashes). The
header lets the game decide, before reading anything else, whether the save can
load as-is, needs migration, needs the player's confirmation, or must be
refused (Simulation Tick & Pause, rule 14; Content Data & Mod Loading, Core Rule
13).

The player never sees sections or headers. They feel what this system
guarantees:
- **A save brings back the same galaxy.** The same ships, the same fragment in
  the hold, the same rival on the trail, and the same hidden truth, exactly
  where they left it.
- **Updates never cost a campaign.** An older save opens in a newer build,
  migrated forward. When something cannot be carried over, the game says what
  and why, before anything is lost.
- **Nothing is ever half-written.** A crash, a full disk or a power cut during a
  save never corrupts the previous save.

Without this system three things would break:
- Every stateful system would invent its own file format and versioning, and an
  update to any one of them could silently break every existing save.
- The determinism the rest of the game is built on (Simulation Tick & Pause,
  rule 14) would not survive a save and a load, because nothing would guarantee
  that state comes back bit-for-bit, in a fixed order.
- A long campaign, the "defeat costs time or resources, never the run" promise
  (Pillar 1), and the one truth per save (Pillar 2) would all depend on luck.

*How* saves are encoded and written (the file format, compression, the atomic
write, the section registry's data structure) is an implementation choice →
**becomes the save schema ADR** named in the concept's suggested ADRs. This GDD
specifies behaviour, guarantees and contracts only.

## Player Fantasy

**Put the war down; it waits for you.** The player experiences this system
**indirectly**. What they feel is that the game never has to be finished in one
sitting, and never takes a campaign away from them.

The player can walk away at any moment, even mid-volley, and come back to find
the campaign just as they left it: the half-turned flank, the queued orders, the
rival two systems out. An update, a crash or a power cut never takes the campaign
from them. When a new build changes something their save depended on, the game
names the one thing that changed, before anything is carried over, and then the
campaign opens.

*Anchor moment:* the machine line is closing, and the player has to leave. They
quit. Days later, after a patch, they load. The battle is paused on the same tick
with the same orders queued, and a single line explains the one thing the update
changed.

**Pillars served:**
- **Pillar 1, *Every Defeat Is a Lead*:** "defeat costs time or resources, never
  the run." Leaving costs nothing, and a crash or an update never costs the run.
  A defeat is answered by the Debrief and a return attempt, not by reloading the
  same moment (the battle save policy, Detailed Design).
- **Pillar 2, *The Truth Is Yours to Tell*:** one fixed truth per save, carried
  intact through every save, load and update.
- **The pillar-tension resolution:** "challenge should feel relaxing." Pause stops
  the battle; this system lets the player stop the game itself.

**Tone:** patient and dependable. The verbs are *waits, keeps, carries,
resumes*.

**This system must never make the player feel:**
- **"I lost hours because the game crashed, or because I updated."**
- **"My campaign was quietly changed under me."** Every migration loss is named,
  and confirmed by the player, before it happens.

*Shaped by `creative-director` (framing A, "Put the war down; it waits for you").
Framing B, "Your campaign outlives every update", was judged too narrow; its
migration beat lives in the paragraph above.*

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
