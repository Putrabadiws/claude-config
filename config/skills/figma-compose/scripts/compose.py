#!/usr/bin/env python3
"""
Figma Layer Composer — export image layers from a Figma node and composite them.

Usage:
    python compose.py <figma_url> [options]

Options:
    --token TOKEN        Figma personal access token
    --output DIR         Output directory (default: current dir)
    --name NAME          Output filename base (default: composed)
    --scales SCALES      Comma-separated scales, e.g. 1,2,3 (default: 1,2)
    --format FORMAT      Output format: webp or jpg (default: webp)
    --quality Q          Output quality 1-100 (default: 90)
    --bg COLOR           Background color hex (default: auto-detect from Figma)
    --crop               Auto-crop empty background edges
    --crop-sides SIDES   Which sides to crop: all, right, left, bottom, top
                         or combinations like left,bottom (default: all)
    --skip-text          Skip text-only frames (default: true)
    --dry-run            Print layer info without composing
"""

import argparse
import json
import math
import os
import re
import sys
import tempfile
import urllib.request


def parse_figma_url(url):
    """Extract file_key and node_id from a Figma URL."""
    m = re.search(r'/design/([A-Za-z0-9]+)/', url) or re.search(r'/file/([A-Za-z0-9]+)/', url)
    if not m:
        raise ValueError(f"Cannot extract file key from URL: {url}")
    file_key = m.group(1)

    node_id = None
    m = re.search(r'node-id=([^&]+)', url)
    if m:
        node_id = m.group(1).replace('-', ':')

    return file_key, node_id


def find_nodes(file_key, token, name=None, width=None, height=None, page=None):
    """
    Search the entire Figma file for frames matching criteria.
    Returns list of (node_id, width, height, path) tuples.
    """
    data = figma_api(f"/files/{file_key}", token)
    results = []

    w_tol = 2  # tolerance for dimension matching
    h_tol = 2

    def search(node, path=''):
        nname = node.get('name', '')
        ntype = node.get('type', '')
        nid = node.get('id', '')
        bbox = node.get('absoluteBoundingBox', {})
        nw = bbox.get('width', 0)
        nh = bbox.get('height', 0)
        current_path = f"{path}/{nname}"

        match = True
        if name and name not in nname:
            match = False
        if width and abs(nw - width) > w_tol:
            match = False
        if height and abs(nh - height) > h_tol:
            match = False
        if page and page.lower() not in current_path.lower():
            match = False

        if match and ntype == 'FRAME' and name:
            results.append((nid, nw, nh, current_path))

        for child in node.get('children', []):
            search(child, current_path)

    doc = data.get('document', {})
    for p in doc.get('children', []):
        search(p, '')

    return results


def figma_api(endpoint, token, retries=3, backoff=30):
    """Call Figma REST API with retry on rate limit."""
    import time
    url = f"https://api.figma.com/v1{endpoint}"
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"X-Figma-Token": token})
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < retries - 1:
                wait = backoff * (attempt + 1)
                print(f"  Rate limited, waiting {wait}s...")
                time.sleep(wait)
            else:
                raise


def download_file(url, dest):
    """Download a file from URL."""
    urllib.request.urlretrieve(url, dest)


def hex_to_rgb(hex_color):
    """Convert hex color to RGB tuple."""
    h = hex_color.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def figma_color_to_rgb(color):
    """Convert Figma color dict {r,g,b,a} (0-1 floats) to RGB tuple."""
    return (
        round(color['r'] * 255),
        round(color['g'] * 255),
        round(color['b'] * 255),
    )


def get_bg_color(node):
    """Extract background color from a Figma frame node."""
    fills = node.get('fills', [])
    for fill in fills:
        if fill.get('type') == 'SOLID' and fill.get('visible', True):
            return figma_color_to_rgb(fill['color'])
    bg = node.get('backgroundColor')
    if bg and bg.get('a', 0) > 0:
        return figma_color_to_rgb(bg)
    return (0, 0, 0)


def is_text_only(node):
    """Check if a node contains only text/UI elements (no images)."""
    ntype = node.get('type', '')
    if ntype == 'TEXT':
        return True
    if ntype == 'INSTANCE':
        # Check if it's a button/icon instance (small UI component)
        bbox = node.get('absoluteBoundingBox', {})
        w, h = bbox.get('width', 0), bbox.get('height', 0)
        if w < 300 and h < 100:
            return True
    children = node.get('children', [])
    if not children:
        return ntype == 'TEXT'
    return all(is_text_only(c) for c in children)


