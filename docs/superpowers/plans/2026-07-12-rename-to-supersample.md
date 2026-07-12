# Rename GhostCrafter → SuperSample Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the mod from "GhostCrafter" to "SuperSample" everywhere — internal Factorio mod ID, all in-repo files, the local dev folder, the GitHub repo, and the local Factorio installation — with nothing left pointing at the old name.

**Architecture:** This is a mechanical rename, not a feature change, so there's no TDD cycle. Each task edits a specific set of files or runs a specific command, followed by a verification step (grep for leftover references, or an observable check like `git remote -v` / the Factorio log). Order matters: in-repo content changes are committed and pushed *before* the folder/repo are renamed, so every git command in this plan runs against a still-valid path and remote.

**Naming convention (matches the existing GhostCrafter convention exactly):**
- PascalCase `SuperSample` replaces PascalCase `GhostCrafter` — used for: `info.json` `name`/`title`, the local folder name, the GitHub repo name.
- kebab-case `supersample` replaces kebab-case `ghost-crafter` — used for: custom-input names, the mod setting name, the locale scope section.

**Tech Stack:** Factorio 2.0 Lua mod, Git, GitHub CLI (`gh`), PowerShell (Windows junctions), Claude Code persistent memory.

**Decisions locked in for this plan (confirmed with user before writing it):**
1. Full rename including the internal Factorio mod ID (`info.json` `name` field) and all `ghost-crafter-*` keybind/setting/locale keys — not a cosmetic-only rename. Consequence accepted: the current test save (`PyOrDie.zip`) will show "GhostCrafter" as a removed mod and "SuperSample" as a new one on next load. This is a test save, not the live server, so this is a one-time non-issue.
2. The two dated historical docs (`docs/superpowers/plans/2026-07-11-ghost-crafter-implementation.md`, `docs/superpowers/specs/2026-07-11-ghost-crafter-design.md`) are **left untouched** — they're a record of what was built at that point in time, like commit messages. Do not edit them in this plan.

---

## File Structure

Files modified in the repo:
- `info.json` — mod identity (name, title)
- `data.lua` — custom-input names
- `settings.lua` — setting name
- `control.lua` — 6 reference sites to the old kebab-case keys
- `locale/en/locale.cfg` — control display names, setting name/description keys, locale scope section
- `tools/check-log.ps1` — hardcoded string match used to highlight mod lines in log output
- `.claude/commands/check-log.md` — prose references to the mod name

Filesystem / external state changed (not in-repo files):
- `C:\Dev\Factorio\GhostCrafter` → `C:\Dev\Factorio\SuperSample` (folder rename)
- `.claude/settings.local.json` — hardcoded absolute paths (local-only file, not committed; update after folder rename so paths stay valid)
- GitHub repo `TheStickface/GhostCrafter` → `TheStickface/SuperSample`
- `%APPDATA%\Factorio\mods\GhostCrafter` junction → recreated as `%APPDATA%\Factorio\mods\SuperSample`, pointing at the new folder path
- `%APPDATA%\Factorio\mods\mod-list.json` — entry renamed
- Claude persistent memory files (outside the repo, in the memory directory) — not part of git, handled as a final task

---

## Task 1: Rename mod identity in `info.json`

**Files:**
- Modify: `info.json`

- [ ] **Step 1: Replace the name and title fields**

Current content:
```json
{
  "name": "GhostCrafter",
  "version": "1.0.1",
  "title": "GhostCrafter",
  "author": "scorps",
  "description": "A keybind that acts as a smart pipette: picks up items you have, or queues a craft for items you don't.",
  "factorio_version": "2.0"
}
```

New content:
```json
{
  "name": "SuperSample",
  "version": "1.1.0",
  "title": "SuperSample",
  "author": "scorps",
  "description": "A keybind that acts as a smart pipette: picks up items you have, or queues a craft for items you don't.",
  "factorio_version": "2.0"
}
```

Version is bumped to `1.1.0` (not a patch) since the mod's identity itself is changing, not just a bugfix.

- [ ] **Step 2: Verify**

