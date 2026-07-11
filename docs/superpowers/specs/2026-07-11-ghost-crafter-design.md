# GhostCrafter — Design Spec
**Date:** 2026-07-11

## Summary

A Factorio 2.0 mod that adds a keybind which acts as a smart pipette: if the player has the hovered entity's item, it mimics the pipette tool (picks it up); if the player doesn't have it, it queues a craft for that item (with sub-recipes) exactly as if clicked in the crafting menu.

---

## Goals

- Single keybind that replaces the need to open the crafting menu for "I want to place more of this"
- Opt-in: does not modify the default Q pipette behavior
- Craft count is configurable per player via mod settings
- Flying text feedback on success and failure
- Focused on buildings, entities, and tiles/foundations — items on the ground are out of scope

---

## File Structure

```
GhostCrafter/
├── info.json                          — mod metadata (factorio_version: "2.0")
├── settings.lua                       — mod setting prototypes
├── data.lua                           — custom input (keybind) prototype
├── control.lua                        — all runtime logic
└── locale/
    └── en/
        └── locale.cfg                 — keybind name + setting labels
```

---

## Settings (`settings.lua`)

All settings are `runtime-per-player` (no restart required, configurable per player).

| Setting name | Type | Default | Description |
|---|---|---|---|
| `ghost-crafter-craft-count` | int-setting | `1` | Number of items to craft per keypress |

### `get_settings(player)` helper in `control.lua`

All settings are accessed through a single helper so future options require only one-line additions here:

```lua
local function get_settings(player)
  return {
    craft_count = settings.get_player_settings(player)["ghost-crafter-craft-count"].value,
  }
end
```

---

## Custom Input (`data.lua`)

Registers one custom input prototype with no default keybind (user assigns in Factorio's controls menu):

```lua
data:extend({
  {
    type = "custom-input",
    name = "ghost-crafter-craft",
    key_sequence = "",   -- unbound by default
    consuming = "none",
  }
})
```

---

## Runtime Logic (`control.lua`)

### Recipe Cache

Built on `on_init` and `on_configuration_changed`. Stored in `storage` (Factorio 2.0 global persistent table). 

To ensure compatibility with dynamic technology unlocks (e.g. `on_research_finished`), player force differences, and recycling loops:
1. The cache is **static and global** (independent of force), mapping `item_name (string) → recipe_name (string)`.
2. During initialization, we iterate *all* recipes in the game and filter them. We map each item product to its primary recipe.
3. **Filtering Rules** to prevent cache pollution:
   - **No fluids:** Exclude recipes where any ingredient or product is a fluid (since fluids cannot be hand-crafted).
   - **Hand-craftable only:** Exclude recipes whose category is not hand-craftable by characters (e.g., exclude `chemistry`, `smelting`, `oil-processing`, `recycling`, etc.).
   - **Exclude recycling recipes:** Recycling recipes (e.g. named starting with `recycling-` or with category `recycling`) are explicitly ignored to prevent them from overwriting standard crafting recipes.

At runtime, we verify recipe availability for the player's specific force using:
`player.force.recipes[recipe_name].enabled`

### `resolve_hovered_target(player) → {name: string, quality: string, is_tile: boolean} | nil`

Resolves the item name, quality, and type associated with whatever the player is currently hovering or targeting.

1. **Entity Ghost / Normal Entity:**
   - Name: `entity.ghost_prototype.items_to_place_this[1].name` (for ghost) or `entity.prototype.items_to_place_this[1].name` (for normal entity).
   - Quality: `entity.quality.name` (defaults to `"normal"` if quality is disabled/absent).
2. **Tile Ghost / Selected Tile:**
   - In Factorio 2.0, players can hover over tiles. If the player selects a tile/tile ghost, we resolve the placing item name via `tile_prototype.items_to_place_this[1].name`.
   - Quality: `"normal"` (tiles do not have quality levels).
3. **Anything else (resources, cliffs, nil):** Returns `nil` (silent no-op).

### Event Handler Flow

When the custom input `"ghost-crafter-craft"` is fired:

1. **Identify Hovered Target:**
   - Resolve target item `name`, `quality`, and `is_tile` using `resolve_hovered_target(player)`.
   - If `nil`, exit silently.

2. **Check Inventory & Pipette (Native):**
   - Call native Factorio 2.0 API: `player.pipette(name, quality, false)` (with `allow_ghost = false`).
   - If this returns `true`, the player has the item in inventory (or a suitable fallback quality). The cursor is set, and the script exits successfully.

3. **Check Craftability:**
   - If the player doesn't have the item, retrieve `recipe_name` from the recipe cache for `name`.
   - If the recipe is `nil`, or if `player.force.recipes[recipe_name].enabled` is `false`, exit silently (cannot craft).

4. **Calculate Craft Count & Multipliers:**
   - Get the base craft count from `get_settings(player)`.
   - Check modifier keys from the custom input event (e.g., `event.shift`, `event.control`).
   - If `Shift` is held, multiply the craft count by `5` (or custom multiplier). If `Control` is held, queue a full stack.

5. **Queue Crafting:**
   - Call `player.begin_crafting{recipe=recipe_name, count=count}`.
   - If the returned value (queued count) is greater than `0`:
     - Show flying text: `"Queued: [count]x [item display name]"`
     - **Immediate Ghost Cursor:** Call `player.pipette(name, quality, true)` (with `allow_ghost = true`). This places a ghost of the item in the player's hand so they can start blueprinting/placing ghosts immediately while the items are crafting. The ghost cursor will automatically upgrade to the real item once crafting completes.
   - If the returned value is `0`:
     - Show flying text: `"Missing materials"`

---

## Edge Cases

| Scenario | Behavior |
|---|---|
| Nothing under cursor | Silent |
| Entity/Tile has no `items_to_place_this` (resource, cliff) | Silent |
| Recipe not enabled for player's force | Recipe disabled at runtime → silent |
| Player in vehicle or map view | Input event not fired by Factorio — naturally handled |
| Craft count > available materials | `begin_crafting` queues as many as possible; flying text reflects actual queued count |
| Multiple recipes produce same item | Hand-craftable filter applies; primary recipe in static cache wins |
| Tile ghost (concrete, landfill) | Resolved to placing item, pipetted or crafted successfully |
| Target has quality (e.g. rare assembling machine) | Checked via native pipette. If absent, fallback to crafting normal quality version. |

---

## Out of Scope

- Items on the ground
- Modifying the default Q pipette key
- Auto-craft on pipette (always-on mode) — may be added later as a setting
- Crafting more than 1 recipe at a time (multi-select)
