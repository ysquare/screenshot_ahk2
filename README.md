# screenshot_ahk2
A simple functioning screenshot script working with AHKv2

## Introduction
My little practice to implement screenshot application on AHKv2. Tested to work on AHK v2.0.2.

## How it works
### Capturing the screen
1. Requires AHK v2.0, can download it from here: https://www.autohotkey.com/
2. Run the Sample.ahk script, which will load rest of the code
3. the hotkeys:
    1. Select region to capture: Ctrl+Win+Shift+r
    2. Repeat capture with the previous setting (windows or screen region): Ctrl+Win+r
    For me, I typically assign these to mouse custom keys so they can be triggered within a second.
4. For "select to capture", a green mask will show up indicating the window or window component to capture, you can move the mouse around to select other window, then click the mouse (don't move) to indicate you've finished.
5. If you don't want to capture an existing window but a desktop region, feel free to drag with your mouse to select the region, and once the mouse button is up, the region is set
6. after 4 or 5, a blue transparent window will show up, and you can still move/resize the window to refine your region selection
7. After that, press "Enter" to finish the screen capturing.
8. At any time through 4 to 7, press "Esc" or Right Click to cancel the screen capture.
9. screenshot is saved to file (abs path configured in .config.ini) and clipboard for further use.

### Configuration in .config.ini
__Important__ Please make sure you update .config.ini before running the AHK scrip for the first time
1. LogPath: A relative path (starting from the script folder) to the log file for AHK to log important messages
2. ScreenshotPath: an absolute path to the folder that stores all captured pictures
3. DPI is a fix for capture on multiple screens with different screen scales. Refer to Display Settings on Windows, set 96 for 100% scale, 120 for 125%, 144 for 150%, and so on. DPIs should be separated with "|"


## Credits
1. Gdip library: gdip_all.ahk is updated based on [mmikeww](https://github.com/mmikeww/AHKv2-Gdip)'s work. The file is updated to work with released AHKv2 (mmikeww's version worked on AHK v2-a108).
2. Got the original screen selection idea from https://autohotkey.com/board/topic/45921-letuserselectrect-select-a-portion-of-the-screen/.
