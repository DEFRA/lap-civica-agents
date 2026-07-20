---
name: global-exception-handling
description: Centralize exception handling and remove redundant try/catch blocks.
---
 
# Skill: global-exception-handling
 
## Purpose
Replace all generic, silent, and unstructured exception handling in VB.NET / ASP.NET WebForms code with a consistent domain exception hierarchy, fix empty `Catch` blocks, and wire a centralised global exception handler in `Global.asax` so that every unhandled exception is captured, logged via Application Insights, and presented to the user with a safe error page — never a raw stack trace.
 
## Trigger Conditions
- Called after `code-cleanup-refactor` (which has already removed `On Error Resume Next` patterns).
- Runs before `appinsights-logging` so that the `TelemetryClient` calls placed by this skill are consistent with the logging patterns applied in the next skill.
 
---
 
## Step 1 — Define the Domain Exception Hierarchy
 
Create a new file `App_Code\Exceptions\AppExceptions.vb` (or the equivalent shared-code path for the project):
 
```vb
Namespace Application.Exceptions
 
    ''' <summary>Base exception for all application-layer errors.</summary>
    Public Class AppException
        Inherits Exception
 
        Public Sub New(message As String)
            MyBase.New(message)
        End Sub
 
        Public Sub New(message As String, innerException As Exception)
            MyBase.New(message, innerException)
        End Sub
    End Class
 
    ''' <summary>Raised when a database or data-access operation fails.</summary>
    Public Class DataAccessException
        Inherits AppException
 
        Public Property Operation As String
 
        Public Sub New(message As String, operation As String, innerException As Exception)
            MyBase.New(message, innerException)
            Me.Operation = operation
        End Sub
    End Class
 
    ''' <summary>Raised when user-supplied input fails domain validation rules.</summary>
    Public Class ValidationException
        Inherits AppException
 
        Public Property FieldName As String
 
        Public Sub New(message As String, fieldName As String)
            MyBase.New(message)
            Me.FieldName = fieldName
        End Sub
    End Class
 
    ''' <summary>Raised when an external service or integration call fails.</summary>
    Public Class IntegrationException
        Inherits AppException
 
        Public Property ServiceName As String
 
        Public Sub New(message As String, serviceName As String, innerException As Exception)
            MyBase.New(message, innerException)
            Me.ServiceName = serviceName
        End Sub
    End Class
 
    ''' <summary>Raised when a requested resource does not exist.</summary>
    Public Class NotFoundException
        Inherits AppException
 
        Public Sub New(resourceType As String, resourceId As String)
            MyBase.New($"{resourceType} '{resourceId}' was not found.")
        End Sub
    End Class
 
End Namespace
```
 
---
 
## Step 2 — Replace Generic Catch Clauses
 
Scan all `.vb` files for `Catch ex As Exception` blocks.
 
For each occurrence, determine which domain exception type is most appropriate based on the enclosing context:
 
| Context | Replace `Exception` With |
|---|---|
| Data access method (SqlCommand, stored proc, DataAdapter) | `DataAccessException` |
| Input processing, form validation | `ValidationException` |
| External service call (HTTP, SMTP, file I/O) | `IntegrationException` |
| Resource lookup (GetById, FindByName) that can return nothing | `NotFoundException` |
| All others where no specific type can be determined | Keep `Exception` but add structured logging |
 
### Replacement Pattern
 
**Before:**
```vb
Try
    sqlCmd.ExecuteNonQuery()
Catch ex As Exception
    lblError.Text = ex.Message
End Try
```
 
**After:**
```vb
Try
    sqlCmd.ExecuteNonQuery()
Catch ex As SqlException
    Throw New DataAccessException("Failed to save record.", "SaveRecord", ex)
Catch ex As Exception
    Throw New AppException("Unexpected error during save.", ex)
End Try
```
 
---
 
## Step 3 — Fix Empty Catch Blocks
 
An empty `Catch` block is a silent failure — it swallows the exception without any logging or recovery. All empty `Catch` blocks must have at minimum a telemetry call.
 
### Detection Pattern
```vb
Catch ex As Exception
    ' (no statements — empty body)
End Try
```
 
Also detect:
```vb
Catch
    ' (no exception variable, empty body)
End Try
```
 
