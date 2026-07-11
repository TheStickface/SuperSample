# Character Modifiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in per-player settings for bonus inventory slots, crafting speed, and movement speed, applied to the player's character at join/respawn and whenever settings change, with automatic non-zero defaults for a named player list.

**Architecture:** Three new `runtime-per-player` settings in `settings.lua`. A `apply_character_modifiers(player)` function in `control.lua` tracks what it previously applied per player in `storage.player_modifiers` so it can subtract old values and add new ones without conflicting with other mods. On first join, players whose names appear in a hardcoded VIP table get their inventory bonus auto-set to 200 (tracked in `storage.player_initialized` so it only fires once — they can change the setting later without it resetting). Three event handlers fire at join, respawn, and settings change.

**Tech Stack:** Factorio 2.0 Lua mod API — `character_inventory_slots_bonus`, `character_crafting_speed_modifier`, `character_running_speed_modifier` on `LuaEntity` (character), `settings.get_player_settings` for read/write access to per-player settings.

---

### File Map

| File | Change |
|---|---|
| `settings.lua` | Add 3 new settings alongside existing `ghost-crafter-craft-count` |
| `locale/en/locale.cfg` | Add names and descriptions for the 3 new settings |
| `control.lua` | Add `apply_character_modifiers`, update `on_init`/`on_configuration_changed`, add 3 event handlers with VIP init logic |

---

### Task 1: Settings and locale

**Files:**
- Modify: `settings.lua`
- Modify: `locale/en/locale.cfg`

- [ ] **Step 1: Replace `settings.lua` with the expanded version**

```lua
data:extend({
  {
    type = "int-setting",
    name = "ghost-crafter-craft-count",
    setting_type = "runtime-per-player",
    default_value = 1,
    minimum_value = 1,
    maximum_value = 1000,
    order = "a",
  },
  {
    type = "int-setting",
    name = "ghost-crafter-bonus-inventory-slots",
    setting_type = "runtime-per-player",
    default_value = 0,
    minimum_value = 0,
    maximum_value = 500,
    order = "b",
  },
  {
    type = "double-setting",
    name = "ghost-crafter-crafting-speed-modifier",
    setting_type = "runtime-per-player",
    default_value = 1.0,
    minimum_value = 1.0,
    maximum_value = 10.0,
    order = "c",
  },
  {
    type = "double-setting",
    name = "ghost-crafter-movement-speed-modifier",
    setting_type = "runtime-per-player",
    default_value = 1.0,
    minimum_value = 1.0,
    maximum_value = 5.0,
    order = "d",
  },
})
```

- [ ] **Step 2: Replace `locale/en/locale.cfg` with the full updated version**

```ini
[controls]
ghost-crafter-craft=Ghost Crafter: Craft or Pipette
ghost-crafter-craft-shift=Ghost Crafter: Craft ×5 or Pipette
ghost-crafter-craft-ctrl=Ghost Crafter: Craft full stack or Pipette

[mod-setting-name]
ghost-crafter-craft-count=Craft count
ghost-crafter-bonus-inventory-slots=Bonus inventory slots
ghost-crafter-crafting-speed-modifier=Crafting speed multiplier
ghost-crafter-movement-speed-modifier=Movement speed multiplier

[mod-setting-description]
ghost-crafter-craft-count=Number of items to queue per keypress. Shift binding multiplies this by 5; Ctrl binding queues a full stack.
ghost-crafter-bonus-inventory-slots=Extra inventory slots added to your character. 0 = vanilla. Useful for complex modpacks like Pyanodon.
ghost-crafter-crafting-speed-modifier=Hand-crafting speed multiplier. 1.0 = vanilla, 2.0 = double speed, 10.0 = maximum.
ghost-crafter-movement-speed-modifier=Movement speed multiplier. 1.0 = vanilla, 2.0 = double speed, 5.0 = maximum.

[ghost-crafter]
queued=Queued: __1__x __2__
missing-materials=Missing materials
```

- [ ] **Step 3: Commit and push**

```
git add settings.lua locale/en/locale.cfg
git commit -m "feat: add bonus inventory, crafting speed, and movement speed settings"
git push
```

---

### Task 2: Character modifier logic

**Files:**
- Modify: `control.lua`

**How the math works:**
- `character_inventory_slots_bonus` — integer bonus added to inventory size. We track our contribution and swap it on change.
- `character_crafting_speed_modifier` — additive float delta. Factorio base is 0.0 (total speed = 1.0 + modifier). Setting value 2.0 means 2× speed → delta = `2.0 - 1.0 = 1.0`.
- `character_running_speed_modifier` — same pattern.

On respawn the character entity is recreated with all modifiers at 0, so we clear stored prev values first to avoid subtracting phantom values.

**VIP auto-init:** On a player's very first join, if their name is in the VIP table their inventory bonus setting is written to 200. This is tracked in `storage.player_initialized[player_index]` so it never fires again for that player even if they manually reset the setting to 0.

- [ ] **Step 1: Update `script.on_init` to initialize both storage tables**

