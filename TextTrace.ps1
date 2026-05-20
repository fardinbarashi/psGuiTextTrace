<#
System requirements
PSVersion 5.x.x, prefer 7.x.x

About Script :
Author : Fardin Barashi
Title : TextTrace 
Description : TextTrace is a WPF/XAML-based PowerShell script designed to search for specific keywords or patterns within files across a selected directory and its subdirectories. 
It provides an intuitive graphical interface for users to specify search criteria, including file types, case sensitivity, and regex options. 
The script efficiently scans through the files, displays the results in a structured format, and allows users to easily access the matched files or their containing folders.

 - Support for multiple file types
 - Regex / case-sensitive / include subfolders options
 - Shows file name, line number, matched text and full path
 - Context menu: open file, open folder, Notepad, copy path
 - Exports matches to Files\Reports\Report.csv


Version : 1.0
Release day : 2026-05-19
Github Link : https://github.com/fardinbarashi
News :

#>

Set-StrictMode -Version Latest

# --- Assemblies ---
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms

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
    Title="TextTrace - V 1.0"
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

                        <TextBlock Text="Folder Path" Style="{StaticResource SectionLabel}"/>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="8"/>
                                <ColumnDefinition Width="86"/>
                            </Grid.ColumnDefinitions>
                            <TextBox Grid.Column="0" Name="TxtPath"/>
                            <Button Grid.Column="2" Name="BtnBrowse" Content="Browse..." Style="{StaticResource ModernButton}"/>
                        </Grid>

                        <TextBlock Text="File Types" Style="{StaticResource SectionLabel}"/>
                        <CheckBox Name="ChkAllFileTypes" Content="All file types" Margin="0,2,0,6"/>
                        <Border BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1" CornerRadius="8" Height="154">
                            <ListBox Name="TypesList" BorderThickness="0" Padding="6"/>
                        </Border>

                        <TextBlock Text="Custom File Types" Style="{StaticResource SectionLabel}"/>
                        <TextBlock Text="Comma-separated, for example: *.cs,*.vbs" Foreground="{StaticResource TextSecondaryBrush}" FontSize="11" Margin="0,0,0,6"/>
                        <TextBox Name="TxtCustom"/>

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
                                <MenuItem Header="Copy Path" Name="CmCopyPath"/>
                                <Separator/>
                                <MenuItem Header="Open Reports Folder" Name="CmOpenReports"/>
                            </ContextMenu>
                        </DataGrid.ContextMenu>

                        <DataGrid.Columns>
                            <DataGridTextColumn Header="#" Binding="{Binding Index}" Width="58"/>
                            <DataGridTextColumn Header="File Name" Binding="{Binding FileName}" Width="220"/>
                            <DataGridTextColumn Header="Line" Binding="{Binding LineNumber}" Width="70"/>
                            <DataGridTextColumn Header="Match Preview" Binding="{Binding Preview}" Width="*"/>
                            <DataGridTextColumn Header="Full Path" Binding="{Binding Path}" Width="340"/>
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

# --- Data ---
$Results = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$ResultsGrid.ItemsSource = $Results

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

