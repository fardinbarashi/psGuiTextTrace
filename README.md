# TextTrace

**TextTrace** is a modern Windows desktop tool for searching text and regex patterns across multiple file types.

It is built with **PowerShell**, **WPF**, and **XAML**, and is designed for fast inspection of logs, scripts, configuration files, documentation, SQL files, JSON, XML, and other text-based files.

---

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Supported File Types](#supported-file-types)
- [Regex Examples](#regex-examples)
- [Reports](#reports)

- [Roadmap](#roadmap)
- [License](#license)

---

## Features
- Search inside multiple text-based file formats
- Select one, many, or all predefined file types
- Add custom file extensions
- Plain text search
- Regular expression search
- Case-sensitive search option
- Recursive folder scanning
- Result table with file name, line number, preview, and full path
- Right-click context menu for result actions
- Report export
- Search statistics
- Transcript logging for troubleshooting

---

## Screenshots

Add screenshots here when available.


---

## Supported File Types

TextTrace includes these file patterns by default:

```text
*.xml
*.txt
*.log
*.csv
*.json
*.ini
*.config
*.html
*.htm
*.ps1
*.psm1
*.bat
*.cmd
*.md
*.yaml
*.yml
*.sql
```

You can also add custom file patterns in the application.

Example:

```text
*.cs,*.js,*.vbs,*.properties
```

---


## Result Actions

Right-click a result row to access available actions:

| Action | Description |
|---|---|
| Open File | Opens the matched file with the default application |
| Open Containing Folder | Opens File Explorer and selects the matched file |
| Open in Notepad | Opens the matched file in Notepad |
| Copy Path | Copies the full file path to the clipboard |
| Open Reports Folder | Opens the report output folder |

---

## Regex Examples

Enable **Use Regex** before using regex patterns.

Find the word `test` anywhere in a line:

```regex
test
```

Find the exact word `test`:

```regex
\btest\b
```

Find either `error` or `warning`:

```regex
error|warning
```

Find lines that start with `ERROR`:

```regex
^ERROR
```

Find an IPv4 address:

```regex
\b(?:\d{1,3}\.){3}\d{1,3}\b
```

Find PowerShell variables:

```regex
\$[A-Za-z_][A-Za-z0-9_]*
```

Find XML-like tags:

```regex
<[^>]+>
```

Find email addresses:

```regex
\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b
```

If **Case sensitive** is disabled, matching is case-insensitive.

---

## Reports

When matches are found, TextTrace exports the results to a CSV file.

Default location:

```text
Files\Reports\Report.csv
```

The report is saved using:

- UTF-8 encoding
- Semicolon delimiter
- No type information

Report columns:

| Column | Description |
|---|---|
| FileName | Name of the matched file |
| LineNumber | Line number where the match was found |
| Line | Full matching line |
| Path | Full path to the matched file |

---


TextTrace creates transcript logs for troubleshooting.
TextTrace automatically creates missing `Logs` and `Files\Reports` folders.

---

## Troubleshooting



### Regex search fails

Make sure the pattern is valid .NET regular expression syntax.

## Performance Notes

TextTrace works best with text-based files. Very large folders or very large files may take longer to scan.


**TextTrace**  
A modern multi-file text and regex search tool for Windows.
