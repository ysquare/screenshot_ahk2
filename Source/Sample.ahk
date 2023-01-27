#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
#Include .\Screenshot_v2.ahk

GetConfig(ConfigFilePath)

;==================================================
;  take screen shot
;==================================================

selectedRegion := RegionSetting()

^#+r::
{
    global selectedRegion, captureRegion
    if (SelectRegion(&selectedRegion) < 0)
		return
    global captureRegion := selectedRegion.Clone()

    StartTime := A_TickCount
    sOutput := ScreenshotPath . FormatTime(A_Now, ScreenshotFilenameTemplate)
    CaptureScreenRegion(&captureRegion, sFilename:=sOutput, toClipboard:=true)
    return
}

^#r::
{
    global captureRegion
	if !IsSet(captureRegion)
    {
        MonitorGet GetMonitorIndex(), &captureX, &captureY, &captureR, &captureB
        captureRegion := RegionSetting()
        captureRegion.SetRegionByPos(captureX, captureY, captureR, captureB)
    }

    StartTime := A_TickCount
    sOutput := ScreenshotPath . FormatTime(A_Now, ScreenshotFilenameTemplate)
    CaptureScreenRegion(&captureRegion, sFilename:=sOutput, toClipboard:=true)
    return
}

