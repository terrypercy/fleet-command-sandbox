# Systems Index: The Makers' Debt

> **Status**: Draft
> **Created**: 2026-10-28
> **Last Updated**: 2026-10-28 (Simulation Tick & Pause designed)
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

The Makers' Debt needs two engines that meet in one loop. The first is a
pausable, captain-in-the-line fleet battle in which organic ships spend
**Vigor** and machine fleets run on relayed **Coherence**. The second is a
seeded, fixed-truth mystery in which archive fragments shape what each faction
believes about who built the machines. The fail → Debrief → prepare → return
loop joins them (*Pillar 1: Every Defeat Is a Lead*). A loss is explained by the
After-Action Debrief and recorded in the Dossier. What the player shares changes
which faction lends ships for the return (*Pillar 2: The Truth Is Yours to
Tell*, ranked first). Everything the player needs to optimise is surfaced in the
Dossier, Ledger, Debrief and Case File (*Pillar 4: Plan in the Open*). The
organic/machine asymmetry runs through combat, AI, art and lore (*Pillar 5:
Living Against Made*), and the flagship is always flown by hand (*Pillar 3:
Hands on the Helm*).

This index holds **57 systems** (36 explicit in the concept, 21 inferred).
Tiers: **43 MVP** (Tier 0, several at stub depth — see the Producer Note below
the Priority Tiers table), **6 Vertical Slice**, **4 Alpha** (the rest of the
Early Access feature set) and **4 Full Vision**. The MVP tier is build order,
not a scope cut: the full feature list remains the vision.

### System-by-system rationale

**Foundation (7).** The architecture direction is that the simulation is
separate from presentation, runs on a fixed tick, and runs headless.
**Simulation Tick & Pause** is that tick. Pause freezes the simulation, never
the screen or the planning UI. **Deterministic RNG & Seed Streams** gives every
consumer a named stream derived from the save seed. Truth seeding, hit rolls, AI
scoring, loot and missions therefore cannot change one another's results, and
the AI-vs-AI runner can reproduce a battle from a seed. **Runtime ID Service**
issues stable IDs for live things: ships, fleets, fragments and rival
investigators. Saves, the event bus and the Debrief all refer to them. **Content
Data & Mod Loading** turns validated JSON/CSV into typed classes under
namespaced IDs (`base:…`). It rejects negative weights, and it holds the
counter taxonomy as data so mods can extend it. **Save/Load & Migration** is a
framework: every stateful system registers a versioned section, and the
section list belongs in each GDD's Dependencies. **Input & Controls** covers
piloting and orders on mouse and keyboard, with full remapping.
**Gameplay Settings & Modifiers** provides the accessibility and difficulty
values that Vigor, AI, Battle Resolution and the HUD read. It sits in
Foundation so those values are designed in from the start, not retrofitted; only
the option screens are Polish.

**Core (11).** **World Clock** counts game days. It reads `is_held()` from Simulation Tick
& Pause, which owns the single hold-reason set that pause and planning screens
push to, so the clock never depends on Presentation.
**Combat Event Bus & Battle Record** carries typed combat events and records
each battle as a log; the Debrief is a pure function over that log.
**Hulls & Ship Definition** is the hull schema: size classes, mounts and stats.
**Combat Space** owns live ship and fleet instances, movement, a spatial index
for hit and target queries, and the projectile pool. Each system owns its own
data on a ship and the others read it through queries, so no shared ship object
grows. **Weapons & Damage** resolves hits inside the simulation, not through
physics callbacks. **Vigor** owns ceiling erosion, the floor, the early warning
and the effects of running dry. Its design test is that a Starsector player
cannot map it 1:1 onto flux. **Coherence & Links** owns the relay graph, updated
on events, plus jamming and fragmentation. Vigor and Coherence are where the
*Living Against Made* asymmetry is established; the two resource models must
never collapse into one. **Flagship Piloting** is direct control of the
flagship. **Truth Seeding & Candidates** seeds the true maker per save, from 3-4
candidates (3 in Tier 0, the third text-only), plus the per-race attribute
table. **Faction Reputation & Standing** is a plain ledger: standing is spent on
care and written by Belief. **Credits, Upkeep & Sinks** holds the bankruptcy
floor, the defeat-cost limit and the money sinks, suppression included. The
design review found no money sink, so this system exists to provide one.

**Feature (26).** The mystery chain comes first in design order.
- **Archive Fragments & Evidence** presents the finite seeded set: template
  text, the provenance stamp, placement, and how a fragment discovery is shown
  (a short artifact with a provenance stamp). What a claim means, provenance
  reliability, independence groups and case generation belong to Truth
  Seeding & Candidates (#16, 2026-10-30).
- **Faction Belief & Blame** holds each faction's belief distribution, the
  reaction matrix and the derived public history, plus the record of what was
  shared, to whom and when. It also owns **suppression** — the in-case action
  of buying, destroying or sealing a known fragment, and its record — with
  Credits owning the money sink and upkeep. It owns how share and exposure beats
  are presented (templates with race slots).
- **Case File & Deduction** reasons only over held fragments. Ruling a candidate
  out needs at least 2 reliable contradictions.
- **Exposure & Rival Investigation** runs visible, deterministic investigators
  on the world clock.

Combat follows.
- **Fleet Orders** is the order set, including queued orders while paused and
  retreat.
- **Ship AI** is steering, targeting and the injected Vigor/Coherence posture
  policies, and it emits a reason event for every lethal behaviour.
- **Fleet Coordination** turns orders into tasks and formations. It is split
  from Ship AI so neither becomes one oversized system.
- **Battle Resolution & Retreat** emits an outcome (win, loss or retreat)
  within the bounded defeat cost. It never charges costs itself.
- **Machine Nodes & Strongholds** owns the authored strongholds and the counter
  taxonomy.
- **After-Action Debrief** maps cause to counter: 4-6 causes, with an honest
  "unknown".
- **AI-vs-AI Runner & AI Debug Tools** is Tier 0. Its stand-in captain bot flies
  the flagship through the player's command interface. It verifies that every
  Dossier no-ally counter can win and that Debrief causes are right.
- **Allied Lending** lends ships based on a faction's belief: it lends when
  blame lands on rivals and refuses when that faction is blamed itself.

The world comes next.
- **Sector Map & Travel** covers the 3-5 hand-made systems in Tier 0.
- **Points of Interest** are derelicts, archives and witnesses, the
  non-stronghold sources of fragments.
- **Ports, Rest & Care**: rest costs time only and is available at any port that
  is not hostile. Care costs standing.
- **Refit & Loadout** is where a counter-fleet is built. It is the loadout
  change the pass bar logs.
- **Markets & Trade** funds refits.

Later tiers:
- **Reckoning & Endings** (Vertical Slice build, but designed at #23, next to
  Belief) is the player-called scene with an ending classifier that has 4
  outcomes. The classifier defines what Belief's "names" and "split" thresholds
  are for, so its GDD is written early. It reads suppression state; it does not
  own it.
- **Salvage & Recovery** (Vertical Slice).
- **Contracts & Missions** (Alpha) becomes procedural there.
- **Loot & Crafting** (Alpha): gear unlocks a Dossier counter, never raw power.
- **Captain Skills** (Alpha): like Loot, a skill widens the player's options (a
  counter, an order, a tell) and never adds flat power — the "not grind-walled"
  anti-pillar.
