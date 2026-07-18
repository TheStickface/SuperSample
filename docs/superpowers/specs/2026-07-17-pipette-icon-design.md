# Pipette Toggle Icon Design

## Problem

The `supersample-toggle-pipette` shortcut (data.lua) currently reuses the
vanilla `__base__/graphics/icons/burner-inserter.png` item icon as a
placeholder. It doesn't represent the mod's actual function and looks
out of place next to properly-authored shortcut icons.

## Goal

Replace it with a small custom icon that reads as a pipette/eyedropper —
matching the mod's own "smart pipette" identity — at shortcut-bar size.

## Design

Generate a flat white eyedropper silhouette (bulb, tapered tube, pointed
tip, small drop) on a transparent background, 64x64px, via a one-off
Python/Pillow script (not committed — output only). Save the result to
`graphics/icons/pipette-toggle.png`.

Update the `supersample-toggle-pipette` shortcut prototype in `data.lua`:

```lua
icon = "__SuperSample__/graphics/icons/pipette-toggle.png",
icon_size = 64,
small_icon = "__SuperSample__/graphics/icons/pipette-toggle.png",
small_icon_size = 64,
```

(Same file reused for both `icon` and `small_icon`, consistent with how
the prototype already worked before this change — just a new source
image instead of a vanilla one.)

Bump `info.json` version 1.2.1 → 1.2.2 (cosmetic-only change, no
behavior change) so the release can go up on the mod portal alongside
the new thumbnail.

## Out of scope

- No changes to `control.lua` or any crafting/pipette behavior.
- No changes to keybinds or settings.
- No shadow/mask variants — vanilla shortcut icons in this mod don't use
  them today.

## Testing

- Load the mod in-game; shortcut bar shows the new pipette icon instead
  of the burner-inserter icon.
- Icon is recognizable at actual shortcut-button size (not just at 4x
  zoom in a preview).
- Toggle behavior (click and ALT+CAPSLOCK) is unaffected — this is a
  pure asset swap.
