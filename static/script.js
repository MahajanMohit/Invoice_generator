/* ── Config ──────────────────────────────────────────── */
const INITIAL_ROWS = 8;

/* ── State ───────────────────────────────────────────── */
let invoiceNo = "";

/* ── DOM refs ────────────────────────────────────────── */
const tbody        = document.getElementById("itemsBody");
const grandTotalEl = document.getElementById("grandTotal");
const invoiceNoEl  = document.getElementById("invoiceNo");
const dateTimeEl   = document.getElementById("dateTime");
const customerEl   = document.getElementById("customerName");
const generateBtn  = document.getElementById("generateBtn");
const clearBtn     = document.getElementById("clearBtn");
const spinner      = document.getElementById("spinner");
const toast        = document.getElementById("toast");

// Share modal
const shareModal = document.getElementById("shareModal");
const modalSub   = document.getElementById("modalSub");
const btnShare   = document.getElementById("btnShare");
const btnPrint   = document.getElementById("btnPrint");
const btnSkip    = document.getElementById("btnSkip");

// Sidebar
const sidebar           = document.getElementById("sidebar");
const sidebarBackdrop   = document.getElementById("sidebarBackdrop");
const sidebarTab        = document.getElementById("sidebarTab");
const sidebarClose      = document.getElementById("sidebarClose");
const invoicesList      = document.getElementById("invoicesList");
const historyInlineBtn  = document.getElementById("historyInlineBtn");

