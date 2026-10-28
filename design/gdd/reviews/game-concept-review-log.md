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

## Review — 2026-10-28 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: XL
Specialists: game-designer, systems-designer, narrative-director, ai-programmer, godot-specialist, economy-designer, ux-designer, qa-lead; creative-director (senior reviewer)
Blocking items: 8 | Recommended: 9 (carry-forward groups)
Summary: All 8 first-review blockers were addressed; identity, pillars and hook hold. The new problems sat where the revisions meet, mostly in Pillar 2: no way to check a theory, delayed exposure contradicting "always previewed", lying as the optimal lending strategy, and the coupling unable to fire after the first loss. Not MAJOR — none changes the game's identity.
Prior verdict resolved: Yes (all 8 first-review blockers)
Note: concept document, reviewed against the game-concept template (8-section GDD checklist not applicable); `entities.yaml` has 0 entries, no related GDDs — values not cross-checked.
Findings:
- [BLOCKING] Unique Hook / Pillar 2: no player-facing theory check; "provable" vs "nothing hints closeness" contradict
- [BLOCKING] Pillar tensions / Anti-Pillars: "consequences always previewed" and "NOT wiki-dependent … including sharing" contradicted by delayed exposure
- [BLOCKING] Unique Hook / Pillar 2: lending makes lying optimal; blame shape (scalar vs distribution) unstated; no fallback when the ally is locked out; "lie that stands" undefined; lie vs good-faith error
- [BLOCKING] Unique Hook / Core Loop: fragments only from broken strongholds, so the coupling cannot fire after the first loss
- [BLOCKING] Core Mechanics (Vigor): "care from a living race" cost undefined; no always-running clock behind time-only rest; floor must keep a ship viable
- [BLOCKING] Unique Hook: breakaway machines vs "nobody remembers"; jammability of the player's machine ships
- [BLOCKING] MVP Definition: no pass bar; Debrief loss causes 4-6 vs 2-6; lending absent from the slice
- [BLOCKING] Status / Next Steps: stale "re-review pending" and "refine the pillars"
- [RECOMMENDED] Economy GDD: money sinks, bankruptcy floor, lent-ship rate limits, checkable grind-wall test, trade income bound
- [RECOMMENDED] Combat/AI GDD and ADRs: deterministic combat and seeded RNG, orders while paused, Debrief reason codes, dry-Vigor and fragmented-machine AI behaviour, minimal MVP order set, AI frame budget
- [RECOMMENDED] Pause/tick ADR: own sim accumulator, not get_tree().paused; queued-order tick; interpolation
- [RECOMMENDED] Test plan: measurable pillar and 32 px visual tests; Debrief/Dossier view logging
- [RECOMMENDED] Accessibility: create design/accessibility-requirements.md before the Pre-Production gate
- [RECOMMENDED] Onboarding: what if the player wins the intended loss; max time to first Debrief
- [RECOMMENDED] Narrative: authored-content budget; clean-room lore check before the race list; non-candidate races
- [RECOMMENDED] Godot: tag .tres script-execution claim unsourced; CI needs --import first and tolerance of the import segfault; 4.7 input device-ID change
- [RECOMMENDED] Hook sentence: lead with the political verdict, not the shared trope
Disagreements (creative-director rulings): determinism/pause/attribution → ADR-level; MVP pass bar → blocking (narrow); money sinks → Economy GDD; measurable pillar rewrites → GDD ACs; Case File vs l.77 → l.77 scoped to the preview; Tier 0a/0b split → owner's decline stands.
Revisions: all 8 blockers applied 2026-10-28. Owner decisions: truth seeded per save; fragments also from derelicts, archives and testimony (not from losses); "lie that stands" is bittersweet, reached by costly visible suppression; Case File with a consistency count. Defaults approved: care costs standing with that race; good-faith misreading costs less than a contradicted lie; breakaways stripped their own archives (unreliable testimony). MVP slice now includes the Case File and one blame-gated lent escort. The hashes below are of the text that was REVIEWED (HEAD 632eefc), so the revised file reads CHANGED and gets a full re-review. Re-review pending.
Reviewed-Content-Hash: design/gdd/game-concept.md 01eba1cbb28cccd034fcd47cedcb71929f61246b
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43

