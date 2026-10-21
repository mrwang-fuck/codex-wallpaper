$ErrorActionPreference='Stop'
$applicationRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$applicationFile=Join-Path $applicationRoot 'Codex 壁纸.exe'
if(-not (Test-Path -LiteralPath $applicationFile)) {throw 'Wallpaper settings application is missing. Run build-app.ps1 first.'}
Start-Process -FilePath $applicationFile -WorkingDirectory $applicationRoot -WindowStyle Normal
