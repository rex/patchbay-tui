# TASK_STATE — patchbay v1: route apps to devices from a TUI

> Source of truth for in-flight work. Humans and agents both write here.
> This file is **committed** to the repo. It survives sessions, machines,
> and context compactions. Issues live in Rivendell (rex/patchbay-tui).
>
> Branch: `main` (trunk) · Owner (human): Pierce · Last update: 2026-11-23 by Claude Fable 5.2

## 0. TL;DR for a fresh agent session

`patchbay` opens the patch panel: sources left, outputs right, click one then
the other and a cable is drawn. Per-route volume, the silent-route warning and
a permanent Finder source (with QuickLook) have all shipped. This repo is now
`patchbay-tui`; the macOS app lives in rex/patchbay and builds on
`PatchbayCore` from here. **Next:** engine work the app asks for. Never add an
event tap.

## Standing user directives

- Work directly on `main`: no feature branches, no PRs. Keep every gate, and push each commit (Pierce, 2026-11-15).
- Nobody should have to remember device names: outputs are always picked from a live list (Pierce, 2026-11-15). This repo is the terminal front end; the menu bar and window app is rex/patchbay (Pierce, 2026-11-23).
- Public repo: no secrets land in it (Pierce, 2026-11-15).
- Don't copy jkjoplin/AudioRouter code; it has no license.

## 1. Phases

| # | Phase | Status | Exit criteria |
|---|---|---|---|
| 0 | Name, repo, scaffold, Rivendell (#2, #3) | ✅ done | rex/patchbay public, gates green, issues on the board |
| 1 | Routing engine (#4) | ✅ done | `patchbay route <app> <device>` plays that app on that device until Ctrl-C; several routes at once; mismatched sample rates handled |
| 2 | TUI (#5) | ✅ done | Live app and device lists; add, retarget and remove routes; quitting restores everything |
| 3 | Daily-use polish (#8, #9, #11) | ✅ done | Silent routes explain themselves; per-route volume and mute; Finder always listed and QuickLook folded in |

Parent issue: #1. Issues #1–#5 came over from rex/todo#16–#20.

Statuses: `⏸ pending` · `🟡 in-prog` · `✅ done` · `🔴 blocked`

## 2. Slices

### Slice 1.1 — Discovery: audio apps and output devices ✅

- Acceptance:
  - [x] When asked, the engine shall list processes whose output is running, with PID and bundle ID, grouping helper processes under their app.
  - [x] When asked, the engine shall list output devices with their names, UIDs and nominal sample rates, and mark the default.
  - [x] Tests: the pure grouping logic, without Core Audio.

### Slice 1.2 — Route one app to one device ✅

- Acceptance:
  - [x] When a route starts, the app's audio shall reach the chosen device (measured: peak flows through the ring into the output unit).
  - [x] If the tap and the device run at different sample rates, the audio shall still play at the right pitch and speed. (Pierce listened: Chrome's 48 kHz tap on the 44.1 kHz Scarlett.)
  - [x] When patchbay exits, every tap and aggregate it created shall be destroyed (`Route.stop`, plus macOS cleanup of private objects).
  - [x] Two routes at once (Pierce: Chrome → Scarlett and Finder's QuickLook → Ear Force One together).
  - [ ] AirPods specifically stay in high-quality mode (not yet tried; the output-only design is meant to guarantee it).

## 3. Blockers / open questions

- None.

## 4. Recent decisions (append-only, newest first)

- 2026-11-23 — Renamed to `patchbay-tui` at `~/Code/__APPS/terminal/patchbay-tui`. The name `patchbay` belongs to the macOS app repo. `PatchbayCore` is exported as a library product for it (Pierce, #17).
- 2026-11-15 — The terminal running patchbay needs "System Audio Recording"; without it taps are silent and the app is muted. A warning is #8 (found when iTerm2 lacked it).
- 2026-11-15 — Repo lives at `~/Code/__APPS/terminal/patchbay`, public on GitHub (Pierce).
- 2026-11-15 — Name: patchbay (Pierce).

## 5. Next actions (ordered)

1. Nothing queued. Still untried by hand: AirPods as a destination, and a
   Finder route waiting with no audio processes until a QuickLook preview starts.

## 6. Handoff note

2026-11-23: repo renamed to patchbay-tui; the app repo (rex/patchbay) pins
this one by commit, so push engine changes here first, then move the pin there.

2026-11-15: engine built and measured on this Mac (Scarlett 44.1 kHz,
BlackHole 48 kHz). The first design (destination inside the aggregate) was
dropped for the tap-only aggregate + ring + output-only AUHAL; AGENTS.md §9
says why.
