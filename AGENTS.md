# AGENTS.md

<!-- Single source of truth for Claude Code, Codex, Gemini CLI, Cursor, Copilot.
     CLAUDE.md and GEMINI.md are symlinks to this file. Keep under 150 lines. -->

## 1. Project snapshot
- **What**: a terminal UI that routes each Mac app's audio to an output device picked from a live list, and the home of the routing engine (`PatchbayCore`, a library product). The macOS menu bar and window app is a separate repo, rex/patchbay, and depends on that library.
- **Runtime**: Swift 6 (language mode 6, strict concurrency), SwiftPM, macOS 15+; Core Audio process taps (`CATapDescription`, `AudioHardwareCreateProcessTap`), a tap-only private aggregate, a lock-free ring, and an output-only AUHAL per route.
- **Infra**: none. A local binary; CI is GitHub Actions on macOS.
- **Owner**: Pierce. Work is tracked in Rivendell (rex/patchbay-tui issues).
- **Non-goals**: no graphical UI in this repo (that is rex/patchbay), no system-wide hotkeys, no daemon or login item. (Per-route volume is in, as software gain: #9.) `PatchbayCore` is a dependency of the app: changing a public name or signature there breaks its build.

## 2. Setup

```bash
make setup   # swift package resolve + compile
make dev     # swift run patchbay
```

Routing needs the "Screen & System Audio Recording" permission for the
terminal that runs patchbay. CI cannot grant it, so tests that need a live
tap don't belong in `swift test`.

## 3. Commands the agent MUST run before declaring done

- `make lint`
- `make typecheck`
- `make test`  (if testing is enabled in `VIBE.yaml`)
- `make check-architecture`  (if declared)
- `make check-skeleton` — skeleton-owned files (`scripts/`, `.claude/{hooks,commands,agents,rules}`) match the installed agentic-skeleton; if behind, `make sync-skeleton`, then commit + push
- If `infra/**` changed: `terraform fmt -recursive infra/ && terraform validate`
- If `ansible/**` changed: `ansible-lint ansible/ && ansible-playbook --syntax-check`

## 4. Repo layout

```
Sources/       PatchbayCore (engine), PatchbayTUI (pure UI logic), patchbay (executable)
Tests/         Swift Testing suites, mirroring Sources/
specs/         Spec-driven dev artifacts — read specs/<active>/ first
docs/adr/      Architectural decisions (MADR) — read README.md index
agent_docs/    On-demand deep-dive (not auto-loaded)
scripts/       Repo tooling (gates, version bumps, scripts/mcp/ credential helper)
.claude/       Subagents, slash commands, rules, hooks, MCP config
```

## 5. Code style (non-negotiable)

See `CONVENTIONS.md`. Linters enforce formatting and import order — **do not
write style rules here that the linter already checks.**

## 6. Testing policy

See `VIBE.yaml` (`quality_gates.tests`). If testing is `required`, every code
change gets a corresponding test update.

## 7. Security (hard stops)

- **This repo is public.** No secrets, tokens, hostnames of private infra, or
  personal data in code, docs, commits or issues. `detect-secrets` + gitleaks
  enforce at commit, CI runs gitleaks over full history, GitHub push
  protection is on.
- **Never install a keyboard, mouse or event tap** (`CGEvent.tapCreate`,
  `NSEvent.addGlobalMonitor…`, IOHID filters). VIBE.yaml D2 says why.
- Nothing allocates, locks or logs inside a Core Audio IO callback.
- MCP credentials never touch `.env` — they resolve at connect time through
  `scripts/mcp/op-headers.sh` and degrade to OAuth / anonymous tier.
- See `.claude/rules/security.md` for full checklist.

## 8. Architectural decisions

- Read `docs/adr/README.md` index before proposing layering / DB / auth / deploy changes.
- New decisions: create ADR (`docs/adr/template.md`), merge, THEN implement.

## 9. Things agents get wrong here

<!-- Update whenever an agent makes the same mistake twice. Start empty. -->

- Don't put the destination device inside the route's aggregate. That puts its
  inputs on the aggregate's input side, where a headset mic may open (AirPods
  would drop to call quality). The aggregate holds only the tap; an output-only
  AUHAL, which never opens input, plays the ring buffer.
- `kAudioProcessPropertyDevices` (input scope) lists every device a process
  touches, playback-only ones included. It cannot tell you whether a mic is open.
- In an aggregate's input buffer list, the tap's channels come last, after any
  sub-device inputs. Marking a stream unused in `IOProcStreamUsage` zero-fills
  its buffer; `mData` is still non-nil.
- A tap-only aggregate runs on its own clock, so the ring trims to `target`
  frames when the writer runs ahead and re-primes after an underrun.

## 10. Workflow

1. Read `PROGRESS.md` (session orientation) then `TASK_STATE.md` §0 and current slice.
2. Read `CONVENTIONS.md` before editing code.
3. Use `MAP.md` for exploration; `agent_docs/` for deep-dive detail.
4. Use Context7 MCP for up-to-date library docs; don't rely on training data.

## 11. When ending a session

- Update `TASK_STATE.md` §6 (Handoff note).
- Update `PROGRESS.md` "Last session".
- Propose AGENTS.md updates for durable new facts — don't accumulate tribal
  knowledge in auto-memory.

## 12. Subdirectory AGENTS.md (precedence: nearest wins)

- None yet. Add `Sources/<target>/AGENTS.md` when a target grows invariants of its own.

## 13. Composition with skills

This repo was bootstrapped with:
- `agentic-skeleton` (collaboration container — this file's shape — plus
  VIBE.yaml, line limits and the gates). No `lang-*` skill covers a SwiftPM
  command-line tool; the Swift wiring lives in the Makefile.

Add new durable rules to the RIGHT skill, not to this file. Transient context
goes in `TASK_STATE.md`; never here.
