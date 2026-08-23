"use strict";

const FALLBACK_EXTS = ["bat","cmd","config","csv","htm","html","ini","json",
  "log","md","ps1","psm1","sql","txt","xml","yaml","yml"];
let EXTS = [];
let maxBytes = 20 * 1024 * 1024; // configurable via the UI; default 20 MB
let lastMaxMB = 20;

const $ = (s) => document.querySelector(s);
const esc = (s) => s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));

let dirHandle = null;
let cancel = false;
let results = []; // { idx, file, type, line, content, path }
let skipped = []; // { file, path, size } for files larger than the size limit

// ---- Build file-type checkbox grid (extensions come from filetypes.json) ----
const grid = $("#types");

function buildGrid(exts) {
  grid.innerHTML = "";
  exts.forEach((e) => {
    const l = document.createElement("label");
    l.innerHTML =
      `<input type="checkbox" class="ext-chk" value="${e}" checked><span class="ext">.${e}</span>`;
    grid.appendChild(l);
  });
}

async function loadFileTypes() {
  try {
    const url =
      typeof chrome !== "undefined" && chrome.runtime && chrome.runtime.getURL
        ? chrome.runtime.getURL("filetypes.json")
        : "filetypes.json";
    const res = await fetch(url);
    const data = await res.json();
    EXTS = (data.fileTypes || []).map((s) => s.replace(/^\*\./, "").toLowerCase());
  } catch (_) {
    EXTS = FALLBACK_EXTS.slice();
  }
  EXTS.sort((a, b) => a.localeCompare(b)); // alphabetical order
  buildGrid(EXTS);
}
loadFileTypes();

async function loadVersion() {
  try {
    const url =
      typeof chrome !== "undefined" && chrome.runtime && chrome.runtime.getURL
        ? chrome.runtime.getURL("version.json")
        : "version.json";
    const res = await fetch(url);
    const data = await res.json();
    if (data && data.version) {
      const el = $("#ver");
      el.textContent = "v" + data.version;
      el.title = "TextTrace " + data.version + (data.date ? " · " + data.date : "");
      if (data.githublink) el.href = data.githublink;
      el.style.display = "";
    }
  } catch (_) {
    /* version badge stays hidden if version.json is unavailable */
  }
}
loadVersion();

const extBoxes = () => [...document.querySelectorAll(".ext-chk")];

$("#selall").addEventListener("click", () => extBoxes().forEach((b) => (b.checked = true)));
$("#clearall").addEventListener("click", () => extBoxes().forEach((b) => (b.checked = false)));
$("#allfiles").addEventListener("change", (e) =>
  extBoxes().forEach((b) => (b.disabled = e.target.checked))
);

function activeExtensions() {
  if ($("#allfiles").checked) return null; // null = match every file
  const set = new Set(extBoxes().filter((b) => b.checked).map((b) => b.value.toLowerCase()));
  $("#custom").value
    .split(",")
    .map((s) => s.trim().replace(/^\./, "").toLowerCase())
    .filter(Boolean)
    .forEach((x) => set.add(x));
  return set;
}

function extOf(name) {
  const i = name.lastIndexOf(".");
  return i < 0 ? "" : name.slice(i + 1).toLowerCase();
}

function buildPattern() {
  const q = $("#q").value;
  const cs = $("#case").checked;
  const flags = cs ? "g" : "gi";
  if (!q) return null;
  if ($("#regex").checked) return new RegExp(q, flags);
  return new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), flags);
}

// ---- Folder picker ----
$("#pick").addEventListener("click", async () => {
  if (!window.showDirectoryPicker) {
    alert("This browser does not support the File System Access API. Use Chrome or Edge.");
    return;
  }
  try {
    dirHandle = await window.showDirectoryPicker();
    $("#folder").textContent = dirHandle.name;
    $("#folder").setAttribute("data-empty", "false");
  } catch (_) {
    /* user cancelled */
  }
});

