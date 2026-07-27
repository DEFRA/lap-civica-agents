# BSESystem Security Review — Management Summary
**Reference:** ITHC-BSESystem-2026-07-27  
**Prepared For:** LAP Civica Migration Team, DEFRA  
**Classification:** 🔐 Official – Sensitive  
**Date:** 2026-07-27  

---

## 1. Overview

An automated security health check was performed on the **BSESystem web application** — the ASP.NET front-end layer of the BSE (Bovine Spongiform Encephalopathy) case management system. The review examined source code, configuration files, and third-party dependencies.

**15 security issues were identified**, including 2 issues requiring immediate action within 24 hours.

---

## 2. Risk Summary

| Risk Level | Issues Found | Action Required |
|-----------|-------------|-----------------|
| 🔴 Critical | 2 | **Immediate — within 24 hours** |
| 🟠 High | 7 | Urgent — within 7 days |
| 🟡 Medium | 5 | Plan — within 30 days |
| 🟢 Low | 1 | Schedule — within 90 days |

---

## 3. Key Findings (Plain English)

### 🔴 Database Password Stored in a Text File (ITHC-001)
The application stores the database login password directly in a configuration file (`Web.config`) on the server. Anyone with access to this file — including an attacker who finds a way to read files on the server — immediately has the username and password to the BSE database.

**Business Risk:** Full access to all BSE case data, animal records, and audit logs.  
**Action:** Remove the password from the file. Store it in a secure vault (Azure Key Vault). **Deadline: 24 hours.**

---

### 🔴 SQL Server "Super User" Account Has No Password (ITHC-002)
The system's SQL Server database has a configuration that references the built-in "System Administrator" (SA) account with a blank password. This account has unrestricted access to the entire database server.

**Business Risk:** If this server is accessible to an attacker (even from within the network), they can take complete control of the database server, read all data, and potentially run commands on the underlying server operating system.  
**Action:** Disable the SA account. Require a strong password. **Deadline: 24 hours.**

---

### 🟠 Application Reveals Technical Details When Errors Occur (ITHC-003, ITHC-004, ITHC-005)
When the application encounters an error, it currently shows full technical details — including database structure, server file paths, and code stack traces — directly in the user's browser. This information is very useful to attackers planning further attacks.

**Business Risk:** Reduces attacker effort significantly; accelerates exploitation of other vulnerabilities.  
**Action:** Configure the application to show only a generic "something went wrong" message to users; log full details privately on the server. **Deadline: 7 days.**

---

### 🟠 Links Can Be Crafted to Send Users to Malicious Websites (ITHC-006, ITHC-007)
Two pages in the application will redirect users to any website specified in a link — including sites controlled by attackers. An attacker could send a staff member a legitimate-looking government link that silently sends them to a fake login page.

**Business Risk:** Phishing attacks using trusted DEFRA/BSE domain. Risk of credential theft and account compromise.  
**Action:** Restrict redirects to known, approved pages only. **Deadline: 7 days.**

---

### 🟠 Website Is Vulnerable to Script Injection (XSS) (ITHC-008, ITHC-015)
The application does not safely process text received from web addresses (URLs) before displaying it on screen. An attacker can craft a link that, when clicked, injects malicious code into the page — potentially stealing a user's login session.

**Business Risk:** Session hijacking; attacker performs actions as a legitimate user.  
**Action:** Apply HTML encoding to all user-supplied content before display. **Deadline: 7 days.**

---

### 🟡 Missing Browser Security Protections (ITHC-009, ITHC-010)
The application does not send standard security instructions to users' browsers, such as "do not load this page inside another website" or "only use HTTPS". These protections defend against a class of attacks called clickjacking and cross-site request forgery.

**Business Risk:** Users could be tricked into performing unintended actions (e.g., saving or deleting case records).  
**Action:** Add security headers to the web server configuration. **Deadline: 30 days.**

---

## 4. Dependency Risk

| Component | Current Version | Status |
|-----------|----------------|--------|
| AjaxControlToolkit | 17.1.1.0 (2017) | Outdated; recommend upgrade |

---

## 5. Immediate Actions (24-Hour Checklist)

| # | Action | Owner | Deadline |
|---|--------|-------|----------|
| 1 | Remove `Password=password` from `Web.config` appSettings; rotate DB password on `vm-aphadev-003` | Dev + DBA | **Today** |
| 2 | Disable SA account on SQL Server `127.0.0.1`; verify no application uses it | DBA | **Today** |
| 3 | Notify security lead of Critical findings per Defra escalation policy | Tech Lead | **Within 1 hour** |

---

*This summary is intended for non-technical stakeholders. For full technical details, CVSSv3 scores, CWE mappings, and remediation code examples, refer to the full ITHC report: `ITHC-Security-Report-BSESystem-2026-07-27.md`.*

*Findings ITHC-012 and ITHC-013 were identified using AI-assisted analysis and should be independently verified before remediation scheduling.*
