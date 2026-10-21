$ErrorActionPreference='Stop'
$env:PSModulePath=(Join-Path $PSHOME 'Modules')+[IO.Path]::PathSeparator+$env:PSModulePath
. (Join-Path $PSScriptRoot 'DesktopLauncher.ps1')
Start-WallpaperFromDesktop -ScriptPath (Join-Path $PSScriptRoot 'start-settings.ps1') -WorkingDirectory ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')))
