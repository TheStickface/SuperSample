$standardLog = "$env:APPDATA\Factorio\factorio-current.log"
$fallbackLog  = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "factorio-current.log"

$logPath = if (Test-Path $standardLog) {
    $standardLog
} elseif (Test-Path $fallbackLog) {
    $fallbackLog
} else {
    Write-Output "No Factorio log found."
    Write-Output "  Checked: $standardLog"
    Write-Output "  Checked: $fallbackLog"
    exit 1
}

$version   = (Get-Content $logPath -TotalCount 1) -replace '^\s*[\d\.]+\s+', ''
$lastWrite = (Get-Item $logPath).LastWriteTime
$ageMin    = [Math]::Round(((Get-Date) - $lastWrite).TotalMinutes, 1)
$stale     = if ($ageMin -gt 10) { " [STALE: ${ageMin}m old - may not reflect latest run]" } else { "" }

$lines = Get-Content $logPath -Tail 1000

$errorIndices = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*[\d\.]+\s+Error') {
        $errorIndices += $i
    }
}

Write-Output "=== Factorio Log Error Report ==="
Write-Output "Log:      $logPath"
Write-Output "Modified: $lastWrite$stale"
Write-Output "Version:  $version"

if ($errorIndices.Count -eq 0) {
    Write-Output "Errors:   None found"
    Write-Output ""
    Write-Output "--- Log looks clean. Last 15 lines ---"
    $lines | Select-Object -Last 15 | ForEach-Object { Write-Output $_ }
    exit 0
}

Write-Output "Errors:   $($errorIndices.Count) total - showing last"
Write-Output ""

$lastIdx  = $errorIndices[-1]
$startIdx = [Math]::Max(0, $lastIdx - 5)
$endIdx   = [Math]::Min($lines.Count - 1, $lastIdx + 60)

Write-Output "--- Error Block (line $($lastIdx + 1) of $($lines.Count) tail) ---"
for ($i = $startIdx; $i -le $endIdx; $i++) {
    $line = $lines[$i]
    if ($line -match 'GhostCrafter') {
        Write-Output "> MOD: $line"
    } elseif ($line -match '^\s*[\d\.]+\s+Error') {
        Write-Output "> ERR: $line"
    } else {
        Write-Output "       $line"
    }
}
