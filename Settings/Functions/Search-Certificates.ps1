function Search-Certificates {
    param($StorePath, $Keyword, [bool]$Regex, [bool]$Case)

    $roots = if (-not [string]::IsNullOrWhiteSpace($StorePath)) {
        @($StorePath)
    } else {
        @('Cert:\CurrentUser', 'Cert:\LocalMachine')
    }

    Set-UiStatus -Text 'Enumerating certificates...' -Refresh
    $ProgressBar.IsIndeterminate = $true

    $certs = New-Object System.Collections.Generic.List[object]
    foreach ($root in $roots) {
        try {
            $found = Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue |
                     Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509Certificate2] }
            foreach ($c in $found) { $certs.Add($c) }
        } catch {}
    }

    $ProgressBar.IsIndeterminate = $false
    $ProgressBar.Maximum = [Math]::Max(1, $certs.Count)
    $ProgressBar.Value = 0
    Set-UiStatus -Text "Found $($certs.Count) certificates. Searching..." -Refresh

    $processed = 0
    foreach ($cert in $certs) {
        $processed++
        $ProgressBar.Value = [Math]::Min($processed, $ProgressBar.Maximum)

        $fields = @(
            $cert.Subject
            $cert.Issuer
            $cert.Thumbprint
            $cert.FriendlyName
            $cert.SerialNumber
        )
        $hay = ($fields | Where-Object { $_ }) -join ' | '

        if (Test-KeywordMatch -Text $hay -Keyword $Keyword -Regex $Regex -CaseSensitive $Case) {
            $storeLoc = [string]($cert.PSParentPath -replace '^Microsoft\.PowerShell\.Security\\Certificate::', '')
            $certPath = [string]($cert.PSPath       -replace '^Microsoft\.PowerShell\.Security\\Certificate::', '')
            $name = if ($cert.FriendlyName) { $cert.FriendlyName } else { $cert.Subject }
            $line = "Subject=$($cert.Subject); Issuer=$($cert.Issuer); Expires=$($cert.NotAfter.ToString('yyyy-MM-dd')); Thumbprint=$($cert.Thumbprint)"
            Add-Result -Kind 'Certificate' -Name $name -LineNumber '(cert)' -Line $line -Path $certPath -Thumbprint $cert.Thumbprint -StoreLocation $storeLoc
        }

        if (($processed % 25) -eq 0) {
            $ResultCountText.Text = "$($Results.Count) match(es)"
            Set-UiStatus -Text "Searching certificates... $processed / $($certs.Count)" -Refresh
        }
    }
    return $certs.Count
}
