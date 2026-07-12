---
description: Read the Factorio error log, identify what broke in SuperSample, and automatically fix the issue.
---
Run `powershell -ExecutionPolicy Bypass -File tools/check-log.ps1` and read the output.

If errors are found: identify the file and line in SuperSample, read that file, fix the error, and explain what went wrong.
If the log looks clean: say so and suggest checking if the mod is actually enabled in Factorio's mod list.
