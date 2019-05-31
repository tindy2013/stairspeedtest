@echo off
setlocal enabledelayedexpansion

:init
if "%1" == "/rpc" set rpc=1
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
call :writelog "INFO" "Init completed."
if "!rpc!" == "1" goto mainalt

:main
title Stair Speedtest
echo Welcome to Stair Speedtest
echo Which stair do you want to test today? (Supports single ss/ssr/v2ray link and their subscribe links) 
set /p link=Link: 
call :writelog "INFO" "Received Link."
call :chklink "!link!"
if "!linktype!" == "vmess" (echo Found single v2ray link.&&goto singletest)
if "!linktype!" == "ss" (echo Found single ss link.&&goto singletest)
if "!linktype!" == "ssr" (echo Found single ssr link.&&goto singletest)
if "!linktype!" == "sub" goto subscribe
call :writelog "ERROR" "No valid link found."
call :logeof
echo No valid link found. Press anykey to exit.
pause>nul
goto :eof

:mainalt
set /p input=
for /f "delims=^ tokens=1,2" %%i in ('echo "!input!"^|tools\misc\webstring local') do (set link=%%i&&set group=%%j)
call :writelog "INFO" "Received Link. Group Name: !group!"
call :chklink "!link!"
if "!linktype!" == "vmess" (echo {"info":"foundvmess"}&&goto singletestalt)
if "!linktype!" == "ss" (echo {"info":"foundss"}&&goto singletestalt)
if "!linktype!" == "ssr" (echo {"info":"foundssr"}&&goto singletestalt)
if "!linktype!" == "sub" (echo {"info":"foundsub"}&&goto subscribealt)
call :writelog "ERROR" "No valid link found."
call :logeof
echo {"info":"error","reason":"norecoglink"}
echo {"info":"eof"}
goto :eof

:singletest
call :readconf "!link!"
echo Server Group: !groupstr! Name: !ps!
call :writelog "INFO" "Received server. Type: !linktype! Group: !groupstr! Name: !ps!"
echo Now performing tcping...
call :buildjson
call :runclient
call :chkping !add! !port!
if "!pkloss!" == "100.00%%" (
call :writelog "ERROR" "Cannot connect to this node."
echo Cannot connect to server. Skipping speedtest...
set speed=0.00B
set maxspeed=0.00B
) else (
echo Now performing speedtest...
call :perform
if "!speed!" == "0.00B" if not "!speedtest_mode!" == "pingonly" (
call :writelog "ERROR" "Speedtest returned no speed."
echo Speedtest returned no speed. Retesting...
call :perform
if "!speed!" == "0.00B" echo Speedtest returned no speed 2 times. Skipping...
)
)
call :killclient
call :calctraffic
call :writelog "INFO" "Result: Download Speed: !speed!  Max Speed: !maxspeed!  Packet Loss: !pkloss!  Average Ping: !avgping! Traffic used: !trafficstr!"
echo Statistics:
echo 	DL.Speed: !speed! Max.Speed: !maxspeed! Pk.Loss: !pkloss! Avg.Ping: !avgping!
echo 	Traffic used: !trafficstr!
echo.
echo Speedtest done. Press anykey to exit.
call :logeof
pause>nul
goto :eof

:singletestalt
call :readconf "!link!"
echo {"info":"gotserver","id":0,"group":"!groupstr!","remarks":"!ps!"}|tools\misc\webstring
call :writelog "INFO" "Received server. Type: !linktype! Group: !groupstr! Name: !ps!"
echo {"info":"startping","id":0}
call :buildjson
call :runclient
call :chkping !add! !port!
if "!pkloss!" == "100.00%%" (
call :writelog "ERROR" "Cannot connect to this node."
echo {"info":"error","reason":"noconnection","id":"0"}
set speed=0.00B
set maxspeed=0.00B
) else (
echo {"info":"gotping","id":"0","ping":"!avgping!","loss":"!pkloss!"}
echo {"info":"startspeed","id":"0"}
call :perform
if "!speed!" == "0.00B" if not "!speedtest_mode!" == "pingonly" (
call :writelog "INFO" "Speedtest returned no speed."
echo {"info":"retest","id":"0"}
call :perform
if "!speed!" == "0.00B" echo {"info":"nospeed","id":"0"}
)
)
call :killclient
call :writelog "INFO" "Result: Download Speed: !speed!  Max Speed: !maxspeed!  Packet Loss: !pkloss!  Average Ping: !avgping! Traffic used: !trafficstr!"
echo {"info":"gotspeed","id":0,"speed":"!speed!","maxspeed":"!maxspeed!"}
echo {"info":"traffic","size":"!traffic!"}
echo {"info":"eof"}
call :logeof
goto :eof

