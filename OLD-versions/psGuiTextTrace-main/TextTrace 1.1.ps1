<#
System requirements
PSVersion 5.x.x, prefer 7.x.x

About Script :
Author : Fardin Barashi
Title : TextTrace 
Description : TextTrace is a XAML-based PowerShell script designed to search for specific keywords or patterns within files across a selected directory and its subdirectories. 
It provides an intuitive graphical interface for users to specify search criteria, including file types, case sensitivity, and regex options. 
The script efficiently scans through the files, displays the results in a structured format, and allows users to easily access the matched files or their containing folders.

 - Support for multiple file types
 - Regex / case-sensitive / include subfolders options
 - Shows file name, line number, matched text and full path
 - Context menu: open file, open folder, Notepad, copy path
 - Exports matches to Files\Reports\Report.csv, json or html


Version : 1.1
Release day : 2026-06-08
Github Link : https://github.com/fardinbarashi
News :
Added support for searching within the Windows Registry and Certificate Stores, allowing users to find specific keys, values, or certificates based on their search criteria.
Added support for exporting search results to JSON and HTML formats, in addition to CSV, providing users with more options for analyzing and sharing their findings.

#>

# --- Assemblies ---
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
try { Add-Type -AssemblyName System.Security } catch {}

# --- Paths ---
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$LogsFolder    = Join-Path $ScriptRoot 'Logs'
$ReportsFolder = Join-Path $ScriptRoot 'Files\Reports'
$IconPath      = Join-Path $ScriptRoot 'Files\Img\logo\logo.ico'
$ReportFile    = Join-Path $ReportsFolder 'Report.csv'

foreach ($p in @($LogsFolder, $ReportsFolder)) {
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
    }
}

# --- Transcript ---
$ScriptName = $MyInvocation.MyCommand.Name
if (-not $ScriptName) { $ScriptName = 'FilePatternLookup-WPF.ps1' }

$LogStamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$TranscriptFile = Join-Path $LogsFolder "$ScriptName-$LogStamp.txt"
try { Start-Transcript -Path $TranscriptFile -Force | Out-Null } catch {}

