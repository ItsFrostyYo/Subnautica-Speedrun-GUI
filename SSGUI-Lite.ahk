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
SetTimer, CheckCommands, 25
return   ; <<< end auto-execute (important!)

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

; ---------- Setup Wizard ----------
BeginMacroWizard:
    WizardSteps := []
    WizardSteps.Push({id:"InGamePixel", hint:"Step 1 — Hover Over a Unique Spot and Press TAB to Set as Identifier for In Game.", type:"PixelCheck"})
    WizardSteps.Push({id:"QuitButton", hint:"Step 2 — Hover Over the Quit Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"Confirm1", hint:"Step 3 — Hover Over the 1st Yes Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"Confirm2", hint:"Step 4 — Hover Over the 2nd Yes Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"MainMenuPixel", hint:"Step 5 — Hover Over a Unique Spot and Press TAB to Set as Identifier for Main Menu", type:"PixelCheck"})
    WizardSteps.Push({id:"PlayButton", hint:"Step 6 — Hover Over the Play Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"NewGame", hint:"Step 7 — Hover Over the Start a New Game Button and Press TAB to Set as Click.", type:"Click"})
    WizardSteps.Push({id:"GameMode", hint:"Step 8 — Hover Over the Game Mode You Want and Press TAB to Set as Click", type:"Click"})

    WizardData := []
    WizardStep := 1
    WizardActive := true
    SetTimer, Wizard_Tooltip, 40
    MsgBox, 64, Reset Macro Setup, Wizard started.`n`nFollow the tooltip, press TAB to capture each step, or ESC to cancel.
Return

Wizard_Tooltip:
    if (!WizardActive) {
        SetTimer, Wizard_Tooltip, Off
        ToolTip
        Return
    }
    if (WizardStep > WizardSteps.MaxIndex()) {
        SetTimer, Wizard_Tooltip, Off
        ToolTip
        WizardActive := false
        SaveResetMacro(WizardData)
        MsgBox, 64, Reset Macro, Macro saved to `n%ResetMacroIni%.
        Return
    }
    MouseGetPos, mx, my
    if (mx < 0)
        mx := 0
    if (my < 0)
        my := 0
    step := WizardSteps[WizardStep]
    PixelGetColor, col, mx, my, RGB
    StringTrimLeft, colhex, col, 2
    ToolTip, % "Step " WizardStep " of " WizardSteps.MaxIndex() "`n`n" step.hint "`nX: " mx " Y: " my "`nColor: 0x" colhex, mx + 20, my + 20
Return

~Tab::
    if (WizardActive) {
        step := WizardSteps[WizardStep]
        MouseGetPos, x, y
        PixelGetColor, col, x, y, RGB
        StringTrimLeft, colhex, col, 2

        if (step.type = "Click") {
            WizardData.Push({Type:"Click", X:x, Y:y})
            SoundBeep, 750
        } else if (step.type = "PixelCheck") {
            WizardData.Push({Type:"WaitForPixel", X:x, Y:y, Color:colhex})
            SoundBeep, 750
        }
        WizardStep++
        Return
    }
Return

~Esc::
    if (!WizardActive)
        Return
    SetTimer, Wizard_Tooltip, Off
    ToolTip
    WizardActive := false
    WizardStep := 0
    WizardData := []
    MsgBox, 48, Reset Macro, Wizard cancelled.
Return

SaveResetMacro(data) {
    ini := A_ScriptDir "\ResetMacro.ini"
    FileDelete, %ini%
    FileAppend, ; Reset Macro INI generated by Subnautica GUI`n, %ini%
    for idx, item in data {
        section := "Step" idx
        IniWrite, % item.Type, %ini%, %section%, Type
        if (item.Type = "Click") {
            IniWrite, % item.X, %ini%, %section%, X
            IniWrite, % item.Y, %ini%, %section%, Y
        } else if (item.Type = "WaitForPixel") {
            IniWrite, % item.X, %ini%, %section%, X
            IniWrite, % item.Y, %ini%, %section%, Y
            IniWrite, % item.Color, %ini%, %section%, Color
        }
        IniWrite, Step %idx%, %ini%, %section%, Name
    }
}

; ---------- Run Reset Macro (AHK v1 safe, with hidden main menu detection + fallbacks) ----------
RunResetMacro:
    ini := A_ScriptDir "\ResetMacro.ini"
    if !FileExist(ini) {
        MsgBox, 48, No Macro, No ResetMacro.ini found. Please run Setup Macro first.
        return
    }

    ; --- Read Step1 (In-Game) and Step5 (Main Menu) ---
    IniRead, inGameX, %ini%, Step1, X
    IniRead, inGameY, %ini%, Step1, Y
    IniRead, inGameColor, %ini%, Step1, Color
    inGameColor := "0x" . inGameColor

    IniRead, mainX, %ini%, Step5, X
    IniRead, mainY, %ini%, Step5, Y
    IniRead, mainColor, %ini%, Step5, Color
    mainColor := "0x" . mainColor

    ; --- Hidden Main Menu (Step9 / Hardcoded) ---
    hiddenX := 853
    hiddenY := 928
    hiddenColor := 0x000001

    ; --- Detect if In-Game ---
    PixelGetColor, curCol, %inGameX%, %inGameY%, RGB
    if (curCol == inGameColor) {
        ; In-game detected → open pause menu
        Send, {Escape}
        Sleep, 100
        startIdx := 2 ; QuitButton
        useHidden := true
    } else {
        ; Main Menu already
        startIdx := 5
        useHidden := false
    }

    idx := startIdx
    Loop {
        section := "Step" idx
        IniRead, type, %ini%, %section%, Type, NOTFOUND
        if (type == "NOTFOUND")
            break

        if (type == "Click") {
            IniRead, cx, %ini%, %section%, X
            IniRead, cy, %ini%, %section%, Y
            if (idx == 6)
                Sleep, 15
            Sleep, 15
            Click, %cx%, %cy%
            Sleep, 15
        } else if (type == "WaitForPixel") {
            IniRead, px, %ini%, %section%, X
            IniRead, py, %ini%, %section%, Y
            IniRead, targetColor, %ini%, %section%, Color
            targetColor := "0x" . targetColor

            ; --- Wait with timeout ---
            startTime := A_TickCount
            found := false
            Loop {
                PixelGetColor, c, %px%, %py%, RGB
                if (c == targetColor) {
                    found := true
                    break
                }

                ; Timeout logic
                elapsed := A_TickCount - startTime
                if (useHidden && px == hiddenX && py == hiddenY && elapsed > 7500) {
                    ; Hidden menu timeout → fall back to normal main menu
                    px := mainX
                    py := mainY
                    targetColor := mainColor
                    startTime := A_TickCount
                } else if (!useHidden && elapsed > 5000) {
                    ; Normal main menu timeout → fail
                    MsgBox, 48, Reset Macro Error, Could not detect the proper main menu identifiers.`nMacro aborted.
                    return
                }
                Sleep, 1
            }

            ; --- Hardcore Save Deleter ---
            if (useHidden && SaveDeleterOn && px == hiddenX && py == hiddenY && targetColor == hiddenColor) {
                SubnauticaBasePath := "C:\Program Files (x86)\Steam\steamapps\common\Subnautica\SNAppData\SavedGames"
                newestTime := 0
                newestSlot := ""
                Loop, Files, % SubnauticaBasePath "\slot????", D
                {
                    if (A_LoopFileTimeModified > newestTime) {
                        newestTime := A_LoopFileTimeModified
                        newestSlot := A_LoopFileFullPath
                    }
                }
                if (newestSlot != "") {
                    FileRemoveDir, %newestSlot%, 1
                }
            }
        }
        idx++
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