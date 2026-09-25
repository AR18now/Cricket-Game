# Game rules (arcade cricket)

Pocket Boundary plays a simplified, *consistent* version of cricket. Every rule below is
implemented in `scripts/sim/` and covered by tests in `tests/`.

## A delivery

- The bowler runs in and releases the ball. Its path (flight, bounce, sideways deviation for
  seam/spin) is fully determined before release from a seed.
- You get **one swing** per ball. Taps before the batting window opens are ignored ("Wait for
  it"); extra taps after the swing are ignored.
- The bat reaches the hitting zone **0.10 s** after the accepted tap. Contact happens exactly
  where the ball is at that moment; the drawn path always matches.

### Timing categories

| Category | When | Result |
| --- | --- | --- |
| Perfect | within ±26 ms of ideal (narrower on very fast balls) | hit straight back down the "V" |
| Good | within ±55 ms | angled into the gaps |
| Early / Late | still in reach | pulled to the leg side / steered to the off side, weaker |
| Edge | very late, ball almost past the bat | thin edge behind square (catchable by the keeper) |
| Too early / Too late | bat misses the ball | ball carries on; may hit the stumps |

Timing windows never change with difficulty, cosmetics, or mode (practice only widens the
Perfect/Good bands visibly; the tutorial widens them by ×1.5).

### Shot stance (unlocked after the first challenge)

- **Auto** (default): perfect timing lofts the ball, good timing keeps it lower.
- **Grounded**: keeps every shot along the ground (fewer catches, fewer sixes).
- **Lofted**: hits everything in the air (more sixes, more catches).

## Outcomes (exactly one per ball)

| Outcome | Rule |
| --- | --- |
| **Six** | The ball crosses the boundary rope **without touching the ground** after the shot. |
| **Four** | The ball reaches the rope **after touching the ground**. |
| **Bowled** | You did not make contact **and** the ball's actual path passes through the stumps. |
| **Caught** | A fielder reaches the ball **before its first bounce**, inside the rope, at a catchable height (0.12–2.6 m), respecting reaction time and running speed. |
| **Runs (0–3)** | Otherwise a fielder collects the ball; runs are completed automatically (below). |

Precedence: a catch is only possible before the ball crosses the rope; once the ball crosses
the rope the boundary stands. A caught ball never scores runs. Stump and contact checks are
analytic (exact crossing time), so a fast ball can never pass through the bat or the stumps
between frames.

### Automatic running (arcade rule)

Batters only complete runs that are safe. The ball is "back" at
`collect time + pickup (0.6 s) + distance to the nearer stumps ÷ throw speed (20 m/s)`.
Run *k* completes at `2.7 s + (k−1) × 2.0 s`; it counts if it finishes at least 0.2 s before the
ball is back. Maximum 3 runs. There are no run-outs.

### Fielders

Fielders cannot move until their reaction time (0.34 s; bowler 0.59 s; keeper 0.27 s) and then
run at most 6.6 m/s (keeper 4.6 m/s). They cannot teleport. The fielding positions are always
shown on the mini-map.

## Innings formats

| Mode | Overs | Wickets | Batters | Target |
| --- | --- | --- | --- | --- |
| Quick Match | 2 | 3 (4-player arcade squad) | 2 at the crease, strike rotation | Challenge target (16–24) |
| Endless | unlimited | 1 | single batter | none — bat as long as possible |
| Practice | unlimited | dismissals counted, innings never ends | single batter | none |
| First Challenge | 1 | 2 | single batter | 6 runs |

- **Over notation:** 11 legal balls = 1.5 overs; one more = **2.0** (never 1.6). Every
  delivery is legal (no wides/no-balls in this release), so extras are always 0.
- **Strike rotation (Quick Match):** odd runs swap ends; the batters swap at the end of every
  over; after a wicket the **new batter takes strike** (as in the current Laws of Cricket);
  no end-of-over swap after the innings has finished.
- **Chase result:** the innings stops as soon as the target is reached — even on the final
  ball (win takes precedence). If the balls or wickets run out: score = target − 1 is a
  **tie**, otherwise the chase is lost ("N more runs needed"). A preset target is labelled
  **Challenge target**; no fictional opposition innings is shown.
- **Rates:** strike rate = runs × 100 ÷ balls; economy = runs × 6 ÷ legal balls; required rate
  = runs needed × 6 ÷ balls remaining. Zero-ball rates show "-" (never NaN/Infinity).

## Deliberately not in this release

Wides, no-balls, LBW, run-outs, overthrows, byes/leg-byes, weather, multiplayer. These would
need complete simulation and tests before being introduced.

## Local house rules (planned, optional)

Venue rules such as *Wall Rebound* and *Rooftop Precision* are fictional house rules, never
claimed to be universal Pakistani street-cricket rules. They will only apply when a variant is
explicitly selected and will be explained on a rule card before play.

## Pausing and interruptions

The game pauses automatically when the app loses focus or is backgrounded. The simulation
clock is frozen while paused. A delivery is recorded **once**, when it settles on screen;
rewards and records use an idempotent result id, so resuming, replaying or double callbacks
can never count a ball or a reward twice. If the app is terminated mid-match, the unfinished
match is discarded; completed results and progress are already saved.
