#!/usr/bin/env python3
"""Generate a Matrix-style bill app icon for Invoice Bills."""

import os
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
BG_COLOR = (0, 0, 0)
NEON_GREEN = (0, 255, 65)
DIM_GREEN = (0, 80, 20)
DARK_GREEN = (0, 30, 8)
MID_GREEN = (0, 180, 40)
PANEL_BG = (8, 20, 8)
PANEL_BORDER = (0, 255, 65)


def draw_glow_text(draw, pos, text, font, color, glow_color, glow_radius=6):
    """Draw text with a glow effect."""
    x, y = pos
    # Draw glow layers
    for r in range(glow_radius, 0, -1):
        alpha = int(180 * (glow_radius - r) / glow_radius)
        gc = (glow_color[0], glow_color[1], glow_color[2])
        for dx in range(-r, r+1):
            for dy in range(-r, r+1):
                if abs(dx) == r or abs(dy) == r:
                    draw.text((x+dx, y+dy), text, font=font, fill=gc)
    draw.text(pos, text, font=font, fill=color)


def make_icon():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR + (255,))
    draw = ImageDraw.Draw(img)

    # ── 1. Matrix rain columns ───────────────────────────────────────────────
    rain_chars = list("01010110100110") + list("アイウエオカキクケコ") + list("ABCDEF01")
    col_w = 28
    num_cols = SIZE // col_w

    random.seed(42)
    for col in range(num_cols):
        x = col * col_w + 4
        num_chars = random.randint(10, 40)
        start_y = random.randint(-20 * col_w, 0)
        for row in range(num_chars):
            y = start_y + row * 26
            if y < 0 or y > SIZE:
                continue
            # Fade green based on vertical position
            fade = 1.0 - (y / SIZE) * 0.7
            g_val = int(255 * fade)
            b_val = int(65 * fade)
            alpha = int(200 * fade)
            char = random.choice(rain_chars)
            # Top char is brighter
            if row == num_chars - 1:
                g_val = 255
                b_val = 65
                alpha = 255
            try:
                font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 18)
            except Exception:
                font_small = ImageFont.load_default()
            draw.text((x, y), char, font=font_small, fill=(0, g_val, b_val, alpha))

    # ── 2. Central receipt panel ─────────────────────────────────────────────
    panel_w = 520
    panel_h = 620
    px = (SIZE - panel_w) // 2
    py = (SIZE - panel_h) // 2 - 20

    # Glow halo around panel
    glow_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    for offset in range(18, 0, -3):
        alpha = int(80 * (18 - offset) / 18)
        glow_draw.rounded_rectangle(
            [px - offset, py - offset, px + panel_w + offset, py + panel_h + offset],
            radius=18, outline=(0, 255, 65, alpha), width=4
        )
    img = Image.alpha_composite(img, glow_img)
    draw = ImageDraw.Draw(img)

    # Panel background (dark green, semi-opaque)
    panel_overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    panel_draw = ImageDraw.Draw(panel_overlay)
    panel_draw.rounded_rectangle(
        [px, py, px + panel_w, py + panel_h],
        radius=14, fill=PANEL_BG + (230,)
    )
    img = Image.alpha_composite(img, panel_overlay)
    draw = ImageDraw.Draw(img)

    # Panel border (neon green, 3px)
    draw.rounded_rectangle(
        [px, py, px + panel_w, py + panel_h],
        radius=14, outline=PANEL_BORDER, width=3
    )

    # ── 3. Zigzag bottom of receipt ──────────────────────────────────────────
    zigzag_y = py + panel_h - 40
    zz_points = []
    step = 20
    for i in range(panel_w // step + 1):
        x_z = px + i * step
        y_z = zigzag_y + (10 if i % 2 == 0 else 0)
        zz_points.append((x_z, y_z))
    # Draw a filled white area below the zigzag to "cut" the receipt look
    cut_pts = zz_points + [(px + panel_w, py + panel_h), (px, py + panel_h)]
    # Instead, just redraw the border below zigzag as dark
    fill_overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fill_draw = ImageDraw.Draw(fill_overlay)
    fill_draw.polygon(cut_pts, fill=(8, 20, 8, 230))
    img = Image.alpha_composite(img, fill_overlay)
    draw = ImageDraw.Draw(img)
    draw.line(zz_points, fill=NEON_GREEN, width=2)

    # ── 4. Header: ₹ INVOICE ─────────────────────────────────────────────────
    try:
        font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 62)
        font_sub = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 32)
        font_item = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 22)
        font_total = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 36)
        font_small2 = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 20)
    except Exception:
        font_title = font_sub = font_item = font_total = font_small2 = ImageFont.load_default()

    # Rupee symbol + INVOICE
    header_text = "Rs. INVOICE"
    bbox = draw.textbbox((0, 0), header_text, font=font_title)
    tw = bbox[2] - bbox[0]
    tx = (SIZE - tw) // 2
    ty = py + 38

    # Glow for title
    for r in range(12, 0, -2):
        ga = int(100 * (12 - r) / 12)
        for dx in [-r, 0, r]:
            for dy in [-r, 0, r]:
                draw.text((tx+dx, ty+dy), header_text, font=font_title,
                          fill=(0, 220, 40, ga))
    draw.text((tx, ty), header_text, font=font_title, fill=NEON_GREEN)

    # Separator line 1
    sep1_y = ty + 80
    draw.line([(px + 24, sep1_y), (px + panel_w - 24, sep1_y)],
              fill=NEON_GREEN, width=2)

    # ── 5. "BILLS" subtitle ───────────────────────────────────────────────────
    sub_text = ">> BILL GENERATOR <<"
    bbox2 = draw.textbbox((0, 0), sub_text, font=font_small2)
    sw = bbox2[2] - bbox2[0]
    sx = (SIZE - sw) // 2
    sy = sep1_y + 12
    draw.text((sx, sy), sub_text, font=font_small2, fill=MID_GREEN)

    # ── 6. Item rows ─────────────────────────────────────────────────────────
    item_start_y = sy + 44
    items = [
        ("ITEM_001........", "x2", "200.00"),
        ("ITEM_002........", "x1", "150.00"),
        ("ITEM_003........", "x3", "450.00"),
        ("ITEM_004........", "x5", "100.00"),
    ]
    row_h = 38
    for i, (name, qty, price) in enumerate(items):
        iy = item_start_y + i * row_h
        # Draw dim green row
        row_color = DIM_GREEN if i % 2 == 0 else DARK_GREEN
        draw.rectangle([px+12, iy-2, px+panel_w-12, iy+30], fill=row_color)
        draw.text((px+22, iy+4), name, font=font_item, fill=(0, 160, 40))
        draw.text((px+320, iy+4), qty, font=font_item, fill=(0, 200, 50))
        price_bbox = draw.textbbox((0, 0), price, font=font_item)
        pw2 = price_bbox[2] - price_bbox[0]
        draw.text((px + panel_w - pw2 - 22, iy+4), price, font=font_item,
                  fill=MID_GREEN)

    # Separator line 2
    sep2_y = item_start_y + len(items) * row_h + 14
    draw.line([(px + 24, sep2_y), (px + panel_w - 24, sep2_y)],
              fill=NEON_GREEN, width=2)

    # ── 7. TOTAL line ─────────────────────────────────────────────────────────
    total_y = sep2_y + 18
    total_label = "TOTAL:"
    total_val = "Rs. 900.00"
    draw.text((px + 22, total_y), total_label, font=font_total, fill=NEON_GREEN)
    val_bbox = draw.textbbox((0, 0), total_val, font=font_total)
    vw = val_bbox[2] - val_bbox[0]
    # Glow for total value
    for r in range(8, 0, -2):
        ga = int(80 * (8 - r) / 8)
        draw.text((px + panel_w - vw - 22 + r//2, total_y), total_val,
                  font=font_total, fill=(0, 255, 65, ga))
    draw.text((px + panel_w - vw - 22, total_y), total_val, font=font_total,
              fill=NEON_GREEN)

    # ── 8. Scan-line overlay ──────────────────────────────────────────────────
    scan_overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    scan_draw = ImageDraw.Draw(scan_overlay)
    for sy2 in range(0, SIZE, 4):
        scan_draw.line([(0, sy2), (SIZE, sy2)], fill=(0, 0, 0, 25))
    img = Image.alpha_composite(img, scan_overlay)

    # ── 9. Convert and save ───────────────────────────────────────────────────
    out = img.convert("RGB")
    out_path = "shakti_invoice/assets/icon/icon.png"
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out.save(out_path, "PNG")
    print(f"Saved master icon → {out_path}")

    # Resize to all mipmap densities
    densities = {
        "mdpi":    48,
        "hdpi":    72,
        "xhdpi":   96,
        "xxhdpi":  144,
        "xxxhdpi": 192,
    }
    for density, px_size in densities.items():
        resized = out.resize((px_size, px_size), Image.LANCZOS)
        base_dir = f"shakti_invoice/android/app/src/main/res/mipmap-{density}"
        for fname in ["ic_launcher.png", "ic_launcher_round.png"]:
            dest = os.path.join(base_dir, fname)
            os.makedirs(base_dir, exist_ok=True)
            resized.save(dest, "PNG")
            print(f"  → {dest} ({px_size}x{px_size})")

    print("\nDone! All icon files updated.")


if __name__ == "__main__":
    make_icon()
