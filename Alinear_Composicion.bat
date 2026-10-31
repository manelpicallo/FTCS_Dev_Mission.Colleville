@echo off
chcp 65001 >nul
title FTCS - Alineador Geometrico de Composiciones

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\align_composition.ps1"
