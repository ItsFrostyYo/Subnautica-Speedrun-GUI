#SingleInstance Force
SetTitleMatchMode, 2
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
SetDefaultMouseSpeed, 0

; Removed external launcher - installer is now built-in
; Run, %A_ScriptDir%\GUI\SaveFileInstaller.ahk

; ---------------- Config ----------------
BasePath := "C:\Program Files (x86)\Steam\steamapps\common"
ExeName  := "Subnautica.exe"

; Path to NW.js runtime (your GUI) - defaults to script folder
nwExe := A_ScriptDir "\GUI\nw.exe"
appDir := A_ScriptDir "\GUI\"    ; where SSGUI.html and command.txt live

; Hotkey storage
CurrentHotkey       := ""
HotkeyAssigned      := false
CurrentMacroHotkey  := ""
MacroHotkeyAssigned := false
SaveDeleterOn       := false

; Wizard state (kept for backwards compatibility)
WizardActive := false
WizardStep := 0
steps := {}

; Reset macro INI path (original behavior)
ResetMacroIni := A_ScriptDir "\ResetMacro.ini"

; Timer config file
configFile := A_ScriptDir "\TimerConfig.ini"

pipeName := "\\.\pipe\SubnauticaDataPipe"
readBufSize := 4096
readIntervalMs := 100
global hPipe := 0

; ---------- Timer defaults ----------
fontSize := 40
fontColor := "FFFFFF"
xPos := A_ScreenWidth - 150
yPos := 20
autoX := 0, autoY := 0, autoColor := 0
hkStart := "[", hkPause := "]", hkReset := "\", hkAutoOn := "-", hkAutoOff := "="
fontName := "Segoe UI"
running := false
startTime := 0
elapsed := 0
autoStart := false
waitingForPixel := false
timerEnabled := false

; ---------- Load Timer settings ----------
if FileExist(configFile) {
    IniRead, fontSize,   %configFile%, Timer, fontSize, 40
    IniRead, fontColor,  %configFile%, Timer, fontColor, FFFFFF
    IniRead, xPos,       %configFile%, Timer, xPos, % A_ScreenWidth - 150
    IniRead, yPos,       %configFile%, Timer, yPos, 20
    IniRead, autoX,      %configFile%, AutoStart, x, 0
    IniRead, autoY,      %configFile%, AutoStart, y, 0
    IniRead, autoColor,  %configFile%, AutoStart, color, 0
    IniRead, hkStart,    %configFile%, Hotkeys, Start, [
    IniRead, hkPause,    %configFile%, Hotkeys, Pause, ]
    IniRead, hkReset,    %configFile%, Hotkeys, Reset, \
    IniRead, hkAutoOn,   %configFile%, Hotkeys, AutoOn, -
    IniRead, hkAutoOff,  %configFile%, Hotkeys, AutoOff, =
}

; ----------------- Prevent processing stale commands on startup -----------------
try {
    if FileExist(appDir "\command.txt")
        FileDelete, % appDir "\command.txt"
} catch e {
}
try {
    if FileExist(A_ScriptDir "\command.txt")
        FileDelete, % A_ScriptDir "\command.txt"
} catch e {
}

; --- Launch NW.js GUI when AHK starts (if found) ---
if FileExist(nwExe) {
    ; Launch nw.exe pointing at your HTML app
    Run, % """" nwExe """" " " """" appDir "\SSGUI.html" """", , UseErrorLevel, nwPID
    if (ErrorLevel)
        TrayTip, NW.js, Failed to start NW.js GUI, 5, 1
} else {
    TrayTip, NW.js, Could not find nw.exe at %nwExe%, 5, 1
}

#Persistent
; Start both timers so CheckCommands and TryConnect run concurrently
SetTimer, CheckCommands, 25
SetTimer, TryConnect, %readIntervalMs%
return   ; <<< end auto-execute (important!)

; ================================
; ======= Pipeline Detection ======
; ================================

global LastPipeConnected := false  ; Track previous connection state

