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
            if (c = "exit_script") {
                Sleep, 250
                ExitApp
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