# --- XAML ---
[xml]$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="TextTrace - V 1.1"
    Width="1280"
    Height="980"
    MinWidth="980"
    MinHeight="640"
    WindowStartupLocation="CenterScreen"
    Background="#F5F7FA"
    FontFamily="Segoe UI"
    FontSize="13">

    <Window.Resources>
        <SolidColorBrush x:Key="AccentBrush" Color="#0078D7"/>
        <SolidColorBrush x:Key="AccentHoverBrush" Color="#0068BD"/>
        <SolidColorBrush x:Key="PanelBrush" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="BorderBrushSoft" Color="#DCE0E6"/>
        <SolidColorBrush x:Key="TextPrimaryBrush" Color="#202020"/>
        <SolidColorBrush x:Key="TextSecondaryBrush" Color="#606060"/>
        <SolidColorBrush x:Key="MutedBrush" Color="#EEF1F5"/>

        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="{StaticResource TextPrimaryBrush}"/>
        </Style>

        <Style x:Key="SectionLabel" TargetType="TextBlock">
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Foreground" Value="{StaticResource TextSecondaryBrush}"/>
            <Setter Property="Margin" Value="0,14,0,6"/>
        </Style>

        <Style TargetType="TextBox">
            <Setter Property="Height" Value="30"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrushSoft}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Background" Value="White"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>

        <Style TargetType="CheckBox">
            <Setter Property="Margin" Value="0,4,0,4"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimaryBrush}"/>
        </Style>

        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="Height" Value="34"/>
            <Setter Property="Padding" Value="14,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimaryBrush}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrushSoft}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="8">
                            <ContentPresenter
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"
                                Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#F5F7FA"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#E8EDF3"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.55"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="{StaticResource AccentBrush}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="{StaticResource AccentBrush}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="8">
                            <ContentPresenter
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"
                                Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="{StaticResource AccentHoverBrush}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#005A9E"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.55"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="{StaticResource PanelBrush}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrushSoft}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="12"/>
            <Setter Property="Padding" Value="16"/>
        </Style>

        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="White"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrushSoft}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="GridLinesVisibility" Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#EEF1F5"/>
            <Setter Property="RowBackground" Value="White"/>
            <Setter Property="AlternatingRowBackground" Value="#F8F9FB"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="CanUserAddRows" Value="False"/>
            <Setter Property="CanUserDeleteRows" Value="False"/>
            <Setter Property="IsReadOnly" Value="True"/>
            <Setter Property="SelectionMode" Value="Extended"/>
            <Setter Property="SelectionUnit" Value="FullRow"/>
            <Setter Property="AutoGenerateColumns" Value="False"/>
        </Style>
    </Window.Resources>

    <DockPanel LastChildFill="True">
        <Menu DockPanel.Dock="Top" Background="White">
            <MenuItem Header="_File">
                <MenuItem Header="Open Reports Folder" Name="MenuOpenReports"/>
                <Separator/>
                <MenuItem Header="E_xit" Name="MenuExit" InputGestureText="Ctrl+Q"/>
            </MenuItem>
            <MenuItem Header="_Export">
                <MenuItem Header="Export to CSV..."  Name="MenuExportCsv"/>
                <MenuItem Header="Export to JSON..." Name="MenuExportJson"/>
                <MenuItem Header="Export to HTML..." Name="MenuExportHtml"/>
            </MenuItem>
            <MenuItem Header="_Help">
                <MenuItem Header="About" Name="MenuAbout"/>
            </MenuItem>
        </Menu>

        <StatusBar DockPanel.Dock="Bottom" Background="White">
            <StatusBarItem>
                <TextBlock Name="StatusText" Text="Ready"/>
            </StatusBarItem>
        </StatusBar>

        <Grid Margin="12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="310"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Sidebar -->
            <Border Grid.Column="0" Style="{StaticResource Card}">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel>
                        <TextBlock Text="Search" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,6"/>

                        <TextBlock Text="Search Scope" Style="{StaticResource SectionLabel}"/>
                        <StackPanel>
                            <RadioButton Name="RbScopeFiles"    GroupName="Scope" Content="Files" IsChecked="True" Margin="0,2,0,2"/>
                            <RadioButton Name="RbScopeRegistry" GroupName="Scope" Content="Registry (regedit)" Margin="0,2,0,2"/>
                            <RadioButton Name="RbScopeCert"     GroupName="Scope" Content="Certificate store (cert.mmc)" Margin="0,2,0,2"/>
                        </StackPanel>

                        <TextBlock Name="LblPath" Text="Folder Path" Style="{StaticResource SectionLabel}"/>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="8"/>
                                <ColumnDefinition Width="86"/>
                            </Grid.ColumnDefinitions>
                            <TextBox Grid.Column="0" Name="TxtPath"/>
                            <Button Grid.Column="2" Name="BtnBrowse" Content="Browse..." Style="{StaticResource ModernButton}"/>
                        </Grid>
                        <TextBlock Name="LblPathHint" Text="" Foreground="{StaticResource TextSecondaryBrush}" FontSize="11" Margin="0,4,0,0" TextWrapping="Wrap"/>

                        <StackPanel Name="FilePanel">
                            <TextBlock Text="File Types" Style="{StaticResource SectionLabel}"/>
                            <CheckBox Name="ChkAllFileTypes" Content="All file types" Margin="0,2,0,6"/>
                            <Border BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1" CornerRadius="8" Height="154">
                                <ListBox Name="TypesList" BorderThickness="0" Padding="6"/>
                            </Border>

                            <TextBlock Text="Custom File Types" Style="{StaticResource SectionLabel}"/>
                            <TextBlock Text="Comma-separated, for example: *.cs,*.vbs" Foreground="{StaticResource TextSecondaryBrush}" FontSize="11" Margin="0,0,0,6"/>
                            <TextBox Name="TxtCustom"/>
                        </StackPanel>

                        <TextBlock Text="Search Pattern" Style="{StaticResource SectionLabel}"/>
                        <TextBox Name="TxtKeyword"/>

                        <StackPanel Margin="0,14,0,0">
                            <CheckBox Name="ChkRecurse" Content="Include subfolders" IsChecked="True"/>
                            <CheckBox Name="ChkCase" Content="Case sensitive"/>
                            <CheckBox Name="ChkRegex" Content="Use Regex"/>
                        </StackPanel>

                        <Grid Margin="0,18,0,0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Button Grid.Column="0" Name="BtnSearch" Content="Search" Style="{StaticResource PrimaryButton}"/>
                            <Button Grid.Column="2" Name="BtnClear" Content="Clear" Style="{StaticResource ModernButton}"/>
                        </Grid>

                        <Border Background="#F8F9FB" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,18,0,0">
                            <StackPanel>
                                <TextBlock Text="Statistics" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                <TextBlock Name="StatsText" Text="No search performed yet." Foreground="{StaticResource TextSecondaryBrush}" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </Border>

            <!-- Results -->
            <Border Grid.Column="2" Style="{StaticResource Card}">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <DockPanel Grid.Row="0" Margin="0,0,0,12">
                        <TextBlock Text="Results" FontSize="22" FontWeight="SemiBold" DockPanel.Dock="Left"/>
                        <TextBlock Name="ResultCountText" Text="0 matches" Foreground="{StaticResource TextSecondaryBrush}" HorizontalAlignment="Right" DockPanel.Dock="Right" Margin="12,6,0,0"/>
                    </DockPanel>

                    <DataGrid Name="ResultsGrid" Grid.Row="1" AlternationCount="2">
                        <DataGrid.ContextMenu>
                            <ContextMenu>
                                <MenuItem Header="Open File" Name="CmOpenFile"/>
                                <MenuItem Header="Open Containing Folder" Name="CmOpenFolder"/>
                                <MenuItem Header="Open in Notepad" Name="CmOpenNotepad"/>
                                <Separator/>
                                <MenuItem Header="Open in Registry Editor" Name="CmOpenRegedit"/>
                                <MenuItem Header="View Certificate" Name="CmViewCert"/>
                                <Separator/>
                                <MenuItem Header="Copy Path" Name="CmCopyPath"/>
                                <Separator/>
                                <MenuItem Header="Open Reports Folder" Name="CmOpenReports"/>
                            </ContextMenu>
                        </DataGrid.ContextMenu>

                        <DataGrid.Columns>
                            <DataGridTextColumn Header="#" Binding="{Binding Index}" Width="58"/>
                            <DataGridTextColumn Header="Kind" Binding="{Binding Kind}" Width="80"/>
                            <DataGridTextColumn Header="Name / Source" Binding="{Binding FileName}" Width="200"/>
                            <DataGridTextColumn Header="Line / Value" Binding="{Binding LineNumber}" Width="84"/>
                            <DataGridTextColumn Header="Match Preview" Binding="{Binding Preview}" Width="*"/>
                            <DataGridTextColumn Header="Path / Location" Binding="{Binding Path}" Width="320"/>
                        </DataGrid.Columns>
                    </DataGrid>

                    <ProgressBar Name="ProgressBar" Grid.Row="2" Height="18" Margin="0,12,0,0" Minimum="0" Maximum="1" Value="0"/>
                </Grid>
            </Border>
        </Grid>
    </DockPanel>
