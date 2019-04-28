@echo off
set /p link=
call speedtest.bat /rpc !link!
if %rpc% equ 1 echo {"info":"error","reason":"unhandled"}
goto :eof