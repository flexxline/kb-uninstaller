
& {
    $ErrorActionPreference = "Stop"
    $kb = "KB5132061"
    $package = "Package_for_RollupFix~31bf3856ad364e35~amd64~~26100.9974.1.23"
    $Host.UI.RawUI.WindowTitle = "WINDOWS PATCH REMOVER | $kb"

    Clear-Host
    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |  WINDOWS PATCH REMOVER                           |" -ForegroundColor Cyan
    Write-Host "  |  TARGET: KB5132061                               |" -ForegroundColor White
    Write-Host "  +--------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ""

    $isAdmin = [Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "  [ERROR] Run PowerShell as Administrator." -ForegroundColor Red
        return
    }

    Write-Host "  [01] Checking Windows package..." -ForegroundColor Cyan

    try {
        $info = Get-WindowsPackage -Online -PackageName $package
    }
    catch {
        Write-Host "  [ERROR] Could not verify the package." -ForegroundColor Red
        return
    }

    if ($info.PackageState -ne "Installed") {
        Write-Host "  [STOP] Package is not installed." -ForegroundColor Yellow
        return
    }

    # Check the expected KB identity before removing anything.
    if ("$($info.Description) $($info.PackageName)" -notmatch "KB5132061") {
        Write-Host "  [STOP] Package identity could not be verified." -ForegroundColor Red
        return
    }

    Write-Host "  [OK] KB5132061 package verified." -ForegroundColor Green
    Write-Host "  [02] Starting DISM removal..." -ForegroundColor Cyan
    Write-Host ""

    $log = Join-Path $env:TEMP "KB5132061-removal.log"
    $arguments = @(
        "/Online"
        "/Remove-Package"
        "/PackageName:$package"
        "/NoRestart"
        "/Quiet"
        "/LogPath:$log"
    )

    try {
        $process = Start-Process -FilePath "$env:WINDIR\System32\dism.exe" `
            -ArgumentList $arguments -PassThru -WindowStyle Hidden
    }
    catch {
        Write-Host "  [ERROR] DISM could not start." -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)"
        return
    }

    $frames = @("|", "/", "-", "\")
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $i = 0

    while (-not $process.HasExited) {
        $frame = $frames[$i % $frames.Count]
        $seconds = [int]$watch.Elapsed.TotalSeconds

        Write-Host -NoNewline "`r  $frame Removing $kb ... elapsed ${seconds}s   " `
            -ForegroundColor Cyan

        Start-Sleep -Milliseconds 120
        $process.Refresh()
        $i++
    }

    $watch.Stop()
    $exitCode = $process.ExitCode

    Write-Host "`r$(' ' * 72)`r" -NoNewline
    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor DarkCyan

    if ($exitCode -eq 0) {
        Write-Host "  [SUCCESS] DISM removal completed." -ForegroundColor Green
    }
    elseif ($exitCode -eq 3010) {
        Write-Host "  [SUCCESS] Removal completed. Restart required." -ForegroundColor Yellow
    }
    else {
        Write-Host "  [FAILED] DISM exit code: $exitCode" -ForegroundColor Red
        Write-Host "  Windows may have blocked the removal." -ForegroundColor Yellow
    }

    Write-Host "  Time: $([int]$watch.Elapsed.TotalSeconds) seconds" -ForegroundColor Gray
    Write-Host "  Log: $log" -ForegroundColor Gray
    Write-Host "  +--------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ""
}
