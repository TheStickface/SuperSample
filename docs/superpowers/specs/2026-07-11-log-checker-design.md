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

1. Resolve log path: `$env:APPDATA\Factorio\factorio-current.log`
2. If file does not exist → print clear message with path and exit
3. Read all lines
4. Extract Factorio version from line 0 (always present, useful for context)
5. Find all lines matching `^\s*[\d\.]+\s+Error` — Factorio's standard error format
6. **No errors found:** print "Log looks clean", show last 10 lines in case of non-standard failure
7. **Errors found:**
   - Print header: log path, Factorio version, total error count
   - Take last error index, extract `[index-5 .. index+60]` for context window (captures full Lua stack trace)
   - For each line in the window: if it contains "GhostCrafter", prefix with `> MOD:` to highlight
   - Print the annotated block

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

Claude Code loads this file when `/check-log` is typed. Content:

```markdown
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
