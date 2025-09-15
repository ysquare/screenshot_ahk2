#Requires AutoHotkey v2.0
#include Lib/Gdip_All_v2.ahk
#Include ./Window_Settings.ahk

; Credits
; Gdip_All.ahk coming from https://www.autohotkey.com/boards/viewtopic.php?f=6&t=6517
; the SelectRegion function is based upon the code developed by jeeswg,
; orignal post here: https://www.autohotkey.com/boards/viewtopic.php?t=42810
; whose code is based upon Lexikos's work at
; https://autohotkey.com/board/topic/45921-letuserselectrect-select-a-portion-of-the-screen/
;
; My updates: 1: add a window/control selection prior to free drag slection
;             2: add a resizable confirm rectangle, and use enter to confirm
;             3: the keywait function is replaced with loop check;


; ==============================================================================
; Configuration Sector
; Transparancy ranges from 0 - 255, 0 is fully transparent, 255 is opaque

; Credits
; UIA.ahk from https://github.com/Descolada/UIA-v2/tree/main


DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")

SelectionColor := "Green"
SelectionTransparency := 64   ; 0-255
ConfirmColor := 0x0078D7 ; this is the same color with default window title bar
ConfirmTransparency := 128
SnapshotFlashColor := "Gray"
SnapshotFlashDuration := 50 ;milliseconds
SnapshotFlashTransparency := 64    ; 0-255
ScreenshotFilenameTemplate := "Screen yyyyMMdd-HHmmss.png"
ScreenshotFilenameTemplate_Continuous := "Screen yyyyMMdd-HHmmss"
ScreenshotFolderTemplate := "Screen yyyyMMdd-HHmmss"
SmallDelta := 30  ; the smallest screenshot that can be taken is 10x10 by pixel
LogIntervalMs := 1000 ; the interval for logging, in milliseconds

captureIntervalMs := 1000 ; Default interval in milliseconds, if not overridden by .config.ini, set it to 1s.
BitmapCompareThreshold := 1 ; the threshold for bitmap comparison, typically between 1 and 10, can be float number
BitmapCompareThumbnailSize := 8 ; the size of the thumbnail for bitmap comparison

GetConfig(A_ScriptDir "\.config.ini")
GetConfig(configFile)
{
    Try
    {
        global LogPath := A_WorkingDir "\" IniRead(configFile , "Path" , "LogPath")
        SplitPath(LogPath, ,&OutDir)
        EnsureFolderExists(OutDir)

        global ScreenshotPath := EnsureFolderExists(IniRead(configFile, "Path", "ScreenshotPath"))
        global captureIntervalMs := IniRead(configFile, "Capture", "CaptureIntervalMs")
        global BitmapCompareThreshold := IniRead(configFile, "Capture", "BitmapCompareThreshold")
        global IsShowStopCaptureUI := IniRead(configFile, "Capture", "IsShowStopCaptureUI", 0)
        global ShowConfirmOnContinuousCapture := IniRead(configFile, "Capture", "ShowConfirmOnContinuousCapture", 1)
    } Catch Error as err
    {
        MsgBox "Error Getting Configuartion, please check", "Error", "iconx"
        ExitApp -1
    }
}

; ==============================================================================
global captureX,captureY,captureR,captureB
CoordMode "Mouse", "Screen"
DetectHiddenWindows True

; --- GDI+ global session management ---
global g_pToken := 0
global lastBitmap := 0 ; old: save the last captured bitmap for comparison
; New: cache the last thumbnail and its grayscale array for deduplication
global lastThumbBitmap := 0
global lastThumbGrayArr := 0

; Start GDI+ at script start
if !g_pToken {
    g_pToken := Gdip_Startup()
    if !g_pToken {
        MsgBox "Failed to start GDI+"
        ExitApp
    }
}

; Ensure cleanup at script exit
OnExit(*) {
    global lastBitmap, g_pToken
    FlushLogQueue()
    if IsSet(lastBitmap) && lastBitmap {
        Gdip_DisposeImage(lastBitmap)
        lastBitmap := 0
    }
    if g_pToken {
        Gdip_Shutdown(g_pToken)
        g_pToken := 0
    }
}

; --- Modular thumbnail and comparison helpers ---
CreateThumbnail(pBitmap) {
    global BitmapCompareThumbnailSize
    return Gdip_ResizeBitmap(pBitmap, BitmapCompareThumbnailSize, BitmapCompareThumbnailSize)
}

CompareGrayArrays(arr1, arr2, threshold) {
    diff := 0
    for i, v in arr1
        diff += Abs(v - arr2[i])
    avgDiff := diff / arr1.Length
    return avgDiff < threshold
}

