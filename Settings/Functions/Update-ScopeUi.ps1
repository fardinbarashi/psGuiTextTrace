function Update-ScopeUi {
    switch (Get-SelectedScope) {
        'Files' {
            $LblPath.Text     = 'Folder Path'
            $LblPathHint.Text = ''
            $BtnBrowse.Visibility = 'Visible'
            $BtnBrowse.Content = 'Open Folder'
            $FilePanel.Visibility = 'Visible'
            if ($TxtPath.Text -match '^(HK|Cert:)') { $TxtPath.Clear() }
        }
        'Registry' {
            $LblPath.Text     = 'Registry Path'
            $LblPathHint.Text = 'e.g. HKLM:\SOFTWARE or HKCU:\Software. Tick "Include subfolders" for a recursive search.'
            $BtnBrowse.Visibility = 'Visible'
            $BtnBrowse.Content = 'Open RegEdit'
            $FilePanel.Visibility = 'Collapsed'
            if ([string]::IsNullOrWhiteSpace($TxtPath.Text) -or ($TxtPath.Text -notmatch '^HK')) {
                $TxtPath.Text = 'HKCU:\Software'
            }
        }
        'Certificates' {
            $LblPath.Text     = 'Cert Store Path (optional)'
            $LblPathHint.Text = 'Leave empty to scan CurrentUser + LocalMachine, or e.g. Cert:\LocalMachine\My'
            $BtnBrowse.Visibility = 'Visible'
            $BtnBrowse.Content = 'Open Cert.mmc'
            $FilePanel.Visibility = 'Collapsed'
            if ($TxtPath.Text -match '^HK') { $TxtPath.Clear() }
        }
    }
}
