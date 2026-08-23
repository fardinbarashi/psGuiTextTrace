function Get-SelectedScope {
    if ($RbScopeRegistry.IsChecked -eq $true) { return 'Registry' }
    if ($RbScopeCert.IsChecked -eq $true)     { return 'Certificates' }
    return 'Files'
}
