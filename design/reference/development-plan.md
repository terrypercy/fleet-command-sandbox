# Building an Original Fleet-Command Space Sandbox: What Starsector Is and How a Studio Could Make a Game in Its Genre

> **Source:** development plan supplied by the project owner at onboarding (2026-10-28).
> Reference material, not a GDD. Skills read it as input; the design record is
> built from it by `/brainstorm`, `/map-systems` and `/design-system`.

A game like Starsector can be built legally as an original game by a small studio. The realistic path is a 4–6 person core team, a combat-first prototype, an Early Access launch after about 2 years, and a total budget of roughly CA$1.5–2.5M before Ontario tax credits. The rules of the genre (fleet battles, trading, factions, colonies) can be reused. Starsector's names, setting, art, code and specific designs cannot.

## TL;DR

- **What Starsector is:** a finished, playable, commercial game that is still in alpha. It is not a set of design documents or a prototype. Fractal Softworks, led by Alex Mosolov, has worked on it since 2009 and has sold it since 2011 as a US$15 pre-order from its own website only. It runs on a custom Java engine with LWJGL, and it is built from data files that make it very easy to mod. The current release is 0.98a (2025), and 0.98.5a is in development in October 2026.
- **How a studio would make one:** build the real-time fleet combat first and prove it is fun. Then add the campaign layer (sector map, factions, simplified economy, missions, colonies) on top of a data-driven engine (Godot or Unity are recommended over a custom engine). Ship to Steam Early Access, keep updating publicly, and support modding.
- **Budget and timeline:** about CA$1.5–2.5M over roughly 3 years for a lean 4–6 person Ontario team, or CA$5–7M for a 12–15 person team. Ontario's 40% refundable OIDMTC, plus Ontario Creates and CMF programs, can cover a large share of labour costs. The biggest risks are scope creep, the economy simulation and ship AI, all of which Starsector itself struggled with.

## Part 1 — What Starsector Is

### Overview

| Item | Detail |
|---|---|
| Genre | Open-world, single-player space RPG/sandbox: real-time top-down fleet combat, trading, exploration, fleet management, colony building |
| Developer | Fractal Softworks, a very small independent studio led by Alex Mosolov |
| Origins | Earliest code revision dates to late 2009. Public alpha released April 29, 2011, under the name "Starfarer". Renamed Starsector at version 0.54.1a |
| Current status (Oct 2026) | Version 0.98a released March 27, 2025, last hotfixed as 0.98a‑RC8 on April 18, 2025. Version 0.98.5a is "In Development", with patch notes updated October 6, 2026. A June 2026 dev blog post introduced an "Extended Mode". Still no 1.0 |
| Platforms | Windows, macOS, Linux |
| Price / distribution | US$15 pre-order, which includes all future updates and the final version. Sold only from the developer's website, not on Steam |
| Engine | Custom engine written in Java using LWJGL (OpenGL). Updated to Java 17 in 0.98a for better performance |
| Team | Credits list Alex Mosolov (dev and design lead), David Baumgart (art, design, writing, coding), Stian Stark (music, sound design) and Ivaylo Kovatchev (writing, design, coding, credited "in loving memory"). Two volunteers are thanked for QA and testing |
| Influences | Star Control 1 and 2, Wing Commander: Privateer, Sid Meier's Pirates!, Solar Winds, MechWarrior 4: Mercenaries, Master of Orion 2 |

### What form it exists in

Starsector is a **playable, commercially sold game in a long-running pre-release ("alpha") state**. It is not a design document, a pitch or a tech demo. Anyone who pays the pre-order price can download the full current build. What exists publicly:

