$ErrorActionPreference='Stop'
$applicationRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('codex-wallpaper-skill-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $testRoot 'scripts'))|Out-Null
$powershellFile=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$wrapper=Join-Path $applicationRoot 'skill\codex-wallpaper\scripts\wallpaper.ps1'
try {
    foreach($name in @('control.cjs','settings-store.cjs','runtime.cjs')) {Copy-Item -LiteralPath (Join-Path $applicationRoot ('scripts\'+$name)) -Destination (Join-Path $testRoot 'scripts')}
    $original=(& node.exe (Join-Path $applicationRoot 'scripts\control.cjs') state|ConvertFrom-Json).settings
    $image=Join-Path $testRoot "星空 壁纸 & test'.jpg"
    Copy-Item -LiteralPath (Join-Path $applicationRoot 'app\assets\wallpaper-settings.png') -Destination $image
    $fixture=@{enabled=$true;imagePath=$image;brightness=1;blur=0;tint=0.36;scope='window'}
    [IO.File]::WriteAllText((Join-Path $testRoot 'settings.json'),($fixture|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    $result=& $powershellFile -NoProfile -ExecutionPolicy Bypass -File $wrapper -ApplicationRoot $testRoot -Transparency 75 -Blur 3
    if($LASTEXITCODE -ne 0) {throw 'Skill adjustment failed'}
    $state=$result|ConvertFrom-Json
    if($state.settings.imagePath -ne $image -or $state.settings.brightness -ne 1 -or $state.settings.scope -ne 'window' -or $state.settings.tint -ne 0.25 -or $state.settings.blur -ne 3) {throw 'Skill changed an unrelated value or corrupted a Unicode path'}
    if($state.live.applied) {throw 'Disconnected skill incorrectly claimed live application'}
    $state=(& $powershellFile -NoProfile -ExecutionPolicy Bypass -File $wrapper -ApplicationRoot $testRoot -Disable)|ConvertFrom-Json
    if($LASTEXITCODE -ne 0 -or $state.settings.enabled -or $state.settings.imagePath -ne $image) {throw 'Skill restore failed'}
    $state=(& $powershellFile -NoProfile -ExecutionPolicy Bypass -File $wrapper -ApplicationRoot $testRoot -Enable)|ConvertFrom-Json
    if($LASTEXITCODE -ne 0 -or -not $state.settings.enabled) {throw 'Skill enable failed'}
    $skills=Join-Path $testRoot 'installed-skills';$desktop=Join-Path $testRoot 'desktop'
    $installed=(& $powershellFile -NoProfile -ExecutionPolicy Bypass -File (Join-Path $applicationRoot 'scripts\install-integration.ps1') -SkillParent $skills -DesktopPath $desktop)|ConvertFrom-Json
    if($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $installed.shortcut)) {throw 'Integration installation failed'}
    $location=Get-Content -LiteralPath (Join-Path $installed.skill 'location.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if($location.applicationRoot -ne $applicationRoot) {throw 'Installed skill points to a different application'}
    $installedState=(& $powershellFile -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installed.skill 'scripts\wallpaper.ps1') -Status)|ConvertFrom-Json
    if($LASTEXITCODE -ne 0 -or $installedState.settings.imagePath -ne $original.imagePath) {throw 'Installed skill could not resolve actual software settings'}
    [void](& $powershellFile -NoProfile -ExecutionPolicy Bypass -File (Join-Path $applicationRoot 'scripts\install-integration.ps1') -SkillParent $skills -DesktopPath $desktop)
    if($LASTEXITCODE -ne 0) {throw 'Reinstallation failed'}
    Write-Output 'PASS: skill Unicode paths, relative updates, restore, saved-only status, installation, location, and reinstallation'
} finally {
    $resolved=[IO.Path]::GetFullPath($testRoot)
    $expectedPrefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar+'codex-wallpaper-skill-'
    if($resolved.StartsWith($expectedPrefix,[StringComparison]::OrdinalIgnoreCase)) {Remove-Item -LiteralPath $resolved -Recurse -Force}
}
