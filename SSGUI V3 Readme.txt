Subnautica Speedrun GUI V3
By ItsFrosti

================================================================================
Overview
================================================================================
Subnautica Speedrun GUI V3 provides a streamlined way to manage multiple
Subnautica versions, restart the game quickly, toggle the RNG mod, run a
customizable reset macro, and optionally enable hardcore save deletion.

The app pairs an AutoHotkey script with a custom NW.js-powered GUI, allowing you
to control features via an HTML interface.

--------------------------------------------------------------------------------
Getting Started
--------------------------------------------------------------------------------
1. Launch "SSGUI V3.exe"
   - This runs the AutoHotkey backend and automatically launches the GUI
     (nw.exe in the GUI folder, loading SSGUI.html).
2. Use the GUI to configure hotkeys, launch versions, and toggle features.
3. The app communicates internally using "command.txt" (created automatically in
   the GUI folder).

--------------------------------------------------------------------------------
✨ Features
--------------------------------------------------------------------------------

[1] Version Launcher
--------------------
- Dropdown + Launch button lets you select between:
  - 2018 Version (Speedrunner’s Patch)
  - Current Version (2023/2025 Patch)

Requirements:
- Installed via Steam at:
  C:\Program Files (x86)\Steam\steamapps\common
- Game folders must be named:
  - Subnautica 2018
  - Subnautica Current
- One folder must remain named "Subnautica" (the active version). The switcher
  handles the rest.

[2] Game Restart
----------------
- Restart Game button → closes Subnautica and relaunches the active version.
- Set Hotkey → assign any key to instantly restart the game.

[3] Toggle RNG Mod
------------------
- Toggles the BetterRNG Mod by Sprinter_31 on/off.
- Requires the mod to already be installed (this feature does not install it).

[4] Reset Macro
---------------
- Setup Macro button launches a guided 7-step setup:

The Reset Macro will Automatically Press the Esc Button to Open the Pause Menu,

Step 1 of 7 - Hover over the Quit Button and press TAB to Set as Click
Step 2 of 7 - Hover over the 1st Yes Button and press TAB to Set as Click
Step 3 of 7 - Hover over the 2nd Yes Button and press TAB to Set as Click
Step 4 of 7 - Hover over a unique Main Menu spot and press TAB to Set as Identifier
   (suggested: Newsletter "Enter Email" box, left most edge, dark blue inside color)
Step 5 of 7 - Hover over the Play Button and press TAB to Set as Click
Step 6 of 7 - Hover over "Start a New Game" and press TAB to Set as Click
Step 7 of 7 - Hover over desired Game Mode and press TAB to Set as Click

Controls:
- TAB = Confirm step
- ESC = Cancel setup

Why 2 Yes Buttons?
- Under 1 Minute: confirmation doesn’t appear for Yes Button.
- Over 1 Minute: confirmation prompt appears moving the Yes button down.

After setup:
- Enter a hotkey in text box under Setup Macro → press Set Hotkey.
- That hotkey will trigger the reset macro sequence.

[5] Hardcore Save Deleter
-------------------------
- Toggle button: ON / OFF
- When ON:
  - After a reset, once the macro detects the Main Menu, your latest save is
    automatically deleted.
- When OFF:
  - Only the reset macro runs, saves remain untouched.

⚠️ Warning: Only use this feature with Hardcore saves. Non-hardcore saves may be
lost. 

Do Not run Reset Macro on Main Menu when using Hardcore Save Deleter 
while you have Other Saves because they will be deleted on accident.

--------------------------------------------------------------------------------
⚠️ Notes & Limitations
--------------------------------------------------------------------------------
- If "SSGUI V3.exe" doesn’t launch, you may need install AutoHotkey v1.
- 6-second delays are built into Restart/Version Switcher:
  - Allows Steam time to close and unlock files.
  - If Steam is too slow, close Subnautica manually before switching.
  - This Means the Restart Game Feature is about 2-4 Seconds Slow on average.
- Using Reset Macro + Hardcore Save Deleter will permanently delete the save files.
- RNG Toggle may not always work—depends on your mod installation.
- GUI ↔ AHK communication requires "command.txt".
  - Ensure nothing interferes with this file.

--------------------------------------------------------------------------------
Info
--------------------------------------------------------------------------------
- Version: V3
- Backend: AutoHotkey (compiled as EXE)
- Frontend: NW.js (HTML/CSS/JS GUI)
