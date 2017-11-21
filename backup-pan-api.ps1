# Windows Powershell Script for backing up a PAN firewall cluster
# cURL binary needed. Alternatively (with Powershell 3), the invoke-webrequest method may be used.
#
# Backup using Unix/Linux intentionally not mentioned here (too easy)... 
#
# To get API key see
# https://www.paloaltonetworks.com/documentation/71/pan-os/xml-api/get-started-with-the-pan-os-xml-api/get-your-api-key
#
# Michael Goessmann Matos, NTT Security
# Juli 2015 

$Index1 = 0
$Gen = 30
Start-Sleep -s 1
$TimeStamp = get-date -uformat %V
$Directory = "C:\Temp\"
$CurlBin = "c:\Tools\cURL\AMD64\curl.exe"

invoke-expression -command "$CurlBin -o $Directory\fw1-backup-$TimeStamp.xml -k ""https://<FW1 FQDN>/esp/restapi.esp?type=config&action=show&key=<XML API Key>"""
invoke-expression -command "$CurlBin -o $Directory\fw2-backup-$TimeStamp.xml -k ""https://<FW2 FQDN>/esp/restapi.esp?type=config&action=show&key=<XML API Key>"""
