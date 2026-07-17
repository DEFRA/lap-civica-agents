# LLD Generation Summary — BSE (Bovine Spongiform Encephalopathy)

Generation date: 2026-07-17T00:00:00Z (v2 — regenerated with updated HLD and instructions)

---

## Migration Details

The BSE database migration transfers the on-premises SQL Server database (`DEFACPVWPSQL001\BSE`, hosted on `DEFACPVWPSQL002` in Production) to Azure SQL Database using Microsoft-supported tools.

**Migration method:**
- **Azure Migrate (Discovery and Assessment):** Performs a non-impacting point-in-time assessment of a copy of the live on-premises database to identify compatibility issues, unsupported features, required schema changes, and migration blockers.
- **Azure Database Migration Service (DMS):** Executes schema and full data migration to Azure SQL Database.

**Migration steps:**
1. Schema migration to Azure SQL via DMS (Schema Only mode).
2. Full data migration via DMS.
3. Validate successful completion of data load.
4. Execute functional and performance testing.
5. Freeze source database for final cutover (offline mode).
6. Redirect application connections to Azure SQL Database.
7. Post-cutover verification and monitoring.

**Downtime:** Zero application downtime — cutover only occurs after validating performance and accuracy of the migrated parallel system (per HLD Section 5.1).

**Rollback:** Source on-premises SQL Server remains unchanged and available until migration completion is confirmed. In the event of critical issues, the application is switched back to the on-premises setup.

**Data reconciliation checks:**
- Row count comparison between source and target databases.
- Spot checks on business-critical tables.
- Verification of stored procedures (264 total), views, and indexes.
- Execution of representative queries and comparison of results.
- Reconciliation queries to be defined in LLD (HLD Section 5.1 reference).

**Acceptance criteria:**
- All schema objects migrated without errors.
- 100% of required data successfully migrated and reconciled.
- Functional tests confirm application behaviour matches source system.
- Performance benchmarks meet or exceed agreed thresholds.
- Security and access controls correctly configured and validated.
- Stakeholder sign-off obtained from business and technical teams.

Per HLD Section 5.1 and HLSA Slides 4 and 34.

---

## Document Generation Summary

### Sections Auto-Filled

- **Title block** — Project Name, Author (from updated HLD contributors)
- **Version History** — initial entry dated 2026-07-17
- **Document References** — updated HLD (.NET 10) and HLSA v0.3 cited
- **Introduction** — project name, overview of replaced system, and component scope
- **HLD Deviations** — No deviations; updated HLD targets .NET 10 on Azure App Service, aligned with HLSA v0.3
- **Build Deviations** — noted as N/A at time of initial draft
- **Conceptual Design overview** — full Hub-and-Spoke Azure migration description with source references
- **Components table (C01–C05)** — BSE Web App, Azure SQL Database, Azure Data Factory, App Gateway/WAF, Platform Services
- **Environments overview** — dev, test, preprod, prod with data policies and access controls
- **Azure VMs/EC2 (Server Configuration)** — N/A with justification (PaaS-only architecture)
- **App Services** — all four environments plus ADF (bse-portal-svc-dev/test/preprod/prod, bse-integration-svc)
- **API Management** — N/A (CCoE Application Gateway handles ingress)
- **APIs** — N/A (web application, no standalone REST APIs in scope)
- **Service Bus** — N/A (ADF handles integration)
- **Logic Apps / Functions** — N/A (ADF handles scheduling)
- **VNet Configuration** — hub-vnet (CCoE) + four spoke VNets (10.10–10.40.0.0/23 per env)
- **VNet Subnets** — bse-app-snet (/27) and bse-db-snet (/28) per environment
- **Network Interactions** — NI-001 (user to WAF), NI-002 (app to SQL), NI-003 (ADF to TSE)
- **Network Design narrative** — Hub-and-Spoke description, ingress and egress details
- **External Access** — Ingress, Egress, and External-to-External details all populated
- **Anti-Virus** — Microsoft Defender for Cloud (App Service + SQL)
- **Vulnerability Scanning** — Defender for SQL + Defender for Cloud
- **SOC Integration** — Sentinel + Log Analytics workspace + CCoE SOC routing
- **Application Registrations** — BSE-Portal-App, AppService-ManagedIdentity, ADF-ManagedIdentity
- **Authentication table** — NI-001 through NI-004 with SAML 2.0 SSO, Managed Identity, MFA details
- **Authorisation table** — role-based, RBAC, PIM, SQL db_datareader, Key Vault, DevOps pipeline
- **Encryption at Rest** — TDE (SQL), Azure Key Vault, platform-managed (App Service, Storage)
- **Encryption in Transit table** — NI-001 through NI-005 with TLS 1.2+ for all connections
- **Intrusion Detection and Prevention** — Sentinel, Defender for SQL, Defender for App Service, Azure Firewall Threat Intelligence
- **Storage Accounts** — N/A (SharePoint Online for documents; no Azure Storage in scope)
- **Databases** — bse-case-db (Production: 8 vCores/200GB/ZRS; Dev/Test/PreProd variants)
- **Backup and Recovery** — SQL automated backups with per-env retention; App Service CI/CD rollback; Key Vault soft delete
- **Capacity Management** — App Service autoscale P2v3 (2–4 instances prod); SQL serverless autoscale
- **Clustering and Resilience** — App Service zone-redundant P2v3; SQL zone-redundant with auto-failover group; ADF managed IR
- **Disaster Recovery** — SQL cross-region replication, RPO minutes, RTO 8–48 hours
- **Infrastructure Monitoring** — Azure Monitor, Logic Monitor (CCoE), Log Analytics, NSG Flow Logs
- **Application Monitoring** — Azure Application Insights (telemetry sampling 5% prod, 30-day Dev to 180-day Prod retention)
- **Scheduling** — ADF triggers: TSE-to-BSE at 00:20 daily; BSE Core-to-Export at 07:00 daily
- **Software Deployment and Management** — Azure DevOps CI/CD with OIDC, Bicep IaC, gated approvals
- **Licensing** — Azure subscription-based PaaS pricing with key cost drivers identified
- **Pre-Production** — P1v3, 2 instances, 30-day backup, 60–90-day log retention, CAB approval gate
- **Dev/Test** — S1, 1 instance, 7–14-day backup, 7–30-day log retention, PR review gate
- **Migration Details** — full Azure Migrate + DMS approach, cutover steps, rollback strategy, acceptance criteria
- **Figure 1 (High Level Component Diagram)** — Mermaid graph showing all components and integrations
- **Figure 2 (Interaction Diagram)** — Mermaid sequence diagram showing user auth flow and ADF pipelines
- **Figure 3 (Physical Diagram)** — Mermaid graph showing Hub-Spoke VNet physical layout with subnets
- **Figure 4 (Network Diagram)** — Mermaid graph showing full network topology with NSG rules and egress rules

