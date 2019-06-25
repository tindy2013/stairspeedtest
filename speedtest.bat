@echo off
setlocal enabledelayedexpansion

:init
if "%1" == "/rpc" (set rpc=1) else (set rpc=0)
mkdir results>nul 2>nul
mkdir temp>nul 2>nul
mkdir logs>nul 2>nul
set group=
set fasturl=
set traffic=0
set thread_count=4
call :makelogname
call :killall
call :readpref
call :parseinit
call :writelog "INFO" "Init completed."

:main
call :printout "welcome"
if "!rpc!" == "1" goto mainalt
title Stair Speedtest
set /p link=Link: 
goto recvlink

:mainalt
set /p input=
for /f "delims=^ tokens=1-6" %%i in ('echo "!input!"^|tools\misc\webstring local') do (
set link=%%i
set group=%%j
call :overrideconf "%%k" "speedtest_mode"
call :overrideconf "%%l" "preferred_ping_method"
call :overrideconf "%%m" "export_sort_method"
call :overrideconf "%%n" "export_with_maxspeed"
)
goto recvlink

:recvlink
call :writelog "INFO" "Received Link."
call :chklink "!link!"
if "!linktype!" == "vmess" (call :printout "foundvmess" && goto singletest)
if "!linktype!" == "ss" (call :printout "foundss" && goto singletest)
if "!linktype!" == "ssr" (call :printout "foundssr" && goto singletest)
if "!linktype!" == "sub" goto subscribe
call :writelog "ERROR" "No valid link found."
call :printout "unrecog"
call :logeof
call :printout "eof"
goto end

:singletest
call :parselink "!link!"
set id=0
call :testnode
call :printout "gotstats"
call :writelog "INFO" "Single node test completed."
call :logeof
call :printout "eof"
goto end

:subscribe
call :makeresult
call :printout "foundsub"
if not "!rpc!" == "1" (
set /p group=Group Name: 
)
call :parsesub "!link!"
set sub=1
set id=0
set totals=!linktype_count!
if "!totals!"=="-1" (
del /q "!resultfile!"
call :printout "nonodes"
call :writelog "ERROR" "No nodes are found in this subscription."
call :printout "eof"
goto :eof
)
for /l %%A in (0,1,!totals!) do (
call :testnode
set /a id=!id!+1
)
set /a totals=!totals!+1
call :calctraffic
call :writelog "INFO" "All nodes tested. Total/Online nodes: !totals!/!onlines! Traffic used: !trafficstr!"
call :resulteof
call :printout "picsaving"
call :exportresult
call :printout "picsaved"
call :logeof
call :printout "eof"
goto end

:parseinit
call :arrinit "linktype"
call :arrinit "groupstr"
call :arrinit "ps"
call :arrinit "add"
call :arrinit "port"
call :arrinit "proxystr"
goto :eof

:parselink
for /f "delims=, tokens=1-5,*" %%a in ('echo "%~1" ^| tools\misc\speedtestutil link !preferred_ss_client!_!preferred_ssr_client! !override_conf_port!') do (
call :arrappend "linktype" "%%a"
set strdata=%%b
call :arrappendalt "groupstr"
set strdata=%%c
call :arrappendalt "ps"
call :arrappend "add" "%%d"
call :arrappend "port" "%%e"
call :arrappend "proxystr" "%%f"
)
goto :eof

:parsesub
call :writelog "INFO" "Downloading subscription data..."
for /f "delims=" %%i in ('tools\network\wget -qO- "!link!"^|tools\misc\speedtestutil sub !preferred_ss_client!_!preferred_ssr_client! !override_conf_port!') do for /f "delims=, tokens=1-5,*" %%a in ("%%i") do (
set groupstr=%%b
set ps=%%c
call :chkignore
if !ignored! equ 0 (
call :arrappend "linktype" "%%a"
set strdata=%%b
call :arrappendalt "groupstr"
set strdata=%%c
call :arrappendalt "ps"
call :arrappend "add" "%%d"
call :arrappend "port" "%%e"
call :arrappend "proxystr" "%%f"
)
)
goto :eof

