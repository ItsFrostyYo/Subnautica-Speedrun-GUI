──────────────────────────────────────────────────────────────
      Subnautica Speedrun GUI — Normal Version (Release V1.5)
                     By ItsFrosti


SSGUI (Normal Version) provides a streamlined way to manage multiple
Subnautica versions, restart the game quickly, toggle the RNG mod,
run a customizable reset macro, optionally enable hardcore save deletion,
toggle an optional speedrun timer, and install or manage practice save files.

The app combines an AutoHotkey backend with a custom NW.js-powered GUI,
allowing control through a modern HTML interface.

================================================================
▶ HOW TO USE
================================================================

1. Launch **"SSGUI-Normal.exe"**
   - This runs the AutoHotkey backend and automatically launches the GUI.
   - (AutoHotkey launches `nw.exe` in the GUI folder, which loads `SSGUI.html`.)

2. Use the GUI to configure all features and set hotkeys.

3. The app communicates internally with the GUI using a text document
   (`command.txt`), which is created automatically in the GUI folder.

================================================================
▶ FEATURES
================================================================

[1] Version Launcher
────────────────────
Allows switching between:
- **2018 Version** (Speedrunner’s Patch)
- **Current Version** (2023/2025 Patch)

**Requirements**
- Installed via Steam at:
  `C:\Program Files (x86)\Steam\steamapps\common`
- Game folders must be named:
  - `Subnautica 2018`
  - `Subnautica Current`
- One folder must remain named **"Subnautica"** (the active version).
  The switcher automatically renames and swaps versions as needed.


[2] Game Restart
────────────────────
- **Restart Game** button closes and relaunches the active Subnautica version.
- **Set Hotkey** allows assigning any key to instantly restart the game.


[3] Toggle RNG Mod
────────────────────
- Toggles the **BetterRNG Mod by Sprinter_31** on or off.
- Requires the mod to already be installed.  
  (This feature does *not* install the mod.)


[4] Reset Macro
────────────────────
Automates resetting a speedrun with a single key press.

**Setup Process (7 Steps)**
1. Hover over a unique In Game spot → press **TAB**  
   *[Recommended: Health Circle's Red Color (Survival/Hardcore) or Unique Teal color on the Depth/Compass Ring (Creative)]*
2. Hover over the **Quit** button → press **TAB**
3. Hover over the **1st Yes** button → press **TAB**
4. Hover over the **2nd Yes** button → press **TAB**
5. Hover over a unique Main Menu spot → press **TAB**  
   *(Recommended: Newsletter “Enter Email” box, leftmost edge *still* color)*
6. Hover over the **Play** button → press **TAB**
7. Hover over **Start a New Game** → press **TAB**
8. Hover over desired **Game Mode** → press **TAB**

**Controls**
- **TAB** = Confirm step  
- **ESC** = Cancel setup

**Why two “Yes” buttons?**
- < 1 Minute: No confirmation prompt appears  
- > 1 Minute: Confirmation moves the Yes button lower

After setup:
- Saves to the same folder as the .exe/ahk and saves as "ResetMacro.ini"
  - Can use a Preset as long as its named "ResetMacro.ini" 
     and in the correct folder it will use those settings.
- Enter a hotkey below *Setup Macro* → click **Set Hotkey**.
- Press that hotkey to trigger the reset macro sequence.


[5] Hardcore Save Deleter
────────────────────
- **Toggle ON/OFF**

When **ON:**
- After a reset, once the macro detects the Main Menu,
  your most recent save is automatically deleted.

When **OFF:**
- Only the reset macro runs — no saves are deleted.


[6] Speedrun Timer
────────────────────
- **Toggle ON/OFF**
  - When ON → Timer overlay appears (top-right by default)
  - When OFF → Timer overlay is removed

**Timer Settings**
- Launches a GUI to configure:
  - Timer position, color, and font size
  - Hotkeys for Start, Pause, Reset
  - Toggle AutoStart and configure AutoStart pixel detection
  - All this Saves to a .ini next to the .exe/ahk

[7] Save File Installer
────────────────────
- Opens GUI to configure and install practice save files.
- Reads the `Save Files` folder in the GUI directory.
- Select a category and save file from the dropdown → press **Install**.
- Installs into your currently active game version.

================================================================
▶ NOTES & LIMITATIONS
================================================================

- If **"SSGUI-Normal.exe"** fails to launch, install **AutoHotkey v1**.
- A 6-second delay is built into Restart and Version Switching:
  - Allows Steam time to fully close and unlock files.
  - Manual closing may be required if Steam is slow.
- Reset Macro + Hardcore Save Deleter = **Permanent deletion** of saves.
  - Running the Reset Macro on the Main Menu while Hardcore Save Deleter is ON 
     may delete other saves unintentionally. 
  - Should be used ONLY when resetting for Hardcore just to be safe.
- RNG Toggle may not work depending on your mod installation.
- Save File Installer may require administrator privileges.
- GUI ↔ AHK communication depends on `command.txt`.
  - Do not delete or interfere with this file.

──────────────────────────────────────────────────────────────
