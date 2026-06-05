# Codex Status Monitor

A small open-source macOS utility that shows the current Codex or Claude project status inside a DynamicNotchKit-style notch monitor.

The monitor uses the selected provider mark itself as the status light:

- Green logo: `Done`
- Yellow blinking logo: `Waiting`
- Blue gradient logo: `Working`
- Gray logo: `Setup` or `Error`

Gray means the monitor does not currently have a usable live status:

- `Setup` / `Choose Project`: no project folder has been selected yet.
- `Error` / `No Thread`: Codex has no matching local thread for the selected project.
- `Error` / `No Data Yet`: Claude has no matching Claude Code JSONL session for the selected project. This is expected for Claude Desktop or Claude Web.
- `Error` / `Missing Session`: a matching session record exists, but the referenced session file is missing.
- `Error` / `Error`: the local state file could not be read or parsed.

The monitor stays compact by default. When the status changes, it shows a short English label for 5 seconds, then returns to the compact logo-only view.

Provider icons are bundled from [Lobe Icons](https://github.com/lobehub/lobe-icons) under the MIT license. The app includes the Lobe Icons license text in its resources; Codex and Claude trademarks remain owned by their respective owners.

## Icon Attribution

The bundled provider icons come from Lobe Icons:

- Codex: [`packages/static-png/light/codex.png`](https://github.com/lobehub/lobe-icons/blob/master/packages/static-png/light/codex.png)
- Claude: [`light/claude-color.png`](https://unpkg.com/@lobehub/icons-static-png@latest/light/claude-color.png)
- License: [`MIT`](https://github.com/lobehub/lobe-icons/blob/master/LICENSE), copied into the app bundle as `LobeIcons-LICENSE.txt`

## Requirements

- macOS 14 or newer
- Swift 6 toolchain
- Codex Desktop with local state in `~/.codex`, or Claude CLI / Claude Code with local state in `~/.claude`

The app is not App Store sandboxed because it needs to read local Codex or Claude state files.

## Notch Design

The window follows DynamicNotchKit's compact trailing layout: a transparent top panel draws a solid black notch shape, keeps the hardware notch space in the center, and places the provider status mark and temporary status text on the trailing side. Only the mark itself receives mouse events; the text, notch background, and transparent panel do not block clicks behind them.

## Run

```bash
swift run --scratch-path .build CodexStatusMonitor
```

On first launch, choose the project folder you want to monitor. The choice is saved locally and can be changed from the context menu. The same menu also switches the active provider between Codex and Claude.

## Build

```bash
swift build --scratch-path .build --product CodexStatusMonitor
```

## Core Checks

This repository includes a lightweight check target because some Command Line Tools installs do not include XCTest or Swift Testing.

```bash
swift run --scratch-path .build CodexStatusMonitorCoreChecks
```

## Package a .app

```bash
Scripts/package-app.sh
```

The app bundle will be written to `Packaging/Codex Status Monitor.app`.

## How Status Is Detected

Codex mode reads `~/.codex/state_5.sqlite`, matches the selected project directory against `threads.cwd`, then uses `threads.rollout_path` to read the session JSONL file.

Claude mode reads `~/.claude/projects/*/*.jsonl`, matches the selected project directory against each transcript line's `cwd`, and picks the newest matching main session. This supports Terminal CLI sessions and VS Code Claude Code sessions.

Claude Desktop and Claude Web are not supported status sources. They do not expose a stable local transcript with project `cwd` and turn/tool state. Their Electron or browser caches can contain historical UI strings such as `thinking`, `message.sent`, or tool names, but those strings are not reliable indicators of the current conversation state, and scanning them can make the monitor slow. When Claude mode cannot find a matching Claude Code JSONL session, the monitor shows `No Data Yet`.

Codex and Claude provider marks are loaded from bundled Lobe Icons resources, so CLI-only users do not need the desktop apps installed for the icon display.

Status priority:

```text
Setup/Error > Waiting > Working > Done
```

Waiting is conservative:

- unresolved `request_user_input` is a strong Waiting signal
- unresolved approval/escalation requests are strong Waiting signals
- decision keywords such as `please confirm`, `choose`, `let me know`, `请确认`, `请选择`, `是否继续` are Waiting signals
- a final message ending in `?` or `？` only counts when it is clearly choice-like

Plain explanatory questions such as `这个问题为什么会发生？` are treated as `Done`.
