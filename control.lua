local function resolve_hovered_target(player)
  local entity = player.selected
  if not entity or not entity.valid then return nil end

  local etype = entity.type
  local proto, quality

  if etype == "entity-ghost" then
    proto   = entity.ghost_prototype
    quality = entity.quality and entity.quality.name or "normal"
  elseif etype == "tile-ghost" then
    proto   = entity.ghost_prototype
    quality = "normal"
  else
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

local VIP_PLAYERS         = { ["stickface"] = true, ["tmallow"] = true }
local VIP_INVENTORY_BONUS = 200
local VIP_CRAFTING_SPEED  = 4.0  -- delta for 5x (5.0 - 1.0)
local VIP_MOVEMENT_SPEED  = 2.0  -- delta for 3x (3.0 - 1.0)

script.on_init(function()
  storage.recipe_cache = build_recipe_cache()
  storage.vip_applied = {}
end)

script.on_configuration_changed(function()
  storage.recipe_cache = build_recipe_cache()
  storage.vip_applied = storage.vip_applied or {}
end)

local function apply_vip_bonuses(player)
  if not player or not player.valid or not player.character then return end
  if not VIP_PLAYERS[player.name] then return end

  local prev = storage.vip_applied[player.index] or { inventory = 0, crafting = 0.0, movement = 0.0 }
  local char = player.character
  char.character_inventory_slots_bonus   = char.character_inventory_slots_bonus   - prev.inventory + VIP_INVENTORY_BONUS
  char.character_crafting_speed_modifier = char.character_crafting_speed_modifier - prev.crafting  + VIP_CRAFTING_SPEED
  char.character_running_speed_modifier  = char.character_running_speed_modifier  - prev.movement  + VIP_MOVEMENT_SPEED
  storage.vip_applied[player.index] = {
    inventory = VIP_INVENTORY_BONUS,
    crafting  = VIP_CRAFTING_SPEED,
    movement  = VIP_MOVEMENT_SPEED,
  }
end

local function get_settings(player)
  return {
    craft_count = settings.get_player_settings(player)["ghost-crafter-craft-count"].value,
  }
end

local STACK_FALLBACK = 50

local function handle_craft_action(player, multiplier)
  if not player or not player.valid or not player.character then return end

  local target = resolve_hovered_target(player)
  if not target then return end

  local item_name = target.name
  local quality   = target.quality
  local s         = get_settings(player)

  local item_count = player.get_item_count({name = item_name, quality = quality})
  if item_count > 0 then
    player.clean_cursor()
    if player.cursor_stack then
      player.cursor_stack.set_stack({name = item_name, count = item_count})
    end
    return
  end

  local recipe_name = storage.recipe_cache[item_name]
  if not recipe_name then return end

  local force_recipe = player.force.recipes[recipe_name]
  if not force_recipe or not force_recipe.enabled then return end

  local count
  if multiplier == "stack" then
    local item_proto = game.item_prototypes[item_name]
    count = item_proto and item_proto.stack_size or STACK_FALLBACK
  else
    count = s.craft_count * (multiplier or 1)
  end

  local queued = player.begin_crafting{recipe = recipe_name, count = count}

  if queued > 0 then
    local display_name = game.item_prototypes[item_name].localised_name
    player.create_local_flying_text{
      text     = {"ghost-crafter.queued", queued, display_name},
      position = player.position,
    }
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

script.on_event(defines.events.on_player_joined_game, function(event)
  apply_vip_bonuses(game.players[event.player_index])
end)

script.on_event(defines.events.on_player_respawned, function(event)
  storage.vip_applied[event.player_index] = nil
  apply_vip_bonuses(game.players[event.player_index])
end)