- **Background Faction Economy** (Alpha) writes only through the Markets and
  Contracts APIs.
- **Officers** (Full Vision).
- **Colonies & Industry** (Full Vision) serves the mystery and alliances, not a
  4X.
- **Breakaway Machine Faction** (Full Vision): mixed fleets, unreliable
  testimony.

**Presentation (8).**
- **Camera & Combat View** sets the combat zoom that the 32 px readability tests
  assume. It must never drive the tick.
- **Combat HUD & Tactical Overlay** shows link patterns (solid, dashed, snapped),
  Vigor glow and posture tells.
- **Dossier** shows per-node weaknesses, counters, and a helper faction with its
  lending condition (never a suggested blame shift).
- **Ledger** (Vertical Slice) covers markets and trade routes. Markets cannot
  leave stub depth until the Ledger ships with it.
- **Public History Screen** combines the Case File, the sharing preview and the
  exposure readout into one screen.
- **Port & Fleet Management Screens** hold refit, market and fleet.
- **Menus, Settings & Save UI**.
- **Audio Direction & Adaptive Music** (Vertical Slice) gives organic and machine
  their own palettes, frames defeat as a lead (it listens to Battle Resolution
  and the Debrief), and scores the mystery beats (fragment discovery,
  exposure). Tier 0 gets one placeholder defeat-to-Debrief cue.

**Polish (5).**
- **Onboarding & Opening Sequence** has an MVP stub: a guided first fight plus
  text cards, then the intended loss, exempt from lasting costs, and the first
  Debrief. The full authored first 10 minutes is Vertical Slice.
- **Telemetry & Playtest Logging** subscribes to events and never to UI. The MVP
  pass bar is measured from its logs.
- **Accessibility Options UI** and **Difficulty Options UI** are Vertical Slice
  screens over the Foundation provider.
- **Platform Integration** (Steam/Epic, achievements, cloud saves, Workshop) is
  Full Vision.

### Relationship analysis

- **The combat spine.** Tick → Combat Space → Weapons, Vigor and Coherence →
  Ship AI and Fleet Coordination → Battle Resolution → Debrief → Dossier. This is
  the riskiest chain: two AI families, hit resolution in the simulation, and
  attributable failures. The runner verifies it end to end.
- **The mystery spine.** Truth Seeding → Fragments → Belief → Case File,
  Exposure, Lending, Reckoning. Each faction's belief is the hub. Lending, the
  Public History screen, Exposure and the Reckoning all read it, and only Belief
  writes belief state.
- **Where the two halves meet.** Allied Lending (belief → ships in the return
  fleet), the Debrief and Dossier (naming a helper faction and its lending
  condition), and Ports, Rest & Care (hostility and standing change where a ship
  can recover). These three are where *Pillar 2* touches *Pillar 1*. If they are
  thin, the mystery looks decorative.
- **The clock as a shared pressure.** The World Clock drives rest days,
  investigator progress and (from Alpha) contract expiry. Credits caps the cost
  of a defeat so the clock can never make a retry unaffordable.
- **Data and persistence underneath everything.** Content Data, IDs, RNG streams
  and Save are bottlenecks. A late change to any of them ripples through every
  system, so they are designed first and kept small.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Simulation Tick & Pause | Core | MVP | In Review | design/gdd/simulation-tick-and-pause.md | — |
