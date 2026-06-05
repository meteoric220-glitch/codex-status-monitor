# Codex Status Monitor

![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![License MIT](https://img.shields.io/badge/license-MIT-green)
![Build from source](https://img.shields.io/badge/install-build%20from%20source-lightgrey)

A Dynamic Island-style notch indicator for Codex and Claude on macOS.

Codex Status Monitor sits beside the MacBook notch and turns the provider logo into a compact status light for the current project. It stays out of the way by default, briefly expands when the status changes, and lets you jump back to your AI coding tool with a double click.

| Signal | Meaning |
| --- | --- |
| Green logo | `Done` |
| Yellow blinking logo | `Waiting` |
| Blue flowing logo | `Working` |
| Gray logo | `Setup` or `Error` |

## Get the app locally

Build the app yourself and run the generated `.app` bundle:

```bash
git clone https://github.com/meteoric220-glitch/codex-status-monitor.git
cd codex-status-monitor
Scripts/package-app.sh
open "Packaging/Codex Status Monitor.app"
```

The packaged app is written to:

```text
Packaging/Codex Status Monitor.app
```

You can also open that `.app` directly from Finder. On first launch, choose the project folder you want to monitor.

## Requirements

- macOS 14 or newer
- Swift 6 toolchain
- Codex with local state in `~/.codex`, or Claude Code / Claude CLI with local state in `~/.claude`

The app is not App Store sandboxed because it needs to read local Codex or Claude status files. It runs locally and does not upload your project data.

## How it works

The monitor uses a DynamicNotchKit-style shape: a transparent top panel draws a solid black notch extension, keeps the hardware notch area clear, and places the provider logo next to it. Only the logo receives mouse events; the notch background, temporary text, and transparent panel do not block clicks behind them.

The app reads local session state for the selected project:

- Codex mode reads `~/.codex/state_5.sqlite`, matches the selected project directory, then reads the linked session JSONL.
- Claude mode reads `~/.claude/projects/*/*.jsonl`, matches transcripts by `cwd`, and uses the newest matching main session.

Claude Desktop and Claude Web are not supported status sources. They do not expose a stable local transcript with project `cwd` and turn/tool state. When Claude mode cannot find a matching Claude Code JSONL session, the monitor shows `No Data Yet`.

## Controls

- Single-click the logo to show the current status label for 5 seconds.
- Double-click the logo to jump back to the most recent AI/developer tool app, such as Codex, Claude, VS Code, Cursor, Terminal, iTerm, or Warp.
- Right-click the logo to open the native macOS menu.
- Use the menu to refresh status, change project, reveal the project in Finder, switch provider, switch notch side, or quit.

## Status detection

Status detection is intentionally conservative:

- unresolved user-input requests and approval requests are `Waiting`
- active unresolved turns or tool calls are `Working`
- completed final answers are `Done` unless they clearly ask for user action
- setup and unreadable local state are shown as gray `Setup` or `Error`

Common gray states:

- `Choose Project`: no project folder has been selected
- `No Thread`: Codex has no matching local thread for the selected project
- `No Data Yet`: Claude has no matching Claude Code JSONL session
- `Missing Session`: a matching session record exists, but the referenced file is missing
- `Error`: local state could not be read or parsed

## Development

Run the app without packaging:

```bash
swift run --scratch-path .build CodexStatusMonitor
```

Build the executable:

```bash
swift build --scratch-path .build --product CodexStatusMonitor
```

Run the lightweight core checks:

```bash
swift run --scratch-path .build CodexStatusMonitorCoreChecks
```

This repository uses a simple check target instead of XCTest or Swift Testing so it works on Command Line Tools installs that do not include those test frameworks.

## Icon attribution

Provider icons are bundled from [Lobe Icons](https://github.com/lobehub/lobe-icons) under the MIT license:

- Codex: [`packages/static-png/light/codex.png`](https://github.com/lobehub/lobe-icons/blob/master/packages/static-png/light/codex.png)
- Claude: [`light/claude-color.png`](https://unpkg.com/@lobehub/icons-static-png@latest/light/claude-color.png)
- License: [`MIT`](https://github.com/lobehub/lobe-icons/blob/master/LICENSE), copied into the app bundle as `LobeIcons-LICENSE.txt`

Codex and Claude trademarks remain owned by their respective owners.
