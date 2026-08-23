function Start-SearchJob {
    <#
        Runs the search on a background thread so the UI thread stays free to
        react to Stop instantly. The job cannot touch WPF controls, so it does
        two things only:
          - reports matches into $SharedQueue (a thread-safe ConcurrentQueue)
          - checks $CancelFlag between items and stops the moment it is set

        $CancelFlag is a [ref]-like single-element array shared with the UI
        thread. Stop sets element 0 to $true; the loop sees it on its next pass,
        which happens between individual Select-String matches - so a cancel
        lands mid-file, not only between files.
    #>
    param(
        [Parameter(Mandatory)] $Scope,
        [Parameter(Mandatory)] $PathText,
        [Parameter(Mandatory)] $Keyword,
        [bool] $Regex,
        [bool] $Case,
        [bool] $Recurse,
        [string[]] $FileTypes,
        [Parameter(Mandatory)] $SharedQueue,
        [Parameter(Mandatory)] $CancelFlag,
        [Parameter(Mandatory)] $Progress
    )

    Start-ThreadJob -ArgumentList $Scope,$PathText,$Keyword,$Regex,$Case,$Recurse,$FileTypes,$SharedQueue,$CancelFlag,$Progress -ScriptBlock {
        param($Scope,$PathText,$Keyword,$Regex,$Case,$Recurse,$FileTypes,$Queue,$Cancel,$Progress)

        function Test-Match {
            param($Text,$Keyword,$Regex,$Case)
            if ([string]::IsNullOrEmpty($Text)) { return $false }
            if ($Regex) {
                $opts = if ($Case) { [Text.RegularExpressions.RegexOptions]::None }
                        else       { [Text.RegularExpressions.RegexOptions]::IgnoreCase }
                try { return [Text.RegularExpressions.Regex]::IsMatch($Text,$Keyword,$opts) } catch { return $false }
            }
            $cmp = if ($Case) { [StringComparison]::Ordinal } else { [StringComparison]::OrdinalIgnoreCase }
            return ($Text.IndexOf($Keyword,$cmp) -ge 0)
        }

        function Emit {
            param($Kind,$Name,$LineNumber,$Line,$Path,$Thumbprint=$null,$StoreLocation=$null)
            $Queue.Enqueue([pscustomobject]@{
                Kind=$Kind; FileName=$Name; LineNumber=$LineNumber; Line=$Line
                Path=$Path; Thumbprint=$Thumbprint; StoreLocation=$StoreLocation
            })
        }

        try {
            switch ($Scope) {

                'Files' {
                    $files = @()
                    foreach ($type in $FileTypes) {
                        $a = @{ Path=$PathText; Filter=$type; File=$true; Force=$true; ErrorAction='SilentlyContinue' }
                        if ($Recurse) { $a.Recurse = $true }
                        $files += Get-ChildItem @a
                    }
                    $files = @($files | Sort-Object FullName -Unique)
                    $Progress['Total'] = $files.Count

                    $m = @{ Pattern=$Keyword }
                    if (-not $Regex) { $m.SimpleMatch = $true }
                    if ($Case)       { $m.CaseSensitive = $true }

                    $i = 0
                    foreach ($file in $files) {
                        if ($Cancel[0]) { break }
                        $i++; $Progress['Done'] = $i
                        try {
                            # Stream matches so cancel can land mid-file
                            Select-String -Path $file.FullName @m -ErrorAction SilentlyContinue | ForEach-Object {
                                if ($Cancel[0]) { return }
                                Emit -Kind 'File' -Name $file.Name -LineNumber $_.LineNumber -Line $_.Line -Path $file.FullName
                            }
                        } catch {}
                    }
                }

                'Registry' {
                    $keys = New-Object System.Collections.Generic.List[object]
                    try { $ri = Get-Item -Path $PathText -ErrorAction SilentlyContinue; if ($ri) { $keys.Add($ri) } } catch {}
                    $children = if ($Recurse) { Get-ChildItem -Path $PathText -Recurse -ErrorAction SilentlyContinue }
                                else          { Get-ChildItem -Path $PathText -ErrorAction SilentlyContinue }
                    foreach ($k in $children) { if ($k) { $keys.Add($k) } }
                    $Progress['Total'] = $keys.Count

                    $i = 0
                    foreach ($key in $keys) {
                        if ($Cancel[0]) { break }
                        $i++; $Progress['Done'] = $i
                        if (-not $key) { continue }
                        $keyName = [string]$key.Name

                        if (Test-Match $keyName $Keyword $Regex $Case) {
                            Emit -Kind 'Registry' -Name (Split-Path $keyName -Leaf) -LineNumber '(key)' -Line $keyName -Path $keyName
                        }
                        $props = $null
                        try { $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue } catch {}
                        if ($props) {
                            foreach ($p in $props.PSObject.Properties) {
                                if ($Cancel[0]) { break }
                                if ($p.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
                                $vt = if ($p.Value -is [Array]) { ($p.Value -join ', ') } else { [string]$p.Value }
                                if ((Test-Match $p.Name $Keyword $Regex $Case) -or (Test-Match $vt $Keyword $Regex $Case)) {
                                    Emit -Kind 'Registry' -Name $p.Name -LineNumber '(value)' -Line "$($p.Name) = $vt" -Path $keyName
                                }
                            }
                        }
                    }
                }

                'Certificates' {
                    $roots = if (-not [string]::IsNullOrWhiteSpace($PathText)) { @($PathText) }
                             else { @('Cert:\CurrentUser','Cert:\LocalMachine') }
                    $certs = New-Object System.Collections.Generic.List[object]
                    foreach ($root in $roots) {
                        try {
                            Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue |
                                Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509Certificate2] } |
                                ForEach-Object { $certs.Add($_) }
                        } catch {}
                    }
                    $Progress['Total'] = $certs.Count

                    $i = 0
                    foreach ($cert in $certs) {
                        if ($Cancel[0]) { break }
                        $i++; $Progress['Done'] = $i
                        $hay = @($cert.Subject,$cert.Issuer,$cert.Thumbprint,$cert.FriendlyName,$cert.SerialNumber | Where-Object { $_ }) -join ' | '
                        if (Test-Match $hay $Keyword $Regex $Case) {
                            $storeLoc = [string]($cert.PSParentPath -replace '^Microsoft\.PowerShell\.Security\\Certificate::','')
                            $certPath = [string]($cert.PSPath       -replace '^Microsoft\.PowerShell\.Security\\Certificate::','')
                            $name = if ($cert.FriendlyName) { $cert.FriendlyName } else { $cert.Subject }
                            $line = "Subject=$($cert.Subject); Issuer=$($cert.Issuer); Expires=$($cert.NotAfter.ToString('yyyy-MM-dd')); Thumbprint=$($cert.Thumbprint)"
                            Emit -Kind 'Certificate' -Name $name -LineNumber '(cert)' -Line $line -Path $certPath -Thumbprint $cert.Thumbprint -StoreLocation $storeLoc
                        }
                    }
                }
            }
        }
        finally {
            $Progress['Finished'] = $true
        }
    }
}
