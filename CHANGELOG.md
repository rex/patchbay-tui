# Changelog

All notable changes to this project are documented here. This project
follows [Semantic Versioning](https://semver.org/) and
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Format:

```markdown
## [X.Y.Z] — YYYY-MM-DD — Agent: <name>
### Added | Changed | Fixed | Removed | Deprecated | Security
- <what changed, in imperative voice>
```

**Every commit requires a version bump and a matching entry here.** The
`scripts/check_version_bumped.py` gate enforces this; `auto-commit.sh`
calls `scripts/bump_version.py <level>` before commit.

**Bump level guidance** (agent decides per slice):
- `patch` — bug fix, documentation change, refactor with no behavior change
- `minor` — new feature, new public API, any backward-compatible addition
- `major` — breaking change, removal, incompatible behavior change

**Agent attribution is required.** Every entry names the agent (or human)
that authored the change. This is how we keep `git blame` honest when
multiple agents and humans work on the same slice.

Append new entries at the top. One entry per commit (same cadence as
version bumps).

---

## [0.11.0] — 2026-11-23 — Agent: Claude Fable 5.2
### Added
- Engine pieces the macOS app needs. The terminal UI does not use them yet.
  - `RouteBook.meter(of:)` and `RouteStats.takeMeter()`: a second peak reader
    for a level display that polls many times a second. `measure` and the
    silence watch keep their own once-a-second peak.
  - `RouteBook.setPaused(_:)` and `isPaused`: pausing stops every route at
    once and keeps every wish; `reconcile` builds nothing until resumed.
  - `RouteBook.rebuild(_:)`: tears one live route down so the next
    `reconcile` builds it fresh.
  - `OutputDevice.makeDefault()`: sets the Mac's default output.
  - `OutputDevice.onListChange(queue:_:)`: fires when a device is connected or
    removed or the default output changes.
- Tests for pausing, rebuilding and the two separate peaks. Setting the
  default output and the device listener touch real hardware, so they are
  not run in `swift test`.

## [0.10.0] — 2026-11-23 — Agent: Claude Fable 5.2
### Added
- `PatchbayCore` is now a library product, so the macOS app (rex/patchbay)
  can depend on the engine. The `patchbay` command is unchanged.

### Changed
- The repo is now `patchbay-tui`. The name `patchbay` belongs to the macOS
  app repo. AGENTS.md, TASK_STATE.md, PROGRESS.md, MAP.md, the README and
  VIBE.yaml (new decision D4) say so, and the old "no menu-bar app" non-goal
  now reads "no graphical UI in this repo".

## [0.9.0] — 2026-11-17 — Agent: Claude Opus 5.5
### Changed
- Adopt agentic-skeleton 0.54.0's include-based Makefile: the gates live in the skeleton-owned make/agentic-skeleton.mk and the Makefile keeps this repo's own recipes, so make check-skeleton stops failing on them. Verified against make's rule database; repo targets, variables and the default goal are unchanged.

## [0.8.0] — 2026-11-15 — Agent: Claude Opus 5.5
### Added
- Remembered routes. Every route change (connect, disconnect, volume, mute)
  saves `~/Library/Application Support/patchbay/routes.json`, or
  `$PATCHBAY_ROUTES_FILE`, and launch restores it, so routes and their
  volumes come back after a restart. Verified live across two launches.
- `RouteMemory`: a Codable file with app and output IDs and names, volume
  and mute. A missing or broken file means no routes. Apps known only by
  process ID aren't saved.
- A route's meter reads `away` while its output is disconnected.

### Changed
- A route now lasts until it is disconnected. When its app isn't running,
  the app stays listed and the route waits. When its output is away, the
  app plays normally and the route resumes when the output returns. Before,
  both cases dropped the route.
- `RouteBook` moved into `PatchbayCore` (now public) so it can be tested;
  it gained `remember()` and `restore(_:)`.

## [0.7.0] — 2026-11-15 — Agent: Claude Opus 5.5
### Added
- `make install-command` builds the release binary and installs `patchbay`
  to `$(PREFIX)/bin` (default `~/.local/bin`), warning if that isn't on PATH.
  `make uninstall-command` removes it. Installed and run from PATH on this
  Mac.

## [0.6.1] — 2026-11-15 — Agent: Claude Opus 5.5
### Changed
- TASK_STATE.md: new standing directive from Pierce to work directly on
  `main`, with no branches or PRs. Phase 3 (silent-route warning, volume,
  Finder source) is recorded as done, and nothing is queued.

## [0.6.0] — 2026-11-15 — Agent: Claude Opus 5.5
### Added
- One permanent "Finder" source. Finder is pinned to the list even before
  it touches audio, and QuickLook joins it: `com.apple.quicklook.*`, plus any
  process macOS names "… (Finder)", such as the QLC previewer's extension.
  More generally, a process named "X (App)" groups under App when App is
  running (`AppNames.hostKey`, `AppGrouping.apps(host:pinned:)`).
- Routes are now wishes (app → output) kept by `RouteBook`. A wish whose app
  has no audio processes waits; its cable is drawn and its meter reads
  `ready`. It goes live as soon as processes appear and rebuilds as they
  change. It ends only on disconnect, when the app quits (unpinned apps), or
  when its output goes away. Volume stays with the app.
- `AudioProcess.onListChange` listens for the audio server's process list,
  so a new QuickLook preview joins its route within milliseconds instead of
  on the next 1-second refresh.

### Changed
- Controller hands route bookkeeping to `RouteBook`.

## [0.5.0] — 2026-11-15 — Agent: Claude Opus 5.5
### Added
- Per-route volume. Each route's level shows beside its meter (" 45%",
  "100%", "mute"). `+`/`=` and `-`/`_` step it by 5%, `m` mutes, and the
  scroll wheel over a routed source turns it (anywhere else the wheel still
  moves the cursor). Changing the level unmutes.
