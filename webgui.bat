@echo off
setlocal enabledelayedexpansion
start http://127.0.0.1:65430/gui.html
tools\websocketd --port=65430 --maxforks=1 --staticdir=tools\ exec.bat