Run: `grep -n "GhostCrafter\|SuperSample" info.json`
Expected: both `"name"` and `"title"` show `SuperSample`, nothing shows `GhostCrafter`.

---

## Task 2: Rename custom-input keybind names in `data.lua`

**Files:**
- Modify: `data.lua`

- [ ] **Step 1: Replace all three custom-input names**

Current content:
```lua
data:extend({
  {
    type = "custom-input",
    name = "ghost-crafter-craft",
    key_sequence = "CAPSLOCK",
    consuming = "none",
  },
  {
    type = "custom-input",
    name = "ghost-crafter-craft-shift",
    key_sequence = "CONTROL + CAPSLOCK",
    consuming = "none",
  },
  {
    type = "custom-input",
    name = "ghost-crafter-craft-ctrl",
    key_sequence = "SHIFT + CAPSLOCK",
    consuming = "none",
  },
})
```

New content:
```lua
data:extend({
  {
    type = "custom-input",
    name = "supersample-craft",
    key_sequence = "CAPSLOCK",
    consuming = "none",
  },
  {
    type = "custom-input",
    name = "supersample-craft-shift",
    key_sequence = "CONTROL + CAPSLOCK",
    consuming = "none",
  },
  {
    type = "custom-input",
    name = "supersample-craft-ctrl",
    key_sequence = "SHIFT + CAPSLOCK",
    consuming = "none",
  },
})
```

- [ ] **Step 2: Verify**

Run: `grep -n "ghost-crafter" data.lua`
Expected: no output (no matches).

---

## Task 3: Rename the mod setting in `settings.lua`

**Files:**
- Modify: `settings.lua`

- [ ] **Step 1: Replace the setting name**

Current content:
```lua
data:extend({
  {
    type = "int-setting",
    name = "ghost-crafter-craft-count",
    setting_type = "runtime-per-user",
    default_value = 1,
    minimum_value = 1,
    maximum_value = 1000,
    order = "a",
  },
})
```

New content:
```lua
data:extend({
  {
    type = "int-setting",
    name = "supersample-craft-count",
    setting_type = "runtime-per-user",
    default_value = 1,
    minimum_value = 1,
    maximum_value = 1000,
    order = "a",
  },
})
```

- [ ] **Step 2: Verify**

Run: `grep -n "ghost-crafter" settings.lua`
Expected: no output.

---

## Task 4: Update all 6 reference sites in `control.lua`

**Files:**
- Modify: `control.lua:74`, `control.lua:118`, `control.lua:126`, `control.lua:132`, `control.lua:136`, `control.lua:140`

- [ ] **Step 1: Update the setting lookup key (line 74)**

Old: `    craft_count = settings.get_player_settings(player)["ghost-crafter-craft-count"].value,`
New: `    craft_count = settings.get_player_settings(player)["supersample-craft-count"].value,`

- [ ] **Step 2: Update the two locale keys (lines 118, 126)**

Old:
```lua
      text     = {"ghost-crafter.queued", queued, display_name},
```
New:
```lua
      text     = {"supersample.queued", queued, display_name},
```

Old:
```lua
      text     = {"ghost-crafter.missing-materials"},
```
New:
```lua
      text     = {"supersample.missing-materials"},
```

- [ ] **Step 3: Update the three event registrations (lines 132, 136, 140)**

Old:
```lua
script.on_event("ghost-crafter-craft", function(event)
  handle_craft_action(game.players[event.player_index], 1)
end)

script.on_event("ghost-crafter-craft-shift", function(event)
  handle_craft_action(game.players[event.player_index], 5)
end)

script.on_event("ghost-crafter-craft-ctrl", function(event)
  handle_craft_action(game.players[event.player_index], "stack")
end)
```
New:
```lua
script.on_event("supersample-craft", function(event)
  handle_craft_action(game.players[event.player_index], 1)
end)

script.on_event("supersample-craft-shift", function(event)
  handle_craft_action(game.players[event.player_index], 5)
end)

script.on_event("supersample-craft-ctrl", function(event)
  handle_craft_action(game.players[event.player_index], "stack")
end)
```

- [ ] **Step 4: Verify**