IsBitmapChangedAndUpdate(pBitmap) {
    global lastThumbGrayArr, BitmapCompareThumbnailSize, BitmapCompareThreshold
    pThumb := CreateThumbnail(pBitmap)
    arr := GetGrayArrayFromBitmap(pThumb, BitmapCompareThumbnailSize, BitmapCompareThumbnailSize)
    Gdip_DisposeImage(pThumb)
    isDuplicate := false
    if (lastThumbGrayArr != 0) {
        isDuplicate := CompareGrayArrays(arr, lastThumbGrayArr, BitmapCompareThreshold)
    }
    if !isDuplicate {
        lastThumbGrayArr := arr
    }
    return !isDuplicate
}

global SaveQueue := []          ; Array of {bitmap, filename, region, showConfirm, logPrefix, toClipboard}
global IsSaveWorkerRunning := false
global MAX_SAVE_QUEUE := 10

QueueBitmapForSaving(pBitmap, sFilename, region, showConfirm, logPrefix := "Captured", toClipboard := false) {
    global SaveQueue, IsSaveWorkerRunning, MAX_SAVE_QUEUE
    if SaveQueue.Length >= MAX_SAVE_QUEUE {
        writeLog("[WARN] Save queue full, discarding capture at " . A_Now)
        Gdip_DisposeImage(pBitmap)
        return
    }
    SaveQueue.Push({bitmap: pBitmap, filename: sFilename, region: region.Clone(), showConfirm: showConfirm, logPrefix: logPrefix, toClipboard: toClipboard})
    if !IsSaveWorkerRunning {
        IsSaveWorkerRunning := true
        SetTimer(SaveBitmapWorker, 10)
    }
}

SaveBitmapWorker() {
    global SaveQueue, IsSaveWorkerRunning
    if SaveQueue.Length = 0 {
        IsSaveWorkerRunning := false
        SetTimer(SaveBitmapWorker, 0)
        return
    }
    item := SaveQueue.RemoveAt(1)
    sFilename := item.filename
    sFilename := updateFilename(&sFilename)
    ; 1. copy to clipboard if requested
    if item.toClipboard
        Gdip_SetBitmapToClipboard(item.bitmap)
    ; 2. save bitmap to file if filename is provided
    if sFilename
        Gdip_SaveBitmapToFile(item.bitmap, sFilename)

    Gdip_DisposeImage(item.bitmap)
    ; 3. write to log
    if item.HasOwnProp("region") && item.region
        writeLog(item.logPrefix " to " sFilename " (" item.region.ScreenString() ")")
    else
        writeLog(item.logPrefix " to " sFilename)
    ; 4. show confirmation
    if item.showConfirm && FileExist(sFilename)
        ShowCapturedRegion(item.region)
    ; Continue timer for next item
    SetTimer(SaveBitmapWorker, -10)
}

CaptureScreenRegion(&region, sFilename:="", toClipboard:=False, showConfirm:=true, deduplicate:=false)
{
    global lastThumbGrayArr, LastConfirmGui
    if ( sFilename!="" || toClipboard )  ; either of the options should be true to proceed
    {
        monitor_index := GetMonitorIndex(region)  ; todo: change GetMonitorIndex()
        if monitor_index > 0  ; only do capture when window is in normal status, not when it's minimized or hidden
        {
            ; GDI+ is already started globally
            if showConfirm && IsSet(LastConfirmGui) && LastConfirmGui{
                LastConfirmGui.Destroy()
                LastConfirmGui := 0
            }
            pBitmap := Gdip_BitmapFromScreen(region.ScreenString(), 0x40cc0020) ; always getting bitmap from screen, not from window
            if !pBitmap || pBitmap = -1
            {
                writeLog("Failed to capture screen! pBitmap is invalid.")
                return 0
            }
            if deduplicate {
                if !IsBitmapChangedAndUpdate(pBitmap) {
                    Gdip_DisposeImage(pBitmap)
                    return 0 ; skip save, duplicate
                }
            }
            if sFilename || toClipboard {
                QueueBitmapForSaving(pBitmap, sFilename, region, showConfirm, "Captured", toClipboard)
                ; Do NOT dispose pBitmap here! The worker will do it.
            } else {
                Gdip_DisposeImage(pBitmap)
            }
            return 1 ; indicate saved/queued
        }
    }
    return 0
}

; Need this to avoid duplicated filename, use the following procedure to find the
; first available filename
updateFilename(&sFilename)
{
    SplitPath sFilename, ,&dir, &ext, &name_no_ext
    postfix := 1
    while FileExist(sFilename)
        sFilename := dir "\" name_no_ext "_" postfix++ "." ext
    return sFilename
}

