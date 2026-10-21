$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output=Join-Path $projectRoot '.test-output'
[void][IO.Directory]::CreateDirectory($output)
& (Join-Path $projectRoot 'tests\gui-smoke.exe') $projectRoot (Join-Path $projectRoot 'app\assets\wallpaper-settings.png') (Join-Path $output 'settings-preview.png')
if($LASTEXITCODE -ne 0) {throw 'Native UI verification failed'}
