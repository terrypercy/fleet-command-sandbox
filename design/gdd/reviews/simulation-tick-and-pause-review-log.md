# Review Log — Simulation Tick & Pause

## Review — 2026-10-28 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: L
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, gameplay-programmer, ux-designer, performance-analyst; senior: creative-director
Blocking items: 13 | Recommended: 6 groups (clerical, formulas, engine/implementation, UX for /ux-design, missing ACs, naming)
Summary: A careful foundation GDD with the right creative direction; Pillar 3 is well served. The problems were in the precision of the contract: self-contradictory AI and flagship data paths, a D7 logic bug, determinism and performance claims without a defined scope, and blocking ACs that could not be executed. Not a change to what the game is, so not MAJOR REVISION; but every Core system depends on it, so all blockers had to be fixed before epics.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design, rule 3 / Dependencies: AI decisions said to feed P3 the same tick but also "made into the order queue"
- [BLOCKING] Detailed Design, rule 6: Flagship Piloting (#15) absent; no owner, precedence, sampling time or camera frame for the flagship command
- [BLOCKING] Formulas, D7: firing never disarmed (rearm 0 re-fires every tick); no last_fire_tick init/reset; one default for all triggers; late fire
- [BLOCKING] Formulas, D8: 2^24 mislabelled as float32 seconds; integer ticks not made authoritative
- [BLOCKING] Formulas, D2-D4: float accumulator could leave [0,1) and be poisoned by NaN
- [BLOCKING] Interactions: "frozen while held" effect classes had no mechanism
- [BLOCKING] Detailed Design, rule 14: no OS/CPU in header; platform scope unstated; state_hash undefined
- [BLOCKING] Formulas, D6/D10 and rule 8: performance gate undefined (60 fps only, p95 only, no reference machine); the tick cap did not protect the frame
- [BLOCKING] Game Feel: under-50 ms latency claim did not add up (worst case ~67-83 ms at 60 Hz, ~115-132 ms at 30 Hz)
- [BLOCKING] States and Transitions: overlapping derived states, no precedence
- [BLOCKING] Acceptance Criteria: AC-28, -34, -40, -44, -45, -46, -52 not executable as written; lint list incomplete
- [BLOCKING] Player Fantasy: Pillar 1 claim tied Debrief trust to replay equality instead of the Battle Record
- [BLOCKING] Detailed Design, rule 10: mid-battle planning screens not constrained (concept: planning happens between battles)
- [RECOMMENDED] Dependencies: "Not yet listed in the index" table stale; rule 18 out of order; qa-lead note count
- [RECOMMENDED] Formulas: D5 window counted held time; D2 0.99/1.01 s cliff; D9 step ordering; first-contact mostly dead
- [RECOMMENDED] Engine/implementation: physics ban, frame_delta source, begin_frame, AIM_QUANTUM unit, replay-log scope, state_hash/save cost budgets, headless throughput
- [RECOMMENDED] UI Requirements (to /ux-design): indicator/banner layout and cap, "still paused" cue, held vs 0.5x, battle-start opt-out, Tactical step discoverability, gamepad, accessibility
- [RECOMMENDED] Acceptance Criteria: missing ACs (rule 16 option off, D5 after resume, D7 boundaries, replay-log size, content-hash/platform mismatch, order tie-break)

Owner decisions taken in revision (2026-10-28): drop D7 late fire (overrides the earlier decision); honest end-to-end latency target with 30 Hz flagship prediction; same-platform determinism for MVP; planning screens read-only in battle.
Disagreements ruled by creative-director: keep D4 alpha snap; keep rule 18 numbered 18 but moved last; performance gate definition blocking, numbers to spike/ADR; hold data contract here, layout to /ux-design.
Revisions applied the same day: all 13 blockers plus clerical items, in the uncommitted working copy. The stamp below is the REVIEWED (pre-revision, HEAD) content, so the next check reads CHANGED and a full re-review runs.
Reviewed-Content-Hash: design/gdd/simulation-tick-and-pause.md 37cd11f864bcca0c7f9db18e8d84e82c5633e30d
Reviewed-Content-Hash: design/registry/entities.yaml 094b32832f52d0a90d1848be7a7b036fcde3b05f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 91bcce6adab264f2d2a9c18d32312baced1f2597
Reviewed-Content-Hash: design/gdd/systems-index.md 58c7ddbe6ad9e3b58e6e985fafd0b9787036d4f6