:subscribe
call :makeresult
echo Found subscribe link.
echo If you have imported an v2ray subscribe link which doesn't contain a Group Name, you can write a custom name below.
echo If you have imported an ss/ssr link which contains a Group Name, press Enter to skip.
set /p group=Group Name: 
echo.
set id=-1
set totals=0
set onlines=0
call :writelog "INFO" "Downloading subscription data..."
rem saving all subscribe data to a variable might cause problem, removed for now
rem for /f "tokens=*" %%i in ('tools\network\curl -L --silent "!link!"') do set subdata=%%i
rem if "!subdata!" == "" (
rem echo Nothing returned from subscribe link. Please check your subscribe link.
rem call :end
rem goto :eof
rem )
rem for /f "delims=" %%i in ('echo !subdata!^|tools\misc\speedtestutil sub') do (
for /f "delims=" %%i in ('tools\network\wget -t 1 -T 5 -qO- "!link!"^|tools\misc\speedtestutil sub !preferred_ss_client!_!preferred_ssr_client! !override_conf_port!') do (
for /f "delims=, tokens=1-5,*" %%a in ("%%i") do (set linktype=%%a&&set groupstr=%%b&&set ps=%%c&&set add=%%d&&set port=%%e&&set proxystr=%%f)
rem don't log sensitive info?
rem call :writelog "INFO" "Parsed link info: Group: !groupstr! Name: !ps! Address: !add! Port: !port!"
if not "!linktype!" == "" (
set /a id=!id!+1
set /a totals=!totals!+1
call :chkexcluderemark
call :chkincluderemark
call :batchtest
)
)
call :calctraffic
if !id! gtr -1 (
call :writelog "INFO" "All nodes tested. Total/Online nodes: !totals!/!onlines! Traffic used: !trafficstr!"
echo All nodes tested. Traffic used: !trafficstr!
echo Now exporting png.
call :resulteof
call :exportresult
echo Result png saved to "!resultpath!.png".
) else (
del /q "!resultfile!">nul 2>nul
echo No nodes found. Please check your subscribe link.
)
call :logeof
call :end
goto :eof

:subscribealt
call :makeresult
set id=-1
set totals=0
set onlines=0
echo {"info":"fetchingsub"}
call :writelog "INFO" "Downloading subscription data..."
rem for /f %%i in ('tools\network\wget -qO- "!link!"') do set subdata=%%i
rem if "!subdata!" == "" (
rem echo {"info":"error","reason":"invalidsub"}
rem echo {"info":"eof"}
rem goto :eof
rem )
rem echo {"info":"gotsub"}
rem for /f "delims=" %%i in ('echo !subdata!^|tools\misc\speedtestutil sub') do (
for /f "delims=" %%i in ('tools\network\wget -t 1 -T 5 -qO- "!link!"^|tools\misc\speedtestutil sub !preferred_ss_client!_!preferred_ssr_client! !override_conf_port!') do (
for /f "delims=, tokens=1-5,*" %%a in ("%%i") do (set linktype=%%a&&set groupstr=%%b&&set ps=%%c&&set add=%%d&&set port=%%e&&set proxystr=%%f)
rem don't log sensitive info?
rem call :writelog "INFO" "Parsed link info: Group: !groupstr! Name: !ps! Address: !add! Port: !port!"
if not "!linktype!" == "" (
set /a id=!id!+1
set /a totals=!totals!+1
call :chkexcluderemark
call :chkincluderemark
call :batchtestalt
)
)
if !id! gtr -1 (
call :writelog "INFO" "All nodes tested. Total/Online nodes: !totals!/!onlines! Traffic used: !trafficstr!"
call :calctraffic
call :resulteof
echo {"info":"picsaving"}
call :exportresult
echo {"info":"picsaved","path":"%logpath:\=\\%.png"}
) else (
del /q "!logfile!">nul 2>nul
echo {"info":"error","reason":"nonodes"}
)
call :logeof
echo {"info":"eof"}
goto :eof

:end
echo Press anykey to exit.
pause>nul
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

:batchtest
if !excluded! equ 1 goto :eof
if !included! equ 0 goto :eof
echo.
if not "!group!" == "" set groupstr=!group!
echo Current Server Group: !groupstr! Name: !ps!
call :writelog "INFO" "Received server. Type: !linktype! Group: !groupstr! Name: !ps!"
echo Now performing tcping...
call :buildjson
call :runclient
call :chkping !add! !port!
if "!pkloss!" == "100.00%%" (
call :writelog "ERROR" "Cannot connect to this node."
echo Cannot connect to server. Skipping speedtest...
set speed=0.00B
set maxspeed=0.00B
) else (
echo Now performing speedtest...
call :perform
if "!speed!" == "0.00B" if not "!speedtest_mode!" == "pingonly" (
call :writelog "ERROR" "Speedtest returned no speed."
echo Speedtest returned no speed. Retesting...
call :perform
if "!speed!" == "0.00B" echo Speedtest returned no speed 2 times. Skipping...
)
)
call :killclient
echo Result: DL.Speed: !speed! Max.Speed: !maxspeed! Pk.Loss: !pkloss! Avg.Ping: !avgping!
if not "!speed!" == "0.00B" set /a onlines=!onlines!+1
call :writeresult
goto :eof

:batchtestalt
if !excluded! equ 1 (set /a id=!id!-1&&goto :eof)
if !included! equ 0 (set /a id=!id!-1&&goto :eof)
if not "!group!" == "" set groupstr=!group!
echo {"info":"gotserver","id":!id!,"group":"!groupstr!","remarks":"!ps!"}|tools\misc\webstring
call :writelog "INFO" "Received server. Type: !linktype! Group: !groupstr! Name: !ps!"
echo {"info":"startping","id":!id!}
call :buildjson
call :runclient
call :chkping !add! !port!
echo {"info":"gotping","id":!id!,"ping":"!avgping!","loss":"!pkloss!"}
if "!pkloss!" == "100.00%%" (
call :writelog "ERROR" "Cannot connect to this node."
echo {"info":"error","reason":"noconnection","id":!id!}
set speed=0.00B
set maxspeed=0.00B
) else (
echo {"info":"startspeed","id":!id!}
call :perform
if "!speed!" == "0.00B" if not "!speedtest_mode!" == "pingonly" (
call :writelog "ERROR" "Speedtest returned no speed."
echo {"info":"retest","id":"!id!"}
call :perform
if "!speed!" == "0.00B" echo {"info":"nospeed","id":"!id!"}
)
)
call :killclient
echo {"info":"gotspeed","id":!id!,"speed":"!speed!","maxspeed":"!maxspeed!"}
if not "!speed!" == "0.00B" set /a onlines=!onlines!+1
call :writeresult
goto :eof

:buildjson
call :writelog "INFO" "Writing config file..."
echo !proxystr! > config.json
goto :eof

:readconf
for /f "delims=, tokens=1-5,*" %%a in ('echo "%~1" ^| tools\misc\speedtestutil link !preferred_ss_client!_!preferred_ssr_client! !override_conf_port!') do (set linktype=%%a&&set groupstr=%%b&&set ps=%%c&&set add=%%d&&set port=%%e&&set proxystr=%%f)
rem don't log sensitive info?
rem call :writelog "INFO" "Parsed link info: Group: !groupstr! Name: !ps! Address: !add! Port: !port!"
call :chkexcluderemark
call :chkincluderemark
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
call :sleep 3
goto :eof

:runss
rem fix obfs-local
call :writelog "INFO" "Starting up shadowsocks-libev..."
cd tools\clients\shadowsocks-libev
wscript ..\..\misc\runss.vbs //B
cd ..\..\..
call :sleep 3
goto :eof

:runsswin
call :writelog "INFO" "Starting up shadowsocks-win..."
copy /y config.json tools\clients\shadowsocks-win\gui-config.json>nul 2>nul
start tools\clients\shadowsocks-win\shadowsocks-win.exe
goto :eof

:runssr
call :writelog "INFO" "Starting up shadowsocksr-libev..."
wscript tools\misc\runssr.vbs //B
call :sleep 3
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

:sleep
ping -n %1 127.1>nul 2>nul
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
if not defined preferred_test_method set preferred_test_method=file
if "!preferred_test_method!" == "file" (call :performfile&&goto :eof)
if "!preferred_test_method!" == "fast.com" (call :performfast&&goto :eof)
goto :eof

:performfile
call :writelog "INFO" "Now performing file download speed test..."
rem http://cachefly.cachefly.net/200mb.test
rem https://dl.google.com/dl/android/aosp/bonito-pd2a.190115.029-factory-aac5b874.zip
rem https://download.microsoft.com/download/2/0/E/20E90413-712F-438C-988E-FDAA79A8AC3D/dotnetfx35.exe
set testfile=https://download.microsoft.com/download/2/0/E/20E90413-712F-438C-988E-FDAA79A8AC3D/dotnetfx35.exe
rem handshake first (but may cause problem)
rem tools\network\curl -m 1 -o test.test -x socks5://127.0.0.1:65432 !testfile! -L -s>nul 2>nul
rem then do the real testing
rem for /f "delims=, tokens=1-2" %%i in ('tools\network\curl -m 10 -o test.test -x socks5://127.0.0.1:65432 !testfile! -L -s -skw "%%{speed_download},%%{size_download}"') do (set speed=%%i&&set /a traffic=!traffic!+%%j/1024)
for /f "delims=, tokens=1-3" %%i in ('tools\network\multithread-test -tc !thread_count! -nd -xa 127.0.0.1 -xp 65432 -tf !testfile!') do (
call :writelog "RAW" "%%~i,%%~j,%%~k"
set speed=%%i&&set maxspeed=%%j&&set /a traffic=!traffic!+%%k/1024
call :writelog "INFO" "Average speed: %%i  Max speed: %%j  Traffic used in bytes: %%k"
)
rem no need to calculate
rem call :calcspeed
goto :eof

:performfast
call :writelog "INFO" "Now performing fast.com speed test..."
tools\network\curl -o fast.htm --silent -x socks5://127.0.0.1:65432 https://fast.com
for /f "tokens=*" %%i in ('echo placeholder ^| tools\misc\speedtestutil fastpage') do set script=%%i
tools\network\curl -o fast.js --silent -x socks5://127.0.0.1:65432 https://fast.com!script!
for /f %%i in ('echo placeholder ^| tools\misc\speedtestutil fasttoken') do set token=%%i
for /f %%i in ('tools\network\curl --silent -x socks5://127.0.0.1:65432 "https://api.fast.com/netflix/speedtest?https=true&token=!token!&urlCount=1" ^| tools\misc\speedtestutil fastjson') do set fasturl=%%i
for /d %%a in (0,1,2) do (
for /f "delims=, tokens=1-2" %%i in ('tools\network\curl -m 30 -o test.test -x socks5://127.0.0.1:65432 "!fasturl!" -L -s -skw "%%{speed_download},%%{size_download}"') do (set oncespeed=%%i&&set /a traffic=!traffic!+%%j/1024)
set oncespeed=!oncespeed:.000=!
set /a speed=!speed!+!oncespeed!
)
set /a speed=!speed!/3
call :calcspeed
goto :eof

:calcspeed
set speed=%speed:.000=%
if "!speed!" == "0" (set speed=0.00B&&goto :eof)
if !speed! geq 1048576 (
set /a speed=!speed!/1024*100/1024
set speeddec=!speed:~-2!
set /a speed=!speed!/100
set speed=!speed!.!speeddec:~0,2!MB
) else (
if !speed! geq 1024 (
set /a speed=!speed!*100/1024
set speeddec=!speed:~-2!
set /a speed=!speed!/100
set speed=!speed!.!speeddec:~0,2!KB
) else (
set speed=!speed!B
)
)
goto :eof

:exportresult
call :writelog "INFO" "Now exporting result..."
if not defined export_sort_method set export_sort_method=speed
echo !resultfile! | tools\misc\speedtestutil export tools\misc\util.js tools\misc\style.css !export_with_maxspeed!>"!resultpath!.htm"
cd results
rem ..\tools\misc\phantomjs ..\tools\misc\simplerender.js "!resultname!.htm" "!resultname!.png"
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
if defined !arrname!!i! (set /a i=!i!+1&&goto arrlengthloop)
set /a !arrname!_count=!i!-1
goto :eof

:placeholder
goto :eof