- `Volume`: software gain applied in the output unit's render callback, so
  it works on every device, the Scarlett included. It uses a squared curve
  so 50% sounds about half as loud, and ramps across one buffer so changes
  don't click. Lock-free and allocation-free on the render thread. A rebuilt
  or re-pointed route keeps its app's volume for the session.

### Changed
- `Key.scroll(x:y:delta:)` replaces the wheel's plain up/down, so a scroll
  knows where it happened.
- AGENTS.md no longer lists per-app volume as a non-goal.

## [0.4.0] — 2026-11-15 — Agent: Claude Opus 5.5
### Added
- Silent-route warning. When a playing app's route has carried only exact
  silence for 3 seconds, the TUI swaps its meter for a red `⚠ none` and
  says in the status line which terminal needs the System Audio Recording
  permission. `patchbay route` prints the same warning. This is what a
  missing permission looks like: macOS gives the tap silence instead of an
  error, and still mutes the app.
- `SilenceWatch` (pure, tested) and `HostApp`, which finds the `.app` that
  patchbay runs inside by walking up the process tree.
- README "If a route is silent" troubleshooting.

## [0.3.1] — 2026-11-15 — Agent: Claude Opus 5.5
### Changed
- TASK_STATE.md records Pierce's listen test: Chrome's 48 kHz tap plays at
  the right pitch on the 44.1 kHz Scarlett, and two routes run at once. The
  routing engine phase is done. AirPods themselves are still untried.

## [0.3.0] — 2026-11-15 — Agent: Claude Opus 5.5
### Added
- The patch panel: `patchbay` with no arguments opens a full-screen TUI with
  sources (apps) on the left and outputs on the right. Click a source, then
  an output, and a colored cable is drawn between them while the route runs.
  "↩ Normal output" or `d` disconnects. The keyboard does everything too
  (↑↓ ⏎ Esc Tab, `a` for every app, `q` to quit). Quitting stops every route
  and restores the terminal.
- Live upkeep every second: lists refresh, each route shows a level meter, a
  route is rebuilt when its app gains or loses audio processes (a new browser
  helper), and is dropped when its app quits or its device disconnects.
- `PatchbayTUI` target: key and SGR-mouse parsing, the panel state, a styled
  canvas, cable drawing with merged crossings, and numbered labels for
  devices that share a name. 22 new tests.
- `AppNames.isRegularApp`. Idle daemons are hidden unless you press `a`, and
  WebKit's shared audio process is named "Safari & other web views".

### Changed
- `patchbay` with no arguments opens the TUI instead of printing usage.

## [0.2.1] — 2026-11-15 — Agent: Claude Opus 5.5
### Added
- MIT license (`LICENSE`, plus a License section in the README), Pierce's
  choice for the public repo.

## [0.2.0] — 2026-11-15 — Agent: Claude Opus 5.5
### Added
- `PatchbayCore`, the routing engine. `OutputDevice.all()` lists output
  devices (default first, aggregates hidden). `AudioProcess.all()` and
  `AppGrouping` list the apps registered with the audio server, with browser
  and Electron helpers grouped under their app. `Route` sends one app to one
  device.
- A route is a muting process tap, then a private tap-only aggregate whose
  IOProc fills a lock-free SPSC `RingBuffer`, then an output-only AUHAL on
  the destination that converts the sample rate. Tested on this Mac: a 48 kHz
  tap into the 44.1 kHz Scarlett and into 48 kHz BlackHole, with audio
  flowing and the buffer steady at 300–950 frames over 12 seconds.
- `patchbay list` and `patchbay route <app> <device> [seconds]`.
- Swift Testing suites for app grouping, HAL error codes and the ring buffer
  (priming, underrun, trimming a fast writer, overflow, tap channel offset).

### Changed
- Tests are now a required gate (`VIBE.yaml`, `make test` runs `swift test`).
- The minimum is macOS 15, for `Synchronization.Atomic` in the ring buffer.

## [0.1.1] — 2026-11-15 — Agent: Claude Opus 5.5
### Changed
- TASK_STATE.md maps each phase to its issue (#1–#5, moved here from
  rex/todo). The repo is linked to Rivendell, which closes the naming and
  repo-setup issues.

## [0.1.0] — 2026-11-15 — Agent: Claude Opus 5.5
### Added
- Scaffold from `agentic-skeleton`: AGENTS.md (CLAUDE.md and GEMINI.md
  symlink to it), VIBE.yaml, TASK_STATE.md, the gate scripts, `.claude/`
  hooks, agents and commands, and pre-commit with gitleaks and
  detect-secrets.
- SwiftPM package (`Package.swift`, macOS 14.2+) with a placeholder
  `patchbay` executable.
- Makefile wired for Swift: `lint` (swift-format, strict), `typecheck`
  (`swift build --build-tests`), `test` (`swift test` once tests are
  required), `fix`, `build`, `dev`.
- CI on GitHub Actions (macOS): lint, compile, tests, and a gitleaks scan
  of the full history.
- VIBE.yaml decisions D1–D3: a TUI, Core Audio process taps with no event
  taps, and a public repo with no secrets.
