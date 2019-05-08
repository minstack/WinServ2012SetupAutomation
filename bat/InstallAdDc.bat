@ECHO OFF
del /F /Q "C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*"
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& 'c:\scripts\ps1\AD.ps1'"
PAUSE