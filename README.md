# screenshot_ahk2

A modern, flexible screenshot tool for AutoHotkey v2, supporting both single and continuous region capture with an interactive UI.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Features](#features)
3. [Getting Started](#getting-started)
4. [How to Capture](#how-to-capture)
5. [Capture Modes](#capture-modes)
    - [Single Capture](#single-capture)
    - [Continuous Capture](#continuous-capture)
6. [Hotkeys & Controls](#hotkeys--controls)
7. [Configuration](#configuration)
8. [Credits](#credits)

---

## Introduction

**screenshot_ahk2** is a practice implementation of a screenshot application using AutoHotkey v2 (tested on v2.0.2). It provides a modern, interactive UI for selecting and capturing screen regions, with both single and continuous capture modes.

---

## Features

- **Robust Region Selection:** Select any window or screen region with improved precision and reliability
- **Interactive UI:** Resizable, movable region selection overlay with enhanced user controls
- **Dual Output:** Save screenshots to file and clipboard simultaneously
- **Continuous Capture:** Advanced continuous capture mode with intelligent change detection
- **Configurable:** Extensive configuration options via `.config.ini`
- **Comprehensive Logging:** Detailed logging of all captures and system events
- **Stable Hotkey Management:** Reliable hotkey cleanup prevents interference with other applications

---

## Getting Started

### Prerequisites

- [AutoHotkey v2.0+](https://www.autohotkey.com/)

### Setup

1. **Clone or download** this repository.
2. **Configure paths:**  
   Edit `.config.ini` (see below) to set your log and screenshot directories.
3. **Run** `Sample.ahk` to start the script.

---

## How to Capture

### Single Capture

There are two ways to perform a single capture:

1. **Select region to capture:**
   - Press `Ctrl+Win+Shift+R` to start region selection.
   - A green overlay appears. Hover to select a window, or drag to select a custom region.
   - Click to confirm the initial region.
   - A blue, resizable window appears. Move/resize as needed.
   - **Press `Enter`** to capture the selected region once.
   - Screenshot is saved to the configured folder and copied to the clipboard.

2. **Quick repeat capture:**
   - Press `Ctrl+Win+R` to quickly capture using the region from the last session.
   - If there is no previous capture, it will capture the active screen where the mouse is located.

### Continuous Capture

You can start a continuous capture session in two ways:

1. **During region selection:**
   - Start region selection (`Ctrl+Win+Shift+R`), then press **Shift+Enter** to begin continuous capture for the selected region.
2. **Keyboard Shortcut:**
   - Press `Ctrl+Win+T` to start a continuous capture session directly (using the last selected region).

**In continuous mode:**
- Screenshots are saved with incrementing filenames in a timestamped folder.
- The script monitors the selected region and captures **only when a change is detected**.
- After each capture, a gray notification flashes on screen.
- You can trigger an immediate capture at any time by pressing `Ctrl+Win+R`.

**Stopping continuous capture:**
- **Using the Stop UI:** If the floating stop window is shown, click the "Exit Capture" button.
- **Keyboard Shortcut:** Press `Ctrl+Win+Shift+T` (as assigned in `Sample.ahk`) to stop continuous capture immediately.
- **Start a New Capture Session:** Initiating any new capture session (continuous, single, or even just canceling the selection) will automatically stop any ongoing continuous capture before starting the new session.

---

## Hotkeys & Controls

| Shortcut            | Function & Behavior                                                                 |
|---------------------|-----------------------------------------------------------------------------------|
| Ctrl+Win+Shift+R    | Select region to capture. After selection: <br> - **Enter**: Capture once <br> - **Shift+Enter**: Start continuous capture session |
| Ctrl+Win+R          | Repeat capture with previously selected region. <br> - In continuous mode, triggers an **immediate capture** regardless of change detection. |
| Ctrl+Win+T          | Start continuous capture immediately with the last selected region.                |
| Ctrl+Win+Shift+T    | Stop continuous capture session.                                                   |

**During Region Selection:**
- **f, s, r, e, t, w, l, h**: Adjust window borders and selection options
- **Esc** or **Right Click**: Cancel selection (hotkeys are immediately released)
- **Left Click**: Select window or start drag region
- **Drag**: Create custom rectangular region with precise start/end coordinates

**Notes:**
- You can rebind these hotkeys in `Sample.ahk` or assign them to mouse buttons for convenience
- All hotkeys are properly cleaned up when selection is canceled, preventing interference with other applications
- The selection process uses a 5px threshold to distinguish between window selection clicks and drag operations

---

## Configuration

**Edit `.config.ini` before first use:**

- `LogPath`: Relative path (from script folder) for the log file
- `ScreenshotPath`: Absolute path to the folder for screenshots
- `captureIntervalMs`: (Optional) Interval for continuous capture (ms)
- `BitmapCompareThreshold`: (Optional) Similarity threshold for deduplication

### Example `.config.ini`

```ini
[Path]
LogPath = "Logs\log.txt"
ScreenshotPath = "C:\Screenshots\" 

[Capture]
CaptureIntervalMs = 200
BitmapCompareThreshold = 1
IsShowStopCaptureUI = 1
```

Adjust the paths and options as needed for your environment.

---

## Recent Improvements

### v3.0 - Enhanced Region Selection & Hotkey Management

**Major Refactoring (SelectRegion v3):**
- **Completely redesigned SelectRegion function** for better robustness, clarity, and maintainability
- **Modular architecture** with clear separation of window selection, drag region, and confirmation phases
- **Enhanced state management** using dedicated SelectionState and SelectionPhase classes
- **Improved error handling** with comprehensive try/catch blocks and logging throughout

**Precision Improvements:**
- **Exact drag coordinates:** Region selection now starts precisely where mouse is pressed and ends exactly where mouse is released
- **Smart click vs drag detection:** 5px threshold distinguishes between window selection (clicks) and region dragging
- **Consistent coordinate handling:** Eliminated coordinate inconsistencies between different selection phases

**Critical Bug Fixes:**
- **Fixed RButton hotkey blocking:** Resolved critical issue where canceling selection would leave RButton blocked in other applications
- **Comprehensive hotkey cleanup:** Added immediate hotkey cleanup in all cancellation scenarios across multiple functions
- **Resource leak prevention:** Proper cleanup of timers, hotkeys, and GUI resources in all exit conditions

**Performance & UX Enhancements:**
- **Optimized update frequencies:** Reduced GUI flicker and improved responsiveness
- **Better throttling:** Implemented smart throttling for smooth dragging without performance impact
- **Enhanced debugging:** Added comprehensive debug logging for troubleshooting and monitoring

**Technical Improvements:**
- **Idempotent cleanup:** All cleanup operations are safe to call multiple times
- **Race condition elimination:** Fixed timing issues in hotkey management and state transitions
- **Memory management:** Proper disposal of resources prevents memory leaks during extended use

These improvements make the screenshot tool significantly more reliable, precise, and user-friendly while maintaining all existing functionality.

---

## Credits

- **Gdip library:** Based on [mmikeww/AHKv2-Gdip](https://github.com/mmikeww/AHKv2-Gdip), updated for AHK v2
- **Region selection:** Inspired by [Lexikos's LetUserSelectRect](https://autohotkey.com/board/topic/45921-letuserselectrect-select-a-portion-of-the-screen/) and [jeeswg's improvements](https://www.autohotkey.com/boards/viewtopic.php?t=42810)