- **Playable builds** for all three desktop platforms, with major versions released roughly every 1–2 years (0.9a in 2018, 0.95a in 2021, 0.96a in 2023, 0.98a in 2025).
- **A developer blog** with design essays on topics such as the combat simulator, skill redesigns, writing missions, and "Extended Mode", plus **detailed public patch notes** on the official forum.
- **No formal public roadmap with dates.** Releases ship "however long it takes for all the new features to make sense when taken together, and be reasonably polished," as Mosolov put it. A Steam release has been discussed for years but is held back until the game is roughly "1.0-ish."
- **Moddable game data and a public modding API.** The game's code is not open source, and parts of the core are obfuscated. Ship, weapon and faction data, however, are stored in readable CSV and JSON files.

### Core gameplay systems (genre conventions)

**Combat layer (real-time, top-down, pausable):**
- The player pilots one ship directly and gives orders to AI-controlled allies (escort, defend, attack, retreat, capture objectives).
- The central mechanic is **flux**, a heat-like resource. Ships build it up by firing weapons and by blocking hits with shields. Pushing past capacity causes an "overload" that leaves the ship briefly helpless. "Soft" flux drains on its own. "Hard" flux, from shield hits, drains only when shields are lowered. The core skill in combat is managing your own flux while pushing the enemy's flux up.
- Damage types interact with defences. For example, kinetic weapons do 200% damage to shields, while high-explosive weapons favour armour.
- Hulls have weapon mount slots. "Variants" are loadouts. Hull modifications change stats. Each ship has one built-in special system. Officers with skills captain AI ships.
- After battle, the player can salvage wrecks or recover them to join the fleet.