Find (lines 64–66):
```lua
script.on_init(function()
  storage.recipe_cache = build_recipe_cache()
end)
```

Replace with:
```lua
script.on_init(function()
  storage.recipe_cache = build_recipe_cache()
  storage.player_modifiers = {}
  storage.player_initialized = {}
end)
```

- [ ] **Step 2: Update `script.on_configuration_changed` to guard both storage tables**

Find (lines 68–70):
```lua
script.on_configuration_changed(function()
  storage.recipe_cache = build_recipe_cache()
end)
```

Replace with:
```lua
script.on_configuration_changed(function()
  storage.recipe_cache = build_recipe_cache()
  storage.player_modifiers = storage.player_modifiers or {}
  storage.player_initialized = storage.player_initialized or {}
end)
```

- [ ] **Step 3: Add `apply_character_modifiers` after the `on_configuration_changed` block**

```lua
local function apply_character_modifiers(player)
  if not player or not player.valid or not player.character then return end

  local prev = storage.player_modifiers[player.index] or {
    inventory_slots = 0,
    crafting_speed  = 0.0,
    movement_speed  = 0.0,
  }

  local ps = settings.get_player_settings(player)
  local new_inventory = ps["ghost-crafter-bonus-inventory-slots"].value
  local new_crafting  = ps["ghost-crafter-crafting-speed-modifier"].value - 1.0
  local new_movement  = ps["ghost-crafter-movement-speed-modifier"].value - 1.0

  local char = player.character
  char.character_inventory_slots_bonus   = char.character_inventory_slots_bonus   - prev.inventory_slots + new_inventory
  char.character_crafting_speed_modifier = char.character_crafting_speed_modifier - prev.crafting_speed  + new_crafting
  char.character_running_speed_modifier  = char.character_running_speed_modifier  - prev.movement_speed  + new_movement

  storage.player_modifiers[player.index] = {
    inventory_slots = new_inventory,
    crafting_speed  = new_crafting,
    movement_speed  = new_movement,
  }
end
```

- [ ] **Step 4: Add the three event handlers at the end of `control.lua`**

Append after the existing `script.on_event("ghost-crafter-craft-ctrl", ...)` block:

```lua
local VIP_DEFAULTS = {
  ["stickface"] = true,
  ["tmallow"]   = true,
}
local VIP_INVENTORY_BONUS = 200

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.players[event.player_index]
  if VIP_DEFAULTS[player.name] and not storage.player_initialized[player.index] then
    settings.get_player_settings(player)["ghost-crafter-bonus-inventory-slots"] = {value = VIP_INVENTORY_BONUS}
    storage.player_initialized[player.index] = true
  end
  apply_character_modifiers(player)
end)

script.on_event(defines.events.on_player_respawned, function(event)
  storage.player_modifiers[event.player_index] = nil
  apply_character_modifiers(game.players[event.player_index])
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if not event.player_index then return end
  local s = event.setting
  if s == "ghost-crafter-bonus-inventory-slots"
  or s == "ghost-crafter-crafting-speed-modifier"
  or s == "ghost-crafter-movement-speed-modifier" then
    apply_character_modifiers(game.players[event.player_index])
  end
end)
```

- [ ] **Step 5: Commit and push**

```
git add control.lua
git commit -m "feat: apply per-player inventory, crafting speed, and movement speed modifiers"
git push
```

- [ ] **Step 6: Test in Factorio**

Load a save with the mod enabled. Go to Settings → Mod Settings → Per Player.
Expected: four settings visible — "Craft count", "Bonus inventory slots", "Crafting speed multiplier", "Movement speed multiplier".

**Test VIP auto-init (as stickface or tmallow):**
1. Join a new save for the first time.
2. Check Settings → Mod Settings → Per Player → "Bonus inventory slots".
3. Expected: value is automatically set to `200`.
4. Verify character has bonus: `/c game.print(game.player.character.character_inventory_slots_bonus)`
   Expected output: `200`
5. Change the setting to `50` — expected: inventory shrinks to +50. Does NOT reset to 200 on rejoin.

**Test non-VIP player:**
1. Join as any other player name.
2. Expected: "Bonus inventory slots" defaults to `0`, no auto-change.

**Test inventory slots (manual):**
1. Set "Bonus inventory slots" to `100`.
2. Expected: inventory immediately expands.
3. Verify: `/c game.print(game.player.character.character_inventory_slots_bonus)` → `100`

**Test crafting speed:**
1. Set "Crafting speed multiplier" to `3.0`.
2. Verify: `/c game.print(game.player.character.character_crafting_speed_modifier)` → `2` (delta = 3.0 - 1.0)

**Test movement speed:**
1. Set "Movement speed multiplier" to `2.0`.
2. Verify: `/c game.print(game.player.character.character_running_speed_modifier)` → `1` (delta = 2.0 - 1.0)

**Test respawn:**
1. Set inventory bonus to `50`, run `/c game.player.character.die()`, respawn.
2. Verify: `/c game.print(game.player.character.character_inventory_slots_bonus)` → `50`
