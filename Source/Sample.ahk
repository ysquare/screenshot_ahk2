#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
#Include .\Screenshot_v2.ahk

;==================================================
;  take screen shot
;==================================================

selectedRegion := RegionSetting()

^#+r::
{
    SelectRegionToCapture()
}

^#r::
{
    RepeatLastCapture()
}

