from flask import Flask, render_template, request, jsonify, send_file
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, HRFlowable
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from datetime import datetime
import sqlite3
import traceback
import threading
import webbrowser
import socket
import os
import sys

# ── Google Sheets (DISABLED — uncomment block below to re-enable) ──────────────
# import gspread
# from google.oauth2.service_account import Credentials
# SCOPES     = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]
# SHEET_NAME = "Invoices"
# CREDS_FILE = os.path.join(os.path.expanduser("~"), "Desktop", "ShaktiGeneralStore", "credentials.json")
# def _creds():
#     return Credentials.from_service_account_file(CREDS_FILE, scopes=SCOPES)
# def get_sheet():
#     return gspread.authorize(_creds()).open(SHEET_NAME).sheet1
# def ensure_header(sheet):
#     if not sheet.row_values(1):
#         sheet.append_row(
#             ["Date", "Time", "Day", "Customer Name", "Grand Total (Rs)", "Paid", "Balance"],
#             value_input_option="USER_ENTERED",
#         )
# ── End Google Sheets block ────────────────────────────────────────────────────

app = Flask(__name__)

# ── Paths ──────────────────────────────────────────────────────────────────────
DESKTOP      = os.path.join(os.path.expanduser("~"), "Desktop")
BASE_DIR     = os.path.join(DESKTOP, "ShaktiGeneralStore")
INVOICES_DIR = os.path.join(BASE_DIR, "invoices")
DB_PATH      = os.path.join(BASE_DIR, "invoices.db")

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

# ── SQLite Database ────────────────────────────────────────────────────────────
def init_db():
    with sqlite3.connect(DB_PATH) as con:
        con.execute("""
            CREATE TABLE IF NOT EXISTS invoices (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                invoice_no  TEXT    NOT NULL,
                date        TEXT    NOT NULL,
                time        TEXT    NOT NULL,
                day         TEXT    NOT NULL,
                customer    TEXT    NOT NULL,
                grand_total REAL    NOT NULL,
                paid        TEXT    NOT NULL DEFAULT 'Paid',
                balance     REAL    NOT NULL DEFAULT 0,
                pdf_path    TEXT,
                created_at  TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
            )
        """)
        con.commit()

def db_next_invoice_number():
    with sqlite3.connect(DB_PATH) as con:
        row = con.execute("SELECT MAX(id) FROM invoices").fetchone()
    last_id = row[0] if row[0] else 0
    return f"SGS-{last_id + 1:03d}"

def db_insert(invoice_no, date_col, time_col, day_col, customer, grand_total, pdf_rel):
    with sqlite3.connect(DB_PATH) as con:
        con.execute(
            """INSERT INTO invoices
               (invoice_no, date, time, day, customer, grand_total, paid, balance, pdf_path)
               VALUES (?,?,?,?,?,?,'Paid',0,?)""",
            (invoice_no, date_col, time_col, day_col, customer, grand_total, pdf_rel),
        )
        con.commit()

def db_list():
    with sqlite3.connect(DB_PATH) as con:
        rows = con.execute(
            "SELECT invoice_no, customer, date, time, pdf_path, created_at "
            "FROM invoices ORDER BY id DESC"
        ).fetchall()
    result = []
    for r in rows:
        try:
            dt    = datetime.strptime(r[5], "%Y-%m-%d %H:%M:%S")
            mtime = dt.timestamp()
        except Exception:
            mtime = 0
        result.append({
            "invoice_no":  r[0],
            "customer":    r[1],
            "date":        r[2],
            "time":        r[3],
            "filename":    r[4],
            "mtime":       mtime,
        })
    return result

init_db()

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

