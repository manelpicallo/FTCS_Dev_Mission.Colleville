@echo off
chcp 65001 >nul
title FTCS - Conversor de Composiciones a Doctrinas

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\convert_compositions.ps1"
