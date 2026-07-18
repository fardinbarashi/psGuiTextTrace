function Get-SelectedFileTypes {
    $types = @()

    foreach ($item in $TypesList.Items) {
        if ($item.IsChecked -eq $true) {
            $types += [string]$item.Content
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($TxtCustom.Text)) {
        $types += $TxtCustom.Text.Split(',') |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    return $types | Sort-Object -Unique
}