</Window>
"@

# --- Load XAML ---
$Reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [Windows.Markup.XamlReader]::Load($Reader)

if (Test-Path $IconPath) {
    try { $Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]$IconPath) } catch {}
}

function Get-WpfControl {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    return $Window.FindName($Name)
}

# --- Controls ---
$TxtPath         = Get-WpfControl 'TxtPath'
$TxtKeyword      = Get-WpfControl 'TxtKeyword'
$TxtCustom       = Get-WpfControl 'TxtCustom'
$TypesList       = Get-WpfControl 'TypesList'
$ChkRecurse      = Get-WpfControl 'ChkRecurse'
$ChkCase         = Get-WpfControl 'ChkCase'
$ChkRegex        = Get-WpfControl 'ChkRegex'
$BtnBrowse       = Get-WpfControl 'BtnBrowse'
$BtnSearch       = Get-WpfControl 'BtnSearch'
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

# --- Data ---
$Results = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$ResultsGrid.ItemsSource = $Results
$script:RowIndex = 0

$FileTypeList = @(
    '*.xml','*.txt','*.log','*.csv','*.json','*.ini','*.config',
    '*.html','*.htm','*.ps1','*.psm1','*.bat','*.cmd','*.md','*.yaml','*.yml','*.sql'
)

$script:IsUpdatingFileTypeChecks = $false