global LastConfirmGui := 0

ShowCapturedRegion(region) {
    global SnapshotFlashColor, SnapshotFlashTransparency, SnapshotFlashDuration, LastConfirmGui
    ; Destroy previous confirmation GUI if it exists
    if IsSet(LastConfirmGui) && LastConfirmGui
        LastConfirmGui.Destroy()
    MyGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound -DPIScale")
    MyGui.BackColor := SnapshotFlashColor
    WinSetTransparent(SnapshotFlashTransparency, MyGui)
    MyGui.Show(region.GuiString())
    LastConfirmGui := MyGui
    SetTimer(() => (IsSet(MyGui) && MyGui ? MyGui.Destroy() : 0), -SnapshotFlashDuration)
}

; --- Constants for SelectRegion phases ---
class SelectionPhase {
    static WINDOW_SELECT := 1
    static DRAG_REGION := 2
    static CONFIRM := 3
    static CANCELED := -1
    static COMPLETED := 0
}

class SelectionState {
    __New() {
        this.phase := SelectionPhase.WINDOW_SELECT
        this.canceled := false
        this.dragStartX := 0
        this.dragStartY := 0
        this.initialX := 0
        this.initialY := 0
        this.isDragging := false  ; Track if we've actually started dragging (exceeded 5px threshold)
        this.gui := 0
        this.timers := Map()
        this.hotkeys := []
    }
    
    Cancel() {
        this.canceled := true
        this.phase := SelectionPhase.CANCELED
        ; Immediately cleanup to prevent hotkey blocking
        this.Cleanup()
        writeLog("[DEBUG] Selection canceled - hotkeys and resources cleaned up")
    }
    
    IsActive() {
        return !this.canceled && this.phase > SelectionPhase.COMPLETED
    }
    
    Cleanup() {
        ; Make cleanup idempotent - safe to call multiple times

        ; Clean up timers
        if this.timers.Count > 0 {
            for name, _ in this.timers {
                try {
                    SetTimer(name, 0)
                } catch {
                    ; Ignore cleanup errors
                }
            }
            this.timers.Clear()
        }

        ; Clean up hotkeys
        if this.hotkeys.Length > 0 {
            for hotkey in this.hotkeys {
                try {
                    Hotkey hotkey.key, hotkey.func, "Off"
                    writeLog("[DEBUG] Disabled hotkey: " hotkey.key)
                } catch Error as err {
                    writeLog("[WARNING] Failed to disable hotkey " hotkey.key ": " err.Message)
                }
            }
            this.hotkeys := []
        }

        ; Clean up GUI
        if this.gui {
            try {
                this.gui.Destroy()
                writeLog("[DEBUG] GUI destroyed")
            } catch Error as err {
                writeLog("[WARNING] Failed to destroy GUI: " err.Message)
            }
            this.gui := 0
        }
    }
}

SelectRegion(&region) {
    global SelectionColor, SelectionTransparency, SmallDelta, BorderSettings
    
    ; Input validation
    if !IsObject(region) {
        writeLog("[ERROR] SelectRegion: Invalid region object")
        return -1
    }
    
    ; Initialize state
    state := SelectionState()
    CoordMode "Mouse", "Screen"
    DetectHiddenWindows True
    
    try {
        ; Create and setup GUI
        if !_InitializeSelectionGUI(&state, region) {
            state.Cleanup()
            return -1
        }

        ; Phase 1: Window Selection
        result := _WindowSelectionPhase(&state, &region)
        if result <= 0 {
            ; Ensure cleanup happens on early exit (including cancellation)
            if !state.canceled {
                state.Cleanup()
            }
            return result
        }

        ; Phase 2: Drag Region (if mouse was pressed)
        if state.phase = SelectionPhase.DRAG_REGION {
            result := _DragRegionPhase(&state, &region)
            if result <= 0 {
                ; Ensure cleanup happens on early exit (including cancellation)
                if !state.canceled {
                    state.Cleanup()
                }
                return result
            }
        }

        ; Phase 3: Confirmation
        result := AdjustConfirmWindow(state.gui, &region)

        ; Final cleanup (if not already cleaned up by cancellation)
        if !state.canceled {
            state.Cleanup()
        }

        return result

    } catch Error as err {
        writeLog("[ERROR] SelectRegion failed: " err.Message)
        state.Cleanup()
        return -1
    }
}

