const $ = (id) => document.getElementById(id);

// Fallback list, used only if filetypes.json can't be read.
const FALLBACK_TYPES = [
  ".bat", ".cmd", ".config", ".csv", ".htm", ".html", ".ini", ".json",
  ".log", ".md", ".ps1", ".psm1", ".sql", ".txt", ".xml", ".yaml", ".yml",
];

const MAX_ROWS_SHOWN = 5000;               // cap rendered rows (export includes all)
const YIELD_EVERY = 25;                     // hand control back to the UI every N files

let picked = [];
let rootName = "";
let results = [];
let skippedFiles = [];   // files skipped for being too large
let lastMaxMB = 20;      // size limit used in the last search (0 = no limit)
let running = false;
let cancel = false;

// ---- File-type checkboxes -------------------------------------------------
// Load the extension list from filetypes.json ("*.bat" -> ".bat"), sorted A–Z.
async function loadFileTypes() {
  try {
    const res = await fetch("filetypes.json");
    const data = await res.json();
    const list = (data.fileTypes || [])
      .map((t) => String(t).replace(/^\*/, "").toLowerCase())      // "*.bat" -> ".bat"
      .map((t) => (t.startsWith(".") ? t : "." + t))
      .filter(Boolean);
    if (!list.length) return FALLBACK_TYPES.slice();
    return list.sort((a, b) => a.localeCompare(b));                 // alphabetical
  } catch {
    return FALLBACK_TYPES.slice();
  }
}

function buildTypes(types) {
  const grid = $("ftGrid");
  grid.innerHTML = "";
  for (const ext of types) {
    const label = document.createElement("label");
    const cb = document.createElement("input");
    cb.type = "checkbox";
    cb.className = "ft-box";
    cb.value = ext;
    cb.checked = true;
    label.appendChild(cb);
    const span = document.createElement("span");
    span.textContent = ext;
    label.appendChild(span);
    grid.appendChild(label);
  }
}
const typeBoxes = () => Array.from(document.querySelectorAll(".ft-box"));

$("selectAll").addEventListener("click", (e) => { e.preventDefault(); typeBoxes().forEach((b) => (b.checked = true)); });
$("clearTypes").addEventListener("click", (e) => { e.preventDefault(); typeBoxes().forEach((b) => (b.checked = false)); });
$("allFiles").addEventListener("change", (e) => { $("ftGrid").classList.toggle("disabled", e.target.checked); });


loadFileTypes().then(buildTypes);

// ---- Version badge (from version.json) ------------------------------------
async function loadVersion() {
  try {
    const res = await fetch("version.json");
    const data = await res.json();
    const el = $("version");
    if (!el || !data.version) return;
    el.textContent = "v" + data.version;
    if (data.githublink) el.href = data.githublink;
    el.title = data.date ? "Released " + data.date + " — view on GitHub" : "View on GitHub";
    el.hidden = false;
  } catch { /* leave the badge hidden if the file can't be read */ }
}
loadVersion();

// ---- Empty state ----------------------------------------------------------
const EMPTY_HTML =
  '<div class="empty-title">Choose a folder to begin</div>' +
  '<div class="empty-sub">Pick a folder, enter a search term, and matches will appear here with the matching text highlighted.</div>';

function resetEmptyState() {
  const e = $("empty");
  e.innerHTML = EMPTY_HTML;
  e.style.color = "";
  e.style.display = "block";
}

// ---- Folder selection -----------------------------------------------------
$("folder").addEventListener("change", (e) => {
  picked = Array.from(e.target.files || []);
  rootName = picked.length ? picked[0].webkitRelativePath.split("/")[0] || "" : "";
  $("folderName").textContent = picked.length ? rootName : "No folder selected";
  $("folderName").dataset.empty = picked.length ? "false" : "true";
  if (!results.length) resetEmptyState();
});