function Invoke-Search {
    $folder = $TxtPath.Text.Trim()
    $keyword = $TxtKeyword.Text

    if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path $folder)) {
        Show-Message -Message 'Please choose a valid folder first.' -Title 'Missing Folder' -Icon 'Warning'
        return
    }

    if ([string]::IsNullOrWhiteSpace($keyword)) {
        Show-Message -Message 'Please enter a search pattern.' -Title 'Missing Search Pattern' -Icon 'Warning'
        return
    }

    $types = @(Get-SelectedFileTypes)
    if ($types.Count -eq 0) {
        Show-Message -Message 'Select at least one file type.' -Title 'No File Type' -Icon 'Warning'
        return
    }

    $Results.Clear()
    $ResultCountText.Text = '0 matches'
    $StatsText.Text = 'Search running...'
    $ProgressBar.IsIndeterminate = $true
    Set-UiStatus -Text 'Listing files...' -Refresh

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $files = @()

        foreach ($type in $types) {
            $gciArgs = @{
                Path        = $folder
                Filter      = $type
                File        = $true
                Force       = $true
                ErrorAction = 'SilentlyContinue'
            }

            if ($ChkRecurse.IsChecked -eq $true) {
                $gciArgs.Recurse = $true
            }

            $files += Get-ChildItem @gciArgs
        }

        $files = @($files | Sort-Object FullName -Unique)

        $ProgressBar.IsIndeterminate = $false
        $ProgressBar.Maximum = [Math]::Max(1, $files.Count)
        $ProgressBar.Value = 0

        Set-UiStatus -Text "Found $($files.Count) files. Searching..." -Refresh

        $matchArgs = @{ Pattern = $keyword }
        if ($ChkRegex.IsChecked -ne $true) { $matchArgs.SimpleMatch = $true }
        if ($ChkCase.IsChecked -eq $true)  { $matchArgs.CaseSensitive = $true }

        $allMatches = New-Object System.Collections.Generic.List[object]
        $rowIndex = 0
        $processed = 0

        foreach ($file in $files) {
            $processed++
            $ProgressBar.Value = [Math]::Min($processed, $ProgressBar.Maximum)

            $hits = $null
            try {
                $hits = Select-String -Path $file.FullName @matchArgs -ErrorAction SilentlyContinue
            }
            catch {
                # Skip files that cannot be read.
                continue
            }

            if ($hits) {
                foreach ($hit in $hits) {
                    $rowIndex++

                    $preview = ''
                    if ($null -ne $hit.Line) {
                        $preview = $hit.Line.Trim()
                        if ($preview.Length -gt 220) {
                            $preview = $preview.Substring(0, 220) + '...'
                        }
                    }

                    $record = [pscustomobject]@{
                        Index      = $rowIndex
                        FileName   = $file.Name
                        LineNumber = $hit.LineNumber
                        Preview    = $preview
                        Line       = $hit.Line
                        Path       = $file.FullName
                    }

                    $Results.Add($record)
                    $allMatches.Add([pscustomobject]@{
                        FileName   = $file.Name
                        LineNumber = $hit.LineNumber
                        Line       = $hit.Line
                        Path       = $file.FullName
                    }) | Out-Null
                }
            }

            if (($processed % 40) -eq 0) {
                $ResultCountText.Text = "$($Results.Count) match(es)"
                Set-UiStatus -Text "Searching... $processed / $($files.Count) files" -Refresh
            }
        }

        if ($allMatches.Count -gt 0) {
            $allMatches | Export-Csv -Path $ReportFile -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force
        }
        elseif (Test-Path $ReportFile) {
            Remove-Item $ReportFile -Force
        }

        $sw.Stop()
        $uniqueFiles = @($allMatches | Select-Object -ExpandProperty FileName -Unique).Count

        $StatsText.Text = @(
            "Files scanned: $($files.Count)"
            "Matches found: $($allMatches.Count)"
            "Files with matches: $uniqueFiles"
            "Elapsed: $([Math]::Round($sw.Elapsed.TotalSeconds, 2)) s"
            ''
            "Report: $(if (Test-Path $ReportFile) { 'Saved to Report.csv' } else { 'No matches' })"
        ) -join [Environment]::NewLine

        $ResultCountText.Text = "$($allMatches.Count) match(es)"
        Set-UiStatus -Text "Done - $($allMatches.Count) match(es) in $([Math]::Round($sw.Elapsed.TotalSeconds, 2)) s"
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

$MenuExit.Add_Click({ $Window.Close() })

$MenuAbout.Add_Click({
    Show-Message -Message "Text-Trace github link : https://github.com/Text-Trace" -Title 'About' -Icon 'Information'
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

# Ctrl+Q
$Window.Add_KeyDown({
    param($sender, $eventArgs)

    if (($eventArgs.Key -eq [System.Windows.Input.Key]::Q) -and
        (($eventArgs.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -eq [System.Windows.Input.ModifierKeys]::Control)) {
        $Window.Close()
    }
})

# --- Show window ---
try {
    [void]$Window.ShowDialog()
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
