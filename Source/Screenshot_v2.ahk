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
SnapshotFlashDuration := 100 ;milliseconds
SnapshotFlashTransparency := 128    ; 0-255
ScreenshotFilenameTemplate := "Screen yyyyMMdd-HHmmss.png"
ScreenshotFilenameTemplate_Continuous := "Screen yyyyMMdd_HHmmss"
SmallDelta := 10  ; the smallest screenshot that can be taken is 10x10 by pixel

captureIntervalMs := 1000 ; Default interval in milliseconds, if not overridden by .config.ini, set it to 1s.
BitmapCompareThreshold := 1 ; the threshold for bitmap comparison, typically between 1 and 10, can be float number
BitmapCompareThumbnailSize := 8 ; the size of the thumbnail for bitmap comparison

GetConfig(A_ScriptDir "\.config.ini")
GetConfig(configFile)
{
    Try
    {
        global LogPath := A_WorkingDir "\" IniRead(configFile , "Path" , "LogPath")
        global ScreenshotPath := IniRead(configFile, "Path", "ScreenshotPath")
        global captureIntervalMs := IniRead(configFile, "Path", "captureIntervalMs")
        global BitmapCompareThreshold := IniRead(configFile, "Path", "BitmapCompareThreshold")
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
global lastBitmap := 0

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
    if IsSet(lastBitmap) && lastBitmap {
        Gdip_DisposeImage(lastBitmap)
        lastBitmap := 0
    }
    if g_pToken {
        Gdip_Shutdown(g_pToken)
        g_pToken := 0
    }
}

CaptureScreenRegion(&region, sFilename:="", toClipboard:=False, showConfirm:=true, deduplicate:=false)
{
    global lastBitmap
    if ( sFilename!="" || toClipboard )  ; either of the options should be true to proceed
    {
        monitor_index := GetMonitorIndex(region)  ; todo: change GetMonitorIndex()
        if monitor_index > 0  ; only do capture when window is in normal status, not when it's minimized or hidden
        {
            ; GDI+ is already started globally
            pBitmap := Gdip_BitmapFromScreen(region.ScreenString(), 0x40cc0020) ; always getting bitmap from screen, not from window
            if deduplicate && (lastBitmap != 0) && CompareBitmapsByThumbnail(pBitmap, lastBitmap) {
                Gdip_DisposeImage(pBitmap)
                return 0 ; skip save, duplicate
            }
            if toClipboard
                Gdip_SetBitmapToClipboard(pBitmap)
            if sFilename
                Gdip_SaveBitmapToFile(pBitmap, updateFilename(&sFilename))

            if lastBitmap {
                Gdip_DisposeImage(lastBitmap)
                lastBitmap := 0
            }
            if !pBitmap || pBitmap = -1
            {
                MsgBox "Failed to capture screen! pBitmap is invalid."
                return 0
            }
            width := Gdip_GetImageWidth(pBitmap)
            height := Gdip_GetImageHeight(pBitmap)
            lastBitmap := Gdip_CloneBitmapArea(pBitmap, 0, 0, width, height)

            Gdip_DisposeImage(pBitmap)

            ; display a confirmation splash if screenshot succeeds
            if showConfirm && FileExist(sFilename)
                ShowRegion(region)
            return 1 ; indicate saved
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

ShowRegion(region)
{
    global SnapshotFlashColor, SnapshotFlashTransparency, SnapshotFlashDuration
    DetectHiddenWindows True
    MyGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound -DPIScale")
    MyGui.BackColor := SnapshotFlashColor
    WinSetTransparent(SnapshotFlashTransparency, MyGui)
    MyGui.Show region.GuiString()
    Sleep SnapshotFlashDuration
    MyGui.Destroy
}

SelectRegion(&region)
{
    global SelectionColor, SelectionTransparency
    CoordMode "Mouse", "Screen"

    selectState := 0   ; selectState 0 - waiting to select; -1 - canceled; 1 - ready to proceed
    DetectHiddenWindows True
    myGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound -DPIScale")
	myGui.BackColor := SelectionColor
	WinSetTransparent SelectionTransparency, myGui

    Hotkey "*RButton", SelectRegion_Canceled, "On" ; * meaning the right button click happening with any other key down.
    Hotkey "Esc", SelectRegion_Canceled, "On"

    ; before selecting windowClass
    region.check_win_id()  ; windows could have been closed, thus need another check
    MyGui.Show(region.GuiString())
    
    if region.IsSet()  ; todo: this code does not work
    {
        region.GetCenter(&vX0, &vY0)
        MouseMove(vX0, vY0)
    }

    ; globally, selectState means the status: 0 - stay in current state, 1 - should go to the next state, -1: user canceled
    ; here during window selection, selectState: 0 - selecting windows, 1 - mouse down, -1 - canceled (ESC or right click)
    Hotkey "f", SelectWindow_PresetUpdate, "On"  ; toggle content focus
    Hotkey "s", SelectWindow_PresetUpdate, "On"  ; adjusting the whole set
    Hotkey "r", SelectWindow_PresetUpdate, "On"  ; adjusting ratio
    Hotkey "e", SelectWindow_PresetUpdate, "On"  ; adjusting extended cut
    Hotkey "t", SelectWindow_PresetUpdate, "On"  ; adjusting top only
    Hotkey "w", SelectWindow_PresetUpdate, "On"  ; adjusting width only
    Hotkey "l", SelectWindow_PresetUpdate, "On"  ; adjusting left only
    Hotkey "h", SelectWindow_PresetUpdate, "On"  ; adjusting hight only

    ; Preset_updated := False ; True if a preset update (boundary or aspect ratio) is applied
    SetTimer(SelectWindow_Update, 250)
    While !selectState   ; mouse click or ESC/right click to get out of the cycle
    {
        if GetKeyState("LButton")
        {
            selectState := 1
            break
        }
        Sleep 10
    }
    SetTimer(SelectWindow_Update, 0)
    Hotkey "f", SelectWindow_PresetUpdate, "Off"
    Hotkey "s", SelectWindow_PresetUpdate, "Off"
    Hotkey "r", SelectWindow_PresetUpdate, "Off"
    Hotkey "e", SelectWindow_PresetUpdate, "Off"
    Hotkey "t", SelectWindow_PresetUpdate, "Off"
    Hotkey "w", SelectWindow_PresetUpdate, "Off"
    Hotkey "l", SelectWindow_PresetUpdate, "Off"
    Hotkey "h", SelectWindow_PresetUpdate, "Off"

    if (selectState = -1)   ; user cancaled during window selection (didn't click down button and escaped)
        Goto TearingDown

    ; selectState: 0 - dragging with mouse LButton down, 1 - mouse LButton up, -1 - canceled (ESC or right click)
    selectState := 0
  
    SetTimer(RegionDrag_Update, 10)
    While !selectState
    {
        if !GetKeyState("LButton")
        {
            selectState := 1
            break
        }
        Sleep 20
    }
    SetTimer(RegionDrag_Update, 0)

    if (selectState = -1)  ; user cancels when dragging (escaped before click button up)
        Goto TearingDown

    selectState := AdjustConfirmWindow(myGui, &region)

TearingDown:
    Hotkey "Esc", SelectRegion_Canceled, "Off"
    Hotkey "*RButton", SelectRegion_Canceled, "Off"
	MyGui.Destroy
	return selectState

    SelectWindow_Update()
    {
        if !selectState
        {
            MouseGetPos &vX, &vY
            if (!IsSet(vX0) || !IsSet(Vy0) || (vX!=vX0 or vY!=vY0))
            {
                myGui.Show "Hide"

                processname := region.GetProcessName()
                if BorderSettings.Has(processname)
                    region.borders := BorderSettings[processname]
                else
                    region.borders := BorderSettings["default"]

                GetWindowRegionFromMouse(&region)
                myGui.Show(region.GuiString())
                vX0 := vX, vY0 := vY
            }
        }
    }

    SelectWindow_PresetUpdate(ThisHotkey)
    {
        if (ThisHotKey = "f")
            region.toggle_content_focus()
        else if (ThisHotKey = "s")
            region.change_border("SET")
        else if (ThisHotKey = "r")
            region.change_border("RATIO")
        else if (ThisHotKey = "t")
            region.change_border("TOP")
        else if (ThisHotKey = "w")
            region.change_border("RIGHT")
        else if (ThisHotkey = "l")
            region.change_border("LEFT")
        else if (ThisHotkey = "h")
            region.change_border("BOTTOM")
        else if (ThisHotkey = "e")
            region.change_border("EXTENDED") ; extend the region to the next ratio
        region.moveGui(myGui)

    }

    RegionDrag_Update()
    {
        if !selectState
        {
            MouseGetPos &vX, &vY
            if (abs(vX-vX0)>SmallDelta and (abs(vY-vY0)>SmallDelta))
            {
                ; todo: will the following 2 lines too slow for region drag?
                region.SetRegionByPos(vX, vY, vX0, vY0)
                region.MoveGui(myGui)
            }
        }
    }

    SelectRegion_Canceled(ThisHotKey)
    {
        if !selectState
            selectState := -1
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
        if WinActive(aGui) && GetKeyState("Enter")
        {
            confirmState := 1
            break
        }
        sleep 20
    }

    Hotkey "*RButton", Confirm_Canceled, "Off"
    Hotkey "Esc", Confirm_Canceled, "Off"
    OnMessage(0x201, WM_LBUTTONDOWN, 0)
    
    WinGetPos &guix2, &guiy2, &guiw2, &guih2, aGui
    if (guix1!=guix2 || guiy1!=guiy2 || guiw1!=guiw2 || guih1!=guih2)
        region.SetRegionRect(guix2+offsetX,guiy2,guiw2-2*offsetX,guih2-offsetY)

    aGui.Destroy
    return confirmState

    Confirm_Canceled(ThisHotKey)
    {
        if !confirmState
        confirmState := -1
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

writeLog(text)
{
    global LogPath
    SplitPath(LogPath, ,&OutDir)
    EnsureFolderExists(OutDir)
    TimeString := FormatTime(A_Now, "yyyy/MM/dd-HH:mm:ss")
    FileAppend TimeString "`t" A_ComputerName "`t" text "`n", LogPath
}

selectedRegion := RegionSetting()

SelectRegionToCapture()
{
    global selectedRegion
    if (SelectRegion(&selectedRegion) < 0)
		return
    global captureRegion := selectedRegion.Clone()

    StartTime := A_TickCount
    sOutput := EnsureFolderExists(ScreenshotPath) . FormatTime(A_Now, ScreenshotFilenameTemplate)
    CaptureScreenRegion(&captureRegion, sFilename:=sOutput, toClipboard:=true, showConfirm:=true)
    writeLog "Captured to " sOutput " (" captureRegion.ScreenString() ") in " A_TickCount-StartTime "ms."
    return

}

RepeatLastCapture()
{
    global captureRegion
	if !IsSet(captureRegion)
    {
        MonitorGet GetMonitorIndex(), &captureX, &captureY, &captureR, &captureB
        captureRegion := RegionSetting()
        captureRegion.SetRegionByPos(captureX, captureY, captureR, captureB)
    }

    StartTime := A_TickCount
    sOutput := EnsureFolderExists(ScreenshotPath) . FormatTime(A_Now, ScreenshotFilenameTemplate)
    CaptureScreenRegion(&captureRegion, sFilename:=sOutput, toClipboard:=true, showConfirm:=true)
    writeLog "Captured to " sOutput " (" captureRegion.ScreenString() ") in " A_TickCount-StartTime "ms."
    return
}

global isCaptureContinue := false ; if a continuous capture is running
global isCaptureInProgress := false ; if a single capture is running
global captureTimerActive := false ; if a capture timer is active
global lastCaptureBitmap := 0 ; save the last captured bitmap for comparison

global stopGui
global Path := "" ; the path to save screenshots

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
    global isCaptureContinue, captureRegion, CaptureCount, Path, ScreenshotFilenameTemplate, stopGui, captureIntervalMs, sOutput, captureTimerActive, isCaptureInProgress
    if !isCaptureContinue {
        SetTimer(DoCapture, 0)
        captureTimerActive := false
        return
    }
    if isCaptureInProgress {
        ; Skip this tick if a capture is already running
        return
    }
    isCaptureInProgress := true
    try {
        CaptureCount += 1
        sOutput := Path . FormatTime(A_Now, ScreenshotFilenameTemplate) . Format("_{:05}.png", CaptureCount)
        ret := CaptureScreenRegion(&captureRegion, sFilename:=sOutput, toClipboard:=false, showConfirm:= true, deduplicate:=!immediateCapture)
        if ret {
            logMessage := immediateCapture ? "Immediate capture " : "Captured "
            writeLog logMessage CaptureCount " Screenshots to " sOutput " (" captureRegion.ScreenString() ")"
        }
    } finally {
        isCaptureInProgress := false
    }
    SetTimer(DoCapture, -captureIntervalMs)
}

ContinuousCapture()
{
    global captureRegion, isCaptureContinue, stopGui, lastBitmap
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

    StartTime := A_TickCount
    global CaptureCount := 0
    stopGui := ShowStopCaptureUI()
    global Path := EnsureFolderExists(ScreenshotPath . FormatTime(A_Now, ScreenshotFilenameTemplate_Continuous))
    global sOutput

    global captureTimerActive := true
    SetTimer(DoCapture, -10) ; fire first capture immediately

    while(isCaptureContinue)
        Sleep 100
    SetTimer(DoCapture, 0)
    captureTimerActive := false
    if IsSet(stopGui)
        stopGui.Destroy
    writeLog "Captured " CaptureCount " Screenshots to " sOutput " (" captureRegion.ScreenString() ") in " A_TickCount-StartTime "ms."
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
    btnCaptureExit.OnEvent("Click", (*) => StopContinuousCapture(stopGui))

    ; Add second button for immediate capture
    y := y + btnHeight + spacing
    btnCaptureNow := stopGui.Add("Button", "x" x " y" y " w" btnWidth " h" btnHeight, "Capture Now")
    btnCaptureNow.OnEvent("Click", (*) => (
        ; SetTimer(DoCapture, 0), ; Delete the timer
        DoCapture(true)                ; Call DoCapture with true
    ))

    ; 允许拖动整个窗口
    OnMessage(0x201, WM_LBUTTONDOWN)
    WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
        PostMessage 0xA1, 2
    }

    x := A_ScreenWidth - guiWidth - 60
    y := A_ScreenHeight - guiHeight - 200
    stopGui.Show("x" x " y" y " w" guiWidth " h" guiHeight)
    WinSetTransparent(guiTransparency, stopGui)
    return stopGui
}

StopContinuousCapture(stopGui?)
{
    global isCaptureContinue
    isCaptureContinue := false
    if IsSet(stopGui) && stopGui
        stopGui.Destroy()
}