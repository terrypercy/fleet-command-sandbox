# Onboarding & Opening Sequence

> **Status**: Designed (pending review)
> **Author**: owner + agents
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30 · CD-GDD-ALIGN: CONCERNS → revisions applied (pre-contact retreat consumes nothing; lead line shows, not tells; tighter spoiler AC; pass-bar mapping; win card)
> **Implements Pillar**: Pillar 1 (Every Defeat Is a Lead — the game opens with a stronghold you are meant to lose, and teaches that losing is a lead); Pillar 3 (Hands on the Helm — the player flies from the first minute)

## Summary

The opening puts the player at the helm in the first seconds, wins them a small
machine skirmish that teaches flying, one fleet order and cutting a relay, then
sends them into a stronghold built to beat them. That loss costs nothing, and
the first Debrief and Dossier show that it was a lead. This system sequences the
beats, shows non-blocking hints, owns the one-per-save `exempt_lasting_cost`
grant, and offers skip and practice for experienced players.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Battle Resolution & Retreat, Machine Nodes & Strongholds, After-Action Debrief, Dossier`

## Overview

Onboarding & Opening Sequence (#53) runs the first ten to fifteen minutes of a
new campaign. It adds no new combat rules. It orders content that other systems
already define: a weak roaming machine fleet (the **skirmish**), the opening
stronghold `base:node.opening` (Machine Nodes rule 24), the opening-loss Debrief
(Debrief rule 20), the Dossier, and the fallback port (Sector Map rule 26). It
owns three things. (1) The **beat sequence** and its state, saved with the
campaign. (2) **Hints**: short cards, tied to triggers, that never hold the
simulation and never block input. (3) The **exactly-once rule**: the effective
`exempt_lasting_cost` flag goes onto exactly one battle per save, the first
battle against the opening node. At MVP the sequence is a stub (guided skirmish,
text cards, the intended loss, the first Debrief); the fully authored first ten
minutes is Vertical Slice (systems index). This GDD specifies both, and marks
the Vertical Slice parts.

## Player Fantasy

*"I took the helm, I won my first fight, and then something old and patient
took my fleet apart. It cost me nothing, and the report told me exactly how it
did it. I already know what I'll try next."*

Target MDA aesthetics, in order:
- **Challenge** (Pillar 1): the stronghold beats you first. The loss is a
  puzzle with its pieces shown, not a punishment.
- **Sensation** (Pillar 3): you fly the flagship in the first minute. No menu
  stands between you and the helm.
- **Discovery** (Pillar 1): the Debrief and Dossier reveal what beat you. A
  sealed archive aboard the keystone poses the mystery's question without
  answering it.

Self-Determination Theory:
- **Competence**: the skirmish is won by construction (rule 9), so the player
  enters the stronghold having succeeded. The loss that follows is read, named
  and actionable (Debrief rule 20), so competence is not shaken but redirected.
- **Autonomy**: nothing forces the next step. Pause is always available. Hints
  can be dismissed or turned off. The player may skip the whole tutorial layer.
- **Relatedness** (light at MVP): the hook names the makers as people with a
  history, and the factions as people who disagree about it.

Flow: the sequence follows the concept's sawtooth. Tension rises through the
skirmish, releases on its win, rises sharply in the stronghold, and releases in
the Debrief, where "Nothing was lost" removes the anxiety that a harsh start
causes (concept: Starsector's start is the cautionary example).

## Detailed Design

### Core Rules

**A. The beats**

1. **The beat sheet.** A new campaign in **Full** mode (rule 14) runs these beats
   in order. Times are targets at 1× speed, not limits (D1).

   | # | Beat | Target time | What the player does | Taught |
   |---|---|---|---|---|
   | B0 | **Hook card** | ≤ 10 s | Reads one line over the opening shot; any input closes it | The mystery's question (rule 18) |
   | B1 | **Flight** | ~90 s | Flies the flagship in the start system toward a contact marker | Move, aim, fire, camera recentre |
   | B2 | **Skirmish** | ~4 min | Fights the skirmish fleet: one relay and two escorts | Pause/resume, one fleet order, cutting a relay link |
   | B3 | **Approach** | ~1 min | Travels one hop to the opening node; opens its Dossier page; engages from the pre-battle panel | Sector map travel, Dossier (J), readiness |
   | B4 | **Opening battle** | ~5 min | Fights the opening stronghold and, as designed, loses | Nothing new is hinted; the player applies B1–B2 |
   | B5 | **First Debrief** | player-paced | Reads the opening-loss Debrief | "This is what beat you" |
   | B6 | **Dossier** | player-paced | Sees the counters the loss revealed | Where leads live |
   | B7 | **Port** | player-paced | Docks at the fallback port; sees refit and roster | Changing something between attempts |

2. **Beats advance on world events, never on timers.** Each beat has one entry
   event and one exit event (States and Transitions). A beat with no exit event
   yet waits indefinitely. #53 never moves the fleet, never fires, never issues
   orders and never starts a battle for the player.
3. **#53 never adds a hold.** It adds no `PLAYER_PAUSE`, `AUTO_PAUSE`,
   `PLANNING` or `SYSTEM` reason (Simulation Tick & Pause). Teaching moments
   that need a still field ride on the holds that already exist: **Battle
   start** (default ON) and **First enemy contact** (default ON). If the player
   has turned a trigger off in Settings, its hint shows over the live battle.
4. **The skirmish is an ordinary battle.** It carries no exemption. Its outcome
   goes through Battle Resolution like any roaming encounter. The sequence
   advances to B3 whatever its outcome (rule 10).
5. **The opening battle is ordinary except for the flag.** Its only difference
   is the effective exemption (rule 11). Its outcome, report, Debrief, Dossier
   reveals and fallback are all the owners' standard rules.
6. **The sequence ends** (state DONE) when the player first leaves the fallback
   port after B7, or when the exemption is consumed in Skip mode (rule 14). After
   DONE, #53 shows no further hints except the one-time first-loss card
   (rule 13).

**B. Hints**

7. **A hint is a non-modal card.** It sits at a fixed screen corner that the
   HUD reserves (UI Requirements). It never takes focus, never captures input
   and never darkens the field. Each hint has: an id, a trigger, an at most
   two-line text, the action(s) it names, and a **done** condition.
8. **Hint lifecycle** (D3). A hint shows when its trigger fires and D3 allows
   it. It closes on the first of: its done condition (the player performs the
   named action), the player dismissing it (click its × or the "dismiss hint"
   action), or `HINT_TIMEOUT_S` of unpaused real time. A hint that closed by done
   never shows again in this save. One that closed otherwise may show again,
   up to `HINT_MAX_SHOWS` times. At most one hint shows at a time; a newer hint
   queues behind the current one.
9. **Prompts read the live binding table** (Input & Controls rule 21). A hint
   names the action and shows its current key. Rebinding mid-hint updates the
   card on the next frame.
10. **The MVP hint set.** Text is placeholder; final copy is UX and Narrative's.

    | Id | Beat | Trigger | Card (placeholder) | Done when |
    |---|---|---|---|---|
    | `h.move` | B1 | Flight context begins | "[W A S D] to fly. Aim with the mouse." | move axis non-zero for 60 ticks |
    | `h.fire` | B1 | Contact marker within weapon range of the flagship | "[LMB] fires primary." | any fire action |
    | `h.recentre` | B1 | Camera more than one screen from the flagship | "[C] recentres on your flagship." | recentre action |
    | `h.pause` | B2 | `AUTO_PAUSE:battle_start` added | "The battle waits for you. [Space] resumes, and pauses any time." | resume action |
    | `h.relay` | B2 | First enemy contact with the skirmish fleet | "That ship is a relay. It links the machines and keeps them strong." | relay selected or targeted |
    | `h.order` | B2 | `h.relay` closed | "Select your fleet, then [F1] on the relay to focus it." (order name: Fleet Orders #19) | taught order issued on the relay |
    | `h.cut` | B2 | First `relay_cut`-class link event in the skirmish | "Link cut. Unlinked machines are weaker." | — (shows once, closes by timeout or dismiss) |
    | `h.dossier` | B3 | Fleet arrives in the opening node's system | "[J] opens the Dossier: what you know about this place." | Dossier opened on the node page |
    | `h.debrief` | B5 | Opening Debrief opens | Lead line (rule 12) | Debrief closed |
    | `h.port` | B7 | Docked at fallback port | "Refit and roster are here. What would you change?" | any refit or roster screen opened |

    No hint is shown during B4. The opening battle is the player's own.
11. **Hints are presentation only.** They read events and the binding table.
    They write nothing the simulation reads. Their timers are wall-clock and
    sit outside the deterministic simulation. Turning hints off, dismissing
    them or letting them time out changes no outcome.

**C. The exemption (exactly once)**

12. **The lead line.** On the opening-loss Debrief (Debrief rule 20), #53 adds
    one line above the cause block: "This is what beat you." and, under the
    top-ranked cause, its action as "Counter: {cause action}". It never says "try again", never names the opening node
    as a destination and never sets a waypoint back to it. A retry must be the
    player's own idea, because the Tier 0 pass bar measures retry without
    prompt (concept, MVP Definition).
13. **If the opening is won, the lesson moves.** The win is an ordinary win
    (Battle Resolution rule 19): the node breaks and its fragment slot pays out
    under Archive Fragments' standard rules. #53 adds one card on that Debrief:
    "Broken on the first attempt. The archive is open." On the player's **first
    later loss-class Debrief** in this save, #53 shows the lead lines of rule 12
    ("This is what beat you." and "Counter: {cause action}") once, without
    "Nothing was lost" (that loss is not exempt).
14. **The effective flag** (D2). When a battle setup is built against a node,
    #53 supplies `exempt_lasting_cost = node.exempt_lasting_cost AND NOT
    save.opening_exempt_consumed`. Battle Resolution copies this value, never the
    raw node field. Only `base:node.opening` has the node field true (Machine
    Nodes rule 1: at most one per save).
15. **Consumption.** `save.opening_exempt_consumed` becomes true when Battle
    Resolution publishes the report of a battle whose setup carried the flag
    true, whatever the outcome: win, loss, retreat, standoff or mutual. It is
    written in the same save transaction as the outcome. A battle with no
    report (application closed or crashed mid-battle) consumes nothing; the
    deterministic setup is rebuilt from the last save. Exception: a
    PLAYER_RETREATED report with no first enemy contact consumes nothing.
16. **Never re-granted.** Nothing resets `opening_exempt_consumed` in a save:
    not a settings change, not a reload of an older save of the same campaign
    (that save simply predates the consumption), not skip or practice. A new
    campaign has its own save and its own one grant.
17. **The exemption is shown only while it is live.** The Dossier quote
    (Dossier rule 18) and the pre-battle panel show "A loss here costs nothing"
    only while D2 evaluates true for that node. After consumption the opening
    node shows Credits' ordinary defeat quote.

**D. The mystery hook**

18. **The hook is truth-neutral.** Every hook line must be true under every
    seeded truth and every red herring (Gameplay Settings rule 9: difficulty
    never touches the truth; Archive Fragments' truth-blind wording). It may
    state only: machines exist and guard places; someone made them; the people
    of the sector disagree about who; a sealed archive is aboard this node. It
    never names, ranks, hints at or excludes a candidate maker, a time period or
    a motive. Intent line for Narrative (placeholder, not final copy): *"Someone
    built the machines. Everyone you'll meet has a different answer to who."*
19. **Where the hook appears.** B0 (one line); the opening node's Dossier page,
    which shows its fragment slot as "Archive: sealed — break this node to read
    it" (Archive Fragments' opening slot, one of the 3 MVP node slots); and the
    opening Debrief's footer, which repeats the sealed line. Nothing in the
    hook changes with the outcome.

**E. Skip, practice and replay**

20. **New-campaign choice.** The new-campaign screen offers **Full opening**
    (default on a profile with no finished opening) and **Skip to the sector**
    (default once any campaign on the profile has reached DONE). It is a
    one-line choice, not a dialogue.
21. **Skip to the sector** starts the fleet docked at the start port. The B0
    card still shows once (≤ 10 s, closable). B1, B2 and all hints are
    skipped. The opening node, its flag and its sealed slot are unchanged:
    the experienced player keeps their one free attempt. The sequence is in
    state SKIPPED until the exemption is consumed, then DONE.
22. **Stop hints mid-sequence.** The system menu has "Stop tutorial hints" for
    the current save. It turns hints off but changes no beat or flag. The
    profile setting `onboarding_hints` (on/off) is the default for new saves.
23. **Practice skirmish.** The main menu's Practice entry runs the B2 skirmish
    with its hints, outside any campaign. It writes no save, sends nothing to
    any cost consumer and has no exemption to consume. It is the replay path for
    the controls tutorial. The opening battle itself has no replay: a new
    campaign replays it.
24. **No escort in the opening.** Allied Lending offers no loan while
    `opening_exempt_consumed` is false, so the opening battle is always fought
    by the player's own fleet and the Machine Nodes rule 22 proof holds.

**F. Content constraints**

25. **The skirmish fleet** (`base:roam.opening_skirmish`, working name):
    one relay and two escorts, placed in the start system at least one screen
    from the flagship's spawn. It must pass the **skirmish proof**: the MVP
    starting fleet with default doctrine and the flagship issuing no input wins
    every `PROOF_SEEDS` battle, at every Settings value that affects roaming
    fleets (D4). That makes the first win the player's by construction.
26. **The start position.** The campaign starts in a system with the free port
    (Sector Map rule 3), `OPENING_HOPS` (default 1) hops from the opening node.
    The fallback port after the opening loss is therefore the start port in the
    default layout.

### States and Transitions

**Sequence state** (`save.opening_state`)

| State | Entered when | Leaves to |
|---|---|---|
| NOT_STARTED | save created | HOOK (Full), SKIPPED (Skip) |
| HOOK | campaign tick 0 | FLIGHT (card closed or 10 s) |
| FLIGHT | hook closed | SKIRMISH (skirmish battle context begins) |
| SKIRMISH | skirmish battle begins | APPROACH (skirmish report published, any outcome) |
| APPROACH | skirmish report published | OPENING_BATTLE (battle against the opening node begins) |
| OPENING_BATTLE | opening battle begins | DEBRIEF (report published) |
| DEBRIEF | opening report published | DOSSIER (Debrief closed) |
| DOSSIER | Debrief closed | PORT (fleet docked at the fallback port, or at any port after a win) |
| PORT | docked | DONE (fleet departs the port) |
| SKIPPED | Skip chosen | DONE (exemption consumed) |
| DONE | see above | — |

Leaving the route during APPROACH (travelling elsewhere, fighting other
contacts) does not change state. Hints for later beats simply wait for their
triggers.

**Exemption** (`save.opening_exempt_consumed`)

| Value | Meaning | Changes when |
|---|---|---|
| false | the opening node's next battle is exempt | a report of a battle whose setup carried the flag is published |
| true | no battle in this save is exempt | never |

### Interactions with Other Systems

| System | Direction | What crosses | Rule |
|---|---|---|---|
| Battle Resolution & Retreat (#22) | #53 → #22 | Effective `exempt_lasting_cost` in the setup (D2) | 14 |
| Battle Resolution & Retreat (#22) | #22 → #53 | Report published, `opening_loss`, outcome class | 13, 15 |
| Machine Nodes & Strongholds (#23) | #23 → #53 | `base:node.opening`, `exempt_lasting_cost`, `first_encounter`, rule 22 proof | 14, 25 |
| Vigor (#13) / Credits (#18) | via #22 | Rule 18 / rule 8 exemptions keyed on the setup flag | 5 |
| After-Action Debrief (#24) | #24 → #53 | Opening-loss presentation (rule 20); #53 adds lead line and win/first-loss cards | 12, 13 |
| Dossier (#47) | #53 → #47 | Effective flag for the rule 18 quote; sealed-slot line | 17, 19 |
| Gameplay Settings (#7) | both | `onboarding_hints`; trigger toggles read; rule 10a unchanged | 3, 22 |
| Input & Controls | #53 reads | Live binding table, action events | 9, 10 |
| Simulation Tick & Pause | #53 reads | `AUTO_PAUSE:battle_start`, first-contact holds | 3 |
| Sector Map & Travel (#26) | both | Start system, `OPENING_HOPS`, fallback placement | 26 |
| Archive Fragments (#28) | #28 → #53 | Opening slot status (sealed/granted) | 19 |
| Allied Lending | #53 → Lending | No loan while unconsumed | 24 |
| Combat HUD | #53 → HUD | Pre-battle exemption line; hint corner | 17, UI |
| Telemetry & Playtest Logging (#54) | #53 → #54 | Onboarding events (Dependencies) | — |

## Formulas

### D1. Time to first Debrief (budget, not a limit)

`T_first = T_hook + T_flight + T_skirmish + T_approach + T_battle`

| Variable | Meaning | Target (s, 1×, unpaused) | Range |
|---|---|---|---|
| `T_hook` | B0 | 10 | 0–10 |
| `T_flight` | B1 | 90 | 45–150 |
| `T_skirmish` | B2 | 240 | 150–360 |
| `T_approach` | B3, incl. Dossier read | 60 | 30–180 |
| `T_battle` | B4 to defeat | 300 | 180–480 |

Constraint: designed `T_first ≤ FIRST_DEBRIEF_BUDGET_S` (900 s). Paused time is
excluded (pause is never graded, Simulation Tick rule 18).

Worked example: 10 + 90 + 240 + 60 + 300 = 700 s (11 min 40 s) ≤ 900 s, a
margin of 200 s. Worst case of the ranges: 10 + 150 + 360 + 180 + 480 = 1,180 s,
which breaks the budget; content tuning must keep the sum of the medians, not
the worst case, inside it, and the playtest (AC-21) checks real players.

### D2. Effective exemption

`exempt(setup) = node.exempt_lasting_cost ∧ ¬save.opening_exempt_consumed`

For a non-node battle (roaming fleet, skirmish), `exempt = false`.

Worked example: first battle at `base:node.opening`: true ∧ ¬false = **true**.
Report published (any outcome) → consumed = true. Second battle there:
true ∧ ¬true = **false**. A battle at another stronghold: false ∧ … = **false**.

### D3. Hint show test

`show(h) = hints_on ∧ triggered(h) ∧ ¬done(h) ∧ shows(h) < HINT_MAX_SHOWS ∧ no_hint_visible`

If all but `no_hint_visible` hold, `h` queues (FIFO); a queued hint whose beat
has ended is discarded. Timeout counts only frames where the simulation is not
held, so a hint is never lost while the player reads with the game paused.

Worked example: `HINT_MAX_SHOWS` 2. `h.order` times out once (`shows` 1). The
trigger cannot refire (`h.relay` already closed), so it stays closed: shows is
1 < 2 but `triggered` is false. `h.fire` times out, then the flagship comes
back in range: triggered, not done, 1 < 2 → shows (`shows` 2). It times out
again; a third range entry gives 2 < 2 false → never shown again.

### D4. Skirmish proof

`skirmish_ok = ∀ seed ∈ PROOF_SEEDS, ∀ v ∈ settings_affecting_roamers: outcome(seed, v, flagship_idle) ∈ win_class`

Run by the AI-vs-AI Runner (#25) at build time, like Machine Nodes rule 22's
inverse proof. One failure fails the build's content check.

## Edge Cases

- **The player wins the opening.** Ordinary win: node breaks, fragment slot
  pays out, exemption consumed (rule 15). Win card shows (rule 13). Vigor still
  restores `C` because it keys on the setup flag (Vigor rule 18); that is
  harmless and consistent with Battle Resolution rule 19. The lead line moves to
  the first later loss.
- **The player retreats at once.** PLAYER_RETREATED is loss class, so
  `opening_loss` is true and nothing is charged. If the retreat came after first
  enemy contact, the exemption is consumed and Dossier rule 10a reveals
  something if any counter was evidenced. If it came before first contact, the
  exemption is **not** consumed (rule 15 exception): the player learned nothing,
  so the free lesson is kept and the next setup at the opening node still
  carries the flag.
- **The player never goes to the opening node.** Nothing forces them. The flag
  waits. Their first battle there, however late, is exempt. Hints for B3–B7
  wait for their triggers.
- **The player fights another stronghold first** (Skip mode or roaming off
  route). That battle is ordinary and costs normally; the opening node keeps its
  flag. The Dossier shows each node's own quote, so the difference is visible.
- **The skirmish is lost or retreated from.** Ordinary loss-class outcome with
  ordinary costs from the starting hold, and the sequence still advances to B3
  (rule 4). The skirmish proof (D4) makes this require active effort. Open
  Question 1 asks whether it should also be free.
- **A crash or quit mid-opening battle.** No report, so no consumption (rule
  15). Reload rebuilds the same deterministic setup; the flag is still live.
- **Reloading a save from before the opening battle.** That save has
  `consumed = false`, legitimately: it is an earlier point in time, not a reset
  (rule 16). Save-scumming the exempt battle yields nothing a free loss does
  not already give.
- **Settings at the Custom minimums.** The opening still wins first (Settings
  rule 10a, Machine Nodes rule 22). #53 changes nothing about strength.
- **Auto-pause triggers turned off.** `h.pause` and `h.relay` show over a live
  battle (rule 3). The text still says Space pauses.
- **Hints off and Full mode.** Beats run with no cards; the content still
  teaches by its shape (a relay in a small fight, the sealed line in the
  Dossier).
- **Rebinding during a hint.** The card updates (rule 9). A rebinding screen
  holds the battle (Input rule 20); hint timeout does not run.
- **Headless runs** (AI-vs-AI Runner, tests). #53 is inactive; the flag is
  supplied by the test setup and D2 is unit-tested directly.
- **Two hints trigger on one tick.** The first in the rule 10 table order shows;
  the other queues (D3).

## Dependencies

| System | Type | Interface |
|---|---|---|
| Battle Resolution & Retreat (#22) | Hard | Setup flag in; report, `opening_loss`, outcome class out |
| Machine Nodes & Strongholds (#23) | Hard | Opening node, flags, proofs (rules 1, 22, 24) |
| After-Action Debrief (#24) | Hard | Rule 20 presentation; card slots for rules 12–13 |
| Dossier (#47) | Hard | Rule 18 quote reads D2; sealed-slot line |
| Vigor (#13), Credits (#18) | Hard (via #22) | Rule 18, rule 8 |
| Simulation Tick & Pause | Hard | Hold events (read only) |
| Input & Controls | Hard | Live binding table, action events |
| Sector Map & Travel (#26) | Hard | Start system, fallback port |
| Gameplay Settings & Modifiers (#7) | Soft | `onboarding_hints`, trigger toggles |
| Archive Fragments (#28) | Soft | Opening slot state |
| Allied Lending | Soft | Loan gate (rule 24) |
| Combat HUD | Soft | Pre-battle line, hint corner |
| Fleet Orders (#19) | Soft | Name of the taught order |
| AI-vs-AI Runner (#25) | Soft | D4 proof |
| Telemetry & Playtest Logging (#54) | Soft (reverse) | Events below; #54 owns the schema |

**Telemetry hooks for #54** (emitted on the event bus, never read from UI):
`ONBOARDING_STARTED {mode}`, `ONBOARDING_BEAT {state, campaign_tick}`,
`HINT_SHOWN {hint_id}`, `HINT_CLOSED {hint_id, how: done|dismissed|timeout}`,
`HINTS_STOPPED`, `OPENING_EXEMPT_CONSUMED {outcome}`, `ONBOARDING_DONE`. Wall
time is stamped by #54, outside the simulation.

## Tuning Knobs

All in `assets/data/onboarding/opening.tres` (path proposed; data, not code).

| Knob | Category | Default | Safe range | Affects | Rationale |
|---|---|---|---|---|---|
| `HINT_TIMEOUT_S` | Feel | 12 | 6–30 | How long an unheeded card stays | Long enough to read two lines twice; short enough not to nag |
| `HINT_MAX_SHOWS` | Feel | 2 | 1–3 | Repeat nagging | One reminder, then trust the player |
| `FIRST_DEBRIEF_BUDGET_S` | Gate | 900 | 600–1,200 | Content length check (D1) | Concept: "first 10 minutes" plus margin |
| `OPENING_HOPS` | Gate | 1 | 1–2 | Distance start → opening node | One hop keeps B3 short and teaches travel once |
| `HOOK_CARD_MAX_S` | Feel | 10 | 5–15 | B0 length | The player should be at the helm in seconds |
| Skirmish composition | Curve | 1 relay, 2 escorts | must pass D4 | First fight difficulty | Smallest fleet that shows a link |
| `onboarding_hints` (profile) | Feel | on | on/off | Hint default for new saves | Assists group (Settings rule 18) |

## Visual/Audio Requirements

- Hint cards share the HUD's panel style; no new art at MVP.
- The opening keystone needs a readable "sealed archive" marker on the
  Dossier page (icon from the Archive Fragments set).
- Vertical Slice: an authored B0 opening shot and a distinct musical sting on
  "Nothing was lost" (Audio #52). Art and audio direction are their owners'.

## Game Feel

- The player has control of the flagship within `HOOK_CARD_MAX_S` of pressing
  New Campaign. No loading of tutorial screens between.
- Hints appear without motion that draws the eye from combat (fade only, no
  slide or bounce), and close the frame their done condition is met.
- The stronghold's first moments should read as calm and heavy (Anvil
  contracts slowly), so the loss feels like a machine working, not a spike.
- The Debrief's "Nothing was lost" is the release beat of the sawtooth; it is
  the first thing read.

## UI Requirements

- **Hint corner**: a reserved region the Combat HUD and Sector Map never
  cover; the card shows text, the current key glyph(s) and a × button.
- **System menu**: "Stop tutorial hints" while hints are on in this save.
- **New-campaign screen**: Full opening / Skip to the sector (rule 20).
- **Main menu**: Practice skirmish (rule 23).
- **Pre-battle panel** and **Dossier node page**: "A loss here costs nothing"
  while D2 is true (rule 17); "Archive: sealed" line.
- **Debrief**: lead line slot, win card slot, footer hook line.
- All text is keyboard-navigable and readable at the HUD's minimum text scale
  (Accessibility requirements).

## Cross-References

- `design/gdd/game-concept.md` — Flow State Design (onboarding curve), MVP
  Definition (Tier 0 pass bar).
- `design/gdd/machine-nodes-and-strongholds.md` — rules 1, 22, 24.
- `design/gdd/battle-resolution-and-retreat.md` — rule 19.
- `design/gdd/vigor.md` rule 18; `design/gdd/credits-upkeep-and-sinks.md` rule 8.
- `design/gdd/after-action-debrief.md` rule 20.
- `design/gdd/dossier.md` rules 10a, 18.
- `design/gdd/gameplay-settings-and-modifiers.md` rules 9, 10a, 18.
- `design/gdd/simulation-tick-and-pause.md` rules 11, 18 (auto-pause table).
- `design/gdd/input-and-controls.md` rules 3, 20, 21.
- `design/gdd/sector-map-and-travel.md` rules 3, 26.
- `design/gdd/archive-fragments-and-evidence.md` (MVP slots).
- `design/gdd/allied-lending.md` rule 14.

## Acceptance Criteria

- **AC-01 (Logic; rule 14)**: D2 returns true for the first setup at `base:node.opening` and false for any other node, any roaming fleet and the skirmish.
- **AC-02 (Logic; rule 15)**: after a report of a flagged battle is published with each outcome (win, loss, retreat after first enemy contact, standoff, mutual), `opening_exempt_consumed` is true and the next setup at the opening node has the flag false; a published PLAYER_RETREATED report with no first enemy contact leaves `opening_exempt_consumed` false and the next setup's flag true.
- **AC-03 (Logic; rule 15)**: a flagged battle aborted without a report leaves `opening_exempt_consumed` false; reloading rebuilds an identical setup (same hash).
- **AC-04 (Logic; rule 16)**: no settings change, mode change or Practice run sets `opening_exempt_consumed` back to false.
- **AC-05 (Integration; rules 5, 14)**: an opening loss leaves Credits hold, Vigor `C` and campaign day unchanged, and the Debrief shows rule 20's struck-through costs.
- **AC-06 (Integration; rule 13)**: a scripted opening win breaks the node, grants its fragment, shows the win card and no "Nothing was lost"; the next loss-class Debrief shows the lead line once and costs normally.
- **AC-07 (Logic; rule 3)**: across a full scripted opening, #53 adds zero hold reasons (hold log contains no reason sourced from #53).
- **AC-08 (Logic; rule 11)**: the opening battle replayed with hints on, off and all dismissed produces identical reports.
- **AC-09 (Logic; D3)**: the D3 worked example reproduces exactly; timeout does not advance while the simulation is held.
- **AC-10 (UI; rule 9)**: rebinding fire to another key while `h.fire` shows updates its glyph on the next frame (screenshot).
- **AC-11 (UI; rule 10)**: each MVP hint appears at its trigger in the hint corner and closes on its done condition (one retained screenshot per hint).
- **AC-12 (UI; rule 17)**: the opening node's Dossier page and pre-battle panel show "A loss here costs nothing" before consumption and Credits' ordinary quote after.
- **AC-13 (UI; rule 12)**: the opening-loss Debrief contains the lead line and contains none of "try again", "retry", "next time", the node's name as a destination, or a waypoint.
- **AC-14 (Logic; rule 24)**: Allied Lending offers no loan while unconsumed.
- **AC-15 (Logic; rule 25, D4)**: the skirmish proof passes in every `PROOF_SEEDS` battle at every roamer-affecting setting; a weakened starting fleet fixture makes the check fail.
- **AC-16 (Integration; rule 21)**: Skip mode starts docked at the start port with no hints, and the first battle at the opening node is exempt.
- **AC-17 (Integration; rule 23)**: a Practice run writes no save file and emits no cost-consumer call.
- **AC-18 (Logic; rule 2)**: with the player idle, the sequence state never advances past FLIGHT and #53 issues no movement, fire or order commands.
- **AC-19 (UI; rule 18)**: every hook line is reviewed against each seeded truth and the red herring; the review record shows it is true under all of them (Narrative sign-off).
- **AC-20 (Logic; Dependencies)**: each telemetry event fires once at its transition with the listed fields.
- **AC-21 (Playtest; D1, rule 1)**: in the Tier 0 cohort (≥ 5 testers, ≥ 3 new to the genre), at least 4 of 5, including at least 2 of 3 new to the genre, reach the first Debrief with no moderator help, with median unpaused time ≤ `FIRST_DEBRIEF_BUDGET_S`.
- **AC-22 (Playtest; rules 12, 15; concept pass bar 1)**: at least 4 of 5, including at least 2 of 3 new to the genre, start a new attempt on the opening node after the opening loss without a moderator prompt (same or next session), using the concept's Pass-bar definitions (MVP Definition) verbatim.
- **AC-23 (Playtest; rule 1 B7; concept pass bar 2)**: at least 4 of 5, including at least 2 of 3 new to the genre, show a logged loadout change (roster, refit or order set) between the opening attempt and their next attempt on it, using the concept's Pass-bar definitions (MVP Definition) verbatim.
- **Concept pass bar 3 (share reason)** is outside #53; it is measured by Public History Screen AC-21 and Faction Belief & Blame's ACs.
- **AC-24 (Playtest; rules 12, 19)**: asked after the Debrief "why did you lose?", at least 4 of 5 name a cause matching the Debrief's top-ranked cause; asked "who built the machines?", answers are spread across candidates or "don't know", with no candidate given by more than 2 of 5 citing the opening alone (the hook did not give away the maker).
- **AC-25 (Playtest; Player Fantasy)**: at most 1 of 5 describes the opening loss as unfair or as a punishment in the post-session interview; at least 4 of 5 use the taught fleet order unprompted in the opening battle.

## Open Questions

Resolved with the recommended defaults under the owner's standing instruction to
proceed (the owner may revisit any of them at review):
- **A skirmish loss is an ordinary loss** (no second exemption mechanism); the
  build-time check (D4) makes it unlosable with the flagship idle.
- **No retry prompt at Tier 0**: no "try again", no waypoint back; the
  Debrief's lead does the work (Pillar 1's design test).
- **A retreat before first contact consumes nothing** (CD review reversed the earlier default): a free lesson is never lost without a lesson.
- **The pre-battle slot** is Combat HUD & Tactical Overlay rule 16's panel.
- **The order taught at B2 is F1 Attack** (Fleet Orders).

| # | Question | Recommendation | Owner |
|---|---|---|---|
| 6 | Does Sector Map already guarantee the start system and `OPENING_HOPS` 1? | Amend Sector Map to state it (rule 26). | Sector Map owner |
| 7 | Final hook copy and the "Nothing was lost" framing line. | Narrative writes within rule 18's constraint. | narrative-director |
| 8 | Telemetry schema and wall-clock stamping. | #54 adopts the event list above. | #54 owner |
| 9 | Do any Settings values scale roaming fleets? Determines D4's sweep. | Sweep all Tier C values that touch roamers. | Settings owner |
