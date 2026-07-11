# GhostCrafter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Factorio 2.0 mod with a keybind that mimics the pipette tool when the player has the hovered item, or queues a hand-craft (with sub-recipes) when they don't, with flying text feedback and a ghost cursor after queuing.

**Architecture:** Five files — `info.json` (metadata), `settings.lua` (per-player craft count), `data.lua` (three custom input prototypes for base/shift/ctrl variants), `control.lua` (startup recipe cache + single event handler shared by all three inputs), `locale/en/locale.cfg` (all display strings). No external libraries.

**Tech Stack:** Factorio 2.0 Lua mod API, LuaJIT 2.1, `gh` CLI for GitHub, Factorio in-game console (`/c`) for runtime verification.

---

### File Map

| File | Responsibility |
|---|---|
| `info.json` | Mod metadata: name, version, `factorio_version: "2.0"` |
| `settings.lua` | `ghost-crafter-craft-count` runtime-per-player int setting |
| `data.lua` | Three `custom-input` prototypes (base, shift ×5, ctrl full-stack) |
| `control.lua` | `get_settings`, `resolve_hovered_target`, `handle_craft_action`, init hooks |
| `locale/en/locale.cfg` | Control names, setting labels, queued/missing-materials strings |

---

### Task 1: Mod scaffold and git init

**Files:**
- Create: `info.json`
- Create: `settings.lua`
- Create: `data.lua`
- Create: `control.lua`
- Create: `locale/en/locale.cfg`

- [ ] **Step 1: Create `info.json`**

```json
{
  "name": "GhostCrafter",
  "version": "0.1.0",
  "title": "GhostCrafter",
  "author": "scorps",
  "description": "A keybind that acts as a smart pipette: picks up items you have, or queues a craft for items you don't.",
  "factorio_version": "2.0"
}
```

- [ ] **Step 2: Create stub files**

`settings.lua`:
```lua
-- mod settings defined in Task 3
```

`data.lua`:
```lua
-- custom inputs defined in Task 4
```

`control.lua`:
```lua
-- runtime logic defined in Tasks 5-8
```

`locale/en/locale.cfg`:
```ini
; strings defined in Task 3
```

- [ ] **Step 3: Initialize git and commit**

```bash
git init
git add info.json settings.lua data.lua control.lua locale/en/locale.cfg docs/
git commit -m "feat: initial mod scaffold and design docs"
```

---

### Task 2: GitHub repo

**Files:** none (git operations only)

- [ ] **Step 1: Create and push GitHub repo**

```bash
gh repo create GhostCrafter --public --description "Factorio 2.0 mod: smart pipette that auto-queues crafting" --source . --remote origin --push
```

Expected: GitHub URL printed to terminal (e.g. `https://github.com/scorps/GhostCrafter`).

---

### Task 3: Locale and settings

**Files:**
- Modify: `locale/en/locale.cfg`
- Modify: `settings.lua`

- [ ] **Step 1: Write `locale/en/locale.cfg`**

```ini
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

- [ ] **Step 2: Write `settings.lua`**

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
  }
})
```

- [ ] **Step 3: Commit and push**

```bash
git add locale/en/locale.cfg settings.lua
git commit -m "feat: add locale strings and craft-count setting"
git push
```

---

### Task 4: Custom input prototypes

**Files:**
- Modify: `data.lua`

- [ ] **Step 1: Write `data.lua`**

```lua
data:extend({
  {
    type = "custom-input",
    name = "ghost-crafter-craft",
    key_sequence = "",   -- unbound by default; player assigns in Controls
    consuming = "none",
  },
  {
    type = "custom-input",
    name = "ghost-crafter-craft-shift",
    key_sequence = "",
    consuming = "none",
  },
  {
    type = "custom-input",
    name = "ghost-crafter-craft-ctrl",
    key_sequence = "",
    consuming = "none",
  },
})
```

- [ ] **Step 2: Load mod in Factorio and verify all three keybinds appear**

Start Factorio → Settings → Controls → scroll to the Mods section.
Expected: three entries — "Ghost Crafter: Craft or Pipette", "Ghost Crafter: Craft ×5 or Pipette", "Ghost Crafter: Craft full stack or Pipette" — all showing empty binding slots.

- [ ] **Step 3: Commit and push**

```bash
git add data.lua
git commit -m "feat: register three ghost-crafter custom inputs (base, shift, ctrl)"
git push
```

---

### Task 5: Recipe cache

**Files:**
- Modify: `control.lua`

The cache maps `item_name → recipe_name` for every hand-craftable recipe (character crafting categories only, no fluid ingredients). Built once on init and rebuilt when mods/tech change.

- [ ] **Step 1: Write `control.lua`**

