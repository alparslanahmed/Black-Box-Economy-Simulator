@echo off
setlocal
set "ODIN=%USERPROFILE%\odin\dist\odin.exe"
if not exist "%ODIN%" (
    echo Odin compiler not found at %ODIN%
    echo Install Odin or edit this script to point at odin.exe
    exit /b 1
)
if not exist build mkdir build
echo Building Black Box Economy Simulator...
"%ODIN%" build src -out:build\blackbox.exe -o:speed
if errorlevel 1 exit /b 1
copy /Y "%USERPROFILE%\odin\dist\vendor\raylib\windows\raylib.dll" build\raylib.dll >nul
echo.
echo Built build\blackbox.exe
echo Run with run.bat   or   build\blackbox.exe --help
endlocal
