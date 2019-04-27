# Stair Speedtest
A small script that can test the stairs' download speed, packet loss and latency. Supports single ss/ssr/v2ray links and their subscribe links.

**NOTICE: THIS SCRIPT USES SINGLE THREAD FOR SPEEDTEST, THEREFORE THE RESULT MAT BE DIFFERENT FROM SSRSPEED (WHICH USES 4X THREADS)!!**
## Usage
* JUST RUN THE SCRIPT, PASTE THE LINK AND GO! Then just wait till it completes.
* Results for subscribe link tests will be saved to a log file in the root folder.
* Exporting results to a PNG file is now available. You can choose whether or not to export it by the end of the test.
* An interactive HTML file with test results will also be generated with the PNG file. In this HTML, you can sort by name, ping, packet loss or average speed.
## Thanks
**This script is inspired by [NyanChanMeow](https://github.com/NyanChanMeow)'s original script [SSRSpeed](https://github.com/NyanChanMeow/SSRSpeed). From which I have learned quite a lot on how to rewrite the code, and it has provoded me with some critical information. THANK YOU FOR YOUR HARD-WORKING!!**

**Also thanks to [CareyWang](https://github.com/CareyWang) for his help and debug.**
## Known Bugs
* ~~Currently does not support http obfs in vmess link. (Clash doesn't support it at all, but will switch to v2ray-core soon to enable all v2ray functions.)~~ Already switched to v2ray-core. kcp and h2 support are on the way.
* ~~If encryption method is *chacha20* in ssr link, ssr client will crash and no speedtest result will be displayed. (This is a bug in ssr-native, the only solution by now is to switch to another client like ssr-libev. Will do it soon.)~~ Already switched to ssr-libev. But there might still be some unknown bugs. USE AT YOUR OWN RISK. Will add ccr-csharp client soon.
* ~~No obfs options for ss links. (Clash hardly supports it. Will switch to ss-libev soon.) (It would still be quite hard to analyze different kinds of ss links. ;) )~~ Switched to ss-libev with obfs supports.
## Future Functions
* Fast.com speedtest has been added to the script, but it is still under testing.
* ssr-csharp client implementation.
* Web GUI
## Licences
* [Tencent/rapidjson](https://github.com/Tencent/rapidjson) (MIT/BSD/JSON)
* [curl/curl](https://github.com/curl/curl) (Modified BSD)
* [tcping.exe](https://elifulkerson.com/projects/tcping.php) (GPL)
* [Dreamacro/clash](https://github.com/Dreamacro/clash) (MIT)
* [ShadowsocksR-Live/shadowsocksr-native](https://github.com/ShadowsocksR-Live/shadowsocksr-native) (GNU)
* [shadowsocksrr/shadowsocksr-libev](https://github.com/shadowsocksrr/shadowsocksr-libev) (GNU)
* [shadowsocks/shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev) (GNU)
