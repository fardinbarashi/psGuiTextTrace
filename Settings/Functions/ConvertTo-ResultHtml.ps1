function ConvertTo-ResultHtml {
    param($Rows, [string]$Scope, [string]$Keyword)

    function E { param($s) [System.Net.WebUtility]::HtmlEncode([string]$s) }

    # Encode, then wrap search-term matches in <mark> (case-insensitive, literal).
    # Text and term are both HTML-encoded first, so the only raw markup inserted
    # is our own <mark> tag - no injection risk.
    $kwEnc = E $Keyword
    function Hl {
        param($s)
        $enc = E $s
        if ([string]::IsNullOrEmpty($kwEnc)) { return $enc }
        return [regex]::Replace($enc, [regex]::Escape($kwEnc),
            { param($m) '<mark>' + $m.Value + '</mark>' },
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    $iconB64 = 'iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAADJklEQVR4nO3dUY7iMBBFUTOa/a+ld8j8DBJCHWInLtcrv3u/aTvCJ3HTHeDx/Glk3J/sA6DcAGAeAMwDgHkAMA8A5gHAPACYBwDzAGAeAMwDgHkAMA8A5gHAPACYBwDzAGAeAMwDgHkAMA8A5gHAPACYBwDzAGAeAMz7m30AAT07HvMIP4oi7QCgZ8HPfsYWRGUAVxb+bCw7CBUBzFz4o7FtIFQCELnwR3NtD6HKq4CVi68w77IqAMhehOz5Q1PfAq48+T2X7dFxn53jlksZwMgijS7O++N759kSgeoW0Lsoj3Z/UUbG2G47UAQwsvgzs0SgBqD3z7hRl+LesbdBoAbgrFV78HZ7/VFKAM7OqtWLcjbfFlcBJQCUkAoAtbO/d97yVwEVAN/K3o+z5w9NAUD1s6j08SsA+JbK2adyHNNTB0DBAcC8bADf9k+1y+634yn7e0A2AEoOAOYp3w9w1IrLrdr2ExZXAPMAYF7FLcDm8rwirgDmAcC8bACV/rhS6Y9W3WUDoOQAYJ46AJVtQOU4pqcAoOz++b/Sx68A4Kzssy97/tBUAKjefKl6s+q0VABQUkoA1K4C25/9rWkB6GkVgp55tvjdQA1A7xszo5780bHLI1AD0Fre27SvjlcagSKA1sYQ3F2AWWOUTPl+gEcb+/iW958befysSn6EjDKA1sYQvMo8G8shUN0C3iv1hLZi20EFAK2BIKwqAFqL/Wyg3+a6WwkElQC8WvUhURYIKgJ4NRPC0VjbI1B/FdDT5yLN/saQK69EPpN9dbADgM8inuhtEVTeAla35XYAgLG2QwCA8bZCAIBrbYMAANfbAgEA7lUeAQDuVxoBAOZUFgEA5lUSAQDmVg4BAOZXCgEAYiqDAABxlUAAgNhmfKdhaACI7+oiLvnXMQDWdOerbUMDwLp6F3XpTSMAWNvZ4i6/YwgA6zta5JTbxQCQ0+dip90rCIC8Zr7/4HIAyC39LmEAmAcA8wBgHgDMA4B5ADAPAOYBwDwAmAcA8wBgHgDMA4B5ADAPAOYBwDwAmAcA8wBgHgDMA4B5ADAPAOYBwDwAmAcA8/4BrV9c1aHK48EAAAAASUVORK5CYII='
    $genDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $count   = $Rows.Count

    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine(@"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TextTrace Report</title>
  <style>
    :root { --mono: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
            --sans: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif; }
    body { font-family: var(--sans); font-size: 13px; line-height: 1.5; margin: 0; color: #1a1d22; background: #ffffff; }
    .wrap { max-width: 1200px; margin: 0 auto; padding: 24px; }

    .hd { display: flex; align-items: center; gap: 14px; margin: 0 0 18px; }
    .logo { width: 40px; height: 40px; flex: none; }
    h1 { font-family: var(--mono); font-size: 22px; font-weight: 700; margin: 0; color: #1a1d22; }
    h1 span { color: #f5a623; }
    .meta { font-family: var(--sans); color: #6b7280; font-size: 13px; margin: 3px 0 0; }
    .meta b { color: #1a1d22; font-weight: 700; }

    table { border-collapse: collapse; width: 100%; table-layout: fixed; }
    thead th {
      position: sticky; top: 0; background: #eef0f3; text-align: left; padding: 9px 10px;
      border-bottom: 2px solid #d7dbe0; font-family: var(--sans);
      font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #4b5563;
    }
    thead .filters th { position: sticky; top: 36px; background: #f7f8fa; padding: 6px 8px; border-bottom: 1px solid #e2e6ea; }
    input.f { width: 100%; box-sizing: border-box; border: 1px solid #cfd4da; border-radius: 5px; padding: 5px 7px;
              font-family: var(--sans); font-size: 12.5px; color: #1a1d22; outline: none; }
    input.f::placeholder { color: #9ca3af; }
    input.f:focus { border-color: #f5a623; box-shadow: 0 0 0 3px rgba(245,166,35,.14); }

    tbody td { padding: 7px 10px; border-bottom: 1px solid #edf0f2; vertical-align: top; font-family: var(--mono); font-size: 13px; }
    tbody tr:nth-child(odd)  { background: #ffffff; }
    tbody tr:nth-child(even) { background: #f5f6f8; }
    tbody tr:hover { background: #fff3d0; }

    td.idx, td.line { color: #9aa1ab; text-align: right; white-space: nowrap; }
    td.file { font-weight: 600; word-break: break-word; }
    td.type { color: #6b7280; word-break: break-word; }
    td.content { word-break: break-word; }
    td.content mark { background: #ffd23f; color: #1a1d22; font-weight: 400; border-radius: 2px; padding: 0 1px; }
    td.path { color: #6b7280; word-break: break-all; }

    .count { font-family: var(--sans); color: #6b7280; font-size: 12px; margin: 10px 2px 0; }
  </style>
</head>
<body>
  <div class="wrap">

    <div class="hd">
      <img class="logo" src="data:image/png;base64,$iconB64" alt="">
      <div>
        <h1>Text<span>Trace</span> Report</h1>
        <p class="meta"><span id="shown">$count</span> of <span id="total">$count</span> matches shown &middot; pattern: <b>$(E $Keyword)</b> &middot; scope: $(E $Scope) &middot; $(E $genDate)</p>
      </div>
    </div>

    <table>
      <colgroup>
        <col style="width:5%">
        <col style="width:19%">
        <col style="width:8%">
        <col style="width:9%">
        <col style="width:35%">
        <col style="width:24%">
      </colgroup>
      <thead>
        <tr>
          <th>Index</th><th>Filename</th><th>Type</th><th>LineNumber</th><th>Content</th><th>Path</th>
        </tr>
        <tr class="filters">
          <th><input class="f" data-col="0" placeholder="Filter Index"></th>
          <th><input class="f" data-col="1" placeholder="Filter Filename"></th>
          <th><input class="f" data-col="2" placeholder="Filter Type"></th>
          <th><input class="f" data-col="3" placeholder="Filter LineNumber"></th>
          <th><input class="f" data-col="4" placeholder="Filter Content"></th>
          <th><input class="f" data-col="5" placeholder="Filter Path"></th>
        </tr>
      </thead>
      <tbody>
"@)

    foreach ($r in $Rows) {
        [void]$sb.AppendLine('<tr>' +
            "<td class='idx'>$(E $r.Index)</td>" +
            "<td class='file'>$(E $r.FileName)</td>" +
            "<td class='type'>$(E $r.Kind)</td>" +
            "<td class='line'>$(E $r.LineNumber)</td>" +
            "<td class='content'>$(Hl $r.Line)</td>" +
            "<td class='path'>$(E $r.Path)</td>" +
            '</tr>')
    }

    [void]$sb.AppendLine(@"
      </tbody>
    </table>

    <p class="count" id="count">$count of $count rows</p>

  </div>

  <script>
    (function () {
      var inputs = document.querySelectorAll('input.f');
      var rows = Array.prototype.slice.call(document.querySelectorAll('tbody tr'));
      var countEl = document.getElementById('count');
      var shownEl = document.getElementById('shown');
      var total = rows.length;

      function apply() {
        var filters = [];
        inputs.forEach(function (inp) {
          var v = inp.value.trim().toLowerCase();
          if (v) filters.push([parseInt(inp.getAttribute('data-col'), 10), v]);
        });
        var shown = 0;
        rows.forEach(function (tr) {
          var ok = true;
          for (var i = 0; i < filters.length; i++) {
            var cell = tr.children[filters[i][0]];
            if (!cell || cell.textContent.toLowerCase().indexOf(filters[i][1]) === -1) { ok = false; break; }
          }
          tr.style.display = ok ? '' : 'none';
          if (ok) shown++;
        });
        countEl.textContent = shown + ' of ' + total + ' rows';
        if (shownEl) shownEl.textContent = shown;
      }

      inputs.forEach(function (inp) { inp.addEventListener('input', apply); });
    })();
  </script>
</body>
</html>
"@)

    return $sb.ToString()
}