```lua
local function build_recipe_cache()
  local cache = {}

  -- Only cache recipes the character entity can hand-craft
  local char_proto = game.entity_prototypes["character"]
  local craftable_cats = char_proto and char_proto.crafting_categories or {}

  for name, recipe in pairs(game.recipe_prototypes) do
    if not craftable_cats[recipe.category] then goto continue end

    -- Skip recipes with fluid ingredients (cannot hand-craft with fluids)
    local has_fluid = false
    for _, ingredient in pairs(recipe.ingredients) do
      if ingredient.type == "fluid" then
        has_fluid = true
        break
      end
    end
    if has_fluid then goto continue end

    -- Map each item product to this recipe; first recipe found wins
    for _, product in pairs(recipe.products) do
      if product.type == "item" and not cache[product.name] then
        cache[product.name] = name
      end
    end

    ::continue::
  end

  return cache
end

script.on_init(function()
  storage.recipe_cache = build_recipe_cache()
end)

script.on_configuration_changed(function()
  storage.recipe_cache = build_recipe_cache()
end)
```

- [ ] **Step 2: Verify cache contents in Factorio console**

Start a new game with the mod enabled, then run:
```lua
/c local t = {}; for k,v in pairs(storage.recipe_cache) do t[#t+1] = k.."="..v end; game.print(table.concat(t, ", "):sub(1,500))
```
Expected: a comma-separated list like `iron-chest=iron-chest, copper-cable=copper-cable, ...`

If the output is empty, debug the character categories:
```lua
/c local cp = game.entity_prototypes["character"]; for k in pairs(cp.crafting_categories) do game.print(k) end
```
Expected: at least one category name printed (typically `crafting`).

- [ ] **Step 3: Commit and push**

```bash
git add control.lua
git commit -m "feat: build hand-craftable item→recipe cache on init and config change"
git push
```

---

### Task 6: resolve_hovered_target

**Files:**
- Modify: `control.lua`

- [ ] **Step 1: Add `resolve_hovered_target` above the `script.on_init` block**

```lua
-- Returns {name, quality, is_tile} for the entity/ghost under the cursor, or nil.
local function resolve_hovered_target(player)
  local entity = player.selected
  if not entity or not entity.valid then return nil end

  local etype = entity.type
  local proto, quality

  if etype == "entity-ghost" then
    proto   = entity.ghost_prototype
    quality = entity.quality and entity.quality.name or "normal"
  elseif etype == "tile-ghost" then
    proto   = entity.ghost_prototype   -- LuaTilePrototype
    quality = "normal"                 -- tiles have no quality levels
  else
    -- Normal placed entity; silently ignore resources, cliffs, etc.
    proto   = entity.prototype
    quality = entity.quality and entity.quality.name or "normal"
  end

  if not proto then return nil end

  local items = proto.items_to_place_this
  if not items or #items == 0 then return nil end

  return {
    name    = items[1].name,
    quality = quality,
    is_tile = (etype == "tile-ghost"),
  }
end
```

- [ ] **Step 2: Add a temporary debug handler to verify in-game (append to `control.lua`)**

```lua
-- TEMP: remove after Task 6 testing
script.on_event("ghost-crafter-craft", function(event)
  local player = game.players[event.player_index]
  local target = resolve_hovered_target(player)
  if target then
    game.print(string.format("Target: %s  quality=%s  is_tile=%s",
      target.name, target.quality, tostring(target.is_tile)))
  else
    game.print("No target")
  end
end)
```

- [ ] **Step 3: Bind the base keybind in Controls and test each case**

Bind "Ghost Crafter: Craft or Pipette" to any unused key (e.g. `Y`).

| Scenario | Expected output |
|---|---|
| Hover over assembling machine | `Target: assembling-machine-1  quality=normal  is_tile=false` |
| Hover over entity ghost (blueprint) | `Target: <entity-name>  quality=normal  is_tile=false` |
| Hover over concrete tile ghost | `Target: concrete  quality=normal  is_tile=true` |
| Hover over iron ore (resource) | `No target` |
| Hover over empty ground | `No target` |

- [ ] **Step 4: Remove the temp handler and commit**

Delete the `-- TEMP` block added in Step 2, then:

```bash
git add control.lua
git commit -m "feat: add resolve_hovered_target for entity, ghost, and tile detection"
git push
```

---

### Task 7: Main event handler

**Files:**
- Modify: `control.lua`

- [ ] **Step 1: Add `get_settings` helper above `resolve_hovered_target`**

```lua
local function get_settings(player)
  return {
    craft_count = settings.get_player_settings(player)["ghost-crafter-craft-count"].value,
  }
end
```

- [ ] **Step 2: Add `handle_craft_action` and wire up all three inputs (append after the `script.on_configuration_changed` block)**