// ---- Matching functions ---------------------------------------------------
function globToRegex(glob) {
  const esc = glob.trim().replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".");
  return new RegExp("^" + esc + "$", "i");
}

function normalizeToken(tok) {
  tok = tok.trim();
  if (!tok) return null;
  if (tok.includes("*")) return { glob: globToRegex(tok) };
  if (tok.startsWith(".")) return { ext: tok.toLowerCase() };
  return { ext: "." + tok.toLowerCase() };
}

function collectMatchers() {
  const tokens = [];
  typeBoxes().forEach((b) => { if (b.checked) tokens.push(b.value); });
  $("customTypes").value.split(/[,\s]+/).filter(Boolean).forEach((t) => tokens.push(t));
  return tokens.map(normalizeToken).filter(Boolean);
}

function fileMatches(name, matchers) {
  const lower = name.toLowerCase();
  return matchers.some((m) => (m.ext ? lower.endsWith(m.ext) : m.glob.test(name)));
}

function depthOk(f) {
  if ($("recursive").checked) return true;
  return f.webkitRelativePath.split("/").length <= 2; // only files directly in the chosen folder
}

function buildSearchRegex() {
  const q = $("query").value;
  const flags = $("caseSensitive").checked ? "g" : "gi";
  const pattern = $("useRegex").checked ? q : q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(pattern, flags);
}

function fileType(name) {
  const i = name.lastIndexOf(".");
  return i > 0 ? name.slice(i + 1).toLowerCase() : "";
}

function fmtSize(bytes) {
  const mb = bytes / (1024 * 1024);
  return mb >= 1 ? mb.toFixed(1) + " MB" : Math.max(1, Math.round(bytes / 1024)) + " KB";
}

function nowStamp() {
  const d = new Date();
  const p = (x) => String(x).padStart(2, "0");
  return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) +
    " " + p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds());
}

function fileStamp() {
  const d = new Date();
  const p = (x) => String(x).padStart(2, "0");
  return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) +
    "_" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds());
}

function esc(s) {
  return String(s).replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
}

function highlight(line, re) {
  re.lastIndex = 0;
  let out = "", last = 0, m;
  while ((m = re.exec(line)) !== null) {
    if (m[0].length === 0) { re.lastIndex++; continue; }
    out += esc(line.slice(last, m.index)) + "<mark>" + esc(m[0]) + "</mark>";
    last = m.index + m[0].length;
  }
  return out + esc(line.slice(last));
}

const tick = () => new Promise((r) => setTimeout(r, 0));

// ---- Search ---------------------------------------------------------------
async function search() {
  if (running) return;
  if (!picked.length) { setStatus("Choose a folder first."); return; }
  if (!$("query").value) { setStatus("Enter something to search for."); return; }

  const allFiles = $("allFiles").checked;
  const matchers = collectMatchers();
  if (!allFiles && !matchers.length) { setStatus("Select at least one file type."); return; }

  let searchRe;
  try { searchRe = buildSearchRegex(); }
  catch (e) { setStatus("Invalid regex: " + e.message, true); return; }

  const files = picked.filter((f) => depthOk(f) && (allFiles || fileMatches(f.name, matchers)));

  running = true; cancel = false; results = []; skippedFiles = [];
  const mb = parseFloat($("maxSize").value);
  lastMaxMB = isFinite(mb) && mb > 0 ? mb : 0;             // 0 = no limit
  const maxBytes = lastMaxMB ? lastMaxMB * 1024 * 1024 : Infinity;
  $("run").disabled = true; $("stop").disabled = false;
  disableExports(true);
  $("rows").innerHTML = "";
  $("empty").style.display = "none";

  const t0 = performance.now();
  let scanned = 0, hitFiles = 0;

  for (let i = 0; i < files.length; i++) {
    if (cancel) break;
    const f = files[i];

    $("progress").style.width = ((i / Math.max(files.length, 1)) * 100).toFixed(1) + "%";
    if (i % YIELD_EVERY === 0) {
      updateStats(scanned, results.length, (performance.now() - t0) / 1000);
      await tick();
    }

    if (f.size > maxBytes) { skippedFiles.push({ path: f.webkitRelativePath || f.name, size: f.size }); continue; }
    let text;
    try { text = await f.text(); } catch { continue; }
    scanned++;

    const lines = text.split(/\r\n|\r|\n/);
    let hit = false;
    for (let ln = 0; ln < lines.length; ln++) {
      searchRe.lastIndex = 0;
      if (!searchRe.test(lines[ln])) continue;
      hit = true;
      results.push({
        index: results.length + 1,
        fileName: f.name,
        type: fileType(f.name),
        lineNumber: ln + 1,
        line: lines[ln].slice(0, 2000),
        path: f.webkitRelativePath || f.name,
      });
    }
    if (hit) hitFiles++;
  }

  $("progress").style.width = "100%";
  const elapsed = (performance.now() - t0) / 1000;
  renderRows(searchRe);

  const cancelled = cancel;
  running = false; cancel = false;
  $("run").disabled = false; $("stop").disabled = true;
  disableExports(results.length === 0);
  updateStats(scanned, results.length, elapsed);
  setStatus((cancelled ? "Stopped. " : "Done. ") + results.length + " matches in " + hitFiles + " files.");
  setTimeout(() => ($("progress").style.width = "0%"), 600);
}

