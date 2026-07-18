function Search-Files {
    param($Folder, $Keyword, [bool]$Regex, [bool]$Case, [bool]$Recurse)

    $types = @(Get-SelectedFileTypes)
    $files = @()
    foreach ($type in $types) {
        $gciArgs = @{
            Path        = $Folder
            Filter      = $type
            File        = $true
            Force       = $true
            ErrorAction = 'SilentlyContinue'
        }
        if ($Recurse) { $gciArgs.Recurse = $true }
        $files += Get-ChildItem @gciArgs
    }
    $files = @($files | Sort-Object FullName -Unique)

    $ProgressBar.IsIndeterminate = $false
    $ProgressBar.Maximum = [Math]::Max(1, $files.Count)
    $ProgressBar.Value = 0
    Set-UiStatus -Text "Found $($files.Count) files. Searching..." -Refresh

    $matchArgs = @{ Pattern = $Keyword }
    if (-not $Regex) { $matchArgs.SimpleMatch = $true }
    if ($Case)       { $matchArgs.CaseSensitive = $true }

    $processed = 0
    foreach ($file in $files) {
        $processed++
        $ProgressBar.Value = [Math]::Min($processed, $ProgressBar.Maximum)

        $hits = $null
        try {
            $hits = Select-String -Path $file.FullName @matchArgs -ErrorAction SilentlyContinue
        }
        catch { continue }

        if ($hits) {
            foreach ($hit in $hits) {
                Add-Result -Kind 'File' -Name $file.Name -LineNumber $hit.LineNumber -Line $hit.Line -Path $file.FullName
            }
        }

        if (($processed % 40) -eq 0) {
            $ResultCountText.Text = "$($Results.Count) match(es)"
            Set-UiStatus -Text "Searching... $processed / $($files.Count) files" -Refresh
        }
    }
    return $files.Count
}
