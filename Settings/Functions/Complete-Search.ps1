function Complete-Search {
    <#
        Called on the UI thread once the worker has finished and the queue is
        drained. Writes the auto-export CSV, fills in statistics, resets the
        buttons, and cleans up the job.
    #>
    $script:SearchSw.Stop()

    # Auto-export to Report.csv, as the original did
    if ($Results.Count -gt 0) {
        $Results | Select-Object Index, Kind, FileName, LineNumber, Line, Path |
            Export-Csv -Path $ReportFile -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force
    }
    elseif (Test-Path $ReportFile) {
        Remove-Item $ReportFile -Force
    }

    $cancelled = $script:CancelFlag[0]
    $done      = $script:Progress['Done']
    $total     = $script:Progress['Total']

    $uniqueSources = @($Results | Select-Object -ExpandProperty FileName -Unique).Count
    $scannedLabel  = switch ($script:SearchScope) {
        'Files'        { 'Files scanned' }
        'Registry'     { 'Keys scanned' }
        'Certificates' { 'Certificates scanned' }
    }

    $StatsText.Text = @(
        "Scope: $($script:SearchScope)"
        "$scannedLabel`: $done / $total"
        "Matches found: $($Results.Count)"
        "Distinct sources: $uniqueSources"
        "Elapsed: $([Math]::Round($script:SearchSw.Elapsed.TotalSeconds, 2)) s"
        ''
        $(if ($cancelled) { 'STOPPED by user.' } else { 'Completed.' })
        $(if (Test-Path $ReportFile) { 'Saved to Report.csv' } else { 'No matches' })
        'Use the Export menu for JSON / HTML.'
    ) -join [Environment]::NewLine

    $ResultCountText.Text = "$($Results.Count) match(es)"
    $ProgressBar.IsIndeterminate = $false
    $ProgressBar.Value = 0

    $BtnStop.IsEnabled   = $false
    $BtnSearch.IsEnabled = $true

    $status = if ($cancelled) {
        "Stopped - $($Results.Count) match(es) before cancel"
    } else {
        "Done - $($Results.Count) match(es) in $([Math]::Round($script:SearchSw.Elapsed.TotalSeconds, 2)) s"
    }
    Set-UiStatus -Text $status

    # Clean up the finished job
    if ($script:SearchJob) {
        try { Remove-Job -Job $script:SearchJob -Force -ErrorAction SilentlyContinue } catch {}
        $script:SearchJob = $null
    }
}