const COPY_SVG =
  '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="9" width="11" height="11" rx="2"></rect>' +
  '<path d="M5 15V5a2 2 0 0 1 2-2h10"></path></svg>';

function renderRows(searchRe) {
  const body = $("rows");
  body.innerHTML = "";
  const shown = results.slice(0, MAX_ROWS_SHOWN);
  const frag = document.createDocumentFragment();
  for (const r of shown) {
    const tr = document.createElement("tr");
    tr.innerHTML =
      '<td class="c-idx">' + r.index + "</td>" +
      '<td class="c-file">' + esc(r.fileName) + "</td>" +
      '<td class="c-type">' + esc(r.type) + "</td>" +
      '<td class="c-line">' + r.lineNumber + "</td>" +
      '<td class="c-text">' + highlight(r.line, searchRe) + "</td>" +
      '<td class="c-path">' + esc(r.path) + "</td>" +
      '<td class="c-copy"><button class="copy-btn" title="Copy path" data-path="' + esc(r.path) + '">' + COPY_SVG + "</button></td>";
    frag.appendChild(tr);
  }
  body.appendChild(frag);
  if (results.length > MAX_ROWS_SHOWN) {
    const tr = document.createElement("tr");
    tr.innerHTML = '<td class="c-path" colspan="7">… ' +
      (results.length - MAX_ROWS_SHOWN) + " more matches hidden, but included in the export.</td>";
    body.appendChild(tr);
  }
  $("empty").style.display = results.length ? "none" : "block";
}

// Copy path to clipboard (delegated)
$("rows").addEventListener("click", async (e) => {
  const btn = e.target.closest(".copy-btn");
  if (!btn) return;
  try {
    await navigator.clipboard.writeText(btn.dataset.path);
    btn.classList.add("done");
    btn.title = "Copied";
    setTimeout(() => { btn.classList.remove("done"); btn.title = "Copy path"; }, 1200);
  } catch { /* ignore */ }
});

function updateStats(scanned, matches, elapsed) {
  $("stats").hidden = false;
  $("stScanned").textContent = scanned.toLocaleString("en-US");
  $("stMatches").textContent = matches.toLocaleString("en-US");
  $("stTime").textContent = elapsed.toFixed(2) + "s";
  const wrap = $("stSkippedWrap");
  if (skippedFiles.length) {
    $("stSkipped").textContent = skippedFiles.length.toLocaleString("en-US");
    wrap.hidden = false;
  } else {
    wrap.hidden = true;
  }
}

