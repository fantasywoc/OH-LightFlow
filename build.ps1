$env:JAVA_HOME = "E:\Program\OH\Harmony-os-build\jdk-17"
$env:PATH = "E:\Program\OH\Harmony-os-build\jdk-17\bin;D:\Sofeware\DevEco Studio\tools\node;" + $env:PATH

Write-Host "JAVA_HOME: $env:JAVA_HOME"

& "E:\Program\OH\Harmony-os-build\command-line-tools\bin\hvigorw.bat" --stop-daemon
Write-Host "Starting build..."

& "E:\Program\OH\Harmony-os-build\command-line-tools\bin\hvigorw.bat" assembleApp