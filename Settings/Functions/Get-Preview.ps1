function Get-Preview {
    param($Text)
    if ($null -eq $Text) { return '' }
    $t = ([string]$Text).Trim()
    if ($t.Length -gt 220) { $t = $t.Substring(0, 220) + '...' }
    return $t
}
