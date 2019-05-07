@echo off
title Stair Speedtest Web GUI Backend
setlocal enabledelayedexpansion
start http://127.0.0.1:65430/gui.html
tools\websocketd --port=65430 --maxforks=1 --staticdir=tools\ speedtest.bat /rpc