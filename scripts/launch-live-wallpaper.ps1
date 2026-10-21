param([switch]$Resume)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = (Join-Path $PSHOME 'Modules') + [IO.Path]::PathSeparator + $env:PSModulePath
. (Join-Path $PSScriptRoot 'DesktopLauncher.ps1')
$controllerArguments = if ($Resume) { '-Resume' } else { '' }
Start-WallpaperFromDesktop -ScriptPath (Join-Path $PSScriptRoot 'start-live-wallpaper.ps1') -Arguments $controllerArguments -WorkingDirectory ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')))
