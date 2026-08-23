"use strict";

// ---------- Element references ----------
const el = (id) => document.getElementById(id);
const pickDirBtn   = el("pickDir");
const dirLabel     = el("dirLabel");
const patternInput = el("pattern");
const searchBtn    = el("search");
const stopBtn      = el("stop");
const useRegexCb    = el("useRegex");
const caseCb        = el("caseSensitive");
const recursiveCb   = el("recursive");
const maxSizeIn     = el("maxSize");
const allTypesCb    = el("allTypes");
const typesGrid     = el("typesGrid");
const customExtIn   = el("customExt");
const checkAllBtn   = el("checkAll");
const checkNoneBtn  = el("checkNone");
const resultsBody  = el("resultsBody");
const emptyState   = el("emptyState");
const statScanned  = el("statScanned");
const statMatches  = el("statMatches");
const statElapsed  = el("statElapsed");
const statSkipped  = el("statSkipped");
const statCurrent  = el("statCurrent");
const exportCsvBtn  = el("exportCsv");
const exportJsonBtn = el("exportJson");
const exportHtmlBtn = el("exportHtml");
const toast        = el("toast");

// ---------- State ----------
let dirHandle = null;
let running = false;
let aborted = false;
let results = [];        // { index, fileName, type, lineNumber, line, path }
let skipped = [];        // files skipped because they exceed the size limit
let lastMaxMB = 20;      // size limit used by the last search (for the report)
let matcherForRender = null; // regex used to highlight in the table

// Files that are almost never useful to scan as text.
const SKIP_EXT = new Set([
  "png","jpg","jpeg","gif","bmp","ico","webp","svg","pdf","zip","gz","7z",
  "rar","tar","exe","dll","bin","mp3","mp4","mov","avi","woff","woff2","ttf",
  "otf","eot","class","jar","so","dylib","o","obj","lib","pdb"
]);

// Read the size limit (MB) from the UI; default to 20 MB if blank/invalid.
function getMaxMB() {
  const v = parseFloat(maxSizeIn.value);
  return (isFinite(v) && v > 0) ? v : 20;
}

// Fallback list used only if filetypes.json can't be read.
const FALLBACK_TYPES = [
  "bat","cmd","config","csv","htm","html","ini","json","log",
  "md","ps1","psm1","sql","txt","xml","yaml","yml"
];

const typeBoxes = () => [...typesGrid.querySelectorAll('input[data-typebox="true"]')];

// Build the file-type checkboxes from a list of extensions (sorted A–Z).
function renderTypeCheckboxes(exts) {
  const clean = [...new Set(
    exts.map((e) => String(e).trim().replace(/^\*?\./, "").toLowerCase()).filter(Boolean)
  )].sort((a, b) => a.localeCompare(b));

  typesGrid.innerHTML = "";
  clean.forEach((ext) => {
    const label = document.createElement("label");
    label.className = "type-check";
    const cb = document.createElement("input");
    cb.type = "checkbox";
    cb.value = ext;
    cb.checked = true;
    cb.dataset.typebox = "true";
    label.append(cb, document.createTextNode("." + ext));
    typesGrid.appendChild(label);
  });
}

// Read the file types from filetypes.json (bundled with the extension).
async function loadFileTypes() {
  try {
    const res = await fetch("filetypes.json", { cache: "no-store" });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const data = await res.json();
    const list = Array.isArray(data.fileTypes) ? data.fileTypes
               : Array.isArray(data.extensions) ? data.extensions
               : Array.isArray(data) ? data : null;
    if (!list || list.length === 0) throw new Error("empty fileTypes");
    renderTypeCheckboxes(list);
  } catch (err) {
    renderTypeCheckboxes(FALLBACK_TYPES);
  }
}
loadFileTypes();

// Read version.json (bundled with the extension) and show the version badge.
async function loadVersion() {
  try {
    const res = await fetch("version.json", { cache: "no-store" });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const data = await res.json();
    if (data && data.version) {
      const badge = el("appVersion");
      badge.textContent = "v" + data.version;
      if (data.date) badge.title = "Released " + data.date;
      badge.hidden = false;
    }
  } catch (err) {
    /* no version.json — leave the badge hidden */
  }
}
loadVersion();

