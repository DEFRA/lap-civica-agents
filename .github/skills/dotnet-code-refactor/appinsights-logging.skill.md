---
name: appinsights-logging
description: Inject Application Insights telemetry for observability which includes log context not personal information
---
 
# Skill: appinsights-logging
 
## Purpose
Replace all legacy and inconsistent logging mechanisms in VB.NET / ASP.NET WebForms code with Application Insights structured telemetry. Installs the required NuGet packages, wires the `TelemetryClient` through a shared helper, and applies consistent log levels, contextual properties, and operation tracking across the entire codebase.
 
## Trigger Conditions
- Called after `global-exception-handling` has wired `Application_Error` and domain exceptions are in place.
- The exception types introduced by `global-exception-handling` are referenced in `TrackException` calls placed by this skill.
 
---
 
## Step 1 — Install NuGet Packages
 
Add the following packages to every web project's `packages.config`:
 
```xml
<package id="Microsoft.ApplicationInsights" version="2.22.0" targetFramework="net48" />
<package id="Microsoft.ApplicationInsights.Web" version="2.22.0" targetFramework="net48" />
<package id="Microsoft.ApplicationInsights.WindowsServer" version="2.22.0" targetFramework="net48" />
<package id="Microsoft.ApplicationInsights.WindowsServer.TelemetryChannel" version="2.22.0" targetFramework="net48" />
```
 
Run `nuget restore` after editing `packages.config` (see `nuget-package-upgrade` skill for restore command).
 
---
 
## Step 2 — Configure ApplicationInsights.config
 
Create or update `ApplicationInsights.config` at the project root:
 
```xml
<?xml version="1.0" encoding="utf-8"?>
<ApplicationInsights xmlns="http://schemas.microsoft.com/ApplicationInsights/2013/Settings">
  <InstrumentationKey>__APP_INSIGHTS_INSTRUMENTATION_KEY__</InstrumentationKey>
  <TelemetryInitializers>
    <Add Type="Microsoft.ApplicationInsights.Web.AzureAppServiceRoleNameFromHostNameHeaderInitializer, Microsoft.AI.Web" />
    <Add Type="Microsoft.ApplicationInsights.Web.OperationNameTelemetryInitializer, Microsoft.AI.Web" />
    <Add Type="Microsoft.ApplicationInsights.Web.SyntheticUserAgentTelemetryInitializer, Microsoft.AI.Web" />
    <Add Type="Microsoft.ApplicationInsights.Web.ClientIpHeaderTelemetryInitializer, Microsoft.AI.Web" />
    <Add Type="Microsoft.ApplicationInsights.Web.OperationCorrelationTelemetryInitializer, Microsoft.AI.Web" />
    <Add Type="Microsoft.ApplicationInsights.Web.UserTelemetryInitializer, Microsoft.AI.Web" />
    <Add Type="Microsoft.ApplicationInsights.Web.AuthenticatedUserIdTelemetryInitializer, Microsoft.AI.Web" />
    <Add Type="Microsoft.ApplicationInsights.Web.AccountIdTelemetryInitializer, Microsoft.AI.Web" />
    <Add Type="Microsoft.ApplicationInsights.Web.SessionTelemetryInitializer, Microsoft.AI.Web" />
  </TelemetryInitializers>
  <TelemetryModules>
    <Add Type="Microsoft.ApplicationInsights.Web.RequestTrackingTelemetryModule, Microsoft.AI.Web" />
    <Add Type="Microsoft.ApplicationInsights.Web.ExceptionTrackingTelemetryModule, Microsoft.AI.Web" />
  </TelemetryModules>
</ApplicationInsights>
```
 
> Replace `__APP_INSIGHTS_INSTRUMENTATION_KEY__` with a Key Vault reference at deploy time — never hardcode the key.
 
---
 
## Step 3 — Create Shared TelemetryHelper
 
Create `App_Code\Logging\TelemetryHelper.vb`:
 
```vb
Imports Microsoft.ApplicationInsights
Imports Microsoft.ApplicationInsights.DataContracts
Imports System.Collections.Generic
 
Namespace WebApp.Logging
 
    ''' <summary>
    ''' Application-wide telemetry wrapper. All logging in the application
    ''' must go through this class rather than creating TelemetryClient instances directly.
    ''' </summary>
    Public NotInheritable Class TelemetryHelper
 
        Private Shared ReadOnly _client As New TelemetryClient()
 
        Private Sub New()
        End Sub
 
        ''' <summary>Log an exception with structured context properties.</summary>
        Public Shared Sub TrackException(ex As Exception,
                                         operation As String,
                                         Optional additionalProperties As Dictionary(Of String, String) = Nothing)
            Dim props As New Dictionary(Of String, String) From {
                {"operation", operation},
                {"appVersion", GetType(TelemetryHelper).Assembly.GetName().Version.ToString()}
            }
            If additionalProperties IsNot Nothing Then
                For Each kvp In additionalProperties
                    props(kvp.Key) = kvp.Value
                Next
            End If
            _client.TrackException(ex, props)
        End Sub
 
        ''' <summary>Log a diagnostic trace message.</summary>
        Public Shared Sub TrackTrace(message As String,
                                      level As SeverityLevel,
                                      Optional operation As String = Nothing)
            Dim props As New Dictionary(Of String, String)
            If operation IsNot Nothing Then props("operation") = operation
            _client.TrackTrace(message, level, props)
        End Sub
 
        ''' <summary>Log a named business event.</summary>
        Public Shared Sub TrackEvent(eventName As String,
                                      Optional properties As Dictionary(Of String, String) = Nothing)
            _client.TrackEvent(eventName, properties)
        End Sub
 
        ''' <summary>Flush all pending telemetry. Call in Application_End.</summary>
        Public Shared Sub Flush()
            _client.Flush()
        End Sub
 
    End Class
 
End Namespace
```
 
