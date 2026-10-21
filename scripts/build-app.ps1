$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not (Test-Path -LiteralPath $compiler)) {throw '.NET Framework C# compiler is unavailable'}
$assetRoot=Join-Path $projectRoot 'app\assets'
[IO.Directory]::CreateDirectory($assetRoot)|Out-Null
& (Join-Path $PSScriptRoot 'New-WallpaperIcon.ps1')
$iconFile=Join-Path $assetRoot 'wallpaper-settings.ico'
$common=@('/nologo','/optimize+','/codepage:65001','/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll')
& $compiler @common /target:winexe ('/win32manifest:'+(Join-Path $projectRoot 'app\app.manifest')) ('/win32icon:'+$iconFile) ('/out:'+(Join-Path $projectRoot 'Codex 壁纸.exe')) (Join-Path $projectRoot 'app\WallpaperApp.cs')
if($LASTEXITCODE -ne 0) {throw 'Windows app compilation failed'}
& $compiler @common /target:exe /main:GuiSmoke ('/out:'+(Join-Path $projectRoot 'tests\gui-smoke.exe')) (Join-Path $projectRoot 'app\WallpaperApp.cs') (Join-Path $projectRoot 'tests\gui-smoke.cs')
if($LASTEXITCODE -ne 0) {throw 'UI verification compilation failed'}
Get-Item -LiteralPath (Join-Path $projectRoot 'Codex 壁纸.exe')|Select-Object FullName,Length