**Campaign layer (real-time on a strategic map):**
- A sector map of hand-made core star systems plus procedurally generated systems for exploration.
- Seven joinable factions (the player can also stay independent, according to Wikipedia's summary of the game), each with reputations, laws and contraband lists.
- A market economy with tariffs and a black market. Mission and bounty boards. Planet surveying.
- Player colonies with industries, which over time let the player run their own faction.
- Character levelling with skill points, and a "story point" currency for special choices.
- A light main story that the player uncovers gradually. Mosolov wants players to "create their own story."

### Tech and data approach (lessons for a new studio)

- **Data-driven content.** Ships are defined by a row in a `ship_data.csv` spreadsheet (balance stats such as hitpoints, armour and flux) plus a JSON `.ship` file (geometry, weapon slot positions, engine locations). Weapons follow the same pattern with `weapon_data.csv` and `.weapon` files. Designers can rebalance in a spreadsheet without touching code.
- **Script hooks.** Mods can add Java or Kotlin code against the published API. Mosolov has said that using the modding API for the game's own core development "improves the modding API tremendously."
- **Mod scene.** The community is very active, with library mods and total-conversion-scale mods. The best known is Nexerelin, which adds 4X-style faction wars, diplomacy and planetary conquest and was still being updated in September 2026. Mods have greatly extended the game's lifespan.

### How such a small team built it

- **Funding came from early sales, not a publisher.** In an October 2020 Indie Retro News interview, Mosolov said: "I had some savings when I started," and pre-order revenue kept development going, though "it got pretty close a few times, to where I was wondering if I'd have to get a full-time job again (at least for a bit)."
- **Coverage drove sales.** Coverage by TotalBiscuit, Beaglerush and others was critical, especially SsethTzeentach's video "Starsector Review | Explore the Cosmos™ | Ruin Everything™", uploaded August 2, 2019. A Fractal Softworks forum thread recorded it passing 5 million views, Filmot now lists it at about 6.8 million, and it briefly brought down the purchase site. Mosolov called it "a breakthrough moment." No official sales figures have been published.
- **Rewrites were expensive.** In the same October 2020 Indie Retro News interview, Mosolov names the **economy** as the biggest obstacle: "It's been through something like 4 or 5 revisions, progressing from more simulationist to more and more abstracted with each one," because what emerged from the simulation "usually isn't desirable, and it's all hidden from the player anyway, *and* it eats up CPU cycles."
- **Ship AI is a permanent workload.** Fourteen years in, forum threads still discuss AI positioning problems, and players have made full AI-replacement mods.
- **Art style:** detailed 2D top-down ship sprites with a "kitbashed" industrial look, painted character portraits and illustrations, and an original soundtrack. The art was made almost entirely by one artist, which keeps the look consistent and the cost low, but also limits how fast content can be produced.

## Part 2 — The Development Plan (Original IP)

### 1. Game concept outline (placeholder, to be developed with the studio)

**Working title:** *[Original Title TBD]*, a single-player fleet-command sandbox set in an original universe.

- **Pitch:** "Command a fleet of customizable starships in real-time tactical battles, then trade, explore, take contracts and build colonies across a living, contested region of space."
- **Originality rules:** an original setting and history, original factions with their own visual languages, original ship designs and names, and an original combat resource. Do not use a "flux" clone. For example, a power or heat-distribution mechanic designed from scratch could fill the same role. Use a different visual identity, such as a distinctive palette, a modular ship-construction look, or a different camera or UI style.
- **Suggested differentiators** to discuss with the studio: a clearer and shorter main story, a readable abstracted economy from day one, stronger fleet-wide AI tactics, built-in mod tools, and Steam Workshop support from Early Access.

### 2. Core feature list

| Priority | Feature |
|---|---|
| Must-have (Early Access) | Real-time top-down combat with pause; ~4 ship size classes; 25–40 hulls; 40–60 weapons; loadout/refit screen; player piloting + fleet orders; ship AI; post-battle salvage and recovery; sector map with ~30–60 systems (mix of hand-made and procedural); 4–6 factions with reputation; markets and simple economy; procedurally generated missions/bounties; character skills; save/load and autosave; mod support for data files |
| Should-have (by 1.0) | Colonies and industries; officers with skills; exploration content (derelicts, ruins, anomalies); main story arc; endgame threats; tutorials; achievements/cloud saves; Workshop |
| Nice-to-have (post-launch) | Scripting API for mods; alternate game modes; expansions; console/Steam Deck optimization |

### 3. Team layout

| Role | Lean indie (4–6 core) | Mid-size (12–15) |
|---|---|---|
| Creative director / lead designer | 1 (often also producer) | 1 |
| Producer / project manager | shared | 1 |
| Systems & economy designer | shared with lead | 1–2 |
| Content/mission designer + writer | contract writer | 1–2 |
| Gameplay programmer (combat, ships) | 1 | 2 |
| AI programmer (ship + faction AI) | shared | 1 |
| Engine/tools/UI programmer (data pipeline, mod tools, saves) | 1 | 1–2 |
| 2D ship/sprite artist | 1 | 2 |
| UI/UX artist | contract | 1 |
| Illustrator (portraits, events) | contract | 1 |
| Audio (music + SFX) | contract | 1 (or contract) |
| QA | community + contract | 1–2 |
| Community/marketing | part-time | 1 |

Starsector shows that 3–4 multi-skilled people can ship a deep game. They did it over more than 15 years, however. A paid studio has to compress that, which is why even the lean option assumes 4–6 people plus contractors.

### 4. Tech approach

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Godot 4** | Free, MIT licence, no royalties or seat fees; strong native 2D; text-based scene files suit version control and modding | Smaller talent pool; consoles via third-party porters | **Recommended** for a 2D-first lean team |
| **Unity 6** | Huge talent pool and asset store; mature console pipeline | Personal tier only under US$200K revenue/funding; Pro rose from US$2,200 to US$2,310/seat/year on January 12, 2026 (a 5% increase, reported by 80.lv); 2023 Runtime Fee episode (cancelled 2024) shows terms can change | **Strong alternative**, especially for a mid-size team |
| **Unreal 5** | Top-tier 3D, source access | Overkill for 2D; 5% royalty above threshold; heavier pipeline | Not recommended for this genre |
| **Custom engine (e.g., Java + LWJGL, as Starsector uses)** | Full control and performance | Years of extra engineering; Starsector's path was possible because its lead programmer *was* the engine | Avoid unless the studio already has a proven in-house engine |

**Architecture principles:**
- **Two-layer design.** Separate *combat* (a real-time physics/projectile simulation and per-ship AI) from the *campaign* (a strategic tick-based simulation of fleets, markets and factions). Link them only through a battle-setup and battle-result interface. Each layer can then be built and tested on its own.
- **Data-driven everything.** Ships, weapons, hull modifications, factions, commodities and missions live in spreadsheet or JSON files that load at startup. Designers balance in spreadsheets, and modders use the same files.
- **Mod support from day one.** Use a "mods folder overrides base data" loading order, keep IDs and file formats stable, and publish an API. Starsector's experience shows that building your own content through the mod API makes the API better.
- **Abstracted economy.** Begin with a simple supply/demand model per market (each industry produces and consumes goods, and prices follow shortages and surpluses) rather than a full simulation of individual traders. This follows Starsector's own lesson.
- **Layered AI.** Use separate controllers for per-ship combat (movement, shields, weapon groups), fleet tactics (formations, targeting), and campaign faction AI (patrols, raids, expansion). Build a batch "AI vs AI" auto-battle tool early so balance and AI regressions can be tested overnight.
- **Procedural generation.** Use seeded generation of star systems (star types, planets, resources, points of interest) around a hand-made core region, so the world is both curated and replayable.
- **Save system.** Use versioned save files with migration code. Saves must survive updates during Early Access, and Starsector's community values save compatibility highly.
- **Tools.** Build an in-game ship editor (weapon slots, collision outlines, engine positions) and a combat simulator. Starsector's simulator was added early and later became a major feature in its own right.

### 5. Phased roadmap with milestones (lean team)

| Phase | Duration | Key deliverables / exit criteria |
|---|---|---|
| **0. Concept** | 1–2 months | Pitch deck, one-page concept, competitor analysis, high-level budget, engine decision, IP clearance check (name/trademark search) |
| **1. Pre-production** | 3–4 months | Game Design Document (GDD), Technical Design Document (TDD), art bible (style frames, 3 sample ships per faction), data schema for ships/weapons |
| **2. Combat prototype** | 3–4 months | Playable 1-vs-many skirmish with 6–8 hulls and ~10 weapons, core resource mechanic, basic AI, refit screen. **Gate:** external playtesters want to replay it |
| **3. Vertical slice** | 4–6 months | One small sector (5–8 systems), 2 factions, trading, 3 mission types, battle-to-campaign loop, save/load, Steam page live for wishlists. **Gate:** the slice is fun for 2+ hours; funding applications submitted |
| **4. Production → Early Access** | 8–12 months | Full Early Access feature set (see must-haves), mod loading, onboarding/tutorial, localization hooks, performance pass, demo for Steam Next Fest |
| **5. Early Access** | 12–18 months | Major updates every ~3–4 months (colonies, story chapters, endgame), public patch notes and dev blog, mod community support |
| **6. Beta / 1.0 launch** | 3–4 months | Content lock, balance, polish, achievements, Workshop, marketing push, press/influencer outreach |
| **7. Post-launch** | ongoing | Patches, paid expansion(s), possible console/Steam Deck ports |

**Time to Early Access:** about 20–28 months. **Time to 1.0:** about 3–4 years.

### 6. Documentation deliverables the studio should produce

1. **Game Design Document (GDD).** A living wiki covering vision, core loops, combat rules, campaign systems, economy model, progression and content lists.
2. **Technical Design Document (TDD).** Engine choice, architecture diagram (combat vs campaign), data formats, save/versioning, mod API, AI design, performance targets.
3. **Art bible.** Faction visual languages, ship size and silhouette rules, palette, UI style guide, sprite specifications.
4. **Content pipeline docs.** Step-by-step instructions for adding a ship or weapon (sprite → editor → data row → test). These later become the public modding guide.
5. **Production plan and roadmap.** Milestones, budget, risk register, and an Early Access roadmap for the public.
6. **Audio and narrative bibles.** Music direction, SFX list, setting lore, faction histories, tone guide.

### 7. Budget and timeline tiers

Assumptions: Ontario-based staff. Fully loaded cost (salary plus benefits, payroll taxes, equipment and overhead) of roughly CA$8,000–11,000 per person per month. This is based on Canadian game-programmer salary data that ranges from about CA$69K (Glassdoor) to about CA$115K (ERI) depending on source and seniority. The tiers also include contractors, software, marketing and a 15–20% contingency.

| Tier | Team | Duration | Estimated cost (CAD) | Approx. USD | Notes |
|---|---|---|---|---|---|
| **A. Micro / founder-led** | 2–3 + contractors | 2 yrs to EA, then funded by sales | CA$500K–900K to Early Access | US$360K–650K | Closest to Starsector's path; highest schedule risk; depends on EA sales |
| **B. Lean indie (recommended)** | 4–6 core + contractors | ~3 yrs to 1.0 | **CA$1.5–2.5M** | US$1.1–1.8M | Realistic quality bar for Steam; consistent with Innovecs Games' 2026 benchmark of US$945,000 for a 5-person in-house core team at about US$10,500 per person per month (loaded) for 18 months (an outsourcing studio's estimate) |
| **C. Mid-size** | 12–15 | 3–4 yrs | CA$5–7M | US$3.6–5M | Faster content output, fuller story, polish closer to "AA"; usually needs a publisher or investor |

