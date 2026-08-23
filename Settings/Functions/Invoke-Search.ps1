function Invoke-Search {
    <#
        Starts the search on a background thread and drains its results into the
        grid from a DispatcherTimer on the UI thread. Because the heavy work is
        off the UI thread, Stop is instant: it sets the shared cancel flag, and
        the worker sees it on its next item - which, for files, is between
        individual Select-String matches, so a cancel lands mid-file.
    #>
    $keyword = $TxtKeyword.Text
    if ([string]::IsNullOrWhiteSpace($keyword)) {
        Show-Message -Message 'Please enter a search pattern.' -Title 'Missing Search Pattern' -Icon 'Warning'
        return
    }

    $scope    = Get-SelectedScope
    $pathText = $TxtPath.Text.Trim()

    # --- Scope-specific validation ---
    switch ($scope) {
        'Files' {
            if ([string]::IsNullOrWhiteSpace($pathText) -or -not (Test-Path $pathText)) {
                Show-Message -Message 'Please choose a valid folder first.' -Title 'Missing Folder' -Icon 'Warning'; return
            }
            if ((@(Get-SelectedFileTypes)).Count -eq 0) {
                Show-Message -Message 'Select at least one file type.' -Title 'No File Type' -Icon 'Warning'; return
            }
        }
        'Registry' {
            if ([string]::IsNullOrWhiteSpace($pathText)) {
                Show-Message -Message 'Enter a registry path, e.g. HKLM:\SOFTWARE.' -Title 'Missing Registry Path' -Icon 'Warning'; return
            }
            if (-not (Test-Path $pathText)) {
                Show-Message -Message "Registry path not found:`n$pathText" -Title 'Invalid Registry Path' -Icon 'Warning'; return
            }
        }
        'Certificates' {
            if (-not [string]::IsNullOrWhiteSpace($pathText) -and -not (Test-Path $pathText)) {
                Show-Message -Message "Cert store path not found:`n$pathText" -Title 'Invalid Cert Path' -Icon 'Warning'; return
            }
        }
    }

    # --- Reset UI ---
    $Results.Clear()
    $script:RowIndex = 0
    $ResultCountText.Text = '0 matches'
    $StatsText.Text = 'Search running...'
    $ProgressBar.IsIndeterminate = $true
    $ProgressBar.Value = 0
    Set-UiStatus -Text 'Starting search...'

    $BtnStop.IsEnabled   = $true
    $BtnSearch.IsEnabled = $false

    # --- Shared state between UI thread and worker ---
    # ConcurrentQueue: worker enqueues matches, timer dequeues them.
    # Cancel: single-element array so both threads see the same slot.
    # Progress: synchronized hashtable for Done / Total / Finished.
    $script:SearchQueue  = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
    $script:CancelFlag   = [bool[]]@($false)
    $script:Progress     = [hashtable]::Synchronized(@{ Done = 0; Total = 0; Finished = $false })
    $script:SearchScope  = $scope
    $script:SearchSw     = [System.Diagnostics.Stopwatch]::StartNew()

    $regex   = ($ChkRegex.IsChecked   -eq $true)
    $case    = ($ChkCase.IsChecked    -eq $true)
    $recurse = ($ChkRecurse.IsChecked -eq $true)
    $types   = @(Get-SelectedFileTypes)

    $script:SearchJob = Start-SearchJob `
        -Scope       $scope `
        -PathText    $pathText `
        -Keyword     $keyword `
        -Regex       $regex `
        -Case        $case `
        -Recurse     $recurse `
        -FileTypes   $types `
        -SharedQueue $script:SearchQueue `
        -CancelFlag  $script:CancelFlag `
        -Progress    $script:Progress

    # --- Drain timer on the UI thread ---
    $script:DrainTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:DrainTimer.Interval = [TimeSpan]::FromMilliseconds(120)

    $script:DrainTimer.Add_Tick({
        # Pull whatever the worker has produced since last tick
        $item = $null
        $drained = 0
        while ($script:SearchQueue.TryDequeue([ref]$item)) {
            $script:RowIndex++
            $Results.Add([pscustomobject]@{
                Index         = $script:RowIndex
                Kind          = $item.Kind
                FileName      = $item.FileName
                LineNumber    = $item.LineNumber
                Preview       = (Get-Preview $item.Line)
                Line          = $item.Line
                Path          = $item.Path
                Thumbprint    = $item.Thumbprint
                StoreLocation = $item.StoreLocation
            })
            $drained++
            if ($drained -ge 200) { break }   # keep the UI responsive on big bursts
        }

        $done  = $script:Progress['Done']
        $total = $script:Progress['Total']
        if ($total -gt 0) {
            $ProgressBar.IsIndeterminate = $false
            $ProgressBar.Maximum = $total
            $ProgressBar.Value   = [Math]::Min($done, $total)
        }
        $ResultCountText.Text = "$($Results.Count) match(es)"
        if (-not $script:CancelFlag[0]) {
            Set-UiStatus -Text "Searching... $done / $total"
        }

        # Finished when the worker flagged done AND the queue is empty
        if ($script:Progress['Finished'] -and $script:SearchQueue.IsEmpty) {
            $script:DrainTimer.Stop()
            Complete-Search
        }
    })

    $script:DrainTimer.Start()
}