Run: `grep -n "ghost-crafter" control.lua`
Expected: no output.

---

## Task 5: Update `locale/en/locale.cfg`

**Files:**
- Modify: `locale/en/locale.cfg`

- [ ] **Step 1: Replace the full file content**

Current content:
```
[controls]
ghost-crafter-craft=Ghost Crafter: Craft or Pipette
ghost-crafter-craft-shift=Ghost Crafter: Craft ×5 or Pipette
ghost-crafter-craft-ctrl=Ghost Crafter: Craft full stack or Pipette

[mod-setting-name]
ghost-crafter-craft-count=Craft count

[mod-setting-description]
ghost-crafter-craft-count=Number of items to queue per keypress. Shift binding multiplies this by 5; Ctrl binding queues a full stack.

[ghost-crafter]
queued=Queued: __1__x __2__
missing-materials=Missing materials
```

New content:
```
[controls]
supersample-craft=SuperSample: Craft or Pipette
supersample-craft-shift=SuperSample: Craft ×5 or Pipette
supersample-craft-ctrl=SuperSample: Craft full stack or Pipette

[mod-setting-name]
supersample-craft-count=Craft count

[mod-setting-description]
supersample-craft-count=Number of items to queue per keypress. Shift binding multiplies this by 5; Ctrl binding queues a full stack.

[supersample]
queued=Queued: __1__x __2__
missing-materials=Missing materials
```

- [ ] **Step 2: Verify**

Run: `grep -ni "ghost.crafter" locale/en/locale.cfg`
Expected: no output.

---

## Task 6: Update `tools/check-log.ps1`

**Files:**
- Modify: `tools/check-log.ps1`

- [ ] **Step 1: Replace the hardcoded mod-name match**

The script highlights log lines belonging to this mod with a `> MOD:` prefix by matching the literal string `GhostCrafter`. Find this line:
```powershell
    if ($line -match 'GhostCrafter') {
```
Replace with:
```powershell
    if ($line -match 'SuperSample') {
```

- [ ] **Step 2: Verify**

Run: `grep -n "GhostCrafter" tools/check-log.ps1`
Expected: no output.

---

## Task 7: Update `.claude/commands/check-log.md`

**Files:**
- Modify: `.claude/commands/check-log.md`

- [ ] **Step 1: Replace both prose references**

Current content:
```markdown
---
description: Read the Factorio error log, identify what broke in GhostCrafter, and automatically fix the issue.
---
Run `powershell -ExecutionPolicy Bypass -File tools/check-log.ps1` and read the output.

If errors are found: identify the file and line in GhostCrafter, read that file, fix the error, and explain what went wrong.
If the log looks clean: say so and suggest checking if the mod is actually enabled in Factorio's mod list.
```

New content:
```markdown
---
description: Read the Factorio error log, identify what broke in SuperSample, and automatically fix the issue.
---
Run `powershell -ExecutionPolicy Bypass -File tools/check-log.ps1` and read the output.

If errors are found: identify the file and line in SuperSample, read that file, fix the error, and explain what went wrong.
If the log looks clean: say so and suggest checking if the mod is actually enabled in Factorio's mod list.
```

- [ ] **Step 2: Verify**

Run: `grep -n "GhostCrafter" .claude/commands/check-log.md`
Expected: no output.

---

## Task 8: Commit and push all in-repo changes (folder and remote still at old names)

**Files:** none (git operations only)

- [ ] **Step 1: Confirm no other in-repo reference to the old name remains**

Run: `grep -rli "ghostcrafter\|ghost-crafter" . --exclude-dir=.git --exclude-dir=docs`
Expected: no output. (The `docs` dir is excluded deliberately — the two historical plan/spec docs are staying as-is per the locked-in decision above.)

- [ ] **Step 2: Stage and commit**

```bash
git add info.json data.lua settings.lua control.lua locale/en/locale.cfg tools/check-log.ps1 .claude/commands/check-log.md
git commit -m "rename: GhostCrafter -> SuperSample

Renames the mod's internal Factorio ID, all keybind/setting/locale
keys, and supporting tooling. info.json name/title, ghost-crafter-*
identifiers -> supersample-*. Bumps to 1.1.0. Existing test saves
will show GhostCrafter as removed and SuperSample as new — expected,
not yet deployed to the live server.

Folder and GitHub repo renamed in a follow-up step."
```