// ---- Search ----
async function run() {
  if (!dirHandle) {
    $("#pick").focus();
    flashEmpty("Choose a folder first", "Click “Choose folder…” to pick a directory to search.");
    return;
  }
  let pattern;
  try {
    pattern = buildPattern();
  } catch (_) {
    flashEmpty("Invalid regular expression", "Check the search term or turn off Regex.");
    return;
  }
  if (!pattern) {
    flashEmpty("Enter a search term", "Type a word or a regular expression above.");
    return;
  }

  const exts = activeExtensions();
  const mb = parseFloat($("#maxsize").value);
  lastMaxMB = isFinite(mb) && mb > 0 ? mb : 20;
  maxBytes = lastMaxMB * 1024 * 1024;
  const t0 = performance.now();
  cancel = false;
  results = [];
  skipped = [];
  let scanned = 0;

  $("#rows").innerHTML = "";
  $("#empty").style.display = "none";
  $("#go").disabled = true;
  $("#stop").disabled = false;

  const recurse = $("#recurse").checked;
  try {
    scanned = await walk(dirHandle, dirHandle.name, pattern, exts, recurse, 0);
  } catch (err) {
    console.error(err);
  }

  const secs = ((performance.now() - t0) / 1000).toFixed(2);
  $("#scanned").textContent = scanned.toLocaleString("en-US");
  $("#hits").textContent = results.length.toLocaleString("en-US");
  $("#time").textContent = secs + "s";

  const sk = $("#skipped-stat");
  if (skipped.length) {
    sk.style.display = "";
    sk.title = "Files larger than " + lastMaxMB + " MB were skipped";
    sk.innerHTML = "<b>" + skipped.length.toLocaleString("en-US") + "</b> skipped";
  } else {
    sk.style.display = "none";
  }
  $("#go").disabled = false;
  $("#stop").disabled = true;

  renderRows();
  if (results.length === 0)
    flashEmpty("No matches", "Nothing matched. Adjust the term, toggle Regex, or widen file types.");
}

async function walk(dir, path, pattern, exts, recurse, scannedSoFar) {
  let scanned = scannedSoFar;
  for await (const [name, handle] of dir.entries()) {
    if (cancel) return scanned;
    const p = path + "/" + name;
    if (handle.kind === "file") {
      if (exts && !exts.has(extOf(name))) continue;
      let file;
      try {
        file = await handle.getFile();
      } catch (_) {
        continue;
      }
      if (file.size > maxBytes) {
        skipped.push({ file: name, path: p, size: file.size });
        continue;
      }
      scanned++;
      let text;
      try {
        text = await file.text();
      } catch (_) {
        continue;
      }
      const lines = text.split(/\r?\n/);
      for (let i = 0; i < lines.length; i++) {
        pattern.lastIndex = 0;
        if (pattern.test(lines[i])) {
          results.push({
            idx: results.length + 1,
            file: name,
            type: extOf(name),
            line: i + 1,
            content: lines[i],
            path: p,
          });
        }
      }
      if (scanned % 200 === 0) await new Promise((r) => setTimeout(r, 0)); // keep UI responsive
    } else if (handle.kind === "directory" && recurse) {
      scanned = await walk(handle, p, pattern, exts, recurse, scanned);
    }
  }
  return scanned;
}

// ---- Rendering ----
function renderRows() {
  const pattern = buildPattern();
  const tb = $("#rows");
  tb.innerHTML = "";
  const frag = document.createDocumentFragment();
  for (const r of results) {
    let marked = esc(r.content);
    if (pattern) {
      pattern.lastIndex = 0;
      marked = esc(r.content).replace(pattern, (m) => `<mark>${esc(m)}</mark>`);
    }
    const tr = document.createElement("tr");
    tr.innerHTML =
      `<td class="idx">${r.idx}</td>` +
      `<td class="file">${esc(r.file)}</td>` +
      `<td class="type">${esc(r.type)}</td>` +
      `<td class="line">${r.line}</td>` +
      `<td class="content">${marked}</td>` +
      `<td class="path">${esc(r.path)}</td>` +
      `<td class="copy"><button class="copy-btn" title="Copy path">` +
      `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/></svg></button></td>`;
    tr.querySelector(".copy-btn").addEventListener("click", (ev) => {
      ev.stopPropagation();
      copy(r.path);
    });
    frag.appendChild(tr);
  }
  tb.appendChild(frag);
}

function flashEmpty(title, body) {
  $("#empty").style.display = "block";
  $("#empty").querySelector(".big").textContent = title;
  $("#empty").lastChild.nodeValue = " " + body;
  $("#empty").innerHTML = `<div class="big">${esc(title)}</div>${esc(body)}`;
}