// "All files" overrides the individual boxes.
allTypesCb.addEventListener("change", () => {
  typesGrid.classList.toggle("disabled", allTypesCb.checked);
  customExtIn.disabled = allTypesCb.checked;
});
checkAllBtn.addEventListener("click", () => typeBoxes().forEach((b) => (b.checked = true)));
checkNoneBtn.addEventListener("click", () => typeBoxes().forEach((b) => (b.checked = false)));

// ---------- Directory selection ----------
pickDirBtn.addEventListener("click", async () => {
  if (!window.showDirectoryPicker) {
    showToast("Your Edge version is missing the folder picker (File System Access API).");
    return;
  }
  try {
    dirHandle = await window.showDirectoryPicker({ mode: "read" });
    dirLabel.textContent = dirHandle.name;
    dirLabel.dataset.empty = "false";
    updateSearchEnabled();
  } catch (err) {
    if (err && err.name !== "AbortError") {
      showToast("Couldn't open the folder.");
    }
  }
});

patternInput.addEventListener("input", updateSearchEnabled);
patternInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !searchBtn.disabled) startSearch();
});

function updateSearchEnabled() {
  searchBtn.disabled = running || !dirHandle || patternInput.value.trim() === "";
}

// ---------- Search ----------
searchBtn.addEventListener("click", startSearch);
stopBtn.addEventListener("click", () => { aborted = true; });

// Returns a Set of extensions to match, or null to match every file.
function getExtensionFilter() {
  if (allTypesCb.checked) return null; // match everything

  const set = new Set();
  typeBoxes().forEach((b) => { if (b.checked) set.add(b.value); });

  // Add any custom extensions the user typed (accepts "cs", ".cs" or "*.cs").
  customExtIn.value
    .split(",")
    .map((s) => s.trim().replace(/^\*?\./, "").toLowerCase())
    .filter(Boolean)
    .forEach((ext) => set.add(ext));

  return set;
}

function buildMatcher(pattern, useRegex, caseSensitive, global) {
  const flags = (caseSensitive ? "" : "i") + (global ? "g" : "");
  const source = useRegex
    ? pattern
    : pattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); // escape for literal search
  return new RegExp(source, flags);
}

async function* walk(handle, path, recursive) {
  for await (const entry of handle.values()) {
    const entryPath = path ? `${path}/${entry.name}` : entry.name;
    if (entry.kind === "file") {
      yield { handle: entry, path: entryPath, name: entry.name };
    } else if (entry.kind === "directory" && recursive) {
      yield* walk(entry, entryPath, recursive);
    }
  }
}

function extensionOf(name) {
  const dot = name.lastIndexOf(".");
  return dot === -1 ? "" : name.slice(dot + 1).toLowerCase();
}

