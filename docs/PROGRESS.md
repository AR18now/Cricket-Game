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

## Owner feedback round 2 (implemented)

| Request | Done |
| --- | --- |
| 1 wicket | Classic = one wicket, single batter |
| Hitting feels slow, make it smooth | Shorter run-ups/pauses, 2x post-contact playback, results final once runs are complete, hit-stop, tap to fast-forward/skip, stay in batter's view while the ball flies away, snapped side-camera cut, cached static backdrop and skipped hidden redraws for frame rate |
| More attractive UI/UX, effects, animations | Bat trail + impact flash, floating +runs, score pop, banner/timing pop-ins, confetti on boundaries/milestones/new best, faster truck, PLAY pulse, screen fade, result count-up |

## Owner feedback round 3 (implemented)

| Report | Cause / fix |
| --- | --- |
| After getting out and restarting, the bowler never came; only "Wait..." | Result screen paused the sim clock; "Play again" cleared the controller flag but not the clock's own pause flag. `start_match` now unpauses both. Harness regression: get out -> Play again -> delivery clock runs and the ball is bowled |
| Ball arriving at the bat not smooth | Removed the contact hit-stop (read as a stutter); post-contact playback eases to 2x instead of jumping; analytic motion trail on the ball in the batter's view; ball eases out of the bowler's drawn hand at release; batter's view cross-fades to the side camera |

## Owner feedback round 4 (implemented)

| Request | Done |
| --- | --- |
| Optional hint at the moment to hit | Menu chip Hints On/Off: HIT NOW cue, button flash, ring guide, and slow-motion (45%) around the ideal tap; input scaled so timing stays exact (harness: tap on cue = perfect, 2.4 ms). Hint scores kept as a separate best |
| More realistic human bodies | Tapered limbs (thigh/calf/forearm), shaped torso, soft shading instead of cartoon outlines, sleeves, collar, ribbed pads, gloves, shoes, faces with nose/ear/brows, beards, helmet peak/grille/neck guard - side view and batter's view |
| Better colours / realistic scene | Mown grass outfield with stripes, inner circle, tan pitch, red-white rope with flags, navy fielding kit, deep green batting kit, varied skin tones |

## Owner feedback round 5 (implemented, placeholder voices)

| Request | Done |
| --- | --- |
| Commentary in English and Urdu | Every commentary line is now spoken: `vo_<id>_en` / `vo_<id>_ur` clips (54), language chip on the menu (Urdu / English / Mix) and in Settings; captions follow the spoken language; music ducks for the clip's length; a newer line replaces an older one. **Voices are robotic eSpeak NG placeholders** (`tools/gen_voice.py`), Urdu script text needs native-speaker review. Real recordings drop in with the same file names. Voice experience is **not** complete until reviewed recordings replace them |

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
5. Voice clips: placeholder TTS is in; final voice needs approval of approach (record with a friend / licensed generation) and native-speaker review of the Urdu text.

### Play-test questions (Milestone B)

1. **Responsiveness:** When you tap/press Space, does the swing feel instant? Any taps that seemed ignored?
2. **Readability:** Can you tell where the ball will arrive and *why* each ball ended as it did (banner explanation, mini-map)?
3. **Difficulty:** After 2–3 Quick Matches, is timing too easy (too many sixes) or too hard (too many misses)? Rough win/loss count?

## Next steps

- CI is green; next: stage E.2 (challenge set, practice shot guide) while awaiting feedback.
- Stage E.1–E.2 while awaiting feedback; then venues and local rules.
