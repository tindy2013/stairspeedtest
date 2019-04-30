@echo off
title Stair Speedtest
setlocal enabledelayedexpansion

:init
call :killv2core
call :killssr
call :killss
call :readpref
set group=
set fasturl=
mkdir results>nul 2>nul

:main
echo Welcome to Stair Speedtest!
echo Which stair do you want to test today? (Supports single ss/ssr/v2ray link and their subscribe links) 
set /p link=Link: 
call :chklink "!link!"
if "%linktype%" == "vmess" (echo Found single v2ray link.&&goto singletest)
if "%linktype%" == "ss" (echo Found single ss link.&&goto singletest)
if "%linktype%" == "ssr" (echo Found single ssr link.&&goto singletest)
if "%linktype%" == "sub" goto subscribe
echo No valid link found. Press anykey to exit.
pause>nul
goto :eof

:singletest
call :readconf "!link!"
echo Server Group: !groupstr! Name: !ps!
echo Now performing tcping...
call :chkping %add% %port%
if "%pkloss%" == "100.00%%" (
echo Cannot connect to server. Skipping speedtest...
set speed=0.00KB
) else (
echo Now performing speedtest...
call :buildjson
call :runclient
call :perform
call :killclient
)
echo Statistics:
echo 	DL.Speed: %speed% Pk.Loss: %pkloss% Avg.Ping: %avgping%
echo.
echo Speedtest done. Press anykey to exit.
pause>nul
goto :eof

:subscribe
call :makelogname
echo Found subscribe link.
echo If you have imported an v2ray subscribe link which doesn't contain a Group Name, you can write a custom name below.
echo If you have imported an ss/ssr link which contains a Group Name, press Enter to skip.
set /p group=Group Name: 
echo.
for /f "delims=" %%i in ('tools\curl -L --silent "!link!"^|tools\speedtestutil sub') do (
for /f "delims=, tokens=1-5,*" %%a in ("%%i") do (set linktype=%%a&&set groupstr=%%b&&set ps=%%c&&set add=%%d&&set port=%%e&&set proxystr=%%f)
call :chkexcluderemark
call :chkincluderemark
call :batchtest
)
call :logeof
call :exportresult
echo Result png saved to "%logpath%.png".
echo Press anykey to exit.
pause>nul
goto :eof

:makelogname
for /f "tokens=1,2" %%i in ("%date%") do (
call :instr "/" "%%i"
if !retval! equ 0 (set curdate=%%i) else (set curdate=%%j)
)
for /f %%i in ("%time:~0,5%") do (
if "!time:~0,1!" == " " (set curtime=0%%i) else (set curtime=%%i)
)
set logname=%curdate:/=%-%curtime::=%
set logpath=results\%logname%
set logfile=%logpath%.log
echo group,remarks,loss,ping,avgspeed>%logfile%
goto :eof

:writelog
echo %groupstr%,%ps%,%pkloss%,%avgping%,%speed%>>"%logfile%"
goto :eof

:logeof
echo Generated at %curdate:/=-% %time% by Stair Speedtest>>"%logfile%"
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

:batchtest
if %excluded% equ 1 goto :eof
if %included% equ 0 goto :eof
echo.
if not "%group%" == "" set groupstr=%group%
echo Current Server Group: %groupstr% Name: %ps%
echo Now performing tcping...
call :chkping %add% %port%
if "%pkloss%" == "100.00%%" (
echo Cannot connect to server. Skipping speedtest...
set speed=0.00KB
) else (
echo Now performing speedtest...
call :buildjson
call :runclient
call :perform
call :killclient
)
echo Result: DL.Speed: %speed% Pk.Loss: %pkloss% Avg.Ping: %avgping%
call :writelog
goto :eof

:buildjson
echo %proxystr% > config.json
goto :eof

:readconf
for /f "delims=, tokens=1-5,*" %%a in ('echo "%~1" ^| tools\speedtestutil') do (set linktype=%%a&&set groupstr=%%b&&set ps=%%c&&set add=%%d&&set port=%%e&&set proxystr=%%f)
call :chkexcluderemark
call :chkincluderemark
goto :eof

:chkexcluderemark
set excluded=0
call :arrlength "exclude_remarks"
if %exclude_remarks_count% equ -1 goto :eof
for /L %%i in (0,1,%exclude_remarks_count%) do (
	if defined exclude_remarks%%i (
		call :instr "!exclude_remarks%%i!" "%ps%"
		if !retval! equ 0 set excluded=1
	)
)
goto :eof

:chkincluderemark
set included=0
call :arrlength "include_remarks"
if %include_remarks_count% equ -1 (set included=1&&goto :eof)
for /L %%i in (0,1,%include_remarks_count%) do (
	if defined include_remarks%%i (
		call :instr "!include_remarks%%i!" "%ps%"
		if !retval! equ 0 set included=1
	)
)
goto :eof

:runclient
if "%linktype%" == "vmess" call :runv2core
if "%linktype%" == "ss" call :runss
if "%linktype%" == "ssr" call :runssr
goto :eof

:runv2core
wscript tools\runv2core.vbs //B
call :sleep 3
goto :eof

:runss
cd tools
wscript runss.vbs //B
cd ..
call :sleep 3
goto :eof

:runssr
wscript tools\runssr.vbs //B
call :sleep 3
goto :eof

:killclient
if "%linktype%" == "vmess" call :killv2core
if "%linktype%" == "ss" call :killss
if "%linktype%" == "ssr" call :killssr
goto :eof

:killv2core
tskill v2-core>nul 2>nul
goto :eof

:killss
tskill ss-libev>nul 2>nul
tskill obfs-local>nul 2>nul
goto :eof

:killssr
tskill ssr-libev>nul 2>nul
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
goto :eof

:perform
set speed=00
tools\curl -m 3 -x socks5://127.0.0.1:65432 http://cachefly.cachefly.net/100mb.test -L -s>nul 2>nul
for /f %%i in ('tools\curl -m 10 -o test.test -x socks5://127.0.0.1:65432 https://download.microsoft.com/download/2/2/A/22AA9422-C45D-46FA-808F-179A1BEBB2A7/office2007sp3-kb2526086-fullfile-en-us.exe -L -s -skw "%%{speed_download}"') do set speed=%%i
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
echo %logfile% | tools\speedtestutil export tools\util.js>"%logpath%.htm"
cd results
..\tools\phantomjs ..\tools\simplerender.js "%logname%.htm" "%logname%.png"
cd ..
goto :eof

:readpref
for /f "eol=[ delims== tokens=1,2" %%i in (pref.ini) do (
set itemname=%%i
if not "!itemname:~0,1!" == ";" set !itemname!=%%j
)
goto :eof

:instr
echo "%~2"|find "%~1">nul
set retval=!errorlevel!
goto :eof

:chrinstr
set retval=0
for /f "delims=%~1 tokens=1" %%z in ("%~2") do if "%~2" == "%%z" set retval=1
goto :eof

:arrlength
set i=0
set arrname=%~1
:arrlengthloop
if defined %arrname%%i% (set /a i=%i%+1&&goto arrlengthloop)
set /a %arrname%_count=%i%-1
goto :eof

:placeholder
goto :eof
