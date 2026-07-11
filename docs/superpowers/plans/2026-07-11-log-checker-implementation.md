# Log Checker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `/check-log` slash command that runs a PowerShell filter script against the Factorio log and gives Claude everything needed to diagnose and fix mod errors in one step.

**Architecture:** Two files — `tools/check-log.ps1` reads the last 1000 lines of the Factorio log, finds and annotates the last error block, and handles missing/stale logs; `.claude/commands/check-log.md` is the Claude Code slash command that runs the script and instructs Claude to fix whatever it finds.

**Tech Stack:** PowerShell 5.1, Claude Code custom commands (YAML frontmatter + markdown).

---

### File Map

| File | Responsibility |
|---|---|
| `tools/check-log.ps1` | Locate log, extract last error block, annotate, print |
| `.claude/commands/check-log.md` | Slash command definition — runs script, directs Claude to fix errors |

---

### Task 1: `tools/check-log.ps1`

**Files:**
- Create: `tools/check-log.ps1`

- [ ] **Step 1: Create `tools/check-log.ps1`**

```powershell
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
$stale     = if ($ageMin -gt 10) { " [STALE: ${ageMin}m old — may not reflect latest run]" } else { "" }

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

Write-Output "Errors:   $($errorIndices.Count) total — showing last"
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
```

- [ ] **Step 2: Verify the script runs without errors**

```powershell
powershell -ExecutionPolicy Bypass -File tools/check-log.ps1
```

Expected (if Factorio has been run before): header lines with log path, version, modified time, and either error block or "Log looks clean".
Expected (if Factorio never run): "No Factorio log found." with two checked paths.

- [ ] **Step 3: Commit and push**

```
git add tools/check-log.ps1
git commit -m "feat: add check-log PowerShell script for Factorio error extraction"
git push
```

---

### Task 2: `.claude/commands/check-log.md`

**Files:**
- Create: `.claude/commands/check-log.md`

- [ ] **Step 1: Create `.claude/commands/check-log.md`**

```markdown
---
description: Read the Factorio error log, identify what broke in GhostCrafter, and automatically fix the issue.
---
Run `powershell -ExecutionPolicy Bypass -File tools/check-log.ps1` and read the output.

If errors are found: identify the file and line in GhostCrafter, read that file, fix the error, and explain what went wrong.
If the log looks clean: say so and suggest checking if the mod is actually enabled in Factorio's mod list.
```

- [ ] **Step 2: Verify the command appears in Claude Code**

In Claude Code, type `/` and look for `check-log` in the autocomplete list. It should show the description "Read the Factorio error log, identify what broke in GhostCrafter, and automatically fix the issue."

- [ ] **Step 3: Commit and push**

```
git add .claude/commands/check-log.md
git commit -m "feat: add /check-log Claude Code slash command"
git push
```
