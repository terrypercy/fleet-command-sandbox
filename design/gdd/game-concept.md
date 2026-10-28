# Game Concept: The Makers' Debt

*Created: 2026-10-28*
*Status: Draft (revised 2026-10-28 after the first `/design-review`: NEEDS REVISION → revisions applied; second review the same day: NEEDS REVISION → revisions applied, re-review pending)*

> Working title. A trademark search on the title is required before any public
> use (`design/reference/development-plan.md` § 9).
>
> **Inputs:** `design/reference/development-plan.md` (the owner's plan, read by
> section — § 1 concept outline, § 2 feature list, § 9 IP, § 10 risks),
> genre research on Starsector, Star Valor and Starlathe, and the `/brainstorm`
> session of 2026-10-28. Review gates run at `review_mode: full`: CD-PILLARS
> (CONCERNS → revisions applied), AD-CONCEPT-VISUAL (CONCEPTS → direction
> chosen), TD-FEASIBILITY (CONCERNS), PR-SCOPE (OPTIMISTIC → one adjustment
> applied).

---

## Elevator Pitch

> It's a top-down fleet-command space sandbox where you fly your flagship
> against machine fleets that one of the organic races built — and nobody
> remembers which. Trade, fight and investigate across feuding races; what you
> uncover, and who you tell, decides who stands with you when the machines
> arrive.

**10-second test:** "Starsector-style fleet battles, plus a whodunnit: one of
the living races built the killer robots, and you decide who history blames."

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Fleet-command space sandbox; action-RPG progression; investigative mystery |
| **Platform** | PC (Steam / Epic), mouse and keyboard first |
| **Target Audience** | Explorers and Storytellers first, strategy-minded Achievers second (see Target Player Profile) |
| **Player Count** | Single-player |
| **Session Length** | 30-120 minutes; one fail-prepare-return arc spans 1-3 sessions |
| **Monetization** | Premium, Steam Early Access first (plan § 8) — not yet decided in detail |
| **Estimated Scope** | Large (5-10 years to 1.0, solo, full-time; Early Access at 2.2-3.8 years) — PR-SCOPE estimate, Low confidence until Tier 0 measures real velocity |
| **Comparable Titles** | Starsector, Star Valor, Starlathe (genre); Return of the Obra Dinn, Outer Wilds (fixed-truth deduction) |

---

## Core Fantasy

**You are the detective-admiral whose discoveries reshape alliances in the
middle of a war.** You fly your flagship in the line, you watch a machine
formation fall apart when you cut its links, and you hold the evidence that
decides which race the galaxy blames for building those machines.

The emotional promise is the owner's favourite moment in games: **fail,
prepare, return, win.** A machine stronghold beats you. You go away, learn
exactly why, trade and salvage and recruit and refit, persuade a faction to lend
you ships — and come back with the fleet that breaks it. What you can do here
that you can't elsewhere: every defeat makes you smarter in ways the game shows
you, and every victory hands you a piece of the truth you then have to decide
what to do with.

---

## Unique Hook

**It's like Starsector, AND ALSO the machines were built by one of you — and
you decide who history blames.**

- Breaking a machine stronghold yields **archive fragments**: evidence about
  which organic race built the Instrument.
- There is **one fixed, hidden truth per save**: the true maker is seeded at new
  game from the candidate races, so it cannot be looked up. The **public
  history** — how the galaxy spreads blame across the candidates — is shaped by
  which fragments you share, and with whom. Factions react to that blame state.
- The **consequences of sharing** are previewed before you commit, as
  **first-order effects only**: which factions move, in which direction, and a
  coarse band (slight, marked, severe). No magnitudes, and the preview is
  **truth-blind** — nothing in it hints how close a fragment is to the truth; a
  confirm step, and no undo once committed. Later consequences follow **no hidden
  rule**: they are legible after the fact, and a persistent **exposure-risk
  readout** (low / rising / high) shows how many independent fragments contradict
  the public history, never which candidate is true.
- **Checking a theory — the Case File.** The player can state a candidate at any
  time; the Case File answers "consistent with N independent fragments" or
  "contradicted by [fragment]", never "correct". This is how a detective tests a
  case before going public; the sharing preview stays truth-blind.
- **The two halves of the fantasy are coupled.** A faction's blame state decides
  which allied ships it will lend for your return attempt, and the After-Action
  Debrief can name the faction that would help. Persuading a faction is therefore
  a mechanic, not flavour, and what you tell them changes what you can bring
  back to the stronghold that beat you. Fragments come from broken strongholds
  and also from **derelicts, archives and testimony** found between attempts, so
  there is evidence to share before the first return. Lent ships are **never
  required**: every Dossier entry names at least one counter that needs no ally.
- **The truth matters.** A public history that contradicts the truth can be
  exposed later by independent fragments, and factions that trusted you turn on
  you. A good-faith misreading is not a lie: sharing a theory the Case File had
  not contradicted costs trust slowly if exposed; sharing one it had contradicted
  costs it sharply. See Pillar 2 for the three possible endings.