---
 
## Step 4 — Log Level Mapping
 
Apply the correct severity level for every logging call replacement:
 
| Legacy Pattern | New Call | Level | Notes |
|---|---|---|---|
| `EventLog.WriteEntry(..., Error)` / `EventLogEntryType.Error` | `TelemetryHelper.TrackException(ex, ...)` | Error | Wrap in suppressing try/catch (EventLog unavailable on App Service) |
| `EventLog.WriteEntry(..., Warning)` / `EventLogEntryType.Warning` | `TelemetryHelper.TrackTrace(msg, SeverityLevel.Warning, ...)` | Warning | |
| `EventLog.WriteEntry(..., Information)` | `TelemetryHelper.TrackTrace(msg, SeverityLevel.Information, ...)` | Information | |
| `Debug.Print(...)` / `Debug.WriteLine(...)` | `TelemetryHelper.TrackTrace(msg, SeverityLevel.Verbose, ...)` | Verbose | Remove from production; guard with `#If DEBUG` or remove entirely |
| `Console.WriteLine(...)` (diagnostic) | `TelemetryHelper.TrackTrace(msg, SeverityLevel.Information, ...)` | Information | |
| `Response.Write(...)` (debug output) | Remove entirely + `TelemetryHelper.TrackTrace(msg, SeverityLevel.Warning, ...)` | Warning | Never write debug output to HTTP response in production |
| Business event tracking (user action, workflow step) | `TelemetryHelper.TrackEvent(eventName, properties)` | — | |
 
### Level Discipline Rules
- **Verbose**: developer diagnostics only — never fire in production by default.
- **Information**: normal start/end of significant operations (workflow initiated, record saved).
- **Warning**: recoverable unexpected state (retry triggered, fallback value used, deprecated path taken).
- **Error**: operation failed and was not recovered; an exception was thrown.
- **Critical**: application startup failure, security breach detected, data corruption — rare; treated as an incident trigger.
 
---
 
## Step 5 — Add Contextual Properties
 
Every `TrackException` and significant `TrackTrace` call must include at minimum:
 
| Property | Source | Notes |
|---|---|---|
| `operation` | Enclosing method name | `NameOf(MethodName)` |
| `userId` | `HttpContext.Current.User.Identity.Name` | Non-PII identifier; do not log full UPN |
| `sessionId` | `HttpContext.Current.Session?.SessionID` | For session-correlated error diagnosis |
| `pageUrl` | `HttpContext.Current.Request?.Url?.AbsolutePath` | Path only — no query string if it contains tokens |
 
---
 
## Step 6 — Wire Flush in Application_End
 
In `Global.asax.vb`, add:
 
```vb
Sub Application_End(sender As Object, e As EventArgs)
    TelemetryHelper.Flush()
End Sub
```
 
---
 
## Step 7 — Replace EventLog.WriteEntry in Catch Blocks
 
Where `EventLog.WriteEntry` appears inside a `Catch` block, wrap it in a suppressing try/catch to prevent the secondary exception from masking the original:
 
```vb
' Before
Catch ex As Exception
    EventLog.WriteEntry("MyApp", ex.Message, EventLogEntryType.Error)
End Try
 
' After
Catch ex As Exception
    TelemetryHelper.TrackException(ex, "ProcessRecord",
        New Dictionary(Of String, String) From {{"recordId", recordId.ToString()}})
End Try
```
 
> The suppressing try/catch around `EventLog.WriteEntry` is only needed during phased rollout. Once all `EventLog` calls are replaced, no suppressing wrapper is required.
 
---
 
## Outputs
 
| Output | Description |
|---|---|
| `App_Code\Logging\TelemetryHelper.vb` | Shared telemetry wrapper class |
| `ApplicationInsights.config` | Application Insights configuration file |
| `docs\code-refactor\logging-enhancement-report.json` | Structured log: legacy calls replaced, NuGet packages added, files modified |
| All modified `.vb` files | Updated in place with `TelemetryHelper` calls |
 
---
 
## Constraints
 
- **Never hardcode** the Application Insights Instrumentation Key — use a Key Vault reference via App Service application settings.
- **Never log** authentication tokens, session cookies, full UPN, or any PII in telemetry properties.
- **Never** create a `new TelemetryClient()` directly in application code — always use `TelemetryHelper`.
- **Never** use `TrackException` for expected business exceptions (e.g., `ValidationException` raised by user input) — use `TrackEvent` or `TrackTrace(Warning)` for expected paths.
- Do **not** add `#Disable Warning` pragmas to suppress compiler warnings about replaced `EventLog` calls — fix them.
- Do **not** use `Response.Write` for any diagnostic output — ever.
 
 --