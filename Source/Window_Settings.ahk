#Requires AutoHotkey v2.0
#include Lib/UIA.ahk
#include Lib/UIA_Browser.ahk


Class CyclicArray
{
    current_index := 0

    __New(params*)
    {
        this.elements := params
    }

    get_current()
    {
        return this.elements[this.current_index+1]
    }

    current_move_next()
    {
        current := this.get_current()
        if (len := this.elements.Length) > 1
            this.current_index := mod(this.current_index+1, len)
        return current
    }

    reset()
    {
        this.current_index := 0
    }

}

; declaring the default settings here so objects can be reused
default_settings := CyclicArray({l:0, t:0, r:0, b:0, ratio:0, extended_cut:0})
default_ratios := CyclicArray(9/16, 10/16, 3/4, 0) ; ratio=0 means original ratio
default_tops := CyclicArray(0)
default_rights := CyclicArray(0)
default_lefts := CyclicArray(0)
default_bottoms := CyclicArray(0)
default_extended_cut := CyclicArray(1, 0)


Class BorderSetting
{
    setting_index := 0  ; zero based
    current_setting := {l:0, t:0, r:0, b:0, ratio:0, extended_cut:0}
    
    settings := default_settings
    ratios := default_ratios
    tops := default_tops
    rights := default_rights
    lefts := default_lefts
    bottoms := default_bottoms
    extended_cut := default_extended_cut

    get_next_setting(&left_border, &top_border, &right_border, &bottom_border, &aspect_ratio, &extended_cut)
    {
        ; notice: cannot assign setting in set to current_setting directly
        ; otherwise the setting in global set will be altered by ratio/t/r/l/b operations
        current_setting := this.settings.current_move_next()
        left_border := current_setting.l
        top_border := current_setting.t
        right_border := current_setting.r
        bottom_border := current_setting.b
        aspect_ratio := current_setting.ratio
        extended_cut := current_setting.extended_cut
    }

    get_ratio()
    {
        return this.ratios.current_move_next()
    }

    get_left()
    {
        return this.lefts.current_move_next()
    }
    get_top()
    {
        return this.tops.current_move_next()
    }
    get_right()
    {
        return this.rights.current_move_next()
    }
    get_bottom()
    {
        return this.bottoms.current_move_next()
    }

    get_extended_cut()
    {
        return this.extended_cut.current_move_next()
    }
    
    reset()
    {
        this.settings.reset(), this.ratios.reset()
        this.lefts.reset(), this.tops.reset(), this.rights.reset(), this.bottoms.reset()
        return this
    }


}

DefaultBorder := BorderSetting()
DefaultBorder.settings := CyclicArray(
    {l:8, t:0, r:8, b:8, ratio:0, extended_cut:0},
    {l:0, t:0, r:0, b:0, ratio:0, extended_cut:0}
)

zoom := BorderSetting()
zoom.settings := CyclicArray(
    {l:0, t:0, r:0, b:80, ratio:0, extended_cut:0},
    {l:0, t:0, r:0, b:0, ratio:0, extended_cut:0}   
)

teams := BorderSetting()
teams.settings := CyclicArray(
    {l:3, t:4, r:2, b:3, ratio:0, extended_cut:0},
    {l:0, t:0, r:0, b:0, ratio:0, extended_cut:0}
)
teams.tops := CyclicArray(98, 156, 300, 359, 0)
teams.rights := CyclicArray(382, 494, 0)

wemeet := BorderSetting()
wemeet.settings := CyclicArray(
    {l:21, t:20, r:21, b:21, ratio:0, extended_cut:0},
    {l:0, t:0, r:0, b:0, ratio:0, extended_cut:0}
)

lync := BorderSetting()
lync.settings := CyclicArray(
    {l:5, t:3, r:5, b:3, ratio:0, extended_cut:0},
    {l:5, t:5, r:5, b:5, ratio:0, extended_cut:0},
    {l:0, t:0, r:0, b:0, ratio:0, extended_cut:0}
)

explorer := BorderSetting()
explorer.settings := CyclicArray(
    {l:8, t:0, r:8, b:8, ratio:0, extended_cut:0},
    {l:10, t:10, r:10, b: 10, ratio: 0, extended_cut:0},
    {l:30, t:10, r:50, b: 50, ratio: 0, extended_cut:0},
    {l:0, t:0, r:0, b:0, ratio:0, extended_cut:0}
)
explorer.tops := CyclicArray(10,20,30,0)
explorer.lefts := CyclicArray(10,20,30,0)
explorer.rights := CyclicArray(10,20,30,0)
explorer.bottoms := CyclicArray(10,20,30,0)