```lua
local STACK_FALLBACK = 50  -- fallback stack size if item prototype missing

local function handle_craft_action(player, multiplier)
  if not player or not player.valid or not player.character then return end

  local target = resolve_hovered_target(player)
  if not target then return end

  local item_name = target.name
  local quality   = target.quality
  local s         = get_settings(player)

  -- 1. Player has the item → mimic pipette (put in cursor)
  local item_count = player.get_item_count({name = item_name, quality = quality})
  if item_count > 0 then
    player.clean_cursor()
    player.cursor_stack.set_stack({name = item_name, count = item_count})
    return
  end

  -- 2. Look up recipe in cache
  local recipe_name = storage.recipe_cache[item_name]
  if not recipe_name then return end

  -- 3. Confirm recipe is still enabled for this force at runtime
  local force_recipe = player.force.recipes[recipe_name]
  if not force_recipe or not force_recipe.enabled then return end

  -- 4. Compute craft count
  local count
  if multiplier == "stack" then
    local item_proto = game.item_prototypes[item_name]
    count = item_proto and item_proto.stack_size or STACK_FALLBACK
  else
    count = s.craft_count * (multiplier or 1)
  end

  -- 5. Queue crafting (Factorio handles sub-recipe queuing automatically)
  local queued = player.begin_crafting{recipe = recipe_name, count = count}

  if queued > 0 then
    local display_name = game.item_prototypes[item_name].localised_name
    player.create_local_flying_text{
      text     = {"ghost-crafter.queued", queued, display_name},
      position = player.position,
    }
    -- Ghost cursor so player can place immediately while items are crafting
    -- Only for entity targets; tile placement uses cursor_stack instead
    if not target.is_tile then
      player.cursor_ghost = {name = item_name, quality = quality}
    end
  else
    player.create_local_flying_text{
      text     = {"ghost-crafter.missing-materials"},
      position = player.position,
    }
  end
end

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

- [ ] **Step 3: Test the no-item → craft path**

Setup: give yourself iron plates and iron sticks (for iron chest), but no iron chests. Place an iron chest, then take it out of your inventory.

1. Hover over the iron chest → press base keybind (`Y`).
2. Expected: flying text "Queued: 1x Iron Chest", ghost iron chest appears in cursor, crafting queue shows 1 iron chest.

- [ ] **Step 4: Test missing materials path**

Setup: have an empty inventory (or no crafting ingredients at all).

1. Hover over an assembling machine → press keybind.
2. Expected: flying text "Missing materials", nothing queued.

- [ ] **Step 5: Test has-item → pipette path**

Setup: have 5 iron chests in inventory.

1. Hover over a placed iron chest → press keybind.
2. Expected: iron chest appears in cursor (no flying text), same as pressing Q.

- [ ] **Step 6: Verify `cursor_ghost` after crafting**

After Step 3 succeeds:
1. Move mouse — the cursor should show a ghost iron chest you can place.
2. Once crafting completes, placing should consume the real item.

- [ ] **Step 7: Commit and push**

```bash
git add control.lua
git commit -m "feat: main event handler — pipette mimic, craft queue, flying text, ghost cursor"
git push
```

---

### Task 8: Verify modifier key variants

**Files:** none (code already wired in Task 7)

- [ ] **Step 1: Bind all three inputs in Factorio Controls**

Settings → Controls → Mods:
- "Ghost Crafter: Craft or Pipette" → `Y`
- "Ghost Crafter: Craft ×5 or Pipette" → `Shift+Y`
- "Ghost Crafter: Craft full stack or Pipette" → `Ctrl+Y`

- [ ] **Step 2: Test ×5 variant**

Setup: have enough iron plates for 5+ iron chests (300 iron plates, 100 iron sticks).

1. Ensure you have 0 iron chests.
2. Hover over placed iron chest → press `Shift+Y`.
3. Expected: flying text "Queued: 5x Iron Chest", crafting queue shows 5.

- [ ] **Step 3: Test full-stack variant**

Setup: have a large quantity of materials (use `/c game.player.insert{name="iron-plate", count=5000}`).

1. Ensure you have 0 iron chests.
2. Hover over placed iron chest → press `Ctrl+Y`.
3. Expected: flying text "Queued: 50x Iron Chest" (iron chest stack size is 50), crafting queue shows 50 (or as many as materials allow).

- [ ] **Step 4: Verify mod settings affect base count**

1. Go to Settings → Mod Settings → Per Player → set "Craft count" to `3`.
2. Hover over placed iron chest (no iron chests in inventory) → press `Y`.
3. Expected: flying text "Queued: 3x Iron Chest".
4. Press `Shift+Y` → Expected: "Queued: 15x Iron Chest" (3 × 5).

- [ ] **Step 5: Final push**

```bash
git push
```
