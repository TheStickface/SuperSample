# Pipette Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-player shortcut-bar toggle (+ keybind) that controls whether the SuperSample craft keybinds pipette an already-owned item or always force-craft, matching vanilla's "toggle personal roboport" UX.

**Architecture:** A `shortcut` prototype (`data.lua`) provides the clickable top-bar button; a paired `custom-input` provides the keybind via `associated_control_input`. `control.lua` initializes the toggle to "on" once per player, handles `on_lua_shortcut` to flip it, and gates the existing inventory-check branch in `handle_craft_action` on the toggle's state. No new files — this project has no automated test framework, so verification is manual, via the Factorio console and in-game play, following this repo's existing plan convention (see `docs/superpowers/plans/2026-07-11-ghost-crafter-implementation.md`).

**Tech Stack:** Factorio 2.0 Lua mod API, LuaJIT 2.1, Factorio in-game console (`/c`) for runtime verification.

---

### File Map

| File | Change |
|---|---|
| `data.lua` | Add `shortcut` prototype + `custom-input` for the toggle |
| `locale/en/locale.cfg` | Add control name, shortcut name, shortcut description |
| `control.lua` | Add `SHORTCUT_NAME` constant, default-state init, `on_lua_shortcut` handler, gate the pipette branch in `handle_craft_action` |

---

### Task 1: Shortcut + keybind prototypes

**Files:**
- Modify: `data.lua`

- [ ] **Step 1: Add the shortcut and custom-input to `data.lua`**

Add two new entries to the existing `data:extend({...})` array (after the three existing `supersample-craft*` custom-inputs, before the closing `})`):

```lua
  {
    type = "custom-input",
    name = "supersample-toggle-pipette",
    key_sequence = "ALT + CAPSLOCK",
    consuming = "none",
  },
  {
    type = "shortcut",
    name = "supersample-toggle-pipette",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/burner-inserter.png",
    icon_size = 64,
    associated_control_input = "supersample-toggle-pipette",
  },
```

The full `data.lua` should read:

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
  {
    type = "custom-input",
    name = "supersample-toggle-pipette",
    key_sequence = "ALT + CAPSLOCK",
    consuming = "none",
  },
  {
    type = "shortcut",
    name = "supersample-toggle-pipette",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/burner-inserter.png",
    icon_size = 64,
    associated_control_input = "supersample-toggle-pipette",
  },
})
```

- [ ] **Step 2: Load the mod in Factorio and verify the prototypes registered**

Start Factorio with the mod enabled, load any save.
Expected:
- A new icon (burner-inserter picture) appears in the top-left shortcut bar.
- Settings → Controls → Mods shows a new entry for the toggle's keybind (label will show as its untranslated internal name until Task 2 adds locale — that's expected at this point).

If the shortcut icon doesn't appear or the game fails to load, check the log with the `check-log` skill before proceeding.

- [ ] **Step 3: Commit**

```bash
git add data.lua
git commit -m "feat: add pipette toggle shortcut and keybind prototypes"
```

---

### Task 2: Locale strings

**Files:**
- Modify: `locale/en/locale.cfg`

- [ ] **Step 1: Add the new locale entries**

Add a `supersample-toggle-pipette` line under `[controls]`, and two new sections, so the file reads:

```ini
[controls]
supersample-craft=SuperSample: Craft or Pipette
supersample-craft-shift=SuperSample: Craft ×5 or Pipette
supersample-craft-ctrl=SuperSample: Craft full stack or Pipette
supersample-toggle-pipette=SuperSample: Toggle Pipette

[mod-setting-name]
supersample-craft-count=Craft count

[mod-setting-description]
supersample-craft-count=Number of items to queue per keypress. Shift binding multiplies this by 5; Ctrl binding queues a full stack.

[shortcut-name]
supersample-toggle-pipette=Toggle Pipette

[shortcut-description]
supersample-toggle-pipette=When enabled, SuperSample craft keybinds pipette items you already have instead of crafting new ones. When disabled, they always craft.

