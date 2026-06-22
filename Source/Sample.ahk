#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
#Include .\Screenshot_v2.ahk

; Buffer hotkey presses instead of dropping them when the per-hotkey thread limit
; is hit (default is Off). Helps during continuous-capture main-thread load.
#MaxThreadsBuffer On

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
    StartContinuousCapture()
}

^#+t::
{
    StopContinuousCapture()
}
