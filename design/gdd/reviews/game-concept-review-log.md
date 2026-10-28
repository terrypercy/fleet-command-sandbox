# Review Log: game-concept.md

## Review — 2026-10-28 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: XL
Specialists: game-designer, systems-designer, narrative-director, ai-programmer, godot-specialist, economy-designer, ux-designer, qa-lead; creative-director (senior reviewer)
Blocking items: 8 | Recommended: 12 (carry-forward groups)
Summary: The concept is sound — pillars hold, the prototype backs the combat core, scope tiers are honest. Two decisions had to be made in the concept itself before /map-systems: how the two halves of the fantasy connect (combat loop and mystery) and what is at stake in Pillar 2. The rest was stale text or belongs in later GDDs, ADRs and test plans. No pillar or hook changed.
Prior verdict resolved: First review
Note: the 8-section GDD checklist was NOT APPLICABLE (this is a concept document, not a system GDD); it was reviewed against the game-concept template, which it satisfies. Dependency graph and registry cross-check also not applicable (no Dependencies section, no related GDDs, `entities.yaml` has 0 entries).
Findings:
- [BLOCKING] Unique Hook / Core Loop: the fail-prepare-return loop and the mystery were not coupled — blame state should gate lent ships and the Debrief name the helper faction
- [BLOCKING] Pillar 2: no stake, payoff or authored bounds — add terminal states (truth confirmed / lie exposed / lie that stands), 3-4 candidates, red herring, no decisive fragment
- [BLOCKING] Core Loop / Core Identity: sandbox vs campaign unresolved; session length did not fit one arc (1-3 sessions); stopping point after the Debrief
- [BLOCKING] Core Mechanics (Vigor): no lockout replacement, no erosion intent, no floor rule, no port restore cost
- [BLOCKING] Unique Hook: originality line missing (differentiator is the political verdict); clean-room lore check
- [BLOCKING] MVP Definition: core hypothesis not testable ("satisfying", "care") — rewritten as behavioural logs
- [BLOCKING] Next Steps / Open Questions / Technical: stale text (test-setup, prototype, "unproven", gdUnit4); `rand_weighted` is an inference
- [BLOCKING] Unique Hook: sharing preview wording — first-order effects only, coarse bands, confirm, no undo
- [RECOMMENDED] Vigor GDD: erosion as fraction of per-hull base Vigor, floor, rest cost, erosion across retries, zero-Vigor damage loophole
- [RECOMMENDED] Coherence GDD: fragmentation rule (components vs count), hysteresis, mixed-fleet relays
- [RECOMMENDED] Debrief GDD: cause taxonomy with IDs, fallback, multi-cause ranking
- [RECOMMENDED] Mystery/Blame GDD: weight vectors, normalisation, farmable repeats, reaction matrix, writing budget
- [RECOMMENDED] Economy GDD: faucets/sinks, defeat-cost envelope, bankruptcy floor, grind-wall test, reputation vs blame
- [RECOMMENDED] Fleet Orders and Enemy AI GDDs: orders while paused, order set, persistence, telegraphed postures
- [RECOMMENDED] UX: design/accessibility-requirements.md first, first-10-minutes disclosure budget, readiness readout and retreat, non-colour channels, Dossier spoiler rules
- [RECOMMENDED] ADRs: renderer and glow, tick/pause/determinism (seeded RNG), input scheme, chart-overlay UI, physics vs custom collision, JSON vs .tres mod data
- [RECOMMENDED] Test plan: strategy per story type; Tier 0 gate n>=5 testers (3 new to genre), AI-vs-AI runner with labelled losses
- [RECOMMENDED] World-builder: identities for the four races
Revisions: all 8 blocking items were applied to `game-concept.md` on 2026-10-28 (decisions: blame gates lent ships; lies can be exposed; optional ending then free play; port restore costs time only). The hashes below are of the text that was REVIEWED, so the revised file reads CHANGED and gets a full re-review. Re-review pending.
Reviewed-Content-Hash: design/gdd/game-concept.md f6292afd0d86f3c33b56ea8febf1a9b2a8d546a6
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