/* ── Clock ───────────────────────────────────────────── */
function updateClock() {
  const now = new Date();
  const pad = n => String(n).padStart(2, "0");
  dateTimeEl.value =
    `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()}  ` +
    `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
}
updateClock();
setInterval(updateClock, 1000);

/* ── Invoice number ──────────────────────────────────── */
async function loadInvoiceNumber() {
  try {
    const res  = await fetch("/get_invoice_number");
    const data = await res.json();
    if (data.error) throw new Error(data.error);
    invoiceNo = data.invoice_no;
    invoiceNoEl.textContent = invoiceNo;
  } catch (e) {
    invoiceNoEl.textContent = "SGS-???";
    showToast("Could not load invoice number: " + e.message, "error");
  }
}
loadInvoiceNumber();

/* ── Row builder ─────────────────────────────────────── */
function createRow(index) {
  const tr = document.createElement("tr");
  tr.dataset.index = index;

  tr.innerHTML = `
    <td class="row-num">${index}</td>
    <td><input class="item-input item-name"  type="text"   placeholder="Item name" /></td>
    <td><input class="item-input item-qty"   type="number" placeholder="0" min="0" step="any" /></td>
    <td><input class="item-input item-price" type="number" placeholder="0.00" min="0" step="any" /></td>
    <td class="total-cell">—</td>
    <td>
      <button class="del-btn" title="Remove row" tabindex="-1">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <line x1="18" y1="6"  x2="6"  y2="18"/>
          <line x1="6"  y1="6"  x2="18" y2="18"/>
        </svg>
      </button>
    </td>`;

  const nameInput  = tr.querySelector(".item-name");
  const qtyInput   = tr.querySelector(".item-qty");
  const priceInput = tr.querySelector(".item-price");
  const totalCell  = tr.querySelector(".total-cell");
  const delBtn     = tr.querySelector(".del-btn");

  function recalcRow() {
    const qty   = parseFloat(qtyInput.value)   || 0;
    const price = parseFloat(priceInput.value) || 0;
    const total = qty * price;
    totalCell.textContent = total > 0 ? `₹ ${total.toFixed(2)}` : "—";
    recalcGrand();
  }
  qtyInput.addEventListener("input",   recalcRow);
  priceInput.addEventListener("input",  recalcRow);

  [nameInput, qtyInput, priceInput].forEach(inp => {
    inp.addEventListener("input", () => { if (isLastRow(tr)) addRow(); });
    inp.addEventListener("focus", () => {
      document.querySelectorAll("tbody tr").forEach(r => r.classList.remove("active-row"));
      tr.classList.add("active-row");
    });
    inp.addEventListener("keydown", e => {
      if (e.key === "Tab" && !e.shiftKey && inp === priceInput) {
        e.preventDefault();
        if (isLastRow(tr)) addRow();
        const rows = tbody.querySelectorAll("tr");
        const next = rows[getRowIndex(tr) + 1];
        if (next) next.querySelector(".item-name").focus();
      }
    });
  });

  delBtn.addEventListener("click", () => {
    if (tbody.querySelectorAll("tr").length <= 1) return;
    tr.remove();
    renumberRows();
    recalcGrand();
  });

  return tr;
}

/* ── Helpers ─────────────────────────────────────────── */
function isLastRow(tr) {
  const rows = tbody.querySelectorAll("tr");
  return tr === rows[rows.length - 1];
}
function getRowIndex(tr) {
  return Array.from(tbody.querySelectorAll("tr")).indexOf(tr);
}
function addRow() {
  tbody.appendChild(createRow(tbody.querySelectorAll("tr").length + 1));
}
function renumberRows() {
  tbody.querySelectorAll("tr").forEach((tr, i) => {
    tr.querySelector(".row-num").textContent = i + 1;
    tr.dataset.index = i + 1;
  });
}
function recalcGrand() {
  let grand = 0;
  tbody.querySelectorAll("tr").forEach(tr => {
    const qty   = parseFloat(tr.querySelector(".item-qty").value)   || 0;
    const price = parseFloat(tr.querySelector(".item-price").value) || 0;
    grand += qty * price;
  });
  grandTotalEl.textContent = grand.toFixed(2);
}

/* ── Init rows ───────────────────────────────────────── */
function initRows() {
  tbody.innerHTML = "";
  for (let i = 1; i <= INITIAL_ROWS; i++) tbody.appendChild(createRow(i));
}
initRows();

/* ── Clear ───────────────────────────────────────────── */
clearBtn.addEventListener("click", () => {
  customerEl.value = "";
  initRows();
  recalcGrand();
  customerEl.focus();
});

/* ── Generate ────────────────────────────────────────── */
generateBtn.addEventListener("click", async () => {
  const items = [];
  tbody.querySelectorAll("tr").forEach((tr, i) => {
    const name  = tr.querySelector(".item-name").value.trim();
    const qty   = parseFloat(tr.querySelector(".item-qty").value)   || 0;
    const price = parseFloat(tr.querySelector(".item-price").value) || 0;
    if (name || qty || price) {
      items.push({
        item_no:    i + 1,
        item_name:  name || "(unnamed)",
        qty, unit_price: price,
        total: parseFloat((qty * price).toFixed(2)),
      });
    }
  });

  const customer = customerEl.value.trim();
  if (!customer)        { showToast("Please enter a customer name.", "warn"); return; }
  if (!items.length)    { showToast("Add at least one item.",         "warn"); return; }

  const grandTotal = items.reduce((s, it) => s + it.total, 0).toFixed(2);

  spinner.classList.remove("hidden");
  generateBtn.disabled = true;

  try {
    const res  = await fetch("/generate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        customer_name: customer,
        datetime:      dateTimeEl.value,
        invoice_no:    invoiceNo,
        items,
        grand_total:   grandTotal,
      }),
    });
    const data = await res.json().catch(() => ({ error: "Unknown error" }));
    if (!res.ok) throw new Error(data.error || "Server error");

    if (data.db_error) {
      showToast(`Invoice ${invoiceNo} saved! (DB warning: ${data.db_error})`, "warn");
    } else {
      showToast(`Invoice ${invoiceNo} saved successfully!`, "success");
    }

    openShareModal(data.filename, data.invoice_no, data.customer, data.grand_total);

  } catch (e) {
    showToast("Error: " + e.message, "error");
  } finally {
    spinner.classList.add("hidden");
    generateBtn.disabled = false;
  }
});

/* ── Share Modal ─────────────────────────────────────── */
function resetForm() {
  customerEl.value = "";
  initRows();
  recalcGrand();
  customerEl.focus();
  loadInvoiceNumber();
  loadSidebarInvoices();
}

function closeShareModal() {
  shareModal.classList.add("hidden");
  resetForm();
}

/* Encode a relative path like "2026/03/file.pdf" without encoding the slashes */
function encodePath(relPath) {
  return relPath.split("/").map(encodeURIComponent).join("/");
}

function openShareModal(filename, invNo, customer, grandTotal) {
  modalSub.textContent = `${invNo}  •  ${customer}  •  ₹${parseFloat(grandTotal).toFixed(2)}`;
  shareModal.classList.remove("hidden");

  const pdfUrl = `${window.location.origin}/invoice-file/${encodePath(filename)}`;

  // View/Share — opens receipt PDF in new tab
  btnShare.onclick = () => { window.open(pdfUrl, "_blank"); };

  // Print — opens same receipt PDF; user selects thermal printer from browser print dialog
  btnPrint.onclick = () => { window.open(pdfUrl, "_blank"); };

  btnSkip.onclick = closeShareModal;
}


/* ── Sidebar ─────────────────────────────────────────── */
function openSidebar() {
  sidebar.classList.add("open");
  sidebarBackdrop.classList.remove("hidden");
  loadSidebarInvoices();
}
function closeSidebar() {
  sidebar.classList.remove("open");
  sidebarBackdrop.classList.add("hidden");
}

sidebarTab.addEventListener("click",        openSidebar);
historyInlineBtn.addEventListener("click", openSidebar);
sidebarClose.addEventListener("click",     closeSidebar);
sidebarBackdrop.addEventListener("click",  closeSidebar);

async function loadSidebarInvoices() {
  invoicesList.innerHTML = `<p class="sidebar-loading">Loading…</p>`;
  try {
    const res   = await fetch("/invoices-list");
    const files = await res.json();

    if (!files.length) {
      invoicesList.innerHTML = `<p class="sidebar-loading">No invoices yet.</p>`;
      return;
    }

    // Group by date label
    const today    = new Date();
    const todayStr = fmtDate(today);
    const yday     = new Date(today); yday.setDate(yday.getDate() - 1);
    const ydayStr  = fmtDate(yday);

    let currentGroup = null;
    const fragment   = document.createDocumentFragment();

    files.forEach(f => {
      // DB returns date as "DD-MM-YYYY"; convert to "YYYY-MM-DD" for comparison
      const [dd, mm, yyyy] = (f.date || "").split("-");
      const dateComp = (yyyy && mm && dd) ? `${yyyy}-${mm}-${dd}` : "";
      const label    = dateComp === todayStr ? "Today"
                     : dateComp === ydayStr  ? "Yesterday"
                     : f.date || "Unknown";

      if (label !== currentGroup) {
        currentGroup = label;
        const g = document.createElement("div");
        g.className = "sidebar-date-group";
        g.textContent = label;
        fragment.appendChild(g);
      }

      const item = document.createElement("div");
      item.className = "sidebar-item";
      item.innerHTML = `
        <div class="sidebar-item-top">
          <span class="sidebar-item-no">${f.invoice_no || "—"}</span>
          <span class="sidebar-item-total">₹${parseFloat(f.grand_total || 0).toFixed(2)}</span>
        </div>
        <span class="sidebar-item-name">${f.customer || "—"}</span>
        <span class="sidebar-item-time">${f.time || ""}</span>`;
      item.addEventListener("click", () => {
        window.open(`/invoice-file/${encodePath(f.filename)}`, "_blank");
      });
      fragment.appendChild(item);
    });

    invoicesList.innerHTML = "";
    invoicesList.appendChild(fragment);
  } catch (e) {
    invoicesList.innerHTML = `<p class="sidebar-loading">Error loading invoices.</p>`;
  }
}

/* Parse filename from a relative path like "2026/03/SGS-001_CustomerName_DD-MM-YYYY.pdf" */
function parseFilename(filepath) {
  // Extract just the basename (last segment)
  const filename = filepath.split("/").pop();
  const name  = filename.replace(".pdf", "");
  const parts = name.split("_");
  const invNo = parts[0];
  const dateRx = /^\d{2}-\d{2}-\d{4}$/;

  if (parts.length >= 3 && dateRx.test(parts[parts.length - 1])) {
    return {
      invNo,
      customer: parts.slice(1, -1).join(" "),
      date:     parts[parts.length - 1].split("-").reverse().join("-"), // YYYY-MM-DD for comparison
      total:    null,
    };
  }
  return { invNo, customer: parts.slice(1).join(" ") || "—", date: null, total: null };
}

function fmtDate(d) {
  // Returns DD-MM-YYYY string
  const dt = d instanceof Date ? d : new Date(d * 1000);
  return `${String(dt.getDate()).padStart(2,"0")}-${String(dt.getMonth()+1).padStart(2,"0")}-${dt.getFullYear()}`;
}
function fmtTime(mtime) {
  const dt = new Date(mtime * 1000);
  const h  = String(dt.getHours()).padStart(2,"0");
  const m  = String(dt.getMinutes()).padStart(2,"0");
  return `${h}:${m}`;
}

/* ── Toast ───────────────────────────────────────────── */
let toastTimer;
function showToast(msg, type = "success") {
  toast.textContent = msg;
  toast.className   = `toast ${type}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.add("hidden"), 3500);
}