- [ ] **Step 3: Push**

```bash
git push origin master
```

Expected: pushes cleanly since the remote is still `github.com/TheStickface/GhostCrafter` at this point — renaming the repo (Task 10) happens after this push, and GitHub's redirect keeps the old URL valid indefinitely regardless.

---

## Task 9: Rename the local folder

**Files:** none (filesystem operation)

- [ ] **Step 1: Rename via PowerShell, from outside the folder being renamed**

Run (do NOT `cd` into the GhostCrafter folder first — renaming your own cwd out from under a shell breaks subsequent relative-path commands):
```powershell
Rename-Item -Path "C:\Dev\Factorio\GhostCrafter" -NewName "SuperSample"
```

- [ ] **Step 2: Verify**

Run: `Test-Path "C:\Dev\Factorio\SuperSample\info.json"`
Expected: `True`

Run: `Test-Path "C:\Dev\Factorio\GhostCrafter"`
Expected: `False`

From this point on, every command in this plan uses `C:\Dev\Factorio\SuperSample` (or `C:/Dev/Factorio/SuperSample` in Git Bash) as the repo path.

---

## Task 10: Rename the GitHub repository

**Files:** none (GitHub operation via `gh` CLI)

- [ ] **Step 1: Rename the repo**

Run from inside the renamed folder (this also updates the local `origin` remote automatically, since `gh repo rename` detects it's run from within the repo's working directory):
```bash
cd "C:/Dev/Factorio/SuperSample"
gh repo rename SuperSample --yes
```

- [ ] **Step 2: Verify the remote was updated**

Run: `git remote -v`
Expected: both fetch and push URLs show `https://github.com/TheStickface/SuperSample.git`

If it still shows the old URL, fix manually:
```bash
git remote set-url origin https://github.com/TheStickface/SuperSample.git
```

- [ ] **Step 3: Verify the repo responds at the new location**

Run: `gh repo view TheStickface/SuperSample --json name,url`
Expected: JSON showing `"name": "SuperSample"`.

---

## Task 11: Update local Claude Code settings (paths only, not committed)

**Files:**
- Modify: `.claude/settings.local.json`

- [ ] **Step 1: Replace every literal path segment**

This file has 8 occurrences of the literal path `C:\\Dev\\Factorio\\GhostCrafter` (in PowerShell/Bash permission entries). Replace each with `C:\\Dev\\Factorio\\SuperSample`. The entries themselves (command names, flags) stay identical — only the embedded path changes.

- [ ] **Step 2: Verify**

Run: `grep -c "GhostCrafter" "C:/Dev/Factorio/SuperSample/.claude/settings.local.json"`
Expected: `0`

This file is local-only (not tracked by git in most Claude Code setups) — confirm with `git status` that it doesn't show as a pending change; if it does, it's fine to leave uncommitted, this is a local dev-machine setting.

---

## Task 12: Recreate the Factorio mods junction under the new name

**Files:** none (Factorio install directory, outside the repo)

- [ ] **Step 1: Remove the old junction**

