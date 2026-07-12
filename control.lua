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
  local char_proto = prototypes.entity["character"]
  local craftable_cats = char_proto and char_proto.crafting_categories or {}

  for name, recipe in pairs(prototypes.recipe) do
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

local function get_settings(player)
  return {
    craft_count = settings.get_player_settings(player)["supersample-craft-count"].value,
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
    player.clear_cursor()
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
    local item_proto = prototypes.item[item_name]
    count = item_proto and item_proto.stack_size or STACK_FALLBACK
  else
    count = s.craft_count * (multiplier or 1)
  end

  local queued = player.begin_crafting{recipe = recipe_name, count = count}

  if queued > 0 then
    local display_name = prototypes.item[item_name].localised_name
    player.create_local_flying_text{
      text     = {"supersample.queued", queued, display_name},
      position = player.position,
    }
    if not target.is_tile then
      player.cursor_ghost = {name = item_name, quality = quality}
    end
  else
    player.create_local_flying_text{
      text     = {"supersample.missing-materials"},
      position = player.position,
    }
  end
end

script.on_event("supersample-craft", function(event)
  handle_craft_action(game.players[event.player_index], 1)
end)

script.on_event("supersample-craft-shift", function(event)
  handle_craft_action(game.players[event.player_index], 5)
end)

script.on_event("supersample-craft-ctrl", function(event)
  handle_craft_action(game.players[event.player_index], "stack")
end)
