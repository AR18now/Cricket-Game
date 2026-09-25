# Pocket Boundary (working title)

A Pakistan-inspired, mobile-first arcade cricket game built with **Godot 4.7.2** (GDScript,
Compatibility renderer). One-tap batting with believable ball flight, fielding and scoring —
*from the neighbourhood pitch to the floodlights*.

> "Pocket Boundary" is a provisional internal title and has **not** been cleared as a public
> brand. Team names, the DevTorque identity mark and all text are placeholders for review.

## Current status

Milestone B (playable vertical slice) is implemented and running; parts of Milestone C are in
place. See [`docs/PROGRESS.md`](docs/PROGRESS.md) for the milestone plan, evidence and blockers.

## Pinned versions

| Tool | Version | Source |
| --- | --- | --- |
| Godot editor | 4.7.2-stable (`4.7.2.stable.official.ed1daf0bf`) | github.com/godotengine/godot releases, SHA-512 verified |
| Export templates | 4.7.2-stable (same release) | SHA-512 verified |
| Renderer | GL Compatibility (desktop + mobile) | `project.godot` |
| CI JDK (Android) | 17 (GitHub runner) | `.github/workflows/build.yml` |

SHA-512 values are recorded in the CI workflow.

## Play it on Windows (no tools needed)

Every push runs the **Test and build** workflow on GitHub Actions. Open the repository on
GitHub → **Actions** → the latest *Test and build* run → **Artifacts** → download
`PocketBoundary-windows`, unzip, run `PocketBoundary.exe`.
(`PocketBoundary-windows-dev` is a debug build with the F3 debug overlay.)

## Open the project on Windows

1. Download Godot **4.7.2-stable** (standard, not .NET) for Windows from the official Godot
   website/GitHub releases.
2. Clone this repository, start Godot, **Import** → select `project.godot`.
3. Press **F5** to play.

Controls: **Space / Enter / left click / tap** = swing · **Esc / P** = pause · **M** = mute ·
**F3** = debug overlay (debug builds only).

## Command line (any OS)

```bash
# Import assets (first run / after adding files)
godot --headless --path . --import

# Automated tests (exit code != 0 on failure)
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/run_tests.gd -- --filter=test_scoring

# Balance report: outcome distribution by timing offset / stance / bowler
godot --headless --path . --script res://tools/sim_stats.gd

# Exports (templates must be installed)
godot --headless --path . --export-release "Windows" build/windows/PocketBoundary.exe
godot --headless --path . --export-release "Linux"   build/linux/PocketBoundary.x86_64
godot --headless --path . --export-debug   "Android" build/android/PocketBoundary-debug.apk

# Dev harness on a debug build (needs a display; Linux CI uses xvfb-run)
godot --path . -- --harness=smoke   --out=/abs/path/captures
godot --path . -- --harness=quick   --out=/abs/path/captures
godot --path . -- --harness=capture --out=/abs/path/captures

# Regenerate the original sound palette (Python 3 stdlib only)
python3 tools/gen_audio.py
```

## Project layout

```
scripts/sim/        Pure simulation + rules (no nodes; headless-testable)
scripts/game/       Presentation: projection, rig, poses, venue, ball, world, match controller
scripts/ui/         Theme, HUD, menus, scorecard, settings, overlays
scripts/services/   Autoloads: Save (atomic versioned saves), Audio (buses, captions)
scripts/dev/        Development-only harness (excluded from release exports)
data/               Tuning, bowler profiles, venues (.tres resources)
assets/             Fonts (OFL) and generated audio
tests/              Headless test suite
tools/              gen_audio.py, sim_stats.gd
docs/               Progress, style guide, toolchain notes
```

## Documentation

- [docs/PROGRESS.md](docs/PROGRESS.md) — milestones, status, decisions, blockers
- [GAME_DESIGN.md](GAME_DESIGN.md) — feel, controls, modes, identity
- [GAME_RULES.md](GAME_RULES.md) — arcade rules and edge cases
- [TESTING.md](TESTING.md) — commands and recorded results
- [ASSET_LICENSES.md](ASSET_LICENSES.md) — provenance of every asset
- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) — store preparation and owner actions
- [docs/STYLE_GUIDE.md](docs/STYLE_GUIDE.md) — visual/audio style guide
- [docs/TOOLCHAIN.md](docs/TOOLCHAIN.md) — environment findings and tool decisions
- [VOICE_SCRIPT.csv](VOICE_SCRIPT.csv) — commentary manifest (text drafted, clips pending)
