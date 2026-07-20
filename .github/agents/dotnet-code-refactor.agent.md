---
name: dotnet-code-refactor-agent
description: Cleans and improves legacy code, with strong focus on maintainability, error handling, and logging, without changing business logic.
model: Claude Sonnet 4.6 (copilot) # specify the model to use for this agent. If not set, the default model will be used.
 
tools: ['search/codebase', 'read/problems', 'edit' ] # specify the tools this agent can use. If not set, all enabled tools are allowed.
---
 
## Skills Used
 
> Skills execute in the following order. Each skill must complete successfully before the next begins, except `html-report-generator` which always runs last regardless of partial completion.
 
| Order | Skill | Purpose |
|---|---|---|
| 1 | `code-cleanup-refactor` | Remove dead code, fix naming, split large methods, catalogue TODOs, remove `On Error Resume Next` |
| 2 | `global-exception-handling` | Replace generic exceptions with domain types, fix empty catch blocks, wire `Global.asax` handler |
| 3 | `appinsights-logging` | Replace legacy logging with Application Insights structured telemetry |
| 4 | `build-validation` | Restore packages and run MSBuild; iterate until zero errors |
| 5 | `html-report-generator` | Produce the styled HTML conversion report from all skill outputs |
 
### Skill References
- code-cleanup-refactor
- global-exception-handling
- appinsights-logging
- build-validation
- html-report-generator
---
 
## Input Parameters
 
| Parameter | Required | Description | Example |
|---|---|---|---|
| `solutionFolder` | ✅ Yes | Absolute or relative path to the repository root containing the `.sln` file | `C:\Projects\ApplicationSystem` |
| `reportOutputFolder` | No | Folder where the HTML report is written (default: `<solutionFolder>\docs\code-refactor`) | `C:\Projects\ApplicationSystem\docs\code-refactor` |
 
## Output Contract
 
| Output | Path | Description |
|---|---|---|
| HTML Conversion Report | `<solutionFolder>\docs\code-refactor\conversion-report-<YYYY-MM-DD>.html` | Fully styled self-contained HTML report covering all changes |
| Build Log | `<solutionFolder>\docs\code-refactor\build-output.log` | Raw MSBuild output from `build-validation` skill |
| Skill JSON Logs | `<solutionFolder>\docs\code-refactor\*.json` | Per-skill machine-readable change logs |
 
## Prerequisite
 
> **Run the `dotnet-framework-upgrade` agent first** before invoking this agent.
> This agent assumes the solution already targets  or  and all NuGet packages
> have been upgraded to compatible versions. Framework and NuGet upgrade responsibilities
> are owned exclusively by the `dotnet-framework-upgrade` agent.
 
## 1. Responsibilities
- Read the current files from the `solutionFolder` input parameter
- Fix build errors and warnings arising from code changes (via the `build-validation` skill)
- Generate an HTML conversion report with professional CSS styling clearly documenting what changes were performed (via the `html-report-generator` skill)
### 1.1 Code Cleanup
- Remove dead and unreachable code (unreferenced `Module`, unused `Imports`, orphaned event handlers)
- Improve naming conventions: PascalCase for Public members, camelCase for local variables, remove Hungarian notation prefixes
- Split large methods (>50 lines) and classes (>300 lines) into focused, single-responsibility units
- Catalogue all `TODO`, `FIXME`, and `HACK` comments with file reference, line number, and recommended action — do not remove without approval
- Remove `On Error Resume Next` patterns — replace with structured `Try`/`Catch`/`Finally` blocks (see 1.2)
 
### 1.2 Error Handling Improvement
- Replace all empty `Catch` blocks with structured handling: log the exception via Application Insights then re-throw or return a typed error result
- Replace `Catch ex As Exception` with domain-specific exception types from the application exception hierarchy
- Domain exception hierarchy base: `AppException` → `DataAccessException`, `ValidationException`, `IntegrationException`
- Maintain the global exception handling in `Global.asax` `Application_Error` — route all unhandled exceptions through a centralised `IHttpModule` handler
- Ensure all `Catch` blocks that suppress exceptions contain at minimum an Application Insights `TrackException` call
 
### 1.3 Logging Enhancement
- Replace `EventLog.WriteEntry`, `Debug.Print`, and `Response.Write` debug output with Application Insights structured telemetry
- Use the correct severity: `TrackException` for errors and exceptions, `TrackEvent` for business events, `TrackTrace` for diagnostic messages
- Apply log-level discipline: Verbose → Information → Warning → Error → Critical — never use Error level for expected business exceptions
- Add contextual properties to every telemetry call: operation name, user identifier (non-PII), and module/class name
- Wrap `EventLog.WriteEntry` calls in a suppressing try/catch where the underlying EventLog service is unavailable on App Service (see `azure-infra.instructions.md`)
 
### 1.4 Quality & Safety Checks
- Compile/build validation using MSBuild in Release configuration — zero errors must be achieved before completion
- NuGet restore must use `nuget.exe`, not `dotnet restore`
- Build must run on Windows only — the .NET Framework toolchain is not available on Linux runners
 

## 2. Success Criteria
- Zero `On Error Resume Next` statements remain in any `.vb` file
- Zero empty `Catch` blocks remain
- Zero `EventLog.WriteEntry` calls remain outside suppressing wrappers 