- **Originality.** "A creator race's machines turn on it" is a common trope, and
  Starsector also asks who built its automated fleets. The differentiator is the
  **political verdict** (you decide who history blames), not the discovery of who
  built the machines. A clean-room lore check against Starsector is required
  before the world bible is written.
- Late in the game a **breakaway machine faction** can join you, so one fleet
  mixes living Vigor ships with Coherence-linked machines. Your own machine ships
  **can be jammed** like any other. The breakaways stripped their own archives
  when they broke away; what they recall is **testimony** — evidence with marked,
  unreliable provenance, never decisive.

*Alternatives considered for the hook* (session record): a blockade-breaking
loop on its own (Breakwater), a living bio-fleet (Hollow Tide), relighting a
silent relay network (The Quiet Lanes), territory that reshapes combat
(Rootfall), hybrid bio-machine grafting (Graftborn). The mystery won because it
gives the fail-prepare-return loop a story reason and matches the owner's
"Story & Discovery" choice; pieces of the others survive (the Debrief from
Breakwater, the grown-ship race from Hollow Tide).

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Narrative** (drama, story arc) | 1 | A fixed-truth mystery about who built the machines; a public blame state the player shapes; factions that react to it. Story through systems and evidence, not branching dialogue |
| **Discovery** (exploration, secrets) | 2 | Archive fragments, machine-node intel filling the Dossier, a region of four races to learn |
| **Challenge** (obstacle course, mastery) | 3 | Machine strongholds that beat you first; readable defeats; counter-fleets you work out |
| **Fantasy** (make-believe, role-playing) | 4 | Captain-in-the-line flagship piloting; the detective-admiral identity |
| **Expression** (self-expression, creativity) | 5 | Loot, crafting and refits; fleet composition; which truth you tell |
| **Sensation** (sensory pleasure) | 6 | Breath and Wire visuals: bioluminescent hulls, link lines snapping |
| **Submission** (relaxation, comfort zone) | 7 | Pause always available; trade and travel between fights; challenge that feels earned, not punishing |
| **Fellowship** (social connection) | N/A | Single-player; no multiplayer (anti-pillar) |

*Why Narrative over Challenge:* the owner picked "Story & Discovery" as the
primary experience and wants challenge that is relaxing because a story creates
it. Challenge is the beat, not the point.

### Key Dynamics (Emergent player behaviors)

- Players will **attack a stronghold they know they might lose**, because a
  loss fills in the Dossier.
- Players will **read the After-Action Debrief and build a counter-fleet** —
  a planned answer rather than a bigger number.
- Players will **hunt relay ships first** in machine fights, learning to cut
  Coherence before brawling.
- Players will **ration Vigor across an expedition**, choosing which fights are
  worth spending their ceiling on and when to head back to port.
- Players will **hold fragments back**, weighing which faction to tell and what
  the blame shift will cost them — and will form their own theory of the truth.
- Players will **plan trade runs with the Ledger** to fund the next attempt.

### Core Mechanics (Systems we build)

1. **Pausable real-time fleet combat, captain in the line** — the player pilots
   the flagship directly and commands the escorts.
2. **Asymmetric combat resources — Vigor against Coherence.**
   - *Vigor* (organic): living energy spent by weapons, shields and boost. Every
     spend **erodes that ship's Vigor ceiling for the rest of the expedition**;
     only port rest, or care from a living race, restores it. It is a cost you
     carry between battles, not a bar you fill and vent. *Care* is offered only
     at that race's ports and costs **standing with that race** instead of time.
   - *Vigor design requirements* (from CD-PLAYTEST and the first design review;
     numbers belong in the Vigor GDD): **no hard lockout** — running dry changes a
     ship's behaviour instead of disabling it, with an early warning before it
     happens, checked against "can a Starsector player map this 1:1 onto flux?";
     erosion must **change how players spend**, not only how long they can fire;
     the ceiling floor must **never soft-lock** a player — at the floor a ship can
     still fight and retreat, not merely hold a non-zero value; and restoring at
     port costs **time only** — rest days on a **world clock that always runs**
     (in the sandbox and after the optional ending), during which contracts
     expire and rivals act — so port is never free and never a money trap.
   - *Coherence* (machine): fleet-wide command bandwidth relayed through visible
     links from relay ships. Cut a relay or jam a link and the formation
     fragments into individual, simpler ships.
3. **Planning tools in the game** — the **After-Action Debrief** (cause and
   counter for every loss), the **Dossier** (per machine node: weaknesses,
   counter-fleet, which faction would help) and the **Ledger** (markets and
   trade routes).
4. **Archive fragments and public blame** — evidence from machine strongholds,
   derelicts, archives and testimony; a sharing choice with previewed
   first-order consequences; public blame tracked as a distribution over the
   candidate races, which factions react to and which gates the ships they lend
   for a return attempt; the Case File for testing a theory; one fixed hidden
   truth, seeded per save.
