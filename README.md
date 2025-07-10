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

- Select any window or screen region to capture
- Resizable, movable region selection overlay
- Save screenshots to file and clipboard
- Continuous capture mode with change detection
- Configurable paths and options via `.config.ini`
- Logging of all captures

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

**Notes:**
- You can rebind these hotkeys in `Sample.ahk` or assign them to mouse buttons for convenience.
- During region selection, you can also use:
  - **Esc** or **Right Click**: Cancel selection

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
LogPath=Source/Logs/log.txt
ScreenshotPath=C:/Users/YourName/Pictures/Screenshots
captureIntervalMs=1000

[Options]
BitmapCompareThreshold=1.5
```

Adjust the paths and options as needed for your environment.

---

## Credits

- **Gdip library:** Based on [mmikeww/AHKv2-Gdip](https://github.com/mmikeww/AHKv2-Gdip), updated for AHK v2
- **Region selection:** Inspired by [Lexikos's LetUserSelectRect](https://autohotkey.com/board/topic/45921-letuserselectrect-select-a-portion-of-the-screen/) and [jeeswg's improvements](https://www.autohotkey.com/boards/viewtopic.php?t=42810)
