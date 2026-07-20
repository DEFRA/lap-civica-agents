---
name: code-cleanup-refactor
description: Clean code and remove duplication using best-practice refactoring.
---
 
# Skill: code-cleanup-refactor
 
## Purpose
Scan all VB.NET source files in the solution, remove dead and unreachable code, enforce naming conventions, split oversized methods and classes, catalogue TODO/FIXME/HACK comments, and remove `On Error Resume Next` patterns — replacing them with structured `Try`/`Catch` blocks.
 
## Trigger Conditions
- Called after `framework-upgrade` and `nuget-package-upgrade` have completed.
- Runs before `global-exception-handling` so that `On Error Resume Next` patterns are resolved into `Try`/`Catch` blocks first.
 
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
| Orphaned event handlers (`Handles` clause referencing a control that no longer exists in `.aspx`) | Remove the handler sub |
| Commented-out code blocks (3+ consecutive commented lines) | Log as candidate for removal; do not remove without marking in TODO catalogue |
| Empty `If` blocks with no body | Remove the `If`/`End If` structure |
 
> **Do not remove** code that is invoked via reflection, late binding (`CallByName`), or dynamic event subscription (`AddHandler`).
 
Log each removal in `docs/code-refactor/code-cleanup-report.json` with: file path, line range, pattern type, action taken.
 
---
 
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
 
For each match, record:
 
```json
{
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
    telemetry.TrackException(ex, New Dictionary(Of String, String) From {
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
- Do **not** rename Public members that are referenced from `.aspx` markup `<%# %>` data-binding expressions without also updating the markup.
- Do **not** remove `TODO` comments from source — catalogue only.
- Do **not** split auto-generated designer files (`*.designer.vb`).
- Do **not** enforce naming conventions on auto-generated code.