| 2 | Deterministic RNG & Seed Streams (inferred) | Core | MVP | Designed | design/gdd/deterministic-rng-and-seed-streams.md | — |
| 3 | Runtime ID Service (inferred) | Core | MVP | Designed | design/gdd/runtime-id-service.md | — |
| 4 | Content Data & Mod Loading | Core | MVP | Designed | design/gdd/content-data-and-mod-loading.md | — |
| 5 | Save/Load & Migration | Persistence | MVP | Designed | design/gdd/save-load-and-migration.md | Simulation Tick & Pause, Deterministic RNG & Seed Streams, Runtime ID Service, Content Data & Mod Loading |
| 6 | Input & Controls (inferred) | Core | MVP | Designed | design/gdd/input-and-controls.md | Simulation Tick & Pause |
| 7 | Gameplay Settings & Modifiers (inferred) | Core | MVP | Designed | design/gdd/gameplay-settings-and-modifiers.md | Content Data & Mod Loading, Input & Controls |
| 8 | World Clock | Core | MVP | Designed | design/gdd/world-clock.md | Simulation Tick & Pause |
| 9 | Combat Event Bus & Battle Record | Core | MVP | Designed | design/gdd/combat-event-bus-and-battle-record.md | Simulation Tick & Pause, Deterministic RNG & Seed Streams, Runtime ID Service |
| 10 | Hulls & Ship Definition (inferred) | Gameplay | MVP | Designed | design/gdd/hulls-and-ship-definition.md | Content Data & Mod Loading |
| 11 | Combat Space (inferred) | Core | MVP | Designed | design/gdd/combat-space.md | Simulation Tick & Pause, Runtime ID Service, Hulls & Ship Definition |
| 12 | Weapons & Damage (inferred) | Gameplay | MVP | Designed | design/gdd/weapons-and-damage.md | Simulation Tick & Pause, Deterministic RNG & Seed Streams, Combat Event Bus & Battle Record, Combat Space |
| 13 | Vigor | Gameplay | MVP | Designed | design/gdd/vigor.md | Simulation Tick & Pause, Gameplay Settings & Modifiers, Combat Event Bus & Battle Record, Combat Space |
| 14 | Coherence & Links | Gameplay | MVP | Designed | design/gdd/coherence-and-links.md | Simulation Tick & Pause, Combat Event Bus & Battle Record, Combat Space |
| 15 | Flagship Piloting | Gameplay | MVP | Designed | design/gdd/flagship-piloting.md | Simulation Tick & Pause, Input & Controls, Combat Space, Weapons & Damage, Vigor, Coherence & Links |
| 16 | Truth Seeding & Candidates (inferred) | Narrative | MVP | Designed | design/gdd/truth-seeding-and-candidates.md | Deterministic RNG & Seed Streams, Content Data & Mod Loading, Save/Load & Migration |
| 17 | Faction Reputation & Standing | Progression | MVP | Designed | design/gdd/faction-reputation-and-standing.md | Content Data & Mod Loading, Save/Load & Migration |
| 18 | Credits, Upkeep & Sinks (inferred) | Economy | MVP | Designed | design/gdd/credits-upkeep-and-sinks.md | Save/Load & Migration, World Clock |
| 19 | Fleet Orders | Gameplay | MVP | Designed | design/gdd/fleet-orders.md | Simulation Tick & Pause, Input & Controls, Combat Space, Runtime ID Service |
| 20 | Ship AI | Gameplay | MVP | Designed | design/gdd/ship-ai.md | Simulation Tick & Pause, Deterministic RNG & Seed Streams, Gameplay Settings & Modifiers, Combat Event Bus & Battle Record, Combat Space, Weapons & Damage, Vigor, Coherence & Links, Runtime ID Service |
| 21 | Fleet Coordination | Gameplay | MVP | Designed | design/gdd/fleet-coordination.md | Simulation Tick & Pause, Deterministic RNG & Seed Streams, Fleet Orders, Ship AI, Runtime ID Service |
| 22 | Battle Resolution & Retreat | Gameplay | MVP | Designed | design/gdd/battle-resolution-and-retreat.md | Simulation Tick & Pause, Combat Event Bus & Battle Record, Weapons & Damage, Fleet Orders, Runtime ID Service |
| 23 | Machine Nodes & Strongholds | Gameplay | MVP | Designed | design/gdd/machine-nodes-and-strongholds.md | Content Data & Mod Loading, Hulls & Ship Definition, Coherence & Links, Fleet Coordination |
| 24 | After-Action Debrief | Gameplay | MVP | Designed | design/gdd/after-action-debrief.md | Simulation Tick & Pause, Deterministic RNG & Seed Streams, Combat Event Bus & Battle Record, Battle Resolution & Retreat, Machine Nodes & Strongholds, Runtime ID Service |
| 25 | AI-vs-AI Runner & AI Debug Tools | Meta | MVP | Designed | design/gdd/ai-vs-ai-runner-and-ai-debug-tools.md | Simulation Tick & Pause, Deterministic RNG & Seed Streams, Combat Event Bus & Battle Record, Flagship Piloting, Ship AI, Fleet Coordination, Machine Nodes & Strongholds, Runtime ID Service |
| 26 | Sector Map & Travel | Gameplay | MVP | Designed | design/gdd/sector-map-and-travel.md | Deterministic RNG & Seed Streams, Content Data & Mod Loading, World Clock |
| 27 | Ports, Rest & Care | Gameplay | MVP | Designed | design/gdd/ports-rest-and-care.md | World Clock, Vigor, Faction Reputation & Standing, Sector Map & Travel |
| 28 | Archive Fragments & Evidence | Narrative | MVP | Designed | design/gdd/archive-fragments-and-evidence.md | Runtime ID Service, Content Data & Mod Loading, Truth Seeding & Candidates |
| 29 | Points of Interest | Gameplay | MVP | Designed | design/gdd/points-of-interest.md | Sector Map & Travel, Archive Fragments & Evidence |
| 30 | Faction Belief & Blame | Narrative | MVP | Designed | design/gdd/faction-belief-and-blame.md | Truth Seeding & Candidates, Faction Reputation & Standing, Credits, Upkeep & Sinks, Archive Fragments & Evidence, Runtime ID Service |
| 31 | Case File & Deduction | Narrative | MVP | Designed | design/gdd/case-file-and-deduction.md | Truth Seeding & Candidates, Archive Fragments & Evidence |
| 32 | Exposure & Rival Investigation | Narrative | MVP | Designed | design/gdd/exposure-and-rival-investigation.md | Deterministic RNG & Seed Streams, World Clock, Archive Fragments & Evidence, Faction Belief & Blame, Runtime ID Service |
| 33 | Allied Lending | Gameplay | MVP | Designed | design/gdd/allied-lending.md | Hulls & Ship Definition, Fleet Coordination, Faction Belief & Blame, Runtime ID Service |
| 34 | Reckoning & Endings | Narrative | Vertical Slice | Not Started | — | Truth Seeding & Candidates, Credits, Upkeep & Sinks, Faction Belief & Blame, Case File & Deduction, Exposure & Rival Investigation |
| 35 | Refit & Loadout | Progression | MVP | Designed | design/gdd/refit-and-loadout.md | Hulls & Ship Definition, Weapons & Damage, Credits, Upkeep & Sinks |
| 36 | Salvage & Recovery | Economy | Vertical Slice | Not Started | — | Credits, Upkeep & Sinks, Battle Resolution & Retreat, Runtime ID Service |
| 37 | Markets & Trade | Economy | MVP | In Design | design/gdd/markets-and-trade.md | Credits, Upkeep & Sinks, Sector Map & Travel |
| 38 | Contracts & Missions | Economy | Alpha | Not Started | — | Deterministic RNG & Seed Streams, World Clock, Faction Reputation & Standing, Credits, Upkeep & Sinks, Sector Map & Travel |
| 39 | Loot & Crafting | Progression | Alpha | Not Started | — | Deterministic RNG & Seed Streams, Content Data & Mod Loading, Refit & Loadout, Salvage & Recovery |
| 40 | Captain Skills | Progression | Alpha | Not Started | — | Save/Load & Migration, Flagship Piloting |
| 41 | Officers | Progression | Full Vision | Not Started | — | Ship AI, Captain Skills |
| 42 | Colonies & Industry | Economy | Full Vision | Not Started | — | Faction Reputation & Standing, Credits, Upkeep & Sinks, Sector Map & Travel |
| 43 | Background Faction Economy | Economy | Alpha | Not Started | — | World Clock, Faction Reputation & Standing, Markets & Trade, Contracts & Missions |
| 44 | Breakaway Machine Faction | Gameplay | Full Vision | Not Started | — | Coherence & Links, Ship AI, Archive Fragments & Evidence, Allied Lending, Runtime ID Service |
| 45 | Camera & Combat View (inferred) | Core | MVP | Not Started | — | Simulation Tick & Pause, Input & Controls, Combat Space, Runtime ID Service |
| 46 | Combat HUD & Tactical Overlay (inferred) | UI | MVP | Not Started | — | Simulation Tick & Pause, Gameplay Settings & Modifiers, Vigor, Coherence & Links, Fleet Orders, Ship AI, Camera & Combat View, Runtime ID Service |
| 47 | Dossier | UI | MVP | Not Started | — | Simulation Tick & Pause, Machine Nodes & Strongholds, After-Action Debrief, Allied Lending |
| 48 | Ledger | UI | Vertical Slice | Not Started | — | Simulation Tick & Pause, Sector Map & Travel, Markets & Trade |
| 49 | Public History Screen (inferred) | UI | MVP | Not Started | — | Simulation Tick & Pause, Faction Belief & Blame, Case File & Deduction, Exposure & Rival Investigation |
| 50 | Port & Fleet Management Screens (inferred) | UI | MVP | Not Started | — | Ports, Rest & Care, Refit & Loadout, Markets & Trade |
| 51 | Menus, Settings & Save UI (inferred) | UI | MVP | Not Started | — | Simulation Tick & Pause, Save/Load & Migration, Input & Controls, Gameplay Settings & Modifiers |
| 52 | Audio Direction & Adaptive Music | Audio | Vertical Slice | Not Started | — | Combat Event Bus & Battle Record, Vigor, Coherence & Links, Battle Resolution & Retreat, After-Action Debrief, Archive Fragments & Evidence, Exposure & Rival Investigation |
| 53 | Onboarding & Opening Sequence | Meta | MVP | Not Started | — | Battle Resolution & Retreat, Machine Nodes & Strongholds, After-Action Debrief, Dossier |
| 54 | Telemetry & Playtest Logging (inferred) | Meta | MVP | Not Started | — | Simulation Tick & Pause, Deterministic RNG & Seed Streams, Combat Event Bus & Battle Record, Faction Belief & Blame, Exposure & Rival Investigation, Refit & Loadout, Runtime ID Service |
| 55 | Accessibility Options UI (inferred) | Meta | Vertical Slice | Not Started | — | Gameplay Settings & Modifiers, Menus, Settings & Save UI |
| 56 | Difficulty Options UI (inferred) | Meta | Vertical Slice | Not Started | — | Gameplay Settings & Modifiers, Menus, Settings & Save UI |
| 57 | Platform Integration | Meta | Full Vision | Not Started | — | Save/Load & Migration |