function copy(text) {
  if (navigator.clipboard) navigator.clipboard.writeText(text);
}

// ---- Export ----
function stamp() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, "0");
  return (
    d.getFullYear() +
    p(d.getMonth() + 1) +
    p(d.getDate()) +
    "_" +
    p(d.getHours()) +
    p(d.getMinutes()) +
    p(d.getSeconds())
  );
}

function download(filename, text, mime) {
  const blob = new Blob([text], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function exportCSV() {
  const q = (s) => `"${String(s).replace(/"/g, '""')}"`;
  const head = ["Index", "FileName", "Type", "LineNumber", "Content", "Path"].map(q).join(";");
  const body = results.map((r) =>
    [q(r.idx), q(r.file), q(r.type), q(r.line), q(r.content), q(r.path)].join(";")
  );
  download(`TextTrace_${stamp()}.csv`, [head, ...body].join("\r\n"), "text/csv");
}
function exportJSON() {
  const data = results.map((r) => ({
    Index: r.idx,
    FileName: r.file,
    Type: r.type,
    LineNumber: r.line,
    Content: r.content,
    Path: r.path,
  }));
  download(`TextTrace_${stamp()}.json`, JSON.stringify(data, null, 2), "application/json");
}
function exportHTML() {
  const pattern = buildPattern();
  const hl = (s) => {
    if (!pattern) return esc(s);
    pattern.lastIndex = 0;
    return esc(s).replace(pattern, (m) => `<mark>${esc(m)}</mark>`);
  };
  const rows = results
    .map(
      (r) =>
        `<tr><td class="num">${r.idx}</td>` +
        `<td data-col="file">${esc(r.file)}</td>` +
        `<td data-col="type">${esc(r.type)}</td>` +
        `<td class="num" data-col="line">${r.line}</td>` +
        `<td data-col="content"><code>${hl(r.content)}</code></td>` +
        `<td data-col="path">${esc(r.path)}</td></tr>`
    )
    .join("\n");

  const skippedHtml = skipped.length
    ? `
<div class="skipped">
  <div class="skipped-head">${skipped.length} file${skipped.length > 1 ? "s" : ""} skipped &middot; larger than ${lastMaxMB} MB</div>
  <table>
    <thead><tr><th>Filename</th><th>Size</th><th>Path</th></tr></thead>
    <tbody>
${skipped
  .map(
    (s) =>
      `      <tr><td>${esc(s.file)}</td><td class="size">${(s.size / 1024 / 1024).toFixed(1)} MB</td><td class="path">${esc(s.path)}</td></tr>`
  )
  .join("\n")}
    </tbody>
  </table>
</div>`
    : "";

  const doc = `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<title>TextTrace Report</title>
<style>
  :root{
    --ink:#1a1d22;--muted:#6b7280;--num:#9aa1ab;--amber:#f5a623;
    --line:#edf0f2;--stripe:#f5f6f8;--hover:#fff3d0;
    --headbg:#eef0f3;--headbd:#d7dbe0;--headtx:#4b5563;
    --filterbg:#f7f8fa;--filterbd:#e2e6ea;--fieldbd:#cfd4da;
    --mark:#ffd23f;
    --mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
  }
  *{box-sizing:border-box}
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;margin:0;color:var(--ink);background:#fff}
  header{padding:22px 28px}
  .brand{display:flex;align-items:center;gap:13px}
  .brand .logo{flex:none;width:40px;height:40px;display:block}
  h1{margin:0;font-family:var(--mono);font-weight:700;font-size:22px;letter-spacing:-.01em}
  h1 span{color:var(--amber)}
  .meta{color:var(--muted);font-size:13px;margin-top:7px}
  .tablewrap{padding:0 28px 40px}
  table{border-collapse:collapse;width:100%;font-size:13px;border:1px solid var(--headbd);border-radius:8px;overflow:hidden}
  thead th{position:sticky;top:0;background:var(--headbg);color:var(--headtx);text-align:left;
    padding:12px 14px;font-size:12px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;border-bottom:2px solid var(--headbd)}
  thead .filters th{background:var(--filterbg);padding:8px 12px;border-bottom:1px solid var(--filterbd)}
  thead input{width:100%;border:1px solid var(--fieldbd);background:#fff;color:var(--ink);
    border-radius:5px;padding:7px 10px;font-size:12.5px;font-family:inherit;outline:none}
  thead input:focus{border-color:var(--amber);box-shadow:0 0 0 3px rgba(245,166,35,.14)}
  thead input::placeholder{color:#9ca3af}
  tbody td{border-bottom:1px solid var(--line);padding:9px 14px;vertical-align:top;font-family:var(--mono)}
  tbody tr:last-child td{border-bottom:0}
  tbody tr:nth-child(even){background:var(--stripe)}
  tbody tr:hover{background:var(--hover)}
  td.num{text-align:right;color:var(--num);white-space:nowrap;font-variant-numeric:tabular-nums}
  td[data-col="file"]{font-weight:600}
  td[data-col="type"]{color:var(--muted)}
  td[data-col="path"]{color:var(--muted);white-space:nowrap}
  code{font-family:var(--mono)}
  mark{background:var(--mark);color:var(--ink);border-radius:2px;padding:0 2px;font-weight:400}
  .count{color:var(--muted);font-size:12px;padding:0 28px 12px}
  .skipped{padding:6px 28px 40px}
  .skipped-head{color:#b45309;font-size:13px;font-weight:700;margin:0 0 10px}
  .skipped table{width:100%;border-collapse:collapse;font-size:13px;border:1px solid var(--headbd);border-radius:8px;overflow:hidden}
  .skipped thead th{background:var(--headbg);color:var(--headtx);text-align:left;padding:10px 14px;font-size:12px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;border-bottom:1px solid var(--headbd)}
  .skipped tbody td{padding:8px 14px;border-bottom:1px solid var(--line);font-family:var(--mono)}
  .skipped tbody tr:last-child td{border-bottom:0}
  .skipped td.size{text-align:right;color:var(--muted);white-space:nowrap;font-variant-numeric:tabular-nums}
  .skipped td.path{color:var(--muted);white-space:nowrap}
</style></head>
<body>
<header>
  <div class="brand">
    <img class="logo" alt="TextTrace" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAE5UlEQVR4nO3Y32vddx3H8cfn+z05bZIlmUoQvVChKKJIxxAmyFyHTFjX7ofSUBCH4l9gquBdWlAUXYa3vVHYkEqqTZO06ZizSQvzxg4VVmUFdRfqfoTZZTVJc358316cc7J2zvQk57QVdp5wLs453/fn+3l93u/P+/3+fOjRo0ePHu9lUrcGigmZT0suy8AnhEWFwyIl0a33dJ2Ykkc0J73JMzfr/aVOjGNClsbUIU7YJbfbDp9RQeEt73faq15OYyoQIXXbG9sKoSCZakw+TrlHybiqh+V22tl8qI6rasIlyaQLnkpH1GJClo4obq+AKXkaU48Zk8q+JZdkqKDS8AhyQ2x8q3rBin1pzKst+y7Mf+sCYkEp3a8WMyYNGldF3aqS4yrmFF5UCHXDyh4Vvqrfx2S46s8qvpi+4pVueWJLAuKAPB1Xj2k/MOy71tTl/qDm22m/xXe1mTes8BM1X9cvqbgoudfvLN/SDBUTjUwTcz4ep9XiGfWY8Zc4aoCGZ2JKHhOymJBFyOKovg37WT+MZ0WcFTHtcMum03m17YEIuUXJsp8a9DXr1tU8mB61EBf0pc+q/g+7zAtybyirOG+n3Vb9S7+7fMkrgk680NYKNNNfPX6rX9gnE6rOpccsxIvKnhexoOTSOxakUcx4WZ6+YSWm/Uj4hQGjVt2XOBaLSqjdVAGOy1D3us/ZoV9dwrGmsEobI9QiJMedddU/3eFDwh4cs9TZHmhPwGhzZcMuZTutI/e3lEScsM+IB1xReGdFzoQ+yVVLKfkelmLaZZkPSz7ZycS3JqBFaqa9hKI52eR92KURBtePF01RSf91o0DRnezTnoC33fyamopcWTLaDKGn8fSNhgiSeUOqBpvL8PftTvpa2hNwoPnKEee8ac2IslUHUzIVU8pGb1CQ1uRpr/Wo+oKdPqpA5td4OzxvpoCUREzJXbLug86r26/PAzFnd9rvj63q/G62zc2bxQV9/mFcwqoVOzwPFrvXF21KqyWOWXfHvIgzipjx+43/F5QiZBHSxqfxW8NuxqF4TsSzIn7p+3Btobs1IlrV+ISfxVkRc+rxjFNx0qc2tTtlImZVYkY15hUx50w8ZZBmoeuArfVCJAtyexTm/NyAg2qoeV3ZUWvm5V5SFQp3yD0ofNOQe6yoK+QojMisOOeyh9LjVjpp7LbejYbksJSOKGLWMQMOqiPDvxWSy021fQYNSxotdWC9uX0LNSNK1ixatTeNWduuiO2dB64VccaXhXF8XomNqC5QRc2Smh8Lo+70Hcuq6BOqhvVZdU7Ymx62GiFLaWsiOkphjT6sUSNizr24W+4uNdQtGzJjxZ/SI16DmDFpyLi3miJanljtTjhtT0QbB/ZYUIqJRsqOGZNxVsRJlTgp4oRq/EbEKQsx1ajYrWTRDt27VpmS/1dRWhIOKFISrQSwcZobNt6NcOqagHaIkCw2RUybNHKDcGrjFqOjHLxVUhLuV48JpfSYQ6540rA+VGVKltUMuM+d5mK2edKLzRf5lnqgxabhVKj4gLI3POcj9vqrYrMbjFvqgRaJsEc9FpTSIw55s+mJUFFWtuIKnjSn7uL/87UkaSM7nfREnBdx2kpM28PWstFt4zoRs56IX3mI29Dodcq1m3UrDV7H9zLdYuPMcVFstZ3o0aNHjx7vXf4Dp4VZwvryk2wAAAAASUVORK5CYII=">
    <h1>Text<span>Trace</span> Report</h1>
  </div>
  <div class="meta">${results.length} matches &middot; ${new Date().toLocaleString("en-US")}</div>
</header>
<div class="count" id="count"></div>
<div class="tablewrap">
  <table id="tbl">
    <thead>
      <tr><th>Index</th><th>Filename</th><th>Type</th><th>LineNumber</th><th>Content</th><th>Path</th></tr>
      <tr class="filters">
        <th></th>
        <th><input data-f="file" placeholder="Filter Filename"></th>
        <th><input data-f="type" placeholder="Filter Type"></th>
        <th><input data-f="line" placeholder="Filter LineNumber"></th>
        <th><input data-f="content" placeholder="Filter Content"></th>
        <th><input data-f="path" placeholder="Filter Path"></th>
      </tr>
    </thead>
    <tbody>
${rows}
    </tbody>
  </table>
</div>
${skippedHtml}
<script>
(function(){
  var inputs=[].slice.call(document.querySelectorAll("thead input"));
  var rows=[].slice.call(document.querySelectorAll("tbody tr"));
  var count=document.getElementById("count");
  function apply(){
    var terms=inputs.map(function(i){return {col:i.dataset.f,v:i.value.toLowerCase()};});
    var shown=0;
    rows.forEach(function(tr){
      var ok=terms.every(function(t){
        if(!t.v) return true;
        var cell=tr.querySelector('[data-col="'+t.col+'"]');
        return cell && cell.textContent.toLowerCase().indexOf(t.v)>-1;
      });
      tr.style.display=ok?"":"none";
      if(ok) shown++;
    });
    count.textContent=shown+" of "+rows.length+" rows shown";
  }
  inputs.forEach(function(i){i.addEventListener("input",apply);});
  apply();
})();
</script>
</body></html>`;
  download(`TextTrace_${stamp()}.html`, doc, "text/html");
}

document.querySelectorAll(".exp button").forEach((b) =>
  b.addEventListener("click", () => {
    if (!results.length) return;
    if (b.dataset.x === "csv") exportCSV();
    else if (b.dataset.x === "json") exportJSON();
    else exportHTML();
  })
);

// ---- Wire up ----
$("#go").addEventListener("click", run);
$("#stop").addEventListener("click", () => (cancel = true));
$("#q").addEventListener("keydown", (e) => {
  if (e.key === "Enter") run();
});
// Re-highlight instantly when toggling case/regex without re-scanning:
["regex", "case"].forEach((id) =>
  $("#" + id).addEventListener("change", () => {
    if (results.length) renderRows();
  })
);
