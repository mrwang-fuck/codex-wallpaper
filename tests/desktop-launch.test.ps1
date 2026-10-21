$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\DesktopLauncher.ps1')
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-wallpaper-desktop-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$outputPath = Join-Path $testRoot 'child.json'
$fixture = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'fixtures\desktop-child.ps1'))
Start-WallpaperFromDesktop -ScriptPath $fixture -Arguments ('-OutputPath "' + $outputPath + '"') -WorkingDirectory $testRoot
$deadline = [DateTime]::UtcNow.AddSeconds(15)
while (-not (Test-Path -LiteralPath $outputPath)) {
    if ([DateTime]::UtcNow -ge $deadline) { throw 'The desktop child did not report its process ancestry' }
    Start-Sleep -Milliseconds 100
}
$child = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($child.parentName -ne 'explorer') { throw ('The launcher must use the desktop Explorer process; actual parent: ' + $child.parentName) }
if ($child.administrator -ne $false) { throw 'The installer controller must run as the normal desktop user' }
'PASS: actual child belongs to Explorer rather than Codex and runs without administrator privileges'
