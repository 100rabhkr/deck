# Helm

A control station for a terminal-centric, multi-agent coding workflow. Helm keeps track of every Claude / Codex session and dev server across all your projects, so you always know what is running where, and can put idle agents to sleep to reclaim memory without losing a single conversation.

Built because running a dozen-plus concurrent AI coding sessions on one machine turns into invisible RAM and no situational awareness. Helm makes the fleet visible and controllable.

## The model

Every session is in one of three states:

- **live** — an agent process is running and holding RAM.
- **warm** — a terminal/pane is open but the agent exited; resumes instantly, ~0 RAM.
- **cold** — no pane, only history on disk; resume opens a shell and continues.

The core action is **sleep**: stop a live agent, reclaim its RAM, keep the session resumable from disk. Only *live* sessions cost memory, so sleeping the idle ones is free savings.

## Structure

- `SessionEngine` — the reusable core: discovery of live agents (from the process table), warm/cold history (from on-disk session stores), dev-server tracking, uptimes, the sleep action, and pluggable per-folder context. Agent-agnostic; anything that runs as a process or leaves a session file behind can be tracked. This module is the product's brain and stays isolated so the GUI imports the exact same logic the CLI uses.
- `deck` — the CLI front-end. A thin presentation layer over `SessionEngine`.

### Context providers (no hard dependencies)

Each folder can carry a one-line "what's happening here" summary, resolved through a provider chain so the engine never depends on any one source:

- `GitContextProvider` — the folder's last commit subject. Universal; every developer has git.
- `BrainContextProvider` — reads `~/brain/sessions` **only if it exists**, otherwise reports itself unavailable and is skipped. A personal bonus, never a requirement.

New sources (a `.helm/summary` file, a README line) drop in as additional providers.

Later phases wire `SessionEngine` into a native macOS app (SwiftUI home screen, tabs backed by an embedded terminal engine, one-touch multi-window workspaces, and attention notifications when a background session needs input).

## Usage

```
swift build
swift run deck               # live agents + dev servers
swift run deck history       # all sessions: live / warm / cold, newest first
swift run deck history -c    # ...with a context summary per folder (slower)
swift run deck servers       # dev servers only
swift run deck sleep 1234    # stop a live agent, reclaim its RAM
swift run deck selftest      # built-in checks (no XCTest / Xcode needed)
swift run deck --json        # machine-readable, for the GUI
```

## Status

Phase 1 + 1.5: the session engine (live + warm/cold history + dev servers + pluggable context) and the `deck` CLI. Usable today.

Known follow-up: `cwd` lookups shell out to `lsof`; a native libproc call would make discovery near-instant. Fine for the CLI; worth doing before the GUI polls on a timer.
