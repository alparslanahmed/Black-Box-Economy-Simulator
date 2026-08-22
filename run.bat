@echo off
setlocal
if not exist build\blackbox.exe (
    call "%~dp0build.bat"
    if errorlevel 1 exit /b 1
)
if not exist build\raylib.dll (
    copy /Y "%USERPROFILE%\odin\dist\vendor\raylib\windows\raylib.dll" build\raylib.dll >nul
)
pushd "%~dp0"
build\blackbox.exe %*
popd
endlocal
