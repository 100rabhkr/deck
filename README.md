# Deck

**A control station for running many terminal coding sessions at once.**

If you drive a fleet of AI coding agents across a lot of projects, you know the mess: a dozen terminal windows stacked on top of each other, no idea which sessions are alive, which are idle burning memory, or which one is quietly waiting on you. Deck turns that pile into one calm dashboard, and a tidy grid, and a glanceable notch on your screen edge.

Native macOS. Reads nothing it should not. No network, no telemetry, no credentials.

## Why it exists

Running one coding agent is easy. Running fifteen, across fifteen folders, is chaos: you lose track of what is open, background agents hold gigabytes while you are not looking, and finding the right window is alt-tab roulette. Deck makes the whole fleet visible and controllable from one place, and lets you spend memory on an agent only when you actually want to.

## What it does

### The dashboard
Every coding session across all your projects, in one list, tagged **live** (running now), **warm** (a shell is open, no agent), or **cold** (history on disk). It auto-refreshes on a timer, so the list always matches reality. Discovery is native (libproc), so scanning your whole machine takes milliseconds, not seconds.

### Open cheap, resume on purpose
Click a project and Deck opens a fast, GPU-rendered terminal in that folder. Opening is deliberately cheap: you get a shell, nothing heavy starts on its own. When you actually want the agent, hit **Resume** and Deck drops you back into that project's conversation. If a folder holds several past conversations, it asks which one, with a preview of each.

### Sleep to get your memory back
Stop any session's agent with one click, or **Sleep all idle** to reclaim the whole idle pile at once. Nothing is lost; the conversation resumes from disk whenever you return. Deck shows you exactly how much RAM the idle sessions are holding.

### Tile the fleet
One control switches between a single focused terminal and a **2x2, 3x3, or 4x4 grid** of live sessions, so you can watch many agents work at once instead of juggling windows. Each cell has its own resume, focus, and sleep.

### Workspaces
Save a set of projects and reopen them all in one click, tiled automatically at a sensible density. **Last session** brings back whatever you had open.

### The side notch
A small always-on pill pinned to the **top, right, or bottom** edge of your screen, floating above everything and visible on every Space. At a glance: how many sessions are live, how many idle, how much RAM. When a session you are not looking at **needs you, it turns amber and names it**. Click the name to jump straight to it.

### Attention chime
Deck watches each session's terminal bell. When a background session rings, one you are not looking at, it lets you know: an amber badge on its row, tab, and grid cell, a chime, and a notification. Focus it and the alert clears. So you can let agents run and get pulled back only when they actually want you.

### Dev-server tracker
Deck also spots your running dev servers, their ports and how long they have been up, and lets you kill a stray one.

### Make it yours
A Settings window (Appearance, Behaviour, Agents, Chime, Notch): themes, font, auto-refresh interval, default layout, the idle threshold, restore-on-launch, editable resume commands, chime sound, and which edge the notch pins to.

### A CLI too
The same engine, on the command line:

```
deck            live agents + dev servers
deck history    every session: live / warm / cold
deck sleep <pid>   stop a live agent, reclaim its RAM
deck servers    dev servers only
```

## Private by design

Deck reads only what your Mac already exposes about your own processes, and the session files your coding tools already write to disk. It does not read your keychain or any credential, it makes no network calls, and it sends nothing anywhere. Everything stays on your machine.

## Install

Requires macOS 14+ (Apple silicon) and the Swift toolchain (Xcode Command Line Tools are enough).

**Download:** grab the latest `Deck.app` from [Releases](https://github.com/100rabhkr/deck/releases). It is not notarised, so after downloading run `xattr -cr /Applications/Deck.app` once, then open it.

**Or build it:**

```
git clone https://github.com/100rabhkr/deck.git
cd deck
swift run DeckApp        # the app
swift run deck history   # the CLI
scripts/bundle.sh        # build dist/Deck.app
```

### macOS permissions
macOS protects your Downloads, Documents, and Desktop folders. If your projects live in one of those, grant Deck (or the terminal you launch it from) access under **System Settings, Privacy & Security, Full Disk Access**, then relaunch. Without it, terminals still open, just in your home folder.

## How it works

Native macOS app. It reads live session state from the process table (via the system's own APIs) and session history from where your tools already keep it. Each pane is a real terminal surface. The reusable core lives in the `SessionEngine` module; the app and the `deck` CLI are thin layers over it.

## License

MIT. Do anything you like with it, build it into whatever you want, just keep the attribution. See [LICENSE](LICENSE).

---

Built by [Saurabh Kumar](https://github.com/100rabhkr). Built for [360 Labs](https://github.com/360Labs-ai) and the world.
