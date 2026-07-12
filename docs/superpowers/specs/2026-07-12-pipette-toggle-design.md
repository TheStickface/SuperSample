# Pipette Toggle Design

## Problem

`handle_craft_action` (control.lua) currently always checks the player's
inventory first: if you already have the hovered building, it pipettes it
into your cursor instead of crafting a fresh one. There's no way to force a
craft when you already hold the item — e.g. to top up a stack you're about
to run out of, or because you'd rather not disturb your held inventory item.

## Goal

Add a per-player toggle, in the style of vanilla's "toggle personal
roboport" button, that controls whether the pipette step runs at all:

- **Toggle ON** (default): current behavior. If you have the item, pipette
  it to cursor. Otherwise, craft it.
- **Toggle OFF**: always craft, ignoring inventory contents, even if you
  already hold the item.

The toggle must be clickable (shortcut-bar icon) and keybind-able, matching
vanilla UX conventions, not buried in the mod settings menu.

## Design

### 1. Shortcut + keybind (data.lua)

Add a `shortcut` prototype:

```lua
{
  type = "shortcut",
  name = "supersample-toggle-pipette",
  action = "lua",
  toggleable = true,
  icon = "__base__/graphics/icons/burner-inserter.png",
  icon_size = 64,
  associated_control_input = "supersample-toggle-pipette",
}
```

Add a matching `custom-input`:

```lua
{
  type = "custom-input",
  name = "supersample-toggle-pipette",
  key_sequence = "ALT + CAPSLOCK",
  consuming = "none",
}
```

Because `associated_control_input` is set, pressing the keybind fires the
same `on_lua_shortcut` event as clicking the button — one event handler
covers both.

### 2. Default state & persistence (control.lua)

The engine's default toggle state for an unset shortcut is `false`,  but we
want new/first-time players to start with pipette **on**. Track
initialization per player so we only force the default once, and never
stomp a player's own choice on subsequent loads:

```lua
local SHORTCUT_NAME = "supersample-toggle-pipette"

local function ensure_pipette_default(player)
  storage.pipette_initialized = storage.pipette_initialized or {}
  if storage.pipette_initialized[player.index] then return end
  player.set_shortcut_toggled(SHORTCUT_NAME, true)
  storage.pipette_initialized[player.index] = true
end
```

Call `ensure_pipette_default` from:
- `on_init` (loop over `game.players`, covers mod added to a fresh save with
  existing players)
- `on_player_created` (new players)
- `on_configuration_changed` (loop over `game.players`, covers existing
  saves updating to the version that adds this feature)

### 3. Toggle handler (control.lua)

```lua
script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= SHORTCUT_NAME then return end
  local player = game.players[event.player_index]
  player.set_shortcut_toggled(SHORTCUT_NAME, not player.is_shortcut_toggled(SHORTCUT_NAME))
end)
```

### 4. Runtime behavior change (control.lua)

In `handle_craft_action`, gate the existing pipette branch on the toggle:

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

Everything after this point (recipe lookup, `begin_crafting`, flying text,
`cursor_ghost` assignment) is unchanged — when the toggle is off, or when
the toggle is on but the item count is 0, execution falls through to
crafting exactly as it does today. This affects all three keybinds
(`supersample-craft`, `-shift`, `-ctrl`) uniformly, since they all funnel
through `handle_craft_action`.

## Out of scope

- No changes to `settings.lua` — this is not a mod setting.
- No changes to crafting/recipe logic itself.
- No per-quality or per-item toggle granularity — it's a single global
  per-player flag.

## Testing

- Toggle ON, item in inventory → pipettes to cursor (existing behavior,
  regression check).
- Toggle ON, item not in inventory → crafts (existing behavior).
- Toggle OFF, item in inventory → crafts instead of pipetting (new
  behavior).
- Toggle OFF, item not in inventory → crafts (unchanged).
- Toggle persists across save/reload, and across a mod update on an
  existing save with existing players.
- New player joining a multiplayer game defaults to toggle ON.
- Clicking the shortcut button and pressing ALT+CAPSLOCK both flip the
  toggle and stay in sync.
