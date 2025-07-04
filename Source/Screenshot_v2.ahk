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
GetConfig(A_ScriptDir "\.config.ini")
is_Capture_Continue := false

GetConfig(configFile)
{
    Try
    {
        global LogPath := A_WorkingDir "\" IniRead(configFile , "Path" , "LogPath")
        global ScreenshotPath := IniRead(configFile, "Path", "ScreenshotPath")

    } Catch Error as err
    {
        MsgBox "Error Getting Configuartion, please check", "Error", "iconx"
        ExitApp -1
    }
}

; ==============================================================================
global captureX,captureY,captureR,captureB
global selectX, selectY, selectR, selectB
CoordMode "Mouse", "Screen"
DetectHiddenWindows True

CaptureScreenRegion(&region, sFilename:="",toClipboard:=False,showConfirm:=true)
{
    if ( sFilename!="" || toClipboard )  ; either of the options should be true to proceed
    {
        monitor_index := GetMonitorIndex(region)  ; todo: change GetMonitorIndex()
        if monitor_index > 0  ; only do capture when window is in normal status, not when it's minimized or hidden
        {
            ; start GDI and do the screen capture
            pToken := Gdip_Startup()
            if !pToken
            {
                MsgBox "Gdip_Startup error, exiting the app", "Error", "iconx"
                ExitApp 1
            }

            pBitmap := Gdip_BitmapFromScreen(region.ScreenString(), 0x40cc0020) ; always getting bitmap from screen, not from window
            if toClipboard
                Gdip_SetBitmapToClipboard(pBitmap)
            if sFilename
                Gdip_SaveBitmapToFile(pBitmap, updateFilename(&sFilename))

            DeleteObject(pBitmap)
            Gdip_DisposeImage(pBitmap)
            Gdip_Shutdown(pToken)

            ; display a confirmation splash if screenshot succeeds
            if showConfirm && FileExist(sFilename)
                ShowRegion(region)
        }
    }
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
    global selectedRegion, captureRegion
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

global captureIntervalMs := 1000 ; Default interval in milliseconds
global captureTimerActive := false

global stopGui

global Path := ""

DoCapture(*) {
    global is_Capture_Continue, captureRegion, CaptureCount, Path, ScreenshotFilenameTemplate, stopGui, captureIntervalMs, sOutput, captureTimerActive
    if !is_Capture_Continue {
        SetTimer(DoCapture, 0)
        captureTimerActive := false
        return
    }
    CaptureCount += 1
    sOutput := Path . FormatTime(A_Now, ScreenshotFilenameTemplate) . Format("_{:05}.png", CaptureCount)
    CaptureScreenRegion(&captureRegion, sFilename:=sOutput, toClipboard:=false, 
        showConfirm:= true || (CaptureCount <=3) || mod(CaptureCount, 60) = 0)
    writeLog "Captured " CaptureCount " Screenshots to " sOutput " (" captureRegion.ScreenString() ")"
    SetTimer(DoCapture, -captureIntervalMs)
}

ContinuousCapture()
{
    global captureRegion, is_Capture_Continue, captureIntervalMs, stopGui
    is_Capture_Continue := true
    if !IsSet(captureRegion)
    {
        MonitorGet GetMonitorIndex(), &captureX, &captureY, &captureR, &captureB
        captureRegion := RegionSetting()
        captureRegion.SetRegionByPos(captureX, captureY, captureR, captureB)
    }

    StartTime := A_TickCount
    global CaptureCount := 0
    stopGui := ShowStopCaptureButton()
    global Path := EnsureFolderExists(ScreenshotPath . FormatTime(A_Now, ScreenshotFilenameTemplate_Continuous))
    global sOutput

    global captureTimerActive := true
    SetTimer(DoCapture, -10) ; fire first capture immediately

    while(is_Capture_Continue)
        Sleep 100
    SetTimer(DoCapture, 0)
    captureTimerActive := false
    if IsSet(stopGui)
        stopGui.Destroy
    writeLog "Captured " CaptureCount " Screenshots to " sOutput " (" captureRegion.ScreenString() ") in " A_TickCount-StartTime "ms."
    return
}

ShowStopCaptureButton()
{
    global is_Capture_Continue
    global captureIntervalMs
    if (!IsSet(captureIntervalMs) || !captureIntervalMs)
        captureIntervalMs := 1000  ; 默认值

    btnWidth := 160, btnHeight := 40
    padding := 30
    sliderWidth := 260
    labelHeight := 24
    sliderHeight := 32
    spacing := 16
    guiWidth := Max(btnWidth, sliderWidth) + 2 * padding
    guiHeight := btnHeight + labelHeight + sliderHeight + 3 * spacing + 2 * padding
    btnText := "Exit Capture"
    btnTransparency := 64

    ; 指数滑动参数
    minInterval := 100
    maxInterval := 300000
    sliderMin := 0
    sliderMax := 100
    ; 根据当前interval算初始slider位置
    sliderPos := Round((Log(captureIntervalMs/minInterval)/Log(maxInterval/minInterval)) * (sliderMax - sliderMin) + sliderMin)
    if sliderPos < sliderMin
        sliderPos := sliderMin
    if sliderPos > sliderMax
        sliderPos := sliderMax

    stopGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound -DPIScale")
    stopGui.SetFont("s12 c0x888888 bold", "Segoe UI")
    y := padding
    btn := stopGui.Add("Button", "x" padding " y" y " w" btnWidth " h" btnHeight, btnText)
    btn.OnEvent("Click", (*) => StopContinuousCapture(stopGui))

    y += btnHeight + spacing
    stopGui.SetFont("s10", "Segoe UI")
    intervalText := stopGui.Add("Text", "x" padding " y" y " w" sliderWidth " h" labelHeight, "Interval (ms):")

    y += labelHeight + spacing // 2
    slider := stopGui.Add("Slider", "x" padding " y" y " w" sliderWidth " h" sliderHeight " Range" sliderMin "-" sliderMax " ToolTip vIntervalSlider", sliderPos)

    y += sliderHeight + spacing // 2
    intervalLabel := stopGui.Add("Text", "x" padding " y" y " w" sliderWidth " h" labelHeight " vIntervalLabel", Format("{:0.2f} s", captureIntervalMs / 1000))

    slider.OnEvent("Change", (ctrl, *) => (
        captureIntervalMs := Round(minInterval * ((maxInterval/minInterval) ** ((ctrl.Value - sliderMin) / (sliderMax - sliderMin)))),
        stopGui["IntervalLabel"].Text := Format("{:0.2f} s", captureIntervalMs / 1000),
        ; Reset timer and fire capture immediately if timer is active
        (captureTimerActive ? (SetTimer(DoCapture, 0), DoCapture()) : "")
    ))

    ; 允许拖动整个窗口
    OnMessage(0x201, WM_LBUTTONDOWN)
    WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
        PostMessage 0xA1, 2
    }

    x := A_ScreenWidth - guiWidth - 60
    y := A_ScreenHeight - guiHeight - 200
    stopGui.Show("x" x " y" y " w" guiWidth " h" guiHeight)
    WinSetTransparent(btnTransparency, stopGui)
    return stopGui
}

StopContinuousCapture(stopGui?)
{
    global is_Capture_Continue
    is_Capture_Continue := false
    if IsSet(stopGui) && stopGui
        stopGui.Destroy()
}