---

### Sections Requiring Manual Review

| Section | Reason |
|---------|--------|
- **HLD Deviations (Table 1)** — No deviations. Updated HLD now targets .NET 10 on Azure App Service, fully aligned with HLSA v0.3 Slide 15. No outstanding platform discrepancy.
| Approval table | Approver names, sign-off dates, and email addresses must be completed by human reviewers. |
| Security Design | WAF custom rule configuration, Conditional Access policy specifics, PIM elevation window durations, and break-glass account details require DEFRA Security team review. **[MANUAL REVIEW REQUIRED]** |
| Risks and Open Questions | HLSA RAID items (R-001: direct DB access via SSMS; R-002: security vulnerabilities; D-003: TSE connectivity) and HLD impact assessment risks require team review and updated mitigation plans. **[MANUAL REVIEW REQUIRED]** |
| Key Vault backup/export policy | DEFRA CCoE guidance on Key Vault backup must be confirmed. |
| Build Deviations (Table 2) | To be updated after the Implementation phase commences with any actual build deviations. |

---

### Needs Input

1. **Project ID** — not provided in HLD v0.2 or HLSA v0.3 source documents.
2. **Approval table** — approver names, roles, sign-off dates, and email addresses for all reviewers and approvers.
3. **Key Vault backup/export policy** — confirm with DEFRA CCoE team.
4. **Subscription and EA agreement details** — confirm subscription names and Azure EA agreement reference with DEFRA Procurement.
5. **Additional approver** — a fourth approver row in the Approval table is pre-allocated and requires input.
6. **Exact subnet CIDR allocations** — non-Production environments (dev, test, preprod) subnet CIDRs are CCoE-allocated; confirm with CCoE network team.
7. **Data migration reconciliation queries** — per HLD Section 5.1, specific reconciliation SQL queries are to be defined in the LLD (not yet provided in source documents).
8. **TSE database connectivity confirmation** — per HLSA RAID item D-003, the exact VPN/ExpressRoute/Private Endpoint routing path to the TSE database (`tses.data.prd1.prd.cerespfm.cloud`) must be confirmed and NSG rules validated.

---

### Assumptions

