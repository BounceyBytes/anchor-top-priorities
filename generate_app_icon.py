#!/usr/bin/env python3
"""
Generate updated Anchor app icons with flame/streak theme
"""

from PIL import Image, ImageDraw
import math

def create_gradient_background(width, height, color1, color2):
    """Create a vertical gradient background"""
    base = Image.new('RGB', (width, height), color1)
    top = Image.new('RGB', (width, height), color2)
    mask = Image.new('L', (width, height))
    mask_data = []
    for y in range(height):
        mask_data.extend([int(255 * (y / height))] * width)
    mask.putdata(mask_data)
    base.paste(top, (0, 0), mask)
    return base

def draw_anchor(draw, cx, cy, size, color):
    """Draw the anchor symbol"""
    # Anchor dimensions
    ring_radius = size * 0.12
    crossbar_width = size * 0.7
    crossbar_height = size * 0.12
    stem_width = size * 0.12
    stem_height = size * 0.55
    hook_width = size * 0.8
    hook_height = size * 0.25

    # Draw ring at top
    ring_bbox = [
        cx - ring_radius, cy - size * 0.45 - ring_radius,
        cx + ring_radius, cy - size * 0.45 + ring_radius
    ]
    draw.ellipse(ring_bbox, outline=color, width=int(size * 0.08))

    # Draw stem
    stem_bbox = [
        cx - stem_width / 2, cy - size * 0.45,
        cx + stem_width / 2, cy + stem_height - size * 0.45
    ]
    draw.rounded_rectangle(stem_bbox, radius=stem_width / 2, fill=color)

    # Draw crossbar
    crossbar_bbox = [
        cx - crossbar_width / 2, cy - crossbar_height / 2,
        cx + crossbar_width / 2, cy + crossbar_height / 2
    ]
    draw.rounded_rectangle(crossbar_bbox, radius=crossbar_height / 2, fill=color)

    # Draw anchor hooks (bottom curves)
    # Left hook
    left_hook_points = []
    for i in range(20):
        angle = math.pi * (0.5 + i / 40.0)
        x = cx - hook_width / 4 + math.cos(angle) * hook_width / 3
        y = cy + stem_height - size * 0.45 + math.sin(angle) * hook_height
        left_hook_points.append((x, y))

    if len(left_hook_points) >= 2:
        draw.line(left_hook_points, fill=color, width=int(size * 0.12), joint='curve')

    # Right hook
    right_hook_points = []
    for i in range(20):
        angle = math.pi * (0.5 + i / 40.0)
        x = cx + hook_width / 4 - math.cos(angle) * hook_width / 3
        y = cy + stem_height - size * 0.45 + math.sin(angle) * hook_height
        right_hook_points.append((x, y))

    if len(right_hook_points) >= 2:
        draw.line(right_hook_points, fill=color, width=int(size * 0.12), joint='curve')

    # Add triangular points at hook ends
    # Left triangle
    draw.polygon([
        (cx - hook_width * 0.42, cy + stem_height - size * 0.45 + hook_height * 0.7),
        (cx - hook_width * 0.47, cy + stem_height - size * 0.45 + hook_height * 0.95),
        (cx - hook_width * 0.32, cy + stem_height - size * 0.45 + hook_height * 0.85)
    ], fill=color)

    # Right triangle
    draw.polygon([
        (cx + hook_width * 0.42, cy + stem_height - size * 0.45 + hook_height * 0.7),
        (cx + hook_width * 0.47, cy + stem_height - size * 0.45 + hook_height * 0.95),
        (cx + hook_width * 0.32, cy + stem_height - size * 0.45 + hook_height * 0.85)
    ], fill=color)