[supersample]
queued=Queued: __1__x __2__
missing-materials=Missing materials
```

- [ ] **Step 2: Reload the mod and verify locale**

Reload Factorio (or use `/c game.reload_mods()` if in a running save with the mod already loaded... otherwise restart).
Expected:
- Shortcut bar icon's tooltip reads "Toggle Pipette" with the description text on hover.
- Settings → Controls → Mods shows "SuperSample: Toggle Pipette" as the keybind label.

- [ ] **Step 3: Commit**

```bash
git add locale/en/locale.cfg
git commit -m "feat: add locale strings for pipette toggle"
```

---

### Task 3: Default-state initialization

**Files:**
- Modify: `control.lua`

- [ ] **Step 1: Add the `SHORTCUT_NAME` constant at the top of `control.lua`**

Insert before the existing `local function resolve_hovered_target(player)` (currently line 1):

```lua
local SHORTCUT_NAME = "supersample-toggle-pipette"

```

- [ ] **Step 2: Add `ensure_pipette_default` after `build_recipe_cache`**

Insert directly after the `build_recipe_cache` function's closing `end` (currently line 62), before the existing `script.on_init` block:

```lua
local function ensure_pipette_default(player)
  storage.pipette_initialized = storage.pipette_initialized or {}
  if storage.pipette_initialized[player.index] then return end
  player.set_shortcut_toggled(SHORTCUT_NAME, true)
  storage.pipette_initialized[player.index] = true
end
```

- [ ] **Step 3: Wire `ensure_pipette_default` into `on_init`, `on_player_created`, and `on_configuration_changed`**

Replace the existing:

```lua
script.on_init(function()
  storage.recipe_cache = build_recipe_cache()
end)

script.on_configuration_changed(function()
  storage.recipe_cache = build_recipe_cache()
end)
```

with:

```lua
script.on_init(function()
  storage.recipe_cache = build_recipe_cache()
  for _, player in pairs(game.players) do
    ensure_pipette_default(player)
  end
end)

script.on_configuration_changed(function()
  storage.recipe_cache = build_recipe_cache()
  for _, player in pairs(game.players) do
    ensure_pipette_default(player)
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  ensure_pipette_default(game.players[event.player_index])
end)
```

- [ ] **Step 4: Verify default state in the Factorio console**

Start a new game with the mod enabled.
```lua
/c game.print(tostring(game.player.is_shortcut_toggled("supersample-toggle-pipette")))
```
Expected: `true`

- [ ] **Step 5: Commit**

```bash
git add control.lua
git commit -m "feat: default pipette toggle to on for new and existing players"
```

---

### Task 4: Toggle handler

**Files:**
- Modify: `control.lua`

- [ ] **Step 1: Add the `on_lua_shortcut` handler**

Insert after the `on_player_created` block added in Task 3:

```lua
script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= SHORTCUT_NAME then return end
  local player = game.players[event.player_index]
  player.set_shortcut_toggled(SHORTCUT_NAME, not player.is_shortcut_toggled(SHORTCUT_NAME))
end)
```

- [ ] **Step 2: Verify clicking the shortcut button toggles it**

In a running game:
1. Click the shortcut bar icon.
2. Expected: the button visually depresses/highlights (toggled off → the button state flips from its default "on" look), and:
```lua
/c game.print(tostring(game.player.is_shortcut_toggled("supersample-toggle-pipette")))
```
prints `false`.
3. Click again → prints `true`.

- [ ] **Step 3: Verify the keybind toggles it**

1. Bind "SuperSample: Toggle Pipette" if not already bound to `ALT + CAPSLOCK` (Settings → Controls → Mods).
2. Press `ALT + CAPSLOCK` in-game.
3. Run the same console check as Step 2 — confirm it flips.

If pressing the keybind does **not** flip the toggle (i.e. `associated_control_input` doesn't forward to `on_lua_shortcut` in this Factorio version), add this additional handler directly below the one from Step 1, since the custom-input and shortcut share the same name:

```lua
script.on_event("supersample-toggle-pipette", function(event)
  local player = game.players[event.player_index]
  player.set_shortcut_toggled(SHORTCUT_NAME, not player.is_shortcut_toggled(SHORTCUT_NAME))
end)
```

Only add this fallback if Step 3 fails — do not add it speculatively, since with a working `associated_control_input` it would cause a double-toggle (key press undoing itself).

- [ ] **Step 4: Commit**

```bash
git add control.lua
git commit -m "feat: toggle pipette shortcut on click and keybind"
```

---

### Task 5: Gate the pipette branch

**Files:**
- Modify: `control.lua`

- [ ] **Step 1: Update the inventory-check branch in `handle_craft_action`**

Replace:

```lua
  local item_count = player.get_item_count({name = item_name, quality = quality})
  if item_count > 0 then
    player.clear_cursor()
    if player.cursor_stack then
      player.cursor_stack.set_stack({name = item_name, count = item_count})
    end
    return
  end
