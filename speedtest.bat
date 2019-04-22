@echo off
title vpn speedtest
setlocal enabledelayedexpansion

:init
call :killclash
call :killssr
set group=
set fasturl=

:main
set /p link=link? 
call :chklink "%link%"
if "%linktype%" == "vmess" goto singlevmess
if "%linktype%" == "ss" goto singless
if "%linktype%" == "ssr" goto singlessr
if "%linktype%" == "sub" goto subscribe
echo no valid link found. press anykey to exit.
pause>nul
goto :eof

::::subs

:singlevmess
echo found vmess link.
echo.
goto clashtest

:singless
echo found ss link.
echo.
goto clashtest

:clashtest
call :readconf "!link!"
echo Server name: !ps!
echo testing speed and latency...
call :buildclash
call :runclash
call :perform
call :killclash
call :chkping %add% %port%
echo Statistics:
echo 	DL.Speed: %speed% Pk.Loss: %pkloss% Avg.Ping: %avgping%
echo.
echo press anykey to exit.
pause>nul
goto :eof

:singlessr
echo found ssr link.
echo.
call :readconf "!link!"
echo Server Group: !groupstr! Name: !ps!
echo testing speed and latency...
call :buildssr
call :runssr
call :perform
call :killssr
call :chkping %add% %port%
echo Statistics:
echo 	DL.Speed: %speed% Pk.Loss: %pkloss% Avg.Ping: %avgping%
echo.
echo press anykey to exit.
pause>nul
goto :eof

:subscribe
call :makelogname
echo found subscribe link.
echo please customize your group name. press enter to skip.
set /p group=group name: 
echo.
for /f "delims=" %%i in ('tools\curl --silent "!link!"^|tools\speedtestutil sub') do (
call :chklink "%%i"
if "!linktype!" == "vmess" call :batchclash "%%~i"
if "!linktype!" == "ss" call :batchclash "%%~i"
if "!linktype!" == "ssr" call :batchssr "%%~i"
)
call :logeof
choice /M "end of file. do you want to export result to .png file?"
if %errorlevel% equ 1 call :exportresult
if %errorlevel% equ 2 goto :eof
echo press anykey to exit.
pause>nul
goto :eof

::::functions

:makelogname
for /f "tokens=1" %%i in ("%date%") do set curdate=%%i
set curdate=%curdate:/=%
for /f "tokens=*" %%i in ('time /T') do set curtime=%%i
set logname=%curdate%-%curtime::=%
set logfile=%logname%.log
rem echo group,remarks,loss,ping,avgspeed>%logfile%
goto :eof

:writelog
echo %groupstr%,%ps%,%pkloss%,%avgping%,%speed%>>%logfile%
goto :eof

:logeof
for /f %%i in ("%date:/=-%") do set curdate=%%i
echo Generated at %curdate% %time%>>%logfile%
goto :eof

:chklink
set linktype=nothing
call :instr "http" "%~1"
if %retval% equ 0 (set linktype=sub&&goto :eof)
call :instr "vmess://" "%~1"
if %retval% equ 0 (set linktype=vmess&&goto :eof)
call :instr "ss://" "%~1"
if %retval% equ 0 (set linktype=ss&&goto :eof)
call :instr "ssr://" "%~1"
if %retval% equ 0 (set linktype=ssr&&goto :eof)
goto :eof

:batchclash
echo.
call :readconf %1
if not "%group%" == "" set groupstr=%group%
echo Current Server Group: %groupstr% Name: %ps%
echo.
call :buildclash
call :runclash
call :perform
call :killclash
call :chkping %add% %port%
echo Result: DL.Speed: %speed% Pk.Loss: %pkloss% Avg.Ping: %avgping%
call :writelog
echo.
goto :eof

:batchssr
echo.
call :readconf %1
if not "%group%" == "" set groupstr=%group%
echo Current Server Group: %groupstr% Name: %ps%
echo.
call :buildssr
call :runssr
call :perform
call :killssr
call :chkping %add% %port%
echo Result: DL.Speed: %speed% Pk.Loss: %pkloss% Avg.Ping: %avgping%
call :writelog
echo.
goto :eof

:instr
echo "%~2"|find "%~1">nul
set retval=!errorlevel!
goto :eof

:chrinstr
set retval=0
for /f "delims=%~1 tokens=1" %%z in ("%~2") do if "%~2" == "%%z" set retval=1
goto :eof