BorderSettings := Map()
BorderSettings["default"] := DefaultBorder ; this should always exist
BorderSettings["Zoom.exe"] := zoom
BorderSettings["Teams.exe"] := teams
BorderSettings["ms-teams.exe"] := teams
BorderSettings["msedgewebview2.exe"] := teams
BorderSettings["WeMeetApp.exe"] := wemeet
BorderSettings["lync.exe"] := lync
BorderSettings["explorer.exe"] := explorer

Class RegionSetting
{
    win_id  := 0
    left    := 0
    top     := 0
    right   := 0
    bottom  := 0

    is_focus_content := false
    focus_content_element := "" ; the element with Name "共享内容视图"
    focus_win_id := 0

    borders := BorderSettings["default"]
    left_border     := 0
    top_border      := 0
    right_border    := 0
    bottom_border   := 0
    aspect_ratio    := 0
    extended_cut    := 0
    
    Static adjustAspectRatio(&x, &y, &w, &h, target_h_w_ratio, extended_cut)  ;h/w ratio is easier wholy divided
    {
        if ( target_h_w_ratio <= 0 || h*w = 0)
            return
        ratio := h/w
        if (ratio > target_h_w_ratio) ; 如果高宽比大于目标高宽比，则裁剪高度
        {
            h_new := w * target_h_w_ratio
            y += Round((h - h_new) / 2)
            h := Round(h_new)
            if (extended_cut = 1) ; 如果开启扩展裁剪，则在裁剪高度的基础上进一步裁剪宽度，将9/16和10/16的屏横向适配到3/4
            {
                w_new := Round(h_new * 4/3)
                x += Round((w - w_new) / 2)
                w := Round(w_new)
            }
        }
        Else if (ratio < target_h_w_ratio) ; 如果高宽比小于目标高宽比，则裁剪宽度
        {
            w_new := h / target_h_w_ratio
            x += Round((w - w_new) / 2)
            w := Round(w_new)
            if (extended_cut = 1) ; 如果开启扩展裁剪，则在裁剪宽度的基础上进一步裁剪高度，将10/16和3/4的屏纵向适配到9/16
            {
                h_new := Round(w_new * 9/16)
                y += Round((h - h_new) / 2)
                h := Round(h_new)
            }
        }
    }

    isSet()
    {
        return (this.top != this.bottom && this.left != this.right)
    }

    GetRegionRect(&OutX:=0, &OutY:=0, &OutWidth:=0, &OutHeight:=0)
    {
        this.check_win_id()
        OutX := this.left + this.left_border
        OutY := this.top + this.top_border
        OutWidth := this.right - this.right_border - OutX
        OutHeight := this.bottom - this.bottom_border - OutY
        
        RegionSetting.adjustAspectRatio(&OutX, &OutY, &OutWidth, &OutHeight, this.aspect_ratio, this.extended_cut)

        return (OutWidth>0 && OutHeight>0)
    }

    SetRegionRect(x, y, w, h)
    {
        this.GetRegionRect(&x0, &y0, &w0, &h0)

        if ( x0!=x || y0!=y || w0!=w || h0!=h)
        {
            this.reset_borders()
            this.win_id := 0
            this.left := x
            this.top := y
            this.right := x + w
            this.bottom := y + h
        }
    }

    SetRegionByPos(x1, y1, x2, y2)
    {
        x10:=this.left,y10:=this.top,x20:=this.right,y20:=this.bottom
        (x1 < x2) ? (this.left := x1, this.right := x2) : (this.left := x2, this.right := x1)
        (y1 < y2) ? (this.top := y1, this.bottom := y2) : (this.top := y2, this.bottom := y1)
        if (this.left!=x10 || this.right!=x20 || this.top!=y10 || this.bottom!=y20)
        {
            this.reset_borders()
            this.win_id := 0
        }
    }

    SetWinID(win_id)
    {
        if (this.win_id != win_id)
        {
            this.win_id := win_id
            this.check_win_id()
            this.reset_borders()
        }
    }

    check_win_id() ; sync win_id to region positions
    {
        if this.win_id = 0
            return true  ; No window to track, free screen region is always valid
        Try
        {
            if (this.is_focus_content && this.focus_win_id = this.win_id)
            {
                focusTick := A_TickCount  ; UIA reads can spike and starve the keyboard hook
                ; The cached UIA element can be missing ("") or have a collapsed
                ; rect when Teams changes its sharing layout. Refresh it; if it is
                ; still unusable, drop focus and fall back to the window rect so
                ; the overlay keeps tracking instead of freezing.
                if !IsObject(this.focus_content_element)
                    this.get_focus_content_element()
                rect := 0
                if IsObject(this.focus_content_element)
                {
                    try rect := this.focus_content_element.BoundingRectangle
                    if (!IsObject(rect) || rect.r <= rect.l || rect.b <= rect.t)
                    {
                        this.get_focus_content_element()
                        if IsObject(this.focus_content_element)
                            try rect := this.focus_content_element.BoundingRectangle
                    }
                }
                if IsObject(rect) && rect.r > rect.l && rect.b > rect.t
                {
                    this.left := rect.l, this.top := rect.t, this.right := rect.r, this.bottom := rect.b
                }
                else
                {
                    ; Focus content unavailable - revert to window rect & disable focus
                    this.is_focus_content := false
                    this.focus_content_element := 0
                    this.focus_win_id := 0
                    WinGetPos(&x, &y, &w, &h, "ahk_id " this.win_id)
                    if (w <= 0 || h <= 0)
                        throw TargetError("Window size is invalid.")
                    this.left := x, this.top := y, this.right := x+w, this.bottom := y+h
                }
                if (A_TickCount - focusTick > 250)
                    writeLog("[WARN] slow UIA focus read " (A_TickCount - focusTick) "ms (can starve the keyboard hook)")
            }
            else
            {
                WinGetPos(&x, &y, &w, &h, "ahk_id " this.win_id)
                if (w <= 0 || h <= 0)
                    throw TargetError("Window size is invalid.")
                this.left := x, this.top := y, this.right := x+w, this.bottom := y+h
            }
            return true  ; Success
        }
        Catch TargetError as err
        {
            ; Only reset win_id to 0 if window truly doesn't exist
            if !WinExist("ahk_id " this.win_id)
            {
                this.win_id := 0
                this.is_focus_content := false
                return false  ; Window closed
            }
            ; Window exists but has invalid dimensions (e.g., during maximization)
            return false  ; Window in invalid state
        }
    }

    updateXYWH(x, y, w, h)
    {
        this.left := x
        this.top := y
        this.right := x + w
        this.bottom := y + h
    }

    updateXYRB(x, y, r, b)
    {
        this.left   := x
        this.top    := y
        this.right  := r
        this.bottom := b
    }

    toggle_content_focus()
    {
        this.is_focus_content := !this.is_focus_content
        if (this.is_focus_content)
        {
            this.get_focus_content_element(true)  ; logDiag: capture element info on user-initiated press
        }
        else
        {
            this.focus_content_element := 0
            this.focus_win_id := 0
        }
    }

    get_focus_content_element(logDiag := false)
    {
        ; Assume "not found" until a valid element is resolved. Everything below
        ; is guarded so this method never throws - a failure simply disables
        ; focus and lets callers fall back to the plain window rect.
        this.focus_content_element := 0
        try {
            process_name := WinGetProcessName("ahk_id " this.win_id)

            ; Choose the HWND to use as the UIA root. The shared-content element
            ; lives in the app's TOP-LEVEL UI tree, but win_id is usually a child
            ; rendering window (new Teams: "TeamsVideo"; old Teams: a WebView2
            ; sub-window) whose own UIA subtree is empty. So for Teams variants we
            ; root at the top-level ancestor; WeMeet keeps its VideoWindow hop.
            if (process_name = "ms-teams.exe" || process_name = "Teams.exe" || process_name = "msedgewebview2.exe") {
                hwnd := DllCall("GetAncestor", "Ptr", this.win_id, "UInt", 2, "Ptr")  ; GA_ROOT = top-level window
                if !hwnd
                    hwnd := this.win_id
            }
            else if (process_name = "WeMeetApp.exe" && WinGetTitle("ahk_id " this.win_id) = "VideoWindow") {
                hwnd := DllCall("GetParent", "Ptr", this.win_id, "Ptr")
            }
            else {
                hwnd := this.win_id
            }

            if logDiag
                writeLog("[DEBUG] focus(f): process=" process_name " win_id=" this.win_id " UIA root hwnd=" hwnd)

            root := UIA.ElementFromHandle(hwnd)

            ; Search for all possible target elements (Teams CN/EN, WeMeet).
            ; In this UIA lib FindFirst THROWS when nothing matches, so guard it.
            found := 0
            try found := root.FindFirst({
                Or: [
                    {Name: "共享内容视图"},
                    {Name: "Shared content view"},
                    {Name: "VideoLayoutExtensionWidget", ClassName: "QFWidget"}
                ]
            })
            if IsObject(found)
            {
                ; For Teams the shared-content pane is type "main"; the actual
                ; rendered shared screen is its largest "menu" descendant (which
                ; excludes the presenting/control bars). Pick the largest to avoid
                ; transient dropdown menus; fall back to the pane itself.
                if (found.LocalizedType = "main") {
                    menuChild := 0, bestArea := 0
                    try {
                        for c in found.FindAll({Type: "Menu"}) {
                            mr := c.BoundingRectangle
                            area := (mr.r - mr.l) * (mr.b - mr.t)
                            if (area > bestArea)
                                bestArea := area, menuChild := c
                        }
                    }
                    if IsObject(menuChild)
                        found := menuChild
                }
                this.focus_content_element := found
                this.focus_win_id := this.win_id
                if logDiag {
                    r := found.BoundingRectangle
                    writeLog("[DEBUG] focus(f): FOUND  Name='" found.Name "' Type='" found.LocalizedType "' Class='" found.ClassName "' AutoId='" found.AutomationId "' rect=" r.l "," r.t "," r.r "," r.b)
                }
                return  ; success
            }

            if logDiag
                writeLog("[DEBUG] focus(f): shared-content element not found")
        } catch Error as err {
            if logDiag
                writeLog("[DEBUG] focus(f): lookup threw: " err.Message)
            ; fall through to "not found"
        }
        ; Element not found / lookup failed - disable focus so callers fall back
        ; to the plain window rect instead of freezing the overlay.
        this.is_focus_content := false
        this.focus_content_element := 0
        this.focus_win_id := 0
    }

    change_border(option)
    {
        If (option = "SET")
        {
            this.borders.get_next_setting(&left_border, &top_border, &right_border, &bottom_border, &aspect_ratio, &extended_cut)
            this.left_border    := left_border
            this.top_border     := top_border
            this.right_border   := right_border
            this.bottom_border  := bottom_border
            this.aspect_ratio   := aspect_ratio
            this.extended_cut   := extended_cut
        }
        Else If (option = "LEFT")
            this.left_border := this.borders.get_left()
        Else if (option = "TOP")
            this.top_border := this.borders.get_top()
        else if (option = "RIGHT")
            this.right_border := this.borders.get_right()
        else if (option = "BOTTOM")
            this.bottom_border := this.borders.get_bottom()
        else if (option = "RATIO")
            this.aspect_ratio := this.borders.get_ratio()
        else if (option = "EXTENDED")
            this.extended_cut := this.borders.get_extended_cut()
    }

    reset_borders()
    {
        this.borders.reset()
        this.left_border    := 0
        this.top_border     := 0
        this.right_border   := 0
        this.bottom_border  := 0
        this.aspect_ratio   := 0
    }

    GuiString()
    {
        this.GetRegionRect(&x, &y, &w, &h)
        return "NA x" x " y" y " w" w " h" h
    }

    ScreenString(scale:=1)
    {
        this.GetRegionRect(&x, &y, &w, &h)
        return x*scale "|" y*scale "|" w*scale "|" h*scale
    }

    GetCenter(&pX, &pY)
    {
        this.GetRegionRect(&x, &y, &w, &h)
        pX := x + Round(w/2)
        pY := y + Round(h/2)
    }

    moveGui(aGui)
    {
        this.GetRegionRect(&x, &y, &w, &h)
        aGui.Move(x, y, w, h)
    }

    GetProcessName()
    {
        Try
            return WinGetProcessName("ahk_id " this.win_id)
        Catch TargetError as err
            return ""
    }
    
    GetClassName()
    {
        Try
            return winGetClass("ahk_id " this.win_id)
        Catch TargetError as err
            return ""
    }

}