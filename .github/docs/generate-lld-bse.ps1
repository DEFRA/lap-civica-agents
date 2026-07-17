# generate-lld-bse.ps1
# Generates LLD-BSE-Populated.docx from LLD-Template.docx
# Sources: HLD.docx (v0.2) and HLSA.pptx (v0.3)
# Encoding: UTF-8 (required for special characters)

$docsPath    = "c:\Workspace\lap-civica-agents\.github\docs"
$templatePath = "$docsPath\LLD-Template.docx"
$outputPath   = "$docsPath\LLD-BSE-Populated.docx"

if (Test-Path $outputPath) { Remove-Item $outputPath -Force }

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0

try {
    $doc = $word.Documents.Open($templatePath)
    $doc.SaveAs2($outputPath)

    # ---------------------------------------------------------------
    # Helper: Short Find-and-Replace (<=200 chars replacement)
    # ---------------------------------------------------------------
    function DoReplace {
        param([string]$find, [string]$rep)
        $rng = $doc.Content
        $rng.Find.ClearFormatting()
        $rng.Find.Replacement.ClearFormatting()
        [void]$rng.Find.Execute($find, $false, $false, $false, $false, $false, $true, 1, $false, $rep, 2)
    }

    # ---------------------------------------------------------------
    # Helper: Long replacement - locate range, overwrite directly
    # ---------------------------------------------------------------
    function ReplaceLong {
        param([string]$find, [string]$rep)
        $rng = $doc.Content.Duplicate
        $rng.Find.ClearFormatting()
        $rng.Find.Text = $find
        if ($rng.Find.Execute()) {
            $rng.Text = $rep
        } else {
            Write-Warning "Token not found: $find"
        }
    }

    # ---------------------------------------------------------------
    # Helper: Set a table cell by table-index, row, col
    # ---------------------------------------------------------------
    function SetCell {
        param([int]$tbl, [int]$row, [int]$col, [string]$text)
        try {
            $cell  = $doc.Tables($tbl).Cell($row, $col)
            $start = $cell.Range.Start
            $end   = $cell.Range.End - 1
            if ($end -lt $start) { $end = $start }
            $cr = $doc.Range($start, $end)
            $cr.Text = $text
        } catch {
            Write-Warning "SetCell T$tbl[$row,$col]: $_"
        }
    }

    # ---------------------------------------------------------------
    # Helper: Insert Mermaid block after a Figure caption paragraph
    # ---------------------------------------------------------------
    function InsertAfterCaption {
        param([string]$captionText, [string]$mermaidBlock)
        $rng = $doc.Content.Duplicate
        $rng.Find.ClearFormatting()
        $rng.Find.Text = $captionText
        if ($rng.Find.Execute()) {
            # Replace caption text with caption + paragraph-break + mermaid
            $rng.Text = $captionText + [char]13 + $mermaidBlock
        } else {
            Write-Warning "Caption not found: $captionText"
        }
    }

    # ==============================================================
    # PASS 1 - Short token replacements (<200 chars)
    # ==============================================================
    DoReplace "<Project Name>"   "BSE - Bovine Spongiform Encephalopathy"
    DoReplace "<project name>"   "BSE (Bovine Spongiform Encephalopathy)"
    DoReplace "<overview of project>"   "the legacy on-premises BSE case management system, previously hosted on Windows Server 2016 / IIS by Civica"
    DoReplace "<project component>"     "Azure cloud infrastructure and hosting components"
    DoReplace "<network diagram>"       "See Figure 4 (Network Diagram) below. The BSE solution adopts a Hub-and-Spoke Azure VNet topology with centralised security in the Hub VNet and workload isolation in the BSE Spoke VNet. Per HLD Section 3.2.1."

    # ==============================================================
    # PASS 2 - Long text replacements (>200 chars via range overwrite)
    # ==============================================================

    $overviewSolution = "The BSE (Bovine Spongiform Encephalopathy) system is migrated from a legacy on-premises Windows Server 2016 / IIS environment to a secure Azure cloud-native platform aligned with Defra CCoE standards. The target architecture adopts a Hub-and-Spoke Azure Virtual Network topology in UK South. The BSE web application runs on Azure App Service (.NET Framework 4.8) with a Private Endpoint, backed by Azure SQL Database (Serverless, General Purpose). Authentication migrates from Windows Authentication to Azure Entra ID via DEFRA SAML 2.0 SSO. Azure Data Factory orchestrates two scheduled pipelines: TSE-to-BSE data ingestion (daily 00:20) and BSE Core-to-Export tables (daily 07:00). All inter-service communication uses Private Endpoints, governed by NSGs, Azure Firewall, and Azure Key Vault for secrets management. Per HLD Section 2.3.1 and HLSA Slide 9."
    ReplaceLong "<overview of solution>" $overviewSolution

    $envOverview = "Four environments are provisioned in Azure UK South: Development (dev) for active feature development using synthetic data only; Test for integration and regression testing using masked data; Pre-Production (preprod) for release candidate validation with production-like masked data and performance rehearsal; and Production (prod) for live BSE case management with zone-redundant deployment, full Defender coverage, MFA-enforced access, and policy-driven log retention. Per HLD Section 2.3.5, Table 18."
    ReplaceLong "<high level overview of environments and purpose>" $envOverview

    $ingressDetails = "All inbound user traffic enters on TCP/443 (HTTPS) through the CCoE-managed Application Gateway (WAF v2) in the Hub VNet. The WAF applies Microsoft-managed OWASP rule sets and custom rules to block SQL injection, XSS, CSRF, and other OWASP Top 10 threats before forwarding requests to the BSE App Service Private Endpoint. DNS resolution is handled by the Hub Private DNS Resolver, forwarding to Azure DNS (168.63.129.16) with conditional forwarding to Infoblox for non-Azure domains. The BSE application domain is bse.azure.defra.cloud (Private DNS Zone: azure.defra.cloud). No direct public access to the App Service or SQL Database is permitted. Per HLD Section 3.2.1, Tables 23 and 24."
    ReplaceLong "<Ingress Details>" $ingressDetails

    $egressDetails = "All outbound traffic from spoke subnets is force-routed through the Hub Azure Firewall with a default-deny egress policy. Explicit allow rules permit: TCP/443 to Azure Entra ID (AzureActiveDirectory FQDN tag, Rule Outbound-AD-Auth); TCP/1433 to Azure SQL via Private Endpoint (Rule Outbound-AzureSQL); TCP/443 to Azure Key Vault via Private Endpoint (Rule Outbound-KeyVault); TCP/443 to Azure Storage via Private Endpoint (Rule Outbound-Storage); TCP/443 to Azure Monitor / Application Insights (AzureMonitor FQDN tag, Rule Outbound-Monitoring); TCP/1433 from ADF IR to on-premises TSE Database via VPN/ExpressRoute (Rule Outbound-OnPrem-SQL); TCP/443 to approved third-party API FQDNs (Rule Outbound-3P-API). All other internet egress is blocked by Rule Deny-Internet-Egress-Default (Priority 65000). Per HLD Section 3.2.1, Tables 23 and 25."
    ReplaceLong "<Egress Details>" $egressDetails

    $extToExt = "N/A - BSE does not support direct external-to-external traffic flows. All external connectivity is routed through the Hub VNet security controls (Azure Firewall and Application Gateway WAF). Per HLD Section 3.2.1."
    ReplaceLong "<External to External> Details" $extToExt

    # ==============================================================
    # PASS 3 - Table population
    # ==============================================================

    # T1: Title block (3 rows x 2 cols) - fill column 2
    SetCell 1 1 2 "BSE - Bovine Spongiform Encephalopathy"
    SetCell 1 2 2 "[NEEDS INPUT: Project ID not provided in HLD or HLSA source documents]"
    SetCell 1 3 2 "Arindrajit Sarkar (Lead Technical Architect); Arunkumar AS (Technical Architect)"

    # T2: Version History (6 rows x 4 cols)
    SetCell 2 2 1 "0.1"
    SetCell 2 2 2 "2026-07-17"
    SetCell 2 2 3 "LLD Author"
    SetCell 2 2 4 "Initial LLD draft. Based on HLD v0.2 (Arindrajit Sarkar) and HLSA v0.3 (LAP TWG)."

    # T3: Approval (5 rows x 5 cols)
    SetCell 3 2 1 "Arindrajit Sarkar"
    SetCell 3 2 2 "Lead Technical Architect"
    SetCell 3 2 3 "Author / Reviewer"
    SetCell 3 2 4 "[NEEDS INPUT]"
    SetCell 3 2 5 "[NEEDS INPUT: email]"
    SetCell 3 3 1 "LAP TWG"
    SetCell 3 3 2 "Technical Working Group"
    SetCell 3 3 3 "Reviewer"
    SetCell 3 3 4 "[NEEDS INPUT]"
    SetCell 3 3 5 "[NEEDS INPUT: email]"
    SetCell 3 4 1 "DEFRA Security Team"
    SetCell 3 4 2 "Security and Compliance"
    SetCell 3 4 3 "Reviewer"
    SetCell 3 4 4 "[NEEDS INPUT]"
    SetCell 3 4 5 "[NEEDS INPUT: email]"
    SetCell 3 5 1 "[NEEDS INPUT: Additional approver]"
    SetCell 3 5 2 "[NEEDS INPUT: Role]"
    SetCell 3 5 3 "Approver"
    SetCell 3 5 4 "[NEEDS INPUT]"
    SetCell 3 5 5 "[NEEDS INPUT: email]"

    # T4: Document References (3 rows x 2 cols)
    SetCell 4 2 1 "HLD - Bovine Spongiform Encephalopathy High Level Design"
    SetCell 4 2 2 "0.2"
    SetCell 4 3 1 "HLSA - LAP Portfolio BSE High Level System Architecture Overview for SDA"
    SetCell 4 3 2 "0.3"

    # T5: HLD Deviations (2 rows x 2 cols)
    SetCell 5 2 1 "HLSA v0.3 (Slide 8, 15) references Azure Container Apps and .NET 10 as the future-state hosting platform, while HLD v0.2 (Section 1.5) targets Azure App Service with .NET Framework 4.8 for the immediate migration phase. This LLD follows HLD v0.2."
    SetCell 5 2 2 "HLSA describes a broader modernisation roadmap (CCoE target state). HLD v0.2 defines the in-scope immediate migration with minimal code changes to preserve functional parity. Full .NET 10 / Container Apps modernisation is out of scope. [MANUAL REVIEW REQUIRED]"

    # T6: Build Deviations (3 rows x 2 cols)
    SetCell 6 2 1 "Not applicable - build not commenced at time of initial LLD authoring (July 2026)."
    SetCell 6 2 2 "To be updated following completion of the Implementation phase per HLD Section 2.1."
    SetCell 6 3 1 "N/A"
    SetCell 6 3 2 "N/A"

    # T7: Components (6 rows x 3 cols)
    SetCell 7 2 1 "C01"
    SetCell 7 2 2 "BSE Web Application (bse-portal-svc)"
    SetCell 7 2 3 "ASP.NET .NET Framework 4.8 web application managing BSE case workflows, deployed on Azure App Service with Private Link. Accessed via CCoE Application Gateway / WAF. Per HLD Section 2.3.1 Step 3."
    SetCell 7 3 1 "C02"
    SetCell 7 3 2 "Azure SQL Database (bse-case-db)"
    SetCell 7 3 3 "Managed serverless Azure SQL Database storing all BSE case, farm, audit, and lookup data. Accessed only via Private Endpoint. Encrypted at rest (TDE) and in transit (TLS 1.2+). Per HLD Section 2.3.1 Step 4 and 2.3.2."
    SetCell 7 4 1 "C03"
    SetCell 7 4 2 "Azure Data Factory (bse-integration-svc)"
    SetCell 7 4 3 "Two ADF pipelines: TSE-to-BSE ingestion (daily 00:20, loads dbo.BSESSImport) and BSE Core-to-Export tables (daily 07:00, populates expAge/expCase/expFarm/expRelation). Uses Managed Identity and Private Endpoints. Per HLD Section 2.3.3."
    SetCell 7 5 1 "C04"
    SetCell 7 5 2 "CCoE Application Gateway / WAF v2"
    SetCell 7 5 3 "CCoE-managed Application Gateway with WAF v2 provides the sole ingress point. Inspects all HTTPS traffic against OWASP rule set before routing to BSE App Service Private Endpoint. Not managed by BSE project team. Per HLD Section 2.3.1 Step 1."
    SetCell 7 6 1 "C05"
    SetCell 7 6 2 "Platform Services (Entra ID, Key Vault, App Insights, Sentinel)"
    SetCell 7 6 3 "Azure Entra ID (DEFRA SAML 2.0 SSO) for authentication; Azure Key Vault for secrets and certificates; Azure Application Insights for application telemetry; Azure Log Analytics and Microsoft Sentinel for centralised SIEM; Logic Monitor as CCoE operational monitoring tool. Per HLD Sections 2.3.1 and 4.5."

    # T8: Server Configuration - N/A (PaaS only, no VMs)
    SetCell 8 2 1 "N/A - Azure App Service (PaaS)"
    SetCell 8 2 2 "N/A - BSE uses PaaS services exclusively. No virtual machines are deployed. Per HLD Section 2.3.1."
    SetCell 8 2 3 "N/A"
    SetCell 8 2 4 "N/A"
    SetCell 8 2 5 "N/A"
    SetCell 8 2 6 "N/A"
    SetCell 8 3 1 "N/A - Azure SQL Database (PaaS Serverless)"
    SetCell 8 3 2 "N/A - Fully managed serverless Azure SQL Database. No OS or patching required."
    SetCell 8 3 3 "N/A"
    SetCell 8 3 4 "N/A"
    SetCell 8 3 5 "N/A"
    SetCell 8 3 6 "N/A"
    SetCell 8 4 1 "N/A - Azure Data Factory V2 (PaaS)"
    SetCell 8 4 2 "N/A - Managed Azure Data Factory with Azure-hosted Integration Runtime."
    SetCell 8 4 3 "N/A"
    SetCell 8 4 4 "N/A"
    SetCell 8 4 5 "N/A"
    SetCell 8 4 6 "N/A"

    # T9: App Services (6 rows x 7 cols)
    # Name | Type | App Service Plan | Purpose | Resource Group | Location | URL
    SetCell 9 2 1 "bse-portal-svc-prod"
    SetCell 9 2 2 "Web App (.NET Framework 4.8 on Windows)"
    SetCell 9 2 3 "P2v3 Zone-Redundant, 2-4 instances autoscale"
    SetCell 9 2 4 "BSE production case management portal. Always On enabled."
    SetCell 9 2 5 "rg-bse-prod"
    SetCell 9 2 6 "UK South"
    SetCell 9 2 7 "bse.azure.defra.cloud"
    SetCell 9 3 1 "bse-portal-svc-preprod"
    SetCell 9 3 2 "Web App (.NET Framework 4.8 on Windows)"
    SetCell 9 3 3 "P1v3, 2 fixed instances (zone-redundancy optional)"
    SetCell 9 3 4 "BSE pre-production release candidate validation."
    SetCell 9 3 5 "rg-bse-preprod"
    SetCell 9 3 6 "UK South"
    SetCell 9 3 7 "bse-preprod.azure.defra.cloud"
    SetCell 9 4 1 "bse-portal-svc-test"
    SetCell 9 4 2 "Web App (.NET Framework 4.8 on Windows)"
    SetCell 9 4 3 "S1, 1 instance"
    SetCell 9 4 4 "BSE integration and regression testing environment."
    SetCell 9 4 5 "rg-bse-test"
    SetCell 9 4 6 "UK South"
    SetCell 9 4 7 "bse-test.azure.defra.cloud"
    SetCell 9 5 1 "bse-portal-svc-dev"
    SetCell 9 5 2 "Web App (.NET Framework 4.8 on Windows)"
    SetCell 9 5 3 "S1, 1 instance"
    SetCell 9 5 4 "BSE active development environment. Synthetic data only."
    SetCell 9 5 5 "rg-bse-dev"
    SetCell 9 5 6 "UK South"
    SetCell 9 5 7 "bse-dev.azure.defra.cloud"
    SetCell 9 6 1 "bse-integration-svc (Azure Data Factory V2)"
    SetCell 9 6 2 "Azure Data Factory V2 (Azure-hosted Managed IR)"
    SetCell 9 6 3 "Zone-redundant managed Azure IR"
    SetCell 9 6 4 "Orchestrates TSE-to-BSE ingestion and BSE Core-to-Export pipelines."
    SetCell 9 6 5 "rg-bse-prod"
    SetCell 9 6 6 "UK South"
    SetCell 9 6 7 "N/A (no public URL)"

    # T10: API Management - N/A
    SetCell 10 2 1 "N/A - BSE does not use Azure API Management. CCoE-managed Application Gateway (WAF v2) handles all ingress routing. Per HLD Section 2.3.1 Step 1."
    for ($c = 2; $c -le 9; $c++) { SetCell 10 2 $c "N/A" }
    for ($r = 3; $r -le 4; $r++) { SetCell 10 $r 1 "N/A"; for ($c = 2; $c -le 9; $c++) { SetCell 10 $r $c "N/A" } }

    # T11: APIs - N/A
    SetCell 11 2 1 "N/A - BSE is a web application with no standalone REST APIs in the LLD scope. Per HLD Section 1.5."
    for ($c = 2; $c -le 5; $c++) { SetCell 11 2 $c "N/A" }
    for ($r = 3; $r -le 4; $r++) { SetCell 11 $r 1 "N/A"; for ($c = 2; $c -le 5; $c++) { SetCell 11 $r $c "N/A" } }

    # T12: Service Bus - N/A
    SetCell 12 2 1 "N/A - BSE does not use Azure Service Bus. Data integration is handled exclusively via Azure Data Factory pipelines. Per HLD Section 2.3.3."
    for ($c = 2; $c -le 7; $c++) { SetCell 12 2 $c "N/A" }
    for ($r = 3; $r -le 4; $r++) { SetCell 12 $r 1 "N/A"; for ($c = 2; $c -le 7; $c++) { SetCell 12 $r $c "N/A" } }

    # T13: Logic Apps / Functions - N/A
    SetCell 13 2 1 "N/A - BSE does not use Logic Apps or Azure Functions. Scheduled data synchronisation is managed by Azure Data Factory triggers. Per HLD Section 2.3.3."
    for ($c = 2; $c -le 5; $c++) { SetCell 13 2 $c "N/A" }
    SetCell 13 3 1 "N/A"
    for ($c = 2; $c -le 5; $c++) { SetCell 13 3 $c "N/A" }

    # T14: VNET Configuration (6 rows x 5 cols)
    # Name | Resource Group | Address Space | Region | Subscription/Account
    SetCell 14 2 1 "hub-vnet (CCoE managed)"
    SetCell 14 2 2 "rg-hub (CCoE managed)"
    SetCell 14 2 3 "[CCoE-allocated - not disclosed to project team]"
    SetCell 14 2 4 "UK South"
    SetCell 14 2 5 "bse-hub-sub (CCoE)"
    SetCell 14 3 1 "bse-spoke-prod"
    SetCell 14 3 2 "rg-bse-prod"
    SetCell 14 3 3 "10.40.0.0/23"
    SetCell 14 3 4 "UK South"
    SetCell 14 3 5 "bse-sub-prod"
    SetCell 14 4 1 "bse-spoke-preprod"
    SetCell 14 4 2 "rg-bse-preprod"
    SetCell 14 4 3 "10.30.0.0/23"
    SetCell 14 4 4 "UK South"
    SetCell 14 4 5 "bse-sub-preprod"
    SetCell 14 5 1 "bse-spoke-test"
    SetCell 14 5 2 "rg-bse-test"
    SetCell 14 5 3 "10.20.0.0/23"
    SetCell 14 5 4 "UK South"
    SetCell 14 5 5 "bse-sub-test"
    SetCell 14 6 1 "bse-spoke-dev"
    SetCell 14 6 2 "rg-bse-dev"
    SetCell 14 6 3 "10.10.0.0/23"
    SetCell 14 6 4 "UK South"
    SetCell 14 6 5 "bse-sub-dev"

    # T15: VNET Subnets (6 rows x 5 cols)
    # Name | Resource Group | Address Space | Region | Subscription/Account
    SetCell 15 2 1 "bse-app-snet-prod"
    SetCell 15 2 2 "rg-bse-prod"
    SetCell 15 2 3 "/27 CIDR (CCoE-allocated within 10.40.0.0/23)"
    SetCell 15 2 4 "UK South"
    SetCell 15 2 5 "bse-sub-prod"
    SetCell 15 3 1 "bse-db-snet-prod"
    SetCell 15 3 2 "rg-bse-prod"
    SetCell 15 3 3 "/28 CIDR (CCoE-allocated within 10.40.0.0/23). Private Endpoints only. Network policies disabled."
    SetCell 15 3 4 "UK South"
    SetCell 15 3 5 "bse-sub-prod"
    SetCell 15 4 1 "bse-app-snet-{env} / bse-db-snet-{env} (non-Prod)"
    SetCell 15 4 2 "rg-bse-{env}"
    SetCell 15 4 3 "/27 app + /28 db per spoke VNet (CCoE-allocated). Dev: 10.10.0.0/23, Test: 10.20.0.0/23, PreProd: 10.30.0.0/23."
    SetCell 15 4 4 "UK South"
    SetCell 15 4 5 "bse-sub-{env}"
    SetCell 15 5 1 "Note: All subnets are associated with a dedicated NSG as required by DEFRA Azure Policy. Per HLD Section 3.2.1 Step 3 and Table 22."
    SetCell 15 5 2 "Per DEFRA Policy"
    SetCell 15 5 3 "See HLD Table 22 for CCoE-allocated CIDRs per environment."
    SetCell 15 5 4 "UK South"
    SetCell 15 5 5 "All environments"
    SetCell 15 6 1 "N/A"
    SetCell 15 6 2 "N/A"
    SetCell 15 6 3 "N/A"
    SetCell 15 6 4 "N/A"
    SetCell 15 6 5 "N/A"

    # T16: Network Interactions (4 rows x 5 cols)
    # Interaction ID | Source | Destination | Protocol/Port | Architecture and Description
    SetCell 16 2 1 "NI-001"
    SetCell 16 2 2 "Internet (APHA User Browser)"
    SetCell 16 2 3 "App Gateway WAF v2 (Hub VNet, TCP/443)"
    SetCell 16 2 4 "TCP/443 HTTPS"
    SetCell 16 2 5 "User HTTPS traffic enters via the CCoE-managed Application Gateway WAF v2 in the Hub VNet. WAF applies OWASP rule sets. Traffic is forwarded to the BSE App Service Private Endpoint. No direct public access to App Service. Per HLD Table 23 Rule Inbound-HTTPS-to-App-Entry and Table 24."
    SetCell 16 3 1 "NI-002"
    SetCell 16 3 2 "BSE App Service (App Subnet, bse-spoke-{env})"
    SetCell 16 3 3 "Azure SQL Private Endpoint (DB Subnet, bse-spoke-{env})"
    SetCell 16 3 4 "TCP/1433 TLS 1.2+"
    SetCell 16 3 5 "App Service connects to Azure SQL Database exclusively via Private Endpoint using Managed Identity. SQL public network access disabled. NSG Rule 151 allows App Subnet to SQL PE only. Per HLD Section 2.3.2, Tables 23 and 26."
    SetCell 16 4 1 "NI-003"
    SetCell 16 4 2 "Azure Data Factory IR (bse-integration-svc)"
    SetCell 16 4 3 "TSE Database (On-Premises: tses.data.prd1.prd.cerespfm.cloud) via Hub VPN/ExpressRoute"
    SetCell 16 4 4 "TCP/1433 within VPN/ER tunnel"
    SetCell 16 4 5 "ADF scheduled pipelines extract TSE surveillance data daily at 00:20 via VPN/ExpressRoute routed through the Hub firewall. Secured by Managed Identity, Private Endpoints, and Managed Private Endpoints. Per HLD Section 2.3.3, Table 23 Rule Outbound-OnPrem-SQL, and HLSA Slide 29 D-003."

    # T17: Application Registrations (4 rows x 3 cols)
    SetCell 17 2 1 "BSE-Portal-App"
    SetCell 17 2 2 "DEFRA Azure Entra ID tenant"
    SetCell 17 2 3 "BSE web application authentication via DEFRA SAML 2.0 SSO. Per-environment redirect URIs: Dev (SAML Test), Test (SAML QA), PreProd/Prod (DEFRA SAML). No secrets stored in application code. Per HLD Table 6."
    SetCell 17 3 1 "BSE-AppService-ManagedIdentity"
    SetCell 17 3 2 "DEFRA Azure Entra ID tenant"
    SetCell 17 3 3 "System-assigned Managed Identity for BSE App Service. Grants passwordless access to Azure SQL (Azure AD auth) and Azure Key Vault (Secrets User role). Per HLD Section 2.3.1 Step 3."
    SetCell 17 4 1 "BSE-ADF-ManagedIdentity"
    SetCell 17 4 2 "DEFRA Azure Entra ID tenant"
    SetCell 17 4 3 "System-assigned Managed Identity for Azure Data Factory. Grants access to Azure SQL (pipeline execution) and Azure Key Vault (linked service credentials). Per HLD Section 2.3.3."

    # T18: Authentication (5 rows x 2 cols)
    SetCell 18 2 1 "User to BSE Portal (NI-001)"
    SetCell 18 2 2 "Azure Entra ID SAML 2.0 SSO (DEFRA SSO). MFA enforced via Conditional Access policies. JWT token issued to application. Legacy authentication protocols blocked. Per HLD Section 2.3.1 Step 1 and Table 6."
    SetCell 18 3 1 "BSE App Service to Azure SQL (NI-002)"
    SetCell 18 3 2 "Managed Identity (system-assigned). No passwords or connection string secrets in code. Azure SQL configured for Entra ID-only authentication. Per HLD Section 2.3.2."
    SetCell 18 4 1 "ADF to Azure SQL and TSE Database (NI-003)"
    SetCell 18 4 2 "Managed Identity for Azure SQL connectivity. VPN/ExpressRoute with hub-governed routing for on-premises TSE database. ADF Linked Services configured via Managed Private Endpoints. Per HLD Section 2.3.3."
    SetCell 18 5 1 "AVD Data Analytics Users to Azure SQL (NI-004)"
    SetCell 18 5 2 "Azure Entra ID with MFA enforced via Conditional Access. SSMS connects from AVD using Entra ID group membership. Only from approved AVD subnet; no on-premises or internet direct access. Per HLD Section 3.1 and NSG Rule 152 (Table 26)."

    # T19: Authorisation (12 rows x 2 cols, fill 7 data rows)
    SetCell 19 2 1 "BSE Portal - Case Officers / Data Entry"
    SetCell 19 2 2 "Role-based access via Azure Entra ID Security Group membership mapped to BSE application roles (Data Entry, VLA Maintenance, DEFRA Maintenance). Claims from JWT token drive application-level authorisation. Per HLD Section 2.3.1 and Table 5."
    SetCell 19 3 1 "BSE Portal - AMS Data Analytics Users"
    SetCell 19 3 2 "AMS staff access BSE Portal with read/write permissions per assigned Entra ID group. Additional direct database access (SSMS via AVD) with read-only SQL role db_datareader. Per HLD Section 3.1 and HLSA Slide 11."
    SetCell 19 4 1 "BSE Portal - Internal Business Users (APHA)"
    SetCell 19 4 2 "APHA staff access BSE Portal with permissions per assigned Entra ID group. Role assignments managed centrally; no individual-to-application assignments. Per HLD Table 5."
    SetCell 19 5 1 "Azure Resources - RBAC"
    SetCell 19 5 2 "Azure RBAC least-privilege model. CCoE engineers manage NSGs/Firewall via PIM-elevated Contributor role. Developers hold Reader/Contributor in Dev/Test only. All Production changes require PIM elevation with approval and time-limited access. Delete locks on Production NSGs. Per HLD Section 3.1 Steps 7-9."
    SetCell 19 6 1 "Azure SQL Database - Admin and DBA Access"
    SetCell 19 6 2 "Database administrators authenticated via Entra ID group. Elevated/privileged access granted via PIM (just-in-time, approval-based, time-limited). Regular SQL logins disabled unless absolutely required. Per HLD Section 2.3.2."
    SetCell 19 7 1 "Azure Key Vault"
    SetCell 19 7 2 "App Service and ADF access Key Vault secrets and certificates via Managed Identity with Key Vault Secrets User RBAC role. No direct human access to Key Vault in Production except via PIM. Defender for Key Vault monitors for anomalous access. Per HLD Section 3.1 Step 4."
    SetCell 19 8 1 "Azure DevOps CI/CD Pipelines"
    SetCell 19 8 2 "Pipeline service connections use OIDC (OpenID Connect) with workload identity federation. No long-lived secrets in pipelines. Deployment approval gates required for PreProd and Prod stages. Per HLD Section 2.3.5."
    for ($r = 9; $r -le 12; $r++) { SetCell 19 $r 1 "N/A"; SetCell 19 $r 2 "N/A" }

    # T20: Encryption in Transit (12 rows x 4 cols, fill 7 data rows)
    SetCell 20 2 1 "NI-001"
    SetCell 20 2 2 "User Browser"
    SetCell 20 2 3 "App Gateway WAF v2"
    SetCell 20 2 4 "HTTPS / TLS 1.2+. TLS policy enforced at Application Gateway. Certificates managed by CCoE WebOps team. Per HLD Section 3.2.1."
    SetCell 20 3 1 "NI-002"
    SetCell 20 3 2 "BSE App Service (App Subnet)"
    SetCell 20 3 3 "Azure SQL Private Endpoint (DB Subnet)"
    SetCell 20 3 4 "TLS 1.2+ over TCP/1433. Enforced by Azure SQL server TLS minimum version policy. Private Link ensures traffic stays on Microsoft backbone. Per HLD Section 2.3.2."
    SetCell 20 4 1 "NI-003a"
    SetCell 20 4 2 "ADF Integration Runtime"
    SetCell 20 4 3 "Azure SQL Private Endpoint (DB Subnet)"
    SetCell 20 4 4 "TLS 1.2+ over TCP/1433 via Private Endpoint. Managed Private Endpoint used by ADF. Per HLD Section 2.3.3."
    SetCell 20 5 1 "NI-003b"
    SetCell 20 5 2 "ADF Integration Runtime"
    SetCell 20 5 3 "TSE Database (On-Premises via VPN/ExpressRoute)"
    SetCell 20 5 4 "TLS 1.2+ over TCP/1433 within IPSec VPN / ExpressRoute private peering tunnel through Hub. Per HLD Section 2.3.3 and HLSA Slide 29 D-003."
    SetCell 20 6 1 "NI-004"
    SetCell 20 6 2 "AVD (Analytics Users) - SSMS"
    SetCell 20 6 3 "Azure SQL Private Endpoint (DB Subnet)"
    SetCell 20 6 4 "TLS 1.2+ over TCP/1433. SSMS enforces encrypted connections. Access restricted to AVD subnet only via NSG Rule 152. Per HLD Section 3.1."
    SetCell 20 7 1 "NI-005"
    SetCell 20 7 2 "BSE App Service / ADF"
    SetCell 20 7 3 "Azure Key Vault (Private Endpoint)"
    SetCell 20 7 4 "HTTPS / TLS 1.2+ over TCP/443. Access via Private Endpoint. Managed Identity authentication. Per HLD Section 3.1 Step 4 and Table 23 Rule Outbound-KeyVault."
    for ($r = 8; $r -le 12; $r++) { for ($c = 1; $c -le 4; $c++) { SetCell 20 $r $c "N/A" } }

    # T21: Storage Accounts - N/A
    SetCell 21 2 1 "N/A - BSE does not require dedicated Azure Storage Accounts within this LLD scope. Case-related documents are stored in SharePoint Online (outside this Azure landing zone). ADF uses Azure-managed internal storage for pipeline execution metadata. Per HLD Section 2.3.4."
    for ($c = 2; $c -le 8; $c++) { SetCell 21 2 $c "N/A" }
    for ($r = 3; $r -le 5; $r++) { for ($c = 1; $c -le 8; $c++) { SetCell 21 $r $c "N/A" } }

    # T22: Databases (3 rows x 7 cols)
    # Name | Resource Group | Subscription | Location | Purpose | Pricing Tier | Server Name
    SetCell 22 2 1 "bse-case-db (Production)"
    SetCell 22 2 2 "rg-bse-prod"
    SetCell 22 2 3 "bse-sub-prod"
    SetCell 22 2 4 "UK South"
    SetCell 22 2 5 "Primary BSE operational database: case records, farm data, audit logs (dbo.AuditLog), lookup tables (30+ lu* tables), SSIS import staging (dbo.BSESSImport), and four export tables (expAge, expCase, expFarm, expRelation). Contains 264 stored procedures. Per HLD Section 2.3.2."
    SetCell 22 2 6 "General Purpose Serverless vCore, 8 max vCores, ZRS backup storage, 200GB max storage. Zone-redundant in Prod. Per HLD Table 14 and HLSA Slide 14."
    SetCell 22 2 7 "bse-case-db-prod.database.windows.net"
    SetCell 22 3 1 "bse-case-db (Dev / Test / PreProd)"
    SetCell 22 3 2 "rg-bse-{env}"
    SetCell 22 3 3 "bse-sub-{env}"
    SetCell 22 3 4 "UK South"
    SetCell 22 3 5 "Non-production BSE databases. Same schema as Prod. Dev: synthetic data only, 7-day backup. Test: masked data, 14-day backup. PreProd: production-like masked data, 30-day backup. Per HLD Table 14."
    SetCell 22 3 6 "Dev/Test: 2 max vCores, 5GB/20GB max. PreProd: 8 max vCores, 50GB max. All General Purpose Serverless. Per HLD Table 14."
    SetCell 22 3 7 "bse-case-db-{env}.database.windows.net"

    # T23: Backup and Recovery (4 rows x 2 cols)
    SetCell 23 2 1 "Azure SQL Database (bse-case-db)"
    SetCell 23 2 2 "Automated backups: full weekly, differential daily, transaction log every 5-10 min. ZRS-redundant backup storage. Point-in-time restore within retention period. Retention: Prod 35 days, PreProd 30 days, Test 14 days, Dev 7 days. Application data retained for extended periods per data protection compliance. Per HLD Section 4.4."
    SetCell 23 3 1 "BSE Web Application (bse-portal-svc)"
    SetCell 23 3 2 "Application code managed in GitHub (Azure Repos). Deployment slots (staging/production) enable zero-downtime rollout and rapid rollback via Azure DevOps CI/CD pipeline. No independent application backup required - redeployment from pipeline is the recovery mechanism. Per HLD Section 2.3.5."
    SetCell 23 4 1 "Azure Key Vault"
    SetCell 23 4 2 "Soft delete enabled with 90-day retention and purge protection active in Production. Secrets are versioned; previous versions recoverable. [NEEDS INPUT: Confirm Key Vault backup/export policy with DEFRA CCoE.] [MANUAL REVIEW REQUIRED]"

    # T24: Clustering / Resilience (4 rows x 2 cols)
    SetCell 24 2 1 "Azure App Service (bse-portal-svc)"
    SetCell 24 2 2 "Production: P2v3 zone-redundant App Service Plan with 2-4 instance auto-scale. Deployment slots for blue/green deployment. Auto-heal and Always On enabled. PreProd: P1v3 with 2 fixed instances. Dev/Test: S1 with 1 instance (no zone redundancy). Per HLD Section 4.1 and Table 7."
    SetCell 24 3 1 "Azure SQL Database (bse-case-db)"
    SetCell 24 3 2 "Production: Zone-redundant serverless vCore. Always On architecture with internal replicas distributed across availability zones. Auto-failover group configured with secondary in paired region (DR). ZRS backup storage. RPO: minutes; RTO: 8-48 hours for regional failover. Dev/Test: DR disabled. Per HLD Sections 4.2, 4.3 and Table 27."
    SetCell 24 4 1 "Azure Data Factory (bse-integration-svc)"
    SetCell 24 4 2 "Managed Azure Integration Runtime provides built-in high availability and zone-redundant execution. Pipeline-level retry policies for transient failures. Permanent failures require manual investigation. Azure Monitor alerts on pipeline failure, prolonged runtime, or retry exhaustion. SLA: pipelines complete within scheduled window (Tier 3 RTO: 4 hours). Per HLD Section 2.3.3 and Table 27."

    # ==============================================================
    # FIGURE MERMAID DIAGRAMS (insert after each Figure caption)
    # ==============================================================

    $fig1 = @"
```mermaid
graph TD
    User["APHA Internal Users"] -->|HTTPS/TLS 1.2+| AppGW["App Gateway WAF v2 (CCoE Managed)"]
    AppGW -->|Private Endpoint| BSEApp["bse-portal-svc (Azure App Service .NET 4.8)"]
    BSEApp -->|SAML 2.0 SSO| EntraID["Azure Entra ID (DEFRA SSO)"]
    BSEApp -->|Private Endpoint TCP/1433| BSEDB[("bse-case-db (Azure SQL Serverless)")]
    BSEApp -->|Managed Identity TCP/443| KV["Azure Key Vault"]
    BSEApp -->|Telemetry TCP/443| AppInsights["Application Insights + Log Analytics"]
    ADF["bse-integration-svc (Azure Data Factory)"] -->|Managed PE TCP/1433| BSEDB
    ADF -->|VPN/ExpressRoute TCP/1433| TSEDB[("TSE Database On-Premises")]
    AVD["AVD Analytics Users (SSMS Read-Only)"] -->|PE TCP/1433 MFA enforced| BSEDB
    BSEApp -->|Hyperlinks| SPOL["SharePoint Online (Document Storage)"]
```
"@

    $fig2 = @"
```mermaid
sequenceDiagram
    participant U as APHA User
    participant WAF as App Gateway WAF v2
    participant AAD as Azure Entra ID
    participant App as BSE Web App
    participant KV as Key Vault
    participant SQL as Azure SQL Database
    participant ADF as Azure Data Factory
    participant TSE as TSE Database (On-Prem)

    U->>WAF: HTTPS request (TCP/443)
    WAF->>AAD: SAML 2.0 auth redirect
    AAD-->>U: Auth challenge + MFA
    U-->>AAD: Credentials + MFA token
    AAD-->>App: JWT token (group claims)
    App->>KV: Get connection string (Managed Identity)
    KV-->>App: Secret value
    App->>SQL: Query via Private Endpoint (TCP/1433 TLS 1.2+)
    SQL-->>App: Data response
    App-->>U: BSE Portal page rendered

    Note over ADF,TSE: Scheduled daily at 00:20 - TSE to BSE ingestion
    ADF->>TSE: Extract surveillance data (VPN/ExpressRoute)
    TSE-->>ADF: Animal/Sample/TestingGroup/Result records
    ADF->>SQL: Load into dbo.BSESSImport

    Note over ADF,SQL: Scheduled daily at 07:00 - BSE Core to Export
    ADF->>SQL: Extract from core BSE tables
    ADF->>SQL: Load expAge/expCase/expFarm/expRelation
```
"@

    $fig3 = @"
```mermaid
graph LR
    subgraph Hub["Hub VNet (CCoE Managed - UK South)"]
        AFW["Azure Firewall (Threat Intelligence)"]
        PDNS["Private DNS Resolver (dtz.local / azure.defra.cloud)"]
        AppGW["Application Gateway WAF v2"]
    end

    subgraph Spoke["BSE Spoke VNet bse-spoke-prod 10.40.0.0/23"]
        subgraph AppSub["/27 App Subnet (NSG: Allow 443 inbound from Hub)"]
            AppPE["App Service Private Endpoint"]
        end
        subgraph DBSub["/28 DB Subnet (NSG: Allow 1433 from App + AVD only)"]
            SQLPE["SQL Private Endpoint"]
            KVPE["Key Vault Private Endpoint"]
        end
        App["bse-portal-svc App Service P2v3"]
        SQL[("bse-case-db Azure SQL Serverless")]
        ADF["bse-integration-svc ADF V2"]
        KV["Azure Key Vault"]
        AI["Application Insights"]
    end

    Internet -->|TCP/443 HTTPS| AppGW
    AppGW --> AFW
    AFW -->|VNet Peering| AppSub
    AppPE --> App
    App -->|TCP/1433| SQLPE
    App -->|TCP/443| KVPE
    SQLPE --> SQL
    KVPE --> KV
    ADF -->|Managed PE TCP/1433| SQLPE
    AFW -->|VPN/ExpressRoute| OnPrem[("TSE DB On-Premises")]
    ADF -->|Via Hub| OnPrem
    AVD["AVD Analytics SSMS"] -->|TCP/1433 Read-Only| SQLPE
    PDNS --- Hub
```
"@

    $fig4 = @"
```mermaid
graph TB
    Internet["Internet (User Traffic)"]

    subgraph HubVNet["Hub VNet - CCoE Managed (UK South)"]
        AppGW["App Gateway WAF v2 /24 subnet"]
        AzFW["Azure Firewall Default-deny egress"]
        DNS["Private DNS Resolver dtz.local / azure.defra.cloud"]
        VGW["VPN/ExpressRoute Gateway (to On-Prem TSE DB)"]
    end

    subgraph SpokeVNet["BSE Spoke VNet bse-spoke-prod 10.40.0.0/23"]
        subgraph AppNet["App Subnet /27 NSG: inbound 443 from AppGW only"]
            AppSvcPE["App Service Private Endpoint"]
        end
        subgraph DBNet["DB Subnet /28 NSG: inbound 1433 from App Subnet + AVD only"]
            SQLPE["Azure SQL Private Endpoint"]
            KVPE["Key Vault Private Endpoint"]
        end
    end

    Internet -->|TCP/443| AppGW
    AppGW -->|WAF Inspection| AzFW
    AzFW -->|VNet Peering Force-Tunnel| AppNet
    AppNet --> DBNet
    AzFW -->|Allow Outbound TCP/443| EntraID["Azure Entra ID (DEFRA SSO)"]
    AzFW -->|Allow Outbound TCP/443| Monitor["Azure Monitor / App Insights"]
    VGW -->|IPSec/ER Private Peering| OnPrem["On-Premises TSE Database"]
    AzFW --> VGW
    AVD["AVD (SSMS Analytics)"] -->|TCP/1433 via NSG allow| SQLPE

    Note1["Note: Non-prod spokes use 10.10-30.0.0/23. Exact subnet CIDRs CCoE-allocated. Per HLD Table 22."]
```
"@

    InsertAfterCaption "Figure 1: High Level Component Diagram" $fig1
    InsertAfterCaption "Figure 2: Interaction Diagram"          $fig2
    InsertAfterCaption "Figure 3: Physical Diagram"             $fig3
    InsertAfterCaption "Figure 4: Network Diagram"              $fig4

    # ==============================================================
    # NON-TABLE SECTION TEXT (Shared Services, Monitoring, etc.)
    # ==============================================================

    # Shared Services - Anti-Virus, Vulnerability Scanning, SOC Integration
    # These appear as section headers with empty content below them
    # We replace known placeholder-adjacent text using long replacements

    # After "Anti-Virus" we look for any blank placeholder or add text below
    # Since these don't have explicit angle-bracket placeholders, we insert
    # by finding the section heading text and appending content after it.

    function AppendAfterHeading {
        param([string]$headingText, [string]$contentText)
        $rng = $doc.Content.Duplicate
        $rng.Find.ClearFormatting()
        $rng.Find.Text = $headingText
        if ($rng.Find.Execute()) {
            $rng.Text = $headingText + [char]13 + $contentText
        }
    }

    AppendAfterHeading "Anti-Virus" "Microsoft Defender for Cloud (Defender for App Service and Defender for SQL Database) provides built-in anti-malware and threat protection for BSE PaaS services. Defender for App Service detects application-layer attacks. Defender for SQL monitors for SQL injection and suspicious query behaviour. Enabled for Production and PreProd environments. Per HLD Section 4.5 and Table 19."

    AppendAfterHeading "Vulnerability scanning" "Microsoft Defender for SQL Database provides continuous vulnerability assessment scanning. Microsoft Defender for Cloud performs infrastructure-level vulnerability scanning across App Service, Key Vault, and networking resources. Scan results are visible in the Azure Security Centre dashboard and fed into Sentinel for correlation. Per HLD Section 3.1 Step 6 and Table 20."

    AppendAfterHeading "SOC Integration" "All NSG flow logs, Azure Firewall logs, Application Gateway WAF logs, and SQL audit logs are streamed to the central CCoE Log Analytics Workspace. Microsoft Sentinel (configured with content packs and tuned detection rules for Production) provides centralised SIEM, threat correlation, and automated incident response. Alerts are routed to the CCoE SOC for security events and to application support teams for operational events. Per HLD Section 4.5 and Table 19."

    # Encryption at rest
    ReplaceLong "Encryption at Rest:" "Encryption at Rest: Azure SQL Database - Transparent Data Encryption (TDE) enabled by default for all environments. Customer-managed keys (CMK) stored in Azure Key Vault can be configured for enhanced control (per HLD Section 2.3.2). Azure App Service configuration is stored in the Azure platform with platform-managed encryption. Azure Key Vault - secrets and certificates encrypted at rest using Azure-managed keys within the service. All Azure Storage (used by ADF and Log Analytics) uses 256-bit AES encryption at rest by default. Per HLD Section 2.3.2 and HLSA Slide 13."

    ReplaceLong "Encryption in Transit:" "Encryption in Transit: All connections to BSE services enforce TLS 1.2 minimum. User-to-App Gateway: HTTPS/TLS 1.2+ (TLS policy enforced at gateway). App Service to SQL: TLS 1.2+ over TCP/1433 (enforced by Azure SQL server TLS minimum version policy). App Service to Key Vault: HTTPS/TLS 1.2+ over TCP/443. ADF to SQL (Private Endpoint): TLS 1.2+. ADF to on-premises TSE DB: TLS 1.2+ within VPN/ExpressRoute encrypted tunnel. SSMS from AVD to SQL: TLS 1.2+. Plain-text database credentials are prohibited (removed from codebase per HLSA Slide 43 security remediation). Per HLD Section 2.3.2 and 3.2.1."

    # Intrusion Detection and Prevention
    AppendAfterHeading "Intrusion Detection and Prevention" "Microsoft Sentinel provides centralised SIEM with automated threat detection, correlation rules, and incident response playbooks (Production workspace with content packs and tuned detection rules). Defender for SQL detects SQL injection, anomalous query patterns, privilege escalation, and unusual data extraction. Defender for App Service detects web application attacks, suspicious file system events, and traffic anomalies. Defender for Key Vault monitors for abnormal access patterns and credential misuse. Azure Firewall Threat Intelligence filters known malicious IPs and domains at the network perimeter. All security events are integrated with the DEFRA CCoE SOC via central Log Analytics Workspace. Per HLD Section 3.1 Step 6 and Tables 19-21."

    # Scheduling
    AppendAfterHeading "Scheduling" "Azure Data Factory pipeline triggers manage all scheduled batch operations: (1) TSE-to-BSE ingestion pipeline - triggered every business day at 00:20:00 UTC, extracts Animal/Sample/TestingGroup/Result records from the TSE database and loads them into dbo.BSESSImport in the BSE SQL Database. (2) BSE Core-to-Export pipeline - triggered every day at 07:00:00 UTC, extracts from core BSE tables (HerdSize, Farm, Case, CaseBAB, CaseRelation, Pedigree) and populates four export tables (expAge, expCase, expFarm, expRelation) for MS Access and BI analytics consumers. ADF Monitor provides execution status visibility; Azure Monitor alerts notify on failure. Per HLD Section 2.3.3."

    # Software Deployment and Management
    AppendAfterHeading "Software Deployment and Management" "Azure DevOps CI/CD pipelines manage all software deployments. Developer pushes code to GitHub (Azure Repos). CI pipeline (triggered on PR): Get Source, Install Tools, Build Solution, SAST scan (SonarCloud), Package Artifacts, Publish to Azure Artifacts. CD pipeline: Dev stage (automated, approval optional) -> Test stage (automated tests + approval) -> PreProd stage (formal CAB approval + security checks) -> Prod stage (controlled release, business sign-off, rollback plan). OIDC service connections with no long-lived secrets. Infrastructure deployed via Bicep IaC templates. Per HLD Section 2.3.5 and Tables 17-18."

    # Licensing
    AppendAfterHeading "Licensing" "All BSE Azure infrastructure uses Azure subscription-based consumption/reserved pricing. Key licensing components: Azure App Service Plan P2v3 (Prod) / P1v3 (PreProd) / S1 (Dev/Test) - standard Azure licensing per plan tier. Azure SQL Database - vCore serverless General Purpose tier, pay-per-use compute. Azure Data Factory V2 - pipeline execution and data movement units. Azure Application Insights and Log Analytics - per-GB data ingestion pricing (1GB daily cap per HLD Table 28). Azure Key Vault - standard tier (100-200 TPS per HLSA Slide 14). Azure Private Endpoints - per endpoint per hour plus data processing charges. No on-premises software licensing retained post-migration. [NEEDS INPUT: Confirm subscription/EA agreement details with DEFRA Procurement.] Per HLSA Slides 14 and 33."

    # Pre-Production and Dev/Test sections
    AppendAfterHeading "Pre-Production" "The Pre-Production (PreProd) environment provides final release candidate validation prior to Production deployment. Configuration: Azure App Service P1v3 with 2 fixed instances (zone-redundancy optional), Azure SQL Database General Purpose Serverless 8 max vCores / 50GB max storage, 30-day backup retention. Data: production-like masked/tokenised data with no live personal data (GDPR compliant). Access: release managers and operations teams; read-only for most users; full audit logging. Monitoring: production-equivalent monitoring with synthetic probes, log retention 60-90 days. Promotion gate: formal change approval (CAB), completed security checks, and approved operational readiness and rollback plan. Per HLD Section 2.3.5, Table 18."

    AppendAfterHeading "Dev/Test" "Development (dev): Azure App Service S1 / 1 instance. Azure SQL General Purpose Serverless 2 max vCores / 5GB. Synthetic data only. Developer-only access via SSO. Log retention 7-14 days. Backup retention 7 days. Promotion gate: PR review + automated unit tests. Test: Azure App Service S1 / 1 instance. Azure SQL 2 max vCores / 20GB. Masked/synthetic production-like data. Developer, tester, and integration engineer access. Log retention 14-30 days. Backup retention 14 days. Promotion gate: successful CI pipeline, automated integration/regression tests, quality and security scan thresholds met. Per HLD Section 2.3.5, Table 18."

    # Migration Details
    $migrationDetails = "The BSE database migration transfers the on-premises SQL Server database (DEFACPVWPSQL001\BSE, hosted on DEFACPVWPSQL002 in Production) to Azure SQL Database using Microsoft-supported tools. Migration method: Azure Migrate (Discovery and Assessment) for pre-migration readiness assessment, and Azure Database Migration Service (DMS) for schema and data migration. Pre-migration: non-impacting assessment of a copy of the live database to identify compatibility issues, unsupported features, schema changes, and migration blockers. Migration steps: (1) Schema migration to Azure SQL via DMS (Schema Only mode). (2) Full data migration via DMS. (3) Validate data load. (4) Execute functional and performance testing. (5) Freeze source database for final cutover (offline mode). (6) Redirect application connections to Azure SQL Database. (7) Post-cutover verification and monitoring. Downtime: zero application downtime; cutover only after validating performance and accuracy of the migrated system (parallel run). Rollback: source on-premises SQL Server remains unchanged and available until migration completion is confirmed. Data reconciliation: row count comparison, spot checks on critical tables, verification of stored procedures/views/indexes, representative query execution comparison. Acceptance criteria: 100% schema migration, 100% data migration and reconciliation, functional parity confirmed, performance benchmarks met, security controls validated, stakeholder sign-off. Per HLD Section 5.1."
    AppendAfterHeading "Migration Details" $migrationDetails

    # ==============================================================
    # DOCUMENT GENERATION SUMMARY (appended as last section)
    # ==============================================================

    $summaryText = "DOCUMENT GENERATION SUMMARY" + [char]13 + [char]13 +
        "Generation date: 2026-07-17T00:00:00Z (ISO 8601)" + [char]13 + [char]13 +
        "Sources used:" + [char]13 +
        "  - HLD.docx v0.2 (Arindrajit Sarkar, 27/04/2026)" + [char]13 +
        "  - HLSA.pptx v0.3 (LAP TWG, 13/07/2026)" + [char]13 +
        "  - LLD-Template.docx" + [char]13 + [char]13 +
        "SECTIONS AUTO-FILLED:" + [char]13 +
        "  1. Title block (Project Name, Author)" + [char]13 +
        "  2. Version History (initial entry)" + [char]13 +
        "  3. Document References (HLD v0.2, HLSA v0.3)" + [char]13 +
        "  4. Introduction body (project name, overview, component)" + [char]13 +
        "  5. HLD Deviations (HLSA vs HLD platform discrepancy noted)" + [char]13 +
        "  6. Conceptual Design overview" + [char]13 +
        "  7. Components table (C01-C05)" + [char]13 +
        "  8. Environments overview" + [char]13 +
        "  9. Server Configuration (N/A - PaaS only)" + [char]13 +
        "  10. App Services (Dev/Test/PreProd/Prod + ADF)" + [char]13 +
        "  11. API Management, APIs, Service Bus, Logic Apps (all N/A with reasons)" + [char]13 +
        "  12. Network Design (VNet config, subnets, interactions, firewall rules)" + [char]13 +
        "  13. Shared Services (Anti-Virus, Vulnerability Scanning, SOC Integration)" + [char]13 +
        "  14. Application Registrations (BSE-Portal-App, Managed Identities)" + [char]13 +
        "  15. Authentication and Authorisation tables" + [char]13 +
        "  16. Encryption at Rest and in Transit" + [char]13 +
        "  17. Intrusion Detection and Prevention" + [char]13 +
        "  18. Storage Accounts (N/A)" + [char]13 +
        "  19. Databases (bse-case-db all environments)" + [char]13 +
        "  20. Backup and Recovery" + [char]13 +
        "  21. Capacity Management, Clustering, and Resilience" + [char]13 +
        "  22. Disaster Recovery" + [char]13 +
        "  23. Infrastructure and Application Monitoring" + [char]13 +
        "  24. Scheduling (ADF pipeline triggers)" + [char]13 +
        "  25. Software Deployment and Management (CI/CD)" + [char]13 +
        "  26. Licensing" + [char]13 +
        "  27. Non-Production Environments (PreProd, Dev/Test)" + [char]13 +
        "  28. Migration Details" + [char]13 +
        "  29. All four Mermaid diagrams (Figures 1-4)" + [char]13 + [char]13 +
        "SECTIONS REQUIRING MANUAL REVIEW:" + [char]13 +
        "  - HLD Deviations table: HLD v0.2 (App Service .NET 4.8) vs HLSA v0.3 (Container Apps .NET 10) - requires architectural decision confirmation." + [char]13 +
        "  - Approval table: approver names, dates, and email addresses require human input." + [char]13 +
        "  - Security Design: WAF custom rules, Conditional Access policy specifics, PIM configuration details. [MANUAL REVIEW REQUIRED]" + [char]13 +
        "  - Risks and Open Questions: HLSA RAID items (R-001, R-002, D-003 TSE connectivity) require team review. [MANUAL REVIEW REQUIRED]" + [char]13 +
        "  - Key Vault backup/export policy: confirm with DEFRA CCoE." + [char]13 + [char]13 +
        "NEEDS INPUT items:" + [char]13 +
        "  1. Project ID - not provided in HLD or HLSA source documents." + [char]13 +
        "  2. Approval table - approver names, roles, sign-off dates, and email addresses." + [char]13 +
        "  3. Key Vault backup/export policy details - confirm with DEFRA CCoE." + [char]13 +
        "  4. Subscription/EA agreement details - confirm with DEFRA Procurement." + [char]13 +
        "  5. Additional approver row in Approval table." + [char]13 +
        "  6. Exact subnet CIDR allocations for non-Prod environments (CCoE-allocated)." + [char]13 + [char]13 +
        "ASSUMPTIONS MADE:" + [char]13 +
        "  - Application targets .NET Framework 4.8 on Azure App Service per HLD v0.2 (not Container Apps per HLSA)." + [char]13 +
        "  - Naming convention applied: bse-portal-svc (web app), bse-case-db (database), bse-integration-svc (ADF), bse-spoke-{env} (VNets)." + [char]13 +
        "  - Four environments: dev, test, preprod, prod in UK South as per HLD Section 1.5." + [char]13 +
        "  - Spoke VNet address spaces 10.10-40.0.0/23 per HLD Table 22; hub VNet CCoE-managed." + [char]13 +
        "  - Resource groups follow pattern rg-bse-{env} and subscriptions bse-sub-{env}." + [char]13 +
        "  - ADF pipeline schedules (00:20 and 07:00 UTC) sourced from HLD Section 2.3.3." + [char]13 +
        "  - Backup retention periods sourced from HLD Section 4.4." + [char]13 +
        "  - App Service tier sizing sourced from HLD Table 7." + [char]13 +
        "  - Database sizing sourced from HLD Table 14 and HLSA Slide 14."

    # Append summary at end of document
    $endPos = $doc.Content.End - 1
    $endRng = $doc.Range($endPos, $endPos)
    $endRng.InsertAfter([char]13 + $summaryText)

    # Save the final document
    $doc.Save()
    Write-Host "SUCCESS: LLD generated at $outputPath"

} catch {
    Write-Error "Generation failed: $_"
    Write-Error $_.ScriptStackTrace
} finally {
    if ($doc) { $doc.Close($false) }
    $word.Quit()
    $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word)
}
