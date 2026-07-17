# Copilot Global Instructions (VB.NET + ASP.NET + .NET Framework 4.8)

These instructions apply to all GitHub Copilot interactions in this repository, including custom agents under `.github/agents/`.
This file is the shared “brain” that keeps changes consistent, secure, and reviewable across the team. [1](URL of configuration Placeholder)

---

## Repo Context (Assumed)
- Legacy application is primarily **VB.NET** on **ASP.NET (full .NET Framework 4.8)**.
- Changes should remain compatible with **.NET Framework 4.8** (do not upgrade to .NET 6/7/8 unless explicitly requested).
- Authentication is being migrated from **Windows Authentication** to **Azure Entra ID-based authentication**.

---

## Golden Rules (Security & Safety)
1. **Never output or commit secrets** (client secrets, certificates, tokens, connection strings). Use placeholders like `__CLIENT_ID__`, `__TENANT_ID__`, `__AUTHORITY__`.
2. **Never log tokens or full claims payloads**. If diagnostics are needed, log only non-sensitive identifiers and redact values.
3. **Avoid behavioral drift**: do not change authorization outcomes unless the change is explicitly described and tested.
4. **Prefer minimal, incremental changes**: small PRs, clear diffs, easy rollback.

---

## How to Work in This Repo (Required Process)
When implementing changes (especially auth-related):

### 1) Start with discovery
- Identify where authentication and authorization are currently enforced (e.g., access checks, role checks, identity accessors).
- Identify all claim usage points and normalize them through a single mapping layer.

### 2) Make changes in a consistent structure
- Centralize:
  - auth bootstrap/configuration
  - claims normalization/mapping
  - session/expiry/renew behaviors
- Avoid scattered inline claim parsing across pages/controllers/modules.

### 3) Always provide a “change ledger”
For every meaningful change-set, include a short `AUTH_CHANGELOG.md` (or append to `CHANGELOG.md`) with:
- files changed
- key methods touched
- summary of auth behavior changes
- validation performed

---

## Coding Conventions (VB.NET / .NET Framework)
- Keep VB.NET style consistent with existing project conventions:
  - maintain existing naming patterns
  - do not rewrite unrelated code into new paradigms
- Prefer explicit error handling for auth/claims issues:
  - clear failure paths (challenge/deny/config error)
  - no silent catches that swallow auth exceptions

---

## Testing & Validation (Non-Negotiable for Auth Changes)
Any authentication / claims changes must include:

1) **Build verification**
- Ensure the solution compiles with the repo’s standard build.

2) **Runtime flow verification**
- Sign-in redirect round-trip
- Token validation works (issuer/audience/lifetime)
- Session expiry triggers re-auth
- Logout clears session and redirects correctly

3) **Claims mapping verification**
- Roles/groups mapping preserved
- Missing claims handled safely
- Authorization results remain equivalent to pre-migration

4) **Local testing approach**
- Where feasible, use a **mock SAML identity provider** for local validation of claims mapping, then document how to switch to real Entra ID settings. [2](URL of configuration Placeholder)

---

## Output Expectations (How Copilot should respond)
When you propose or implement changes, always output:

### Summary
- What changed and why

### Files Changed
- A bullet list of file paths + what changed

### Key Decisions
- Claims mapping rules
- Session/renew strategy
- Validation approach

### Configuration Keys
- List of required keys (placeholders only, no secrets)

### Verification
- What was built/tested and what outcome is expected