**Ontario and Canadian funding (important for net cost):**
- **Ontario Interactive Digital Media Tax Credit (OIDMTC).** A *refundable* 40% credit on eligible Ontario labour and on marketing and distribution costs, for companies that develop and market their *own* product. The rate is 35% for fee-for-service work. Certification comes through Ontario Creates. Owning the IP yourself, rather than paying a studio a fee to own it, is what unlocks the 40% rate. On a CA$2M Tier B budget that is mostly Ontario labour, the credit could return several hundred thousand dollars. This is an estimate, and actual eligibility must be confirmed with a tax advisor.
- **Ontario Creates IP Fund – Interactive Content stream (2026‑27).** A non-repayable contribution of up to 50% of eligible Ontario expenses. Pre-production requests range from CA$15,000 to CA$50,000. Production requests start at CA$50,000, with a maximum of CA$250,000 for new companies, CA$400,000 for companies with a recently released project, and CA$500,000 for those with a commercially successful release. Applicants need at least one senior owner or employee with 3+ years of full-time game industry experience, 51% Ontario-resident ownership for new companies, and 51% copyright ownership. Ontario Creates must be the last-in funder, and at least 10% cash must come from other sources. Both 2026‑27 deadlines (April 13 and September 14, 2026) have passed, so plan for the 2027‑28 rounds.
- **Canada Media Fund (CMF).** The Prototyping Program offers the lesser of 75% of eligible costs or CA$250,000 (CA$350,000 for applicants with a prior hit). Its current window runs October 27 to November 10, 2026. The Conceptualization Program offers the lesser of 75% or CA$15,000 for first-time applicants and is no longer accepting 2026‑27 applications due to demand. Innovation & Experimentation goes up to CA$1.5M per project. **Note:** CMF early-stage money is a *repayable, non-interest-bearing advance*. If CMF also funds production, it converts into a recoupable investment of 15% of gross revenue for up to 7 years. Some third-party grant websites wrongly describe it as a "grant."
- These programs can often be combined, but stacking rules and "government assistance" reduce some credits. Engage an OIDMTC/CMF consultant or accountant early.