```

with:

```lua
  local item_count = player.get_item_count({name = item_name, quality = quality})
  if item_count > 0 and player.is_shortcut_toggled(SHORTCUT_NAME) then
    player.clear_cursor()
    if player.cursor_stack then
      player.cursor_stack.set_stack({name = item_name, count = item_count})
    end
    return
  end
```

- [ ] **Step 2: Test toggle ON — has item → pipettes (regression check)**

Setup: have 5 iron chests in inventory, toggle in default "on" state.
1. Hover over a placed iron chest → press the base craft keybind (`CAPSLOCK`).
2. Expected: iron chest appears in cursor (pipette behavior), no flying text.

- [ ] **Step 3: Test toggle ON — no item → crafts (regression check)**

Setup: 0 iron chests in inventory, enough materials to craft one.
1. Hover over a placed iron chest → press `CAPSLOCK`.
2. Expected: flying text "Queued: 1x Iron Chest".

- [ ] **Step 4: Test toggle OFF — has item → force-crafts (new behavior)**

Setup: 5 iron chests in inventory, enough materials for another, toggle switched off (click shortcut or press `ALT + CAPSLOCK`).
1. Hover over a placed iron chest → press `CAPSLOCK`.
2. Expected: flying text "Queued: 1x Iron Chest" — item is NOT pulled from inventory into cursor, a new one is queued instead.

- [ ] **Step 5: Test toggle OFF — no item → crafts (unchanged)**

Setup: 0 iron chests in inventory, toggle off.
1. Hover over a placed iron chest → press `CAPSLOCK`.
2. Expected: flying text "Queued: 1x Iron Chest", same as toggle-on case.

- [ ] **Step 6: Test shift/ctrl variants respect the toggle**

Setup: toggle off, 5 iron chests in inventory, plenty of materials.
1. Hover over placed iron chest → press `CONTROL + CAPSLOCK` (the `supersample-craft-shift` binding, ×5 variant).
2. Expected: flying text "Queued: 5x Iron Chest" (or `craft_count × 5`), not a pipette.
3. Hover over placed iron chest → press `SHIFT + CAPSLOCK` (the `supersample-craft-ctrl` binding, full-stack variant).
4. Expected: flying text "Queued: 50x Iron Chest" (iron chest stack size), not a pipette.

- [ ] **Step 7: Test persistence across save/reload**

1. With toggle off, save and reload the game.
2. Run: `/c game.print(tostring(game.player.is_shortcut_toggled("supersample-toggle-pipette")))`
3. Expected: `false` (state persisted).

- [ ] **Step 8: Commit**

```bash
git add control.lua
git commit -m "feat: gate pipette behavior on the toggle so it can force-craft instead"
```

---

### Task 6: Full regression pass

**Files:** none (verification only)

- [ ] **Step 1: Re-run the original ghost-crafter test matrix with toggle ON**

Repeat Task 7 and Task 8's verification steps from `docs/superpowers/plans/2026-07-11-ghost-crafter-implementation.md` (pipette path, craft path, missing-materials path, ghost cursor, shift/ctrl multipliers, mod setting craft count) to confirm nothing regressed with the toggle defaulted on.

- [ ] **Step 2: Confirm mod loads cleanly with no errors**

Use the `check-log` skill to inspect `factorio-current.log` after a play session covering both toggle states.
Expected: no SuperSample-related errors or warnings.

- [ ] **Step 3: Final push**

```bash
git push
```
