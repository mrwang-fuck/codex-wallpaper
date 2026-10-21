param([string]$SkillParent,[string]$DesktopPath)
$ErrorActionPreference='Stop'
$env:PSModulePath=(Join-Path $PSHOME 'Modules')+[IO.Path]::PathSeparator+$env:PSModulePath
$applicationRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$applicationFile=Join-Path $applicationRoot 'Codex 壁纸.exe'
if(-not (Test-Path -LiteralPath $applicationFile)) {throw 'Build the application before installing shortcuts and skill'}
if([string]::IsNullOrWhiteSpace($SkillParent)) {
    $codexDataDirectory=if([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'} else {$env:CODEX_HOME}
    $SkillParent=Join-Path $codexDataDirectory 'skills'
}
if([string]::IsNullOrWhiteSpace($DesktopPath)) {$DesktopPath=[Environment]::GetFolderPath('Desktop')}
$skillFolder=[IO.Path]::GetFullPath((Join-Path $SkillParent 'codex-wallpaper'))
$markerFile=Join-Path $skillFolder 'managed.json'
$identity='codex-wallpaper-settings-v1'
if(Test-Path -LiteralPath $skillFolder) {
    if(-not (Test-Path -LiteralPath $markerFile)) {throw ('An unrelated skill already exists: '+$skillFolder)}
    if((Get-Content -LiteralPath $markerFile -Raw -Encoding UTF8|ConvertFrom-Json).identity -ne $identity) {throw 'Skill ownership marker mismatch'}
}
$shortcutFile=Join-Path $DesktopPath 'Codex 壁纸设置.lnk'
$shell=New-Object -ComObject WScript.Shell
try {
    if(Test-Path -LiteralPath $shortcutFile) {
        $existing=$shell.CreateShortcut($shortcutFile)
        if($existing.Description -ne 'Codex Wallpaper Settings (local)' -and $existing.TargetPath -ne $applicationFile) {throw 'An unrelated desktop shortcut already uses this name'}
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($existing)
    }
    foreach($folder in @($skillFolder,(Join-Path $skillFolder 'agents'),(Join-Path $skillFolder 'scripts'),$DesktopPath)) {[IO.Directory]::CreateDirectory($folder)|Out-Null}
    $sourceFolder=Join-Path $applicationRoot 'skill\codex-wallpaper'
    foreach($relative in @('SKILL.md','agents\openai.yaml','scripts\wallpaper.ps1')) {Copy-Item -LiteralPath (Join-Path $sourceFolder $relative) -Destination (Join-Path $skillFolder $relative) -Force}
    $encoding=[Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText((Join-Path $skillFolder 'location.json'),(@{applicationRoot=$applicationRoot}|ConvertTo-Json),$encoding)
    [IO.File]::WriteAllText($markerFile,(@{identity=$identity;version='1.0.0'}|ConvertTo-Json),$encoding)
    $shortcut=$shell.CreateShortcut($shortcutFile)
    $shortcut.TargetPath=$applicationFile;$shortcut.WorkingDirectory=$applicationRoot
    $dedicatedIcon=Join-Path $applicationRoot 'app\assets\wallpaper-settings.ico'
    $shortcut.IconLocation=if(Test-Path -LiteralPath $dedicatedIcon) {$dedicatedIcon+',0'} else {$applicationFile+',0'}
    $shortcut.Description='Codex Wallpaper Settings (local)';$shortcut.Save()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut)
} finally {[void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)}
@{skill=$skillFolder;shortcut=$shortcutFile;application=$applicationFile}|ConvertTo-Json