TryConnect:
    if (hPipe)
        return

    hPipe := DllCall("CreateFile", "Str", pipeName, "UInt", 0x80000000, "UInt", 0, "UInt", 0, "UInt", 3, "UInt", 0, "UInt", 0, "Ptr")
    if (hPipe != -1 && hPipe != 0) {
        SetTimer, TryConnect, Off
        SetTimer, ReadPipe, %readIntervalMs%
        PipeConnected := true

        if (!LastPipeConnected) {
            TrayTip, Pipeline, Connected to Subnautica Data Pipe, 3, 1
            LastPipeConnected := true
        }
    } else {
        hPipe := 0
        PipeConnected := false
    }
return


ReadPipe:
    if (!hPipe)
        return

    VarSetCapacity(buf, readBufSize, 0)
    bytesRead := 0
    success := DllCall("ReadFile", "Ptr", hPipe, "Ptr", &buf, "UInt", readBufSize, "UInt*", bytesRead, "Ptr", 0)

    if (!success) {
        DllCall("CloseHandle", "Ptr", hPipe)
        hPipe := 0
        PipeConnected := false
        SetTimer, TryConnect, %readIntervalMs%

        if (LastPipeConnected) {
            TrayTip, Pipeline, Disconnected from Subnautica Data Pipe, 3, 2
            LastPipeConnected := false
        }
        return
    }

    if (bytesRead > 0) {
        textData := StrGet(&buf, bytesRead, "UTF-8")
        LatestPipeLine := textData
    }
return

; ============================
; ======== Functions / Labels ========
; ============================

