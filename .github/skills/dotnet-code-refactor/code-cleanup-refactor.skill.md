---
name: code-cleanup-refactor
description: This skill is used by dotnet-code-refactor agent specifically for migrated Civica applications (BSE, Histo, D2R2 and PTLIMS) . Cleans code and remove duplication using best-practice refactoring.
---
 
# Skill: code-cleanup-refactor
 
## Purpose
Scan all source files in the solution, remove dead and unreachable code, enforce naming conventions, split oversized methods and classes, catalogue TODO/FIXME/HACK comments, and remove `On Error Resume Next` patterns — replacing them with structured `Try`/`Catch` blocks.
 
## Trigger Conditions
- Called after `framework-upgrade` Mode B and `nuget-package-upgrade` Mode B have completed.
- At this point the solution targets `.NET 10` with an SDK-style `.vbproj`. All existing application source files are still VB.NET (`.vb`). New C# scaffold files (`Program.cs`, `.cshtml` + `.cshtml.cs` stubs) have been created by the framework upgrade but must not be modified by this skill.
- Remove legacy VB.NET exception suppression patterns:
  - Remove `On Error Resume Next` / `On Error GoTo 0` pairs — replace with structured `Try`/`Catch` blocks.
  - Remove empty `Catch` blocks swallowing exceptions with no logging.
 
---
 
## Step 1 — Discover All VB.NET Source Files
 
Scan the `solutionFolder` recursively for:
- `*.vb` (code-behind, modules, classes, services)
- Exclude: `*.designer.vb`, `AssemblyInfo.vb`, `*.g.vb` (auto-generated)
 
---
 
## Step 2 — Remove Dead and Unreachable Code
 
Identify and remove:
 
| Pattern | Action |
|---|---|
| Unused `Imports` statements | Remove the `Imports` line |
| Unreferenced `Public`/`Private` `Sub` or `Function` within `Module`/`Class` | Remove after confirming no dynamic/reflection binding |
| Code after `Return` or `Exit Sub` within the same block | Remove unreachable lines |
| Orphaned event handlers (`Handles` clause referencing a control that no longer exists) | Remove the handler sub — after Classic→Modern all WebForms controls are gone from the runtime; every `Handles` clause in `.aspx.vb` code-behind is dead code |
| `.aspx.vb` code-behind methods that only perform WebForms UI binding (`Page_Load`, `Button_Click`, etc.) | Log as dead code candidates; do not remove — flag for manual migration to Razor Page `OnGet`/`OnPost` handlers |
## Step 3 — Enforce Naming Conventions
 
| Element | Convention | Example |
|---|---|---|
| Public `Sub`/`Function` | PascalCase | `GetRecord()` |
| Private `Sub`/`Function` | PascalCase | `ValidateInput()` |
| Local variable | camelCase | `patientId` |
| Module-level field | `_camelCase` (underscore prefix) | `_connectionString` |
| Parameter | camelCase | `slideName` |
| Constant (`Const`) | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Class / Module | PascalCase | `ApplicationService` |
| Interface | `I` prefix + PascalCase | `ISlideRepository` |
| Hungarian notation | **Remove prefix** | `strName` → `name`, `intCount` → `count`, `blnActive` → `isActive` |
| Single-letter variable outside `For` loop | Rename to descriptive name | `x` → `slideIndex` |
 
Rename using safe symbol rename (update all references). Log each rename: file, original name, new name, line count affected.
 
---
 
## Step 4 — Split Large Methods and Classes
 
### Size Thresholds
 
| Artefact | Maximum Lines | Action When Exceeded |
|---|---|---|
| `Sub` / `Function` | 50 lines | Extract sub-methods; each extracted method has a single responsibility |
| `Class` / `Module` | 300 lines | Extract into focused classes; use `Partial` only for designer-generated code |
| Code-behind (`.aspx.vb`) | 400 lines | Extract business logic into a service class; keep code-behind to UI event wiring only |
| Nested `If` depth | 3 levels | Refactor with guard clauses (early `Return`/`Exit Sub`) or extract to a named method |
 
