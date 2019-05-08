@ECHO OFF
del /F /Q "C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*"
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& 'c:\scripts\ps1\DhcpWds.ps1'"
ECHO ***  Setup has finished..PLEASE RE-ENABLE LOGON..(press any key)***
PAUSE >nul
netplwiz
ECHO ***  Confirm All Features have been installed    ***
PAUSE