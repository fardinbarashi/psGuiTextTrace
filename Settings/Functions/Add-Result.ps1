function Add-Result {
    param(
        [string]$Kind,
        [string]$Name,
        $LineNumber,
        $Line,
        [string]$Path,
        [string]$Thumbprint = $null,
        [string]$StoreLocation = $null
    )
    $script:RowIndex++
    $Results.Add([pscustomobject]@{
        Index         = $script:RowIndex
        Kind          = $Kind
        FileName      = $Name
        LineNumber    = $LineNumber
        Preview       = (Get-Preview $Line)
        Line          = $Line
        Path          = $Path
        Thumbprint    = $Thumbprint
        StoreLocation = $StoreLocation
    })
}