async function startSearch() {
  const pattern = patternInput.value;
  if (!dirHandle || pattern.trim() === "" || running) return;

  // Validate regex early so the user gets a clear message.
  try {
    buildMatcher(pattern, useRegexCb.checked, caseCb.checked, true);
  } catch (err) {
    showToast("Invalid regex pattern: " + err.message);
    return;
  }

  // Reset UI
  running = true;
  aborted = false;
  results = [];
  skipped = [];
  resultsBody.innerHTML = "";
  emptyState.style.display = "none";
  setExportEnabled(false);
  statSkipped.hidden = true;
  statSkipped.textContent = "";
  searchBtn.disabled = true;
  stopBtn.disabled = false;
  pickDirBtn.disabled = true;

  const extFilter = getExtensionFilter();
  if (extFilter && extFilter.size === 0) {
    showToast("Select at least one file type (or check \u201cAll files\u201d).");
    running = false; stopBtn.disabled = true; pickDirBtn.disabled = false;
    updateSearchEnabled();
    return;
  }
  const recursive = recursiveCb.checked;
  lastMaxMB = getMaxMB();
  const maxBytes = lastMaxMB * 1024 * 1024;
  matcherForRender = buildMatcher(pattern, useRegexCb.checked, caseCb.checked, true);

  let scanned = 0;
  let matchCount = 0;
  const started = performance.now();
  statScanned.textContent = "0";
  statMatches.textContent = "0";
  statElapsed.textContent = "";

  try {
    for await (const file of walk(dirHandle, "", recursive)) {
      if (aborted) break;

      const ext = extensionOf(file.name);
      if (extFilter && !extFilter.has(ext)) continue;
      if (SKIP_EXT.has(ext)) continue;

      let text;
      try {
        const f = await file.handle.getFile();
        if (f.size > maxBytes) {
          skipped.push({
            fileName: file.name,
            type: (extensionOf(file.name) || "").toUpperCase(),
            size: f.size,
            path: file.path
          });
          continue;
        }
        text = await f.text();
      } catch {
        continue; // unreadable / not a text file
      }

      scanned++;
      statCurrent.textContent = file.path;

      const lines = text.split(/\r?\n/);
      for (let i = 0; i < lines.length; i++) {
        // Fresh regex per line to keep lastIndex clean.
        const m = buildMatcher(pattern, useRegexCb.checked, caseCb.checked, false);
        if (m.test(lines[i])) {
          matchCount++;
          const row = {
            index: matchCount,
            fileName: file.name,
            type: (extensionOf(file.name) || "").toUpperCase(),
            lineNumber: i + 1,
            line: lines[i],
            path: file.path
          };
          results.push(row);
          appendRow(row);
        }
      }

      if (scanned % 25 === 0) {
        statScanned.textContent = String(scanned);
        statMatches.textContent = String(matchCount);
        await new Promise((r) => setTimeout(r, 0)); // let the UI breathe + allow Stop
      }
    }
  } catch (err) {
    showToast("Search interrupted: " + (err.message || err));
  }

  // Finalise
  const elapsed = ((performance.now() - started) / 1000).toFixed(2);
  statScanned.textContent = String(scanned);
  statMatches.textContent = String(matchCount);
  statElapsed.textContent = `${elapsed}s${aborted ? " · stopped" : ""}`;
  statCurrent.textContent = "";

  if (skipped.length) {
    statSkipped.textContent = `${skipped.length} skipped (> ${lastMaxMB} MB)`;
    statSkipped.hidden = false;
  } else {
    statSkipped.hidden = true;
  }

  running = false;
  stopBtn.disabled = true;
  pickDirBtn.disabled = false;
  updateSearchEnabled();
  setExportEnabled(results.length > 0 || skipped.length > 0);

  if (results.length === 0) {
    emptyState.textContent = skipped.length
      ? `No matches. ${skipped.length} file(s) skipped as larger than ${lastMaxMB} MB — see the HTML report.`
      : "No matches.";
    emptyState.style.display = "block";
  }
}

// ---------- Rendering ----------
function appendRow(row) {
  const tr = document.createElement("tr");

  const tdIndex = document.createElement("td");
  tdIndex.className = "cell-index";
  tdIndex.textContent = row.index;

  const tdFile = document.createElement("td");
  tdFile.className = "cell-file";
  tdFile.textContent = row.fileName;
  tdFile.title = row.fileName;

  const tdType = document.createElement("td");
  tdType.className = "cell-type";
  tdType.textContent = row.type;

  const tdLineNo = document.createElement("td");
  tdLineNo.className = "cell-line-no";
  tdLineNo.textContent = row.lineNumber;

  const tdLine = document.createElement("td");
  tdLine.className = "cell-line";
  tdLine.appendChild(highlight(row.line));

  const tdPath = document.createElement("td");
  tdPath.className = "cell-path";
  tdPath.textContent = row.path;
  tdPath.title = row.path;

  const tdAct = document.createElement("td");
  const copyBtn = document.createElement("button");
  copyBtn.className = "copy-btn";
  copyBtn.textContent = "\u29C9";
  copyBtn.title = "Copy path";
  copyBtn.addEventListener("click", () => copyPath(row.path));
  tdAct.appendChild(copyBtn);

  tr.append(tdIndex, tdFile, tdType, tdLineNo, tdLine, tdPath, tdAct);
  resultsBody.appendChild(tr);
}

// Wrap matches in <mark>, escaping everything else.
function highlight(line) {
  const frag = document.createDocumentFragment();
  if (!matcherForRender) { frag.append(document.createTextNode(line)); return frag; }

  matcherForRender.lastIndex = 0;
  let last = 0;
  let m;
  let guard = 0;
  while ((m = matcherForRender.exec(line)) !== null) {
    if (guard++ > 5000) break;
    if (m.index > last) frag.append(document.createTextNode(line.slice(last, m.index)));
    const mark = document.createElement("mark");
    mark.textContent = m[0];
    frag.append(mark);
    last = m.index + m[0].length;
    if (m[0].length === 0) matcherForRender.lastIndex++; // avoid infinite loop on empty match
  }
  if (last < line.length) frag.append(document.createTextNode(line.slice(last)));
  return frag;
}