_InitializeSelectionGUI(&state, region) {
    global SelectionColor, SelectionTransparency
    
    try {
        ; Create GUI
        state.gui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound -DPIScale")
        state.gui.BackColor := SelectionColor
        WinSetTransparent SelectionTransparency, state.gui
        
        ; Setup cancel hotkeys
        cancelFunc := (*) => state.Cancel()
        state.hotkeys.Push({key: "*RButton", func: cancelFunc})
        state.hotkeys.Push({key: "Esc", func: cancelFunc})
        Hotkey "*RButton", cancelFunc, "On"
        Hotkey "Esc", cancelFunc, "On"
        
        ; Validate and show initial region
        region.check_win_id()
        state.gui.Show(region.GuiString())
        
        ; Move mouse to region center if region is set
        if region.IsSet() {
            region.GetCenter(&centerX, &centerY)
            state.initialX := centerX
            state.initialY := centerY
            MouseMove(centerX, centerY)
        } else {
            MouseGetPos &tempX, &tempY
            state.initialX := tempX
            state.initialY := tempY
        }
        
        return true
    } catch Error as err {
        writeLog("[ERROR] Failed to initialize selection GUI: " err.Message)
        return false
    }
}

_WindowSelectionPhase(&state, &region) {
    global SmallDelta, BorderSettings
    
    try {
        ; Setup adjustment hotkeys
        adjustFunc := (key, *) => _HandleAdjustmentKey(key, &region, state.gui)
        adjustKeys := ["f", "s", "r", "e", "t", "w", "l", "h"]
        for key in adjustKeys {
            state.hotkeys.Push({key: key, func: adjustFunc.Bind(key)})
            Hotkey key, adjustFunc.Bind(key), "On"
        }
        
        ; Setup window update timer
        updateFunc := () => _UpdateWindowSelection(&state, &region)
        state.timers["WindowUpdate"] := updateFunc
        SetTimer(updateFunc, 100) ; Reduced frequency for better performance
        
        ; Wait for mouse click or cancellation
        while state.IsActive() && state.phase = SelectionPhase.WINDOW_SELECT {
            if GetKeyState("LButton") {
                MouseGetPos &tempX, &tempY
                state.dragStartX := tempX
                state.dragStartY := tempY
                ; Don't set region immediately - wait for 5px threshold in drag update
                state.phase := SelectionPhase.DRAG_REGION
                break
            }
            Sleep 10 ; Reduced sleep for better responsiveness
        }
        
        ; Clean up window selection phase
        if state.timers.Has("WindowUpdate") {
            SetTimer(state.timers["WindowUpdate"], 0)
            state.timers.Delete("WindowUpdate")
        }
        
        ; Remove adjustment hotkeys
        for key in adjustKeys {
            try {
                Hotkey key, "Off"
            } catch {
                ; Ignore cleanup errors
            }
        }
        
        return state.IsActive() ? 1 : -1
        
    } catch Error as err {
        writeLog("[ERROR] Window selection phase failed: " err.Message)
        return -1
    }
}

_DragRegionPhase(&state, &region) {
    try {
        ; Setup drag update timer
        dragFunc := () => _UpdateDragSelection(&state, &region)
        state.timers["DragUpdate"] := dragFunc
        SetTimer(dragFunc, 16) ; ~60fps for smooth dragging
        
        ; Wait for mouse release or cancellation
        while state.IsActive() && state.phase = SelectionPhase.DRAG_REGION {
            if !GetKeyState("LButton") {
                ; Capture exact mouse release position
                MouseGetPos &releaseX, &releaseY
                
                ; Check if release is within 5px threshold - if so, treat as window select (click)
                deltaX := Abs(releaseX - state.dragStartX)
                deltaY := Abs(releaseY - state.dragStartY)
                
                if (!state.isDragging) {
                    ; This was a click, not a drag - keep the current window-based region
                    ; No need to update region since it should already be set from window selection
                    writeLog("[DEBUG] Mouse release within 5px threshold - treating as window selection")
                } else {
                    ; This was a real drag - update region with final position
                    region.SetRegionByPos(releaseX, releaseY, state.dragStartX, state.dragStartY)
                    region.MoveGui(state.gui)
                    writeLog("[DEBUG] Mouse release after drag - using drag selection")
                }
                
                state.phase := SelectionPhase.CONFIRM
                break
            }
            Sleep 10
        }
        
        ; Clean up drag phase
        if state.timers.Has("DragUpdate") {
            SetTimer(state.timers["DragUpdate"], 0)
            state.timers.Delete("DragUpdate")
        }
        
        return state.IsActive() ? 1 : -1
        
    } catch Error as err {
        writeLog("[ERROR] Drag region phase failed: " err.Message)
        return -1
    }
}

