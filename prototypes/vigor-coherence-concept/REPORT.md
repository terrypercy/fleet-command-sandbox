<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: Does cutting Coherence links while the Vigor ceiling erodes across back-to-back fights give readable, tactical decisions? -->
<!-- Date: 2026-10-28 -->
# Concept Prototype Report: Vigor vs Coherence combat

> **Date**: 2026-10-28
> **Prototype Path**: Engine
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

"If the player flies a flagship through 3 back-to-back skirmishes against a linked
machine formation, they will target the relay ships first and see why the fight got
easier after the cut — evidenced by relay-first in at least 2 of the 3 skirmishes AND
a Vigor ceiling after skirmish 3 between 25% and 70% (near 0% = erosion feels
punishing; near 100% = Vigor has no cost)."

---

## Riskiest Assumption Tested

The owner chose to test two together:

1. **The cut is satisfying and readable** — cutting Coherence links and watching the
   formation fall apart. **Proved out**: the formation breaking was the playtester's
   best moment.
2. **Vigor ceiling erosion feels like rationing, not punishment** — the property that
   keeps Vigor from being a flux clone (`game-concept.md`, Pillar 5). **Partly proved
   out**: the final ceiling landed mid-band (58%) and the erosion drew no complaint,
   but the playtester was not directly asked whether it changed how they fought in
   skirmishes 2 and 3, so "felt like a choice" is unconfirmed. The one complaint was a
   different part of Vigor: the hard lockout when it runs dry.

---

## Approach

A separate throwaway Godot 4.7.2 project, one GDScript file drawing placeholder shapes.
Built and headless-checked in the same session, then played by the owner on their
Windows PC.

- Player flagship: WASD move, mouse aim, left-click fire (4 Vigor/shot), Shift boost
  (22 Vigor/s). Every point of Vigor spent lowers the ceiling by 0.03. Vigor refills
  (18/s, after 0.45 s without spending) only up to the ceiling. Hitting 0 Vigor means
  EXHAUSTED for 1.6 s: no fire or boost, half speed.
- Machine formation: 4 / 5 / 6 line ships plus 1 / 2 / 2 fragile relays across the 3
  skirmishes. Linked ships hold formation and fire synchronised, accurate volleys
  (telegraphed by the links brightening). Link lines solid (all relays alive) → dashed
  (one of two dead, slower and less accurate volleys) → snapped with a spark (cut).
  Cut ships turn grey, break formation, wander towards the player and fire singly and
  inaccurately.
- The ceiling carries across all 3 skirmishes and across retries after a defeat; hull
  is restored each skirmish.

**Path chosen:** Engine
**Reason for path:** a top-down action fight where feel is the hypothesis; browser
latency would give a false result.

**Shortcuts taken (intentional):**
- Hardcoded values, one file, no architecture
- Coloured shapes instead of art; no audio, menus, saves or tutorial
- No escorts or fleet orders, Debrief, Dossier, economy, loot or mystery
- Hull restored between skirmishes, so only the Vigor ceiling carries over
- A relay-priority bot for headless smoke runs only (not evidence of fun)

---

## Result

One playtester, the owner, played a full 3-skirmish run.

- **Summary screen:** relay-first **2/3**, final Vigor ceiling **58%**. Both inside
  the signal thresholds.
