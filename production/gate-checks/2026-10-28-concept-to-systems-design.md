## Gate Check: Concept → Systems Design

**Date**: 2026-10-28
**Checked by**: gate-check skill
**Config**: workflow full · review_mode full · qa.level full · team.size studio
**Panel**: 4 of 4 (creative-director, technical-director, producer, art-director)

### Required Artifacts: 3/3 present
- [x] design/gdd/game-concept.md — exists, 43 KB, real content (commit 527c24c)
- [x] Game pillars — 5 ranked pillars (2 > 1 > 5 > 4 > 3) with design tests, plus anti-pillars
- [x] Visual Identity Anchor section — "Breath and Wire"
- [x] (recommended) Concept prototype — prototypes/vigor-coherence-concept/REPORT.md, PROCEED with 4 CD-PLAYTEST conditions

### Quality Checks: 4/4 passing (on the gate's wording)
- [x] Concept reviewed, verdict not MAJOR REVISION NEEDED — two full reviews 2026-10-28, both NEEDS REVISION; the revised text is not yet re-reviewed (Concern 1)
- [x] Core loop described — four timescales
- [x] Target audience identified — Target Player Profile, Bartle and Quantic Foundry framing
- [x] Visual Identity Anchor has a one-line rule and ≥2 principles — 1 rule, 4 principles, each with a test
- [—] Tests / performance / localization — not asked by this gate

### Director Panel Assessment

Creative Director:  CONCERNS
  Re-review the revised Pillar 2 before /map-systems. Carry the prototype's conditions (replace the EXHAUSTED lockout; Vigor must pass the flux test; cheap mystery/Debrief test before production combat) into the Vigor and Mystery/Blame GDDs as acceptance criteria. The prototype proved combat, not the mystery: place Mystery/Blame and Debrief/Dossier in the Core tier.

Technical Director: CONCERNS
  Feasible on Godot 4.7.2. Carry the godot-specialist notes (CI `--import` first plus import-segfault tolerance; .tres claim unsourced; pause/tick pitfalls; 4.7 input device IDs) into the risk register / ADR backlog. AI, Vigor and Coherence GDDs must define AI-visible data, tunable weights and tick/pause rules. Build/run commands missing from project.yaml; concept l.500 says `rigor: full` for `workflow: full`.

Producer:           CONCERNS
  MVP grew by 3 items today (Case File, non-stronghold fragment, blame-gated lent escort) with no re-estimate — record as accepted growth and mark the Tier 0 10-18 months as not re-estimated. team.size: studio + workflow: full puts full overhead on a solo developer (owner's call). Art supply and full- vs part-time each move estimates ~2x.

Art Director:       CONCERNS
  Anchor sufficient for GDDs. Run /art-bible (colour, value, readability first) early in Systems Design, before Vigor/Coherence GDDs lock visual tells. Give the art-supply decision a firm milestone. Schedule the glow rendering spike before the Vigor GDD locks visual acceptance criteria.

### Blockers
None.

### Recommendations (Concerns)
1. Revised concept not re-reviewed — run `/design-review design/gdd/game-concept.md`. (All 4 directors.)
2. No art bible; `.claude/docs/workflow-catalog.yaml` lists art-bible as a required Concept-phase step "before systems design", while `references/gate-systems-design.md` does not require it. Followed the gate definition; reconcile the two. Run `/art-bible` early.
3. MVP growth not re-estimated; art supply and full/part-time still open.
4. Prototype conditions not yet carried into downstream acceptance criteria.
5. Housekeeping: build/run commands in project.yaml; concept l.500 wording; record godot-specialist CI notes.

### Verdict: CONCERNS
Chain-of-Verification: 5 questions checked (review log verdicts, Visual Identity Anchor rule and principles, catalog art-bible entry, l.500, git state re-read) — verdict unchanged.

Stage not advanced: remains Concept. No risks were accepted.
