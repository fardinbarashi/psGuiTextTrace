<#
System requirements
PSVersion 7.4.0

About Script :
Author : Fardin Barashi
Title : TextTrace
Description : A XAML-based PowerShell tool that searches files, the registry and
              certificate stores for a keyword or pattern, and exports matches
              to CSV, JSON or HTML.

Structure :
    TextTrace.ps1                    This file. Loads the UI, wires events, runs.
    Settings\UI\MainWindow.xaml      The whole window, as XAML.
    Settings\Functions\*.ps1         One function per file, dot-sourced below.

    Load order matters. The functions reach WPF controls like $ProgressBar by
    name, so they are dot-sourced AFTER the controls have been created - not at
    the top. Dot-sourcing only defines them; they are not called until a button
    is clicked, by which point every control exists.

Version : 1.3
Release day : 2026-06-08
Github Link : https://github.com/fardinbarashi/psGuiTextTrace

News :
2026-07-18
 - added a stop button
 - better code in the main script
#>


#------------------------------- Assemblies -------------------------------

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
try { Add-Type -AssemblyName System.Security } catch {}

# ThreadJob ships with PowerShell 7. On Windows PowerShell 5.1 install once with:
#   Install-Module ThreadJob -Scope CurrentUser
if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
    try { Import-Module ThreadJob -ErrorAction Stop }
    catch { throw 'Start-ThreadJob is not available. On PowerShell 5.1 run: Install-Module ThreadJob -Scope CurrentUser' }
}

#------------------------------- Paths -------------------------------

$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

$LogsFolder     = Join-Path $ScriptRoot 'Settings\Logs'
$ReportsFolder  = Join-Path $ScriptRoot 'Files\Reports'
$IconPath       = Join-Path $ScriptRoot 'Files\Img\logo\logo.ico'
$ReportFile     = Join-Path $ReportsFolder 'Report.csv'
$XamlPath       = Join-Path $ScriptRoot 'Settings\UI\MainWindow.xaml'
$FunctionFolder = Join-Path $ScriptRoot 'Settings\Functions'

foreach ($p in @($LogsFolder, $ReportsFolder)) {if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null}}

#------------------------------- Transcript -------------------------------

$ScriptName = $MyInvocation.MyCommand.Name
if (-not $ScriptName) { $ScriptName = 'TextTrace.ps1' }

$LogStamp       = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$TranscriptFile = Join-Path $LogsFolder "$ScriptName-$LogStamp.txt"
try { Start-Transcript -Path $TranscriptFile -Force | Out-Null } catch {}

#------------------------------- Load XAML from file -------------------------------

if (-not (Test-Path $XamlPath)) { throw "Cannot find the UI file: $XamlPath"}

[xml]$Xaml = Get-Content -Raw -Encoding UTF8 $XamlPath

$Reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [Windows.Markup.XamlReader]::Load($Reader)

if (Test-Path $IconPath) {
    try { $Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]$IconPath) } catch {}
}

#------------------------------- Controls -------------------------------

function Get-WpfControl {
    param([Parameter(Mandatory)] [string]$Name)
    return $Window.FindName($Name)
}

$TxtPath         = Get-WpfControl 'TxtPath'
$TxtKeyword      = Get-WpfControl 'TxtKeyword'
$TxtCustom       = Get-WpfControl 'TxtCustom'
$TypesList       = Get-WpfControl 'TypesList'
$ChkRecurse      = Get-WpfControl 'ChkRecurse'
$ChkCase         = Get-WpfControl 'ChkCase'
$ChkRegex        = Get-WpfControl 'ChkRegex'
$BtnBrowse       = Get-WpfControl 'BtnBrowse'
$BtnSearch       = Get-WpfControl 'BtnSearch'
$BtnStop         = Get-WpfControl 'BtnStop'
$BtnClear        = Get-WpfControl 'BtnClear'
$ResultsGrid     = Get-WpfControl 'ResultsGrid'
$ProgressBar     = Get-WpfControl 'ProgressBar'
$StatusText      = Get-WpfControl 'StatusText'
$StatsText       = Get-WpfControl 'StatsText'
$ResultCountText = Get-WpfControl 'ResultCountText'
$MenuOpenReports = Get-WpfControl 'MenuOpenReports'
$MenuExit        = Get-WpfControl 'MenuExit'
$MenuAbout       = Get-WpfControl 'MenuAbout'
$CmOpenFile      = Get-WpfControl 'CmOpenFile'
$CmOpenFolder    = Get-WpfControl 'CmOpenFolder'
$CmOpenNotepad   = Get-WpfControl 'CmOpenNotepad'
$CmCopyPath      = Get-WpfControl 'CmCopyPath'
$CmOpenReports   = Get-WpfControl 'CmOpenReports'
$ChkAllFileTypes = Get-WpfControl 'ChkAllFileTypes'
$RbScopeFiles    = Get-WpfControl 'RbScopeFiles'
$RbScopeRegistry = Get-WpfControl 'RbScopeRegistry'
$RbScopeCert     = Get-WpfControl 'RbScopeCert'
$LblPath         = Get-WpfControl 'LblPath'
$LblPathHint     = Get-WpfControl 'LblPathHint'
$FilePanel       = Get-WpfControl 'FilePanel'
$MenuExportCsv   = Get-WpfControl 'MenuExportCsv'
$MenuExportJson  = Get-WpfControl 'MenuExportJson'
$MenuExportHtml  = Get-WpfControl 'MenuExportHtml'
$CmOpenRegedit   = Get-WpfControl 'CmOpenRegedit'
$CmViewCert      = Get-WpfControl 'CmViewCert'

