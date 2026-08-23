function Set-UiStatus {
    param(
        [string]$Text,
        [switch]$Refresh
    )
    $StatusText.Text = $Text
    if ($Refresh) {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [Action]{}
        )
    }
}