:testnode
set linktype=!linktype%id%!
set groupstr=!groupstr%id%!
set ps=!ps%id%!
set add=!add%id%!
set port=!port%id%!
set proxystr=!proxystr%id%!
if not "!group!" == "" set groupstr=!group!
call :printout "gotserver"
set strdata=Received server. Type: !linktype! Group: !groupstr! Name: !ps!
call :writelogalt "INFO"
call :printout "startping"
call :buildjson
call :runclient
call :chkping !add! !port!
if "!pkloss!" == "100.00%%" (
call :writelog "ERROR" "Cannot connect to this node."
call :printout "noconn"
set speed=0.00B
set maxspeed=0.00B
) else (
call :printout "gotping"
call :printout "startspeed"
call :perform
if "!speed!" == "0.00B" if not "!speedtest_mode!" == "pingonly" (
call :writelog "ERROR" "Speedtest returned no speed."
call :printout "retest"
call :perform
if "!speed!" == "0.00B" call :printout "nospeed"
)
call :printout "gotspeed"
call :printout "gotresult"
)
call :killclient
if "!sub!"=="1" (
if not "!speed!" == "0.00B" set /a onlines=!onlines!+1
call :writeresult
)
goto :eof

:end
if "!rpc!"=="1" goto :eof
echo Press anykey to exit.
pause >nul
goto :eof

rem /////CORE FUNCTIONS/////

:printout
if "!rpc!" == "1" (
call :printoutalt "%~1"
goto :eof
)
if "%~1"=="welcome" (
echo Welcome to Stair Speedtest
echo Which stair do you want to test today? (Supports single ss/ssr/v2ray link and their subscribe links) 
)
if "%~1"=="foundvmess" echo Found single v2ray link.
if "%~1"=="foundss" echo Found single ss link.
if "%~1"=="foundssr" echo Found single ssr link.
if "%~1"=="foundsub" (
echo Found subscribe link.
echo If you have imported an v2ray subscribe link which doesn't contain a Group Name, you can write a custom name below.
echo If you have imported an ss/ssr link which contains a Group Name, press Enter to skip.
)
if "%~1"=="unrecog" echo No valid link found. Please check your subscribe link.
if "%~1"=="gotserver" echo Current Server Group: !groupstr! Name: !ps!
if "%~1"=="startping" echo Now performing tcping...
if "%~1"=="noconn" echo Cannot connect to server. Skipping speedtest...
if "%~1"=="startspeed" echo Now performing speedtest...
if "%~1"=="retest" echo Speedtest returned no speed. Retesting...
if "%~1"=="nospeed" echo Speedtest returned no speed 2 times. Skipping...
if "%~1"=="gotresult" echo Result: DL.Speed: !speed! Max.Speed: !maxspeed! Pk.Loss: !pkloss! Avg.Ping: !avgping!
if "%~1"=="gotstats" (
echo Statistics:
echo 	DL.Speed: !speed! Max.Speed: !maxspeed! Pk.Loss: !pkloss! Avg.Ping: !avgping!
echo 	Traffic used: !trafficstr!
echo.
echo Speedtest done.
)
if "%~1"=="picsaving" echo Now exporting png.
if "%~1"=="picsaved" echo Result png saved to "!resultpath!.png".
if "%~1"=="nonodes" echo No nodes found. Please check your subscribe link.
goto :eof

