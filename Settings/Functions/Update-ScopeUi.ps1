function Update-ScopeUi {
    switch (Get-SelectedScope) {
        'Files' {
            $LblPath.Text     = 'Folder Path'
            $LblPathHint.Text = ''
            $BtnBrowse.IsEnabled = $true
            $FilePanel.IsEnabled = $true
            if ($TxtPath.Text -match '^(HK|Cert:)') { $TxtPath.Clear() }
        }
        'Registry' {
            $LblPath.Text     = 'Registry Path'
            $LblPathHint.Text = 'e.g. HKLM:\SOFTWARE or HKCU:\Software. Tick "Include subfolders" for a recursive search.'
            $BtnBrowse.IsEnabled = $false
            $FilePanel.IsEnabled = $false
            if ([string]::IsNullOrWhiteSpace($TxtPath.Text) -or ($TxtPath.Text -notmatch '^HK')) {
                $TxtPath.Text = 'HKCU:\Software'
            }
        }
        'Certificates' {
            $LblPath.Text     = 'Cert Store Path (optional)'
            $LblPathHint.Text = 'Leave empty to scan CurrentUser + LocalMachine, or e.g. Cert:\LocalMachine\My'
            $BtnBrowse.IsEnabled = $false
            $FilePanel.IsEnabled = $false
            if ($TxtPath.Text -match '^HK') { $TxtPath.Clear() }
        }
    }
}
