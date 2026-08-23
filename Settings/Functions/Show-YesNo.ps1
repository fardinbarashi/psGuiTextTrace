function Show-YesNo {
    param([string]$Message, [string]$Title = 'TextTrace')
    return ([System.Windows.MessageBox]::Show(
        $Window, $Message, $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    ) -eq [System.Windows.MessageBoxResult]::Yes)
}
