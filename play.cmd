@echo off
rem Starts the game with the keys from .env (conversations may call the paid API).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run-game.ps1"