- Application targets .NET 10 on Azure App Service per updated HLD (aligns with HLSA v0.3 Slide 15). HLSA/HLD platform discrepancy from earlier draft is resolved.
- Naming convention applied per project instructions: `bse-portal-svc` (web app), `bse-case-db` (database), `bse-integration-svc` (ADF), `bse-spoke-{env}` (VNets), `rg-bse-{env}` (resource groups), `bse-sub-{env}` (subscriptions).
- Four environments provisioned in Azure UK South: dev, test, preprod, prod (per HLD Section 1.5).
- Spoke VNet address spaces 10.10–10.40.0.0/23 per environment per HLD Table 22; Hub VNet is CCoE-managed with undisclosed CIDR.
- All subnet CIDRs within spoke VNets are CCoE-allocated (/27 for app, /28 for DB/PE subnets) per HLD Section 3.2.1.
- ADF pipeline trigger schedules (00:20 UTC and 07:00 UTC) sourced from HLD Section 2.3.3.
- Backup retention periods sourced from HLD Section 4.4.
- App Service tier sizing sourced from HLD Table 7.
- Database sizing (vCores and max storage per environment) sourced from HLD Table 14 and HLSA Slide 14.
- Resource group author defaults to LLD Author (Arindrajit Sarkar); actual author credentials to be confirmed.
- SharePoint Online integration is out of scope for Azure landing zone design (external system, hyperlink access only).

---

## Confidence by Section

| Section | Confidence | Notes |
|---------|-----------|-------|
| Introduction | High | Directly sourced from HLD Executive Summary and HLSA Slide 34 |
| HLD Deviations | High | No deviations — HLD updated to .NET 10, fully aligned with HLSA v0.3 |
| Conceptual Design overview | High | Sourced from HLD Sections 2.3.1 and HLSA Slides 9–10 |
| Components table | High | All 5 components directly from HLD Sections 2.3.1–2.3.3 |
| Environments overview | High | Sourced from HLD Table 18 |
| Server Configuration (N/A) | High | PaaS-only confirmed by HLD throughout |
| App Services | High | Tier, count, and names from HLD Table 7 and Section 2.3.1. .NET 10 runtime confirmed per updated HLD. |
| API Management / APIs / Service Bus / Logic Apps (N/A) | High | Confirmed not in scope by HLD Section 1.5 and 2.3.3 |
| VNet Configuration | High | Address spaces from HLD Table 22; Hub details CCoE-managed (acknowledged unknown) |
| VNet Subnets | Medium | /27 + /28 pattern from HLD Section 3.2.1; exact CIDRs CCoE-allocated |
| Network Interactions | High | Firewall rules directly from HLD Tables 23–26 |
| Network Security (Ingress/Egress) | High | Directly sourced from HLD Tables 23, 24, 25 |
| Shared Services | High | Defender services from HLD Section 3.1 Step 6 |
| Application Registrations | High | From HLD Sections 2.3.1 and Table 6 |
| Authentication | High | SAML 2.0 SSO from HLD Section 2.3.1 Step 1 and Table 6 |
| Authorisation | High | RBAC, claims-based from HLD Section 2.3.1 |
| Encryption | High | TDE, TLS 1.2+ confirmed throughout HLD Sections 2.3.2 and 3.2.1 |
| Intrusion Detection | High | Defender portfolio from HLD Section 3.1 Step 6 |
| Storage Accounts (N/A) | High | SharePoint for docs confirmed; no Azure Storage in LLD scope |
| Databases | High | Full spec from HLD Table 14 and HLSA Slide 14 |
| Backup and Recovery | High | Retention periods from HLD Section 4.4 |
| Capacity Management | High | Autoscale from HLD Table 7 and Section 4.1 |
| Clustering / Resilience | High | From HLD Tables 27, Section 4.1–4.2 |
| Disaster Recovery | High | RPO/RTO from HLD Sections 4.2–4.3 and HLSA Slide 31 (NFR-002/003) |
| Monitoring | High | Azure Monitor config from HLD Table 28 |
| Scheduling | High | Pipeline schedules from HLD Section 2.3.3 |
| Software Deployment | High | CI/CD stages from HLD Section 2.3.5 and Table 18 |
| Licensing | Medium | Service tiers confirmed; subscription/EA details need human input |
| Pre-Production | High | Config from HLD Table 18 |
| Dev/Test | High | Config from HLD Table 18 |
| Migration Details | High | Directly from HLD Section 5.1 |
| Figure 1 – Component Diagram | High | All components and integrations from HLD |
| Figure 2 – Interaction Diagram | High | Auth flow and ADF pipelines from HLD |
| Figure 3 – Physical Diagram | High | Hub-Spoke topology from HLD Section 3.1 |
| Figure 4 – Network Diagram | High | Network rules from HLD Tables 22–26 |
| Document Generation Summary | High | Auto-generated metadata |
| Approval / Sign-off | Low | Requires human input for all approver fields |
| Security Design details | Medium | Architecture confirmed; specific WAF rules and CA policies need DEFRA Security review |
| Risks and Open Questions | Low | RAID items from HLSA; mitigation plans need team review |