### Extraction Pattern
 
```vb
' Before — monolithic method
Private Sub ProcessRequest(recordId As Integer)
    ' 80 lines of mixed validation, data access, and rendering
End Sub
 
' After — split into focused methods
Private Sub ProcessRequest(recordId As Integer)
    Dim record = LoadRecord(recordId)
    ValidateRecord(record)
    RenderRecordDetails(record)
End Sub
 
Private Function LoadRecord(recordId As Integer) As RecordDto
    ' data access only
End Function
 
Private Sub ValidateRecord(record As RecordDto)
    ' validation only
End Sub
 
Private Sub RenderRecordDetails(record As RecordDto)
    ' UI binding only
End Sub
```
 
---
 
## Step 5 — Catalogue TODO / FIXME / HACK Comments
 
Search all files for comments containing: `TODO`, `FIXME`, `HACK`, `TEMP`, `WORKAROUND` (case-insensitive).
 
Scan both VB.NET source files and the stub Razor Pages created by the framework upgrade:
- `*.vb` — application source
- `*.cshtml.cs` — Razor Page stubs (contain `// TODO: Migrate from WebForms` markers)
- `*.cshtml` — Razor Page view stubs

  "file": "relative/path/to/file.vb",
  "line": 142,
  "comment": "' TODO: Replace with stored procedure call",
  "recommendedAction": "Extract to data access layer; use parameterised SqlCommand"
}
```
 
Include the full catalogue as a table in the HTML conversion report.  
**Do not remove** any TODO comment from source — list only.
 
---
 
## Step 6 — Remove On Error Resume Next
 
`On Error Resume Next` silently suppresses all runtime errors. It must be eliminated from every VB.NET source file.
 
### Detection
Search all `.vb` files for `On Error Resume Next` and `On Error GoTo 0` (case-insensitive).
 
### Replacement Pattern
 
**Before:**
```vb
On Error Resume Next
result = repository.GetSlide(slideId)
If Err.Number <> 0 Then
    lblError.Text = Err.Description
    Err.Clear()
End If
On Error GoTo 0
```
 
**After:**
```vb
Try
    result = repository.GetRecord(recordId)
Catch ex As DataAccessException
    lblError.Text = "Unable to retrieve data. Please try again."
    _telemetryHelper.TrackException(ex, New Dictionary(Of String, String) From {
        {"recordId", recordId.ToString()},
        {"operation", "GetRecord"}
    })
End Try
```
 
### Rules
- Replace every `On Error Resume Next` / `On Error GoTo 0` pair with a `Try`/`Catch`/`Finally` block.
- The `Catch` type must be as specific as possible — use the domain exception types defined in `global-exception-handling` skill.
- Map `Err.Number` values to typed exceptions (e.g., `Err.Number = -2147352567` → `COMException`).
- Remove all `Err.Clear()` calls — they are redundant after restructuring.
- Log each removal in `docs/code-refactor/code-cleanup-report.json` with file path and original line range.
 
---
 
## Outputs
 
| Output | Description |
|---|---|
| `docs/code-refactor/code-cleanup-report.json` | Structured log: dead code removed, renames applied, methods split, On Error Resume Next removals, TODO catalogue |
| All modified `.vb` files | Updated in place |
 
---
 
## Constraints

- Do **not** remove code that is invoked via `CallByName`, `AddHandler`, or reflection.
- Do **not** rename Public members that are referenced from `.aspx` markup `<%# %>` data-binding expressions — these files still exist on disk even though they are not processed by the .NET 10 runtime. Renaming without updating the markup will cause build errors if the `.aspx` files are ever compiled.
- Do **not** remove `TODO` comments from source — catalogue only.
- Do **not** split auto-generated designer files (`*.designer.vb`).
- Do **not** enforce naming conventions on auto-generated code.
- Do **not** modify `.cshtml` or `.cshtml.cs` stub files generated by `framework-upgrade` — those are flagged for manual migration and must not be altered by this skill.