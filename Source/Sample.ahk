#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
#Include .\Screenshot_v2.ahk

;==================================================
;  take screen shot
;==================================================

^#+r::
{
    SelectRegionToCapture()
}

^#r::
{
    RepeatLastCapture()
}

^#t::
{
    ContinuousCapture()
}

^#+t::
{
    StopContinuousCapture()
}
