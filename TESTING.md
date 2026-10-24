# Testing

## Automated (headless)

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

Latest result in this repository's development container (Godot 4.7.2, Linux x86_64):
**56 tests, 4,234 checks, 0 failures.** CI runs the same suite on every push.

| File | Covers |
| --- | --- |
| `test_delivery.gd` | Over notation (1.5 → 2.0), zero-ball rates, RNG and delivery reproducibility from seed, every generated delivery playable, bounded pace, path continuity, analytic stump detection at 12–60 m/s (tunnelling guard), wide lines miss |
| `test_contact.gd` | Timing categories at exact window boundaries (±0.5 ms), no-swing, contact point lies on the drawn path, timing → direction mapping, stance → elevation, windows independent of bowler/difficulty |
| `test_shot_rules.gd` | Six vs four, catch only before first bounce (incl. post-bounce hop at catch height), bounded fielder speed, boundary vs catch, dot/1/2/3 running model vs formula, deterministic shot sim, consistency sweep over 1,260 resolved balls |
| `test_scoring.gd` | Legal balls & over rollover, odd-run and end-of-over strike swaps, single off the last ball, new batter on strike, three-wicket all out, last-ball win precedence, tie/loss wording, mid-over win, duplicate delivery ids rejected, bowler figures & economy, endless/practice rules, scorecard totals equal event log |
| `test_input_and_clock.gd` | One swing per delivery, rapid taps ignored, closed window, frame-rate independence (20/60/144 fps), pause freezes the clock, time-scale consistency, same seed → same outcome |
| `test_commentary.gd` | Six lines never on a four, last-ball line matches the real requirement, specific lines beat generic ones, no immediate repeats, VOICE_SCRIPT.csv covers every line |
| `test_save.gd` | Defaults, round trip + backup, corrupt main → backup, interrupted write → tmp, truncated tmp ignored, v0/v1 migration, sanitising, rewards applied once |

## Balance report

```bash
godot --headless --path . --script res://tools/sim_stats.gd
```

Prints outcome percentages per bowler × stance × timing offset (200 seeded deliveries each).
Current summary (Auto stance, Daniyal): perfect (±10 ms) ≈ 96–100 % six; ±25 ms ≈ 84 % six /
15 % caught; ±40 ms ≈ mostly singles; ±90 ms misses (≈50 % bowled). Needs human play-testing.

## Running-game harness (development builds only)

`scripts/dev/dev_harness.gd` is loaded only when `OS.is_debug_build()` and a `--harness=`
argument is passed; release export presets exclude `scripts/dev/*`. It injects **real input
events** (`Input.parse_input_event` + flush) so swings go through the same `_unhandled_input`
path as a keyboard/mouse, captures screenshots of the running game and asserts state.

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 -- --harness=smoke --out=$PWD/captures/smoke
# Portrait: tall window plus the saved Screen setting
xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --resolution 720x1280 -- --harness=smoke --portrait --out=$PWD/captures/smoke_portrait
```

### Performance (CPU per frame)

`--harness=perf` run **headless** (no GPU rasterisation, frame cap and idle sleep off)
measures wall-clock CPU time per frame on the menu and across real deliveries in both
views:

```bash
godot --headless --path . -- --harness=perf --out=$PWD/captures/perf
```

| Screen | Before round 7 (avg / p95) | After (avg / p95) |
| --- | --- | --- |
| Menu | 5.44 / 9.80 ms | 0.25 / 0.36 ms |
| Batter's view | 6.29 / 9.39 ms | 1.32 / 2.46 ms |
| Side view | 5.10 / 7.39 ms | 0.75 / 1.42 ms |

Fixes: side-view figures redraw only when their pose visibly changes and are not posed
or drawn at all while the batter's view covers them (hidden at renderer level, so their
cached drawings survive); batter's-view fielders and umpire live on a cached layer;
the swing's bat-to-ball correction is computed once per swing; capsule geometry uses
precomputed tables. (Engine `TIME_PROCESS` is only refreshed about once a second, so it is
not used for per-frame figures.)

Other modes: `batter` (frozen pose sheet of the striker in both views), `screens` (menu,
settings, truck, pause, result), `look`, `hints`, `restart`, `approach`. Smoke passes in
landscape and portrait (round 6).

Recorded results (development container, software OpenGL via Mesa llvmpipe under Xvfb):

| Check | Editor run | Exported Linux debug build |
| --- | --- | --- |
| Injected Space → swing accepted, timed at dt = 0.1 ms | pass | pass |
| Two extra rapid taps rejected ("already") | pass | pass |
| Exactly one event recorded per delivery | pass | pass |
| Clock frozen while paused mid-delivery; resumed ball recorded once | pass | pass |
| Tutorial → first challenge flow, menus, pause, settings, scorecard screenshots | pass | — |

Release exports (Windows/Linux) were checked to contain no `scripts/dev/dev_harness` and no
tests; the Linux release build launched without script errors.

**CI (GitHub Actions, ubuntu-24.04):** run #1 (commit `1575d65`) passed every step: verified
Godot download, import, tests, balance report, Windows release + dev export, Linux export,
harness-absence check, and Android debug APK export (58 MB artifact). The APK has **not** yet
been installed on a device.

**Frame rate:** ~6 FPS in the container, which uses CPU software rendering. This says nothing
about device performance; no device measurements exist yet.

## Not yet tested (needs hardware or later milestones)

- Real touch input, input-to-swing latency and FPS on reference Android/iOS devices.
- Android install / suspend-resume / aspect ratios on hardware; iOS build (needs Mac).
- Safe-area layout on notched phones (code path exists, untested on devices).
- Human play-test feedback (none collected yet — see PROGRESS.md for the questions).