Run (this removes only the junction/link itself, not the target folder's contents — safe):
```powershell
Remove-Item "$env:APPDATA\Factorio\mods\GhostCrafter" -Force
```

- [ ] **Step 2: Create the new junction pointing at the renamed folder**

```powershell
New-Item -ItemType Junction -Path "$env:APPDATA\Factorio\mods\SuperSample" -Target "C:\Dev\Factorio\SuperSample"
```

- [ ] **Step 3: Verify**

Run: `Test-Path "$env:APPDATA\Factorio\mods\SuperSample\info.json"`
Expected: `True`

---

## Task 13: Update `mod-list.json`

**Files:**
- Modify: `%APPDATA%\Factorio\mods\mod-list.json`

- [ ] **Step 1: Rename the mod entry**

Find:
```json
    {
      "name": "GhostCrafter",
      "enabled": true
    },
```
Replace with:
```json
    {
      "name": "SuperSample",
      "enabled": true
    },
```

(Leave it in its current position in the array — Factorio doesn't care about ordering, this is cosmetic only.)

- [ ] **Step 2: Verify**

Run: `grep -n "GhostCrafter\|SuperSample" "$env:APPDATA/Factorio/mods/mod-list.json"`
Expected: only `SuperSample` shows, with `"enabled": true`.

---

## Task 14: In-game verification

**Files:** none (manual + `/check-log`)

- [ ] **Step 1: Launch Factorio and load the test save**

User action — launch the game normally.

- [ ] **Step 2: Run the log checker**

```bash
powershell -ExecutionPolicy Bypass -File tools/check-log.ps1
```
Expected: `Errors: None found`, and the loaded-mods section of the log shows `SuperSample 1.1.0` (not GhostCrafter).

- [ ] **Step 3: Confirm the "mod no longer present" notice for GhostCrafter (expected, not a bug)**

Factorio will likely show a one-time warning that the save references a mod (`GhostCrafter`) that's no longer present, since the internal ID changed. This is expected per the decision locked in above — dismiss it. Confirm `SuperSample`'s functionality still works: CapsLock, Ctrl+CapsLock, Shift+CapsLock all trigger craft/pipette as before (this logic didn't change, only names did, so no new behavior to test — just confirming nothing broke in the rename).

---

## Task 15: Update Claude's persistent memory

**Files (outside the repo):**
- Modify: `C:\Users\scorp\.claude\projects\C--Dev-Factorio-GhostCrafter\memory\project-ghostcrafter.md`
- Modify: `C:\Users\scorp\.claude\projects\C--Dev-Factorio-GhostCrafter\memory\feedback-github-descriptions.md`
- Modify: `C:\Users\scorp\.claude\projects\C--Dev-Factorio-GhostCrafter\memory\MEMORY.md`

This isn't a repo file, so it's not part of `git status` — it's the assistant's own cross-session memory and needs a manual pass after the above tasks are done.

- [ ] **Step 1: Update `project-ghostcrafter.md`**

Replace all references to "GhostCrafter" (mod name, folder path `C:\Dev\Factorio\GhostCrafter`, GitHub URL) with "SuperSample" / `C:\Dev\Factorio\SuperSample` / `https://github.com/TheStickface/SuperSample`. Add a dated note recording the rename (old name, new name, date, reason: user preference, no functional change).

- [ ] **Step 2: Update `feedback-github-descriptions.md`**

Line 10 currently reads "...in the GhostCrafter repo." — update to "...in the SuperSample repo."

- [ ] **Step 3: Update `MEMORY.md` index line**

Update the one-line pointer for the project memory to reference SuperSample instead of GhostCrafter.

- [ ] **Step 4: Verify**

Re-read all three files and confirm no remaining "GhostCrafter" string outside of explicitly-historical context (e.g. "was previously named GhostCrafter" is fine — a dangling stale reference is not).

---

## Self-Review

**Spec coverage:**
- Internal mod ID + all `ghost-crafter-*` keys → Tasks 1–5 ✓
- Supporting tooling (`check-log.ps1`, `check-log.md`) → Tasks 6–7 ✓
- Local folder rename → Task 9 ✓
- GitHub repo rename → Task 10 ✓
- Local Claude settings paths → Task 11 ✓
- Factorio mods junction + mod-list.json → Tasks 12–13 ✓
- In-game verification nothing broke → Task 14 ✓
- Persistent memory → Task 15 ✓
- Historical docs explicitly left alone → noted in header, excluded from Task 8's grep check ✓

**Placeholder scan:** No TBD/"add appropriate"/"similar to Task N" — every step has exact before/after content or an exact command with expected output.

**Consistency check:** `supersample-craft` / `supersample-craft-shift` / `supersample-craft-ctrl` / `supersample-craft-count` / `supersample.queued` / `supersample.missing-materials` are used identically across Tasks 2, 3, 4, and 5 — no naming drift between files.
