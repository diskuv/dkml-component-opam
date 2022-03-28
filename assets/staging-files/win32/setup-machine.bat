@echo off
@REM Microsoft way of getting around PowerShell permissions: https://github.com/microsoft/vcpkg/blob/71422c627264daedcbcd46f01f1ed0dcd8460f1b/bootstrap-vcpkg.bat
powershell.exe -NoProfile -ExecutionPolicy Bypass "& {& '%~dp0setup-machine.ps1' %*}"
exit /b %ERRORLEVEL%