#------------------------------- Data -------------------------------

$Results = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$ResultsGrid.ItemsSource = $Results
$script:RowIndex = 0

$FileTypeList = @(
    '*.xml','*.txt','*.log','*.csv','*.json','*.ini','*.config',
    '*.html','*.htm','*.ps1','*.psm1','*.bat','*.cmd','*.md','*.yaml','*.yml','*.sql'
)

$script:IsUpdatingFileTypeChecks = $false

#------------------------------- Load functions -------------------------------

if (-not (Test-Path $FunctionFolder)) { throw "Function folder not found: $FunctionFolder" }

$functionFiles = Get-ChildItem -Path $FunctionFolder -Filter '*.ps1' -File
if (-not $functionFiles) { throw "No .ps1 files found in $FunctionFolder" }

foreach ($file in $functionFiles) {
    try   { . $file.FullName }
    catch { throw "Failed to load function file '$($file.Name)': $($_.Exception.Message)" }
}

#------------------------------- File-type checkboxes -------------------------------

foreach ($type in $FileTypeList) {
    $check = New-Object System.Windows.Controls.CheckBox
    $check.Content = $type
    $check.Margin = '2'
    if ($type -eq '*.xml') { $check.IsChecked = $true }

    $check.Add_Checked({
        if ($script:IsUpdatingFileTypeChecks) { return }
        $allChecked = $true
        foreach ($item in $TypesList.Items) {
            if ($item.IsChecked -ne $true) { $allChecked = $false; break }
        }
        $script:IsUpdatingFileTypeChecks = $true
        $ChkAllFileTypes.IsChecked = $allChecked
        $script:IsUpdatingFileTypeChecks = $false
    })

    $check.Add_Unchecked({
        if ($script:IsUpdatingFileTypeChecks) { return }
        $script:IsUpdatingFileTypeChecks = $true
        $ChkAllFileTypes.IsChecked = $false
        $script:IsUpdatingFileTypeChecks = $false
    })

    [void]$TypesList.Items.Add($check)
}

$ChkAllFileTypes.Add_Checked({
    if ($script:IsUpdatingFileTypeChecks) { return }
    $script:IsUpdatingFileTypeChecks = $true
    foreach ($item in $TypesList.Items) { $item.IsChecked = $true }
    $script:IsUpdatingFileTypeChecks = $false
})

$ChkAllFileTypes.Add_Unchecked({
    if ($script:IsUpdatingFileTypeChecks) { return }
    $script:IsUpdatingFileTypeChecks = $true
    foreach ($item in $TypesList.Items) { $item.IsChecked = $false }
    $script:IsUpdatingFileTypeChecks = $false
})

#------------------------------- Event handlers -------------------------------

$BtnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if (-not [string]::IsNullOrWhiteSpace($TxtPath.Text) -and (Test-Path $TxtPath.Text)) { $dialog.SelectedPath = $TxtPath.Text}
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $TxtPath.Text = $dialog.SelectedPath}
})

$BtnSearch.Add_Click({ Invoke-Search })

$BtnStop.Add_Click({ Stop-Search })