def has_image_content(node):
    """Check if a node contains image fills or visual content worth exporting."""
    ntype = node.get('type', '')
    if ntype in ('RECTANGLE', 'ELLIPSE', 'VECTOR', 'LINE'):
        fills = node.get('fills', [])
        for fill in fills:
            if fill.get('type') == 'IMAGE':
                return True
            if fill.get('type') in ('GRADIENT_LINEAR', 'GRADIENT_RADIAL', 'GRADIENT_ANGULAR', 'SOLID'):
                return True
        effects = node.get('effects', [])
        if effects:
            return True
    children = node.get('children', [])
    return any(has_image_content(c) for c in children)


def get_blur_radius(node):
    """Get the maximum blur radius from a node's effects."""
    max_blur = 0
    for effect in node.get('effects', []):
        if effect.get('type') == 'LAYER_BLUR' and effect.get('visible', True):
            max_blur = max(max_blur, effect.get('radius', 0))
    return max_blur


def compute_unclipped_render(node, artboard_bbox):
    """
    Compute the unclipped render bounds of a node, accounting for blur effects.
    Returns (x, y, w, h) relative to the artboard.
    """
    ax, ay = artboard_bbox['x'], artboard_bbox['y']

    def node_render_extent(n):
        """Get the full render extent of a single node including effects."""
        bbox = n.get('absoluteBoundingBox', {})
        if not bbox:
            return None

        x = bbox.get('x', 0)
        y = bbox.get('y', 0)
        w = bbox.get('width', 0)
        h = bbox.get('height', 0)

        blur = get_blur_radius(n)
        if blur > 0:
            x -= blur
            y -= blur
            w += blur * 2
            h += blur * 2

        return (x, y, x + w, y + h)

    def collect_extents(n):
        """Recursively collect render extents of all leaf nodes."""
        extents = []
        children = n.get('children', [])
        if not children:
            ext = node_render_extent(n)
            if ext:
                extents.append(ext)
        else:
            for child in children:
                extents.extend(collect_extents(child))
        # Also include this node's own effects
        if n.get('effects'):
            ext = node_render_extent(n)
            if ext:
                extents.append(ext)
        return extents

    extents = collect_extents(node)
    if not extents:
        bbox = node.get('absoluteBoundingBox', {})
        return (bbox.get('x', 0) - ax, bbox.get('y', 0) - ay,
                bbox.get('width', 0), bbox.get('height', 0))

    x_min = min(e[0] for e in extents)
    y_min = min(e[1] for e in extents)
    x_max = max(e[2] for e in extents)
    y_max = max(e[3] for e in extents)

    return (x_min - ax, y_min - ay, x_max - x_min, y_max - y_min)


def classify_layers(node, skip_text=True):
    """
    Classify direct children of a frame into image layers vs text layers.
    Returns list of (child_node, layer_type) tuples.
    """
    layers = []
    for child in node.get('children', []):
        if skip_text and is_text_only(child):
            layers.append((child, 'text'))
        else:
            layers.append((child, 'image'))
    return layers


