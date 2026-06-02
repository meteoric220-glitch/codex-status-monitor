# Codex Status Monitor

A small open-source macOS utility that shows the current Codex project status inside a DynamicNotchKit-style notch monitor.

The monitor uses the Codex logo itself as the status light:

- Green logo: `Done`
- Yellow blinking logo: `Waiting`
- Blue gradient logo: `Working`
- Gray logo: `Setup` or `Error`

The monitor stays compact by default. When the status changes, it shows a short English label for 5 seconds, then returns to the compact logo-only view.

## Requirements

- macOS 14 or newer
- Swift 6 toolchain
- Codex Desktop with local state in `~/.codex`

The app is not App Store sandboxed because it needs to read local Codex state files.

## Notch Design

The window follows DynamicNotchKit's compact trailing layout: a transparent top panel draws a solid black notch shape, keeps the hardware notch space in the center, and places the Codex logo and temporary status text on the trailing side. Only the logo itself receives mouse events; the text, notch background, and transparent panel do not block clicks behind them.

## Run

```bash
swift run --scratch-path .build CodexStatusMonitor
```

On first launch, choose the project folder you want to monitor. The choice is saved locally and can be changed from the capsule context menu.

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

The app reads `~/.codex/state_5.sqlite`, matches the selected project directory against `threads.cwd`, then uses `threads.rollout_path` to read the session JSONL file.

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