:printoutalt
if "%~1"=="welcome" echo {"info":"started"}
if "%~1"=="foundvmess" echo {"info":"foundvmess"}
if "%~1"=="foundss" echo {"info":"foundss"}
if "%~1"=="foundssr" echo {"info":"foundssr"}
if "%~1"=="foundsub" echo {"info":"foundsub"}
if "%~1"=="unrecog" echo {"info":"error","reason":"norecoglink"}
if "%~1"=="eof" echo {"info":"eof"}
if "%~1"=="gotserver" echo {"info":"gotserver","id":!id!,"group":"!groupstr!","remarks":"!ps!"}|tools\misc\webstring
if "%~1"=="startping" echo {"info":"startping","id":!id!}
if "%~1"=="noconn" echo {"info":"error","reason":"noconnection","id":!id!}
if "%~1"=="gotping" echo {"info":"gotping","id":!id!,"ping":"!avgping!","loss":"!pkloss!"}
if "%~1"=="startspeed" echo {"info":"startspeed","id":!id!}
if "%~1"=="retest" echo {"info":"retest","id":!id!}
if "%~1"=="nospeed" echo {"info":"nospeed","id":!id!}
if "%~1"=="gotspeed" echo {"info":"gotspeed","id":!id!,"speed":"!speed!","maxspeed":"!maxspeed!"}
if "%~1"=="traffic" echo {"info":"traffic","size":"!traffic!"}
if "%~1"=="picsaving" echo {"info":"picsaving"}
if "%~1"=="picsaved" echo {"info":"picsaved","path":"%resultpath:\=\\%.png"}
if "%~1"=="nonodes" echo {"info":"error","reason":"nonodes"}
goto :eof

:makelogname
for /f "tokens=1,2" %%i in ("!date!") do (
call :instr "/" "%%i"
if !retval! equ 0 (set curdate=%%i) else (set curdate=%%j)
)
for /f %%i in ("%time:~0,5%") do (
if "!time:~0,1!" == " " (set curtime=0%%i) else (set curtime=%%i)
)
set logname=%curdate:/=%-%curtime::=%
set logfile=logs\!logname!.log
if "!rpc!" == "1" (echo [!date! !time!][INFO]Stair Speedtest started in Web GUI mode.>"!logfile!") else (echo [!date! !time!][INFO]Stair Speedtest started in CLI mode.>"!logfile!")
goto :eof

:makeresult
set resultpath=results\!logname!
set resultfile=!resultpath!.log
if "!export_with_maxspeed!" == "true" (echo group,remarks,loss,ping,avgspeed,maxspeed>!resultfile!) else (echo group,remarks,loss,ping,avgspeed>!resultfile!)
goto :eof

:writelog
echo [!date! !time!][%~1]%~2 >>"!logfile!"
goto :eof

:writelogalt
echo [!date! !time!][%~1]!strdata!>>"!logfile!"
goto :eof

:writeresult
if "!export_with_maxspeed!" == "true" (echo !groupstr!,!ps!,!pkloss!,!avgping!,!speed!,!maxspeed!>>"!resultfile!") else (echo !groupstr!,!ps!,!pkloss!,!avgping!,!speed!>>"!resultfile!")
goto :eof

:resulteof
echo Traffic used : !trafficstr!. Working Node(s) : [!onlines!/!totals!]>>"!resultfile!"
echo Generated at %curdate:/=-% !time!>>"!resultfile!"
echo By Stair Speedtest.>>"!resultfile!"
goto :eof

:logeof
call :writelog "INFO" "Program terminated."
echo --EOF-- >>"!logfile!"
goto :eof

:calctraffic
if "!traffic!" == "0" (set trafficstr=0.00KB&&goto :eof)
if !traffic! geq 1048576 (
rem no need to worry about accuracy, this is enough for 2 decimals
set /a traffic=!traffic!/1024*100/1024
set trafficdec=!traffic:~-2!
set /a traffic=!traffic!/100
rem fix inaccurate number caused by integer-only calculation
set /a trafficdec=!trafficdec!+1
set trafficstr=!traffic!.!trafficdec:~0,2!GB
) else (
if !traffic! geq 1024 (
set /a traffic=!traffic!*100/1024
set trafficdec=!traffic:~-2!
set /a traffic=!traffic!/100
rem fix inaccurate number caused by integer-only calculation
set /a trafficdec=!trafficdec!+1
set trafficstr=!traffic!.!trafficdec:~0,2!MB
) else (
set trafficstr=!traffic!.00KB
)
)
goto :eof