; ----- Core game helpers -----
CloseGame() {
    Process, Close, Subnautica.exe
    Sleep, 6000
}
GetActiveVersion() {
    global BasePath
    if !FileExist(BasePath "\Subnautica")
        return ""
    if FileExist(BasePath "\Subnautica 2018")
        return "Current"
    else if FileExist(BasePath "\Subnautica Current")
        return "2018"
    else
        return ""
}
SwitchAndLaunch(VersionToLaunch) {
    global BasePath, ExeName
    CloseGame()
    Active := GetActiveVersion()
    if (Active = "") {
        MsgBox, 48, Error, Could not detect which version is currently active.
        return
    }
    if (Active = "2018")
        FileMoveDir, %BasePath%\Subnautica, %BasePath%\Subnautica 2018, R
    else if (Active = "Current")
        FileMoveDir, %BasePath%\Subnautica, %BasePath%\Subnautica Current, R
    if (VersionToLaunch = "2018")
        FileMoveDir, %BasePath%\Subnautica 2018, %BasePath%\Subnautica, R
    else if (VersionToLaunch = "Current")
        FileMoveDir, %BasePath%\Subnautica Current, %BasePath%\Subnautica, R
    Run, "%BasePath%\Subnautica\%ExeName%"
}
RestartActive() {
    global BasePath, ExeName
    CloseGame()
    if !FileExist(BasePath "\Subnautica") {
        MsgBox, 48, Error, Could not find a folder named "Subnautica".`nCannot restart.
        return
    }
    Run, "%BasePath%\Subnautica\%ExeName%"
}
ToggleRNGMod() {
    global BasePath
    folders := [BasePath "\Subnautica", BasePath "\Subnautica Current", BasePath "\Subnautica 2018"]
    modPathSuffix := "\BepInEx\plugins\BetterRNG\"
    changed := false, newState := ""
    for index, folderPath in folders {
        rngPath := folderPath . modPathSuffix
        if !FileExist(rngPath)
            continue
        betterFile   := rngPath . "BetterRNG.dll"
        inactiveFile := rngPath . "inactive.dll"
        if FileExist(betterFile) {
            FileMove, %betterFile%, %inactiveFile%, 1
            if (ErrorLevel = 0)
                changed := true, newState := "OFF"
        } else if FileExist(inactiveFile) {
            FileMove, %inactiveFile%, %betterFile%, 1
            if (ErrorLevel = 0)
                changed := true, newState := "ON"
        }
    }
    if (changed)
        MsgBox, 64, RNG Mod, RNG Mod switched %newState% for all versions.
    else
        MsgBox, 48, RNG Mod, Could not find BetterRNG.dll or inactive.dll in any version folders.
}

; ---------- Reset Macro: Updated with In-Game Identifier & Hidden Main Menu ----------
global WizardActive := false
global WizardStep := 0
global WizardSteps := []
global WizardData := []
ResetMacroIni := A_ScriptDir "\ResetMacro.ini"
global SaveDeleterOn := false
global MacroHotkey := ""
global PipeConnected := false
global LatestPipeLine := ""

ToggleSaveDeleter:
    SaveDeleterOn := !SaveDeleterOn
    if (SaveDeleterOn) {
        GuiControl,, SaveDeleterButton, Hardcore Save Deleter: ON
        GuiControl, +c0x00FF00, SaveDeleterButton ; Green text
    } else {
        GuiControl,, SaveDeleterButton, Hardcore Save Deleter: OFF
        GuiControl, +c0xFF0000, SaveDeleterButton ; Red text
    }
return

; ================================
; ======= Reset Macro Wizard ======
; ================================

BeginMacroWizard:
    WizardSteps := []
    WizardSteps.Push({id:"QuitButton", hint:"Step 1 — Hover Over the Quit Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"Confirm1", hint:"Step 2 — Hover Over the 1st Yes Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"Confirm2", hint:"Step 3 — Hover Over the 2nd Yes Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"PlayButton", hint:"Step 4 — Hover Over the Play Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"NewGame", hint:"Step 5 — Hover Over the Start a New Game Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"GameMode", hint:"Step 6 — Hover Over the Game Mode You Want and Press TAB to Set as Click", type:"Click"})

    WizardData := []
    WizardStep := 1
    WizardActive := true
    SetTimer, Wizard_Tooltip, 40
    MsgBox, 64, Reset Macro Setup, Wizard started.`n`nFollow the tooltip, press TAB to capture each step, or ESC to cancel.
return

Wizard_Tooltip:
    if (!WizardActive) {
        SetTimer, Wizard_Tooltip, Off
        ToolTip
        return
    }
    if (WizardStep > WizardSteps.MaxIndex()) {
        SetTimer, Wizard_Tooltip, Off
        ToolTip
        WizardActive := false
        Gosub, SaveResetMacro
        MsgBox, 64, Reset Macro, Macro saved to `n%ResetMacroIni%.
        return
    }
    MouseGetPos, mx, my
    if (mx < 0)
        mx := 0
    if (my < 0)
        my := 0
    step := WizardSteps[WizardStep]
    ToolTip, % "Step " WizardStep " of " WizardSteps.MaxIndex() "`n`n" step.hint "`nX: " mx " Y: " my, mx + 20, my + 20
return

~Tab::
    if (WizardActive) {
        step := WizardSteps[WizardStep]
        MouseGetPos, x, y

        if (step.type = "Click")
            WizardData.Push({Type:"Click", X:x, Y:y})

        SoundBeep, 750
        WizardStep++
    }
return

~Esc::
    if (!WizardActive)
        return
    SetTimer, Wizard_Tooltip, Off
    ToolTip
    WizardActive := false
    WizardStep := 0
    WizardData := []
    MsgBox, 48, Reset Macro, Wizard cancelled.
return

SaveResetMacro:
    ini := ResetMacroIni
    FileDelete, %ini%
    FileAppend, ; Reset Macro INI generated`n, %ini%
    for idx, item in WizardData {
        section := "Step" idx
        IniWrite, % item.Type, %ini%, %section%, Type
        IniWrite, % item.X, %ini%, %section%, X
        IniWrite, % item.Y, %ini%, %section%, Y
        IniWrite, Step %idx%, %ini%, %section%, Name
    }
return

; ================================
; ======= Run Reset Macro =========
; ================================

RunResetMacro:
    ini := ResetMacroIni
    if !FileExist(ini) {
        MsgBox, 48, No Macro, No ResetMacro.ini found. Please run Setup Macro first.
        return
    }

    ; ---------- Read step coordinates ----------
    IniRead, quitX, %ini%, Step1, X
    IniRead, quitY, %ini%, Step1, Y
    IniRead, confirm1X, %ini%, Step2, X
    IniRead, confirm1Y, %ini%, Step2, Y
    IniRead, confirm2X, %ini%, Step3, X
    IniRead, confirm2Y, %ini%, Step3, Y
    IniRead, playX, %ini%, Step4, X
    IniRead, playY, %ini%, Step4, Y
    IniRead, newGameX, %ini%, Step5, X
    IniRead, newGameY, %ini%, Step5, Y
    IniRead, gameModeX, %ini%, Step6, X
    IniRead, gameModeY, %ini%, Step6, Y

    ; ---------- Parse Pipeline ----------
    StringSplit, coords, LatestPipeLine, `;
    posX := coords1
    posY := coords2
    posZ := coords3

    quitPerformed := false

    ; ---------- Quit Sequence if in-game ----------
    if !(posX = 0 && posY = 1.75 && posZ = 0) {
        quitPerformed := true

        ; Open pause menu
        Send, {Esc}
        Sleep, 75

        ; Click Quit and confirmations
        Click, %quitX%, %quitY%
        Sleep, 50
        Click, %confirm1X%, %confirm1Y%
        Sleep, 50
        Click, %confirm2X%, %confirm2Y%
        Sleep, 50

        ; Wait until main menu
        Loop {
            StringSplit, coords, LatestPipeLine, `;
            posX := coords1
            posY := coords2
            posZ := coords3
            if (posX = 0 && posY = 1.75 && posZ = 0)
                break
            Sleep, 50
        }
    }

    Sleep, 100

    ; ---------- Play Sequence ----------
    Click, %playX%, %playY%
    Sleep, 50
    Click, %newGameX%, %newGameY%
    Sleep, 50
    Click, %gameModeX%, %gameModeY%
    Sleep, 50

    ; ---------- Hardcore Save Deleter ----------
    if (SaveDeleterOn && quitPerformed) {
        SubnauticaBasePath := "C:\Program Files (x86)\Steam\steamapps\common\Subnautica\SNAppData\SavedGames"
        newestTime := 0
        newestSlot := ""
        Loop, Files, %SubnauticaBasePath%\slot????, D
        {
            if (A_LoopFileTimeModified > newestTime) {
                newestTime := A_LoopFileTimeModified
                newestSlot := A_LoopFileFullPath
            }
        }
        if (newestSlot != "")
            FileRemoveDir, %newestSlot%, 1
    }
return

; ============================
; ======== Timer Code ========
; ============================

EnableTimer:
if (!timerEnabled) {
    timerEnabled := true
    Gui, Timer: +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, Timer: Color, 000000
    Gui, Timer: Font, s%fontSize% c%fontColor%, %fontName%
    Gui, Timer: Add, Text, vTimerText Center BackgroundTrans, 00:00.00
    Gui, Timer: Show, x%xPos% y%yPos% NoActivate, Timer
    WinSet, TransColor, 000000, Timer
    SetTimer, UpdateTimer, 30
    RegisterHotkeys()
}
return

DisableTimer:
if (timerEnabled) {
    timerEnabled := false
    Gui, Timer: Destroy
    SetTimer, UpdateTimer, Off
    UnregisterHotkeys()
    running := false
    elapsed := 0
}
return

UpdateTimer:
if (running)
    elapsed := A_TickCount - startTime
ms := Mod(elapsed,1000)
totalSeconds := Floor(elapsed/1000)
minutes := Floor(totalSeconds/60)
seconds := Mod(totalSeconds,60)
hours   := Floor(totalSeconds/3600)
if (hours > 0)
    display := Format("{:02}:{:02}:{:02}.{:02}", hours, Mod(minutes,60), seconds, Floor(ms/10))
else
    display := Format("{:02}:{:02}.{:02}", minutes, seconds, Floor(ms/10))
GuiControl, Timer:, TimerText, % display
return

; --- Hotkey helpers ---
RegisterHotkeys() {
    global hkStart, hkPause, hkReset, hkAutoOn, hkAutoOff
    Hotkey, %hkStart%, StartTimer, On
    Hotkey, %hkPause%, PauseTimer, On
    Hotkey, %hkReset%, ResetTimer, On
    Hotkey, %hkAutoOn%, EnableAutoStart, On
    Hotkey, %hkAutoOff%, DisableAutoStart, On
}
UnregisterHotkeys() {
    global hkStart, hkPause, hkReset, hkAutoOn, hkAutoOff
    Hotkey, %hkStart%, Off
    Hotkey, %hkPause%, Off
    Hotkey, %hkReset%, Off
    Hotkey, %hkAutoOn%, Off
    Hotkey, %hkAutoOff%, Off
}

; --- Hotkey routines ---
StartTimer:
if (!running) {
    running := true
    startTime := A_TickCount - elapsed
}
return

PauseTimer:
if (running) {
    running := false
    elapsed := A_TickCount - startTime
}
return

ResetTimer:
running := false
elapsed := 0
if (timerEnabled)
    GuiControl, Timer:, TimerText, 00:00.00
return

EnableAutoStart:
if (autoX && autoY && autoColor) {
    autoStart := true
    SetTimer, CheckAutoStart, 5
}
return

DisableAutoStart:
autoStart := false
SetTimer, CheckAutoStart, Off
return

CheckAutoStart:
if (!autoStart)
    return
PixelGetColor, c, %autoX%, %autoY%, RGB
if (c = autoColor) {
    if (!running) {
        running := true
        startTime := A_TickCount - elapsed
    }
}
return

; --- Timer Settings GUI ---
ShowSettings:
Gui, Settings: New
Gui, Settings: Font, s10, Segoe UI

; --- Timer Customization Group ---
Gui, Settings: Add, GroupBox, x10 y10 w310 h100, Timer Customization
Gui, Settings: Font, s9, Segoe UI
Gui, Settings: Add, Text, x20 y35 w70, X Pos:
Gui, Settings: Add, Edit, x95 y32 w60 vSetX, %xPos%
Gui, Settings: Add, Text, x165 y35 w70, Y Pos:
Gui, Settings: Add, Edit, x235 y32 w60 vSetY, %yPos%

Gui, Settings: Add, Text, x20 y65 w70, Font Size:
Gui, Settings: Add, Edit, x95 y62 w60 vSetSize, %fontSize%
Gui, Settings: Add, Text, x165 y65 w70, Font Color:
Gui, Settings: Add, Edit, x235 y62 w60 vSetColor, %fontColor%

; --- Hotkeys Group ---
Gui, Settings: Add, GroupBox, x10 y120 w310 h130, Hotkeys
Gui, Settings: Add, Text, x20 y145 w70, Start:
Gui, Settings: Add, Edit, x95 y142 w60 vSetHkStart, %hkStart%
Gui, Settings: Add, Text, x165 y145 w70, Pause:
Gui, Settings: Add, Edit, x235 y142 w60 vSetHkPause, %hkPause%

Gui, Settings: Add, Text, x20 y175 w70, Reset:
Gui, Settings: Add, Edit, x95 y172 w60 vSetHkReset, %hkReset%
Gui, Settings: Add, Text, x165 y175 w70, Auto On:
Gui, Settings: Add, Edit, x235 y172 w60 vSetHkOn, %hkAutoOn%

Gui, Settings: Add, Text, x20 y205 w70, Auto Off:
Gui, Settings: Add, Edit, x95 y202 w60 vSetHkOff, %hkAutoOff%

; --- Action Buttons ---
Gui, Settings: Add, Button, x60 y265 w80 h25 gApplySettings, Apply
Gui, Settings: Add, Button, x160 y265 w140 h25 gSetupAutoStart, Setup AutoStart  ; <<< new button

Gui, Settings: Show, w330 h310, Timer Settings
return

ApplySettings:
Gui, Settings: Submit
xPos     := SetX
yPos     := SetY
fontSize := SetSize
fontColor:= SetColor

; Save hotkeys
hkStart  := SetHkStart
hkPause  := SetHkPause
hkReset  := SetHkReset
hkAutoOn := SetHkOn
hkAutoOff:= SetHkOff

; Write to INI
IniWrite, %fontSize%,  %configFile%, Timer, fontSize
IniWrite, %fontColor%, %configFile%, Timer, fontColor
IniWrite, %xPos%,      %configFile%, Timer, xPos
IniWrite, %yPos%,      %configFile%, Timer, yPos
IniWrite, %hkStart%,   %configFile%, Hotkeys, Start
IniWrite, %hkPause%,   %configFile%, Hotkeys, Pause
IniWrite, %hkReset%,   %configFile%, Hotkeys, Reset
IniWrite, %hkAutoOn%,  %configFile%, Hotkeys, AutoOn
IniWrite, %hkAutoOff%, %configFile%, Hotkeys, AutoOff

Gui, Settings: Destroy
return

SetupAutoStart:  ; <<< button handler
waitingForPixel := true
MsgBox, 64, AutoStart Setup, Hover over the pixel you want to use, then press TAB to save it.
return

; ============================
; ======== COMMAND TIMER ========
; ============================

CheckCommands:
    global CurrentHotkey, HotkeyAssigned
    global CurrentMacroHotkey, MacroHotkeyAssigned
    global SaveDeleterOn, appDir

    paths := [appDir "\command.txt", A_ScriptDir "\command.txt"]

    for index, p in paths {
        if !FileExist(p)
            continue

        FileRead, rawcmd, %p%
        FileDelete, %p%
        if (rawcmd = "")
            continue

        ; Handle multiple commands separated by newlines
        Loop, Parse, rawcmd, `n, `r
        {
            cmd := Trim(A_LoopField)
            if (cmd = "")
                continue

            StringLower, c, cmd  ; make it case-insensitive

            ; --- Game Version ---
            if (c = "launch2018") {
                SwitchAndLaunch("2018")
                continue
            }
            if (c = "launchcurrent") {
                SwitchAndLaunch("Current")
                continue
            }
            if (c = "restartgame" || c = "restart_active" || c = "restartactive") {
                RestartActive()
                continue
            }
            if (c = "toggle_rng" || c = "togglerng" || c = "toggle_rngmod") {
                ToggleRNGMod()
                continue
            }
            if (c = "open_github") {
                ; Use explicit string to ensure proper parsing
                Run, % "https://github.com/ItsFrostyYo/Subnautica-Speedrun-GUI/releases"
                continue
            }
            if (c = "open_youtube") {
                Run, % "https://www.youtube.com/@SNFrosti"
                continue
            }
            if (c = "open_fileoptions") {
                ; Open the integrated Save File Installer GUI (merged)
                Gosub, ShowMenu_SaveFileInstaller
                continue
            }
            if (c = "exit_script") {
                ; Close GUIs if present then exit
                ; Try to close Timer window if exists
                WinClose, Timer.ahk
                ; Close SaveFileInstaller/GUIs
                Gui, SaveFileInstaller:Destroy
                Gui, FileInstaller:Destroy
                Sleep, 500
                ExitApp
            }

            ; --- Timer commands ---
            if (c = "enable_timer") {
                Gosub, EnableTimer
                continue
            }
            if (c = "disable_timer") {
                Gosub, DisableTimer
                continue
            }
            if (c = "show_options") {
                Gosub, ShowSettings
                continue
            }

            ; --- Save Deleter ---
            if (c = "enable_savedeleter" || c = "enablesavedeleter") {
                SaveDeleterOn := true
                TrayTip, Save Deleter, Now ON, 3, 1
                continue
            }
            if (c = "disable_savedeleter" || c = "disablesavedeleter") {
                SaveDeleterOn := false
                TrayTip, Save Deleter, Now OFF, 3, 1
                continue
            }
            if (c = "toggle_savedeleter" || c = "togglesavedeleter") {
                SaveDeleterOn := !SaveDeleterOn
                TrayTip, Save Deleter, % "Now " (SaveDeleterOn ? "ON" : "OFF"), 3, 1
                continue
            }

            ; --- Hotkeys ---
            if InStr(c, "set_hotkey:") {
                key := Trim(SubStr(cmd, InStr(cmd, ":")+1))
                if (key != "") {
                    if (HotkeyAssigned)
                        Hotkey, %CurrentHotkey%, Off
                    CurrentHotkey := key
                    Hotkey, %key%, RestartActive, On
                    HotkeyAssigned := true
                    MsgBox, 64, Hotkey Set, Restart hotkey set to: %CurrentHotkey%
                }
                continue
            }

            if InStr(c, "set_macro_hotkey:") {
                key := Trim(SubStr(cmd, InStr(cmd, ":")+1))
                if (key != "") {
                    if (MacroHotkeyAssigned)
                        Hotkey, %CurrentMacroHotkey%, Off
                    CurrentMacroHotkey := key
                    Hotkey, %key%, RunResetMacro, On
                    MacroHotkeyAssigned := true
                    MsgBox, 64, Macro Hotkey Set, Macro hotkey set to: %CurrentMacroHotkey%
                }
                continue
            }

            ; --- Macro ---
            if (c = "setup_macro") {
                Gosub, BeginMacroWizard
                continue
            }
            if (c = "runresetmacro" || c = "run_macro" || c = "runmacro") {
                Gosub, RunResetMacro
                continue
            }
        }
    }
return

; ============================
; === Integrated Save File Installer (exact behavior of old standalone) ===
; ============================

; === GLOBAL DEFINITIONS ===
global GameSavePath := "C:\Program Files (x86)\Steam\steamapps\common\Subnautica\SNAppData\SavedGames"
global CurrentCategory := ""

; === GUI open point (called from CheckCommands when "open_fileoptions" detected) ===
ShowMenu_SaveFileInstaller:
    Gosub, ShowMenu_SaveInstaller
return

; ===================== GUI =====================
ShowMenu_SaveInstaller:
    Gui, SaveFileInstaller:Destroy
    Gui, SaveFileInstaller:+Resize +OwnDialogs
    Gui, SaveFileInstaller:Color, 001a33, 001a33   ; dark blue background

    ; --- Add background image ---
    bgPath := A_ScriptDir "\Data\BackgroundSFI.png"
    if FileExist(bgPath)
        Gui, SaveFileInstaller:Add, Picture, x0 y0 w650 h260 vBG, %bgPath%

    Gui, SaveFileInstaller:Font, s10 cWhite
    Gui, SaveFileInstaller:Add, Text, vCatLabel x20 y20 w400 h20 BackgroundTrans, Select a category below...
    Gui, SaveFileInstaller:Add, Text, vSaveLabel x20 y50 w200 h20 BackgroundTrans,
    Gui, SaveFileInstaller:Add, DropDownList, vSaveList x20 y70 w300 cWhite Background001a33
    Gui, SaveFileInstaller:Add, Button, vInstallBtn gInstallSave x340 y70 w100 h25 cWhite Background001a33, Install

    ; --- Category Buttons ---
    Gui, SaveFileInstaller:Add, Button, gShowCat1 x20  y120 w150 h30 cWhite Background001a33, Survival Glitched
    Gui, SaveFileInstaller:Add, Button, gShowCat2 x190 y120 w150 h30 cWhite Background001a33, Survival Glitchless
    Gui, SaveFileInstaller:Add, Button, gShowCat3 x360 y120 w150 h30 cWhite Background001a33, Hardcore Glitched
    Gui, SaveFileInstaller:Add, Button, gShowCat4 x20  y160 w150 h30 cWhite Background001a33, Creative Glitchless
    Gui, SaveFileInstaller:Add, Button, gShowCat5 x190 y160 w150 h30 cWhite Background001a33, AA Survival Glitched
    Gui, SaveFileInstaller:Add, Button, gShowCat6 x360 y160 w150 h30 cWhite Background001a33, 100`% Survival Glitched

    Gui, SaveFileInstaller:Show, w650 h260, Save File Installer
return

; ===================== Category Handlers =====================
ShowCat1:
    LoadCategory_SaveInstaller("Survival Glitched")
return
ShowCat2:
    LoadCategory_SaveInstaller("Survival Glitchless")
return
ShowCat3:
    LoadCategory_SaveInstaller("Hardcore Glitched")
return
ShowCat4:
    LoadCategory_SaveInstaller("Creative Glitchless")
return
ShowCat5:
    LoadCategory_SaveInstaller("AA Survival Glitched")
return
ShowCat6:
    LoadCategory_SaveInstaller("100`% Survival Glitched")
return

; ===================== Load Category =====================
LoadCategory_SaveInstaller(category) {
    global CurrentCategory
    CurrentCategory := category

    baseDir := A_ScriptDir "\GUI\Save Files\" category
    GuiControl, SaveFileInstaller:, CatLabel, %category% Save Files
    GuiControl, SaveFileInstaller:, SaveLabel, Select a Save File:
    GuiControl, SaveFileInstaller:, SaveList, |

    if !FileExist(baseDir) {
        MsgBox, 16, Error, Folder not found:`n%baseDir%
        return
    }

    list := ""
    Loop, Files, %baseDir%\*, D
        list .= (list = "" ? "" : "|") A_LoopFileName
    if (list = "")
        list := "(No saves found)"
    GuiControl, SaveFileInstaller:, SaveList, %list%
}

; ===================== Install Handler (original logic restored) =====================
InstallSave:
    global CurrentCategory
    GameSavePath := "C:\Program Files (x86)\Steam\steamapps\common\Subnautica\SNAppData\SavedGames"

    GuiControlGet, save, SaveFileInstaller:, SaveList

    if (CurrentCategory = "") {
        MsgBox, 48, Error, Please select a category first!
        return
    }
    if (save = "" or save = "(No saves found)") {
        MsgBox, 48, Error, Please select a valid save file!
        return
    }

    ; ✅ Correct source path format
    srcDir := A_ScriptDir "\GUI\Save Files\" CurrentCategory "\" save
    destDir := GameSavePath "\" save

    if !FileExist(srcDir) {
        MsgBox, 16, Error, Source folder not found:`n%srcDir%
        return
    }

    ; --- Test permission in target ---
    testFile := GameSavePath "\__ssgui_test.txt"
    FileDelete, %testFile%
    FileAppend, test, %testFile%
    if !FileExist(testFile) {
        MsgBox, 48, Permission Error, ❌ Cannot write to:`n%GameSavePath%`nPlease run as Administrator.
        return
    } else FileDelete, %testFile%

    ; --- Remove existing version ---
    if FileExist(destDir)
        FileRemoveDir, %destDir%, 1
    Sleep, 100

    ; --- Create target and copy recursively ---
    FileCreateDir, %destDir%
    FileCopyDir, %srcDir%, %destDir%, 1

    if ErrorLevel {
        MsgBox, 16, Error, ❌ Failed to install "%save%".`nTry running as Administrator.
        return
    }

    ; --- Verify result ---
    if !FileExist(destDir) {
        MsgBox, 16, Error, ❌ Copy failed — destination folder not found:`n%destDir%
        return
    }

    MsgBox, 64, Success, ✅ Installed "%save%" successfully!`nCopied to:`n%GameSavePath%
return

; ===================== Exit GUI only =====================
GuiClose_SaveFileInstaller:
    Gui, SaveFileInstaller:Destroy
return