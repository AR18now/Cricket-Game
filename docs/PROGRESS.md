# Progress, plan and decisions

_Last updated: 2026-09-25 (session 1)._

## Milestone plan (full creative direction, staged)

| # | Milestone | Scope | Status |
| --- | --- | --- | --- |
| A | Toolchain proof | Godot CLI, templates, Git, run/log/screenshot/input evidence, Windows export | ✅ done in container (see docs/TOOLCHAIN.md). Windows build produced but not executed on Windows |
| B | Playable vertical slice | Pindi ground, bowler, batter, one-tap swing, coherent trajectory, dots/runs/boundaries/bowled, scoreboard, restart | ✅ implemented + automated evidence — **awaiting your play-test** |
| C | Complete core game | Practice, Quick Match, Endless, catches/fielding, tutorial, menus, sound, saves, visual polish, regressions | 🟡 mostly in place (all modes, catches, tutorial, menus, synthesised sound, saves, 56 tests). Remaining: polish pass after feedback, credits screen |
| D | Mobile proof | Android debug build early, then iOS on authorised Mac; input, performance, aspect ratios, suspend/resume | 🟡 Android debug APK now produced by CI (run #1 green); device testing needs your phone. iOS blocked on Mac access |
| E | Release candidate | 3 venues, local rules, bowler cast, voices, scorecards, challenge set, challenge codes, share card, store materials | ⬜ staged below |

### Stage plan for E (in order)

1. ✅ Instant replay of the recorded timeline (never re-simulates; harness verifies no side effects).
2. Authored challenge set (~6) with medals, and shot-direction guide in Practice.
3. Venue system pass: **Karachi Rooftop** (netting, water tanks, dead zones, *Rooftop Precision*)
   and **Lahore Night Ground** (floodlights, painted signwork, fuller crowd).
4. **Wall Rebound** local rule (deterministic reflection, precedence tests) for Pindi variant.
5. Six-ball **challenge codes** (versioned, validated; quantised delivery parameters for
   cross-platform fairness) + locally generated share card.
6. Voice bank: script review → recording/generation (needs your approval) → integration with
   ducking, cooldowns and eligibility (logic already implemented and tested).
7. Credits/licences screen, store screenshots, privacy policy draft, release exports.

## Owner feedback round 1 (implemented)

| Request | Done |
| --- | --- |
| Batter's-point-of-view camera with bowler and whole stadium | Perspective BatterView (default) + side cut after contact; toggle in HUD/menu |
| Truck celebration on 4 / 6 | Truck-art lorry overlay, horn + chain bells, reduced-motion variant |
| One mode, slow start then harder (Doodle-style), optional spin/fast | Classic mode with gentle opening → full pace; Bowlers chip Mixed/Fast/Spin |
| Day / night / rain | Atmosphere presets: sky, ambient light, floodlights, stars/moon, rain overlay + wet outfield, ambience loops |
| Better swing button | Large glossy SWING button: fires on press, glows while the ball can be hit, burst on accept |
| Simple, immersive UX | One PLAY; score pill HUD; minimap/scorecard hidden in Classic; simple result screen with PLAY AGAIN |

## What exists now (evidence)

- Deterministic simulation: analytic delivery path (bounce, deviation), timing → contact at the
  ball's true position, fixed-step (120 Hz) shot flight with drag/bounce/roll, bounded
  fielders (reaction + max speed), catches only before the first bounce, four vs six,
  automatic running. Seeded; same seed → same result (tested).
- Scoring engine derived from one event log: overs, strike rotation, new batter on strike,
  chase precedence, tie/loss wording, bowler figures, economy from legal balls, FoW,
  ball-by-ball, shot map (tested).
- Presentation: Pindi Courtyard (brick courtyard, rooftop spectators, bunting, tea stall,
  kites), vector cricketers with run-up/delivery/follow-through, stance/backlift/swing,
  running between wickets, fielder chase/catch/pick-up/throw, umpire signals, stumps
  broken animation, ball shadow + height stalk + trail, camera follow that never loses the ball.
- UI: menu over the living ground, rule cards, compact HUD (score, overs, chase line, batters,
  bowler, this-over chips, mini field map), timing feedback meter, outcome banner with a
  concrete explanation, captions, pause, settings (volumes, mute, captions, reduced motion,
  vibration, timing guide, banter language, replay tutorial), scorecard/result, onboarding.
- Audio: original synthesised palette, buses, variant selection without immediate repeats,
  event cues tied to the simulation timeline; commentary captions (Roman Urdu / English).
- Saves: versioned, atomic (tmp → bak → main), validated, migrated; rewards applied once.

## Decisions taken (and why)

| Decision | Reason |
| --- | --- |
| Godot 4.7.2-stable, GL Compatibility renderer | Newest stable at start; Compatibility suits stylised 2D and older Android GPUs |
| Pure-GDScript simulation separate from nodes | Headless tests; replays; no physics-engine nondeterminism |
| Analytic delivery path + fixed-step shot sim, resolved at the swing | Outcome and drawn path can never disagree; frame-rate independent |
| Positional contact limits + ms timing bands | Fair, speed-aware windows without the bat "hitting" a ball already past the stumps |
| Automatic running from ball-return time, max 3 | Consistent, explainable, no extra buttons |
| New batter takes strike after a wicket | Matches current Laws of Cricket (18.11) |
| All art procedural/vector, audio synthesised in-repo | Clear ownership; no unlicensed assets |
| No MCP bridge yet | Headless container; CLI + dev harness already gives run/log/capture/input |
| Android built in CI | Container network policy blocks the Android SDK host |

## Blockers / needs from owner

1. **Play-test Milestone B** (5 minutes on Windows) — see questions below.
2. Android phone for install/touch/latency tests (after first CI APK).
3. Mac access for iOS (later).
4. Final title/publisher/support contact (before store prep only).
5. Voice clips: approval of approach (record with a friend / licensed generation) — later.

### Play-test questions (Milestone B)

1. **Responsiveness:** When you tap/press Space, does the swing feel instant? Any taps that seemed ignored?
2. **Readability:** Can you tell where the ball will arrive and *why* each ball ended as it did (banner explanation, mini-map)?
3. **Difficulty:** After 2–3 Quick Matches, is timing too easy (too many sixes) or too hard (too many misses)? Rough win/loss count?

## Next steps

- CI is green; next: stage E.2 (challenge set, practice shot guide) while awaiting feedback.
- Stage E.1–E.2 while awaiting feedback; then venues and local rules.
