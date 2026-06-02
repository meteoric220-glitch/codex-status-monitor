# Codex Status Monitor

A small open-source macOS utility that shows the current Codex project status in a top-right floating capsule.

The monitor uses the Codex logo itself as the status light:

- Green logo: `Done`
- Yellow blinking logo: `Waiting`
- Blue gradient logo: `Working`
- Gray logo: `Setup` or `Error`

The capsule stays compact by default. When the status changes, it expands for 5 seconds to show a short English label, then returns to the compact logo-only view.

## Requirements

- macOS 14 or newer
- Swift 6 toolchain
- Codex Desktop with local state in `~/.codex`

The app is not App Store sandboxed because it needs to read local Codex state files.

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
