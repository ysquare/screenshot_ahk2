# screenshot_ahk2
A simple, flexible screenshot tool for AutoHotkey v2

## Introduction
This project is a practice implementation of a screenshot application using AutoHotkey v2 (tested on v2.0.2). It supports both single and continuous region capture, with a modern, interactive selection UI.

## Features
- Select any window or screen region to capture
- Resizable, movable region selection overlay
- Save screenshots to file and clipboard
- Continuous capture mode (Shift+Enter)
- Configurable paths and options via `.config.ini`
- Logging of all captures

## Getting Started
### Prerequisites
- [AutoHotkey v2.0+](https://www.autohotkey.com/)

### Setup
1. **Clone or download** this repository.
2. **Configure paths:**
   - Edit `.config.ini` (see below) to set your log and screenshot directories.
3. **Run** `Sample.ahk` to start the script.

### Default Hotkeys
- **Ctrl+Win+Shift+R**: Select region to capture
- **Ctrl+Win+R**: Repeat capture with previous region

You can rebind these hotkeys in `Sample.ahk` or assign them to mouse buttons for convenience.

## How to Capture
1. **Start region selection** (`Ctrl+Win+Shift+R`):
   - A green overlay appears. Hover to select a window, or drag to select a custom region.
   - Click to confirm the initial region.
2. **Refine selection:**
   - A blue, resizable window appears. Move/resize as needed.
   - **Press `Enter`** to capture the selected region **once**.
   - **Press `Shift+Enter`** to start a **continuous capture session** (captures repeatedly until stopped).
   - **Press `Esc` or Right Click** at any time to cancel.
3. **After capture:**
   - Screenshot is saved to the configured folder and copied to the clipboard.
   - Log entry is written.

## Continuous Capture Mode
- After selecting a region and pressing **Shift+Enter**, the script enters continuous capture mode.
- A floating window appears with:
  - **Exit Capture** button: Stop continuous capture
  - **Capture Now** button: Take an immediate screenshot
- Screenshots are saved with incrementing filenames in a timestamped folder.

## Configuration: `.config.ini`
**Important:** Update `.config.ini` before first use.

- `LogPath`: Relative path (from script folder) for the log file
- `ScreenshotPath`: Absolute path to the folder for screenshots
- `captureIntervalMs`: (Optional) Interval for continuous capture (ms)
- `BitmapCompareThreshold`: (Optional) Similarity threshold for deduplication

## Shortcut Keys & Capture Behavior

| Shortcut            | Function & Behavior                                                                 |
|---------------------|-----------------------------------------------------------------------------------|
| Ctrl+Win+Shift+R    | Select region to capture. After selection: <br> - **Enter**: Capture once <br> - **Shift+Enter**: Start continuous capture session |
| Ctrl+Win+T          | Start continuous capture immediately with the last selected region. <br> - In continuous mode, screenshots are taken **only when a change is detected** in the selected region. <br> - After each capture, a gray notification is shown. |
| Ctrl+Win+R          | Repeat capture with previously selected region. <br> - If pressed during a continuous capture session, triggers an **immediate capture** regardless of change detection. |
| Ctrl+Win+Shift+T    | Stop continuous capture session.                                                   |

**Notes:**
- You can rebind these hotkeys in `Sample.ahk` or assign them to mouse buttons for convenience.
- During region selection, you can also use:
  - **Esc** or **Right Click**: Cancel selection

### Capture Modes
- **Single Capture:**
  - Select region (`Ctrl+Win+Shift+R`), then press **Enter** to capture once.
- **Continuous Capture:**
  - Select region (`Ctrl+Win+Shift+R`), then press **Shift+Enter**; or press `Ctrl+Win+T` to start with the last region.
  - The script monitors the selected region and captures **only when a change is detected**.
  - After each capture, a gray notification flashes on screen.
  - You can trigger an immediate capture at any time during continuous mode by pressing `Ctrl+Win+R`.
  - Stop continuous capture with `Ctrl+Win+Shift+T`.

## Credits
- **Gdip library:** Based on [mmikeww/AHKv2-Gdip](https://github.com/mmikeww/AHKv2-Gdip), updated for AHK v2
- **Region selection:** Inspired by [Lexikos's LetUserSelectRect](https://autohotkey.com/board/topic/45921-letuserselectrect-select-a-portion-of-the-screen/) and [jeeswg's improvements](https://www.autohotkey.com/boards/viewtopic.php?t=42810)
