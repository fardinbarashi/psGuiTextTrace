function Search-Registry {
    param($Root, $Keyword, [bool]$Regex, [bool]$Case, [bool]$Recurse)

    Set-UiStatus -Text 'Enumerating registry keys...' -Refresh
    $ProgressBar.IsIndeterminate = $true

    $keys = New-Object System.Collections.Generic.List[object]
    try {
        $rootItem = Get-Item -Path $Root -ErrorAction SilentlyContinue
        if ($rootItem) { $keys.Add($rootItem) }
    } catch {}

    $children = if ($Recurse) {
        Get-ChildItem -Path $Root -Recurse -ErrorAction SilentlyContinue
    } else {
        Get-ChildItem -Path $Root -ErrorAction SilentlyContinue
    }
    foreach ($k in $children) { if ($k) { $keys.Add($k) } }

    $ProgressBar.IsIndeterminate = $false
    $ProgressBar.Maximum = [Math]::Max(1, $keys.Count)
    $ProgressBar.Value = 0
    Set-UiStatus -Text "Found $($keys.Count) keys. Searching..." -Refresh

    $processed = 0
    foreach ($key in $keys) {
        $processed++
        $ProgressBar.Value = [Math]::Min($processed, $ProgressBar.Maximum)
        if (-not $key) { continue }

        $keyName = [string]$key.Name   # e.g. HKEY_LOCAL_MACHINE\SOFTWARE\...

        if (Test-KeywordMatch -Text $keyName -Keyword $Keyword -Regex $Regex -CaseSensitive $Case) {
            Add-Result -Kind 'Registry' -Name (Split-Path $keyName -Leaf) -LineNumber '(key)' -Line $keyName -Path $keyName
        }

        $props = $null
        try { $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue } catch {}

        if ($props) {
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
                $valData = $p.Value
                $valText = if ($valData -is [System.Array]) { ($valData -join ', ') } else { [string]$valData }

                if ((Test-KeywordMatch -Text $p.Name -Keyword $Keyword -Regex $Regex -CaseSensitive $Case) -or
                    (Test-KeywordMatch -Text $valText -Keyword $Keyword -Regex $Regex -CaseSensitive $Case)) {
                    Add-Result -Kind 'Registry' -Name $p.Name -LineNumber '(value)' -Line "$($p.Name) = $valText" -Path $keyName
                }
            }
        }

        if (($processed % 50) -eq 0) {
            $ResultCountText.Text = "$($Results.Count) match(es)"
            Set-UiStatus -Text "Searching registry... $processed / $($keys.Count)" -Refresh
        }
    }
    return $keys.Count
}
