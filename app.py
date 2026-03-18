from flask import Flask, render_template, request, jsonify, send_file
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import cm, mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, HRFlowable
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import gspread
from google.oauth2.service_account import Credentials
from datetime import datetime
import traceback
import threading
import webbrowser
import socket
import os
import sys

app = Flask(__name__)

# ── Paths ──────────────────────────────────────────────────────────────────────
DESKTOP      = os.path.join(os.path.expanduser("~"), "Desktop")
BASE_DIR     = os.path.join(DESKTOP, "ShaktiGeneralStore")
INVOICES_DIR = os.path.join(BASE_DIR, "invoices")
CREDS_FILE   = os.path.join(BASE_DIR, "credentials.json")
SHEET_NAME   = "Invoices"

os.makedirs(INVOICES_DIR, exist_ok=True)

# ── Local network IP ───────────────────────────────────────────────────────────
def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return None

LOCAL_IP = get_local_ip()

# ── Register Arial for ₹ symbol (Windows) ─────────────────────────────────────
FONT_REGISTERED = False
try:
    pdfmetrics.registerFont(TTFont("Arial",        "C:/Windows/Fonts/arial.ttf"))
    pdfmetrics.registerFont(TTFont("Arial-Bold",   "C:/Windows/Fonts/arialbd.ttf"))
    pdfmetrics.registerFont(TTFont("Arial-Italic", "C:/Windows/Fonts/ariali.ttf"))
    FONT_REGISTERED = True
except Exception:
    pass

FONT        = "Arial"        if FONT_REGISTERED else "Helvetica"
FONT_BOLD   = "Arial-Bold"   if FONT_REGISTERED else "Helvetica-Bold"
FONT_ITALIC = "Arial-Italic" if FONT_REGISTERED else "Helvetica-Oblique"
RUPEE       = "₹"            if FONT_REGISTERED else "Rs."

# ── Google Sheets ───────────────────────────────────────────────────────────────
SCOPES = [
    "https://spreadsheets.google.com/feeds",
    "https://www.googleapis.com/auth/drive",
]

def _creds():
    return Credentials.from_service_account_file(CREDS_FILE, scopes=SCOPES)

def get_sheet():
    return gspread.authorize(_creds()).open(SHEET_NAME).sheet1

def ensure_header(sheet):
    if not sheet.row_values(1):
        sheet.append_row(
            ["Date", "Time", "Day", "Customer Name", "Grand Total (Rs)", "Paid", "Balance"],
            value_input_option="USER_ENTERED",
        )

def get_next_invoice_number():
    """Derive next invoice number by scanning local PDF files."""
    nums = []
    for root, dirs, files in os.walk(INVOICES_DIR):
        for f in files:
            if f.endswith(".pdf") and not f.endswith("_52mm.pdf") and f.startswith("SGS-"):
                try:
                    nums.append(int(f.split("-")[1].split("_")[0]))
                except (ValueError, IndexError):
                    pass
    return f"SGS-{(max(nums) + 1 if nums else 1):03d}"

# ── Invoice folder (year/month structure) ──────────────────────────────────────
def get_invoice_folder(date_str):
    """Return (and create) invoices/YYYY/MM/ path from date string DD-MM-YYYY."""
    try:
        parts       = date_str.replace("/", "-").split("-")
        day, month, year = parts[0], parts[1], parts[2]
    except Exception:
        from datetime import datetime
        now   = datetime.now()
        year  = str(now.year)
        month = f"{now.month:02d}"
    folder = os.path.join(INVOICES_DIR, year, month)
    os.makedirs(folder, exist_ok=True)
    return folder

# ── Routes ─────────────────────────────────────────────────────────────────────
@app.route("/")
def index():
    return render_template("index.html", local_ip=LOCAL_IP)