foreach ($type in $FileTypeList) {
    $check = New-Object System.Windows.Controls.CheckBox
    $check.Content = $type
    $check.Margin = '2'
    if ($type -eq '*.xml') { $check.IsChecked = $true }

    $check.Add_Checked({
        if ($script:IsUpdatingFileTypeChecks) { return }
        $allChecked = $true
        foreach ($item in $TypesList.Items) {
            if ($item.IsChecked -ne $true) {
                $allChecked = $false
                break
            }
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
    foreach ($item in $TypesList.Items) {
        $item.IsChecked = $true
    }
    $script:IsUpdatingFileTypeChecks = $false
})

$ChkAllFileTypes.Add_Unchecked({
    if ($script:IsUpdatingFileTypeChecks) { return }
    $script:IsUpdatingFileTypeChecks = $true
    foreach ($item in $TypesList.Items) {
        $item.IsChecked = $false
    }
    $script:IsUpdatingFileTypeChecks = $false
})

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

function Show-Message {
    param(
        [string]$Message,
        [string]$Title = 'File Pattern Lookup',
        [string]$Icon = 'Information'
    )

    [System.Windows.MessageBox]::Show(
        $Window,
        $Message,
        $Title,
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::$Icon
    ) | Out-Null
}

function Get-SelectedFileTypes {
    $types = @()

    foreach ($item in $TypesList.Items) {
        if ($item.IsChecked -eq $true) {
            $types += [string]$item.Content
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($TxtCustom.Text)) {
        $types += $TxtCustom.Text.Split(',') |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    return $types | Sort-Object -Unique
}

function Get-SelectedRows {
    $rows = @()
    foreach ($item in $ResultsGrid.SelectedItems) {
        if ($null -ne $item) { $rows += $item }
    }
    return $rows
}

function Open-ReportsFolder {
    if (Test-Path $ReportsFolder) {
        Start-Process explorer.exe $ReportsFolder
    }
}

function Show-YesNo {
    param([string]$Message, [string]$Title = 'TextTrace')
    return ([System.Windows.MessageBox]::Show(
        $Window, $Message, $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    ) -eq [System.Windows.MessageBoxResult]::Yes)
}

function Get-Preview {
    param($Text)
    if ($null -eq $Text) { return '' }
    $t = ([string]$Text).Trim()
    if ($t.Length -gt 220) { $t = $t.Substring(0, 220) + '...' }
    return $t
}

function Test-KeywordMatch {
    param(
        [string]$Text,
        [string]$Keyword,
        [bool]$Regex,
        [bool]$CaseSensitive
    )
    if ([string]::IsNullOrEmpty($Text)) { return $false }

    if ($Regex) {
        $opts = if ($CaseSensitive) {
            [System.Text.RegularExpressions.RegexOptions]::None
        } else {
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        }
        try { return [System.Text.RegularExpressions.Regex]::IsMatch($Text, $Keyword, $opts) }
        catch { return $false }
    }

    $cmp = if ($CaseSensitive) { [System.StringComparison]::Ordinal } else { [System.StringComparison]::OrdinalIgnoreCase }
    return ($Text.IndexOf($Keyword, $cmp) -ge 0)
}

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

function Get-SelectedScope {
    if ($RbScopeRegistry.IsChecked -eq $true) { return 'Registry' }
    if ($RbScopeCert.IsChecked -eq $true)     { return 'Certificates' }
    return 'Files'
}

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

function Search-Files {
    param($Folder, $Keyword, [bool]$Regex, [bool]$Case, [bool]$Recurse)

    $types = @(Get-SelectedFileTypes)
    $files = @()
    foreach ($type in $types) {
        $gciArgs = @{
            Path        = $Folder
            Filter      = $type
            File        = $true
            Force       = $true
            ErrorAction = 'SilentlyContinue'
        }
        if ($Recurse) { $gciArgs.Recurse = $true }
        $files += Get-ChildItem @gciArgs
    }
    $files = @($files | Sort-Object FullName -Unique)

    $ProgressBar.IsIndeterminate = $false
    $ProgressBar.Maximum = [Math]::Max(1, $files.Count)
    $ProgressBar.Value = 0
    Set-UiStatus -Text "Found $($files.Count) files. Searching..." -Refresh

    $matchArgs = @{ Pattern = $Keyword }
    if (-not $Regex) { $matchArgs.SimpleMatch = $true }
    if ($Case)       { $matchArgs.CaseSensitive = $true }

    $processed = 0
    foreach ($file in $files) {
        $processed++
        $ProgressBar.Value = [Math]::Min($processed, $ProgressBar.Maximum)

        $hits = $null
        try {
            $hits = Select-String -Path $file.FullName @matchArgs -ErrorAction SilentlyContinue
        }
        catch { continue }

        if ($hits) {
            foreach ($hit in $hits) {
                Add-Result -Kind 'File' -Name $file.Name -LineNumber $hit.LineNumber -Line $hit.Line -Path $file.FullName
            }
        }

        if (($processed % 40) -eq 0) {
            $ResultCountText.Text = "$($Results.Count) match(es)"
            Set-UiStatus -Text "Searching... $processed / $($files.Count) files" -Refresh
        }
    }
    return $files.Count
}

function Search-Registry {
    param($Root, $Keyword, [bool]$Regex, [bool]$Case, [bool]$Recurse)

    Set-UiStatus -Text 'Enumerating registry keys...' -Refresh
    $ProgressBar.IsIndeterminate = $true

    $keys = New-Object System.Collections.Generic.List[object]
    try {
        $rootItem = Get-Item -Path $Root -ErrorAction SilentlyContinue
        if ($rootItem) { $keys.Add($rootItem) }
    } catch {}

    $children = if ($Recurse) {
        Get-ChildItem -Path $Root -Recurse -ErrorAction SilentlyContinue
    } else {
        Get-ChildItem -Path $Root -ErrorAction SilentlyContinue
    }
    foreach ($k in $children) { if ($k) { $keys.Add($k) } }

    $ProgressBar.IsIndeterminate = $false
    $ProgressBar.Maximum = [Math]::Max(1, $keys.Count)
    $ProgressBar.Value = 0
    Set-UiStatus -Text "Found $($keys.Count) keys. Searching..." -Refresh

    $processed = 0
    foreach ($key in $keys) {
        $processed++
        $ProgressBar.Value = [Math]::Min($processed, $ProgressBar.Maximum)
        if (-not $key) { continue }

        $keyName = [string]$key.Name   # e.g. HKEY_LOCAL_MACHINE\SOFTWARE\...

        if (Test-KeywordMatch -Text $keyName -Keyword $Keyword -Regex $Regex -CaseSensitive $Case) {
            Add-Result -Kind 'Registry' -Name (Split-Path $keyName -Leaf) -LineNumber '(key)' -Line $keyName -Path $keyName
        }

        $props = $null
        try { $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue } catch {}

        if ($props) {
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
                $valData = $p.Value
                $valText = if ($valData -is [System.Array]) { ($valData -join ', ') } else { [string]$valData }

                if ((Test-KeywordMatch -Text $p.Name -Keyword $Keyword -Regex $Regex -CaseSensitive $Case) -or
                    (Test-KeywordMatch -Text $valText -Keyword $Keyword -Regex $Regex -CaseSensitive $Case)) {
                    Add-Result -Kind 'Registry' -Name $p.Name -LineNumber '(value)' -Line "$($p.Name) = $valText" -Path $keyName
                }
            }
        }

        if (($processed % 50) -eq 0) {
            $ResultCountText.Text = "$($Results.Count) match(es)"
            Set-UiStatus -Text "Searching registry... $processed / $($keys.Count)" -Refresh
        }
    }
    return $keys.Count
}

function Search-Certificates {
    param($StorePath, $Keyword, [bool]$Regex, [bool]$Case)

    $roots = if (-not [string]::IsNullOrWhiteSpace($StorePath)) {
        @($StorePath)
    } else {
        @('Cert:\CurrentUser', 'Cert:\LocalMachine')
    }

    Set-UiStatus -Text 'Enumerating certificates...' -Refresh
    $ProgressBar.IsIndeterminate = $true

    $certs = New-Object System.Collections.Generic.List[object]
    foreach ($root in $roots) {
        try {
            $found = Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue |
                     Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509Certificate2] }
            foreach ($c in $found) { $certs.Add($c) }
        } catch {}
    }

    $ProgressBar.IsIndeterminate = $false
    $ProgressBar.Maximum = [Math]::Max(1, $certs.Count)
    $ProgressBar.Value = 0
    Set-UiStatus -Text "Found $($certs.Count) certificates. Searching..." -Refresh

    $processed = 0
    foreach ($cert in $certs) {
        $processed++
        $ProgressBar.Value = [Math]::Min($processed, $ProgressBar.Maximum)

        $fields = @(
            $cert.Subject
            $cert.Issuer
            $cert.Thumbprint
            $cert.FriendlyName
            $cert.SerialNumber
        )
        $hay = ($fields | Where-Object { $_ }) -join ' | '

        if (Test-KeywordMatch -Text $hay -Keyword $Keyword -Regex $Regex -CaseSensitive $Case) {
            $storeLoc = [string]($cert.PSParentPath -replace '^Microsoft\.PowerShell\.Security\\Certificate::', '')
            $certPath = [string]($cert.PSPath       -replace '^Microsoft\.PowerShell\.Security\\Certificate::', '')
            $name = if ($cert.FriendlyName) { $cert.FriendlyName } else { $cert.Subject }
            $line = "Subject=$($cert.Subject); Issuer=$($cert.Issuer); Expires=$($cert.NotAfter.ToString('yyyy-MM-dd')); Thumbprint=$($cert.Thumbprint)"
            Add-Result -Kind 'Certificate' -Name $name -LineNumber '(cert)' -Line $line -Path $certPath -Thumbprint $cert.Thumbprint -StoreLocation $storeLoc
        }

        if (($processed % 25) -eq 0) {
            $ResultCountText.Text = "$($Results.Count) match(es)"
            Set-UiStatus -Text "Searching certificates... $processed / $($certs.Count)" -Refresh
        }
    }
    return $certs.Count
}

function ConvertTo-ResultHtml {
    param($Rows, [string]$Scope, [string]$Keyword)

    function E { param($s) [System.Net.WebUtility]::HtmlEncode([string]$s) }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">')
    [void]$sb.AppendLine('<title>TextTrace Report</title>')
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#202020;background:#F5F7FA;}')
    [void]$sb.AppendLine('h1{font-size:22px;margin:0 0 4px;}')
    [void]$sb.AppendLine('.meta{color:#606060;font-size:13px;margin-bottom:16px;}')
    [void]$sb.AppendLine('table{border-collapse:collapse;width:100%;background:#fff;border:1px solid #DCE0E6;border-radius:8px;overflow:hidden;}')
    [void]$sb.AppendLine('th{background:#0078D7;color:#fff;text-align:left;padding:8px 10px;font-size:13px;}')
    [void]$sb.AppendLine('td{padding:7px 10px;border-top:1px solid #EEF1F5;font-size:13px;vertical-align:top;word-break:break-word;}')
    [void]$sb.AppendLine('tr:nth-child(even) td{background:#F8F9FB;}')
    [void]$sb.AppendLine('</style></head><body>')
    [void]$sb.AppendLine("<h1>TextTrace Report</h1>")
    [void]$sb.AppendLine("<div class='meta'>Scope: <b>$(E $Scope)</b> &middot; Pattern: <b>$(E $Keyword)</b> &middot; Matches: <b>$($Rows.Count)</b> &middot; Generated: $(E (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))</div>")
    [void]$sb.AppendLine('<table><thead><tr><th>#</th><th>Kind</th><th>Name / Source</th><th>Line / Value</th><th>Match</th><th>Path / Location</th></tr></thead><tbody>')

    foreach ($r in $Rows) {
        [void]$sb.AppendLine('<tr>' +
            "<td>$(E $r.Index)</td>" +
            "<td>$(E $r.Kind)</td>" +
            "<td>$(E $r.FileName)</td>" +
            "<td>$(E $r.LineNumber)</td>" +
            "<td>$(E $r.Line)</td>" +
            "<td>$(E $r.Path)</td>" +
            '</tr>')
    }

    [void]$sb.AppendLine('</tbody></table></body></html>')
    return $sb.ToString()
}

function Export-Results {
    param([ValidateSet('CSV','JSON','HTML')][string]$Format)

    if ($Results.Count -eq 0) {
        Show-Message -Message 'No results to export. Run a search first.' -Title 'Export' -Icon 'Warning'
        return
    }

    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    if (Test-Path $ReportsFolder) { $dlg.InitialDirectory = $ReportsFolder }
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

    switch ($Format) {
        'CSV'  { $dlg.Filter = 'CSV file (*.csv)|*.csv';   $dlg.FileName = "TextTrace_$stamp.csv" }
        'JSON' { $dlg.Filter = 'JSON file (*.json)|*.json'; $dlg.FileName = "TextTrace_$stamp.json" }
        'HTML' { $dlg.Filter = 'HTML file (*.html)|*.html'; $dlg.FileName = "TextTrace_$stamp.html" }
    }

    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $path = $dlg.FileName

    $data = $Results | Select-Object Index, Kind, FileName, LineNumber, Line, Path

    try {
        switch ($Format) {
            'CSV'  { $data | Export-Csv -Path $path -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force }
            'JSON' { ($data | ConvertTo-Json -Depth 4) | Set-Content -Path $path -Encoding UTF8 }
            'HTML' { (ConvertTo-ResultHtml -Rows $data -Scope (Get-SelectedScope) -Keyword $TxtKeyword.Text) | Set-Content -Path $path -Encoding UTF8 }
        }
        Set-UiStatus -Text "Exported $($Results.Count) row(s) to $Format"
        if (Show-YesNo -Message "Export complete:`n$path`n`nOpen the file now?" -Title 'Export') {
            Start-Process $path
        }
    }
    catch {
        Show-Message -Message "Export failed: $($_.Exception.Message)" -Title 'Export Error' -Icon 'Error'
    }
}

function Invoke-Search {
    $keyword = $TxtKeyword.Text
    if ([string]::IsNullOrWhiteSpace($keyword)) {
        Show-Message -Message 'Please enter a search pattern.' -Title 'Missing Search Pattern' -Icon 'Warning'
        return
    }

    $scope    = Get-SelectedScope
    $pathText = $TxtPath.Text.Trim()

    # --- Scope-specific validation ---
    switch ($scope) {
        'Files' {
            if ([string]::IsNullOrWhiteSpace($pathText) -or -not (Test-Path $pathText)) {
                Show-Message -Message 'Please choose a valid folder first.' -Title 'Missing Folder' -Icon 'Warning'
                return
            }
            if ((@(Get-SelectedFileTypes)).Count -eq 0) {
                Show-Message -Message 'Select at least one file type.' -Title 'No File Type' -Icon 'Warning'
                return
            }
        }
        'Registry' {
            if ([string]::IsNullOrWhiteSpace($pathText)) {
                Show-Message -Message 'Enter a registry path, e.g. HKLM:\SOFTWARE.' -Title 'Missing Registry Path' -Icon 'Warning'
                return
            }
            if (-not (Test-Path $pathText)) {
                Show-Message -Message "Registry path not found:`n$pathText`n`nUse a PowerShell drive form such as HKLM:\SOFTWARE or HKCU:\Software." -Title 'Invalid Registry Path' -Icon 'Warning'
                return
            }
        }
        'Certificates' {
            if (-not [string]::IsNullOrWhiteSpace($pathText) -and -not (Test-Path $pathText)) {
                Show-Message -Message "Cert store path not found:`n$pathText`n`nLeave empty to scan all, or use e.g. Cert:\LocalMachine\My." -Title 'Invalid Cert Path' -Icon 'Warning'
                return
            }
        }
    }

    $Results.Clear()
    $script:RowIndex = 0
    $ResultCountText.Text = '0 matches'
    $StatsText.Text = 'Search running...'
    $ProgressBar.IsIndeterminate = $true
    Set-UiStatus -Text 'Preparing search...' -Refresh

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $regex   = ($ChkRegex.IsChecked   -eq $true)
        $case    = ($ChkCase.IsChecked    -eq $true)
        $recurse = ($ChkRecurse.IsChecked -eq $true)

        $scanned = 0
        switch ($scope) {
            'Files'        { $scanned = Search-Files        -Folder $pathText -Keyword $keyword -Regex $regex -Case $case -Recurse $recurse }
            'Registry'     { $scanned = Search-Registry     -Root   $pathText -Keyword $keyword -Regex $regex -Case $case -Recurse $recurse }
            'Certificates' { $scanned = Search-Certificates -StorePath $pathText -Keyword $keyword -Regex $regex -Case $case }
        }

        # --- Auto-export current results to Report.csv (as before) ---
        if ($Results.Count -gt 0) {
            $Results | Select-Object Index, Kind, FileName, LineNumber, Line, Path |
                Export-Csv -Path $ReportFile -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force
        }
        elseif (Test-Path $ReportFile) {
            Remove-Item $ReportFile -Force
        }

        $sw.Stop()
        $uniqueSources = @($Results | Select-Object -ExpandProperty FileName -Unique).Count
        $scannedLabel = switch ($scope) {
            'Files'        { 'Files scanned' }
            'Registry'     { 'Keys scanned' }
            'Certificates' { 'Certificates scanned' }
        }

        $StatsText.Text = @(
            "Scope: $scope"
            "$scannedLabel`: $scanned"
            "Matches found: $($Results.Count)"
            "Distinct sources: $uniqueSources"
            "Elapsed: $([Math]::Round($sw.Elapsed.TotalSeconds, 2)) s"
            ''
            "Report: $(if (Test-Path $ReportFile) { 'Saved to Report.csv' } else { 'No matches' })"
            'Use the Export menu for JSON / HTML.'
        ) -join [Environment]::NewLine

        $ResultCountText.Text = "$($Results.Count) match(es)"
        Set-UiStatus -Text "Done - $($Results.Count) match(es) in $([Math]::Round($sw.Elapsed.TotalSeconds, 2)) s"
    }
    catch {
        Show-Message -Message "Error: $($_.Exception.Message)" -Title 'Search Error' -Icon 'Error'
        Set-UiStatus -Text 'Error during search'
    }
    finally {
        $ProgressBar.IsIndeterminate = $false
        $ProgressBar.Value = 0
    }
}

