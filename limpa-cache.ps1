Stop-Service wuauserv -Force
Stop-Service bits -Force
Stop-Service cryptsvc -Force

Remove-Item "C:\Windows\SoftwareDistribution" -Recurse -Force
Remove-Item "C:\Windows\System32\catroot2" -Recurse -Force

Start-Service wuauserv
Start-Service bits
Start-Service cryptsvc


