function ConvertTo-ResultHtml {
    param($Rows, [string]$Scope, [string]$Keyword)

    function E { param($s) [System.Net.WebUtility]::HtmlEncode([string]$s) }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">')
    [void]$sb.AppendLine('<title>TextTrace Report</title>')
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#202020;background:#F5F7FA;}')
    [void]$sb.AppendLine('h1{font-size:22px;margin:0 0 4px;}')
    [void]$sb.AppendLine('.meta{color:#606060;font-size:13px;margin-bottom:16px;}')
    [void]$sb.AppendLine('table{border-collapse:collapse;width:100%;background:#fff;border:1px solid #DCE0E6;border-radius:8px;overflow:hidden;}')
    [void]$sb.AppendLine('th{background:#0078D7;color:#fff;text-align:left;padding:8px 10px;font-size:13px;}')
    [void]$sb.AppendLine('td{padding:7px 10px;border-top:1px solid #EEF1F5;font-size:13px;vertical-align:top;word-break:break-word;}')
    [void]$sb.AppendLine('tr:nth-child(even) td{background:#F8F9FB;}')
    [void]$sb.AppendLine('</style></head><body>')
    [void]$sb.AppendLine("<h1>TextTrace Report</h1>")
    [void]$sb.AppendLine("<div class='meta'>Scope: <b>$(E $Scope)</b> &middot; Pattern: <b>$(E $Keyword)</b> &middot; Matches: <b>$($Rows.Count)</b> &middot; Generated: $(E (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))</div>")
    [void]$sb.AppendLine('<table><thead><tr><th>#</th><th>Kind</th><th>Name / Source</th><th>Line / Value</th><th>Match</th><th>Path / Location</th></tr></thead><tbody>')

    foreach ($r in $Rows) {
        [void]$sb.AppendLine('<tr>' +
            "<td>$(E $r.Index)</td>" +
            "<td>$(E $r.Kind)</td>" +
            "<td>$(E $r.FileName)</td>" +
            "<td>$(E $r.LineNumber)</td>" +
            "<td>$(E $r.Line)</td>" +
            "<td>$(E $r.Path)</td>" +
            '</tr>')
    }

    [void]$sb.AppendLine('</tbody></table></body></html>')
    return $sb.ToString()
}