### 8. Monetization and distribution

- **Recommended: premium price (US$20–30) + Steam Early Access**, with a free demo and wishlist-building from the vertical slice onward. Steam charges a US$100 Steam Direct fee per game, recouped after US$1,000 in revenue, and takes a 30% revenue share on the first US$10M.
- **Optional: direct sales** (website or itch.io) alongside Steam. Starsector's direct-only model keeps margins high and avoids platform risk, but it depended on years of word of mouth and one viral video. A new IP should not count on that.
- **Post-launch:** paid expansions rather than microtransactions. The genre's audience strongly prefers complete, premium experiences.

### 9. IP and legal considerations

- **Generally free to use:** the genre, and general mechanics such as top-down fleet combat, shields that build up heat, trading and factions. US case law (*Tetris Holding v. Xio*, 2012) confirms that "game mechanics and the rules are not protected." Canadian copyright law also follows the idea/expression principle.
- **Protected, so do not use:** Starsector's name or anything confusingly similar; its faction names, lore, characters and setting; ship sprites, silhouettes and designs; UI layouts and icons; music; code; data files; and the overall "look and feel." The same Tetris case found infringement because the clone's visual expression was "akin to literal copying," and *Spry Fox v. Lolapps* (2012) protected a game's look and feel. Trade dress and trademark law add further limits.
- **Practical safeguards:** a clean-room rule (team members must not copy files from Starsector or its mods), original art references and design docs with a clear paper trail, a trademark search on the title, and IP-assignment clauses in every employee and contractor agreement. Have a Canadian IP lawyer review the concept before marketing begins.

