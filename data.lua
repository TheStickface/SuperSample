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
