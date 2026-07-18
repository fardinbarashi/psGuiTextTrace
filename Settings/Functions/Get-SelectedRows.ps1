function Get-SelectedRows {
    $rows = @()
    foreach ($item in $ResultsGrid.SelectedItems) {
        if ($null -ne $item) { $rows += $item }
    }
    return $rows
}