### 10. Risks and lessons from Starsector and the genre

| Risk | Lesson / mitigation |
|---|---|
| **Scope creep** (15+ years and no 1.0) | Lock the Early Access feature list; put "later" ideas in a post-1.0 backlog; time-box each phase |
| **Economy complexity** (4–5 rewrites) | Design the economy to *serve gameplay* from the start; keep it abstracted and visible to the player |
| **Ship/fleet AI quality** | Dedicated AI programmer; automated AI-vs-AI test harness; ship AI-friendly loadout rules |
| **Balance across hundreds of items** | Spreadsheet-driven data, telemetry from playtests, simulator tool |
| **Discoverability** | Build the Steam page and wishlist early; plan YouTuber/streamer outreach (the genre's main sales driver) |
| **Long gaps between updates** (Starsector's 1–2-year cycles) | Smaller, regular Early Access updates to sustain reviews and visibility |
| **Cash-flow risk** | Mosolov's advice: "don't take risks you can't afford to take"; secure funding/tax-credit cash flow before production |
| **Legal similarity claims** | Original identity and documented clean-room process (above) |

## Next Steps and Questions for the Studio

1. **Ownership model:** Will you own the IP and hire the studio fee-for-service, or co-own or license it? This affects the OIDMTC rate (40% vs 35%) and eligibility for Ontario Creates and CMF.
2. **Engine:** Does the studio have Godot or Unity experience, and a modding plan for whichever it chooses?
3. **Team:** Who would be the lead designer and the AI programmer, and have they shipped a systems-heavy or strategy game before?
4. **Prototype-first contract:** Can the first contract cover only Phases 0–2 (about 6–9 months, roughly CA$250–450K at Tier B rates), with a go/no-go decision at the combat-prototype gate?
5. **Funding support:** Will the studio help prepare OIDMTC certification and the Ontario Creates and CMF applications? Does it qualify under the "3+ years industry experience" rules?
6. **Milestones and payments:** Payment schedules tied to playable deliverables, with source code, build access and data files handed over at every milestone.
7. **Art direction:** Can they show 3–5 original ship concepts and a UI mock-up within the pre-production budget?
8. **Release plan:** Do they have experience with a Steam Early Access cadence, demos and Next Fest, community management, and influencer outreach?

## Caveats

- Budget figures are planning estimates built from salary surveys and vendor budget guides. Many of those guides are published by outsourcing studios that have an interest in the numbers. Real quotes will vary widely with scope, seniority and the location of contractors.
- Starsector's sales figures are not public, so its commercial success can only be inferred from coverage and its continued operation.
- Funding program terms change every year. All Ontario Creates and CMF figures above come from 2026‑27 guidelines, and tax credit eligibility must be confirmed with a qualified advisor.
- This report is not legal advice. Consult a Canadian IP lawyer before production.
