param([string]$OutputPath)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = (Join-Path $PSHOME 'Modules') + [IO.Path]::PathSeparator + $env:PSModulePath
$processInfo = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $PID)
$parentProcess = Get-Process -Id $processInfo.ParentProcessId -ErrorAction Stop
$administrator = ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
[PSCustomObject]@{pid=$PID;parentPid=$parentProcess.Id;parentName=$parentProcess.ProcessName;administrator=$administrator} | ConvertTo-Json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
