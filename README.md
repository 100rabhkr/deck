# Deck

A control station for running many terminal coding sessions at once.

If you drive several AI coding agents across a lot of projects, you know the mess: a dozen terminal windows stacked on top of each other, no idea which sessions are still alive, which are idle burning memory, or where you left off in each. Deck turns that pile into one calm dashboard.

## Why it exists

Running one AI coding agent is easy. Running fifteen, across fifteen project folders, is chaos. You lose track of what is open, background agents sit there holding gigabytes of RAM while you are not looking at them, and finding the right window is a game of alt-tab roulette.

Deck was built to make the whole fleet visible and controllable from one place: see every session, open the ones you want, resume an agent when you choose to (not automatically), put idle ones to sleep to get your memory back, and lay several out side by side when you want to watch them work.

## What it does

- **One dashboard for every session.** Deck reads your machine and lists every coding session across all your projects, tagged **live** (running now), **warm** (a shell is open, no agent), or **cold** (history on disk). It auto-refreshes, so the list always matches reality.
- **Open a session as a real terminal.** Click a project and Deck opens a fast, GPU-rendered terminal right in that folder. Opening is cheap: you get a shell, nothing heavy starts on its own.
- **One-touch resume.** When you actually want the agent, hit Resume and Deck drops you back into that project's conversation. If a folder has several past conversations, it asks which one.
- **Sleep to reclaim memory.** Stop any session's agent with one click (or "Sleep all idle" for the whole idle pile). Nothing is lost, the conversation resumes from disk whenever you come back.
- **Tile them in a grid.** Switch between a single focused terminal and a 2x2, 3x3, or 4x4 grid of live sessions, so you can watch many at once instead of juggling windows.
- **Workspaces.** Save a set of projects and reopen them all in one click, tiled automatically. "Last session" brings back whatever you had open.
- **Dev-server tracker.** Deck also spots your running dev servers (their ports and uptime) and lets you kill a stray one.
- **Themes.** Recolour the terminals from a set of built-in themes.

There is also a small CLI, `deck`, that exposes the same engine:

```
deck            live agents + dev servers
deck history    every session: live / warm / cold
deck sleep <pid>   stop a live agent, reclaim its RAM
deck servers    dev servers only
```

## Build and run

Requires macOS 14+ and the Swift toolchain (Xcode Command Line Tools are enough).

```
git clone https://github.com/100rabhkr/deck.git
cd deck
swift run DeckApp        # the app
swift run deck history   # the CLI
```

To build a double-clickable `Deck.app`:

```
scripts/bundle.sh        # produces dist/Deck.app
```

### macOS permissions

macOS protects your Downloads, Documents, and Desktop folders. If your projects live in one of those, grant Deck (or the terminal you launch it from) access under **System Settings, Privacy & Security, Full Disk Access**, then relaunch. Without it, terminals still open, but in your home folder.

## How it works

Deck is a native macOS app. It reads live session state from the process table (instantly, via the system's own APIs) and reads session history from where your coding tools already store it on disk. Each pane is a real terminal. The reusable core lives in the `SessionEngine` module, and both the app and the `deck` CLI are thin layers over it.

## License

MIT. Do anything you like with it, build it into whatever you want, just keep the attribution. See [LICENSE](LICENSE).

Built by [Saurabh Kumar](https://github.com/100rabhkr).