### Fix Pattern
 
**Before:**
```vb
Try
    SendEmailNotification(caseId)
Catch ex As Exception
End Try
```
 
**After:**
```vb
Try
    SendEmailNotification(recordId)
Catch ex As Exception
    ' Email notification is non-critical — log and continue
    telemetry.TrackException(ex, New Dictionary(Of String, String) From {
        {"recordId", recordId.ToString()},
        {"operation", "SendEmailNotification"}
    })
End Try
```
 
> **Never re-throw inside a non-critical fire-and-forget operation** — but the telemetry call is mandatory.
 
Log each fix in `docs/code-refactor/exception-handling-report.json`: file path, line number, original pattern, applied fix.
 
---
 
## Step 4 — Wire Global Exception Handler in Global.asax
 
`Application_Error` in `Global.asax.vb` is the last line of defence for unhandled exceptions. It must capture, log, and redirect — never expose a raw stack trace.
 
```vb
' Global.asax.vb
Sub Application_Error(sender As Object, e As EventArgs)
    Dim ex As Exception = Server.GetLastError()
 
    If ex Is Nothing Then Return
 
    ' Unwrap HttpUnhandledException wrapper
    If TypeOf ex Is HttpUnhandledException AndAlso ex.InnerException IsNot Nothing Then
        ex = ex.InnerException
    End If
 
    ' Log to Application Insights
    Dim telemetry As New TelemetryClient()
    telemetry.TrackException(ex, New Dictionary(Of String, String) From {
        {"url", Request.Url?.ToString()},
        {"user", User?.Identity?.Name},
        {"sessionId", Session?.SessionID}
    })
 
    ' Clear the error so IIS does not display its default error page
    Server.ClearError()
 
    ' Redirect to a safe, user-friendly error page
    Dim errorCode As Integer = 500
    If TypeOf ex Is HttpException Then
        errorCode = DirectCast(ex, HttpException).GetHttpCode()
    End If
 
    Select Case errorCode
        Case 404
            Response.Redirect("~/Error/NotFound.aspx", False)
        Case 403
            Response.Redirect("~/Error/Forbidden.aspx", False)
        Case Else
            Response.Redirect("~/Error/GeneralError.aspx", False)
    End Select
 
    HttpContext.Current.ApplicationInstance.CompleteRequest()
End Sub
```
 
> The `CompleteRequest()` call terminates the current request pipeline cleanly without throwing a `ThreadAbortException`.
 
---
 
## Step 5 — Remove EventLog.WriteEntry from Catch Blocks
 
`EventLog.WriteEntry` is not available in the Azure App Service sandbox and will throw `SecurityException` or `InvalidOperationException`. Any `EventLog.WriteEntry` call inside a `Catch` block must be replaced.
 
**Before:**
```vb
Catch ex As Exception
    EventLog.WriteEntry("webApp", ex.Message, EventLogEntryType.Error)
End Try
```
 
**After:**
```vb
Catch ex As Exception
    Try
        ' EventLog is not available on Azure App Service — use Application Insights
        telemetry.TrackException(ex)
    Catch
        ' Suppress secondary logging failure to avoid masking the original exception
    End Try
    Throw
End Try
```
 
---
 
## Outputs
 
| Output | Description |
|---|---|
| `App_Code\Exceptions\AppExceptions.vb` | New domain exception hierarchy file |
| `docs\code-refactor\exception-handling-report.json` | Structured log: generic catches replaced, empty blocks fixed, EventLog calls replaced, Global.asax changes |
| All modified `.vb` files | Updated in place |
| `Global.asax.vb` | Updated with wired global handler |
 
---
 
## Constraints
 
- Do **not** add a `Catch` block to every `Try` — only add handling where there is meaningful recovery or logging to apply.
- Do **not** re-throw inside `Application_Error` — the global handler is the terminal boundary.
- Do **not** expose exception details (stack traces, SQL messages) in user-facing error pages or HTTP responses.
- Do **not** suppress auth-related exceptions (from OWIN, SAML, or Windows Auth middleware) — these must propagate to allow the auth pipeline to handle them correctly.
- The `AppExceptions.vb` file must be added to the project file's `<Compile>` items list if it is not in a folder that is auto-included.