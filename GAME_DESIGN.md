# Game design

## Premise and tone

*From the neighbourhood pitch to the floodlights.* A fictional local crew — the Pindi Falcons —
plays compact, readable cricket challenges in Pakistan-inspired grounds. Warm, competitive and
welcoming, with short Roman Urdu banter (English option). Anyone who has never been to
Pakistan should understand it within seconds.

All people, teams and places are fictional. No real players, broadcasts, anthems, logos,
commentary voices or stadiums.

## Core loop

1. The bowler runs in and delivers (seeded, readable, bounded variation).
2. **One tap** swings. Timing decides direction and quality:
   early → leg side, perfect → straight down the "V", late → off side, very late → edge.
3. The ball flies in a consistent pseudo-3D model (ground position + separate height, shadow
   and height stalk). Fielders react with bounded speed; catches only happen before a bounce.
4. Runs are taken automatically. The result banner explains *why* ("Caught by Kashif at
   long-off before the ball touched the ground", "Swung 140 ms early — the ball hit the
   stumps").
5. Tap to continue (or it auto-continues). Losing leads straight to *Play again*.

## Controls

| Input | Action |
| --- | --- |
| Tap anywhere on the field / left click / Space / Enter | Swing (one per ball) |
| Shot stance button (after onboarding) | Auto → Grounded → Lofted, between deliveries |
| Pause button / Esc / P | Pause (also automatic on focus loss) |
| Mute button / M | Full mute |

A large **SWING** pad teaches the action for the first balls; taps are accepted anywhere, so
either thumb works. Every accepted tap gets a visible pulse on the batter.

## Main flow (simplified after owner feedback)

Menu = one big **PLAY** plus three optional, remembered chips: **Bowlers** (Mixed / Fast / Spin),
**Time** (Day / Evening / Night / Rain) and **View** (Batter's eye / Side-on). PLAY starts
*Classic*: bat until you lose two wickets; the pace starts slow and builds up. The first three
balls of a new player show a timing ring. Boundaries are celebrated by a decorated truck-art
lorry that drives across the screen ("CHAUKA!" / "CHHAKKA!") with horn and bell chains.

### Camera views

- **Batter's eye (default):** perspective from behind the striker looking at the bowler, the
  umpire, the fielders and the whole ground (houses, rooftop crowd, bunting, floodlights).
  After contact the game cuts to the side camera, which follows the ball into the field.
- **Side-on:** the original fixed oblique view for the whole delivery.
Switch any time with the camera button in the match HUD.

## Other modes (kept in code, not on the main menu)

- **First launch:** identity mark → living ground menu → **PLAY** → three nets balls with a
  timing ring (slow, forgiving, truthful) → *First Challenge* (6 runs off 6 balls) → result →
  optional display name & kit colour (Skip available).
- **Quick Match:** 2 overs, 3 wickets, two batters with strike rotation, chasing a labelled
  *Challenge target*.
- **Practice:** unlimited balls, all three bowlers in rotation, optional timing guide.
- **Endless:** one wicket, bowlers rotate each over, gradually (and boundedly) quicker; local
  best score.

## Bowlers (learnable archetypes)

| Bowler | Style | What actually changes |
| --- | --- | --- |
| Javed "Coach" | tutorial | 13.5–17.5 m/s, straight, good length |
| Daniyal "Chalak" | medium | 19–22.5 m/s, fuller lengths (2.6–5.2 m), wider line |
| Hamza "Tez" | pace | 24–27.5 m/s, back of a length, 22 % slower balls (17–19 m/s) |
| Saad "Ghoom" | spin | 15.5–18 m/s, sideways deviation off the pitch up to 1.3 m/s |

Difficulty can add at most +12 % pace (Endless ramps over 60 balls). It never changes timing
windows, bat reach, input latency or catching.

## Visual direction

Stylised layered 2D with a fixed oblique side view. Slightly cartooned vector cricketers with
believable proportions and grounded animation (run-up, gather, delivery stride, follow-through;
stance, backlift, swing, follow-through; running between wickets; catches, pick-ups and throws).
Warm evening light; emerald, warm sand, off-white markings, terracotta and restrained
floodlight gold. The ball is always a vivid outlined tape ball at a constant on-screen size.
Camera: fixed framing during the delivery; smooth zoom-out/follow after contact that never
loses the ball (reduced-motion mode switches to a static overview). See
[docs/STYLE_GUIDE.md](docs/STYLE_GUIDE.md).

## Venues

1. **Pindi Courtyard** (implemented): brick courtyard, rooftop spectators, bunting strung high
   behind the field, tea stall with a painted "CHAI" sign, evening sky with kites.
2. **Karachi Rooftop** (planned): enclosed rooftop ground, water tanks, safety netting, marked
   dead zones; *Rooftop Precision* challenge target.
3. **Lahore Night Ground** (planned): open ground under lights, painted signwork, fuller crowd.

## Signature features (planned, see PROGRESS)

- **Visible street-ground rules:** Wall Rebound and Rooftop Precision as optional, explained
  variants with tested precedence.
- **Learn the bowler:** the cast above, introduced gradually, with readable cues.
- **Six-ball challenge codes:** shareable offline codes (challenge id, ruleset version,
  difficulty, seed) that reproduce the same deliveries.
- **Named squads and full scorecards** (implemented for Quick Match).
- **Audio & voices:** event-driven audio director (implemented) and a reviewed Roman
  Urdu/English voice bank (text drafted; recordings pending owner decision).