5. **Sandbox economy and progression** — trade and contracts, salvage, loot and
   crafting, faction reputation, captain skills; later officers and colonies.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Which leads to follow and in what order; whom to trust with evidence; how to build the fleet; what history to tell | Core |
| **Competence** (mastery, skill growth) | Losses you understand turn into visibly better fleets; cutting links and rationing Vigor are learnable skills | Core |
| **Relatedness** (connection, belonging) | Officers, faction leaders and the breakaway machines whose trust you earn; a coalition you build | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How: Star
  Valor-style loot and unlocks; completing Dossier entries; breaking every
  stronghold.
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How:
  the mystery, archive fragments, learning machine-node weaknesses and how
  Vigor and Coherence interact. **Primary.**
- [ ] **Socializers** (relationships, cooperation, community) — How: only
  in-fiction (faction relations, officers). Community and modding are a
  secondary channel later.
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — How: not
  served. No PvP.

Quantic Foundry framing: primary motivations **Discovery and Story**; secondary
**Strategy and Completion**. Comparable games for the same player: Starsector,
Star Valor, Outer Wilds, Return of the Obra Dinn, Sunless Sea, FTL, Mount &
Blade.

### Flow State Design

- **Onboarding curve**: the first 10 minutes are a small, winnable machine
  skirmish that teaches flagship piloting, one fleet order and cutting a relay —
  then a stronghold the player is meant to lose, followed by their first
  Debrief. The lesson "losing is a lead" is taught by the game's opening.
  (Starsector's harsh campaign start is the cautionary example.)
- **Difficulty scaling**: strongholds are fixed points of difficulty the player
  grows into; Dossier entries tell the player roughly how ready they are. The
  sandbox lets them choose easier or harder targets.
- **Feedback clarity**: link lines snap visibly; hull glow dims as the Vigor
  ceiling drops; the Debrief names the cause of a loss; the Dossier fills in.
- **Recovery from failure**: defeat costs time and resources (hull damage,
  Vigor ceiling, salvage lost), never the run and never the player's
  understanding. The player retreats to port and tries again with a plan.

---

## Core Loop

### Moment-to-Moment (30 seconds)

The player pilots the flagship in a pausable real-time battle while ordering
escorts. Organic ships fight on **Vigor**: every shot, shield and boost spends
it and lowers that ship's ceiling for the rest of the expedition, so each push
is a choice about now against later. Machine ships fight with perfect
coordination while **Coherence** reaches them through visible link lines. The
satisfying moment is **the cut**: kill a relay or jam a link and an enemy
formation splinters into individual, predictable ships. Feedback is readable:
link lines go solid → dashed → snapped with a spark; organic hulls breathe and
dim.

### Short-Term (5-15 minutes)

Battle → salvage and, at a broken stronghold, an **archive fragment** (derelicts,
archives and testimony between fights yield them too) → the
**After-Action Debrief** names what happened → the **Dossier** updates (a
weakness confirmed, a counter-fleet suggested, a faction that might help) →
the player decides: refit, chase the lead, head to port to restore Vigor, or
choose **who to show the fragment to**. "One more" lives in the half-filled
Dossier entry: the player can see exactly what's missing.

### Session-Level (30-120 minutes)

Travel to a region; trade and take contracts to fund the fleet; gather intel on
a machine node; attempt it — often losing the first time; read the Debrief;
prepare (trade, craft, recruit, earn a faction's ships); return and win. One
fail-prepare-return arc spans **1-3 sessions**. The natural stopping point is
**in port after the Debrief**, with the next attempt planned and the Dossier
entry half-filled. The hook to come back: the newest fragment raises a question,
and some faction is reacting to what you revealed.

### Long-Term Progression

Captain skills, fleet growth, loot and crafting (Star Valor-style unlocks to
chase); faction reputation; officers and colonies at 1.0. The long-term goal:
assemble the evidence, decide what the galaxy believes, unite a coalition around
it — possibly including the breakaway machines — and break the Instrument at its
origin. The ending is **optional**: break the Instrument whenever you are ready
(truth confirmed, lie exposed, or lie that stands — see Pillar 2), then keep
playing freely in a changed world, where the Ledger, trade and colonies are the
endgame.

### Retention Hooks

- **Curiosity**: who really built the machines; the next stronghold's Dossier
  entry; a faction's reaction to your last revelation.
- **Investment**: a fleet and officers you built; Vigor ceilings you've spent
  and must restore; relations you've earned; a theory you're halfway to proving.
- **Social**: none in-game (single-player). Out of game: sharing theories about
  the truth, and mods later.
- **Mastery**: the stronghold that beat you; better counter-fleets; cleaner
  link cuts; spending Vigor well.

---

## Game Pillars

Ranked for tie-breaking: **2 > 1 > 5 > 4 > 3** (CD-PILLARS recommendation,
adopted). The ranking keeps the Narrative and Discovery identity on top; three
of the five pillars lean towards combat and systems.

Intended tensions, and how they resolve:
- *Every Defeat Is a Lead* (clear information) vs *The Truth Is Yours to Tell*
  (ambiguous evidence): **combat information is always clear; historical
  evidence is ambiguous; the first-order consequences of sharing are always
  previewed, and nothing that follows later obeys a hidden rule.**
- *Hands on the Helm* (reflexes) vs *Plan in the Open* (deliberation): pause
  is always available, and planning happens between battles.
- *Hands on the Helm* vs "challenge should feel relaxing": pause, readable
  telegraphs and difficulty options are pillar commitments, not polish.

### Pillar 1: Every Defeat Is a Lead
Losing always yields knowledge the player can act on, and the comeback is
earned.

*Design test*: "Can the Debrief name at least one specific, actionable cause
and counter for this loss?" If not, the loss fails the pillar. *Second test*:
"Does the return attempt feel earned?" — defeat costs time or resources, never
the run, and never the player's understanding.

Link to Pillar 4: defeats fill in the Dossier, so knowledge is earned through
play and then recorded.

### Pillar 2: The Truth Is Yours to Tell
The truth about who built the machines is fixed; the history the galaxy
believes is yours to write.

*Design test*: debating a single authored reveal vs a player-determined
outcome → **the player determines the public history, within authored bounds**:
- one hidden true maker, among **3-4 candidate races**, **seeded per save** (the
  exact count is a decision for the Mystery/Blame GDD);
- fragments are evidence weighted towards candidates; **no single fragment is
  decisive**, and the truth becomes provable only from several independent
  fragments, found in any order. "Provable" is player-facing: the **Case File**
  reports a stated theory as consistent with N independent fragments, or
  contradicted — never "correct";
- at least one **deliberate red herring**, with readable provenance;
- public blame is a **distribution over the candidates**, not a single value;
  factions react to it, and it gates the ships they lend for a return attempt
  (see Unique Hook). Lent ships are never required to win;
- **the truth matters**: a public history that contradicts it can be exposed
  later by independent fragments, and factions that trusted you turn on you;
  exposure risk rises with each independent contradicting fragment, and is shown.
  A good-faith misreading costs less than a lie the Case File had contradicted.
  The three endings are **truth confirmed**, **lie exposed** and **lie that
  stands** — a bittersweet, legitimate ending, reached only by visibly and
  expensively **suppressing** every independent fragment that contradicts the
  public history.

Delivered through systems and short authored beats, not branching dialogue
trees. Weights, normalisation, thresholds and the faction reaction matrix belong
in the Mystery/Blame GDD.

### Pillar 3: Hands on the Helm
Combat is felt first-hand from the flagship.

*Design test*: "The flagship is never abstracted; the fleet is commanded, never
puppeted; pause is always available." Debating more abstraction vs more direct
control **of the flagship** → direct control. This pillar is genre baseline
(Starsector does it); it keeps us in the genre rather than setting us apart, so
it ranks last.

### Pillar 4: Plan in the Open
Everything the player needs to optimise is inside the game and readable **once
learned** — no wiki.

*Design test*: debating a hidden stat vs a surfaced stat → **surfaced**,
through the Dossier, Ledger and Debrief. These tools are protected in scope
above hull and weapon counts.

### Pillar 5: Living Against Made
The Vigor/Coherence asymmetry runs through mechanics, art and lore.

*Design test*: debating one shared system for convenience vs an asymmetric
one → **asymmetric, as long as it stays readable**. *Originality test*: "If a
Starsector player can map Vigor 1:1 onto flux, Vigor fails." The cost — two
resource models and two AI behaviour families — is accepted because it is a
pillar: cut content counts before cutting the asymmetry. Open late-game test:
how the player's own machine ships handle relays and jamming in a mixed fleet,
resolved inside the asymmetry rather than by flattening it.

### Anti-Pillars (What This Game Is NOT)

- **NOT wiki-dependent**: no hidden formulas or unexplained modifiers. Sharing
  fragments previews its first-order effects, and what follows later obeys no
  hidden rule and is legible after the fact; the truth is seeded per save, so it
  cannot be looked up. It would break *Plan in the Open*.
- **NOT run-ending on defeat by default**: permadeath only as an optional mode.
  It would break *Every Defeat Is a Lead*.
- **NOT consequence-free on defeat either**: a loss costs time or resources, or
  the comeback feels empty (*Every Defeat Is a Lead*).
- **NOT a single forced public history**: there is one hidden truth, but the
  game never forces what the galaxy believes (*The Truth Is Yours to Tell*).
- **NOT grind-walled**: no stat-check walls you can only grind past. Each
  successful return must trace back to a Dossier- or Debrief-informed change
  (fleet composition, refit, ally, tactic), not just levels or gear.
- **NOT reskinned**: organics and machines never share one mechanic with
  different art (*Living Against Made*).
- **NOT a 4X or empire sim**: colonies serve the mystery and the alliances,
  never spreadsheet management.
- **NOT branching-dialogue storytelling**: story comes through systems and
  evidence. A solo developer cannot write branching trees across many factions.
- **NOT multiplayer**: it would split the effort ship AI and the story need.

---

## Visual Identity Anchor

**Direction: Breath and Wire** (AD-CONCEPT-VISUAL, with Direction B's chart
language for the planning tools). Seeds `/art-bible`.

**Visual rule:** *Living things glow from within; made things are lit from
outside and held together by lines.*

Supporting principles:
1. **Figure/ground** — backgrounds stay in the bottom ~20% of the value range
   so emissives always pop. *Design test:* if a background element competes with
   a hull's glow at combat zoom, darken the background.
2. **Mechanics are the art** — Vigor is the brightness and pulse rate of an
   organic ship's emissive core (an eroded ceiling reads as a dimmer, raggeder
   pulse); Coherence is drawn as link lines in three patterns that read without
   colour: solid = linked, dashed = degraded, snapped with a spark = cut.
   *Design test:* can a colour-blind player at 32 px tell a fresh ship from a
   spent one, and a linked machine from a cut one?
3. **Shape tells allegiance** — organic races are asymmetric, curved and lobed,
   one primitive per race (the race that grows its ships uses coral or seed-pod
   forms; others shell spirals, membrane sails, segmented carapace). Machines are
   strict geometry from a small kit of repeated modules. Breakaway machines keep
   the geometry but slowly break their symmetry. *Design test:* filled solid
   black at 32 px, can you name the faction?
4. **Planning tools are drawn on the captain's chart** — Dossier, Ledger,
   Debrief and the paused tactical overlay use an ink-on-dark-paper chart
   language; the Debrief replays a battle as annotated chart marks. Ambiguous
   evidence has its own pencil-grey "uncertain" treatment.

**Colour philosophy:** organic hulls are dark and desaturated, each race with
one signature emissive hue (warm amber, rose…) — on organics, colour means
*life*. The Instrument is near-monochrome bone and graphite with one hard
white-violet signal colour — on machines, colour means *connection*. Breakaway
machines' signal drifts warmer. Damage and threat use a reserved channel
(white-hot flashes) that never collides with a faction hue.

**Distance from Starsector (originality, all directions):** no greebled
realistic military plating, no grey/brown hull palette, no teal-on-black
rectangular panel UI, no near-symmetric "naval ship from above" silhouettes for
organics.

*Alternatives considered:* The Plotting Table (cheapest, most readable, risks
abstract-feeling combat against *Hands on the Helm*) and Relics in the Dark
(most atmospheric, highest cost, works against *Plan in the Open*).

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Starsector | Genre conventions: pausable top-down fleet combat with flagship piloting, refit, salvage, factions posting and withdrawing contracts, data-driven moddable content | Original setting, factions, ships and combat resource (Vigor is not flux); readable defeats; a short, clear mystery; planning tools in place of wiki culture; a gentler start | Validates that the genre has a devoted audience and that a small team can build it — and shows its pitfalls (harsh start, system overload, 15+ years without 1.0) |
| Star Valor | Diablo-style loot and crafting; faction reputation with faction-specific ships; "runs with a singular purpose of unlocking something" | Fleet command rather than a single ship; difficulty you can read rather than "cakewalk or Dark Souls"; less dead travel | Validates the incremental, unlock-chasing motivation the owner loves |
| Starlathe | A region whose factions trade, haul and fight without the player | A coarser, abstracted simulation that serves gameplay (plan § 10), introduced after the MVP | Unreleased; store pages only — a stated intent, not proven design |
| Return of the Obra Dinn / Outer Wilds | A fixed truth the player pieces together from evidence | Evidence comes from combat victories, and the player decides what the galaxy believes | Validates that players love deduction with a real answer |
| Sunless Sea / FTL | Costs that carry between encounters on an expedition | Vigor ceiling erosion on living ships | Validates attrition across a journey as tension rather than punishment |
| Mount & Blade | A captain in a living, feuding world | Space, and allegiances shaped by evidence | Validates the role-playing "my place in a world at war" fantasy |

**Non-game inspirations**: deep-sea bioluminescent life (the organic look);
circuit diagrams and survey charts (the machines and the planning tools);
detective fiction where the truth is known but the verdict is political.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 20-45 |
| **Gaming experience** | Mid-core to hardcore PC players comfortable with systems |
| **Time availability** | 30-120 minute sessions; evenings and weekends |
| **Platform preference** | PC (Steam) |
| **Current games they play** | Starsector, Star Valor, FTL; incremental games; story-driven strategy RPGs |
| **What they're looking for** | A fleet sandbox with a story worth uncovering, where losing teaches them something and they never need a wiki |
| **What would turn them away** | Unreadable difficulty spikes; mandatory wiki-digging; grind walls; a clone of an existing game's look |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.7.2, GDScript — the owner's choice, already configured in `project.yaml`. Fits 2D, data-driven content and modding. Version risk: the model's training predates 4.5-4.7; verify every engine API against `docs/engine-reference/godot/`. Installed editor confirmed as 4.7.2 (`4.7.2.stable.official.ed1daf0bf`, the owner's Windows PC, 2026-10-28; `VERSION.md`) |
| **Key Technical Challenges** | Ship and fleet AI across two resource models (HIGH); the Debrief's loss attribution (cause → counter classifier) on a combat event bus; pausable real-time with direct piloting; projectile counts at scale; persistent world, faction and blame state in versioned saves; a moddable data pipeline |
| **Art Style** | 2D flat vector-style sprites, two layers (body + emissive mask), glow on dark backgrounds |
| **Art Pipeline Complexity** | Medium (custom 2D): one shared Vigor shader; a ~12-module machine kit; four organic shape languages are the main cost |
| **Audio Needs** | Moderate to adaptive — organic and machine sound palettes; music that frames defeat as a lead (not yet specified) |
| **Networking** | None |
| **Content Volume** | Early Access launch: ~15-20 hulls, 25-30 weapons, 20-30 systems, 3-4 factions; growing in Early Access to the plan's full counts (25-40 hulls, 40-60 weapons, 30-60 systems, 4 organic races + the Instrument + breakaways) |
| **Procedural Systems** | Procedural missions and bounties; mixed hand-made and procedural sector map (seeded, deterministic, with hand-placed anchors) after the MVP. MVP systems are hand-made |