:buildclash
echo socks-port: 65432 > config.yml
echo mode: Rule >> config.yml
echo allow-lan: true >> config.yml
echo Proxy: >> config.yml
echo %proxystr% >> config.yml
echo Rule: >> config.yml
echo - MATCH,proxy >> config.yml
goto :eof

:buildssr
echo %proxystr% > config.json
goto :eof

:readconf
for /f "delims=, tokens=1-4,*" %%a in ('echo "%~1"^|tools\speedtestutil') do (set groupstr=%%a&&set ps=%%b&&set add=%%c&&set port=%%d&&set proxystr=%%e)
goto :eof

:buildssconf
goto :eof

:runclash
wscript tools\runclash.vbs //B
call :sleep 3
goto :eof

:runssr
wscript tools\runssr.vbs //B
call :sleep 3
goto :eof

:killclash
tskill clash>nul 2>nul
goto :eof

:killssr
tskill ssr-local>nul 2>nul
goto :eof

:sleep
ping -n %1 127.1>nul 2>nul
goto :eof

:chkping
set avgping=0.00
set pkloss=100.00%%
for /f "tokens=*" %%i in ('tools\tcping -n 6 -i 1 %1 %2') do (
call :instr "Average" "%%~i"
if !retval! equ 0 set avgping=%%i
call :instr "Was unable to connect" "%%~i"
if !retval! equ 0 goto :eof
call :instr " fail" "%%~i"
if !retval! equ 0 set pklossstr=%%i
)
for /f "delims=( tokens=2" %%j in ("%pklossstr%") do (
set pkloss=%%~j
set pkloss=!pkloss:~0,-6!
)
for /f "delims== tokens=4" %%j in ("%avgping%") do (
set avgping=%%~j
set avgping=!avgping:ms=!
set avgping=!avgping:~1,-1!
)
rem for /f %%k in ("%retstr%") do set avgping=%%k
goto :eof

:perform
set speed=00
for /f %%i in ('tools\curl -m 15 -o test.test -x socks5://127.0.0.1:65432 http://cachefly.cachefly.net/100mb.test -L -s -skw "%%{speed_download}"') do set speed=%%i
rem http://updates-http.cdn-apple.com/2019SpringFCS/fullrestores/091-79183/ECD07652-499F-11E9-99DE-E74576CE070F/iPhone11,8_12.2_16E227_Restore.ipsw
rem http://cachefly.cachefly.net/100mb.test
rem https://download.microsoft.com/download/2/2/A/22AA9422-C45D-46FA-808F-179A1BEBB2A7/office2007sp3-kb2526086-fullfile-en-us.exe
set speed=%speed:.00=%
if "%speed%" == "00" (set speed=0.00KB&&goto :eof)
set speeddec=%speed:~-7%
if "%speeddec%" == "%speed%" (
set speeddec=%speed:~-4%
set speed=%speed:~0,-4%.%speeddec:~0,2%KB
) else (
set speed=%speed:~0,-7%.%speeddec:~0,2%MB
)
goto :eof

:performfast
set speed=00
tools\curl -o fast.htm --silent -x socks5://127.0.0.1:65432 https://fast.com
for /f "tokens=*" %%i in ('echo placeholder ^| tools\speedtestutil fastpage') do set script=%%i
tools\curl -o fast.js --silent -x socks5://127.0.0.1:65432 https://fast.com%script%
for /f %%i in ('echo placeholder ^| tools\speedtestutil fasttoken') do set token=%%i
for /f %%i in ('tools\curl --silent -x socks5://127.0.0.1:65432 "https://api.fast.com/netflix/speedtest?https=true&token=%token%&urlCount=1" ^| tools\speedtestutil fastjson') do set fasturl=%%i
for /f %%i in ('tools\curl -m 30 -o test.test -x socks5://127.0.0.1:65432 "%fasturl%" -L -s -skw "%%{speed_download}"') do set speed=%%i
set speed=%speed:.00=%
if "%speed%" == "00" (set speed=0.00KB&&goto :eof)
set speeddec=%speed:~-7%
if "%speeddec%" == "%speed%" (
set speeddec=%speed:~-4%
set speed=%speed:~0,-4%.%speeddec:~0,2%KB
) else (
set speed=%speed:~0,-7%.%speeddec:~0,2%MB
)
goto :eof

:exportresult
echo %logfile% | tools\speedtestutil export %logname%.htm
tools\phantomjs tools\simplerender.js %logname%.htm %logname%.png
goto :eof

:placeholder
goto :eof