:chklink
set linktype=nothing
call :instr "http" "%~1"
if !retval! equ 0 (set linktype=sub&&goto :eof)
call :instr "vmess://" "%~1"
if !retval! equ 0 (set linktype=vmess&&goto :eof)
call :instr "ss://" "%~1"
if !retval! equ 0 (set linktype=ss&&goto :eof)
call :instr "ssr://" "%~1"
if !retval! equ 0 (set linktype=ssr&&goto :eof)
goto :eof

:buildjson
call :writelog "INFO" "Writing config file..."
echo !proxystr! > config.json
goto :eof

:chkexcluderemark
call :writelog "INFO" "Comparing exclude remarks..."
set excluded=0
call :arrlength "exclude_remarks"
if !exclude_remarks_count! equ -1 goto :eof
for /L %%i in (0,1,!exclude_remarks_count!) do (
	if defined exclude_remarks%%i (
		call :instr "!exclude_remarks%%i!" "!ps!"
		if !retval! equ 0 set excluded=1
	)
)
goto :eof

:chkincluderemark
call :writelog "INFO" "Comparing include remarks..."
set included=0
call :arrlength "include_remarks"
if !include_remarks_count! equ -1 (set included=1&&goto :eof)
for /L %%i in (0,1,!include_remarks_count!) do (
	if defined include_remarks%%i (
		call :instr "!include_remarks%%i!" "!ps!"
		if !retval! equ 0 set included=1
	)
)
goto :eof

:chkignore
call :chkexcluderemark
call :chkincluderemark
set ignored=0
if !excluded! equ 1 (goto nodeignored) else if !included! equ 0 (goto nodeignored) else (
set strdata=Node  !groupstr! - !ps!  has been added.
call :writelogalt "INFO"
call :sleep 0.3
goto :eof
)

:nodeignored
set /a id=!id!-1
set ignored=1
set strdata=Node  !groupstr! - !ps!  has been ignored and will not be tested.
call :writelogalt
call :sleep 0.3
goto :eof

:runclient
if "!linktype!" == "vmess" call :runv2core
if "!linktype!" == "ss" (
if not defined preferred_ss_client set preferred_ss_client=ss-csharp
if "!preferred_ss_client!" == "ss-csharp" call :runsswin
if "!preferred_ss_client!" == "ss-libev" call :runss
)
if "!linktype!" == "ssr" (
if not defined preferred_ssr_client set preferred_ssr_client=ssr-csharp
if "!preferred_ssr_client!" == "ssr-csharp" call :runssrwin
if "!preferred_ssr_client!" == "ssr-libev" call :runssr
)
goto :eof

:runv2core
call :writelog "INFO" "Starting up v2ray core..."
wscript tools\misc\runv2core.vbs //B
call :sleep 2
goto :eof

:runss
rem fix obfs-local
call :writelog "INFO" "Starting up shadowsocks-libev..."
cd tools\clients\shadowsocks-libev
wscript ..\..\misc\runss.vbs //B
cd ..\..\..
call :sleep 2
goto :eof

:runsswin
call :writelog "INFO" "Starting up shadowsocks-win..."
copy /y config.json tools\clients\shadowsocks-win\gui-config.json>nul 2>nul
start tools\clients\shadowsocks-win\shadowsocks-win.exe
goto :eof

:runssr
call :writelog "INFO" "Starting up shadowsocksr-libev..."
wscript tools\misc\runssr.vbs //B
call :sleep 2
goto :eof

:runssrwin
call :writelog "INFO" "Starting up shadowsocksr-win..."
copy /y config.json tools\clients\shadowsocksr-win\gui-config.json>nul 2>nul
start tools\clients\shadowsocksr-win\shadowsocksr-win.exe
goto :eof

:killclient
if "!linktype!" == "vmess" call :killv2core
if "!linktype!" == "ss" (
if not defined preferred_ss_client set preferred_ss_client=ss-csharp
if "!preferred_ss_client!" == "ss-csharp" call :killsswin
if "!preferred_ss_client!" == "ss-libev" call :killss
)
if "!linktype!" == "ssr" (
if not defined preferred_ssr_client set preferred_ssr_client=ssr-csharp
if "!preferred_ssr_client!" == "ssr-csharp" call :killssrwin
if "!preferred_ssr_client!" == "ssr-libev" call :killssr
)
goto :eof

