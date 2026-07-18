function Test-KeywordMatch {
    param(
        [string]$Text,
        [string]$Keyword,
        [bool]$Regex,
        [bool]$CaseSensitive
    )
    if ([string]::IsNullOrEmpty($Text)) { return $false }

    if ($Regex) {
        $opts = if ($CaseSensitive) {
            [System.Text.RegularExpressions.RegexOptions]::None
        } else {
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        }
        try { return [System.Text.RegularExpressions.Regex]::IsMatch($Text, $Keyword, $opts) }
        catch { return $false }
    }

    $cmp = if ($CaseSensitive) { [System.StringComparison]::Ordinal } else { [System.StringComparison]::OrdinalIgnoreCase }
    return ($Text.IndexOf($Keyword, $cmp) -ge 0)
}