_UpdateWindowSelection(&state, &region) {
    static lastX := 0, lastY := 0, lastUpdate := 0
    global SmallDelta, BorderSettings
    
    if !state.IsActive()
        return
        
    MouseGetPos &currentX, &currentY
    currentTime := A_TickCount
    
    ; Throttle updates: 50ms minimum interval and 5px minimum movement
    if (currentTime - lastUpdate < 50) && (Abs(currentX - lastX) < 5 && Abs(currentY - lastY) < 5)
        return
        
    lastX := currentX, lastY := currentY, lastUpdate := currentTime
    
    ; Check if significant movement occurred
    deltaX := Abs(currentX - state.initialX)
    deltaY := Abs(currentY - state.initialY)
    
    if (deltaX + deltaY > SmallDelta) {
        try {
            state.gui.Show "Hide"
            
            ; Update region based on mouse position
            processname := region.GetProcessName()
            if BorderSettings.Has(processname)
                region.borders := BorderSettings[processname]
            else
                region.borders := BorderSettings["default"]
                
            GetWindowRegionFromMouse(&region)
            state.gui.Show(region.GuiString())
            
            ; Update initial position to current for next comparison
            state.initialX := currentX
            state.initialY := currentY
        } catch Error as err {
            writeLog("[ERROR] Failed to update window selection: " err.Message)
        }
    }
}

_UpdateDragSelection(&state, &region) {
    static lastX := 0, lastY := 0, lastUpdate := 0
    
    if !state.IsActive()
        return
        
    MouseGetPos &currentX, &currentY
    currentTime := A_TickCount
    
    ; Throttle updates: 16ms for ~60fps and 2px minimum movement
    if (currentTime - lastUpdate < 16) && (Abs(currentX - lastX) < 2 && Abs(currentY - lastY) < 2)
        return
        
    lastX := currentX, lastY := currentY, lastUpdate := currentTime
    
    ; Check if drag threshold is exceeded (5px tolerance to distinguish click from drag)
    deltaX := Abs(currentX - state.dragStartX)
    deltaY := Abs(currentY - state.dragStartY)
    
    if (deltaX > 5 || deltaY > 5) {
        ; Mark that we've started dragging
        if (!state.isDragging) {
            state.isDragging := true
            writeLog("[DEBUG] Started dragging - exceeded 5px threshold")
        }
        
        try {
            ; Always use the original dragStartX/dragStartY as the fixed starting point
            region.SetRegionByPos(currentX, currentY, state.dragStartX, state.dragStartY)
            region.MoveGui(state.gui)
        } catch Error as err {
            writeLog("[ERROR] Failed to update drag selection: " err.Message)
        }
    }
}

_HandleAdjustmentKey(key, &region, gui) {
    try {
        switch key {
            case "f":
                region.toggle_content_focus()
            case "s":
                region.change_border("SET")
            case "r":
                region.change_border("RATIO")
            case "t":
                region.change_border("TOP")
            case "w":
                region.change_border("RIGHT")
            case "l":
                region.change_border("LEFT")
            case "h":
                region.change_border("BOTTOM")
            case "e":
                region.change_border("EXTENDED")
        }
        region.moveGui(gui)
    } catch Error as err {
        writeLog("[ERROR] Failed to handle adjustment key '" key "': " err.Message)
    }
}