# ── Invoice folder (year → month structure) ────────────────────────────────────
def get_invoice_folder(date_str):
    """Return (and create) invoices/YYYY/MM/ from date string DD-MM-YYYY."""
    try:
        parts            = date_str.replace("/", "-").split("-")
        day, month, year = parts[0], parts[1], parts[2]
    except Exception:
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
        return jsonify({"invoice_no": db_next_invoice_number()})
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route("/generate", methods=["POST"])
def generate():
    data          = request.json
    customer_name = data.get("customer_name", "").strip()
    datetime_str  = data.get("datetime", "")
    invoice_no    = data.get("invoice_no", "")
    items         = data.get("items", [])
    grand_total   = float(data.get("grand_total", 0))

    if not customer_name:
        return jsonify({"error": "Customer name is required."}), 400
    if not items:
        return jsonify({"error": "Add at least one item."}), 400

    safe_customer = "".join(c if c.isalnum() or c in " _-" else "_" for c in customer_name).strip()
    date_part     = datetime_str.split()[0].replace("/", "-")   # DD-MM-YYYY
    pdf_filename  = f"{invoice_no}_{safe_customer}_{date_part}.pdf"
    print(f"[PDF] Saving as: {pdf_filename}")

    invoice_folder = get_invoice_folder(date_part)
    pdf_path       = os.path.join(invoice_folder, pdf_filename)
    rel_pdf        = os.path.relpath(pdf_path, INVOICES_DIR).replace("\\", "/")

    try:
        generate_receipt_pdf(pdf_path, invoice_no, customer_name, datetime_str, items, grand_total)
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"PDF error: {e}"}), 500

    # Parse date / time / day
    try:
        dt       = datetime.strptime(datetime_str.strip(), "%d/%m/%Y  %H:%M:%S")
        date_col = dt.strftime("%d-%m-%Y")
        time_col = dt.strftime("%H:%M:%S")
        day_col  = dt.strftime("%A")
    except Exception:
        date_col, time_col, day_col = date_part, "", ""

    db_error = None
    try:
        db_insert(invoice_no, date_col, time_col, day_col, customer_name, grand_total, rel_pdf)
    except Exception as e:
        traceback.print_exc()
        db_error = str(e)
        print(f"[DB Error] {e}", file=sys.stderr)

    # ── Google Sheets (DISABLED — uncomment to re-enable) ─────────────────────
    # try:
    #     sheet = get_sheet()
    #     ensure_header(sheet)
    #     sheet.append_row(
    #         [date_col, time_col, day_col, customer_name, grand_total, "Paid", 0],
    #         value_input_option="USER_ENTERED",
    #     )
    # except Exception as e:
    #     print(f"[Sheet Error] {e}", file=sys.stderr)
    # ── End Google Sheets block ────────────────────────────────────────────────

    return jsonify({
        "success":     True,
        "filename":    rel_pdf,
        "invoice_no":  invoice_no,
        "customer":    customer_name,
        "grand_total": grand_total,
        "db_error":    db_error,
    })

@app.route("/invoice-file/<path:filename>")
def serve_invoice(filename):
    inv_real  = os.path.realpath(INVOICES_DIR)
    safe_path = os.path.realpath(os.path.join(INVOICES_DIR, filename))
    if not safe_path.startswith(inv_real + os.sep) and safe_path != inv_real:
        return jsonify({"error": "Invalid path"}), 403
    if not os.path.exists(safe_path):
        return jsonify({"error": "File not found"}), 404
    download = request.args.get("dl") == "1"
    return send_file(
        safe_path,
        mimetype="application/pdf",
        as_attachment=download,
        download_name=os.path.basename(safe_path) if download else None,
    )

@app.route("/invoices-list")
def invoices_list():
    try:
        return jsonify(db_list())
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ── PDF colour palette (indigo) ───────────────────────────────────────────────
PDF_PRIMARY = colors.HexColor("#1a237e")
PDF_MID     = colors.HexColor("#3949ab")
PDF_ALT     = colors.HexColor("#f5f5f5")
PDF_GRID    = colors.HexColor("#c5cae9")
WHITE       = colors.white

# ── 58mm Receipt PDF Generator ────────────────────────────────────────────────
THERMAL_W = 58 * mm
THERMAL_M = 2  * mm

