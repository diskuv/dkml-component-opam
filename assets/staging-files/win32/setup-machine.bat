@echo off

REM Find PWSH.EXE
where.exe /q pwsh.exe >NUL 2>NUL
if %ERRORLEVEL% neq 0 (
    goto NeedPowershellExe
)
FOR /F "tokens=* usebackq" %%F IN (`where.exe pwsh.exe`) DO (
SET "SETUP_INTERNAL_PWSHEXE=%%F"
)
"%SETUP_INTERNAL_PWSHEXE%" -NoLogo -Help >NUL 2>NUL
if %ERRORLEVEL% equ 0 (
    SET "SETUP_INTERNAL_POWERSHELLEXE=%SETUP_INTERNAL_PWSHEXE%"
    goto HavePowershellExe
)

REM Find Powershell.EXE
:NeedPowershellExe
FOR /F "tokens=* usebackq" %%F IN (`where.exe powershell.exe`) DO (
SET "SETUP_INTERNAL_POWERSHELLEXE=%%F"
)
"%SETUP_INTERNAL_POWERSHELLEXE%" -NoLogo -Help >NUL 2>NUL
if %ERRORLEVEL% neq 0 (
	echo.
	echo.Neither 'pwsh.exe' nor 'powershell.exe' were found. Make sure you have
	echo.PowerShell installed.
	echo.
	exit /b 1
)

:HavePowershellExe
@REM Microsoft way of getting around PowerShell permissions: https://github.com/microsoft/vcpkg/blob/71422c627264daedcbcd46f01f1ed0dcd8460f1b/bootstrap-vcpkg.bat
"%SETUP_INTERNAL_POWERSHELLEXE%" -NoProfile -ExecutionPolicy Bypass -Command "& {& '%~dp0setup-machine.ps1' %*; exit $LASTEXITCODE}"
exit /b %ERRORLEVEL%
