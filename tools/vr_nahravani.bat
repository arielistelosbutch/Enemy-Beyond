@echo off
rem Nahravani pohybu z oci ve VR (Oculus Rift pres OpenXR) - Operace X
rem Poprve: pretahni na tento soubor Godot .exe (cesta se zapamatuje v godot_cesta.txt).
rem V Oculus aplikaci: Nastaveni > Obecne > OpenXR Runtime = Oculus (aktivni).
setlocal
cd /d "%~dp0.."
set "G="
if not "%~1"=="" set "G=%~1"
if "%G%"=="" if exist "%~dp0godot_cesta.txt" set /p G=<"%~dp0godot_cesta.txt"
if "%G%"=="" (
  echo Nevim, kde je Godot. Pretahni Godot .exe mysi na tento soubor vr_nahravani.bat.
  pause
  exit /b 1
)
if not exist "%G%" (
  echo Godot nenalezen: %G%
  echo Pretahni spravny Godot .exe na tento soubor.
  del "%~dp0godot_cesta.txt" 2>nul
  pause
  exit /b 1
)
>"%~dp0godot_cesta.txt" echo %G%
rem Snimani prstu (Quest 3) se zapina jen pro toto spusteni pres override.cfg, project.godot zustava.
rem (override.cfg, ktery zbyl z minula - okno zavrene driv nez Godot - je nas a pouzije se znovu)
set "OVR="
if exist override.cfg findstr /c:"hand_tracking" override.cfg >nul && del override.cfg
if exist override.cfg (
  echo Ve slozce hry je cizi override.cfg - snimani prstu se nezapne.
) else (
  > override.cfg echo [xr]
  >> override.cfg echo openxr/extensions/hand_tracking=true
  set "OVR=1"
)
echo Bezi nahravani ve VR. Toto okno nezaviraj, po skonceni se samo uklidi.
start "" /wait "%G%" --path "%CD%" --xr-mode on res://scenes/VrRecord.tscn
if defined OVR del override.cfg
