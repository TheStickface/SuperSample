# Pipette Toggle Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder vanilla burner-inserter icon on the `supersample-toggle-pipette` shortcut with a custom pipette/eyedropper icon, and bump the mod version so it can be re-uploaded to the mod portal.

**Architecture:** Generate a 64x64 transparent-background PNG (white eyedropper silhouette) with a one-off Python/Pillow script, save it under `graphics/icons/`, point the existing shortcut prototype at it instead of the vanilla asset, and bump `info.json`. No Lua logic changes.

**Tech Stack:** Python 3 + Pillow (already installed) for image generation; Lua/Factorio data stage for the prototype; JSON for `info.json`.

---

### Task 1: Generate the pipette icon asset

**Files:**
- Create: `graphics/icons/pipette-toggle.png`
- Create (temp, not committed): scratchpad script to generate it

- [ ] **Step 1: Ensure the icons directory exists**

Run: `mkdir -p "C:/Dev/Factorio/SuperSample/graphics/icons"`

- [ ] **Step 2: Write the generator script**

Save to a scratch path (e.g. `C:/Users/scorp/AppData/Local/Temp/claude/.../scratchpad/make_icon.py`) — this script is a build tool, not a repo artifact, so it is not committed:

```python
from PIL import Image, ImageDraw
import math

SIZE = 64
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
WHITE = (255, 255, 255, 255)

cx, cy = 32, 32
angle = math.radians(-45)
u = (math.cos(angle), math.sin(angle))      # points toward bulb (up-right)
p = (-u[1], u[0])                            # perpendicular

def along(t, w=0):
    x = cx + u[0] * t + p[0] * w
    y = cy + u[1] * t + p[1] * w
    return (x, y)

tube_hw = 5
tube_pts = [along(-14, -tube_hw), along(14, -tube_hw), along(14, tube_hw), along(-14, tube_hw)]
draw.polygon(tube_pts, fill=WHITE)

bulb_c = along(20)
r = 9
draw.ellipse([bulb_c[0]-r, bulb_c[1]-r, bulb_c[0]+r, bulb_c[1]+r], fill=WHITE)

tip_pts = [along(-14, -tube_hw), along(-14, tube_hw), along(-24)]
draw.polygon(tip_pts, fill=WHITE)

drop_c = along(-31)
dr = 3.5
draw.ellipse([drop_c[0]-dr, drop_c[1]-dr, drop_c[0]+dr, drop_c[1]+dr*1.3], fill=WHITE)

img.save(r"C:\Dev\Factorio\SuperSample\graphics\icons\pipette-toggle.png")
print("saved")
```

This is the exact geometry already approved by the user during brainstorming (bulb top-right, tapered tube, pointed tip, small drop, 45-degree diagonal).

- [ ] **Step 3: Run the script**

Run: `python <path-to-script>/make_icon.py`
Expected output: `saved`

- [ ] **Step 4: Verify the output file**

Run: `python -c "from PIL import Image; im = Image.open(r'C:\Dev\Factorio\SuperSample\graphics\icons\pipette-toggle.png'); print(im.size, im.mode)"`
Expected: `(64, 64) RGBA`

- [ ] **Step 5: Commit**

```bash
git add graphics/icons/pipette-toggle.png
git commit -m "Add custom pipette icon asset for toggle shortcut"
```

---

### Task 2: Point the shortcut prototype at the new icon

**Files:**
- Modify: `data.lua:31-34`

- [ ] **Step 1: Update the icon fields**

In `data.lua`, within the `supersample-toggle-pipette` shortcut prototype, replace:

```lua
    icon = "__base__/graphics/icons/burner-inserter.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/burner-inserter.png",
    small_icon_size = 64,
```

with:

```lua
    icon = "__SuperSample__/graphics/icons/pipette-toggle.png",
    icon_size = 64,
    small_icon = "__SuperSample__/graphics/icons/pipette-toggle.png",
    small_icon_size = 64,
```

- [ ] **Step 2: Sanity-check the Lua syntax**

Run: `luac -p data.lua` (from repo root; `-p` only parses/checks syntax, doesn't execute)
Expected: no output (no syntax errors). If `luac` isn't available, skip — the change is a string literal swap with no new syntax, but prefer running this if the tool is present.

- [ ] **Step 3: Commit**

```bash
git add data.lua
git commit -m "Use custom pipette icon for toggle shortcut instead of vanilla placeholder"
```

---

### Task 3: Bump the mod version

**Files:**
- Modify: `info.json:3`

- [ ] **Step 1: Bump the version field**

In `info.json`, change:

```json
  "version": "1.2.1",
```

to:

```json
  "version": "1.2.2",
```

- [ ] **Step 2: Verify the file is still valid JSON**

Run: `python -c "import json; print(json.load(open(r'C:/Dev/Factorio/SuperSample/info.json'))['version'])"`
Expected: `1.2.2`

- [ ] **Step 3: Commit**

```bash
git add info.json
git commit -m "Bump version to 1.2.2"
```

---

### Task 4: Rebuild the release zip and verify in-game

**Files:**
- None modified — packaging + manual verification only

- [ ] **Step 1: Run the existing packaging script**

Run: `& "C:\Dev\Factorio\SuperSample\tools\package-release.ps1"` (PowerShell)
Expected output: `Packaged: C:\Dev\Factorio\SuperSample\dist\SuperSample_1.2.2.zip`

- [ ] **Step 2: Confirm the new icon file is included in the zip**

Run: `unzip -l "C:/Dev/Factorio/SuperSample/dist/SuperSample_1.2.2.zip"`
Expected: listing includes `SuperSample_1.2.2/graphics/icons/pipette-toggle.png`

- [ ] **Step 3: Manually verify in-game**

Launch Factorio with the mod (junction already points at this repo, per project memory). Confirm:
- Shortcut bar shows the new pipette icon, not the burner-inserter icon.
- Icon is recognizable at actual shortcut-button size.
- Clicking the shortcut and pressing ALT+CAPSLOCK both still toggle it correctly (regression check — this task changes only the icon asset, not toggle logic).

This step is manual (no automated test harness for in-game rendering exists in this repo) — report back pass/fail before considering the plan complete.