---

## Categories

| Category | Description | Systems in this game |
|----------|-------------|----------------------|
| **Core** | Foundation systems everything depends on | Simulation Tick & Pause, RNG Streams, Runtime IDs, Content Data, Input, Settings & Modifiers, World Clock, Event Bus & Battle Record, Combat Space, Camera |
| **Gameplay** | The systems that make the game fun | Hulls, Weapons & Damage, Vigor, Coherence, Piloting, Fleet Orders, Ship AI, Fleet Coordination, Battle Resolution, Strongholds, Debrief, Sector Map, Ports/Rest/Care, Points of Interest, Allied Lending, Breakaways |
| **Progression** | How the player grows over time | Reputation & Standing, Refit & Loadout, Loot & Crafting, Captain Skills, Officers |
| **Economy** | Resource creation and consumption | Credits/Upkeep/Sinks, Markets & Trade, Salvage, Contracts & Missions, Colonies, Background Economy |
| **Persistence** | Save state and continuity | Save/Load & Migration |
| **UI** | Player-facing information displays | Combat HUD, Dossier, Ledger, Public History Screen, Port & Fleet Screens, Menus/Settings/Save UI |
| **Audio** | Sound and music systems | Audio Direction & Adaptive Music |
| **Narrative** | Story and evidence delivery | Truth Seeding, Archive Fragments, Faction Belief & Blame, Case File, Exposure & Rival Investigation, Reckoning & Endings |
| **Meta** | Systems outside the core game loop | AI-vs-AI Runner & Debug Tools, Onboarding, Telemetry, Accessibility Options UI, Difficulty Options UI, Platform Integration |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | Tier 0 first playable — tests the fail → Debrief → prepare → return loop and the mystery slice against the concept's pass bar | Design FIRST |
| **Vertical Slice** | Required for one complete, polished area. Demonstrates the full experience. | Vertical slice — one region end to end, including the Reckoning | Design SECOND |
| **Alpha** | All features present in rough form. Complete mechanical scope, placeholder content OK. | Early Access launch feature set (Tier 1) | Design THIRD |
| **Full Vision** | Polish, edge cases, nice-to-haves, and content-complete features. | 1.0 (Tier 2) and later | Design as needed |