function setStatus(msg, isErr) {
  // Status is folded into the stats/empty areas; surface errors in the empty slot.
  const empty = $("empty");
  if (!results.length) { empty.textContent = msg; empty.style.display = "block"; }
  empty.style.color = isErr ? "var(--stop)" : "var(--dim)";
}

function disableExports(disabled) {
  ["exportCsv", "exportJson", "exportHtml"].forEach((id) => ($(id).disabled = disabled));
}

// ---- Export ---------------------------------------------------------------
function download(name, text, type) {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const a = document.createElement("a");
  a.href = url; a.download = name; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function toCsv() {
  const head = ["Index", "FileName", "Type", "LineNumber", "Content", "Path"]
    .map((c) => '"' + c + '"').join(";");
  const body = results.map((r) =>
    [r.index, r.fileName, r.type, r.lineNumber, r.line, r.path]
      .map((v) => '"' + String(v).replace(/"/g, '""') + '"').join(";")
  );
  return "\uFEFF" + [head, ...body].join("\r\n");
}

function toJson() {
  return JSON.stringify(
    results.map((r) => ({
      Index: r.index,
      FileName: r.fileName,
      Type: r.type,
      LineNumber: r.lineNumber,
      Content: r.line,
      Path: r.path,
    })),
    null,
    2
  );
}

const REPORT_LOGO = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAADJklEQVR4nO3dUY7iMBBFUTOa/a+ld8j8DBJCHWInLtcrv3u/aTvCJ3HTHeDx/Glk3J/sA6DcAGAeAMwDgHkAMA8A5gHAPACYBwDzAGAeAMwDgHkAMA8A5gHAPACYBwDzAGAeAMwDgHkAMA8A5gHAPACYBwDzAGAeAMz7m30AAT07HvMIP4oi7QCgZ8HPfsYWRGUAVxb+bCw7CBUBzFz4o7FtIFQCELnwR3NtD6HKq4CVi68w77IqAMhehOz5Q1PfAq48+T2X7dFxn53jlksZwMgijS7O++N759kSgeoW0Lsoj3Z/UUbG2G47UAQwsvgzs0SgBqD3z7hRl+LesbdBoAbgrFV78HZ7/VFKAM7OqtWLcjbfFlcBJQCUkAoAtbO/d97yVwEVAN/K3o+z5w9NAUD1s6j08SsA+JbK2adyHNNTB0DBAcC8bADf9k+1y+634yn7e0A2AEoOAOYp3w9w1IrLrdr2ExZXAPMAYF7FLcDm8rwirgDmAcC8bACV/rhS6Y9W3WUDoOQAYJ46AJVtQOU4pqcAoOz++b/Sx68A4Kzssy97/tBUAKjefKl6s+q0VABQUkoA1K4C25/9rWkB6GkVgp55tvjdQA1A7xszo5780bHLI1AD0Fre27SvjlcagSKA1sYQ3F2AWWOUTPl+gEcb+/iW958befysSn6EjDKA1sYQvMo8G8shUN0C3iv1hLZi20EFAK2BIKwqAFqL/Wyg3+a6WwkElQC8WvUhURYIKgJ4NRPC0VjbI1B/FdDT5yLN/saQK69EPpN9dbADgM8inuhtEVTeAla35XYAgLG2QwCA8bZCAIBrbYMAANfbAgEA7lUeAQDuVxoBAOZUFgEA5lUSAQDmVg4BAOZXCgEAYiqDAABxlUAAgNhmfKdhaACI7+oiLvnXMQDWdOerbUMDwLp6F3XpTSMAWNvZ4i6/YwgA6zta5JTbxQCQ0+dip90rCIC8Zr7/4HIAyC39LmEAmAcA8wBgHgDMA4B5ADAPAOYBwDwAmAcA8wBgHgDMA4B5ADAPAOYBwDwAmAcA8wBgHgDMA4B5ADAPAOYBwDwAmAcA8/4BrV9c1aHK48EAAAAASUVORK5CYII=";

function toHtml() {
  let re = null;
  try { re = buildSearchRegex(); } catch { re = null; }

  const rows = results.map((r) => {
    const content = re ? highlight(r.line, re) : esc(r.line);
    return "<tr>" +
      "<td class='idx'>" + r.index + "</td>" +
      "<td class='file'>" + esc(r.fileName) + "</td>" +
      "<td class='type'>" + esc(r.type) + "</td>" +
      "<td class='line'>" + r.lineNumber + "</td>" +
      "<td class='content'>" + content + "</td>" +
      "<td class='path'>" + esc(r.path) + "</td>" +
    "</tr>";
  }).join("\n");

  const query = esc($("query").value);
  const stamp = nowStamp();

  let skippedHtml = "";
  if (skippedFiles.length) {
    const items = skippedFiles
      .map((s) => "<li>" + esc(s.path) + " \u2014 " + fmtSize(s.size) + "</li>")
      .join("");
    const limitTxt = lastMaxMB ? "larger than " + lastMaxMB + " MB" : "over the size limit";
    skippedHtml =
      "<div class='skipped'><b>" + skippedFiles.length + " file" +
      (skippedFiles.length > 1 ? "s" : "") + " skipped</b> (" + limitTxt + ")<ul>" +
      items + "</ul></div>";
  }

  const css =
    "body{font:13px/1.5 system-ui,'Segoe UI',Roboto,sans-serif;margin:0;color:#1a1d22;background:#fff}" +
    ".wrap{max-width:1200px;margin:0 auto;padding:24px}" +
    ".hd{display:flex;align-items:center;gap:14px;margin:0 0 18px}" +
    ".logo{width:40px;height:40px;flex:none}" +
    "h1{font-family:ui-monospace,Menlo,Consolas,monospace;margin:0;font-size:22px;font-weight:700}" +
    "h1 span{color:#f5a623}" +
    ".meta{color:#6b7280;margin:3px 0 0}" +
    ".meta b{color:#1a1d22;font-weight:700}" +
    ".skipped{margin:14px 0 0;padding:10px 14px;background:#fff8e6;border:1px solid #f0e2b8;" +
      "border-left:3px solid #f5a623;border-radius:6px;color:#6b5d33;font-size:13px}" +
    ".skipped b{color:#4b4222}" +
    ".skipped ul{margin:6px 0 0;padding-left:18px}" +
    ".skipped li{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:12px;color:#6b5d33}" +
    "table{border-collapse:collapse;width:100%;font-size:13px}" +
    "thead th{position:sticky;top:0;background:#eef0f3;text-align:left;padding:9px 10px;" +
      "border-bottom:2px solid #d7dbe0;font-size:12px;text-transform:uppercase;letter-spacing:.04em;color:#4b5563}" +
    "thead .filters th{position:sticky;top:36px;background:#f7f8fa;padding:6px 8px;border-bottom:1px solid #e2e6ea}" +
    "input.f{width:100%;box-sizing:border-box;border:1px solid #cfd4da;border-radius:5px;" +
      "padding:5px 7px;font:12.5px system-ui;outline:none;color:#1a1d22}" +
    "input.f::placeholder{color:#9ca3af}" +
    "input.f:focus{border-color:#f5a623;box-shadow:0 0 0 3px rgba(245,166,35,.14)}" +
    "tbody td{padding:7px 10px;border-bottom:1px solid #edf0f2;vertical-align:top}" +
    "tbody tr:nth-child(odd){background:#ffffff}" +
    "tbody tr:nth-child(even){background:#f5f6f8}" +
    "tbody tr:hover{background:#fff3d0}" +
    "td.idx,td.line{color:#9aa1ab;text-align:right;white-space:nowrap;font-family:ui-monospace,Menlo,Consolas,monospace}" +
    "td.file{font-family:ui-monospace,Menlo,Consolas,monospace;white-space:nowrap;font-weight:600}" +
    "td.type{color:#6b7280;font-family:ui-monospace,Menlo,Consolas,monospace;white-space:nowrap}" +
    "td.content{font-family:ui-monospace,Menlo,Consolas,monospace;word-break:break-word}" +
    "td.content mark{background:#ffd23f;color:#1a1d22;font-weight:400;border-radius:2px;padding:0 1px}" +
    "td.path{color:#6b7280;font-family:ui-monospace,Menlo,Consolas,monospace;word-break:break-all}" +
    ".count{color:#6b7280;font-size:12px;margin:10px 2px 0}";

  const script =
    "(function(){" +
    "var inputs=document.querySelectorAll('input.f');" +
    "var rows=Array.prototype.slice.call(document.querySelectorAll('tbody tr'));" +
    "var countEl=document.getElementById('count');var shownEl=document.getElementById('shown');var total=rows.length;" +
    "function apply(){var filters=[];inputs.forEach(function(inp){var v=inp.value.trim().toLowerCase();" +
    "if(v)filters.push([parseInt(inp.getAttribute('data-col'),10),v]);});" +
    "var shown=0;rows.forEach(function(tr){var ok=true;" +
    "for(var i=0;i<filters.length;i++){var cell=tr.children[filters[i][0]];" +
    "if(!cell||cell.textContent.toLowerCase().indexOf(filters[i][1])===-1){ok=false;break;}}" +
    "tr.style.display=ok?'':'none';if(ok)shown++;});" +
    "countEl.textContent=shown+' of '+total+' rows';if(shownEl)shownEl.textContent=shown;}" +
    "inputs.forEach(function(inp){inp.addEventListener('input',apply);});" +
    "})();";

  return "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'>" +
    "<meta name='viewport' content='width=device-width, initial-scale=1'>" +
    "<title>TextTrace Report</title><style>" + css + "</style></head><body><div class='wrap'>" +
    "<div class='hd'><img class='logo' src='" + REPORT_LOGO + "' alt=''>" +
    "<div><h1>Text<span>Trace</span> Report</h1>" +
    "<p class='meta'><span id='shown'>" + results.length + "</span> of " +
    "<span id='total'>" + results.length + "</span> matches shown \u00B7 pattern: <b>" + query +
    "</b> \u00B7 scope: Files \u00B7 " + stamp + "</p></div></div>" +
    skippedHtml +
    "<table><thead>" +
    "<tr><th>Index</th><th>Filename</th><th>Type</th><th>LineNumber</th><th>Content</th><th>Path</th></tr>" +
    "<tr class='filters'><th></th>" +
    "<th><input class='f' data-col='1' placeholder='Filter filename'></th>" +
    "<th><input class='f' data-col='2' placeholder='Filter type'></th>" +
    "<th><input class='f' data-col='3' placeholder='Filter linenumber'></th>" +
    "<th><input class='f' data-col='4' placeholder='Filter content'></th>" +
    "<th><input class='f' data-col='5' placeholder='Filter path'></th></tr>" +
    "</thead><tbody>" + rows + "</tbody></table>" +
    "<p class='count' id='count'>" + results.length + " of " + results.length + " rows</p>" +
    "<script>" + script + "<\/script>" +
    "</div></body></html>";
}

// ---- Wiring ---------------------------------------------------------------
$("run").addEventListener("click", search);
$("query").addEventListener("keydown", (e) => { if (e.key === "Enter") search(); });
$("stop").addEventListener("click", () => { if (running) cancel = true; });
$("exportCsv").addEventListener("click", () => download("TextTrace_" + fileStamp() + ".csv", toCsv(), "text/csv"));
$("exportJson").addEventListener("click", () => download("TextTrace_" + fileStamp() + ".json", toJson(), "application/json"));
$("exportHtml").addEventListener("click", () => download("TextTrace_" + fileStamp() + ".html", toHtml(), "text/html"));
