function Start-WallpaperFromDesktop {
    param([string]$ScriptPath, [string]$Arguments = '', [string]$WorkingDirectory)
    $hostExecutable = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $commandArguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $ScriptPath + '" ' + $Arguments
    $shellObject = New-Object -ComObject Shell.Application
    $windows = $null; $desktop = $null; $document = $null; $application = $null
    try {
        $windows = $shellObject.Windows()
        [int]$desktopHwnd = 0
        $desktop = $windows.FindWindowSW(0,$null,8,[ref]$desktopHwnd,1)
        if ($null -eq $desktop) { throw 'The Windows desktop Explorer process is unavailable' }
        $document = $desktop.Document
        $application = $document.Application
        $application.ShellExecute($hostExecutable,$commandArguments,$WorkingDirectory,'open',0)
    } finally {
        foreach ($reference in @($application,$document,$desktop,$windows,$shellObject)) {
            if ($null -ne $reference -and [Runtime.InteropServices.Marshal]::IsComObject($reference)) { [Runtime.InteropServices.Marshal]::ReleaseComObject($reference) | Out-Null }
        }
    }
}