**Architecture direction from TD-FEASIBILITY** (to become ADRs, since
`rigor: full`):
- Keep the **simulation separate from presentation**: ships, fleets, Vigor,
  Coherence and factions are typed plain-data model objects on a fixed tick;
  scene nodes only render and take input.
- **AI in layers**: shared steering and targeting; a per-model resource policy
  (Vigor / Coherence) injected per ship; fleet orders on top; fragmented
  machines fall back to a simple state machine. Utility scoring with
  data-driven weights. A headless AI-vs-AI battle runner for tuning and
  regression tests.
- A **combat event bus** from day one, feeding the Debrief.
- **Saves**: versioned JSON/dictionary with `schema_version` and migrations;
  stable namespaced string IDs (`base:…`, `mymod:…`); never save node trees.
- **Mod data** in JSON or CSV validated against a schema, loaded into typed
  classes. Avoid loading third-party `.tres` files (a possible script-execution
  path — to verify in the ADR). Reject negative weights in loot tables: the
  4.7.2 change is to `RandomPCG::rand_weighted`; that it applies to
  `RandomNumberGenerator.rand_weighted()` is the engine reference's own
  **inference**, so validate weights in the loader regardless.
- **Rendering**: draw a fleet's links in one `_draw()` pass, and widen them
  (4.7 draws `CanvasItem` lines without an antialiasing feather). Glow changed
  in 4.6 — spike it on D3D12 and Vulkan. Whether 2D canvas glow and per-instance
  canvas shader uniforms behave as needed in 4.7.2 is NOT SOURCEABLE in the
  engine reference; the spike settles it. Treat the spike as a pre-production
  gate with written pass/fail criteria and a **named renderer** (Forward+,
  Mobile or Compatibility), which is itself an ADR decision.
