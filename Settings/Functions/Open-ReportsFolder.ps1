function Open-ReportsFolder {
    if (Test-Path $ReportsFolder) {
        Start-Process explorer.exe $ReportsFolder
    }
}