@app.route("/get_invoice_number")
def get_invoice_number():
    try:
        inv_no = get_next_invoice_number()
        return jsonify({"invoice_no": inv_no})
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route("/generate", methods=["POST"])
def generate():
    data          = request.json
    customer_name = data["customer_name"].strip()
    datetime_str  = data["datetime"]
    invoice_no    = data["invoice_no"]
    items         = data["items"]
    grand_total   = float(data["grand_total"])

    if not customer_name:
        return jsonify({"error": "Customer name is required."}), 400
    if not items:
        return jsonify({"error": "Add at least one item."}), 400

    safe_customer    = "".join(c if c.isalnum() or c in " _-" else "_" for c in customer_name).strip()
    date_part        = datetime_str.split()[0].replace("/", "-")   # DD-MM-YYYY
    pdf_filename     = f"{invoice_no}_{safe_customer}_{date_part}.pdf"
    thermal_filename = f"{invoice_no}_{safe_customer}_{date_part}_52mm.pdf"
    print(f"[PDF] Saving as: {pdf_filename}")

    invoice_folder = get_invoice_folder(date_part)
    pdf_path       = os.path.join(invoice_folder, pdf_filename)
    thermal_path   = os.path.join(invoice_folder, thermal_filename)

    # Relative paths for URL routing (always forward slashes)
    rel_pdf     = os.path.relpath(pdf_path,     INVOICES_DIR).replace("\\", "/")
    rel_thermal = os.path.relpath(thermal_path, INVOICES_DIR).replace("\\", "/")

    try:
        generate_pdf(pdf_path, invoice_no, customer_name, datetime_str, items, grand_total)
        generate_thermal_pdf(thermal_path, invoice_no, customer_name, datetime_str, items, grand_total)
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"PDF error: {e}"}), 500

    # Parse date/time/day from datetime_str (format: "DD/MM/YYYY  HH:MM:SS")
    try:
        dt       = datetime.strptime(datetime_str.strip(), "%d/%m/%Y  %H:%M:%S")
        date_col = dt.strftime("%d-%m-%Y")
        time_col = dt.strftime("%H:%M:%S")
        day_col  = dt.strftime("%A")
    except Exception:
        date_col = date_part
        time_col = ""
        day_col  = ""

    sheet_error = None
    try:
        sheet = get_sheet()
        ensure_header(sheet)
        sheet.append_row(
            [date_col, time_col, day_col, customer_name, grand_total, "Paid", 0],
            value_input_option="USER_ENTERED",
        )
    except Exception as e:
        traceback.print_exc()
        sheet_error = str(e)
        print(f"[Sheet Error] {e}", file=sys.stderr)

    return jsonify({
        "success":          True,
        "filename":         rel_pdf,
        "thermal_filename": rel_thermal,
        "invoice_no":       invoice_no,
        "customer":         customer_name,
        "grand_total":      grand_total,
        "sheet_error":      sheet_error or None,
    })

@app.route("/invoice-file/<path:filename>")
def serve_invoice(filename):
    """Serve any PDF (A4 or thermal) from within the invoices directory."""
    inv_real  = os.path.realpath(INVOICES_DIR)
    safe_path = os.path.realpath(os.path.join(INVOICES_DIR, filename))
    # Security: prevent path traversal
    if not safe_path.startswith(inv_real + os.sep) and safe_path != inv_real:
        return jsonify({"error": "Invalid path"}), 403
    if not os.path.exists(safe_path):
        return jsonify({"error": "File not found"}), 404
    download = request.args.get("dl") == "1"
    return send_file(
        safe_path,
        mimetype="application/pdf",
        as_attachment=download,
        download_name=os.path.basename(filename) if download else None,
    )

@app.route("/invoices-list")
def invoices_list():
    """Return all A4 invoices from year/month subdirectories, newest first."""
    files = []
    try:
        for root, dirs, filenames in os.walk(INVOICES_DIR):
            dirs.sort()
            for f in sorted(filenames):
                # Skip thermal receipt copies and non-PDFs
                if not f.endswith(".pdf") or f.endswith("_52mm.pdf"):
                    continue
                full_path = os.path.join(root, f)
                rel_path  = os.path.relpath(full_path, INVOICES_DIR).replace("\\", "/")
                mtime     = os.path.getmtime(full_path)
                files.append({"filename": rel_path, "mtime": mtime})
        files.sort(key=lambda x: x["mtime"], reverse=True)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    return jsonify(files)


# ── PDF colour palette (indigo) ───────────────────────────────────────────────
PDF_PRIMARY = colors.HexColor("#1a237e")
PDF_MID     = colors.HexColor("#3949ab")
PDF_LIGHT   = colors.HexColor("#e8eaf6")
PDF_ALT     = colors.HexColor("#f5f5f5")
PDF_GRID    = colors.HexColor("#c5cae9")
WHITE       = colors.white

