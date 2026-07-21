---
name: code-cleanup-refactor
description: This skill is used by dotnet-code-refactor agent specifically for migrated Civica applications (BSE, Histo, D2R2 and PTLIMS) . Cleans code and remove duplication using best-practice refactoring.
---
 
# Skill: code-cleanup-refactor
 
## Purpose
Scan all source files in the solution, remove dead and unreachable code, enforce naming conventions, split oversized methods and classes, catalogue TODO/FIXME/HACK comments, and remove `On Error Resume Next` patterns — replacing them with structured `Try`/`Catch` blocks.
 
## Trigger Conditions
- Called after `framework-upgrade` Mode B and `nuget-package-upgrade` Mode B have completed.
- The `language` input controls which patterns apply:
  - **`language=vb`**: The solution targets `.NET 10` with an SDK-style `.vbproj`. All existing application source files are VB.NET (`.vb`). C# scaffold files (`Program.cs`, `.cshtml` + `.cshtml.cs` stubs) exist but their `.cshtml` view markup must not be modified by this skill. The `.cshtml.cs` PageModel stubs may be populated with `OnGet`/`OnPost` handlers migrated from WebForms code-behind.
  - **`language=cs`**: All application source files have been converted to C# (`.cs`). Apply C#-specific cleanup patterns (see steps below). Populate `.cshtml.cs` PageModel stubs with `OnGet`/`OnPost` handlers migrated from the original WebForms code-behind logic.
- Remove legacy exception suppression patterns based on language:
  - **VB.NET**: Remove `On Error Resume Next` / `On Error GoTo 0` pairs — replace with structured `Try`/`Catch` blocks.
  - **C#**: Remove empty `catch` blocks swallowing exceptions silently. Remove `#pragma warning disable` directives that suppress nullable or exception-related warnings without a documented reason.
  - Both: Remove empty `Catch`/`catch` blocks with no logging.
 
---
 
## Step 1 — Discover All Source Files

**language=vb** — scan the `solutionFolder` recursively for:
- `*.vb` (code-behind, modules, classes, services)
- Exclude: `*.designer.vb`, `AssemblyInfo.vb`, `*.g.vb` (auto-generated)

**language=cs** — scan the `solutionFolder` recursively for:
- `*.cs` (controllers, services, repositories, helpers)
- `*.cshtml.cs` (Razor Page PageModel files — stubs to be populated)
- Exclude: `*.g.cs`, `*.AssemblyInfo.cs`, auto-generated files under `obj/`

In both cases also scan for TODO/FIXME markers in:
- `*.cshtml` (Razor Page view stubs — read-only catalogue; do not modify view markup)
 
---
 
## Step 2 — Remove Dead and Unreachable Code

### VB.NET (language=vb)

| Pattern | Action |
|---|---|
| Unused `Imports` statements | Remove the `Imports` line |
| Unreferenced `Public`/`Private` `Sub` or `Function` within `Module`/`Class` | Remove after confirming no dynamic/reflection binding |
| Code after `Return` or `Exit Sub` within the same block | Remove unreachable lines |
| Orphaned event handlers (`Handles` clause referencing a control that no longer exists) | Remove the handler sub — after Classic→Modern all WebForms controls are gone from the runtime; every `Handles` clause in `.aspx.vb` code-behind is dead code |
| `.aspx.vb` code-behind methods that only perform WebForms UI binding (`Page_Load`, `Button_Click`, etc.) | Migrate business logic to the corresponding Razor Page `OnGet`/`OnPost` stub; log the migration in `code-cleanup-report.json` |

### C# (language=cs)

| Pattern | Action |
|---|---|
| Unused `using` directives | Remove the `using` line |
| Unreferenced `public`/`private` methods within a class | Remove after confirming no dynamic/reflection binding |
| Code after `return` or `throw` within the same block | Remove unreachable lines |
| `HttpContext.Current` usage | Replace with `IHttpContextAccessor` injected via constructor |
| `System.Web.*` type references not removed by upgrade | Flag as blocking — these have no equivalent in ASP.NET Core; log and raise as manual migration items |
| Dead code-behind logic in `.aspx.cs` files (if any remain on disk) | Migrate business logic to the corresponding `.cshtml.cs` `OnGet`/`OnPost` method; log the migration |
## Step 3 — Enforce Naming Conventions
 
The following conventions apply to both VB.NET and C# unless noted:

| Element | Convention | VB.NET Example | C# Example |
|---|---|---|---|
| Public method | PascalCase | `GetRecord()` | `GetRecord()` |
| Private method | PascalCase | `ValidateInput()` | `ValidateInput()` |
| Async method (C# only) | PascalCase + `Async` suffix | — | `GetRecordAsync()` |
| Local variable | camelCase | `patientId` | `patientId` |
| Private field | `_camelCase` | `_connectionString` | `_connectionString` |
| Parameter | camelCase | `slideName` | `slideName` |
| Constant | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` | `MAX_RETRY_COUNT` |
| Class / Module | PascalCase | `ApplicationService` | `ApplicationService` |
| Interface | `I` prefix + PascalCase | `ISlideRepository` | `ISlideRepository` |
| Hungarian notation | **Remove prefix** | `strName` → `name`, `blnActive` → `isActive` | `strName` → `name`, `bIsActive` → `isActive` |
| Single-letter variable outside loop | Rename to descriptive name | `x` → `slideIndex` | `x` → `slideIndex` |
 
---
 
## Step 4 — Split Large Methods and Classes
 
### Size Thresholds
 
| Artefact | Maximum Lines | Action When Exceeded |
|---|---|---|
| `Sub` / `Function` / method | 50 lines | Extract sub-methods; each extracted method has a single responsibility |
| `Class` / `Module` | 300 lines | Extract into focused classes; use `Partial` only for designer-generated code |
| Code-behind (`.aspx.vb` or `.cshtml.cs`) | 400 lines | Extract business logic into a service class; keep PageModel to request/response handling only |
| Nested `If`/`if` depth | 3 levels | Refactor with guard clauses (early `Return`/`return` / `Exit Sub`) or extract to a named method |
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
 
## Step 6 — Remove Silent Error Suppression

### VB.NET (language=vb)

`On Error Resume Next` silently suppresses all runtime errors. It must be eliminated from every VB.NET source file.

#### Detection
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
 
#### Rules
- Replace every `On Error Resume Next` / `On Error GoTo 0` pair with a `Try`/`Catch`/`Finally` block.
- The `Catch` type must be as specific as possible — use the domain exception types defined in `global-exception-handling` skill.
- Map `Err.Number` values to typed exceptions (e.g., `Err.Number = -2147352567` → `COMException`).
- Remove all `Err.Clear()` calls — they are redundant after restructuring.
- Log each removal in `docs/code-refactor/code-cleanup-report.json` with file path and original line range.

### C# (language=cs)

C# has no `On Error Resume Next` equivalent, but the same silent-failure intent appears in two patterns:

#### Pattern 1 — Empty catch blocks

Search all `.cs` files for:
```csharp
catch (Exception)
{
    // empty or comment-only
}
```

**Replacement:**
```csharp
catch (Exception ex)
{
    _telemetryHelper.TrackException(ex, nameof(MethodName),
        new Dictionary<string, string> { ["operation"] = nameof(MethodName) });
    throw; // re-throw unless operation is explicitly fire-and-forget
}
```

#### Pattern 2 — Undocumented pragma suppression

Search all `.cs` files for `#pragma warning disable` without a following comment explaining the reason.

- If the suppressed warning is `CS8600`–`CS8670` (nullable), fix the root cause instead of suppressing.
- If the suppression has a legitimate reason, add an explanatory inline comment.

Log each fix in `docs/code-refactor/code-cleanup-report.json`.
 
---
 
## Outputs
 
| Output | Description |
|---|---|
| `docs/code-refactor/code-cleanup-report.json` | Structured log: dead code removed, renames applied, methods split, silent-error-suppression removals, TODO catalogue, PageModel stub migrations |
| All modified `.vb` files (language=vb) / `.cs` and `.cshtml.cs` files (language=cs) | Updated in place |

- Do **not** remove code that is invoked via `CallByName`, `AddHandler`, or reflection.
- Do **not** rename Public members that are referenced from `.aspx` markup `<%# %>` data-binding expressions — these files still exist on disk even though they are not processed by the .NET 10 runtime. Renaming without updating the markup will cause build errors if the `.aspx` files are ever compiled.
- Do **not** remove `TODO` comments from source — catalogue only.
- Do **not** split auto-generated designer files (`*.designer.vb`).
- Do **not** enforce naming conventions on auto-generated code.
- Do **not** modify `.cshtml` Razor Page view markup files — view markup is out of scope for this skill.
- **May** populate `.cshtml.cs` PageModel `OnGet`/`OnPost` stub methods by migrating business logic from the corresponding WebForms code-behind, but only when `language=cs`. Never change the class declaration, namespace, or DI constructor added by `framework-upgrade`.