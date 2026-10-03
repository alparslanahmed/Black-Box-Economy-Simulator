@echo off
setlocal
pushd "%~dp0"
where go >nul 2>nul
if errorlevel 1 goto missinggo
where npm >nul 2>nul
if errorlevel 1 goto missingnode
if not exist build mkdir build
pushd frontend
call npm ci
if errorlevel 1 goto failedinner
call npm run build
if errorlevel 1 goto failedinner
popd
pushd backend
go build -o ..\build\blackbox-server.exe ./cmd/server
if errorlevel 1 goto failedinner
go build -o ..\build\simtool.exe ./cmd/simtool
if errorlevel 1 goto failedinner
go build -o ..\build\experiment.exe ./cmd/experiment
if errorlevel 1 goto failedinner
popd
echo Built backend and frontend. Start with run.bat.
popd
exit /b 0
:missinggo
echo Go 1.26 or newer is required on PATH.
goto failed
:missingnode
echo Node.js and npm are required on PATH.
goto failed
:failedinner
popd
:failed
popd
exit /b 1
