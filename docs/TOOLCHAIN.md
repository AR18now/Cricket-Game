# Toolchain and environment findings

## Where development runs

Claude Code runs in a **managed Linux cloud container** (Ubuntu 24.04, x86_64, 4 vCPU, no GPU),
not on the owner's Windows PC and not in WSL. The repository is cloned fresh per session and
work is delivered through Git (branch pushes) and CI artifacts. There is therefore no
Windows/WSL path bridge to manage; Windows builds are cross-exported and tested on Linux.

| Capability | Status | Evidence |
| --- | --- | --- |
| Godot 4.7.2 editor CLI | works | `godot --version` → `4.7.2.stable.official.ed1daf0bf`, SHA-512 verified |
| Export templates 4.7.2 | installed, verified | Windows/Linux exports produced |
| Run game + read logs | works | Xvfb + Mesa llvmpipe (OpenGL 4.5 core, Compatibility renderer) |
| Real screenshots of the running game | works | `get_viewport().get_texture().get_image()` under Xvfb (captures in session) |
| Inject input and assert state | works | Dev harness: injected Space → swing at dt = 0.1 ms; rapid taps rejected |
| Windows export | produced | `build/windows/PocketBoundary.exe` (110 MB, embedded PCK); cannot be executed here (no Windows/Wine) |
| Linux export run | works | release build launched without script errors; debug export passed smoke harness |
| Android SDK | **blocked** in this container (`dl.google.com` denied by network policy) | built instead by GitHub Actions (runner ships the SDK) |
| iOS | requires macOS + Xcode | pending authorised Mac access |
| Audio output | dummy driver only (no sound card) | audio logic runs; listening tests need a human |
| Frame-rate measurement | not representative (software rendering, ~6 FPS) | device measurements pending |

## MCP bridge decision

The prompt suggested evaluating a community Godot MCP bridge (e.g. `slangwald/godot-mcp`).
This session's GitHub access is scoped to this repository, so its README/licence/source could
not be inspected, and an editor bridge adds little here: the container is headless and the
Godot CLI + a development-only harness already provides run, logs, screenshots and input
injection. **Decision: no MCP bridge for now.** Revisit only if a GUI editor session on the
owner's machine is used, after reviewing the bridge's code, licence and network binding
(loopback only), and never inside release builds.

## Reproducing the toolchain

See README "Pinned versions". CI (`.github/workflows/build.yml`) downloads the same editor and
templates, checks SHA-512 sums, imports, runs tests, and exports Windows (release + dev), Linux
and an Android debug APK (debug keystore generated per run; no secrets stored).