def draw_flame(draw, cx, cy, size, colors):
    """Draw a stylized flame behind the anchor"""
    flame_height = size * 0.35
    flame_width = size * 0.25

    # Outer flame (orange/red)
    outer_points = [
        (cx, cy - flame_height * 0.7),  # Top point
        (cx - flame_width * 0.7, cy - flame_height * 0.3),  # Left curve
        (cx - flame_width * 0.4, cy),  # Left bottom
        (cx, cy - flame_height * 0.15),  # Center dip
        (cx + flame_width * 0.4, cy),  # Right bottom
        (cx + flame_width * 0.7, cy - flame_height * 0.3),  # Right curve
    ]
    draw.polygon(outer_points, fill=colors[0])

    # Inner flame (yellow/white) - smaller and higher
    inner_points = [
        (cx, cy - flame_height * 0.55),
        (cx - flame_width * 0.35, cy - flame_height * 0.2),
        (cx - flame_width * 0.2, cy - flame_height * 0.05),
        (cx, cy - flame_height * 0.1),
        (cx + flame_width * 0.2, cy - flame_height * 0.05),
        (cx + flame_width * 0.35, cy - flame_height * 0.2),
    ]
    draw.polygon(inner_points, fill=colors[1])

def create_app_icon(filename, bg_color1, bg_color2, anchor_color, include_flame=True, flame_colors=None):
    """Create a 1024x1024 app icon"""
    size = 1024
    img = create_gradient_background(size, size, bg_color1, bg_color2)
    draw = ImageDraw.Draw(img, 'RGBA')

    center_x = size // 2
    center_y = size // 2
    symbol_size = size * 0.55

    # Draw flame if requested (behind anchor)
    if include_flame and flame_colors:
        flame_y = center_y - symbol_size * 0.65
        draw_flame(draw, center_x, flame_y, symbol_size, flame_colors)

    # Draw anchor
    draw_anchor(draw, center_x, center_y, symbol_size, anchor_color)

    # Round the corners for iOS icon
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = int(size * 0.2237)  # iOS icon corner radius ratio
    mask_draw.rounded_rectangle([(0, 0), (size, size)], corner_radius, fill=255)

    # Apply mask
    output = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    output.paste(img, (0, 0))
    output.putalpha(mask)

    # Convert to RGB with white background (for non-transparent formats)
    final = Image.new('RGB', (size, size), 'white')
    final.paste(output, (0, 0), output)

    final.save(filename, 'PNG', quality=100)
    print(f"Created: {filename}")

# Generate the three app icon variants
if __name__ == '__main__':
    # Default (light) - Coral/Orange gradient with flame
    create_app_icon(
        '/home/user/anchor-top-priorities/Anchor/Assets.xcassets/AppIcon.appiconset/AppIcon-Default.png',
        bg_color1=(255, 107, 107),  # Coral (lighter)
        bg_color2=(255, 87, 87),    # Coral (darker) - matching anchorCoral
        anchor_color=(255, 255, 255),  # White
        include_flame=True,
        flame_colors=(
            (255, 159, 67),   # Orange
            (255, 223, 117)   # Light yellow
        )
    )

    # Dark - Darker gradient with blue flame
    create_app_icon(
        '/home/user/anchor-top-priorities/Anchor/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png',
        bg_color1=(40, 44, 52),     # Dark gray
        bg_color2=(28, 31, 38),     # Darker gray
        anchor_color=(255, 255, 255),  # White
        include_flame=True,
        flame_colors=(
            (100, 181, 246),  # Blue
            (129, 212, 250)   # Light blue
        )
    )

    # Tinted - Similar to default but slightly different
    create_app_icon(
        '/home/user/anchor-top-priorities/Anchor/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png',
        bg_color1=(255, 138, 101),  # Lighter coral/peach
        bg_color2=(255, 112, 97),   # Coral
        anchor_color=(255, 255, 255),  # White
        include_flame=True,
        flame_colors=(
            (255, 193, 7),    # Amber
            (255, 235, 59)    # Yellow
        )
    )

    print("\n✅ All app icons generated successfully!")
    print("The icons now feature the streak flame theme while keeping the anchor symbol.")