AdjustConfirmWindow(aGui, &region)  ; todo: continue here
{
    global confirmColor, ConfirmTransparency
    confirmState := 0
    OnMessage(0x201, WM_LBUTTONDOWN) ; https://autohotkey.com/board/topic/61348-how-to-make-this-gui-movable/

    aGui.Opt "+Resize"
    aGui.BackColor := ConfirmColor
    WinSetTransparent ConfirmTransparency, aGui ; todo: can we make the resize title bar transparent?
    aGui.Show region.GuiString()
    WinGetPos &guix, &guiy, &guiw, &guih, aGui
    region.GetRegionRect(,,&vW, &vH)
    offsetX := (guiw - vW)/2, offsetY := (guih - vH)/2
    aGui.Move(guix-offsetX, , ,guih-offsetY) ; guix move for 2*offset width, guih move for 1 offset hight
    WinGetPos &guix1, &guiy1, &guiw1, &guih1, aGui
    Hotkey "*RButton", Confirm_Canceled, "On"
    Hotkey "Esc", Confirm_Canceled, "On"
    while !confirmState
    {
        ; Detect Shift+Enter for continuous capture, Enter for single capture
        if WinActive(aGui) {
            if GetKeyState("Enter") {
                if GetKeyState("Shift") {
                    confirmState := 2 ; Shift+Enter for continuous capture
                    break
                } else {
                    confirmState := 1 ; Enter for single capture
                    break
                }
            }
        }
        sleep 20
    }

    ; Clean up hotkeys (safe to call even if already cleaned up in Confirm_Canceled)
    try {
        Hotkey "*RButton", Confirm_Canceled, "Off"
        writeLog("[DEBUG] AdjustConfirmWindow: RButton hotkey disabled")
    } catch {
        ; Already disabled, ignore
    }
    try {
        Hotkey "Esc", Confirm_Canceled, "Off"
        writeLog("[DEBUG] AdjustConfirmWindow: Esc hotkey disabled")
    } catch {
        ; Already disabled, ignore
    }
    OnMessage(0x201, WM_LBUTTONDOWN, 0)
    
    WinGetPos &guix2, &guiy2, &guiw2, &guih2, aGui
    if (guix1!=guix2 || guiy1!=guiy2 || guiw1!=guiw2 || guih1!=guih2)
        region.SetRegionRect(guix2+offsetX,guiy2,guiw2-2*offsetX,guih2-offsetY)

    aGui.Destroy
    return confirmState

    Confirm_Canceled(ThisHotKey)
    {
        if !confirmState {
            confirmState := -1
            ; Immediately clean up hotkeys to prevent blocking
            try {
                Hotkey "*RButton", Confirm_Canceled, "Off"
                Hotkey "Esc", Confirm_Canceled, "Off"
                writeLog("[DEBUG] AdjustConfirmWindow: Canceled - hotkeys cleaned up immediately")
            } catch Error as err {
                writeLog("[WARNING] AdjustConfirmWindow: Failed to clean up hotkeys: " err.Message)
            }
        }
        return
    }

    WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
        PostMessage 0xA1, 2
    }

}

GetWindowRegionFromMouse(&region)
{
    MouseGetPos &pX, &pY, &overWindowID, &overControlID, 2

    windowClass := WinGetClass("ahk_id " overWindowID)
    if ( windowClass = "WorkerW" || windowClass = "Progman" )
    {
        MonitorGet GetMonitorIndex(), &regionX, &regionY, &regionR, &regionB
        region.setRegionByPos(regionX, regionY, regionR, regionB)
    }
    else
    {
        if (StrLen(overControlID) > 0)
            region.SetWinID(overControlID)
        else
            region.SetWinID(overWindowID)
    }

}

inRegion(pointX, pointY, regionX, regionY, regionW, regionH)
{
    return (pointX >= regionX) && (pointX < regionX + regionW) && (pointY >= regionY) && (pointY < regionY + regionH)
}

GetMonitorIndex(region:=0)
{
    pX := 0, pY := 0
    if region
        region.GetCenter(&pX, &pY)
    if (pX=0 && pY=0)
    {
        MouseGetPos(&pX, &pY)
    }

    mcount := MonitorGetCount()
    Loop mcount
    {
        isExisting := MonitorGet(A_Index, &left, &top, &right, &bottom)

        if inRegion(pX, pY, left, top, right - left, bottom - top)
            return A_Index
    }
    return 0
}

EnsureFolderExists(FolderPath)
{
    result := FileExist(FolderPath)
    if result
    {
        if !InStr(result, "D")
        {
            MsgBox FolderPath " is not a directory, please update it in .config.ini.", "Error", "iconx"
            ExitApp -1
        }
    }
    Else{
        DirCreate(FolderPath)
    }
    if SubStr(FolderPath, -1) != "\"
        FolderPath .= "\"
    return FolderPath
}

global LogQueue := []
global IsLogWorkerRunning := false

writeLog(text)
{
    global LogQueue, IsLogWorkerRunning
    TimeString := FormatTime(A_Now, "yyyy/MM/dd-HH:mm:ss")
    LogQueue.Push({ts: TimeString, msg: text})
    if !IsLogWorkerRunning {
        IsLogWorkerRunning := true
        SetTimer(LogWorker, 1000)
    }
}

LogWorker() {
    global LogQueue, IsLogWorkerRunning, LogPath
    if LogQueue.Length = 0 {
        IsLogWorkerRunning := false
        SetTimer(LogWorker, 0)
        return
    }
    SplitPath(LogPath, ,&OutDir)
    attempts := 0
    maxAttempts := 10
    ; Batch all logs in the queue
    logText := ""
    while LogQueue.Length > 0 {
        entry := LogQueue.RemoveAt(1)
        logText .= entry.ts "`t" A_ComputerName "`t" entry.msg "`n"
    }
    while attempts < maxAttempts {
        try {
            FileAppend logText, LogPath
            break
        } catch Error as err {
            attempts++
            Sleep 100  ; wait 100ms before retry
            if attempts >= maxAttempts {
                writeLog("[ERROR] Failed to write to log after multiple attempts: " err.Message)
                break
            }
        }
    }
    ; Continue timer for next batch
    SetTimer(LogWorker, -LogIntervalMs)
}

