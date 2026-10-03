@echo off
setlocal
pushd "%~dp0backend"
go test ./...
if errorlevel 1 goto failed
go vet ./...
if errorlevel 1 goto failed
popd
pushd "%~dp0frontend"
if not exist node_modules (
    call npm ci
    if errorlevel 1 goto failed
)
call npm run build
if errorlevel 1 goto failed
popd
echo All checks passed.
exit /b 0
:failed
popd
exit /b 1
