param(
    [string]$ImagePath,
    [ValidateRange(0.1,2)][double]$Brightness,
    [ValidateRange(0,30)][double]$Blur,
    [ValidateRange(10,100)][double]$Transparency,
    [ValidateSet('window','chat')][string]$Scope,
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Status,
    [switch]$Start,
    [switch]$OpenSettings,
    [string]$ApplicationRoot
)
$ErrorActionPreference='Stop'
$env:PSModulePath=(Join-Path $PSHOME 'Modules')+[IO.Path]::PathSeparator+$env:PSModulePath
if($Enable -and $Disable) {throw 'Enable and Disable cannot be combined'}
if([string]::IsNullOrWhiteSpace($ApplicationRoot)) {
    $locationFile=Join-Path $PSScriptRoot '..\location.json'
    if(Test-Path -LiteralPath $locationFile) {
        $ApplicationRoot=(Get-Content -LiteralPath $locationFile -Raw -Encoding UTF8|ConvertFrom-Json).applicationRoot
    } else {$ApplicationRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))}
}
if(-not [IO.Path]::IsPathRooted($ApplicationRoot)) {throw 'An absolute application directory is required'}
$ApplicationRoot=[IO.Path]::GetFullPath($ApplicationRoot)
$controllerFile=Join-Path $ApplicationRoot 'scripts\control.cjs'
if(-not (Test-Path -LiteralPath $controllerFile)) {throw 'Wallpaper software is missing. Reinstall its skill after moving the application folder.'}
$change=@{}
if($PSBoundParameters.ContainsKey('ImagePath')) {$change.imagePath=$ImagePath;$change.enabled=$true}
foreach($name in @('Brightness','Blur','Transparency','Scope')) {
    if($PSBoundParameters.ContainsKey($name)) {$change[$name.ToLowerInvariant()]=$PSBoundParameters[$name]}
}
if($Enable) {$change.enabled=$true}
if($Disable) {$change.enabled=$false}
if($Status -and $change.Count -gt 0) {throw 'Use Status by itself, or omit it when changing settings'}
$nodeFile=Join-Path $env:ProgramFiles 'nodejs\node.exe'
if(-not (Test-Path -LiteralPath $nodeFile)) {$nodeFile=(Get-Command node.exe -ErrorAction Stop).Source}
function Invoke-WallpaperController {
    param([string]$Action,[string]$Payload='')
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$nodeFile
    # The only argument containing a path is a verified .cjs file; never pass user image paths through a shell.
    $info.Arguments='"'+$controllerFile+'" '+$Action
    $info.WorkingDirectory=$ApplicationRoot;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $info.RedirectStandardInput=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.StandardOutputEncoding=[Text.Encoding]::UTF8;$info.StandardErrorEncoding=[Text.Encoding]::UTF8
    $process=New-Object Diagnostics.Process
    $process.StartInfo=$info
    try {
        [void]$process.Start()
        $stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync()
        $bytes=([Text.UTF8Encoding]::new($false)).GetBytes($Payload)
        $process.StandardInput.BaseStream.Write($bytes,0,$bytes.Length)
        $process.StandardInput.BaseStream.Close()
        if(-not $process.WaitForExit(12000)) {$process.Kill();throw 'Wallpaper controller timed out'}
        $stdout=$stdoutTask.GetAwaiter().GetResult();$stderr=$stderrTask.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0) {throw $stderr.Trim()}
        return $stdout.Trim()
    } finally {$process.Dispose()}
}
if($change.Count -gt 0) {
    [void](Invoke-WallpaperController -Action 'apply' -Payload ($change|ConvertTo-Json -Compress))
    # Give the live loader a chance to acknowledge this exact settings revision.
    Start-Sleep -Milliseconds 1000
}
if($OpenSettings) {& (Join-Path $ApplicationRoot 'scripts\launch-settings.ps1')}
if($Start) {& (Join-Path $ApplicationRoot 'scripts\launch-live-wallpaper.ps1')}
Invoke-WallpaperController -Action 'state'
