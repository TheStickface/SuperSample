# GhostCrafter Log Checker — Design Spec
**Date:** 2026-07-11

## Summary

Developer tooling that lets you type `/check-log` in Claude Code and have Claude automatically read the Factorio error log, identify what broke in GhostCrafter, and fix it. Two components: a PowerShell filter script and a Claude Code slash command that wires them together.

---

## Goals

- One-keystroke error-to-fix pipeline: `/check-log` → Claude reads log → Claude fixes mod
- Filter out noise from the Factorio log (can be 10MB+) — only show the last error block
- Highlight GhostCrafter-specific lines so it's immediately obvious if it's our code
- Gracefully handle no errors, missing log file, and non-standard failures

---

## File Structure

```
GhostCrafter/
├── tools/
│   └── check-log.ps1          — log filter script
└── .claude/
    └── commands/
        └── check-log.md       — Claude Code slash command definition
```

---

## Component 1: `tools/check-log.ps1`

**Input:** None (reads `%APPDATA%\Factorio\factorio-current.log` directly)

**Output:** Printed to stdout — consumed by Claude via `! .\tools\check-log.ps1`

### Logic

1. **Resolve log path:** Check standard path (`$env:APPDATA\Factorio\factorio-current.log`). If missing, check fallback locations (e.g. workspace parent/sibling folders for a local portable install).
2. **Verify existence:** If file does not exist, print a clear message with path and exit.
3. **Read log efficiently:** 
   - Extract Factorio version from line 0 (read only 1 line using `-TotalCount 1`).
   - Read the last 1000 lines (using `-Tail 1000`) for error analysis to avoid performance issues on large files.
4. **Identify errors:** Search the trailing lines for standard Factorio errors matching the regex `^\s*[\d\.]+\s+Error`.
5. **No errors found:** Print "Log looks clean", and show the last 15 lines of the log in case of non-standard/unrecognized failures.
6. **Errors found:**
   - Print header: Log file path, last modified time (to verify log recency), Factorio version, and total error count.
   - Select the last error line's index in the trailing lines array.
   - Extract the context window around it using bounded bounds to prevent negative indexing or out-of-bounds slicing: `[Math]::Max(0, index - 5)` to `[Math]::Min(lines.count - 1, index + 60)`.
   - **Annotate/Highlight:** For each line in the context window, if it contains the mod name `"GhostCrafter"` or matches the standard `Error` pattern, prefix it with `> MOD:` or `> ERR:` respectively to highlight the issue.
   - Print the annotated block.

### Output format example

```
=== Factorio Log Error Report ===
Log:     C:\Users\...\AppData\Roaming\Factorio\factorio-current.log
Version: Factorio 2.0.x (build 1234, win64, steam)
Errors:  3 total — showing last

--- Error Block (line 847 of 1203) ---
   5.231 Loading mod GhostCrafter 0.1.0 (control.lua)
> MOD:    5.232 Error __GhostCrafter__/control.lua:76: attempt to index nil value
> MOD:    stack traceback:
> MOD:      __GhostCrafter__/control.lua:76: in function 'apply_character_modifiers'
   5.232 Error Util.cpp:73: Failed to load mods
```

---

## Component 2: `.claude/commands/check-log.md`

Claude Code loads this file when `/check-log` is typed. It includes YAML frontmatter to register command details for `/help`. Content:

```markdown
---
description: Read the Factorio error log, identify what broke in GhostCrafter, and automatically fix the issue.
---
Run `powershell -ExecutionPolicy Bypass -File tools/check-log.ps1` and read the output.

If errors are found: identify the file and line in GhostCrafter, read that file, fix the error, and explain what went wrong.
If the log looks clean: say so and suggest checking if the mod is actually enabled in Factorio's mod list.
```

---

## Edge Cases

| Scenario | Behavior |
|---|---|
| Log file doesn't exist | Clear message with expected path |
| No errors in log | "Log looks clean" + last 10 lines |
| Error is in Factorio engine, not our mod | Show block without MOD: prefix — Claude still sees it |
| Multiple errors | Show only the last (most recent) — earlier ones are usually stale |
| Stack trace longer than 60 lines | Truncated — sufficient for all standard Factorio error formats |

---

## Out of Scope

- Watching the log in real-time (file watcher)
- Auto-fixing without being asked
- Parsing errors from other mods

---

## Suggested Improvements

1. **Portable/Local Installation Fallback Detection:** If the log file is not found in the standard AppData folder (e.g. because the developer uses a portable zip installation), check sibling/parent directories of the workspace.
2. **Multi-Source Error and Exception Highlighting:** Extend the highlight tags so that the main `Error` line itself is highlighted (with `> ERR:`) in addition to mod-specific stack traces (with `> MOD:`). This makes the entry point of the traceback immediately clear.
3. **Stale Log & Lock Verification:** Display the log's last write time and warn if the log is stale (e.g. older than 10 minutes) or if Factorio is currently running, which might indicate the log file is partially locked or hasn't been written to disk yet.
