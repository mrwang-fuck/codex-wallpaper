$ErrorActionPreference='Stop'
$applicationRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$package=Get-AppxPackage -Name 'OpenAI.Codex'|Sort-Object Version -Descending|Select-Object -First 1
if($null -eq $package) {Write-Output 'SKIP: Codex Store installation is not present';exit 0}
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('codex-wallpaper-configure-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
try {
    [void](& (Join-Path $applicationRoot 'scripts\configure.ps1') -ApplicationRoot $testRoot)
    $recordFile=Join-Path $testRoot 'installation.json'
    $before=[IO.File]::ReadAllText($recordFile)
    $record=$before|ConvertFrom-Json
    if($record.executable -ne (Join-Path $package.InstallLocation 'app\ChatGPT.exe')) {throw 'Automatic installation discovery selected a different executable'}
    $unsigned=Join-Path $testRoot 'ChatGPT.exe';[IO.File]::WriteAllText($unsigned,'unsigned fixture')
    $rejected=$false
    try {& (Join-Path $applicationRoot 'scripts\configure.ps1') -ApplicationRoot $testRoot -ExecutablePath $unsigned} catch {$rejected=$true}
    if(-not $rejected -or [IO.File]::ReadAllText($recordFile) -ne $before) {throw 'An unsigned executable overwrote the verified installation record'}
    Write-Output 'PASS: Store discovery, OpenAI signature verification, and unsigned executable rejection'
} finally {
    $resolved=[IO.Path]::GetFullPath($testRoot)
    $prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar+'codex-wallpaper-configure-'
    if($resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) {Remove-Item -LiteralPath $resolved -Recurse -Force}
}