def generate_receipt_pdf(path, invoice_no, customer_name, datetime_str, items, grand_total):
    """Generate a receipt-style PDF sized for a 58mm thermal printer."""
    est_h     = (42 + len(items) * 10 + 20) * mm
    page_size = (THERMAL_W, est_h)

    doc = SimpleDocTemplate(
        path,
        pagesize=page_size,
        rightMargin=THERMAL_M,
        leftMargin=THERMAL_M,
        topMargin=1 * mm,
        bottomMargin=2 * mm,
    )
    story = []

    s_head  = ParagraphStyle("th", fontName=FONT_BOLD,   fontSize=9,   alignment=TA_CENTER, leading=12, textColor=PDF_PRIMARY)
    s_sub   = ParagraphStyle("ts", fontName=FONT_ITALIC, fontSize=6.5, alignment=TA_CENTER, leading=9,  textColor=PDF_MID)
    s_label = ParagraphStyle("tl", fontName=FONT_BOLD,   fontSize=7,   alignment=TA_CENTER, leading=10, textColor=PDF_MID)
    s_norm  = ParagraphStyle("tn", fontName=FONT,        fontSize=7,   leading=10)
    s_total = ParagraphStyle("tt", fontName=FONT_BOLD,   fontSize=9,   leading=12, alignment=TA_RIGHT, textColor=PDF_PRIMARY)
    s_foot  = ParagraphStyle("tf", fontName=FONT_ITALIC, fontSize=6,   alignment=TA_CENTER, leading=9,  textColor=colors.HexColor("#607d8b"))

    # Store header
    story.append(Paragraph("Shakti General Store", s_head))
    story.append(Spacer(1, 0.5 * mm))
    story.append(Paragraph("Quality Products | Trusted Service", s_sub))
    story.append(Spacer(1, 1 * mm))
    story.append(HRFlowable(width="100%", thickness=1,   color=PDF_PRIMARY, spaceAfter=2))
    story.append(Paragraph("RECEIPT", s_label))
    story.append(HRFlowable(width="100%", thickness=0.5, color=PDF_GRID,    spaceAfter=2))
    story.append(Spacer(1, 1 * mm))

    # Invoice meta
    story.append(Paragraph(f"<font name='{FONT_BOLD}'>Invoice:</font>  {invoice_no}", s_norm))
    story.append(Paragraph(f"<font name='{FONT_BOLD}'>Date:</font>     {datetime_str}", s_norm))
    story.append(Paragraph(f"<font name='{FONT_BOLD}'>Customer:</font> {customer_name}", s_norm))
    story.append(Spacer(1, 1.5 * mm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=PDF_GRID, spaceAfter=2))
    story.append(Spacer(1, 1 * mm))

    # Items table — usable width ≈ 58mm − 4mm margins = 54mm ≈ 153pt
    # Columns: Item name | Qty | Price | Total  →  63+20+34+36 = 153pt
    c_w = [63, 20, 34, 36]
    h_s = ParagraphStyle("ih", fontName=FONT_BOLD, fontSize=6,   leading=8,  alignment=TA_CENTER, textColor=WHITE)
    c_s = ParagraphStyle("ic", fontName=FONT,      fontSize=6.5, leading=9)
    c_r = ParagraphStyle("ir", fontName=FONT,      fontSize=6.5, leading=9,  alignment=TA_RIGHT)

    tbl_data = [[
        Paragraph("Item",            h_s),
        Paragraph("Qty",             h_s),
        Paragraph(f"Price({RUPEE})", h_s),
        Paragraph(f"Total({RUPEE})", h_s),
    ]]
    for item in items:
        tbl_data.append([
            Paragraph(str(item["item_name"]),              c_s),
            Paragraph(str(item["qty"]),                    c_r),
            Paragraph(f"{float(item['unit_price']):,.2f}", c_r),
            Paragraph(f"{float(item['total']):,.2f}",      c_r),
        ])

    ts = TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0), PDF_PRIMARY),
        ("ALIGN",         (0, 0), (-1, 0), "CENTER"),
        ("TOPPADDING",    (0, 0), (-1,-1), 2),
        ("BOTTOMPADDING", (0, 0), (-1,-1), 2),
        ("LEFTPADDING",   (0, 0), (-1,-1), 2),
        ("RIGHTPADDING",  (0, 0), (-1,-1), 2),
        ("LINEBELOW",     (0, 0), (-1,-1), 0.3, PDF_GRID),
    ])
    for i in range(2, len(tbl_data), 2):
        ts.add("BACKGROUND", (0, i), (-1, i), PDF_ALT)

    tbl = Table(tbl_data, colWidths=c_w)
    tbl.setStyle(ts)
    story.append(tbl)
    story.append(Spacer(1, 1.5 * mm))
    story.append(HRFlowable(width="100%", thickness=1, color=PDF_PRIMARY, spaceAfter=3))

    # Grand total
    story.append(Paragraph(f"Grand Total:  {RUPEE} {grand_total:,.2f}", s_total))
    story.append(Spacer(1, 2 * mm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=PDF_GRID, spaceAfter=3))

    # Footer
    story.append(Paragraph("Thank you for shopping!", s_foot))
    story.append(Paragraph("Shakti General Store", s_foot))

    doc.build(story)


# ── mDNS: advertise shakti.local on the local network ─────────────────────────
def register_mdns(port=5000):
    """Advertise shakti.local via mDNS so all LAN devices can reach the app."""
    try:
        from zeroconf import Zeroconf, ServiceInfo
        if not LOCAL_IP:
            return None
        info = ServiceInfo(
            "_http._tcp.local.",
            "Shakti General Store._http._tcp.local.",
            addresses=[socket.inet_aton(LOCAL_IP)],
            port=port,
            properties={"path": "/"},
            server="shakti.local.",
        )
        zc = Zeroconf()
        zc.register_service(info)
        return zc   # keep reference alive — do not garbage-collect
    except Exception as e:
        print(f"  [mDNS] Not available ({e}); use IP address instead.")
        return None


if __name__ == "__main__":
    _zc = register_mdns()

    local_url   = "http://shakti.local:5000"
    network_url = f"http://shakti.local:5000  (or  http://{LOCAL_IP}:5000)" if LOCAL_IP else "unavailable"

    print("=" * 58)
    print("  Shakti General Store — Invoice Tool")
    print(f"  Local:    {local_url}")
    print(f"  Network:  {network_url}")
    print("=" * 58)

    def _open_browser():
        import time
        time.sleep(1.4)
        webbrowser.open(local_url)
    threading.Thread(target=_open_browser, daemon=True).start()

    try:
        from waitress import serve
        print("  Server: waitress  |  Press Ctrl+C to stop")
        print("=" * 58)
        serve(app, host="0.0.0.0", port=5000)
    except ImportError:
        print("  Server: Flask dev  |  Press Ctrl+C to stop")
        print("=" * 58)
        app.run(host="0.0.0.0", port=5000, debug=False)