$BtnClear.Add_Click({
    if ($script:SearchJob) { Stop-Search }
    $Results.Clear()
    $TxtKeyword.Clear()
    $StatsText.Text = 'Cleared.'
    $ResultCountText.Text = '0 matches'
    $ProgressBar.Value = 0
    Set-UiStatus -Text 'Ready'
})

$TxtKeyword.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.Key -eq [System.Windows.Input.Key]::Enter) {
        $eventArgs.Handled = $true
        Invoke-Search
    }
})

$MenuOpenReports.Add_Click({ Open-ReportsFolder })
$CmOpenReports.Add_Click({ Open-ReportsFolder })

$MenuExportCsv.Add_Click({  Export-Results -Format 'CSV' })
$MenuExportJson.Add_Click({ Export-Results -Format 'JSON' })
$MenuExportHtml.Add_Click({ Export-Results -Format 'HTML' })

$RbScopeFiles.Add_Checked({ Update-ScopeUi })
$RbScopeRegistry.Add_Checked({ Update-ScopeUi })
$RbScopeCert.Add_Checked({ Update-ScopeUi })

$MenuExit.Add_Click({ $Window.Close() })

$MenuAbout.Add_Click({
    Show-Message -Message "TextTrace github link : https://github.com/fardinbarashi/psGuiTextTrace" -Title 'About' -Icon 'Information'
})

$CmOpenFile.Add_Click({ foreach ($row in Get-SelectedRows) { if (Test-Path $row.Path) { Start-Process -FilePath $row.Path }} })

$CmOpenFolder.Add_Click({ foreach ($row in Get-SelectedRows) { if (Test-Path $row.Path) { Start-Process explorer.exe "/select,`"$($row.Path)`"" }}})

$CmOpenNotepad.Add_Click({ foreach ($row in Get-SelectedRows) { if (Test-Path $row.Path) { Start-Process notepad.exe $row.Path }}})

$CmCopyPath.Add_Click({
    $paths = @(Get-SelectedRows | ForEach-Object { $_.Path })
    if ($paths.Count -gt 0) { [System.Windows.Clipboard]::SetText(($paths -join [Environment]::NewLine))}})

$CmOpenRegedit.Add_Click({
    $row = Get-SelectedRows | Where-Object { $_.Kind -eq 'Registry' } | Select-Object -First 1
    if (-not $row) {
        Show-Message -Message 'Select a registry result first.' -Title 'Open in Registry Editor' -Icon 'Warning'
        return
    }
    try {
        $lastKey = "Computer\$($row.Path)"
        $regeditKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit'
        if (-not (Test-Path $regeditKey)) { New-Item -Path $regeditKey -Force | Out-Null }
        Set-ItemProperty -Path $regeditKey -Name 'LastKey' -Value $lastKey -Force
    } catch {}
    Start-Process regedit.exe
})

$CmViewCert.Add_Click({
    $row = Get-SelectedRows | Where-Object { $_.Kind -eq 'Certificate' } | Select-Object -First 1
    if (-not $row) {
        Show-Message -Message 'Select a certificate result first.' -Title 'View Certificate' -Icon 'Warning'
        return
    }
    try {
        $cert = Get-Item -Path ("Cert:\" + $row.Path) -ErrorAction Stop
        [System.Security.Cryptography.X509Certificates.X509Certificate2UI]::DisplayCertificate($cert)
    }
    catch { Show-Message -Message "Could not open certificate: $($_.Exception.Message)`n`nTip: certmgr.msc shows the same stores (cert.mmc)." -Title 'View Certificate' -Icon 'Warning' }
})

# Ctrl+Q closes
$Window.Add_KeyDown({
    param($sender, $eventArgs)
    if (($eventArgs.Key -eq [System.Windows.Input.Key]::Q) -and
        (($eventArgs.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -eq [System.Windows.Input.ModifierKeys]::Control)) {
        $Window.Close()
    }
})

#------------------------------- Initialize and show -------------------------------

Update-ScopeUi

try {
    [void]$Window.ShowDialog()
}
finally {
    # Stop a running search cleanly if the window closes mid-scan
    if ($script:CancelFlag)  { $script:CancelFlag[0] = $true }
    if ($script:DrainTimer)  { try { $script:DrainTimer.Stop() } catch {} }
    if ($script:SearchJob)   { try { Remove-Job -Job $script:SearchJob -Force -ErrorAction SilentlyContinue } catch {} }
    try { Stop-Transcript | Out-Null } catch {}
}
