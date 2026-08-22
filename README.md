# TextTrace

![](githubRepoContentDeleteIfYouWant/IMG/texttracelogo.png)

**TextTrace** is a modern Windows desktop tool for searching text and regex patterns across multiple file types. Built with **PowerShell** and **XAML**, it is designed for fast inspection of logs, scripts, configuration files, documentation, SQL, JSON, XML, and other text-based files.

---

## Table of Contents
- [What's new](#whats-new)
- [Requirements](#requirements)
- [Features](#features)
- [Usage & screenshots](#usage--screenshots)
- [Regex examples](#regex-examples)
- [Performance notes](#performance-notes)
- [Roadmap](#roadmap)

---

## What's new

| Version | Changes |
|---------|---------|
| 1.3 | Requires PowerShell 7.4.0 or later (Core); **Stop** button added. |
| 1.2 | Export search results to **JSON** and **HTML**, in addition to CSV. |
| 1.1 | Search the **Windows Registry** and **Certificate stores** for keys, values, or certificates. |

---

## Requirements

| Requirement | Detail |
|-------------|--------|
| PowerShell | 7.4.0 or later (Core) |
| OS | Windows |

---

## Features
| Feature | Detail |
|---------|--------|
| Search scope | Files, Windows Registry, or Certificate store |
| File formats | Search inside multiple text-based file formats |
| File types | Select one, many, or all predefined types, or add custom extensions |
| Search modes | Plain text or regular expression |
| Options | Case-sensitive matching and recursive folder scanning |
| Results | Table with file name, line number, preview, and full path, plus a right-click context menu (see below) |
| Export & logging | Report export (CSV / JSON / HTML), search statistics, and transcript logging |

**Right-click a result row** for these actions:

| Action | Description |
|--------|-------------|
| Open File | Opens the matched file with the default application |
| Open Containing Folder | Opens File Explorer and selects the matched file |
| Open in Notepad | Opens the matched file in Notepad |
| Open in Registry Editor | (Registry scope) Opens regedit at the matched key |
| View Certificate | (Certificate scope) Opens the matched certificate |
| Copy Path | Copies the full file/key path to the clipboard |
| Open Reports Folder | Opens the report output folder |

---

## Usage & screenshots

![](githubRepoContentDeleteIfYouWant/IMG/1.jpg)

When matches are found, TextTrace exports the results to a CSV file. Default location: `Files\Reports\Report.csv` — UTF-8 encoding, semicolon delimiter, no type information.

**Report columns:**

| Column | Description |
|--------|-------------|
| Index | Row number of the match |
| Kind | Scope the match came from (Files / Registry / Certificates) |
| FileName | Name of the matched file |
| LineNumber | Line number where the match was found |
| Line | Full matching line |
| Path | Full path to the matched file |

![](githubRepoContentDeleteIfYouWant/IMG/2.jpg)

**Default file patterns:** `*.xml`, `*.txt`, `*.log`, `*.csv`, `*.json`, `*.ini`, `*.config`, `*.html`, `*.htm`, `*.ps1`, `*.psm1`, `*.bat`, `*.cmd`, `*.md`, `*.yaml`, `*.yml`, `*.sql`

You can also add custom patterns in the application, for example: `*.cs,*.js,*.vbs,*.properties`

![](githubRepoContentDeleteIfYouWant/IMG/3.jpg)
![](githubRepoContentDeleteIfYouWant/IMG/4.jpg)
![](githubRepoContentDeleteIfYouWant/IMG/5.jpg)

---

## Regex examples

Enable **Use Regex** before using regex patterns, and make sure the pattern is valid .NET regular-expression syntax.

| Goal | Pattern |
|------|---------|
| Find `test` anywhere in a line | `test` |
| Find the exact word `test` | `\btest\b` |
| Find either `error` or `warning` | `error\|warning` |
| Find lines that start with `ERROR` | `^ERROR` |
| Find an IPv4 address | `\b(?:\d{1,3}\.){3}\d{1,3}\b` |
| Find PowerShell variables | `\$[A-Za-z_][A-Za-z0-9_]*` |
| Find XML-like tags | `<[^>]+>` |
| Find email addresses | `\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b` |

---

## Performance notes
- Works best with text-based files; very large folders or files may take longer to scan.

---

## Roadmap
Browser add to firefox, Chrome and edge