// ---------- Copy / toast ----------
async function copyPath(path) {
  try {
    await navigator.clipboard.writeText(path);
    showToast("Path copied");
  } catch {
    showToast("Couldn't copy");
  }
}

let toastTimer = null;
function showToast(msg) {
  toast.textContent = msg;
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 2200);
}

// ---------- Export ----------
function setExportEnabled(on) {
  exportCsvBtn.disabled = !on;
  exportJsonBtn.disabled = !on;
  exportHtmlBtn.disabled = !on;
}

function download(filename, content, mime) {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function stamp() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

// CSV: UTF-8 with BOM, semicolon delimiter — matches TextTrace's report format.
exportCsvBtn.addEventListener("click", () => {
  const q = (v) => {
    const s = String(v);
    return /[";\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  };
  const header = ["Index", "FileName", "Type", "LineNumber", "Content", "Path"];
  const rows = results.map((r) =>
    [r.index, r.fileName, r.type, r.lineNumber, r.line, r.path].map(q).join(";")
  );
  const csv = "\uFEFF" + [header.join(";"), ...rows].join("\r\n");
  download(`TextTrace_${stamp()}.csv`, csv, "text/csv;charset=utf-8");
});

exportJsonBtn.addEventListener("click", () => {
  const payload = results.map((r) => ({
    Index: r.index, FileName: r.fileName, Type: r.type,
    LineNumber: r.lineNumber, Content: r.line, Path: r.path
  }));
  download(`TextTrace_${stamp()}.json`, JSON.stringify(payload, null, 2), "application/json");
});

exportHtmlBtn.addEventListener("click", () => {
  const REPORT_LOGO = "data:image/png;base64,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";
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

  // Rebuild the current matcher so the report highlights the same term.
  let rx = null;
  try {
    rx = buildMatcher(patternInput.value, useRegexCb.checked, caseCb.checked, true);
  } catch { rx = null; }

  const hl = (line) => {
    if (!rx) return esc(line);
    rx.lastIndex = 0;
    let out = "", last = 0, m, guard = 0;
    while ((m = rx.exec(line)) !== null) {
      if (guard++ > 5000) break;
      out += esc(line.slice(last, m.index)) + "<mark>" + esc(m[0]) + "</mark>";
      last = m.index + m[0].length;
      if (m[0].length === 0) rx.lastIndex++;
    }
    return out + esc(line.slice(last));
  };

  const rows = results.map((r) => `<tr>
    <td class="c-idx">${r.index}</td><td class="c-file">${esc(r.fileName)}</td><td class="c-type">${esc(r.type)}</td><td class="c-idx">${r.lineNumber}</td>
    <td><code>${hl(r.line)}</code></td><td class="c-path">${esc(r.path)}</td></tr>`).join("\n");

  // Live filter script (kept quote-only so no ${} interpolation leaks in).
  const filterScript =
    "(function(){" +
    "var filters=document.querySelectorAll('.flt');" +
    "var rows=Array.prototype.slice.call(document.querySelectorAll('tbody tr'));" +
    "var counter=document.getElementById('rowcount');var total=rows.length;" +
    "function apply(){var specs=[];filters.forEach(function(f){specs.push({col:parseInt(f.getAttribute('data-col'),10),v:f.value.toLowerCase()});});" +
    "var shown=0;rows.forEach(function(tr){var cells=tr.children;" +
    "var ok=specs.every(function(s){if(!s.v)return true;var cell=cells[s.col];return cell&&cell.textContent.toLowerCase().indexOf(s.v)!==-1;});" +
    "tr.style.display=ok?'':'none';if(ok)shown++;});" +
    "counter.textContent=shown+' of '+total+' rows';}" +
    "filters.forEach(function(f){f.addEventListener('input',apply);});" +
    "})();";

  // Section listing files skipped for exceeding the size limit.
  const fmtMB = (bytes) => (bytes / (1024 * 1024)).toFixed(1) + " MB";
  let skippedSection = "";
  if (skipped.length) {
    const srows = skipped.map((s, i) => `<tr>
      <td class="c-idx">${i + 1}</td><td class="c-file">${esc(s.fileName)}</td><td class="c-type">${esc(s.type)}</td>
      <td class="c-idx">${fmtMB(s.size)}</td><td class="c-path">${esc(s.path)}</td></tr>`).join("\n");
    skippedSection = `
<h2 class="skh">Skipped files — larger than ${lastMaxMB} MB (${skipped.length})</h2>
<table class="skt">
<thead><tr><th>#</th><th>Filename</th><th>Type</th><th>Size</th><th>Path</th></tr></thead>
<tbody>${srows}</tbody></table>`;
  }

  const html = `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TextTrace Report</title>
<style>
  :root{color-scheme:light;
    --mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
  body{font-family:var(--sans);background:#ffffff;color:#1a1d22;margin:24px}

  .brandbar{display:flex;align-items:center;gap:12px;margin:0 0 6px}
  .logo{width:40px;height:40px;display:block;flex:none}
  h1{font-family:var(--mono);font-size:22px;font-weight:700;letter-spacing:.3px;margin:0;color:#1a1d22}
  h1 .accent{color:#f5a623}
  h1 .rep{color:#1a1d22;font-weight:700}
  .meta{font-family:var(--sans);color:#6b7280;font-size:13px;margin:0 0 16px}
  .meta b{color:#1a1d22;font-weight:700}

  table{border-collapse:collapse;width:100%;font-size:13px}
  thead th{position:sticky;top:0;background:#eef0f3;color:#4b5563;text-align:left;
    font-family:var(--sans);font-size:12px;text-transform:uppercase;letter-spacing:.04em;
    font-weight:600;padding:9px 10px;border-bottom:2px solid #d7dbe0}
  thead tr.filters th{background:#f7f8fa;padding:6px 8px;text-transform:none;
    position:sticky;top:36px;border-bottom:1px solid #e2e6ea}
  .flt{width:100%;box-sizing:border-box;font-family:var(--sans);font-size:12.5px;padding:5px 7px;
    border:1px solid #cfd4da;border-radius:5px;background:#fff;color:#1a1d22}
  .flt::placeholder{color:#9ca3af}
  .flt:focus{outline:none;border-color:#f5a623;box-shadow:0 0 0 3px rgba(245,166,35,.14)}

  tbody td{padding:7px 10px;border-bottom:1px solid #edf0f2;vertical-align:top}
  tbody tr:nth-child(odd){background:#ffffff}          /* zebra: odd rows white */
  tbody tr:nth-child(even){background:#f5f6f8}          /* zebra: even rows grey */
  tbody tr:hover{background:#fff3d0}                    /* hover highlight */

  .c-idx{font-family:var(--mono);font-size:13px;color:#9aa1ab;text-align:right;white-space:nowrap}
  .c-file{font-family:var(--mono);font-size:13px;font-weight:600;color:#1a1d22;white-space:nowrap}
  .c-type{font-family:var(--mono);font-size:13px;color:#6b7280;white-space:nowrap}
  .c-path{font-family:var(--mono);font-size:13px;color:#6b7280;white-space:nowrap}
  code{font-family:var(--mono);font-size:13px;color:#1a1d22;white-space:pre-wrap;word-break:break-word}
  mark{background:#ffd23f;color:#1a1d22;font-weight:400;border-radius:2px;padding:0 1px}

  .count{font-family:var(--sans);color:#6b7280;font-size:12px;margin:10px 2px 0}
  .skh{font-family:var(--sans);font-size:14px;font-weight:600;color:#1a1d22;margin:26px 0 8px}
  .skt{margin-top:0}
</style></head><body>
<div class="brandbar">
  <img class="logo" src="${REPORT_LOGO}" alt="">
  <h1>Text<span class="accent">Trace</span> <span class="rep">Report</span></h1>
</div>
<p class="meta"><b>${results.length}</b> matches · ${new Date().toLocaleString()}</p>
<table>
<thead>
  <tr><th>Index</th><th>Filename</th><th>Type</th><th>LineNumber</th><th>Content</th><th>Path</th></tr>
  <tr class="filters">
    <th></th>
    <th><input class="flt" data-col="1" placeholder="Filter Filename"></th>
    <th><input class="flt" data-col="2" placeholder="Filter Type"></th>
    <th><input class="flt" data-col="3" placeholder="Filter LineNumber"></th>
    <th><input class="flt" data-col="4" placeholder="Filter Content"></th>
    <th><input class="flt" data-col="5" placeholder="Filter Path"></th>
  </tr>
</thead>
<tbody>${rows}</tbody></table>
<p class="count" id="rowcount">${results.length} of ${results.length} rows</p>
${skippedSection}
<script>${filterScript}</script>
</body></html>`;
  download(`TextTrace_${stamp()}.html`, html, "text/html;charset=utf-8");
});

// ---------- Init ----------
updateSearchEnabled();
