param([switch]$Resume)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = (Join-Path $PSHOME 'Modules') + [IO.Path]::PathSeparator + $env:PSModulePath
$patchRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workerScript = Join-Path $PSScriptRoot 'live-wallpaper.cjs'
$nodeExecutable = Join-Path $env:ProgramFiles 'nodejs\node.exe'
if (-not (Test-Path -LiteralPath $nodeExecutable)) {$nodeExecutable=(Get-Command node.exe -ErrorAction Stop).Source}
if([int](& $nodeExecutable -p "Number(process.versions.node.split('.')[0])") -lt 24) {throw 'Node.js 24 or newer is required'}
$installationFile=Join-Path $patchRoot 'installation.json'
if(-not (Test-Path -LiteralPath $installationFile)) {& (Join-Path $PSScriptRoot 'configure.ps1')}
$expectedExecutable = (Get-Content -LiteralPath $installationFile -Raw -Encoding UTF8 | ConvertFrom-Json).executable
if(-not (Test-Path -LiteralPath $expectedExecutable)) {& (Join-Path $PSScriptRoot 'configure.ps1');$expectedExecutable=(Get-Content -LiteralPath $installationFile -Raw -Encoding UTF8|ConvertFrom-Json).executable}
& $nodeExecutable (Join-Path $PSScriptRoot 'wallpaper.cjs') --on
if ($LASTEXITCODE -ne 0) { throw 'Wallpaper settings are invalid' }
$liveStatusPath = Join-Path $patchRoot 'live-status.json'
if (Test-Path -LiteralPath $liveStatusPath) {
    try {
        $previous = Get-Content -LiteralPath $liveStatusPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $processInfo = Get-CimInstance Win32_Process -Filter ('ProcessId=' + [int]$previous.pid)
        $validState = $previous.state -in @('waiting-for-codex-exit','starting-original','connecting-original','active','disabled','waiting-for-main','waiting-for-renderer')
        if ($validState -and $previous.executable -eq $expectedExecutable -and $null -ne $processInfo -and $processInfo.ExecutablePath -eq $nodeExecutable -and $processInfo.CommandLine.Contains($workerScript) -and -not $processInfo.CommandLine.Contains('--attach-port')) { exit 0 }
    } catch { }
}
$workerArguments = '"' + $workerScript + '"'
if ($Resume) { $workerArguments += ' --resume' }
$child = Start-Process -FilePath $nodeExecutable -WindowStyle Hidden -ArgumentList $workerArguments -WorkingDirectory $patchRoot -RedirectStandardOutput (Join-Path $patchRoot 'live-output.log') -RedirectStandardError (Join-Path $patchRoot 'live-error.log') -PassThru
@{pid=$child.Id;script=$workerScript;time=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $patchRoot 'live-controller.json') -Encoding UTF8
