@echo off
setlocal
if not exist "%~dp0build\blackbox-server.exe" (
    call "%~dp0build.bat"
    if errorlevel 1 exit /b 1
)
pushd "%~dp0backend"
echo Open http://127.0.0.1:8080 in your browser.
"%~dp0build\blackbox-server.exe" %*
set "BLACKBOX_EXIT=%ERRORLEVEL%"
popd
exit /b %BLACKBOX_EXIT%
