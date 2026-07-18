function Export-Results {
    param([ValidateSet('CSV','JSON','HTML')][string]$Format)

    if ($Results.Count -eq 0) {
        Show-Message -Message 'No results to export. Run a search first.' -Title 'Export' -Icon 'Warning'
        return
    }

    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    if (Test-Path $ReportsFolder) { $dlg.InitialDirectory = $ReportsFolder }
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

    switch ($Format) {
        'CSV'  { $dlg.Filter = 'CSV file (*.csv)|*.csv';   $dlg.FileName = "TextTrace_$stamp.csv" }
        'JSON' { $dlg.Filter = 'JSON file (*.json)|*.json'; $dlg.FileName = "TextTrace_$stamp.json" }
        'HTML' { $dlg.Filter = 'HTML file (*.html)|*.html'; $dlg.FileName = "TextTrace_$stamp.html" }
    }

    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $path = $dlg.FileName

    $data = $Results | Select-Object Index, Kind, FileName, LineNumber, Line, Path

    try {
        switch ($Format) {
            'CSV'  { $data | Export-Csv -Path $path -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force }
            'JSON' { ($data | ConvertTo-Json -Depth 4) | Set-Content -Path $path -Encoding UTF8 }
            'HTML' { (ConvertTo-ResultHtml -Rows $data -Scope (Get-SelectedScope) -Keyword $TxtKeyword.Text) | Set-Content -Path $path -Encoding UTF8 }
        }
        Set-UiStatus -Text "Exported $($Results.Count) row(s) to $Format"
        if (Show-YesNo -Message "Export complete:`n$path`n`nOpen the file now?" -Title 'Export') {
            Start-Process $path
        }
    }
    catch {
        Show-Message -Message "Export failed: $($_.Exception.Message)" -Title 'Export Error' -Icon 'Error'
    }
}
