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