:killall
call :killv2core
call :killss
call :killsswin
call :killssr
call :killssrwin
goto :eof

:killv2core
call :writelog "INFO" "Killing v2ray core..."
taskkill /f /im v2-core.exe>nul 2>nul
goto :eof

:killss
call :writelog "INFO" "Killing shadowsocks-libev..."
taskkill /f /im ss-libev.exe>nul 2>nul
taskkill /f /im obfs-local.exe>nul 2>nul
taskkill /f /im simple-obfs.exe>nul 2>nul
goto :eof

:killsswin
call :writelog "INFO" "Killing shadowsocks-win..."
taskkill /f /im shadowsocks-win.exe>nul 2>nul
taskkill /f /im obfs-local.exe>nul 2>nul
taskkill /f /im simple-obfs.exe>nul 2>nul
goto :eof

:killssr
call :writelog "INFO" "Killing shadowsocksr-libev..."
taskkill /f /im ssr-libev.exe>nul 2>nul
goto :eof

:killssrwin
call :writelog "INFO" "Killing shadowsocksr-win..."
taskkill /f /im shadowsocksr-win.exe>nul 2>nul
goto :eof

:chkping
if "!speedtest_mode!" == "speedonly" (
set avgping=0.00
set pkloss=0.00%%
goto :eof
)
if not defined preferred_ping_method set preferred_ping_method=tcping
if "!preferred_ping_method!" == "googleping" (call :googleping&&goto :eof)
if "!preferred_ping_method!" == "bingping" (call :bingping&&goto :eof)
if "!preferred_ping_method!" == "gstaticping" (call :gstaticping&&goto :eof) else (call :tcping %1 %2&&goto :eof)
goto :eof

:tcping
call :writelog "INFO" "Now performing TCP ping..."
set avgping=0.00
set pkloss=100.00%%
for /f "tokens=*" %%i in ('tools\network\tcping -n 6 -i 1 %1 %2') do (
call :writelog "RAW" "%%~i"
call :instr "Average" "%%~i"
if !retval! equ 0 set avgping=%%i
call :instr "Was unable to connect" "%%~i"
if !retval! equ 0 goto :eof
call :instr " fail" "%%~i"
if !retval! equ 0 set pklossstr=%%i
)
for /f "delims=( tokens=2" %%j in ("!pklossstr!") do (
set pkloss=%%~j
set pkloss=!pkloss:~0,-6!
)
for /f "delims== tokens=4" %%j in ("!avgping!") do (
set avgping=%%~j
set avgping=!avgping:ms=!
set avgping=!avgping:~1,-1!
)
call :writelog "INFO" "TCP Ping: !avgping!  Packet Loss: !pkloss!"
goto :eof

:googleping
call :writelog "INFO" "Now performing google ping..."
call :curlping "https://www.google.com" 200 0
goto :eof

:bingping
call :writelog "INFO" "Now performing bing ping..."
call :curlping "https://www.bing.com" 200 0
goto :eof

:gstaticping
call :writelog "INFO" "Now performing gstatic ping..."
call :curlping "https://www.gstatic.com/generate_204" 204 0
goto :eof

:curlping
if "%~2" == "" (set successcode=200) else (set successcode=%~2)
if "%~3" == "" (set errorcode=0) else (set errorcode=%~3)
set avgping=0
set pkloss=0
set losses=0
set pingval=0
for /L %%a in (0,1,5) do (
for /f "delims=, tokens=1-2" %%b in ('tools\network\curl -m 2 -o test.test -L -x socks5://127.0.0.1:65432 -s -skw "%%{time_connect},%%{http_code}" "%~1"') do (set pingval=%%b&&set retval=%%c&&call :procping)
if !retval! equ !successcode! set /a avgping=!avgping!+!pingval!/10
if !retval! equ !errorcode! set /a losses=!losses!+1
)
set /a avgping=!avgping!/6
set /a pkloss=!losses!*10000/6
if !pkloss! equ 10000 (
set avgping=0.00
set pkloss=100.00%%
goto :eof
) else (
set avgping=!avgping:~0,-2!.!avgping:~-2!
)
if !pkloss! equ 0 (set pkloss=0.00%%) else (set pkloss=!pkloss:~0,-2!.!pkloss:~-2!%%)
goto :eof