> **Creative Director Note** (CD-SYSTEMS: CONCERNS → revisions applied 2026-10-28) (MVP): the set and tiering serve the core fantasy and both spines; these conditions bind the Tier 0 stubs and the GDDs. **#33 Allied Lending stub holds on four conditions** — write them into its acceptance criteria: (a) it works both ways — the escort is granted when blame on the faction's rivals passes a threshold and refused or withdrawn when blame on the lending faction itself passes one, reading Belief's distribution, not Standing; (b) it is previewed — the share preview and the Dossier's helper-faction line show "this share grants / loses the escort" before commit; (c) the escort is real ships that join the return fleet under Fleet Orders, not a stat buff, and the runner still proves every no-ally counter wins without them; (d) it covers the seed landing on the escort's own race. **#32 Exposure stub:** the rival's timer targets one specific unfound seeded fragment, and exposure fires only if that fragment reliably contradicts the current public history — never on a timer alone; the readout (held reliable contradictions plus the rival's progress) stays visible. **#49 Public History stub:** the Case File text panel keeps the first-order share preview and the exposure change (pass-bar item 3 and the "not wiki-dependent" anti-pillar depend on them). **Port screen (MVP):** shows credits, upkeep and the defeat-cost cap, so nothing about the economy is hidden in Tier 0. **Validation:** in Tier 0 playtests at least one tester changes or keeps a share to gain or keep the escort; an exposure fires only against a contradicted public history; no tester lies without paying a visible cost.
>
> **Creative Director Note** (Vertical Slice): **#34 Reckoning & Endings** keeps its Vertical Slice build tier but is designed at #23, next to Faction Belief; suppression is owned by Faction Belief (action and record) and Credits (sink), and Reckoning only reads it. **#48 Ledger** gates Markets leaving stub depth. **#52 Audio** depends on Battle Resolution, the Debrief, Archive Fragments and Exposure.
>
> **Creative Director Note** (Alpha): **#40 Captain Skills** takes the same rule as Loot & Crafting — a skill widens options and never adds flat power; put it in the GDD's Player Fantasy and acceptance criteria.

