@echo off
chcp 65001 >nul
powershell.exe -NoProfile -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File \"%~dp0src\ITSupportToolkit.ps1\"'"
