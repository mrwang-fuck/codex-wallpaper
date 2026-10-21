param([string]$ExecutablePath,[string]$ApplicationRoot)
$ErrorActionPreference='Stop'
$env:PSModulePath=(Join-Path $PSHOME 'Modules')+[IO.Path]::PathSeparator+$env:PSModulePath
if([string]::IsNullOrWhiteSpace($ApplicationRoot)) {$ApplicationRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))}
$ApplicationRoot=[IO.Path]::GetFullPath($ApplicationRoot)
if([string]::IsNullOrWhiteSpace($ExecutablePath)) {
    $package=Get-AppxPackage -Name 'OpenAI.Codex'|Sort-Object Version -Descending|Select-Object -First 1
    if($null -eq $package) {throw 'Codex Store installation not found. Supply -ExecutablePath with the full path to your signed Codex executable.'}
    $ExecutablePath=Join-Path $package.InstallLocation 'app\ChatGPT.exe'
}
if(-not [IO.Path]::IsPathRooted($ExecutablePath)) {throw 'An absolute Codex executable path is required'}
$resolved=(Resolve-Path -LiteralPath $ExecutablePath).ProviderPath
if([IO.Path]::GetFileName($resolved) -notin @('ChatGPT.exe','Codex.exe')) {throw 'Expected the executable from your Codex installation'}
$signature=Get-AuthenticodeSignature -LiteralPath $resolved
if($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or $signature.SignerCertificate.Subject -notmatch 'O="?OpenAI\b') {throw 'The executable must have a valid OpenAI Authenticode signature'}
$record=@{executable=$resolved;version=([Diagnostics.FileVersionInfo]::GetVersionInfo($resolved)).ProductVersion;configuredAt=[DateTime]::UtcNow.ToString('o')}
$encoding=[Text.UTF8Encoding]::new($false)
$recordFile=Join-Path $ApplicationRoot 'installation.json'
$temporary=$recordFile+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
try {
    [IO.File]::WriteAllText($temporary,($record|ConvertTo-Json),$encoding)
    if(Test-Path -LiteralPath $recordFile) {[IO.File]::Replace($temporary,$recordFile,$null)} else {[IO.File]::Move($temporary,$recordFile)}
} finally {if(Test-Path -LiteralPath $temporary) {Remove-Item -LiteralPath $temporary -Force}}
$record|ConvertTo-Json
