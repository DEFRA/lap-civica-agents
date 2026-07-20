# Skill: build-validation
 
> **Note — Canonical skill location**: The full, reusable version of this skill (supporting both
> MSBuild classic and dotnet CLI modern build modes) lives at
> `.github/skills/dotnet-framework-upgrade/build-validation.md`.
> This copy is the **application-specific override** for the `dotnet-code-refactor` agent.
> It applies **Mode A (MSBuild classic)** only — Windows runner, `nuget.exe`, MSBuild.
 
---
 
## Purpose
Validate that the VB.NET / ASP.NET WebForms solution compiles cleanly in Release configuration after all refactoring, framework upgrade, and NuGet package upgrade changes have been applied. Capture all errors and warnings, categorise them, and drive iterative fixes until the build produces zero errors and acceptable warning counts.
 
## Trigger Conditions
- Always runs **after** `framework-upgrade` and `nuget-package-upgrade` have completed.
- Re-runs after every batch of refactoring changes from `code-cleanup-refactor`, `global-exception-handling`, and `appinsights-logging` skills.
 
---
 
## Step 1 — Restore NuGet Packages
 
```powershell
nuget restore <solution-file>.sln
```
 
> **Must use `nuget.exe`** — not `dotnet restore`. The `dotnet restore` command does not support `packages.config` style solutions.
 
Confirm exit code is `0`. If restore fails, report each failed package as a **P0 blocking issue** and halt.
 
---
 
## Step 2 — Run MSBuild in Release Configuration
 
```powershell
msbuild "<solution-file>.sln" `
  /p:Configuration=Release `
  /p:Platform="Any CPU" `
  /p:DeployOnBuild=false `
  /t:Build `
  /nologo `
  /v:minimal `
  2>&1 | Tee-Object -FilePath build-output.log
```
 
> **Must use MSBuild** — not `dotnet build`. The `dotnet build` command does not support `System.Web`-based projects or `packages.config` NuGet restoration.
 
---
 
## Step 3 — Parse and Categorise Build Output
 
Parse `build-output.log` for MSBuild diagnostic entries. Categorise each:
 
| Category | Severity | Action |
|---|---|---|
| `error MSB*` | Build error — MSBuild infrastructure | Halt and fix project file issue |
| `error BC*` | VB.NET compiler error | Fix code or reference issue |
| `error CS*` | C# compiler error | Fix code or reference issue |
| `warning BC40*` | VB.NET obsolescence warning | Log; fix if in touched files |
| `warning BC42*` | VB.NET unused variable / import | Fix — these are dead code indicators |
| `warning MSB3277` | Assembly reference conflict | Fix binding redirect in `web.config` |
| `warning MSB3245` | Assembly not resolved | Fix `<HintPath>` or NuGet restore gap |
 
---
 
## Step 4 — Fix Errors Iteratively
 
For each **compiler error** (`BC*` / `CS*`):
 
1. Identify the file and line number.
2. Determine root cause:
   - **Missing `Imports` / `using`** after NuGet package upgrade changed namespace.
   - **Changed constructor signature** in an upgraded package.
   - **Renamed type or member** in an upgraded package.
   - **Ambiguous reference** after adding Application Insights namespaces.
3. Apply the minimal fix that resolves the error without changing application behaviour.
4. Re-run MSBuild after each batch of fixes.
 
---
 
## Step 5 — Fix Assembly Reference Conflicts (MSB3277)
 
For every `MSB3277` warning (multiple versions of the same assembly):
 
1. Identify the conflicting assembly name and the two versions in conflict.
2. Add or update a `<bindingRedirect>` in `web.config` to redirect the lower version to the higher version.
3. Confirm the output assembly will use the correct version at runtime.
 
---
 
## Step 6 — Validate Zero Errors
 
Confirm:
- `msbuild` exits with code `0`.
- The output log contains `0 Error(s)`.
- All critical `MSB3245` (unresolved assembly) warnings are eliminated.
 
If zero-error state cannot be achieved, report all remaining errors with their file, line, error code, and the attempted fix. Do not proceed to deployment packaging.
 
---
 
## Step 7 — Capture Warning Baseline
 
Record the count and category of remaining warnings after the zero-error build. This becomes the warning baseline for the project. Include in `html-report-generator` output.
 
---
 
## Step 8 — Produce Web Deploy Package (Optional)
 
If deployment packaging is requested:
 
```powershell
msbuild "<WebProject>.vbproj" `
  /p:Configuration=Release `
  /p:DeployOnBuild=true `
  /p:WebPublishMethod=Package `
  /p:PackageAsSingleFile=true `
  /p:SkipInvalidConfigurations=true `
  /p:PackageLocation=".\artifacts" `
  /nologo
```
 
---
 
## Outputs
 
| Output | Description |
|---|---|
| `build-output.log` | Raw MSBuild output |
| `build-validation-report.json` | Structured: error count, warning count, errors list, warnings list, exit code |
| Zero-error confirmation | Boolean flag consumed by `html-report-generator` |
 
---
 
## Constraints
 
- **Never** use `dotnet build` or `dotnet restore`.
- **Never** run build on a Linux runner — the .NET Framework build toolchain is Windows-only.
- **Never** suppress warnings by adding `#Disable Warning` pragmas without documenting the specific reason.
- **Never** mark the build as passing if `Error(s)` count is greater than zero.