## Review — 2026-10-28 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: XL
Specialists: game-designer, systems-designer, narrative-director, economy-designer, ux-designer, ai-programmer, godot-specialist, qa-lead; creative-director (senior reviewer)
Blocking items: 9 | Recommended: 9 (carry-forward groups)
Summary: Identity, hook and pillar ranking hold; all 16 earlier blockers landed and the combat half is sound. The new problems sat in Pillar 2's information model: four specialists independently found the Case File and exposure readout acting as a truth oracle, and nothing defined what drives exposure, what good faith is, what the truth is worth, or how an ending is reached; the 2-race MVP slice could not test any of it. Not MAJOR — none changes what the game is.
Prior verdict resolved: Yes (all 8 second-review blockers)
Note: concept document, reviewed against the game-concept template (8-section GDD checklist not applicable); `entities.yaml` has 0 entries, no related GDDs — values not cross-checked. economy-designer and ai-programmer read partial ranges; overlapping specialists covered the rest.
Findings:
- [BLOCKING] Unique Hook / Pillar 2: Case File + exposure readout are a truth oracle (free single-fragment elimination; held vs world fragments unstated; no exposure trigger); red herring "contradicts" the truth for an honest player
- [BLOCKING] Unique Hook: good faith keyed to Case File queries rewards never querying
- [BLOCKING] Pillar 2: no truth/lie payoff asymmetry; suppression undefined; lender direction unstated
- [BLOCKING] Pillar 2: blame global vs per-faction unstated; no blame→ending rule; no ending trigger; "shared nothing" state
- [BLOCKING] MVP Definition: 2 races cannot test a 3-4 candidate mystery; 1-2 fragments cannot fire exposure
- [BLOCKING] Pillar 2 / Visual Identity: authored-content cost of a seeded truth unbounded; Instrument art would reveal its maker
- [BLOCKING] Core Mechanics (Vigor) / Pillar 1: always-running clock can death-spiral; hostile factions can trap a ship at its floor; opening loss cost; clock behaviour during pause/closed
- [BLOCKING] Technical Considerations / Scope Tiers: AI-vs-AI runner required (l.507) yet listed as not adopted (l.697)
- [BLOCKING] MVP Definition: pass-bar rubric target, "retry" and "logged change" undefined; "tactic" not loggable
- [RECOMMENDED] Mystery/Blame, Debrief GDDs and Tier 0 test plan: ACs for independence, thresholds, bands, truth-blind preview, telemetry events, cause IDs
- [RECOMMENDED] Tick/Pause/Determinism ADR: seeded RNG streams, own sim accumulator, hits resolved in the sim not physics callbacks
- [RECOMMENDED] Rendering ADR / CI: glow and per-instance shader fallbacks; retry `--import` (exit 139 seen 3/17)
- [RECOMMENDED] Debrief, Enemy AI, Fleet Orders GDDs: typed cause events, fixed dry-Vigor posture, jammed-escort order set, AI frame budget
- [RECOMMENDED] Accessibility: design/accessibility-requirements.md — sim speed, orders while paused, remap, colour independence beyond two pairs, photosensitivity
- [RECOMMENDED] UX specs: consolidate ~9 information surfaces with a question→surface map; Dossier faction pages
- [RECOMMENDED] Economy GDD: endgame sink class, standing/reputation/blame fungibility, lent-ship cost, scripted Tier 0 "rivals act"; grind-wall wording "gear gates the Dossier counter, never raw power"
- [RECOMMENDED] Scope Tiers: Tier 0 cut line (drop market and lent escort first)
- [RECOMMENDED] Narrative/world bible: tone, meaning of "debt", breakaway motive, moral framing, clean-room list, anti-pillar → "no player-driven dialogue trees"
Disagreements (creative-director rulings): D1 elimination over held evidence is intended — fix combines held-only reasoning, ≥2 reliable contradictions, finite set and world-clock investigators; queries not metered. D2 "lent ships never required" stands (game-designer's intended-lent-tier offered as option only). D3 owner's ending stance stands. D4 only narrow pass-bar definitions block; other QA items → GDD ACs. D5 determinism → ADR. D6 glow spike already in the gate row → fallback to ADR. D7 surface consolidation → UX specs. D8 sinks → Economy GDD, death-spiral bound concept-level. D9 Tier 0a/0b decline stands; cut line recommended.
Revisions: all 9 blockers applied 2026-10-28. Owner decisions: exposure driven by rival investigators on the world clock; truth costly now and compounding later, lies cheap with suppression upkeep, factions lend when blame lands on rivals; MVP slice uses 3 candidates (third text-only) and ≥4 fragments incl. a red herring; AI-vs-AI harness moved into Tier 0 (reverses that one declined producer suggestion). Defaults approved: finite seeded fragment set; Case File over held fragments, ≥2 reliable independent contradictions to rule out, provenance classes; good faith by held fragments + minimum support; per-faction blame, Reckoning, ending classifier with "unresolved"; template authoring bounds and no race lineage on the Instrument; defeat-cost bounds; world clock stops while paused, in planning screens and when the game is closed. Owner accepted revisions for now (In Review); a re-review decides Approved. The hashes below are of the text that was REVIEWED (HEAD 527c24c), so the revised file reads CHANGED and gets a full re-review.
Reviewed-Content-Hash: design/gdd/game-concept.md d6e41b057c317513aa39d13f0e99906813f1f685
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