:procping
set pingval=!pingval:.=!
:procpingloop
set strtmp=!pingval:~0,1!
if "!strtmp!" == "0" (set pingval=!pingval:~1!&&goto procpingloop)
goto :eof

:perform
set speed=0.00B
set maxspeed=0.00B
if "!speedtest_mode!" == "pingonly" goto :eof
call :performfile
goto :eof

:performfile
call :writelog "INFO" "Now performing file download speed test..."
rem http://cachefly.cachefly.net/200mb.test
rem https://dl.google.com/dl/android/aosp/bonito-pd2a.190115.029-factory-aac5b874.zip
rem https://download.microsoft.com/download/2/0/E/20E90413-712F-438C-988E-FDAA79A8AC3D/dotnetfx35.exe
set testfile=https://download.microsoft.com/download/2/0/E/20E90413-712F-438C-988E-FDAA79A8AC3D/dotnetfx35.exe
for /f "delims=, tokens=1-3" %%i in ('tools\network\multithread-test -tc !thread_count! -nd -xa 127.0.0.1 -xp 65432 -tf !testfile!') do (
call :writelog "RAW" "%%~i,%%~j,%%~k"
set speed=%%i&&set maxspeed=%%j&&set /a traffic=!traffic!+%%k/1024
call :writelog "INFO" "Average speed: %%i  Max speed: %%j  Traffic used in bytes: %%k"
)
goto :eof

:exportresult
call :writelog "INFO" "Now exporting result..."
if not defined export_sort_method set export_sort_method=speed
echo !resultfile! | tools\misc\speedtestutil export tools\misc\util.js tools\misc\style.css !export_with_maxspeed!>"!resultpath!.htm"
cd results
..\tools\misc\phantomjs ..\tools\misc\render_alt.js "!logname!.htm" "!logname!.png" !export_sort_method!
cd ..
call :writelog "INFO" "Result saved to !resultpath!.png ."
goto :eof

:readpref
call :writelog "INFO" "Reading preferences..."
for /f "eol=[ delims== tokens=1,*" %%i in (pref.ini) do (
set itemname=%%i
if not "!itemname:~0,1!" == ";" (
set !itemname!=%%j
call :writelog "INFO" "Added preference item: !itemname!==%%j"
)
)
goto :eof

:overrideconf
if not "%~1"=="!%~2!" (
set !%~2!=%~1
call :writelog "INFO" "Override option: %~2==%~1"
)
goto :eof

rem /////BASIC FUNCTIONS/////

:sleep
tcping.exe -n 1 -w %1 -i 0 127.0.0.1 0 >nul 2>nul
goto :eof

:instr
echo "%~2"|find "%~1">nul
set retval=!errorlevel!
goto :eof

:arrinit
set arrname=%~1
set !arrname!_count=-1
goto :eof

:arrappend
set arrname=%~1
set arrcount=!%arrname%_count!
set /a arrcount=!arrcount!+1
set !arrname!!arrcount!=%~2
set !arrname!_count=!arrcount!
goto :eof

:arrappendalt
set arrname=%~1
set arrcount=!%arrname%_count!
set /a arrcount=!arrcount!+1
set !arrname!!arrcount!=!strdata!
set !arrname!_count=!arrcount!
goto :eof

:arrlength
set i=0
set arrname=%~1
:arrlengthloop
if defined !arrname!!i! (set /a i=!i!+1&&goto arrlengthloop)
set /a !arrname!_count=!i!-1
goto :eof

:placeholder
goto :eof
