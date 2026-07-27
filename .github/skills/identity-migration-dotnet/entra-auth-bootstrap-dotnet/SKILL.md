---
name: entra-auth-bootstrap-dotnet
description: >-
  Bootstraps Azure Entra ID authentication for VB.NET / ASP.NET applications. Supports .NET Framework 4.8
  and ASP.NET Core .NET 8+. Use when migrating from Windows Authentication to Entra ID.
license: OGL-UK-3.0
metadata:
  author: defra-digital
  version: "1.0"
compatibility: ".NET Framework 4.8 and ASP.NET Core .NET 8+"
---

> **Framework scope:** This skill supports two runtime targets. For **.NET Framework 4.8** applications, follow the procedure below as written. For **ASP.NET Core (.NET 8+)** applications, replace `web.config`/`Global.asax` references with `appsettings.json`/`Program.cs` equivalents — wire authentication via `builder.Services.AddAuthentication()` in `Program.cs`, not via OWIN or `Global.asax`.

# Entra Auth Bootstrap (.NET Framework 4.8)

## When to use this skill
Use this skill when you need to:
- Introduce Entra ID sign-in to an ASP.NET (full framework) app
- Centralize authentication startup/configuration
- Replace or decouple Windows Authentication dependencies in a controlled way

## Inputs you should gather (from the repo)
- Current auth mode and entry points (e.g., web.config auth settings, Global.asax, any startup/auth modules)
- Existing usage of identity/roles/groups in VB.NET code
- Required redirect/logout URLs and expected token/claims shape (from migration requirements)

## Procedure (do in order)
1. **Discover current auth wiring**
   - Locate where auth is configured (config + initialization code)
   - List all files involved (e.g., config, startup, modules, global filters)
2. **Design a minimal bootstrap**
   - Choose a single “bootstrap” location for auth initialization (centralized)
   - Ensure it can be enabled/disabled via configuration (if repo pattern allows)
3. **Add configuration keys with placeholders**
   - Add keys for tenant/authority, client/app id, redirect URL, logout URL, and token validation expectations
   - Use placeholders only (no secrets, no real tenant IDs committed)
4. **Wire authentication challenge/redirect**
   - Ensure unauthenticated requests are challenged consistently
   - Ensure post-auth return path is deterministic
5. **Add safe failure paths**
   - Invalid config → fail fast with a clear message for developers
   - Token/claims issues → deny access or re-auth challenge (no silent failures)

## Guardrails
- Do not introduce framework upgrades beyond .NET Framework 4.8
- Do not change authorization semantics (roles/groups) in this skill — only bootstrap
- Never log tokens or raw claims payloads
- Never commit secrets


## References (load when needed)
- ./references/bootstrap-checklist.md
- ./references/config-keys-template.md


## Output format (required)
### Summary
### Files changed (exact paths)
### Configuration keys added (placeholders only)
### Startup/auth flow decisions
### Manual verification steps (high-level)