# ── A4 PDF Generator ──────────────────────────────────────────────────────────
def generate_pdf(path, invoice_no, customer_name, datetime_str, items, grand_total):
    doc = SimpleDocTemplate(
        path, pagesize=A4,
        rightMargin=1.8*cm, leftMargin=1.8*cm,
        topMargin=1.5*cm,   bottomMargin=1.5*cm,
    )
    story = []

    title_style = ParagraphStyle(
        "title", fontName=FONT_BOLD, fontSize=26,
        textColor=PDF_PRIMARY, alignment=TA_CENTER, leading=32,
    )
    tag_style = ParagraphStyle(
        "tag", fontName=FONT_ITALIC, fontSize=10,
        textColor=PDF_MID, alignment=TA_CENTER, leading=15,
    )
    inv_label_style = ParagraphStyle(
        "invlabel", fontName=FONT_BOLD, fontSize=12,
        textColor=colors.HexColor("#3aa6b9"), alignment=TA_CENTER, leading=16,
    )

    header_table = Table(
        [
            [Paragraph("Shakti General Store", title_style)],
            [Paragraph("Quality Products | Trusted Service", tag_style)],
            [Spacer(1, 4)],
            [Paragraph("INVOICE", inv_label_style)],
        ],
        colWidths=[18*cm],
    )
    header_table.setStyle(TableStyle([
        ("TOPPADDING",    (0,0), (-1,-1), 0),
        ("BOTTOMPADDING", (0,0), (-1,-1), 4),
        ("LEFTPADDING",   (0,0), (-1,-1), 0),
        ("RIGHTPADDING",  (0,0), (-1,-1), 0),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 0.15*cm))
    story.append(HRFlowable(width="100%", thickness=2.5, color=PDF_PRIMARY, spaceAfter=6))

    meta_style = ParagraphStyle(
        "meta", fontName=FONT, fontSize=10,
        textColor=colors.HexColor("#1a237e"), leading=16,
    )
    meta_table = Table(
        [
            [
                Paragraph(f"<font name='{FONT_BOLD}'>Invoice No: </font>{invoice_no}", meta_style),
                Paragraph(f"<font name='{FONT_BOLD}'>Date &amp; Time: </font>{datetime_str}", meta_style),
            ],
            [
                Paragraph(f"<font name='{FONT_BOLD}'>Customer: </font>{customer_name}", meta_style),
                "",
            ],
        ],
        colWidths=[9*cm, 9*cm],
    )
    meta_table.setStyle(TableStyle([
        ("BACKGROUND",    (0,0), (-1,-1), PDF_LIGHT),
        ("TOPPADDING",    (0,0), (-1,-1), 9),
        ("BOTTOMPADDING", (0,0), (-1,-1), 9),
        ("LEFTPADDING",   (0,0), (-1,-1), 12),
        ("RIGHTPADDING",  (0,0), (-1,-1), 12),
        ("BOX",           (0,0), (-1,-1), 1,   PDF_GRID),
        ("LINEBELOW",     (0,0), (-1, 0), 0.5, PDF_GRID),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 0.5*cm))

    cell_style = ParagraphStyle(
        "cell", fontName=FONT, fontSize=9.5,
        textColor=colors.HexColor("#1a237e"), leading=14,
    )
    hdr_cell = ParagraphStyle(
        "hdr", fontName=FONT_BOLD, fontSize=9.5,
        textColor=WHITE, leading=14, alignment=TA_CENTER,
    )
    gt_cell = ParagraphStyle(
        "gt", fontName=FONT_BOLD, fontSize=11,
        textColor=WHITE, leading=16,
    )

    col_widths = [1.2*cm, 7*cm, 2*cm, 3.8*cm, 4*cm]
    header_row = [
        Paragraph("#",                     hdr_cell),
        Paragraph("Item Name",             hdr_cell),
        Paragraph("Qty",                   hdr_cell),
        Paragraph(f"Unit Price ({RUPEE})", hdr_cell),
        Paragraph(f"Total ({RUPEE})",      hdr_cell),
    ]
    table_data = [header_row]
    for item in items:
        table_data.append([
            Paragraph(str(item["item_no"]),                         cell_style),
            Paragraph(str(item["item_name"]),                       cell_style),
            Paragraph(str(item["qty"]),                             cell_style),
            Paragraph(f"{RUPEE} {float(item['unit_price']):,.2f}", cell_style),
            Paragraph(f"{RUPEE} {float(item['total']):,.2f}",      cell_style),
        ])
    table_data.append([
        Paragraph("", gt_cell), Paragraph("", gt_cell), Paragraph("", gt_cell),
        Paragraph("Grand Total",                 gt_cell),
        Paragraph(f"{RUPEE} {grand_total:,.2f}", gt_cell),
    ])

    n  = len(table_data)
    ts = TableStyle([
        ("BACKGROUND",    (0, 0), (-1,  0), PDF_PRIMARY),
        ("ALIGN",         (0, 0), (-1,  0), "CENTER"),
        ("TOPPADDING",    (0, 0), (-1,  0), 10),
        ("BOTTOMPADDING", (0, 0), (-1,  0), 10),
        ("ALIGN",         (0, 1), ( 0, -1), "CENTER"),
        ("ALIGN",         (2, 1), (-1, -1), "RIGHT"),
        ("TOPPADDING",    (0, 1), (-1, -2), 8),
        ("BOTTOMPADDING", (0, 1), (-1, -2), 8),
        ("LEFTPADDING",   (0, 0), (-1, -1), 8),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 8),
        ("GRID",          (0, 0), (-1, -2), 0.5, PDF_GRID),
        ("LINEABOVE",     (0, 0), (-1,  0), 0,   WHITE),
        ("BACKGROUND",    (0, -1), (-1, -1), PDF_PRIMARY),
        ("TOPPADDING",    (0, -1), (-1, -1), 11),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 11),
        ("SPAN",          (0, -1), ( 2, -1)),
    ])
    for i in range(2, n - 1, 2):
        ts.add("BACKGROUND", (0, i), (-1, i), PDF_ALT)

    items_table = Table(table_data, colWidths=col_widths, repeatRows=1)
    items_table.setStyle(ts)
    story.append(items_table)
    story.append(Spacer(1, 0.9*cm))

    foot_style = ParagraphStyle(
        "foot", fontName=FONT_ITALIC, fontSize=9,
        textColor=colors.HexColor("#607d8b"), alignment=TA_CENTER, leading=14,
    )
    story.append(HRFlowable(width="100%", thickness=1, color=PDF_GRID, spaceAfter=5))
    story.append(Paragraph("Thank you for shopping at Shakti General Store!", foot_style))
    story.append(Spacer(1, 3))
    story.append(Paragraph("This is a computer-generated invoice. No signature required.", foot_style))

    doc.build(story)