# --- Event handlers ---
$BtnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog

    if (-not [string]::IsNullOrWhiteSpace($TxtPath.Text) -and (Test-Path $TxtPath.Text)) {
        $dialog.SelectedPath = $TxtPath.Text
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtPath.Text = $dialog.SelectedPath
    }
})

$BtnSearch.Add_Click({ Invoke-Search })

$BtnClear.Add_Click({
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
    Show-Message -Message "Text-Trace github link : https://github.com/fardinbarashi/psGuiTextTrace" -Title 'About' -Icon 'Information'
})

$CmOpenFile.Add_Click({
    foreach ($row in Get-SelectedRows) {
        if (Test-Path $row.Path) {
            Start-Process -FilePath $row.Path
        }
    }
})

$CmOpenFolder.Add_Click({
    foreach ($row in Get-SelectedRows) {
        if (Test-Path $row.Path) {
            Start-Process explorer.exe "/select,`"$($row.Path)`""
        }
    }
})

$CmOpenNotepad.Add_Click({
    foreach ($row in Get-SelectedRows) {
        if (Test-Path $row.Path) {
            Start-Process notepad.exe $row.Path
        }
    }
})

$CmCopyPath.Add_Click({
    $paths = @(Get-SelectedRows | ForEach-Object { $_.Path })
    if ($paths.Count -gt 0) {
        [System.Windows.Clipboard]::SetText(($paths -join [Environment]::NewLine))
    }
})

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
    catch {
        Show-Message -Message "Could not open certificate: $($_.Exception.Message)`n`nTip: certmgr.msc shows the same stores (cert.mmc)." -Title 'View Certificate' -Icon 'Warning'
    }
})

# Ctrl+Q
$Window.Add_KeyDown({
    param($sender, $eventArgs)

    if (($eventArgs.Key -eq [System.Windows.Input.Key]::Q) -and
        (($eventArgs.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -eq [System.Windows.Input.ModifierKeys]::Control)) {
        $Window.Close()
    }
})

# --- Initialize scope UI ---
Update-ScopeUi

# --- Show window ---
try {
    [void]$Window.ShowDialog()
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
