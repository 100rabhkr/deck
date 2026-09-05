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

- `SessionEngine` — the reusable core: discovery of live agents (from the process table), dev-server tracking, uptimes, and the sleep action. Agent-agnostic; anything that runs as a process or leaves a session file behind can be tracked. This module is the product's brain and stays isolated so the GUI imports the exact same logic the CLI uses.
- `deck` — the CLI front-end. A thin presentation layer over `SessionEngine`.

Later phases wire `SessionEngine` into a native macOS app (SwiftUI home screen, tabs backed by an embedded terminal engine, one-touch multi-window workspaces, and attention notifications when a background session needs input).

## Usage

```
swift build
swift run deck            # live agents + dev servers
swift run deck servers    # dev servers only
swift run deck sleep 1234 # stop a live agent, reclaim its RAM
swift run deck --json     # machine-readable, for the GUI
```

## Status

Phase 1: the session engine and `deck` CLI. Usable today.
