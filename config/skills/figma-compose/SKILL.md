---
name: figma-compose
description: Compose Figma design layers into optimized reference images. Use when the user wants to export/compose/combine image layers from a Figma design URL, create background images from Figma frames, generate multi-resolution assets (1x/2x/3x), or convert Figma designs to production-ready WebP/JPG images. Triggers on Figma URLs, "compose layers", "export from figma", "create reference image", "background image from design".
disable-model-invocation: true
allowed-tools: Bash(curl *), Bash(<workspace>/py/venv/bin/python3 *), Bash(<workspace>/py/venv/bin/pip *), Bash(open *), Bash(ls *), Bash(mkdir *)
---

# Figma Layer Composer

Compose image layers from a Figma design node into production-ready reference images.

## How It Works

1. Parse Figma URL → extract file key and node ID
2. Fetch node tree via Figma REST API
3. Classify layers: image layers (gradients, photos, shapes) vs text layers (skipped — rendered as HTML)
4. Export image layers from Figma at the highest requested scale
5. Compute exact positions from render bounds (including blur/effect extents)
6. Composite layers with alpha blending on the artboard background color
7. Auto-crop empty background edges (optional)
8. Save at multiple resolutions as WebP or JPG

## Prerequisites

Ensure Pillow and numpy are installed:
```bash
<workspace>/py/venv/bin/pip install Pillow numpy -q
```

## Figma Token

Retrieve the token from memory file `figma.md` in the project memory directory. If not found, ask the user to provide one (Figma → Settings → Personal access tokens).

## Usage

### Quick (script)

```bash
<workspace>/py/venv/bin/python3 ~/.claude/skills/figma-compose/scripts/compose.py \
  "<figma_url>" \
  --token "<token>" \
  --output "<output_dir>" \
  --name "<base_name>" \
  --scales 1,2 \
  --format webp \
  --quality 90 \
  --crop \
  --crop-sides left
```

### Manual (step-by-step)

Use the manual approach when:
- The script's layer classification needs overriding
- Custom positioning or layer ordering is needed
- The user wants to inspect/adjust between steps

#### Step 1: Fetch node tree
```bash
curl -s -H "X-Figma-Token: $TOKEN" \
  "https://api.figma.com/v1/files/$FILE_KEY/nodes?ids=$NODE_ID"
```

#### Step 2: Analyze the tree
Print each child with:
- `absoluteBoundingBox` (design position/size)
- `absoluteRenderBounds` (rendered position/size, accounts for effects)
- `clipsContent`, `rotation`, `opacity`, `blendMode`
- Classify as image or text layer

#### Step 3: Export image layers
```bash
curl -s -H "X-Figma-Token: $TOKEN" \
  "https://api.figma.com/v1/images/$FILE_KEY?ids=$NODE_IDS&scale=$SCALE&format=png"
```

#### Step 4: Compute positions
- Figma exports each node at its **unclipped render bounds** (including blur/shadow effects)
- The artboard's `absoluteBoundingBox` is the origin (0,0)
- For nodes with blur effects: render extends by `blur_radius` in all directions from the design bounds
- Position = `(unclipped_render_x - artboard_x) * scale`

#### Step 5: Compose with Pillow
```python
from PIL import Image
result = Image.new("RGBA", (canvas_w, canvas_h), (*bg_rgb, 255))
# For each layer (bottom to top):
temp = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
temp.paste(layer_img, (px, py))  # handle negative offsets
result = Image.alpha_composite(result, temp)
```

#### Step 6: Auto-crop and save
- Detect content bounds by comparing pixels against background color
- Round crop edges to multiples of 8 for compression efficiency
- Save at each requested scale as WebP (preferred) or JPG

## Key Insights

- **Export scale**: Figma exports at Nx of the **unclipped render bounds**, not the design bounds
- **Text layers**: Skip them — text is rendered as HTML in production. The composed image is the background.
- **Rotation**: Figma exports include rotation already applied. Don't re-rotate.
- **clipsContent**: The artboard clips, but individual layer exports are unclipped. Handle overflow during composition.
- **Blur effects**: Extend render bounds by the blur radius in all directions from the element's design bounds.
- **Background color**: Auto-detect from the artboard's fill. Common: `#070707` for dark themes.

## Common Patterns

### Desktop + Mobile
Figma designs often have desktop and mobile variants. The same image elements are repositioned for mobile. Export each variant separately — reusing desktop exports for mobile won't work because:
- Elements are resized/repositioned
- Blur effects render differently relative to different canvas sizes
- Mobile has different artboard dimensions

### Cropping for CSS
Background images often have large empty areas (solid background color) that CSS can handle. Crop these out and use `background-color` in CSS. Typical: crop left side (text area) for desktop, crop bottom (text area) for mobile.

### Output Naming
Follow the user's naming convention. Common pattern:
```
<section-name>-<variant>-@<scale>x.<format>
e.g., managed-ti-services-desktop-@2x.webp
```