def auto_crop(img, bg_color, sides='all', threshold=5):
    """
    Find crop bounds where content differs from background.
    Returns (left, top, right, bottom) crop box.
    """
    try:
        import numpy as np
    except ImportError:
        return (0, 0, img.width, img.height)

    pixels = np.array(img)
    bg = np.array(bg_color[:3])
    diff = np.abs(pixels[:, :, :3].astype(int) - bg.astype(int)).max(axis=2)
    content_mask = diff > threshold

    rows_with_content = np.any(content_mask, axis=1)
    cols_with_content = np.any(content_mask, axis=0)

    if not rows_with_content.any() or not cols_with_content.any():
        return (0, 0, img.width, img.height)

    top = int(np.argmax(rows_with_content))
    bottom = int(len(rows_with_content) - np.argmax(rows_with_content[::-1]))
    left = int(np.argmax(cols_with_content))
    right = int(len(cols_with_content) - np.argmax(cols_with_content[::-1]))

    side_set = set(s.strip() for s in sides.split(','))

    if 'all' not in side_set:
        if 'top' not in side_set:
            top = 0
        if 'bottom' not in side_set:
            bottom = img.height
        if 'left' not in side_set:
            left = 0
        if 'right' not in side_set:
            right = img.width

    # Round to nearest multiple of 8 for compression efficiency
    left = (left // 8) * 8
    top = (top // 8) * 8
    right = min(img.width, ((right + 7) // 8) * 8)
    bottom = min(img.height, ((bottom + 7) // 8) * 8)

    return (left, top, right, bottom)


def compose(args):
    from PIL import Image

    file_key, node_id = parse_figma_url(args.url)
    token = args.token
    scales = [int(s) for s in args.scales.split(',')]
    max_scale = max(scales)

    print(f"Figma file: {file_key}, node: {node_id}")
    print(f"Scales: {scales}, format: {args.format}, quality: {args.quality}")

    # 1. Fetch node tree
    print("\nFetching node tree...")
    data = figma_api(f"/files/{file_key}/nodes?ids={node_id}", token)
    node = data['nodes'][node_id]['document']
    artboard = node['absoluteBoundingBox']

    aw = artboard['width']
    ah = artboard['height']
    clips = node.get('clipsContent', False)

    print(f"Artboard: {aw}x{ah} (clips={clips})")

    # 2. Detect background color
    if args.bg:
        bg_rgb = hex_to_rgb(args.bg)
    else:
        bg_rgb = get_bg_color(node)
    print(f"Background: #{bg_rgb[0]:02x}{bg_rgb[1]:02x}{bg_rgb[2]:02x}")

    # 3. Classify layers
    layers = classify_layers(node, skip_text=args.skip_text)
    image_layers = [(child, lt) for child, lt in layers if lt == 'image']
    text_layers = [(child, lt) for child, lt in layers if lt == 'text']

    print(f"\nLayers: {len(image_layers)} image, {len(text_layers)} text (skipped)")
    for child, lt in layers:
        marker = '  [IMG]' if lt == 'image' else '  [TXT]'
        bbox = child.get('absoluteBoundingBox', {})
        rel_x = bbox.get('x', 0) - artboard['x']
        rel_y = bbox.get('y', 0) - artboard['y']
        print(f"  {marker} {child['name']} @ ({rel_x:.0f}, {rel_y:.0f}) "
              f"{bbox.get('width', 0):.0f}x{bbox.get('height', 0):.0f}")

    if args.dry_run:
        return

    if not image_layers:
        print("No image layers found. Nothing to compose.")
        return

    # 4. Export image layers from Figma
    node_ids = ','.join(child['id'] for child, _ in image_layers)
    print(f"\nExporting {len(image_layers)} layers at {max_scale}x...")
    export_data = figma_api(
        f"/images/{file_key}?ids={node_ids}&scale={max_scale}&format=png",
        token,
    )

    # 5. Download exports
    tmpdir = tempfile.mkdtemp()
    downloaded = {}
    for child, _ in image_layers:
        url = export_data['images'].get(child['id'])
        if not url:
            print(f"  WARNING: No export URL for {child['name']}")
            continue
        dest = os.path.join(tmpdir, f"{child['id'].replace(':', '_')}.png")
        print(f"  Downloading {child['name']}...")
        download_file(url, dest)
        downloaded[child['id']] = dest

    # 6. Compute positions and compose
    cw = round(aw * max_scale)
    ch = round(ah * max_scale)
    print(f"\nComposing at {max_scale}x: {cw}x{ch}")

    result = Image.new("RGBA", (cw, ch), (*bg_rgb, 255))

    for child, _ in image_layers:
        if child['id'] not in downloaded:
            continue

        img = Image.open(downloaded[child['id']])
        render = compute_unclipped_render(child, artboard)
        rx, ry, rw, rh = render

        # Position at max_scale
        px = round(rx * max_scale)
        py = round(ry * max_scale)

        print(f"  {child['name']}: export {img.size}, "
              f"pos ({px}, {py})")

        # Paste with alpha handling and negative offset clipping
        temp = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        src_x = max(0, -px)
        src_y = max(0, -py)
        dst_x = max(0, px)
        dst_y = max(0, py)
        paste_w = min(img.width - src_x, cw - dst_x)
        paste_h = min(img.height - src_y, ch - dst_y)

        if paste_w > 0 and paste_h > 0:
            cropped = img.crop((src_x, src_y, src_x + paste_w, src_y + paste_h))
            temp.paste(cropped, (dst_x, dst_y))
            result = Image.alpha_composite(result, temp)

    result_rgb = result.convert("RGB")

    # 7. Auto-crop if requested
    if args.crop:
        crop_box = auto_crop(result_rgb, bg_rgb, sides=args.crop_sides)
        print(f"\nAuto-crop: ({crop_box[0]}, {crop_box[1]}) to ({crop_box[2]}, {crop_box[3]})")
        result_rgb = result_rgb.crop(crop_box)
        cw, ch = result_rgb.size
        print(f"Cropped size at {max_scale}x: {cw}x{ch}")

    # 8. Save at each scale
    os.makedirs(args.output, exist_ok=True)
    ext = args.format
    fmt = 'WEBP' if ext == 'webp' else 'JPEG'

    print(f"\nSaving to {args.output}/")
    for scale in sorted(scales):
        sw = round(cw * scale / max_scale)
        sh = round(ch * scale / max_scale)
        suffix = f"@{scale}x" if len(scales) > 1 else ""
        filename = f"{args.name}{suffix}.{ext}"
        path = os.path.join(args.output, filename)

        if scale == max_scale:
            out = result_rgb
        else:
            out = result_rgb.resize((sw, sh), Image.LANCZOS)

        out.save(path, fmt, quality=args.quality)
        size_kb = os.path.getsize(path) / 1024
        print(f"  {filename}: {sw}x{sh} — {size_kb:.1f}KB")

    # Cleanup
    for f in downloaded.values():
        os.remove(f)
    os.rmdir(tmpdir)

    print("\nDone!")


def find_cmd(args):
    """Find nodes in a Figma file by name/dimensions."""
    file_key, _ = parse_figma_url(args.url)
    print(f"Searching {file_key} for name='{args.find_name}' w={args.width} h={args.height} page={args.page}...")
    results = find_nodes(file_key, args.token,
                         name=args.find_name,
                         width=args.width, height=args.height,
                         page=args.page)
    if not results:
        print("No matching frames found.")
        return
    print(f"\nFound {len(results)} matches:")
    for nid, w, h, path in results:
        print(f"  {nid:12s} {w:.0f}x{h:.0f}  {path}")


def main():
    parser = argparse.ArgumentParser(description="Compose Figma image layers into a reference image")
    sub = parser.add_subparsers(dest='command')

    # find subcommand
    find_p = sub.add_parser('find', help='Find frames by name/dimensions')
    find_p.add_argument('url', help='Figma design URL (file key extracted)')
    find_p.add_argument('--token', default=os.environ.get('FIGMA_TOKEN', ''),
                        help='Figma token')
    find_p.add_argument('--name', dest='find_name', required=True,
                        help='Frame name to search for (partial match)')
    find_p.add_argument('--width', type=float, default=None, help='Match width')
    find_p.add_argument('--height', type=float, default=None, help='Match height')
    find_p.add_argument('--page', default=None,
                        help='Filter by page/path (partial match)')

    # compose subcommand (default)
    comp_p = sub.add_parser('compose', help='Compose image layers')
    comp_p.add_argument('url', help='Figma design URL with node-id')
    comp_p.add_argument('--token', default=os.environ.get('FIGMA_TOKEN', ''),
                        help='Figma personal access token (or set FIGMA_TOKEN env)')
    comp_p.add_argument('--output', default='.', help='Output directory')
    comp_p.add_argument('--name', default='composed', help='Output filename base')
    comp_p.add_argument('--scales', default='1,2', help='Comma-separated scales')
    comp_p.add_argument('--format', default='webp', choices=['webp', 'jpg'],
                        help='Output format')
    comp_p.add_argument('--quality', type=int, default=90, help='Output quality 1-100')
    comp_p.add_argument('--bg', default=None, help='Background color hex (auto-detect if omitted)')
    comp_p.add_argument('--crop', action='store_true', help='Auto-crop empty background')
    comp_p.add_argument('--crop-sides', default='all',
                        help='Sides to crop: all, left, right, top, bottom (comma-separated)')
    comp_p.add_argument('--skip-text', action='store_true', default=True,
                        help='Skip text-only frames')
    comp_p.add_argument('--no-skip-text', action='store_false', dest='skip_text',
                        help='Include text frames')
    comp_p.add_argument('--dry-run', action='store_true',
                        help='Print layer info without composing')

    args = parser.parse_args()

    # Default to compose if no subcommand but URL has node-id
    if args.command is None:
        # Backward compat: treat as compose with positional args
        comp_p.parse_args(sys.argv[1:], namespace=args)
        args.command = 'compose'

    token = getattr(args, 'token', '') or os.environ.get('FIGMA_TOKEN', '')
    if not token:
        print("Error: Figma token required. Use --token or set FIGMA_TOKEN env var.")
        sys.exit(1)
    args.token = token

    if args.command == 'find':
        find_cmd(args)
    else:
        compose(args)


if __name__ == '__main__':
    main()
