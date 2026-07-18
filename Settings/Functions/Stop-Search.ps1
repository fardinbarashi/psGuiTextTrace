function Stop-Search {
    # Flip the shared flag. The worker checks it between items - between
    # individual matches within a file - so the stop is effectively instant.
    # The drain timer notices Finished shortly after and calls Complete-Search.
    if ($script:CancelFlag) {
        $script:CancelFlag[0] = $true
        Set-UiStatus -Text 'Stopping...'
        $BtnStop.IsEnabled = $false
    }
}
