#!/usr/bin/env python3
"""Generate an app icon that mimics the Invoice Bills app UI screenshot."""

import os
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024

# App colours (matching the Flutter app)
PRIMARY      = (26, 35, 126)    # #1a237e  – dark blue
MID_BLUE     = (57, 73, 171)    # #3949ab
ACCENT_BLUE  = (63, 81, 181)    # summary pill bg
LIGHT_BG     = (240, 242, 248)  # page background
CARD_WHITE   = (255, 255, 255)
BORDER_GRAY  = (210, 214, 230)
TEXT_DARK    = (26, 35, 126)    # primary blue for headings
TEXT_GRAY    = (120, 130, 150)  # placeholder / secondary
TEXT_LIGHT   = (255, 255, 255)
TOTAL_BAR    = (26, 35, 126)
RUPEE_GREEN  = (255, 255, 255)

def load_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()

MONO_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
MONO      = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
SANS_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SANS      = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

def draw_rounded_rect(draw, box, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = box
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius,
                            fill=fill, outline=outline, width=width)

def make_icon():
    img = Image.new("RGB", (SIZE, SIZE), LIGHT_BG)
    draw = ImageDraw.Draw(img)

    # ── Scaling helper ────────────────────────────────────────────────────────
    # We'll lay out the UI in a 390-wide "virtual" space (phone width)
    # and scale everything up to fill 1024.
    S = SIZE / 390  # ≈ 2.626

    def s(v):
        return int(v * S)

    # ── Background ────────────────────────────────────────────────────────────
    draw.rectangle([0, 0, SIZE, SIZE], fill=LIGHT_BG)

    # ── App header bar ────────────────────────────────────────────────────────
    header_h = s(82)
    # Gradient: draw slices from PRIMARY → MID_BLUE
    for y in range(header_h):
        t = y / header_h
        r = int(PRIMARY[0] + (MID_BLUE[0] - PRIMARY[0]) * t)
        g = int(PRIMARY[1] + (MID_BLUE[1] - PRIMARY[1]) * t)
        b = int(PRIMARY[2] + (MID_BLUE[2] - PRIMARY[2]) * t)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

    # "My Store" title
    f_store_name = load_font(SANS_BOLD, s(22))
    f_tagline    = load_font(SANS, s(13))
    draw.text((s(16), s(20)), "My Store", font=f_store_name, fill=TEXT_LIGHT)
    draw.text((s(16), s(47)), "Quality Products | Trusted Service",
              font=f_tagline, fill=(200, 210, 255))

    # Icons on the right (moon, history, settings) — simple circles/shapes
    icon_y = s(28)
    for ix, shape in enumerate(["moon", "clock", "gear"]):
        cx = SIZE - s(20) - s(ix * 38)
        cy = icon_y + s(10)
        r  = s(11)
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=TEXT_LIGHT, width=s(2))
        if shape == "gear":
            # small dot in center
            draw.ellipse([cx-s(4), cy-s(4), cx+s(4), cy+s(4)],
                         fill=TEXT_LIGHT)
        elif shape == "clock":
            draw.line([cx, cy-s(6), cx, cy], fill=TEXT_LIGHT, width=s(2))
            draw.line([cx, cy, cx+s(5), cy], fill=TEXT_LIGHT, width=s(2))
        elif shape == "moon":
            # crescent: filled circle with offset cutout
            draw.ellipse([cx-r+s(2), cy-r+s(2), cx+r-s(2), cy+r-s(2)],
                         fill=TEXT_LIGHT)
            draw.ellipse([cx-r+s(6), cy-r, cx+r+s(2), cy+r],
                         fill=MID_BLUE)

    # ── Today's Sales summary bar ─────────────────────────────────────────────
    bar_y  = header_h + s(12)
    bar_h  = s(52)
    bar_x0 = s(12)
    bar_x1 = SIZE - s(12)
    # Gradient bar (same as header, slightly lighter)
    for y in range(bar_h):
        t = y / bar_h
        r2 = int(MID_BLUE[0] + (ACCENT_BLUE[0] - MID_BLUE[0]) * t)
        g2 = int(MID_BLUE[1] + (ACCENT_BLUE[1] - MID_BLUE[1]) * t)
        b2 = int(MID_BLUE[2] + (ACCENT_BLUE[2] - MID_BLUE[2]) * t)
        draw.line([(bar_x0, bar_y + y), (bar_x1, bar_y + y)], fill=(r2, g2, b2))
    draw_rounded_rect(draw, [bar_x0, bar_y, bar_x1, bar_y + bar_h],
                      radius=s(14), outline=MID_BLUE, width=s(1))

    f_bar = load_font(SANS_BOLD, s(15))
    f_bar_sm = load_font(SANS, s(13))
    # "Today's Sales" label
    draw.text((bar_x0 + s(14), bar_y + s(16)), "Today's Sales",
              font=f_bar_sm, fill=(200, 210, 255))

    # Pill: "1 invoice"
    pill_x = bar_x0 + s(132)
    pill_y = bar_y + s(10)
    pill_w, pill_h2 = s(80), s(30)
    draw_rounded_rect(draw,
                      [pill_x, pill_y, pill_x + pill_w, pill_y + pill_h2],
                      radius=s(15), fill=(80, 100, 190))
    draw.text((pill_x + s(10), pill_y + s(7)), "1 invoice",
              font=f_bar_sm, fill=TEXT_LIGHT)

    # Rupee + amount
    f_amount = load_font(SANS_BOLD, s(18))
    draw.text((bar_x0 + s(224), bar_y + s(14)), "Rs. 9,300",
              font=f_amount, fill=TEXT_LIGHT)

    # ── Invoice number card ───────────────────────────────────────────────────
    card1_y  = bar_y + bar_h + s(12)
    card1_h  = s(90)
    cx0, cx1 = s(12), SIZE - s(12)
    draw_rounded_rect(draw, [cx0, card1_y, cx1, card1_y + card1_h],
                      radius=s(14), fill=CARD_WHITE, outline=BORDER_GRAY,
                      width=s(1))
    f_inv_no = load_font(SANS_BOLD, s(22))
    f_date   = load_font(SANS, s(13))
    draw.text((cx0 + s(16), card1_y + s(14)), "IC-002",
              font=f_inv_no, fill=TEXT_DARK)
    draw.text((cx0 + s(180), card1_y + s(18)), "12/04/2026  10:49",
              font=f_date, fill=TEXT_GRAY)

    # Customer name field
    field_y = card1_y + s(50)
    field_h = s(34)
    draw_rounded_rect(draw,
                      [cx0 + s(12), field_y, cx1 - s(12), field_y + field_h],
                      radius=s(8), fill=(248, 249, 255), outline=BORDER_GRAY,
                      width=s(1))
    f_field = load_font(SANS, s(14))
    # person icon placeholder
    draw.ellipse([cx0 + s(22), field_y + s(8),
                  cx0 + s(34), field_y + s(20)], fill=TEXT_GRAY)
    draw.text((cx0 + s(40), field_y + s(9)), "Customer Name",
              font=f_field, fill=TEXT_GRAY)

    # ── Items card ────────────────────────────────────────────────────────────
    items_y  = card1_y + card1_h + s(10)
    items_h  = s(200)
    draw_rounded_rect(draw, [cx0, items_y, cx1, items_y + items_h],
                      radius=s(14), fill=CARD_WHITE, outline=BORDER_GRAY,
                      width=s(1))

    f_items_hdr = load_font(SANS_BOLD, s(17))
    f_col_hdr   = load_font(SANS, s(12))
    draw.text((cx0 + s(16), items_y + s(12)), "Items",
              font=f_items_hdr, fill=TEXT_DARK)

    # Column headers
    col_y = items_y + s(38)
    draw.line([(cx0 + s(14), col_y + s(16)), (cx1 - s(14), col_y + s(16))],
              fill=BORDER_GRAY, width=s(1))
    cols = [("Item", s(16)), ("Qty", s(160)), ("Price", s(224)), ("Total", s(300))]
    for label, offset in cols:
        draw.text((cx0 + offset, col_y), label, font=f_col_hdr, fill=TEXT_GRAY)

    # One item row with input boxes
    row_y = col_y + s(24)
    boxes = [(s(16), s(72)), (s(150), s(44)), (s(210), s(54))]
    f_ph = load_font(SANS, s(12))
    labels = ["Name", "Qty", "Pr..."]
    for (bx, bw), lbl in zip(boxes, labels):
        draw_rounded_rect(draw,
                          [cx0 + bx, row_y, cx0 + bx + bw, row_y + s(32)],
                          radius=s(6), fill=(248, 249, 255), outline=BORDER_GRAY,
                          width=s(1))
        draw.text((cx0 + bx + s(6), row_y + s(9)), lbl,
                  font=f_ph, fill=TEXT_GRAY)
    # — and × buttons
    draw.text((cx0 + s(282), row_y + s(9)), "—", font=f_ph, fill=TEXT_GRAY)
    draw.text((cx0 + s(308), row_y + s(9)), "×", font=f_ph, fill=TEXT_GRAY)

    # + Add Item
    add_y = row_y + s(42)
    f_add = load_font(SANS_BOLD, s(14))
    draw.text((cx0 + s(28), add_y), "+ Add Item", font=f_add, fill=TEXT_DARK)

    # ── Grand Total bar ───────────────────────────────────────────────────────
    gt_y  = items_y + items_h + s(10)
    gt_h  = s(56)
    for y in range(gt_h):
        t = y / gt_h
        r3 = int(PRIMARY[0] + (MID_BLUE[0] - PRIMARY[0]) * t)
        g3 = int(PRIMARY[1] + (MID_BLUE[1] - PRIMARY[1]) * t)
        b3 = int(PRIMARY[2] + (MID_BLUE[2] - PRIMARY[2]) * t)
        draw.line([(cx0, gt_y + y), (cx1, gt_y + y)], fill=(r3, g3, b3))
    draw_rounded_rect(draw, [cx0, gt_y, cx1, gt_y + gt_h],
                      radius=s(12), outline=PRIMARY, width=s(1))
    f_total = load_font(SANS_BOLD, s(18))
    draw.text((cx0 + s(18), gt_y + s(17)), "Grand Total",
              font=f_total, fill=TEXT_LIGHT)
    amt_text = "Rs. 0.00"
    f_amt = load_font(SANS_BOLD, s(20))
    bbox = draw.textbbox((0, 0), amt_text, font=f_amt)
    aw = bbox[2] - bbox[0]
    draw.text((cx1 - aw - s(18), gt_y + s(16)), amt_text,
              font=f_amt, fill=TEXT_LIGHT)

    # ── Bottom buttons ────────────────────────────────────────────────────────
    btn_y  = gt_y + gt_h + s(10)
    btn_h  = s(52)
    mid    = SIZE // 2

    # Clear button (outlined)
    draw_rounded_rect(draw, [cx0, btn_y, mid - s(6), btn_y + btn_h],
                      radius=s(12), fill=CARD_WHITE, outline=PRIMARY, width=s(2))
    f_btn = load_font(SANS_BOLD, s(15))
    draw.text((cx0 + s(28), btn_y + s(17)), "✕  Clear",
              font=f_btn, fill=TEXT_DARK)

    # Generate Invoice button (filled)
    for y in range(btn_h):
        t = y / btn_h
        r4 = int(PRIMARY[0] + (MID_BLUE[0] - PRIMARY[0]) * t)
        g4 = int(PRIMARY[1] + (MID_BLUE[1] - PRIMARY[1]) * t)
        b4 = int(PRIMARY[2] + (MID_BLUE[2] - PRIMARY[2]) * t)
        draw.line([(mid + s(6), btn_y + y), (cx1, btn_y + y)],
                  fill=(r4, g4, b4))
    draw_rounded_rect(draw, [mid + s(6), btn_y, cx1, btn_y + btn_h],
                      radius=s(12), outline=PRIMARY, width=s(1))
    draw.text((mid + s(16), btn_y + s(17)), "Generate Invoice",
              font=f_btn, fill=TEXT_LIGHT)

    # ── Save ──────────────────────────────────────────────────────────────────
    out_path = "shakti_invoice/assets/icon/icon.png"
    img.save(out_path, "PNG")
    print(f"Saved master icon → {out_path}")

    densities = {
        "mdpi":    48, "hdpi": 72, "xhdpi": 96,
        "xxhdpi":  144, "xxxhdpi": 192,
    }
    for density, px_size in densities.items():
        resized = img.resize((px_size, px_size), Image.LANCZOS)
        base_dir = f"shakti_invoice/android/app/src/main/res/mipmap-{density}"
        for fname in ["ic_launcher.png", "ic_launcher_round.png"]:
            dest = os.path.join(base_dir, fname)
            os.makedirs(base_dir, exist_ok=True)
            resized.save(dest, "PNG")
            print(f"  → {dest} ({px_size}×{px_size})")

    print("\nDone!")


if __name__ == "__main__":
    make_icon()
