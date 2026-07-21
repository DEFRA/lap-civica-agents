---
skill:
  id: dotnet-code-refactor
  name: .NET Code Refactor
  version: 1.0.0
  owner: Platform/Engineering
  intent: >
    Improve the maintainability, reliability, and observability of migrated VB.NET or C# / ASP.NET
    Core codebases without altering business logic. Removes dead code, enforces naming
    conventions, replaces unstructured error handling with a domain exception hierarchy,
    and wires Application Insights structured telemetry throughout the application.
    Supports both VB.NET-only and C# (Classic→Modern) migration paths via the `language` input.
  recommended_agent: dotnet-code-refactor-agent
  scope:
    includes:
      - Dead code removal and naming convention enforcement (VB.NET and C#)
      - On Error Resume Next elimination (VB.NET) and empty catch block removal (C# and VB.NET)
      - Domain exception hierarchy creation and generic catch replacement
      - Global exception handler wiring in Program.cs via UseExceptionHandler middleware
      - Application Insights NuGet installation and TelemetryHelper DI setup
      - EventLog.WriteEntry replacement with structured telemetry calls
      - Populating Razor Page PageModel stubs (OnGet/OnPost) migrated from WebForms code-behind (C# path only)
    excludes:
      - Business logic changes of any kind
      - Framework version upgrades (use dotnet-framework-upgrade skill)
      - Authentication / identity changes (use identity-migration-dotnet skill)
      - Auto-generated files (*.designer.vb, *.g.vb, AssemblyInfo.vb)
      - Secret values — must never be written to any file
  inputs_required:
    - solutionFolder: "Absolute path to the repository root containing the .sln file"
    - targetFramework: "Target framework moniker, e.g. net10.0"
    - language: "Source language of the migrated application — 'vb' (VB.NET source remains VB.NET) or 'cs' (source migrated to C#). Determines output file extensions and which cleanup patterns apply."
  outputs:
    - "BSESystem/Exceptions/BSESystemExceptions.vb (language=vb) OR BSESystem/Exceptions/BSESystemExceptions.cs (language=cs)"
    - "BSESystem/Logging/TelemetryHelper.vb (language=vb) OR BSESystem/Logging/TelemetryHelper.cs (language=cs)"
    - appsettings.json (ApplicationInsights.ConnectionString placeholder added)
    - Program.cs (UseExceptionHandler middleware and TelemetryHelper DI registration added)
    - docs/code-refactor/code-cleanup-report.json
    - docs/code-refactor/exception-handling-report.json
    - docs/code-refactor/logging-enhancement-report.json
    - docs/code-refactor/build-output.log
    - docs/code-refactor/conversion-report-<YYYY-MM-DD>.html
    - "All modified .vb source files (language=vb) OR all modified .cs source files (language=cs) — updated in place"
  success_criteria:
    - "(language=vb) Zero On Error Resume Next statements remain in any .vb file"
    - "(language=cs) Zero empty catch {} blocks remain in any .cs file"
    - Zero empty Catch blocks remain across all source files
    - Zero EventLog.WriteEntry calls remain in any source file
    - UseExceptionHandler middleware is wired in Program.cs and redirects to safe Razor Page error routes
    - TelemetryHelper is the sole logging entry point across the codebase
    - "(language=cs) All Razor Page PageModel stubs have OnGet/OnPost handlers migrated from WebForms code-behind"
    - Solution builds with zero errors after all changes
  safety:
    - Never change business logic or authorization outcomes.
    - Never modify *.designer.vb, *.g.vb, or AssemblyInfo.vb files.
    - Never modify the HTML structure of .cshtml view stubs — only populate PageModel (.cshtml.cs) OnGet/OnPost handlers when language=cs.
    - Never write secret values (connection strings, keys, passwords) to any file.
    - Never expose stack traces or SQL error messages in user-facing pages.
    - Never suppress auth-related exceptions from ASP.NET Core authentication or SAML middleware.
---
 
# .NET Code Refactor (Skill)
 
This skill provides a structured, repeatable three-phase workflow to clean, harden, and
instrument legacy VB.NET / ASP.NET WebForms codebases for Azure App Service hosting.
Each phase must complete before the next begins.
 
## When to use this skill
Use this skill after `framework-upgrade` and `nuget-package-upgrade` have completed and
the solution builds cleanly against the target framework. Do not use it on code that still
contains unresolved build errors — fix the build first.
 
## Execution Order
 
Run the sub-skills in the following sequence — each depends on outputs from the previous:
 
| Order | Skill file | Purpose |
|---|---|---|
| 1 | [code-cleanup-refactor.md](./code-cleanup-refactor.md) | Remove dead code, enforce naming, split large methods; eliminate `On Error Resume Next` (VB.NET) or empty catch blocks (C#); populate Razor Page stubs (C# path) |
| 2 | [global-exception-handling.md](./global-exception-handling.md) | Define domain exception hierarchy in VB.NET or C#, replace generic catches, wire `UseExceptionHandler` in `Program.cs` |
| 3 | [appinsights-logging.md](./appinsights-logging.md) | Install Application Insights packages, create `TelemetryHelper` in VB.NET or C# (DI-registered), replace all legacy logging |
 
## Inputs
 
| Input | Required | Description |
|---|---|---|
| `solutionFolder` | Yes | Absolute path to the repository root |
| `targetFramework` | Yes | Target framework moniker (e.g. `net10.0`) |
| `language` | Yes | `vb` — source remains VB.NET; `cs` — source has been migrated to C#. Controls file extensions for generated files and which cleanup patterns apply. |
| `BSESystem/Exceptions/BSESystemExceptions.vb` (language=vb) / `BSESystem/Exceptions/BSESystemExceptions.cs` (language=cs) | global-exception-handling |
| `docs/code-refactor/exception-handling-report.json` | global-exception-handling |
| `Program.cs` (UseExceptionHandler wired) | global-exception-handling |
| `BSESystem/Logging/TelemetryHelper.vb` (language=vb) / `BSESystem/Logging/TelemetryHelper.cs` (language=cs) | appinsights-logging |
| `appsettings.json` (ConnectionString placeholder) | appinsights-logging |
| `docs/code-refactor/logging-enhancement-report.json` | appinsights-logging |
| `docs/code-refactor/build-output.log` | build-validation |
| `docs/code-refactor/conversion-report-<YYYY-MM-DD>.html` | html-report-generator |
 
## Safety Guardrails
 
- **Never** change business logic or authorization outcomes.
- **Never** modify auto-generated files (`*.designer.vb`, `*.g.vb`, `AssemblyInfo.vb`).
- **Never** modify the HTML structure of `.cshtml` view stubs — only populate `PageModel` (`.cshtml.cs`) `OnGet`/`OnPost` handlers, and only when `language=cs`.
 