FlushLogQueue() {
    global LogQueue, LogPath
    SetTimer(LogWorker, 0)  ; Stop the log worker timer
    if LogQueue.Length = 0
        return
    SplitPath(LogPath, ,&OutDir)
    logText := ""
    while LogQueue.Length > 0 {
        entry := LogQueue.RemoveAt(1)
        logText .= entry.ts "`t" A_ComputerName "`t" entry.msg "`n"
    }
    try {
        FileAppend logText, LogPath
    } catch Error as err {
        writeLog("[ERROR] Failed to flush log queue: " err.Message)
    }
}

selectedRegion := RegionSetting()

; --- Helper for capture and logging ---
CaptureAndLog(region, toClipboard, showConfirm, deduplicate, outputPathTemplate, logPrefix := "Captured", absolutePath := "") {
    ; StartTime := A_TickCount
    basePath := absolutePath != "" ? absolutePath : ScreenshotPath
    sOutput := basePath . FormatTime(A_Now, outputPathTemplate)
    ret := CaptureScreenRegion(&region, sFilename:=sOutput, toClipboard, showConfirm, deduplicate)
    return ret
}

SelectRegionToCapture()
{
    ; Safety: Ensure all capture timers are stopped and no capture is in progress
    global isCaptureContinue
    if isCaptureContinue {
        StopContinuousCapture()
    }
    global isCaptureInProgress
    while isCaptureInProgress
        Sleep 10

    global selectedRegion
    result := SelectRegion(&selectedRegion)
    if (result < 0)
        return
    global captureRegion := selectedRegion.Clone()

    if (result = 2) {
        ; Shift+Enter: start continuous capture
        StartContinuousCapture()
        return
    }
    ; Enter: single capture (default)
    CaptureAndLog(captureRegion, true, true, false, ScreenshotFilenameTemplate)
    return
}

RepeatLastCapture()
{
    if isCaptureContinue {
        DoCapture(immediateCapture:=true)
    }
    else{
        global captureRegion
        if !IsSet(captureRegion)
        {
            MonitorGet GetMonitorIndex(), &captureX, &captureY, &captureR, &captureB
            captureRegion := RegionSetting()
            captureRegion.SetRegionByPos(captureX, captureY, captureR, captureB)
        }
        CaptureAndLog(captureRegion, true, true, false, ScreenshotFilenameTemplate)
    }
    return
}

global isCaptureContinue := false ; if a continuous capture is running
global isCaptureInProgress := false ; if a single capture is running
global lastCaptureBitmap := 0 ; save the last captured bitmap for comparison

global stopGui
global ContinuousCapturePath := "" ; the path to save screenshots

; 比较两个GDI+ Bitmap对象的缩略图相似度. TODO: 需要优化, lastBitmap不用每次都resize，可以存一个thumbnail重复比较
CompareBitmapsByThumbnail(pBitmap1, pBitmap2, thumbW := BitmapCompareThumbnailSize, thumbH := BitmapCompareThumbnailSize, threshold := BitmapCompareThreshold) {
    if !pBitmap1 || !pBitmap2
        return false
    pThumb1 := Gdip_ResizeBitmap(pBitmap1, thumbW, thumbH)
    pThumb2 := Gdip_ResizeBitmap(pBitmap2, thumbW, thumbH)
    arr1 := GetGrayArrayFromBitmap(pThumb1, thumbW, thumbH)
    arr2 := GetGrayArrayFromBitmap(pThumb2, thumbW, thumbH)
    Gdip_DisposeImage(pThumb1), Gdip_DisposeImage(pThumb2)
    diff := 0
    for i, v in arr1
        diff += Abs(v - arr2[i])
    avgDiff := diff / (thumbW * thumbH)
    return avgDiff < threshold 
}

GetGrayArrayFromBitmap(pBitmap, w, h) {
    arr := []
    Loop h {
        y := A_Index - 1
        Loop w {
            x := A_Index - 1
            ARGB := Gdip_GetPixel(pBitmap, x, y)
            r := (ARGB >> 16) & 0xFF
            g := (ARGB >> 8) & 0xFF
            b := ARGB & 0xFF
            gray := (r*0.299 + g*0.587 + b*0.114)
            arr.Push(gray)
        }
    }
    return arr
}


