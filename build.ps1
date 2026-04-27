$env:JAVA_HOME = "C:\Progra~1\Huawei\DevEc~1\jbr"
$env:PATH = "$($env:JAVA_HOME)\bin;" + $env:PATH

Write-Host "JAVA_HOME: $env:JAVA_HOME"
Write-Host "PATH: $env:PATH"

& "E:\Program\OH\Harmony-os-build\command-line-tools\bin\hvigorw.bat" assembleApp