# ── 52mm Thermal PDF Generator ────────────────────────────────────────────────
THERMAL_W = 52 * mm          # page width
THERMAL_M = 2  * mm          # left/right margin

def generate_thermal_pdf(path, invoice_no, customer_name, datetime_str, items, grand_total):
    """Generate a receipt-style PDF sized for a 52mm thermal printer."""
    # Estimate page height so receipt matches content length
    est_h     = (62 + len(items) * 11 + 22) * mm
    page_size = (THERMAL_W, max(est_h, 80 * mm))

    doc = SimpleDocTemplate(
        path,
        pagesize=page_size,
        rightMargin=THERMAL_M,
        leftMargin=THERMAL_M,
        topMargin=2 * mm,
        bottomMargin=3 * mm,
    )
    story = []

    # ── Styles ──
    s_head  = ParagraphStyle("th", fontName=FONT_BOLD,   fontSize=9,   alignment=TA_CENTER, leading=12, textColor=PDF_PRIMARY)
    s_sub   = ParagraphStyle("ts", fontName=FONT_ITALIC, fontSize=6.5, alignment=TA_CENTER, leading=9,  textColor=PDF_MID)
    s_label = ParagraphStyle("tl", fontName=FONT_BOLD,   fontSize=7,   alignment=TA_CENTER, leading=10, textColor=PDF_MID)
    s_norm  = ParagraphStyle("tn", fontName=FONT,        fontSize=7,   leading=10)
    s_total = ParagraphStyle("tt", fontName=FONT_BOLD,   fontSize=9,   leading=12, alignment=TA_RIGHT, textColor=PDF_PRIMARY)
    s_foot  = ParagraphStyle("tf", fontName=FONT_ITALIC, fontSize=6,   alignment=TA_CENTER, leading=9,  textColor=colors.HexColor("#607d8b"))

    # ── Store header ──
    story.append(Paragraph("Shakti General Store", s_head))
    story.append(Spacer(1, 0.5*mm))
    story.append(Paragraph("Quality Products | Trusted Service", s_sub))
    story.append(Spacer(1, 1*mm))
    story.append(HRFlowable(width="100%", thickness=1,   color=PDF_PRIMARY, spaceAfter=2))
    story.append(Paragraph("RECEIPT", s_label))
    story.append(HRFlowable(width="100%", thickness=0.5, color=PDF_GRID,    spaceAfter=2))
    story.append(Spacer(1, 1*mm))

    # ── Invoice meta ──
    story.append(Paragraph(f"<font name='{FONT_BOLD}'>Invoice:</font>  {invoice_no}", s_norm))
    story.append(Paragraph(f"<font name='{FONT_BOLD}'>Date:</font>     {datetime_str}", s_norm))
    story.append(Paragraph(f"<font name='{FONT_BOLD}'>Customer:</font> {customer_name}", s_norm))
    story.append(Spacer(1, 1.5*mm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=PDF_GRID, spaceAfter=2))
    story.append(Spacer(1, 1*mm))

    # ── Items table ──
    # Usable width ≈ 52mm − 4mm margins = 48mm ≈ 136pt
    # Columns: Item name | Qty | Price | Total  →  56+18+30+32 = 136pt
    c_w = [56, 18, 30, 32]
    h_s = ParagraphStyle("ih", fontName=FONT_BOLD, fontSize=6,   leading=8, alignment=TA_CENTER, textColor=WHITE)
    c_s = ParagraphStyle("ic", fontName=FONT,      fontSize=6.5, leading=9)
    c_r = ParagraphStyle("ir", fontName=FONT,      fontSize=6.5, leading=9, alignment=TA_RIGHT)

    tbl_data = [[
        Paragraph("Item",            h_s),
        Paragraph("Qty",             h_s),
        Paragraph(f"Price({RUPEE})", h_s),
        Paragraph(f"Total({RUPEE})", h_s),
    ]]
    for item in items:
        tbl_data.append([
            Paragraph(str(item["item_name"]),             c_s),
            Paragraph(str(item["qty"]),                   c_r),
            Paragraph(f"{float(item['unit_price']):,.2f}", c_r),
            Paragraph(f"{float(item['total']):,.2f}",      c_r),
        ])

    thermal_ts = TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0), PDF_PRIMARY),
        ("ALIGN",         (0, 0), (-1, 0), "CENTER"),
        ("TOPPADDING",    (0, 0), (-1,-1), 2),
        ("BOTTOMPADDING", (0, 0), (-1,-1), 2),
        ("LEFTPADDING",   (0, 0), (-1,-1), 2),
        ("RIGHTPADDING",  (0, 0), (-1,-1), 2),
        ("LINEBELOW",     (0, 0), (-1,-1), 0.3, PDF_GRID),
    ])
    for i in range(2, len(tbl_data), 2):
        thermal_ts.add("BACKGROUND", (0, i), (-1, i), PDF_ALT)

    tbl = Table(tbl_data, colWidths=c_w)
    tbl.setStyle(thermal_ts)
    story.append(tbl)
    story.append(Spacer(1, 1.5*mm))
    story.append(HRFlowable(width="100%", thickness=1, color=PDF_PRIMARY, spaceAfter=3))

    # ── Grand total ──
    story.append(Paragraph(f"Grand Total:  {RUPEE} {grand_total:,.2f}", s_total))
    story.append(Spacer(1, 2*mm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=PDF_GRID, spaceAfter=3))

    # ── Footer ──
    story.append(Paragraph("Thank you for shopping!", s_foot))
    story.append(Paragraph("Shakti General Store", s_foot))

    doc.build(story)


if __name__ == "__main__":
    net_url = f"  Network:  http://{LOCAL_IP}:5000  (open on phone)" if LOCAL_IP else "  Network:  unavailable"
    print("=" * 54)
    print("  Shakti General Store — Invoice Tool")
    print("  Local:    http://127.0.0.1:5000")
    print(net_url)
    print("=" * 54)

    def _open_browser():
        import time
        time.sleep(1.4)
        webbrowser.open("http://127.0.0.1:5000")
    threading.Thread(target=_open_browser, daemon=True).start()

    try:
        from waitress import serve
        print("  Server: waitress  |  Press Ctrl+C to stop")
        print("=" * 54)
        serve(app, host="0.0.0.0", port=5000)
    except ImportError:
        print("  Server: Flask dev  |  Press Ctrl+C to stop")
        print("=" * 54)
        app.run(host="0.0.0.0", port=5000, debug=False)