DoCapture(immediateCapture := false) {
    global isCaptureContinue, captureRegion, CaptureCount, ContinuousCapturePath, ScreenshotFilenameTemplate, stopGui, captureIntervalMs, isCaptureInProgress, ShowConfirmOnContinuousCapture

    static prev_win_id := 0
    ; Stop continuous capture if win_id transitions from nonzero to zero (any process)
    if (prev_win_id != 0 && captureRegion.win_id = 0) {
        writeLog("Session ended (win_id=0), stopping continuous capture.")
        StopContinuousCapture()
        prev_win_id := 0
        return
    }
    prev_win_id := captureRegion.win_id

    if !isCaptureContinue {
        StopContinuousCapture() ; Ensure cleanup if capture is stopped
        return
    }
    if isCaptureInProgress {
        ; Skip this tick if a capture is already running
        return
    }
    isCaptureInProgress := true
    startTick := A_TickCount
    try {
        ; Check if we can capture:
        ; - If no win_id: free screen region (always valid)
        ; - If has win_id: check if window region is valid
        if (!captureRegion.win_id || captureRegion.check_win_id()) {
            CaptureCount += 1
            outputTemplate := ScreenshotFilenameTemplate_Continuous . Format("_{:05}.png",CaptureCount)
            CaptureAndLog(captureRegion, toClipboard:=false, showConfirm:=ShowConfirmOnContinuousCapture, deduplicate:=!immediateCapture, outputPathTemplate:=outputTemplate, logPrefix:="Captured", absolutePath:=ContinuousCapturePath)
        }
    } finally {
        isCaptureInProgress := false
    }
    elapsed := A_TickCount - startTick
    nextInterval := captureIntervalMs - elapsed
    if (nextInterval < 1)
        nextInterval := 1
    SetTimer(DoCapture, -nextInterval)
}

StartContinuousCapture()
{
    global captureRegion, isCaptureContinue, stopGui, lastBitmap
    if isCaptureContinue {
        StopContinuousCapture()
    }
    if lastBitmap {
        Gdip_DisposeImage(lastBitmap)
        lastBitmap := 0
    }
    isCaptureContinue := true
    if !IsSet(captureRegion)
    {
        MonitorGet GetMonitorIndex(), &captureX, &captureY, &captureR, &captureB
        captureRegion := RegionSetting()
        captureRegion.SetRegionByPos(captureX, captureY, captureR, captureB)
    }
    global CaptureCount := 0
    global IsShowStopCaptureUI
    if IsShowStopCaptureUI
        stopGui := ShowStopCaptureUI()
    global ContinuousCapturePath := EnsureFolderExists(ScreenshotPath . FormatTime(A_Now, ScreenshotFolderTemplate))
    SetTimer(DoCapture, -10) ; fire first capture immediately
    return
}

ShowStopCaptureUI()
{
    global isCaptureContinue

    btnWidth := 140, btnHeight := 40
    padding := 24
    spacing := 10

    guiWidth := btnWidth + 2 * padding
    guiHeight := btnHeight * 2 + spacing + 2 * padding

    guiTransparency := 128

    stopGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound -DPIScale")
    stopGui.SetFont("s10 c0x888888 bold", "Segoe UI")
    y := padding
    x := padding

    btnCaptureExit := stopGui.Add("Button", "x" x " y" y " w" btnWidth " h" btnHeight, "Exit Capture")
    btnCaptureExit.OnEvent("Click", (*) => StopContinuousCapture())

    ; Add second button for immediate capture
    y := y + btnHeight + spacing
    btnCaptureNow := stopGui.Add("Button", "x" x " y" y " w" btnWidth " h" btnHeight, "Capture Now")
    btnCaptureNow.OnEvent("Click", (*) => DoCapture(true))

    ; 允许拖动整个窗口
    OnMessage(0x201, WM_LBUTTONDOWN)

    x := A_ScreenWidth - guiWidth - 60
    y := A_ScreenHeight - guiHeight - 200
    stopGui.Show("x" x " y" y " w" guiWidth " h" guiHeight)
    WinSetTransparent(guiTransparency, stopGui)
    return stopGui
}

StopContinuousCapture() {
    global isCaptureContinue, stopGui
    isCaptureContinue := false
    SetTimer(DoCapture, 0)
    if IsSet(stopGui) && stopGui {
        stopGui.Destroy()
        stopGui := ''
    }
    OnMessage(0x201, WM_LBUTTONDOWN, 0) ; Remove message handler
}

; --- Top-level WM_LBUTTONDOWN handler for draggable GUIs ---
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    PostMessage 0xA1, 2
}