- **Why relays first** (owner's words): "playing games like this, you intuitively know
  that the small ones are protecting the big one and killing them. You could tell that
  likely you weren't going to be able to damage the primary one, or there would be an
  effect to it." → The relay role matched genre convention. Relay-first came from genre
  literacy, not from reading the link lines alone.
- **Best moment:** "when they broke formation, more so that the link was
  disconnected." → The cut's payoff was visible as behaviour (ships scattering), not
  as a number.
- **Worst moment:** "not being able to shoot or really do anything at a certain
  point." Clarified as **running dry** (the EXHAUSTED lockout), not the shrinking
  ceiling. The owner attributed it to "my improper use of the gun system."
- **Surprise:** "I enjoyed the overall feel of movement, bullet tracing, etc."
- **Verdict:** PROCEED. No one-sentence reason was given; the reason recorded below is
  drawn from the owner's answers above.

Reference only: the headless bot (relay-first by design, near-perfect aim) ended with
ceilings of 92% / 83% / 74%. A human who misses more spends more, which matches the
owner's lower 58%.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine |
| Iterations to playable | 1 (ran first time; the only snag was finding `main.tscn` after importing) |
| Prototype duration | Built, headless-checked and played on 2026-10-28, well inside the 1-day cap |
| Playtesters | 1 internal (the owner, who knows the concept), 0 external |
| Feel assessment | Movement and bullet tracing felt good; the cut read clearly as the formation scattering; the 1.6 s EXHAUSTED lockout (no fire, no boost, half speed) felt bad |
| Hypothesis verdict | CONFIRMED (the owner's call). Both numeric signals met; caveat that relay-first was driven by genre convention |

---

## Recommendation: PROCEED

The core fight works. Both falsifiable signals landed: relay-first 2/3 against a target
of at least 2, and a final ceiling of 58% against a band of 25–70%. The concept's
signature moment, cutting links and watching the formation break, was the playtester's
best moment, and base handling felt good even with placeholder shapes. The only negative
was the hard EXHAUSTED lockout, a tuning and design issue inside Vigor rather than a
broken core. The evidence is thin: one internal tester, one run, someone who knows the
concept. It is enough to start designing, not enough to lock tuning.

---

## Creative Director Review (CD-PLAYTEST): CONCERNS

**Owner's decision:** accept with noted concerns. **PROCEED stands.**

The director ruled that PROCEED stands for what was tested — the combat core is worth
designing — but that this does not show the core fantasy landing. Two of its three
clauses ("hold the evidence that decides which race the galaxy blames" and the
fail-prepare-return arc) were out of scope by design. It is not REJECT: the cut, the
signature of the Moment-to-Moment loop, was the tester's best moment and read as
behaviour, and both numeric signals were met.

Pillar findings (ranked 2 > 1 > 5 > 4 > 3):
- **Pillar 2, The Truth Is Yours to Tell:** not reached (out of scope). PROCEED means
  "the combat works", not "the game works".
- **Pillar 1, Every Defeat Is a Lead:** barely reached. There was no Debrief or prepare
  phase, and the report does not record whether the tester lost.
- **Pillar 5, Living Against Made:** partly reached, with a drift risk. The EXHAUSTED
  lockout is functionally Starsector's overload, so the most flux-like part of Vigor
  was the worst moment. The distinctive part, ceiling erosion as rationing, is
  unconfirmed as a felt choice.
- **Pillar 4, Plan in the Open:** partly reached. Relay-first came from genre literacy,
  not from the game teaching it.
- **Pillar 3, Hands on the Helm:** reached, with one violation (the lockout removes all
  agency). Pause and fleet orders were not in the build.

**Conditions attached to PROCEED:**
1. Replace the hard EXHAUSTED lockout with an exhaustion state that changes behaviour,
   plus an early warning before Vigor runs dry — a **requirement**. Check it explicitly
   against the flux originality test.
2. In the next playtest, ask directly whether the shrinking ceiling changed how the
   player fought in later skirmishes, and log how often Vigor hits empty.
3. Include at least one tester new to the genre, to check that the link lines alone
   teach the relay role.
4. Keep a cheap test of the Pillar 2 mystery (fragment sharing, blame state, faction
   reaction) and the Pillar 1 Debrief loop on the plan before production combat.

**We'll know this was right if:** players change their spending because of the ceiling
without being prompted; the replacement for running dry is no longer anyone's worst
moment; and a player new to the genre goes for relays first by reading the link lines.

---

## If Proceeding

- **Core tuning values discovered** (starting points for the Formulas and Tuning Knobs
  sections, not final numbers):
  - Ceiling erosion 0.03 per Vigor spent; shot cost 4; boost 22/s; regen 18/s after a
    0.45 s idle delay; ceiling floor 5. Over 3 skirmishes this produced 58% for a human
    and 74% for a near-perfect bot.
  - Relay 72 HP and line ship 120 HP against 12 damage per shot; linked volleys every
    1.5 s solid, 2.5 s degraded; fragmented ships fire every 2.2–3.4 s with ±0.3 rad
    error.
- **Assumptions confirmed:**
  - The cut is readable and satisfying when shown as behaviour (formation breaking).
  - Relays read as the units to kill first.
  - Moment-to-moment handling can carry the fight (*Hands on the Helm*).
- **Assumptions disproved:**
  - A hard lockout is an acceptable exhaustion state. It wasn't: "not being able to
    shoot or really do anything" was the worst moment, against *Hands on the Helm*.
- **Not yet tested:**
  - Whether ceiling erosion changes behaviour in later fights (not asked).
  - Whether the link lines teach the relay role to a player *without* genre literacy
    (only one genre-literate tester).
- **Emergent mechanics:** none observed beyond the design.
- **Design actions for the GDDs:**
  - Give a warning before Vigor runs dry: glow or ring flicker, or a sound.
  - Replace the hard lockout with an exhaustion state that changes behaviour instead
    of disabling the ship. The CD-PILLARS review offered "panic, frenzy or drift".
  - Keep the relay silhouette and placement distinct; it works with genre expectations.

**Next steps:**
1. `/design-review design/gdd/game-concept.md`
2. `/gate-check`
3. `/map-systems`
4. `/design-system [mechanic]` (use learnings in Tuning Knobs and Formulas sections)

---

## If Pivoting

N/A — verdict is PROCEED.

---

## If Killing

N/A — verdict is PROCEED.

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  That running out of Vigor could be a clean full stop. Losing all agency, even for
  1.6 seconds, is what the player disliked. Players blame themselves for a lockout
  with no warning, which hides a design problem.

- **What surprised us that didn't show up in the brainstorm?**
  How much genre convention carries the relay mechanic. Players already expect small
  support units to protect something, so the lines confirm the idea rather than having
  to teach it. Also, movement and bullet feel were praised with placeholder shapes.

- **What would we test differently next time?**
  Ask directly whether the ceiling changed behaviour in later fights. Test with at
  least one player new to the genre to check that the link lines alone teach the
  relay role. Log Vigor-empty events per skirmish, so lockout frequency is measured
  rather than recalled.

---

> *Prototype code location: `prototypes/vigor-coherence-concept/`*
> *This code is throwaway. Never refactor into production.*