- **Out of Tier 0**: the background economy simulation, procedural sector
  generation, and Steam/Epic integration (the GDExtension's 4.7.2 compatibility
  is NOT SOURCEABLE; needs a technology review).

Suggested ADRs: simulation/view split, combat event bus, save schema,
content/mod data format, AI architecture, Coherence graph, rendering/glow
setup.

---

## Risks and Open Questions

### Design Risks
- **Vigor ceiling erosion could feel punishing** rather than relaxing; it must
  read as a cost worth choosing. It can also fail the other way: too weak to
  change how anyone spends, or a death spiral at the ceiling floor. The first
  prototype never asked whether the ceiling changed behaviour. The requirement
  (see Core Mechanics): erosion changes how players spend, and the floor never
  soft-locks. Needs prototyping and tuning.
- **The mystery has to hold up in any order** across a sandbox; fragments found
  out of sequence must still build a coherent case.
- **Thin faction reactions to blame would make Pillar 2 look broken**, not
  small. Cutting factions is graceful; cutting how deeply they react is not
  (PR-SCOPE).
- **The Debrief only works if its causes are right.** A wrong or vague cause
  breaks Pillar 1.
- **Loot progression drifts towards grind** (Star Valor's pattern); the
  grind-wall anti-pillar test guards it.
- **Mixed late-game fleets** may blur the asymmetry if not designed carefully.

### Technical Risks
*TD-FEASIBILITY verdict: CONCERNS.*
- Ship and fleet AI across Vigor and Coherence — HIGH. Bad Vigor spending reads
  as stupid AI.
- New to Godot plus agent code trained before Godot 4.5 — HIGH (process risk).
  Mitigate with static typing, gdUnit4 green on an empty project, and checking
  every API against the engine reference.
- Debrief loss attribution — MEDIUM. Ship v1 with 4-6 loss causes.
- Saves with persistent world, faction and blame state, plus mods — MEDIUM.
- 2D glow after the 4.6 rework — MEDIUM; cheap to settle with a spike.
- Pause with direct piloting; projectile counts — MEDIUM.
- Background economy — LOW for the MVP, MEDIUM-HIGH for the full vision.
- Coherence link graph — LOW-MEDIUM if updated on events, not every frame.
- Steam/Epic integration — MEDIUM, later; 4.7.2 compatibility NOT SOURCEABLE.

### Market Risks
- The genre's audience is devoted but niche; discoverability is the main
  commercial risk (plan § 10). Wishlists and streamer outreach matter.
- Starsector has a strong following; looking or playing like a clone would hurt
  both reception and legal standing — the originality rules and the clean-room
  process (plan § 9) guard this.
- If generated art is used, Steam requires disclosure and this audience cares
  (PR-SCOPE).

### Scope Risks
*PR-SCOPE verdict: OPTIMISTIC — the design and tier order are sound; the
timescale is optimistic.*
- A solo developer with heavy AI help works like roughly 1.2-1.8 people. Art,
  AI tuning, balance, playtesting and the economy stay bound to human time.
- **Art** is likely the longest single task: four organic shape languages and
  dozens of hulls and weapons, with no art budget stated.
- Even Tier 0 holds the hardest risks (two AI models, link cutting, telemetry,
  the sharing choice); the first playable build is about a year away at
  full-time pace.
- Starsector's own history (15+ years, no 1.0, 4-5 economy rewrites) is the
  warning.

### Open Questions
- **Where does the art come from?** A contract artist, a strictly modular
  kit-of-parts pipeline, or a documented generated-art policy. PR-SCOPE says
  this choice will set the Early Access date. → decide before `/art-bible`
  finishes.
- **Which organic race really built the machines, and who are the candidates?**
  → `/map-systems` and the world-builder.
- **How do the player's own machine ships handle relays and jamming** in a
  mixed fleet? Partly resolved: they can be jammed like any machine ship. The
  relay rules → a GDD for the Coherence system.
- **Does Vigor ceiling erosion feel fair?** Partly answered by the combat
  prototype (final ceiling 58%, no complaint about erosion; the hard lockout was
  the worst moment). Still open: did the ceiling change how the player spent in
  later fights, and how often did Vigor hit empty? (CD-PLAYTEST condition 2.)
- **Do 2D glow and per-ship breathing work in Godot 4.7.2 on D3D12 and
  Vulkan?** → a 2-3 day rendering spike with written pass/fail criteria and a
  named renderer.
- ~~How does a player confirm a theory before committing?~~ Resolved
  2026-10-28: the Case File (see Unique Hook). Its weights and thresholds → the
  Mystery/Blame GDD.
- ~~What is the breakaway machine faction's role in the mystery?~~ Resolved
  2026-10-28: an unreliable witness — they stripped their own archives, and
  their testimony is marked-provenance, never-decisive evidence. Detail → the
  world-builder and the Mystery/Blame GDD.
- **What are the four organic races?** Each needs an identity, a relationship to
  the Instrument, a motive and means to have built it, a reason it could be
  falsely blamed, and a gameplay hook. → `/map-systems` and the world-builder,
  with a clean-room lore check against Starsector first.
- ~~Which Godot editor version is installed locally?~~ Resolved 2026-10-28:
  4.7.2 (`4.7.2.stable.official.ed1daf0bf`), recorded in `VERSION.md`. Still
  open: add build and run commands to `project.yaml`. gdUnit4 6.2.2 is
  installed, and the test command was run on Godot 4.7.2 (commit `aed61d2`).
- **Full-time or part-time development?** The producer's estimates assume
  35-40 hours a week; part-time roughly doubles them.

---

## MVP Definition

**Core hypothesis**: In the **fail → Debrief → prepare → return → win** loop
against a machine stronghold, in captain-in-the-line combat where Vigor and
Coherence play differently, testers (1) retry after losing, (2) change fleet
composition, refit or tactic between attempts, with the change logged, and
(3) give a stated reason for who they share a fragment with. Measured by
behavioural logs and one post-session question ("who built the machines, and why
do you think so?"), not by "satisfying" or "care". Target for the Tier 0 gate:
at least 5 testers in total, at least 3 of them new to the genre, collected over
time; 8 or more is an Early Access target. **Pass bar**: at least 4 of 5
testers, including at least 2 of the 3 new to the genre, each (1) start a new
attempt after a loss without being prompted, (2) show a logged change between
attempts, and (3) give a reason for their share that a written rubric accepts.
At this size the gate is a **qualitative smoke test, not proof**.

The MVP is the **build order**, not a scope cut: the full feature list remains
the vision.

**Required for MVP (Tier 0)**:
1. Pausable real-time combat: a flagship you pilot plus 3-5 escorts under fleet
   orders.
2. Vigor (with ceiling erosion) against Coherence (with cuttable, visible links).
3. About 6 hulls and 8 weapons; 2 organic races plus the Instrument.
4. One machine stronghold you are expected to lose first.
5. After-Action Debrief v1 (4-6 loss causes) and Dossier v1.
6. **Mystery slice**: 1-2 archive fragments (at least one from a
   non-stronghold source), a sharing choice between two factions with previewed
   consequences, a visible relations change, the Case File, and one faction's
   lent escort gated by its blame state (CD-PILLARS: the hook must be proven
   early, not last; the lent escort tests the coupling of the two halves).
7. A cluster of 3-5 hand-made systems with a basic market to fund refits.
8. Save/load with a versioned schema; data loaded from external files with
   stable string IDs.

**Explicitly NOT in MVP** (defer to later):
- Background faction economy simulation (Tier 1+).
- Procedural sector generation and procedural missions (Tier 1).
- Colonies, officers, exploration content, the full story arc, endgame (Tier 2).
- Steam/Epic integration, achievements, cloud saves, Workshop.
- Mod tooling beyond loading data files.

### Scope Tiers (if budget/time shrinks)

Estimates from PR-SCOPE at 35-40 h/week, solo with AI assistance; **Low
confidence** until Tier 0 measures real velocity; part-time roughly doubles
them. Cumulative from today.

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **Learning + pre-production** | Data schema, art bible, first sample ships | Godot learning; spikes (combat sandbox, Breath and Wire glow, Coherence links, minimal Debrief) | 2-4 months |
| **MVP (Tier 0)** | 3-5 systems, 2 races + the Instrument, ~6 hulls, ~8 weapons | The core loop and mystery slice above | 10-18 months |
| **Early Access launch (Tier 1, launch counts)** | ~15-20 hulls, 25-30 weapons, 20-30 systems, 3-4 factions | All plan must-haves: refit, ship AI, salvage, markets, reputation, procedural missions, skills, save/autosave, mod data loading | 2.2-3.8 years |
| **Full Vision (Early Access growth → Tier 2, 1.0)** | Plan's full counts: 25-40 hulls, 40-60 weapons, 30-60 systems, 4 organic races + the Instrument + breakaways | Colonies, officers, exploration, main story arc, endgame, tutorials, achievements and cloud saves, Workshop — delivered as Early Access updates | 5-10 years |
| **Post-launch (Tier 3)** | Expansions | Scripting API, alternate modes, Steam Deck | Ongoing |

*Adjustment applied (PR-SCOPE, chosen by the owner):* Early Access launches at
the fallback counts and grows to the full counts through Early Access updates.
The vision is unchanged; only the order changes.

*If time runs out:* Early Access ships on Tier 1 with fewer hulls and systems;
the pillar features (planning tools, the asymmetry, the mystery loop and how
deeply factions react to blame) are protected over content counts. Three Tier 1
items must not slip: save versioning and migration, stable data IDs and
formats, and the blame-state reactions.

*Producer suggestions not adopted (recorded for later):* splitting Tier 0 into
a 3-5 month combat sandbox (0a) and the campaign loop (0b) with a 12-month
gate; Tier 0 foundations (a Godot learning spike, an AI-vs-AI harness, moddable
data from day one, a Steam page at the end of Tier 0); an early art-supply
decision (kept as an open question above).

---

## Next Steps

Prototype-first path: the concept prototype ran and returned **PROCEED**
(creative-director CONCERNS accepted with 4 conditions — see
`prototypes/vigor-coherence-concept/REPORT.md`).

- [x] `/setup-engine` — already run (Godot 4.7.2); installed editor confirmed
  as 4.7.2. Re-run only to add build and run commands
- [x] `/test-setup` — gdUnit4 6.2.2 installed; CI test command verified on
  Godot 4.7.2 (commit `aed61d2`)
- [x] `/prototype vigor-vs-coherence combat` — PROCEED, with 4 CD-PLAYTEST
  conditions
- [ ] `/art-bible` — Breath and Wire, settling the art-supply question
- [x] `/design-review design/gdd/game-concept.md` — first review 2026-10-28:
  NEEDS REVISION, revised; second review the same day: NEEDS REVISION, revised;
  re-review pending
- [ ] `/map-systems` — systems index; factions and the hidden truth
- [ ] `/design-system` — one GDD per system
- [ ] `/create-architecture`, then `/architecture-decision` for each ADR above
- [ ] `/architecture-review`
- [ ] `/vertical-slice` — before committing to sprints
- [ ] `/gate-check`
