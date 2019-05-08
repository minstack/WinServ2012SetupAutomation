@ECHO OFF
ECHO Please deselect username and password required at logon
ECHO Press any key to launch netplwiz...
PAUSE >nul
netplwiz
ECHO **** netplwiz will launch at the end of the server setup ****
ECHO Press any key to start the setup...
PAUSE >nul

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\ps1\start.ps1'"
PAUSE