> **Producer Note (PR-SCOPE: OPTIMISTIC → adjustments applied 2026-10-28, owner's choice "stub and re-baseline")** (MVP): Tier 0 grew after the concept-stage estimate (AI runner moved in, larger mystery slice, 5 boundary systems), so it is **re-baselined to 14-24 months** (cumulative 16-28 months from today); Early Access 2.5-4.5 years; 1.0 unchanged at 5-10 years, Low confidence. Re-estimate after 3 months of Tier 0. These MVP systems are built at **stub depth** in Tier 0 and finished in the Vertical Slice, behind their final interfaces: **#37 Markets & Trade** → a fixed-price refit shop inside Credits/Refit; **#33 Allied Lending** → a fixed escort granted when a faction's belief crosses a threshold (telemetry logged, unscored — creative-director to confirm the coupling test holds); **#29 Points of Interest** → fragment pickups placed on the sector map; **#27 Ports, Rest & Care** and **#50 Port & Fleet Management Screens** → one port screen, Vigor recovery only; **#49 Public History Screen** → a text panel inside the Case File; **#7 Gameplay Settings & Modifiers** → a constants provider behind the final interface; **#32 Exposure & Rival Investigation** → one rival on a scripted world-clock timer calling Belief's API; **#54 Telemetry** → a JSON dump of the Battle Record plus loadout snapshots. **#53 Onboarding** moves into the MVP as a stub (one guided first fight plus text cards). **Kept at full Tier 0 depth:** Debrief v1 (4-6 causes), AI legibility and the runner, save versioning and migration, stable IDs, Faction Belief. **Build order:** get a thin end-to-end mystery path working (fragment → Case File → share → relation change) before polishing combat AI — a thin mystery slice would make pass-bar item (3) untestable. **Checkpoint (not a tier split):** around months 6-8 of Tier 0, the runner shows each Dossier counter beating its stronghold. Art supply is still the largest open driver of the Early Access date.

---

## Dependency Map

Within a layer, a system may depend on one listed above it in the same layer.

### Foundation Layer (no dependencies)

1. Simulation Tick & Pause — every real-time system runs on its fixed tick; it runs headless, with no scene nodes, so the AI-vs-AI runner can drive it
2. Deterministic RNG & Seed Streams — named streams per consumer derived from the save seed, so no system's random draws change another's
3. Runtime ID Service — stable IDs for live ships, fleets, fragments and investigators, referenced by saves, events and the Debrief
4. Content Data & Mod Loading — all hulls, weapons, fragments, races and the counter taxonomy are validated data
5. Save/Load & Migration — depends on: Runtime ID Service. A framework every stateful system registers a versioned section with
6. Input & Controls — piloting and orders, remapping from day one
7. Gameplay Settings & Modifiers — depends on: Content Data, Input. Accessibility and difficulty values read by gameplay, so they are never retrofitted

### Core Layer (depends on foundation)

1. World Clock — depends on: Simulation Tick (hold-reasons API for pause and planning screens)
2. Combat Event Bus & Battle Record — depends on: Simulation Tick, Runtime IDs
3. Hulls & Ship Definition — depends on: Content Data
4. Combat Space — depends on: Simulation Tick, Runtime IDs, Hulls
5. Weapons & Damage — depends on: RNG Streams, Event Bus, Combat Space
6. Vigor — depends on: Settings & Modifiers, Event Bus, Combat Space
7. Coherence & Links — depends on: Event Bus, Combat Space
8. Flagship Piloting — depends on: Input, Combat Space, Weapons & Damage, Vigor, Coherence
9. Truth Seeding & Candidates — depends on: RNG Streams, Content Data, Save
10. Faction Reputation & Standing — depends on: Content Data, Save
11. Credits, Upkeep & Sinks — depends on: Save, World Clock

### Feature Layer (depends on core)

1. Fleet Orders — depends on: Simulation Tick, Input, Combat Space
2. Ship AI — depends on: RNG Streams, Settings & Modifiers, Event Bus, Combat Space, Weapons & Damage, Vigor, Coherence
3. Fleet Coordination — depends on: Fleet Orders, Ship AI
4. Battle Resolution & Retreat — depends on: Event Bus, Weapons & Damage, Fleet Orders (emits an outcome; Salvage and Credits consume it)
5. Machine Nodes & Strongholds — depends on: Content Data, Hulls, Coherence, Fleet Coordination
6. After-Action Debrief — depends on: Event Bus & Battle Record, Battle Resolution, Strongholds
7. AI-vs-AI Runner & AI Debug Tools — depends on: Simulation Tick, RNG Streams, Event Bus, Flagship Piloting, Ship AI, Fleet Coordination, Strongholds
8. Sector Map & Travel — depends on: Content Data, World Clock
9. Ports, Rest & Care — depends on: World Clock, Vigor, Reputation & Standing, Sector Map
10. Archive Fragments & Evidence — depends on: Runtime IDs, Content Data, Truth Seeding
11. Points of Interest — depends on: Sector Map, Archive Fragments
12. Faction Belief & Blame — depends on: Truth Seeding, Reputation & Standing, Credits (suppression is a sink), Archive Fragments
13. Case File & Deduction — depends on: Truth Seeding, Archive Fragments
14. Exposure & Rival Investigation — depends on: RNG Streams, World Clock, Archive Fragments, Faction Belief
15. Allied Lending — depends on: Hulls, Fleet Coordination, Faction Belief
16. Reckoning & Endings — depends on: Truth Seeding, Credits, Faction Belief, Case File, Exposure (reads suppression state; does not own it)
17. Refit & Loadout — depends on: Hulls, Weapons & Damage, Credits
18. Salvage & Recovery — depends on: Credits, Battle Resolution
19. Markets & Trade — depends on: Credits, Sector Map
20. Contracts & Missions — depends on: RNG Streams, World Clock, Reputation & Standing, Credits, Sector Map
21. Loot & Crafting — depends on: RNG Streams, Content Data, Refit & Loadout, Salvage
22. Captain Skills — depends on: Save, Flagship Piloting
23. Officers — depends on: Ship AI, Captain Skills
24. Colonies & Industry — depends on: Reputation & Standing, Credits, Sector Map
25. Background Faction Economy — depends on: World Clock, Reputation & Standing, Markets & Trade, Contracts & Missions
26. Breakaway Machine Faction — depends on: Coherence, Ship AI, Archive Fragments, Allied Lending

### Presentation Layer (depends on features)

1. Camera & Combat View — depends on: Simulation Tick, Input, Combat Space (never drives the tick)
2. Combat HUD & Tactical Overlay — depends on: Settings & Modifiers, Vigor, Coherence, Fleet Orders, Ship AI, Camera
3. Dossier — depends on: Strongholds, Debrief, Allied Lending
4. Ledger — depends on: Sector Map, Markets & Trade
5. Public History Screen — depends on: Faction Belief, Case File, Exposure
6. Port & Fleet Management Screens — depends on: Ports/Rest/Care, Refit & Loadout, Markets & Trade
7. Menus, Settings & Save UI — depends on: Save, Input, Settings & Modifiers
8. Audio Direction & Adaptive Music — depends on: Event Bus, Vigor, Coherence, Battle Resolution, Debrief (framing defeat as a lead), Archive Fragments, Exposure (mystery beats)

### Polish Layer (depends on everything)

1. Onboarding & Opening Sequence — depends on: Battle Resolution, Strongholds, Debrief, Dossier
2. Telemetry & Playtest Logging — depends on: Event Bus & Battle Record, Faction Belief, Exposure, Refit & Loadout (subscribes to events, never to UI)
3. Accessibility Options UI — depends on: Settings & Modifiers, Menus/Settings/Save UI
4. Difficulty Options UI — depends on: Settings & Modifiers, Menus/Settings/Save UI
5. Platform Integration — depends on: Save

**Simulation Tick & Pause** is also a direct dependency of Weapons & Damage, Vigor, Coherence & Links, Ship AI, Fleet Coordination, Battle Resolution & Retreat (phase handlers), the After-Action Debrief, Dossier, Ledger and Public History Screen (planning holds), Combat HUD, Menus/Settings/Save UI and Telemetry (added from its GDD, 2026-10-28).

**Bottlenecks** (many dependents — high risk, design first and keep small): Simulation Tick & Pause, Content Data & Mod Loading, Combat Event Bus & Battle Record, Combat Space, Hulls, Weapons & Damage, Ship AI, Archive Fragments, Faction Belief & Blame, Credits.
**Leaf nodes** (safe to design late): Officers, Colonies & Industry, Background Faction Economy, Breakaway Machine Faction, Platform Integration, Audio Direction. (Not the Ledger: it is a protected Pillar 4 tool and gates Markets leaving stub depth.)

> **Technical Director Note (TD-SYSTEM-BOUNDARY: CONCERNS → all changes applied 2026-10-28):** added Combat Space, Deterministic RNG & Seed Streams, Runtime ID Service, Fleet Coordination (split from Ship AI) and Gameplay Settings & Modifiers (Accessibility and Difficulty split into a Foundation provider plus Polish option screens); the Event Bus gained a Battle Record, and Faction Belief owns the public-history share record; Camera moved to Presentation and the AI-vs-AI Runner to Feature; dependency fixes (Fleet Orders no longer depends on Piloting; Battle Resolution emits an outcome rather than depending on Credits; Case File and Reckoning read Truth Seeding directly; the runner's captain bot uses the player's command interface; Telemetry never reads UI); the Vigor ↔ AI contract corrected and the Markets/Contracts ↔ Background Economy contract added (see Circular Dependencies). **Rule for every GDD:** each system owns its own data on a ship and others read it through queries; every stateful system lists its save section in Dependencies. **Boundary check by the end of Tier 0:** the headless runner reproduces the same battle twice from one seed, and every Debrief cause traces to a Battle Record event.

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Simulation Tick & Pause | MVP | Foundation | engine-programmer, godot-specialist | M |
| 2 | Deterministic RNG & Seed Streams | MVP | Foundation | engine-programmer, systems-designer | S |
| 3 | Runtime ID Service | MVP | Foundation | lead-programmer | S |
| 4 | Content Data & Mod Loading | MVP | Foundation | tools-programmer, systems-designer, security-engineer | M |
| 5 | Save/Load & Migration | MVP | Foundation | lead-programmer, godot-specialist | M |
| 6 | Input & Controls | MVP | Foundation | gameplay-programmer, ux-designer, accessibility-specialist | S |
| 7 | Gameplay Settings & Modifiers | MVP | Foundation | systems-designer, accessibility-specialist | S |
| 8 | Hulls & Ship Definition | MVP | Core | game-designer, systems-designer | M |
| 9 | Combat Space | MVP | Core | engine-programmer, performance-analyst | L |
| 10 | Combat Event Bus & Battle Record | MVP | Core | lead-programmer, systems-designer | M |
| 11 | World Clock | MVP | Core | systems-designer | S |
| 12 | Weapons & Damage | MVP | Core | systems-designer, game-designer | M |
| 13 | Vigor | MVP | Core | game-designer, systems-designer | L |
| 14 | Coherence & Links | MVP | Core | game-designer, systems-designer, ai-programmer | L |
| 15 | Flagship Piloting | MVP | Core | game-designer, gameplay-programmer | M |
| 16 | Truth Seeding & Candidates | MVP | Core | narrative-director, systems-designer, world-builder | M |
| 17 | Faction Reputation & Standing | MVP | Core | economy-designer, game-designer | S |
| 18 | Credits, Upkeep & Sinks | MVP | Core | economy-designer | M |
| 19 | Archive Fragments & Evidence | MVP | Feature | narrative-director, systems-designer, writer | L |
| 20 | Faction Belief & Blame | MVP | Feature | systems-designer, game-designer, narrative-director | L |
| 21 | Case File & Deduction | MVP | Feature | systems-designer, game-designer | M |
| 22 | Exposure & Rival Investigation | MVP | Feature | systems-designer, game-designer | M |
| 23 | Reckoning & Endings | Vertical Slice | Feature | narrative-director, systems-designer, writer | L |
| 24 | Fleet Orders | MVP | Feature | game-designer, ux-designer | M |
| 25 | Ship AI | MVP | Feature | ai-programmer, game-designer | L |
| 26 | Fleet Coordination | MVP | Feature | ai-programmer | M |
| 27 | Battle Resolution & Retreat | MVP | Feature | game-designer, economy-designer | M |
| 28 | Machine Nodes & Strongholds | MVP | Feature | level-designer, game-designer, ai-programmer | M |
| 29 | After-Action Debrief | MVP | Feature | game-designer, systems-designer, ai-programmer | L |
| 30 | AI-vs-AI Runner & AI Debug Tools | MVP | Feature | tools-programmer, ai-programmer, qa-lead | M |
| 31 | Allied Lending | MVP | Feature | game-designer, economy-designer | S |
| 32 | Sector Map & Travel | MVP | Feature | level-designer, game-designer | M |
| 33 | Points of Interest | MVP | Feature | level-designer, narrative-director | S |
| 34 | Ports, Rest & Care | MVP | Feature | game-designer, economy-designer | S |
| 35 | Refit & Loadout | MVP | Feature | game-designer, systems-designer | M |
| 36 | Markets & Trade | MVP | Feature | economy-designer | S |
| 37 | Camera & Combat View | MVP | Presentation | gameplay-programmer, ux-designer | S |
| 38 | Combat HUD & Tactical Overlay | MVP | Presentation | ux-designer, art-director, ui-programmer | M |
| 39 | Dossier | MVP | Presentation | ux-designer, game-designer | M |
| 40 | Public History Screen | MVP | Presentation | ux-designer, narrative-director | S |
| 41 | Port & Fleet Management Screens | MVP | Presentation | ux-designer, ui-programmer | S |
| 42 | Menus, Settings & Save UI | MVP | Presentation | ux-designer, ui-programmer | S |
| 43 | Telemetry & Playtest Logging | MVP | Polish | analytics-engineer, qa-lead | S |
| 44 | Onboarding & Opening Sequence | MVP | Polish | game-designer, ux-designer | S |
| 45 | Salvage & Recovery | Vertical Slice | Feature | economy-designer | S |
| 46 | Ledger | Vertical Slice | Presentation | ux-designer, economy-designer | M |
| 47 | Audio Direction & Adaptive Music | Vertical Slice | Presentation | audio-director, sound-designer | M |
| 48 | Accessibility Options UI | Vertical Slice | Polish | accessibility-specialist, ux-designer | S |
| 49 | Difficulty Options UI | Vertical Slice | Polish | game-designer, ux-designer | S |
| 50 | Contracts & Missions | Alpha | Feature | game-designer, economy-designer | M |
| 51 | Loot & Crafting | Alpha | Feature | economy-designer, systems-designer | L |
| 52 | Captain Skills | Alpha | Feature | game-designer, systems-designer | M |
| 53 | Background Faction Economy | Alpha | Feature | economy-designer, systems-designer | L |
| 54 | Officers | Full Vision | Feature | game-designer, ai-programmer | M |
| 55 | Colonies & Industry | Full Vision | Feature | economy-designer, game-designer | L |
| 56 | Breakaway Machine Faction | Full Vision | Feature | game-designer, narrative-director, ai-programmer | M |
| 57 | Platform Integration | Full Vision | Polish | release-manager, devops-engineer | S |

Effort estimates: S = 1 session, M = 2-3 sessions, L = 4+ sessions. A "session" is one focused design conversation producing a complete GDD. Systems at stub depth in Tier 0 (see the Producer Note) still get a full GDD; the stub is a build depth, not a design depth. Reckoning & Endings is designed at #23 (CD-SYSTEMS) although it is built in the Vertical Slice: its ending classifier defines Faction Belief's thresholds.

---

## Circular Dependencies

Each cycle is broken by a contract between the two systems. Write the contract into both GDDs.

- **After-Action Debrief ↔ Dossier / Machine Nodes & Strongholds**: the Debrief needs counter IDs, and the Dossier is filled from the Debrief. **Contract:** the counter taxonomy is data in Content Data, owned by Strongholds; the Debrief reads it; the Dossier only displays.
- **Exposure & Rival Investigation ↔ Faction Belief & Blame**: Exposure reads the public history and changes beliefs. **Contract:** Belief owns all belief state and the share record, and exposes an exposure-event API; Exposure only calls it.
- **Vigor / Coherence ↔ Ship AI**: the AI spends Vigor and must react to fragmentation. **Contract:** Vigor owns Vigor state, rules, warning thresholds and dry-state effects on ship stats; Coherence owns the link graph (updated on events) and fragmentation state; Ship AI owns the injected resource policy that maps that state to a posture, and the fallback behaviour for fragmented ships.
- **Faction Belief & Blame ↔ Faction Reputation & Standing**: blame moves standing, and standing gates care. **Contract:** Reputation is a plain ledger; Belief writes reactions into it; Reputation never reads belief.
- **Markets & Trade / Contracts & Missions ↔ Background Faction Economy**: the background economy reads markets and contracts and also sets their prices and offers. **Contract:** Markets and Contracts own their price, supply and offer state and expose write APIs; Background Economy only calls them.
- **World Clock ↔ planning screens**: the clock stops while a planning screen is open. **Contract (revised 2026-10-28, owner decision in the Simulation Tick & Pause GDD):** Simulation Tick & Pause owns the single hold-reason set (player pause, auto-pause, planning screen, system); screens and pause push and pop reasons there; the World Clock only reads `is_held()`. Neither the clock nor the tick depends on Presentation.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Ship AI + Fleet Coordination | Technical | Two AI behaviour families across Vigor and Coherence; bad Vigor spending reads as stupid AI; utility scoring fights legibility (TD-FEASIBILITY: HIGH) | Fixed, telegraphed postures; a reason event for every lethal behaviour; few actions with large score gaps in Tier 0; AI debug overlay; tune in the headless runner |
| After-Action Debrief | Design / Technical | A wrong or vague cause breaks Pillar 1; multi-cause losses; attribution needs evidence, not inference | Pure function over the Battle Record; 4-6 named causes plus an honest "unknown"; runner asserts every scripted loss is classified |
| Combat Space | Technical | Projectile counts at fleet scale; spatial queries in GDScript; determinism | Hits resolved in the sim, not by physics callbacks; projectile pool; broadphase choice settled by a spike; frame budget set in the GDD |
| Simulation Tick & Pause | Technical | Pause with direct piloting; headless runner needs no nodes; 18+ dependents | Own sim accumulator, not `SceneTree.paused`; orders queued to the next tick; Tick/Pause/Determinism ADR before Core GDDs |
| AI-vs-AI Runner | Technical / Scope | Determinism (seeded streams, no wall clock, JSON float round-trip); stand-in captain bot is unlisted work | RNG Streams designed before any consumer; same-seed replay as the Tier 0 boundary test |
| Vigor | Design | Erosion can feel punishing, or too weak to change behaviour; spending at the floor costs nothing; must not map 1:1 onto flux | Prototype the ceiling's effect on later fights (CD-PLAYTEST condition 2); non-zero marginal cost at the floor; flux-mapping table |
| Coherence & Links | Design / Technical | Relay-first may become the only strategy; redundancy kills the cut moment; jammed player escorts | Fragmentation by connected component with hysteresis; redundancy tuned in the GDD; reduced order set for fragmented player ships |
| Faction Belief & Blame + Exposure + Case File | Design | Oracle leaks, willful-ignorance strategies, lying-optimal lending (three review passes found problems here) | Rules now fixed in the concept (held-only reasoning, ≥2 reliable contradictions, investigators on the clock, held-fragment good faith); boundary-case table in the GDDs; truth-blind preview test |
| Archive Fragments + Truth Seeding | Scope | Authored content for any seeded maker is unbounded for a solo developer | Claim templates × per-race attribute table; one reaction matrix; Tier 1 fragment cap; no race lineage on the Instrument |
| Combat HUD & Tactical Overlay | Technical | 2D glow after the 4.6 rework and per-instance canvas shader state are NOT SOURCEABLE for 4.7.2 | 2-3 day rendering spike with pass/fail criteria and a named renderer (pre-production gate); fallback (baked halo / additive layer) recorded in the rendering ADR |
| Credits, Upkeep & Sinks | Design | No money sink survived the concept; clock-driven death spiral | Defeat-cost limit and "never makes a retry unaffordable" invariant in the GDD; suppression and upkeep as sinks |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 57 |
| Design docs started | 34 |
| Design docs reviewed | 1 |
| Design docs approved | 0 |
| MVP systems designed | 34/43 (#1 In Review; #2–#35 pending review; #34 is Vertical Slice) |
| Vertical Slice systems designed | 0/6 |

---

## Next Steps

- [ ] Review and approve this systems enumeration
- [ ] Write the Tick/Pause/Determinism ADR direction into the first GDD (Simulation Tick & Pause) — it fixes the sim/view split every Core system relies on
- [ ] Design MVP-tier systems first, in the order above (use `/design-system [system-name]`)
- [ ] Run `/design-review` on each completed GDD
- [ ] Fresh session: `/design-review design/gdd/simulation-tick-and-pause.md` (status Designed, pending review)
- [ ] UX flag, Simulation Tick & Pause: run `/ux-design` for the combat HUD pause, speed and auto-pause elements and the settings entries before writing epics
- [ ] Run `/gate-check technical-setup` when MVP systems are designed
- [ ] Validate the highest-risk systems with `/vertical-slice` before committing to Production
