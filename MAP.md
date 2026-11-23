# MAP

<!-- Repo map for humans and agents. Keep under 80 lines.
     Update when you add a domain, a module, or a hot path. -->

## Targets

| Target | Purpose | Entry point |
|---|---|---|
| `PatchbayCore` (library product) | Routing engine: discovery, taps, ring buffer, output units, volume; `RouteBook` (wishes vs live routes) and `RouteMemory` (routes.json). The macOS app (rex/patchbay) links it, pinned by commit | `Route.swift`, `RouteBook.swift` |
| `PatchbayTUI` | Pure patch-panel logic: keys and clicks, state, layout, cables | `TUIState.swift`, `Screen.swift` |
| `patchbay` (executable) | Terminal I/O and the refresh loop for the TUI, plus `list` / `route` | `main.swift`, `Controller.swift` |

`PatchbayTUI` has no Core Audio or terminal calls, so its tests render whole
screens and drive clicks without permissions. The executable is the only place
raw mode, mouse reporting and `Route` objects meet.

## Where bodies are buried

- A process tap only works when the terminal running patchbay holds the
  "Screen & System Audio Recording" permission. CI never has it.
- Chrome, Safari and most Electron apps play audio from a helper process, not
  the app's main process. Group helpers under their app by bundle ID.
- A tap and its destination can run at different sample rates (48 kHz vs
  44.1 kHz). That mismatch is the known failure mode to design around.

## Hot paths (watch performance)

- The Core Audio IO callback: real-time thread, no allocation, no locks, no
  logging, no Swift concurrency.

## External dependencies

| System | What we call | When | Failure mode |
|---|---|---|---|
| Core Audio HAL | `AudioHardwareCreateProcessTap`, `AudioHardwareCreateAggregateDevice`, IOProcs | Creating or removing a route | Permission denied or device gone: report it in the TUI and leave the app on its normal output |

## Quick tour (read order for a new contributor)

1. `README.md` — what it is and how it works.
2. `AGENTS.md` — the agent contract and hard stops.
3. `TASK_STATE.md` — what is being built right now.
4. This file — where things live.
