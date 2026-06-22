# CLAUDE.md

Guidance for working in this repo. Read first; keep concise.

## What this is

AutoHotkey **v2** screenshot tool: interactive single + continuous region capture. Tested on AHK v2.0.2. `#Requires AutoHotkey v2.0` — do **not** use v1 syntax.

## Running & testing

- No build step. Launch the entry point with AHK v2: `AutoHotkey.exe Source/Sample.ahk`.
- AHK is **not on PATH** in this environment — locate `AutoHotkey.exe` (v2) yourself or ask the user before assuming a path.
- This is a GUI/hotkey app — there are no automated tests. **Diagnose via the log file** at `LogPath` (default `Source/Logs/log.txt`). Lines are tagged `[DEBUG]` / `[WARN]` / `[ERROR]` and timestamped. When chasing a bug, read the log tail and add targeted `writeLog` calls.
- Iterating = edit `.ahk` → reload script (`#SingleInstance Force` restarts on rerun) → exercise the hotkey → check log. Do not trust behavior without observing the log.

## Repo layout

```
Source/Sample.ahk            # Entry point: hotkey bindings only. Rebind here.
Source/Screenshot_v2.ahk     # Core: capture pipeline, SelectRegion state machine,
                             #   continuous-capture loop, save/log queues, GDI+ lifecycle
Source/Window_Settings.ahk   # RegionSetting model + per-app BorderSettings + UIA focus detection
Source/.config.ini           # Runtime config (paths, intervals, thresholds) — user-edited
Source/Lib/                  # VENDORED: Gdip_All_v2.ahk, UIA.ahk, UIA_Browser.ahk — DO NOT EDIT
```

`.gitignore`d: `Prompts/`, `Source/Logs/`, `Source/Try/`, `Source/CaptureCpp/{build,bin}`.

## Hotkeys (defined in `Sample.ahk`)

| Key             | Action |
|-----------------|--------|
| `Ctrl+Win+Shift+R` | Region select → `Enter` single capture, `Shift+Enter` continuous |
| `Ctrl+Win+R`       | Repeat last capture (or force-immediate capture in continuous mode) |
| `Ctrl+Win+T`       | Start continuous capture (last region) |
| `Ctrl+Win+Shift+T` | Stop continuous capture |

During region select: `f/s/r/e/t/w/l/h` adjust borders/ratio; `Esc` or right-click cancels.

## The four things to understand before editing

**1. `RegionSetting` (`Window_Settings.ahk`) is the central model.** Holds `win_id` + `left/top/right/bottom` + border/aspect fields. `GetRegionRect()` is the single source of truth — it applies borders then aspect-ratio cropping and returns the final capture rect. `ScreenString()` feeds GDI+ capture; `GuiString()`/`moveGui()` drive the overlay. `check_win_id()` re-syncs a tracked window's current position (returns false if window closed/invalid — never treat that as fatal, just skip). When region changes, `SetRegionByPos`/`SetRegionRect` auto-call `reset_borders()` and clear `win_id`.

**2. `SelectRegion` is a 3-phase state machine** (`WINDOW_SELECT → DRAG_REGION → CONFIRM`) managed by the `SelectionState`/`SelectionPhase` classes. The 5px threshold distinguishes a click (window select) from a drag. **Hotkey cleanup is the #1 historical bug source** — `*RButton`/`Esc` must be released in *every* exit path or they stay blocked globally. `SelectionState.Cleanup()` is idempotent; `Cancel()` disables hotkeys immediately before teardown. If you touch any exit/early-return in this flow, verify hotkeys get disabled.

**3. Continuous capture is a self-rescheduling timer.** `DoCapture` schedules its next run via `SetTimer(DoCapture, -nextInterval)` (compensates for capture elapsed time). It **auto-stops when the tracked `win_id` transitions to 0** (window closed). Dedup skips unchanged frames via grayscale-thumbnail comparison (`IsBitmapChangedAndUpdate`); `immediateCapture:=true` bypasses dedup. Guard flags `isCaptureContinue` / `isCaptureInProgress` prevent re-entry.

**4. Saving and logging are async, both timer-driven.** `SaveQueue → SaveBitmapWorker` (file write + optional clipboard + gray flash confirm) and `LogQueue → LogWorker` (batched, retried file append). **Do not `Gdip_DisposeImage` a bitmap you passed to `QueueBitmapForSaving`** — the worker owns disposal. `g_pToken` (GDI+) starts at script load and shuts down `OnExit`; `FlushLogQueue()` also runs `OnExit`.

## Conventions

- **AHK v2 syntax only:** `:=` assignment, function calls (not v1 commands), `&var` ByRef outputs, classes, fat-arrow closures `(*) => ...`.
- Vendored libs in `Source/Lib/` are external dependencies — never modify them; treat as read-only.
- `writeLog()` over direct `FileAppend` — always queue through it so logs batch correctly.
- Errors that can leave hotkeys/timers stuck must clean up in `finally`/`catch` — leak prevention matters more than brevity here (see recent RButton-blocking commits).
- Per-app window chrome cropping lives in the `BorderSettings` Map (`Window_Settings.ahk`) — Zoom/Teams/WeMeet/Lync/explorer are pre-tuned; add an app by defining a `BorderSetting` and mapping `processname.exe` → it.
- `get_focus_content_element()` matches UIA elements in **both** Chinese (`共享内容视图`) and English (`Shared content view`) — keep locale strings in sync when adding detection.

## Config (`Source/.config.ini`)

`[Path] LogPath` (relative to script), `ScreenshotPath` (absolute). `[Capture] CaptureIntervalMs`, `BitmapCompareThreshold`, `IsShowStopCaptureUI`, `ShowConfirmOnSingleCapture`, `ShowConfirmOnContinuousCapture`. Defaults also exist as globals at the top of `Screenshot_v2.ahk`. Missing paths cause `ExitApp -1` on startup.
