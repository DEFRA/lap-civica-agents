# generate-lld-bse-v2.ps1
# Generates LLD-BSE-Populated.docx from LLD-Template.docx
# Sources: HLD.docx (updated, .NET 10) and HLSA.pptx (v0.3)
# Rules applied: Instructions Sections 9, 10, 11, 13
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
    # Helper: Long replacement (>200 chars) - locate and overwrite
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
    # Helper: Insert content after a body-section heading
    # Rules 10 + 11:
    #   - Skip TOC / List-of-Figures / Table-of-Tables paragraph matches
    #   - If the next paragraph after the heading is itself a heading,
    #     create a new Normal paragraph before inserting content
    # ---------------------------------------------------------------
    function AppendAfterHeading {
        param([string]$headingText, [string]$contentText)

        $skipStyleSubstrings = @("TOC", "Table of", "Tableof", "List of", "Contents")

        $rng = $doc.Content.Duplicate
        $rng.Find.ClearFormatting()
        $rng.Find.Text = $headingText

        $found = $false
        while ($rng.Find.Execute()) {
            # Check the style of the matched paragraph
            $styleName = ""
            try { $styleName = $rng.Paragraphs(1).Style.NameLocal } catch { }

            $isNavStyle = $false
            foreach ($skip in $skipStyleSubstrings) {
                if ($styleName -like "*$skip*") { $isNavStyle = $true; break }
            }
            if ($isNavStyle) { continue }

            # Found a body-style match. Now check the next paragraph (Rule 11).
            $nextPara = $null
            try { $nextPara = $rng.Paragraphs(1).Next() } catch { }

            if ($nextPara -ne $null) {
                $nextStyle = ""
                try { $nextStyle = $nextPara.Style.NameLocal } catch { }

                if ($nextStyle -like "*Heading*") {
                    # Consecutive heading — insert a new Normal paragraph after current heading
                    $insertRng = $rng.Paragraphs(1).Range.Duplicate
                    $insertRng.Collapse(0) # collapse to end
                    $insertRng.InsertParagraphAfter()
                    # Move to the newly inserted paragraph
                    $newPara = $rng.Paragraphs(1).Next()
                    $newPara.Style = $doc.Styles("Normal")
                    $newPara.Range.Text = $contentText
                } else {
                    # Normal case — next para is a body paragraph, insert at its start
                    $nextPara.Range.InsertBefore($contentText + [char]13)
                }
            } else {
                # End of document — collapse to end of match and insert
                $insertRng = $rng.Duplicate
                $insertRng.Collapse(0)
                $insertRng.InsertParagraphAfter()
                $insertRng.Text = $contentText
            }

            $found = $true
            break
        }
        if (-not $found) { Write-Warning "Heading not found: $headingText" }
    }

    # ---------------------------------------------------------------
    # Helper: Insert Mermaid block after a Figure caption paragraph
    # Rule 10: skip TOC/List matches; loop to body-style match
    # ---------------------------------------------------------------
    function InsertAfterCaption {
        param([string]$captionText, [string]$mermaidBlock)

        $skipStyleSubstrings = @("TOC", "Table of", "Tableof", "List of", "Contents", "Figure")

        $rng = $doc.Content.Duplicate
        $rng.Find.ClearFormatting()
        $rng.Find.Text = $captionText

        $found = $false
        while ($rng.Find.Execute()) {
            $styleName = ""
            try { $styleName = $rng.Paragraphs(1).Style.NameLocal } catch { }

            $isNavStyle = $false
            foreach ($skip in $skipStyleSubstrings) {
                if ($styleName -like "*$skip*") { $isNavStyle = $true; break }
            }

            # Accept Caption style or any body-level paragraph that is not TOC/List
            $isBodyCaption = ($styleName -like "*Caption*") -or ($styleName -eq "Normal") -or ($styleName -like "*Heading*") -or ($styleName -eq "")
            if ($isNavStyle -and $styleName -notlike "*Caption*") { continue }

            # Insert the mermaid block after this paragraph
            $insertRng = $rng.Paragraphs(1).Range.Duplicate
            $insertRng.Collapse(0)
            $insertRng.InsertParagraphAfter()
            $newPara = $rng.Paragraphs(1).Next()
            if ($newPara -ne $null) {
                $newPara.Style = $doc.Styles("Normal")
                $newPara.Range.Text = $mermaidBlock
            } else {
                $insertRng.Text = $mermaidBlock
            }
            $found = $true
            break
        }
        if (-not $found) { Write-Warning "Caption not found: $captionText" }
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

    $overviewSolution = "The BSE (Bovine Spongiform Encephalopathy) system is migrated from a legacy on-premises Windows Server 2016 / IIS environment to a secure Azure cloud-native platform aligned with Defra CCoE standards. The target architecture adopts a Hub-and-Spoke Azure Virtual Network topology in UK South. The BSE web application runs on Azure App Service (.NET 10) with a Private Endpoint, backed by Azure SQL Database (Serverless, General Purpose). Authentication migrates from Windows Authentication to Azure Entra ID via DEFRA SAML 2.0 SSO. Azure Data Factory orchestrates two scheduled pipelines: TSE-to-BSE data ingestion (daily 00:20) and BSE Core-to-Export tables (daily 07:00). All inter-service communication uses Private Endpoints, governed by NSGs, Azure Firewall, and Azure Key Vault for secrets management. Per HLD Section 2.3.1 and HLSA Slide 9."
    ReplaceLong "<overview of solution>" $overviewSolution

    $envOverview = "Four environments are provisioned in Azure UK South: Development (dev) for active feature development using synthetic data only; Test for integration and regression testing using masked data; Pre-Production (preprod) for release candidate validation with production-like masked data and performance rehearsal; and Production (prod) for live BSE case management with zone-redundant deployment, full Defender coverage, MFA-enforced access, and policy-driven log retention. Per HLD Section 2.3.5, Table 18."
    ReplaceLong "<high level overview of environments and purpose>" $envOverview

    $ingressDetails = "All inbound user traffic enters on TCP/443 (HTTPS) through the CCoE-managed Application Gateway (WAF v2) in the Hub VNet. The WAF applies Microsoft-managed OWASP rule sets and custom rules to block SQL injection, XSS, CSRF, and other OWASP Top 10 threats before forwarding requests to the BSE App Service Private Endpoint. DNS resolution is handled by the Hub Private DNS Resolver, forwarding to Azure DNS (168.63.129.16) with conditional forwarding to Infoblox for non-Azure domains. The BSE application domain is bse.azure.defra.cloud (Private DNS Zone: azure.defra.cloud). No direct public access to the App Service or SQL Database is permitted. Per HLD Section 3.2.1, Tables 23 and 24."
    ReplaceLong "<Ingress Details>" $ingressDetails

    $egressDetails = "All outbound traffic from spoke subnets is force-routed through the Hub Azure Firewall with a default-deny egress policy. Explicit allow rules permit: TCP/443 to Azure Entra ID (AzureActiveDirectory FQDN tag); TCP/1433 to Azure SQL via Private Endpoint; TCP/443 to Azure Key Vault via Private Endpoint; TCP/443 to Azure Storage via Private Endpoint; TCP/443 to Azure Monitor / Application Insights (AzureMonitor FQDN tag); TCP/1433 from ADF IR to on-premises TSE Database via VPN/ExpressRoute; TCP/443 to approved third-party API FQDNs. All other internet egress is blocked by Rule Deny-Internet-Egress-Default (Priority 65000). Per HLD Section 3.2.1, Tables 23 and 25."
    ReplaceLong "<Egress Details>" $egressDetails

    $extToExt = "N/A - BSE does not support direct external-to-external traffic flows. All external connectivity is routed through the Hub VNet security controls (Azure Firewall and Application Gateway WAF). Per HLD Section 3.2.1."
    ReplaceLong "<External to External> Details" $extToExt

    # ==============================================================
    # PASS 3 - Table population
    # ==============================================================

    # T1: Title block (3 rows x 2 cols)
    SetCell 1 1 2 "BSE - Bovine Spongiform Encephalopathy"
    SetCell 1 2 2 "[NEEDS INPUT: Project ID not provided in HLD or HLSA source documents]"
    SetCell 1 3 2 "Arindrajit Sarkar (Lead Technical Architect); Arunkumar AS (Technical Architect)"

    # T2: Version History (6 rows x 4 cols)
    SetCell 2 2 1 "0.1"
    SetCell 2 2 2 "2026-07-17"
    SetCell 2 2 3 "LLD Author"
    SetCell 2 2 4 "Initial LLD draft. Based on updated HLD (.NET 10) and HLSA v0.3."

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
    SetCell 4 2 1 "HLD - Bovine Spongiform Encephalopathy High Level Design (updated, .NET 10)"
    SetCell 4 2 2 "Updated 17/07/2026"
    SetCell 4 3 1 "HLSA - LAP Portfolio BSE High Level System Architecture Overview for SDA"
    SetCell 4 3 2 "0.3"

    # T5: HLD Deviations (2 rows x 2 cols)
    SetCell 5 2 1 "None. The updated HLD now targets .NET 10 on Azure App Service, aligning with HLSA v0.3 Slide 15. No platform discrepancy remains between source documents."
    SetCell 5 2 2 "N/A - sources are now aligned. Per updated HLD Sections 1.5 and 2.3.1."

    # T6: Build Deviations (3 rows x 2 cols)
    SetCell 6 2 1 "Not applicable - build not commenced at time of initial LLD authoring (July 2026)."
    SetCell 6 2 2 "To be updated following completion of the Implementation phase per HLD Section 2.1."
    SetCell 6 3 1 "N/A"
    SetCell 6 3 2 "N/A"

    # T7: Components (6 rows x 3 cols)
    SetCell 7 2 1 "C01"
    SetCell 7 2 2 "BSE Web Application (bse-portal-svc)"
    SetCell 7 2 3 "ASP.NET .NET 10 web application managing BSE case workflows, deployed on Azure App Service with Private Link. Accessed via CCoE Application Gateway / WAF. Per updated HLD Section 2.3.1 Step 3."
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

    # T8: Server Configuration - N/A (PaaS only)
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
    SetCell 9 2 1 "bse-portal-svc-prod"
    SetCell 9 2 2 "Web App (.NET 10 on Windows)"
    SetCell 9 2 3 "P2v3 Zone-Redundant, 2-4 instances autoscale"
    SetCell 9 2 4 "BSE production case management portal. Always On enabled."
    SetCell 9 2 5 "rg-bse-prod"
    SetCell 9 2 6 "UK South"
    SetCell 9 2 7 "bse.azure.defra.cloud"
    SetCell 9 3 1 "bse-portal-svc-preprod"
    SetCell 9 3 2 "Web App (.NET 10 on Windows)"
    SetCell 9 3 3 "P1v3, 2 fixed instances (zone-redundancy optional)"
    SetCell 9 3 4 "BSE pre-production release candidate validation."
    SetCell 9 3 5 "rg-bse-preprod"
    SetCell 9 3 6 "UK South"
    SetCell 9 3 7 "bse-preprod.azure.defra.cloud"
    SetCell 9 4 1 "bse-portal-svc-test"
    SetCell 9 4 2 "Web App (.NET 10 on Windows)"
    SetCell 9 4 3 "S1, 1 instance"
    SetCell 9 4 4 "BSE integration and regression testing environment."
    SetCell 9 4 5 "rg-bse-test"
    SetCell 9 4 6 "UK South"
    SetCell 9 4 7 "bse-test.azure.defra.cloud"
    SetCell 9 5 1 "bse-portal-svc-dev"
    SetCell 9 5 2 "Web App (.NET 10 on Windows)"
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
    SetCell 15 5 1 "Note: All subnets are associated with a dedicated NSG per DEFRA Azure Policy. Per HLD Section 3.2.1 Step 3 and Table 22."
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
    SetCell 16 2 1 "NI-001"
    SetCell 16 2 2 "Internet (APHA User Browser)"
    SetCell 16 2 3 "App Gateway WAF v2 (Hub VNet, TCP/443)"
    SetCell 16 2 4 "TCP/443 HTTPS"
    SetCell 16 2 5 "User HTTPS traffic enters via the CCoE-managed Application Gateway WAF v2. WAF applies OWASP rule sets before routing to BSE App Service Private Endpoint. No direct public access. Per HLD Table 23 Rule Inbound-HTTPS-to-App-Entry and Table 24."
    SetCell 16 3 1 "NI-002"
    SetCell 16 3 2 "BSE App Service (bse-app-snet-{env})"
    SetCell 16 3 3 "Azure SQL Private Endpoint (bse-db-snet-{env})"
    SetCell 16 3 4 "TCP/1433 TLS 1.2+"
    SetCell 16 3 5 "App Service connects to Azure SQL via Private Endpoint using Managed Identity. SQL public network access disabled. NSG Rule 151 restricts inbound to App Subnet only. Per HLD Section 2.3.2 and Tables 23, 26."
    SetCell 16 4 1 "NI-003"
    SetCell 16 4 2 "Azure Data Factory IR (bse-integration-svc)"
    SetCell 16 4 3 "TSE Database (tses.data.prd1.prd.cerespfm.cloud) via Hub VPN/ExpressRoute"
    SetCell 16 4 4 "TCP/1433 within VPN/ER tunnel"
    SetCell 16 4 5 "ADF pipelines extract TSE data daily at 00:20 via VPN/ExpressRoute through Hub firewall. Secured by Managed Identity and Managed Private Endpoints. Per HLD Section 2.3.3, Table 23 Rule Outbound-OnPrem-SQL, and HLSA Slide 29 D-003."

    # T17: Application Registrations (4 rows x 3 cols)
    SetCell 17 2 1 "BSE-Portal-App"
    SetCell 17 2 2 "DEFRA Azure Entra ID tenant"
    SetCell 17 2 3 "BSE web application authentication via DEFRA SAML 2.0 SSO. Per-environment redirect URIs: Dev (SAML Test), Test (SAML QA), PreProd/Prod (DEFRA SAML). No secrets stored in application code. Per HLD Table 6."
    SetCell 17 3 1 "BSE-AppService-ManagedIdentity"
    SetCell 17 3 2 "DEFRA Azure Entra ID tenant"
    SetCell 17 3 3 "System-assigned Managed Identity for BSE App Service. Grants passwordless access to Azure SQL (Entra ID auth) and Azure Key Vault (Secrets User role). Per HLD Section 2.3.1 Step 3."
    SetCell 17 4 1 "BSE-ADF-ManagedIdentity"
    SetCell 17 4 2 "DEFRA Azure Entra ID tenant"
    SetCell 17 4 3 "System-assigned Managed Identity for Azure Data Factory. Grants access to Azure SQL and Azure Key Vault linked service credentials. Per HLD Section 2.3.3."

    # T18: Authentication (5 rows x 2 cols)
    SetCell 18 2 1 "User to BSE Portal (NI-001)"
    SetCell 18 2 2 "Azure Entra ID SAML 2.0 SSO (DEFRA SSO). MFA enforced via Conditional Access policies. JWT token issued to application. Legacy authentication protocols blocked. Per HLD Section 2.3.1 Step 1 and Table 6."
    SetCell 18 3 1 "BSE App Service to Azure SQL (NI-002)"
    SetCell 18 3 2 "Managed Identity (system-assigned). No passwords or connection string secrets in code. Azure SQL configured for Entra ID-only authentication. Per HLD Section 2.3.2."
    SetCell 18 4 1 "ADF to Azure SQL and TSE Database (NI-003)"
    SetCell 18 4 2 "Managed Identity for Azure SQL connectivity. VPN/ExpressRoute with hub-governed routing for on-premises TSE database. ADF Linked Services configured via Managed Private Endpoints. Per HLD Section 2.3.3."
    SetCell 18 5 1 "AVD Data Analytics Users to Azure SQL (NI-004)"
    SetCell 18 5 2 "Azure Entra ID with MFA enforced via Conditional Access. SSMS connects from AVD using Entra ID group membership. Restricted to approved AVD subnet only; no on-premises or internet direct access permitted. Per HLD Section 3.1 and NSG Rule 152 (Table 26)."

    # T19: Authorisation (12 rows x 2 cols)
    SetCell 19 2 1 "BSE Portal - Case Officers / Data Entry"
    SetCell 19 2 2 "Role-based access via Azure Entra ID Security Group membership mapped to BSE application roles (Data Entry, VLA Maintenance, DEFRA Maintenance). Claims from JWT token drive application-level authorisation. Per HLD Section 2.3.1 and Table 5."
    SetCell 19 3 1 "BSE Portal - AMS Data Analytics Users"
    SetCell 19 3 2 "AMS staff access BSE Portal per assigned Entra ID group. Additional direct database access (SSMS via AVD) with read-only SQL role db_datareader. Per HLD Section 3.1 and HLSA Slide 11."
    SetCell 19 4 1 "BSE Portal - Internal Business Users (APHA)"
    SetCell 19 4 2 "APHA staff access BSE Portal with permissions per assigned Entra ID group. Role assignments managed centrally; no individual-to-application assignments. Per HLD Table 5."
    SetCell 19 5 1 "Azure Resources - RBAC"
    SetCell 19 5 2 "Least-privilege Azure RBAC. CCoE engineers manage NSGs/Firewall via PIM-elevated Contributor role. Production changes require PIM elevation with approval and time-limited access. Delete locks on Production NSGs. Per HLD Section 3.1 Steps 7-9."
    SetCell 19 6 1 "Azure SQL Database - Admin and DBA Access"
    SetCell 19 6 2 "Database administrators authenticated via Entra ID group. Elevated access granted via PIM (just-in-time, approval-based, time-limited). Regular SQL logins disabled unless required. Per HLD Section 2.3.2."
    SetCell 19 7 1 "Azure Key Vault"
    SetCell 19 7 2 "App Service and ADF access Key Vault via Managed Identity with Key Vault Secrets User RBAC role. No direct human access in Production except via PIM. Defender for Key Vault monitors for anomalous access. Per HLD Section 3.1 Step 4."
    SetCell 19 8 1 "Azure DevOps CI/CD Pipelines"
    SetCell 19 8 2 "Pipeline service connections use OIDC with workload identity federation. No long-lived secrets in pipelines. Deployment approval gates required for PreProd and Prod stages. Per HLD Section 2.3.5."
    for ($r = 9; $r -le 12; $r++) { SetCell 19 $r 1 "N/A"; SetCell 19 $r 2 "N/A" }

    # T20: Encryption in Transit (12 rows x 4 cols)
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
    SetCell 21 2 1 "N/A - BSE does not require dedicated Azure Storage Accounts in this LLD scope. Case documents are stored in SharePoint Online (outside this Azure landing zone). Per HLD Section 2.3.4."
    for ($c = 2; $c -le 8; $c++) { SetCell 21 2 $c "N/A" }
    for ($r = 3; $r -le 5; $r++) { for ($c = 1; $c -le 8; $c++) { SetCell 21 $r $c "N/A" } }

    # T22: Databases (3 rows x 7 cols)
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
    SetCell 22 3 6 "Dev/Test: 2 max vCores, 5GB/20GB max. PreProd: 8 max vCores, 50GB max. General Purpose Serverless. Per HLD Table 14."
    SetCell 22 3 7 "bse-case-db-{env}.database.windows.net"

    # T23: Backup and Recovery (4 rows x 2 cols)
    SetCell 23 2 1 "Azure SQL Database (bse-case-db)"
    SetCell 23 2 2 "Automated backups: full weekly, differential daily, transaction log every 5-10 min. ZRS-redundant backup storage. Point-in-time restore within retention period. Retention: Prod 35 days, PreProd 30 days, Test 14 days, Dev 7 days. Application data retained for extended periods per compliance. Per HLD Section 4.4."
    SetCell 23 3 1 "BSE Web Application (bse-portal-svc)"
    SetCell 23 3 2 "Application code managed in GitHub (Azure Repos). Deployment slots enable zero-downtime rollout and rapid rollback via Azure DevOps CI/CD. No independent application backup required - redeployment from pipeline is the recovery mechanism. Per HLD Section 2.3.5."
    SetCell 23 4 1 "Azure Key Vault"
    SetCell 23 4 2 "Soft delete enabled with 90-day retention and purge protection active in Production. Secrets are versioned; previous versions recoverable. [NEEDS INPUT: Confirm Key Vault backup/export policy with DEFRA CCoE.] [MANUAL REVIEW REQUIRED]"

    # T24: Clustering / Resilience (4 rows x 2 cols)
    SetCell 24 2 1 "Azure App Service (bse-portal-svc)"
    SetCell 24 2 2 "Production: P2v3 zone-redundant App Service Plan with 2-4 instance auto-scale. Deployment slots for blue/green deployment. Auto-heal and Always On enabled. PreProd: P1v3 with 2 fixed instances. Dev/Test: S1 with 1 instance (no zone redundancy). Per HLD Section 4.1 and Table 7."
    SetCell 24 3 1 "Azure SQL Database (bse-case-db)"
    SetCell 24 3 2 "Production: Zone-redundant serverless vCore. Always On architecture with replicas across availability zones. Auto-failover group with secondary in paired region (DR). ZRS backup storage. RPO: minutes; RTO: 8-48 hours for regional failover. Dev/Test: DR disabled. Per HLD Sections 4.2, 4.3 and Table 27."
    SetCell 24 4 1 "Azure Data Factory (bse-integration-svc)"
    SetCell 24 4 2 "Managed Azure Integration Runtime provides built-in HA and zone-redundant execution. Pipeline-level retry policies for transient failures. Azure Monitor alerts on failure, prolonged runtime, or retry exhaustion. SLA: pipelines complete within scheduled window (Tier 3 RTO: 4 hours). Per HLD Section 2.3.3 and Table 27."

    # ==============================================================
    # FIGURE MERMAID DIAGRAMS
    # Rule 10: InsertAfterCaption skips TOC/List-of-Figures matches
    # ==============================================================

    $fig1 = @"
```mermaid
graph TD
    User["APHA Internal Users"] -->|HTTPS/TLS 1.2+| AppGW["App Gateway WAF v2 (CCoE Managed)"]
    AppGW -->|Private Endpoint| BSEApp["bse-portal-svc (Azure App Service .NET 10)"]
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
    participant App as BSE Web App (.NET 10)
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

    Note over ADF,TSE: Daily 00:20 - TSE to BSE ingestion
    ADF->>TSE: Extract surveillance data (VPN/ExpressRoute)
    TSE-->>ADF: Animal/Sample/TestingGroup/Result records
    ADF->>SQL: Load into dbo.BSESSImport

    Note over ADF,SQL: Daily 07:00 - BSE Core to Export
    ADF->>SQL: Extract from core BSE tables
    ADF->>SQL: Load expAge/expCase/expFarm/expRelation
```
"@

    $fig3 = @"
```mermaid
graph LR
    subgraph Hub["Hub VNet (CCoE Managed - UK South)"]
        AFW["Azure Firewall"]
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
        App["bse-portal-svc App Service .NET 10 P2v3"]
        SQL[("bse-case-db Azure SQL Serverless")]
        ADF["bse-integration-svc ADF V2"]
        KV["Azure Key Vault"]
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
    AVD["AVD Analytics SSMS"] -->|TCP/1433 Read-Only NSG Rule 152| SQLPE
```
"@

    $fig4 = @"
```mermaid
graph TB
    Internet["Internet (User Traffic)"]

    subgraph HubVNet["Hub VNet - CCoE Managed (UK South)"]
        AppGW["App Gateway WAF v2"]
        AzFW["Azure Firewall (Default-deny egress)"]
        DNS["Private DNS Resolver (azure.defra.cloud)"]
        VGW["VPN/ExpressRoute Gateway"]
    end

    subgraph SpokeVNet["BSE Spoke VNet bse-spoke-prod 10.40.0.0/23"]
        subgraph AppNet["App Subnet /27 - NSG inbound 443 from AppGW only"]
            AppSvcPE["App Service Private Endpoint"]
        end
        subgraph DBNet["DB Subnet /28 - NSG inbound 1433 from App + AVD only"]
            SQLPE["Azure SQL Private Endpoint"]
            KVPE["Key Vault Private Endpoint"]
        end
    end

    Internet -->|TCP/443| AppGW
    AppGW -->|WAF Inspection| AzFW
    AzFW -->|VNet Peering Force-Tunnel| AppNet
    AppNet --> DBNet
    AzFW -->|Allow TCP/443| EntraID["Azure Entra ID (DEFRA SSO)"]
    AzFW -->|Allow TCP/443| Monitor["Azure Monitor / App Insights"]
    VGW -->|IPSec/ER Private Peering| OnPrem["On-Premises TSE Database"]
    AzFW --> VGW
    AVD["AVD (SSMS Analytics)"] -->|TCP/1433 via NSG allow| SQLPE
```
"@

    InsertAfterCaption "Figure 1: High Level Component Diagram" $fig1
    InsertAfterCaption "Figure 2: Interaction Diagram"          $fig2
    InsertAfterCaption "Figure 3: Physical Diagram"             $fig3
    InsertAfterCaption "Figure 4: Network Diagram"              $fig4

    # ==============================================================
    # SECTION TEXT - using Rule 11 aware AppendAfterHeading
    # Anti-Virus, Vulnerability scanning, SOC Integration are
    # consecutive headings - Rule 11 inserts new Normal paragraph
    # ==============================================================

    AppendAfterHeading "Anti-Virus" "Microsoft Defender for Cloud (Defender for App Service and Defender for SQL Database) provides built-in anti-malware and threat protection for BSE PaaS services. Defender for App Service detects application-layer attacks. Defender for SQL monitors for SQL injection and suspicious query behaviour. Enabled for Production and PreProd environments. Per HLD Section 4.5 and Table 19."

    AppendAfterHeading "Vulnerability scanning" "Microsoft Defender for SQL Database provides continuous vulnerability assessment scanning. Microsoft Defender for Cloud performs infrastructure-level vulnerability scanning across App Service, Key Vault, and networking resources. Scan results are visible in the Azure Security Centre dashboard and fed into Sentinel for correlation. Per HLD Section 3.1 Step 6 and Table 20."

    AppendAfterHeading "SOC Integration" "All NSG flow logs, Azure Firewall logs, Application Gateway WAF logs, and SQL audit logs are streamed to the central CCoE Log Analytics Workspace. Microsoft Sentinel (configured with content packs and tuned detection rules for Production) provides centralised SIEM, threat correlation, and automated incident response. Alerts route to the CCoE SOC for security events and to application support teams for operational events. Per HLD Section 4.5 and Table 19."

    # Encryption at rest and in transit
    ReplaceLong "Encryption at Rest:" "Encryption at Rest: Azure SQL Database - Transparent Data Encryption (TDE) enabled by default for all environments; customer-managed keys (CMK) in Azure Key Vault available for enhanced control (per HLD Section 2.3.2). Azure Key Vault - secrets and certificates encrypted at rest using Azure-managed keys. All Azure Storage used by ADF and Log Analytics uses 256-bit AES encryption at rest by default. Per HLD Section 2.3.2 and HLSA Slide 13."

    ReplaceLong "Encryption in Transit:" "Encryption in Transit: All connections enforce TLS 1.2 minimum. User-to-App Gateway: HTTPS/TLS 1.2+. App Service to SQL: TLS 1.2+ over TCP/1433 (Azure SQL server TLS minimum version policy). App Service to Key Vault: HTTPS/TLS 1.2+. ADF to SQL (Private Endpoint): TLS 1.2+. ADF to on-premises TSE DB: TLS 1.2+ within VPN/ExpressRoute encrypted tunnel. SSMS from AVD to SQL: TLS 1.2+. Plain-text database credentials are prohibited (remediated per HLSA Slide 43 security findings). Per HLD Section 2.3.2 and 3.2.1."

    AppendAfterHeading "Intrusion Detection and Prevention" "Microsoft Sentinel provides centralised SIEM with automated threat detection and incident response (Production workspace with content packs and tuned detection rules). Defender for SQL detects SQL injection, anomalous query patterns, privilege escalation, and unusual data extraction. Defender for App Service detects web application attacks and suspicious traffic anomalies. Defender for Key Vault monitors for abnormal access patterns. Azure Firewall Threat Intelligence filters known malicious IPs and domains. All security events feed into the DEFRA CCoE SOC via the central Log Analytics Workspace. Per HLD Section 3.1 Step 6 and Tables 19-21. [MANUAL REVIEW REQUIRED]"

    AppendAfterHeading "Scheduling" "Azure Data Factory pipeline triggers manage all scheduled batch operations: (1) TSE-to-BSE ingestion pipeline - triggered every business day at 00:20:00 UTC, extracts Animal/Sample/TestingGroup/Result records from the TSE database and loads them into dbo.BSESSImport in the BSE SQL Database. (2) BSE Core-to-Export pipeline - triggered every day at 07:00:00 UTC, extracts from core BSE tables (HerdSize, Farm, Case, CaseBAB, CaseRelation, Pedigree) and populates four export tables (expAge, expCase, expFarm, expRelation) for MS Access and BI analytics consumers. ADF Monitor tracks execution; Azure Monitor alerts on failure. Per HLD Section 2.3.3."

    AppendAfterHeading "Software Deployment and Management" "Azure DevOps CI/CD pipelines manage all software deployments. Developer pushes code to GitHub (Azure Repos). CI pipeline: Get Source, Install Tools, Build Solution (.NET 10), SAST scan (SonarCloud), Package Artifacts, Publish to Azure Artifacts. CD pipeline: Dev (automated, optional approval) -> Test (automated tests + approval) -> PreProd (CAB approval + security checks) -> Prod (controlled release, business sign-off, rollback plan). OIDC service connections with no long-lived secrets. Infrastructure deployed via Bicep IaC templates. Per HLD Section 2.3.5 and Tables 17-18."

    AppendAfterHeading "Licensing" "All BSE Azure infrastructure uses Azure subscription-based consumption pricing. Key licensing components: Azure App Service Plan P2v3 (Prod) / P1v3 (PreProd) / S1 (Dev/Test). Azure SQL Database - vCore serverless General Purpose tier, pay-per-use compute. Azure Data Factory V2 - pipeline execution and data movement units. Azure Application Insights and Log Analytics - per-GB data ingestion pricing (1GB daily cap per HLD Table 28). Azure Key Vault standard tier (100-200 TPS per HLSA Slide 14). Azure Private Endpoints - per endpoint per hour plus data processing. No on-premises software licensing retained post-migration. [NEEDS INPUT: Confirm subscription/EA agreement details with DEFRA Procurement.] Per HLSA Slides 14 and 33."

    AppendAfterHeading "Pre-Production" "The Pre-Production (PreProd) environment provides final release candidate validation. Configuration: Azure App Service P1v3 with 2 fixed instances (zone-redundancy optional), Azure SQL General Purpose Serverless 8 max vCores / 50GB, 30-day backup retention. Data: production-like masked/tokenised data, no live personal data (GDPR compliant). Access: release managers and operations teams; read-only for most users; full audit logging. Monitoring: production-equivalent monitoring with synthetic probes, log retention 60-90 days. Promotion gate: formal CAB approval, completed security checks, approved operational readiness and rollback plan. Per HLD Section 2.3.5 and Table 18."

    AppendAfterHeading "Dev/Test" "Development (dev): Azure App Service S1 / 1 instance. Azure SQL General Purpose Serverless 2 max vCores / 5GB. Synthetic data only. Developer-only access via SSO. Log retention 7-14 days. Backup retention 7 days. Promotion gate: PR review + automated unit tests. Test: Azure App Service S1 / 1 instance. Azure SQL 2 max vCores / 20GB. Masked/synthetic data. Developer, tester, and integration engineer access. Log retention 14-30 days. Backup retention 14 days. Promotion gate: CI pipeline, automated integration/regression tests, quality and security scan thresholds met. Per HLD Section 2.3.5 and Table 18."

    $migrationDetails = "The BSE database migration transfers the on-premises SQL Server database (DEFACPVWPSQL001\BSE, hosted on DEFACPVWPSQL002) to Azure SQL Database using Microsoft-supported tools. Migration method: Azure Migrate (Discovery and Assessment) for pre-migration readiness assessment of a copy of the live database; Azure Database Migration Service (DMS) for schema and data migration. Migration steps: (1) Schema migration to Azure SQL via DMS (Schema Only). (2) Full data migration via DMS. (3) Validate data load. (4) Functional and performance testing. (5) Freeze source database for final cutover. (6) Redirect application connections to Azure SQL. (7) Post-cutover verification. Downtime: zero - cutover only after validating performance and accuracy (parallel run). Rollback: source on-premises SQL Server remains available until migration confirmed. Reconciliation: row count comparison, spot checks on critical tables, stored procedure and index verification, representative query comparison. Acceptance criteria: 100% schema migration, 100% data migration and reconciliation, functional parity confirmed, performance benchmarks met, security controls validated, stakeholder sign-off obtained. Per HLD Section 5.1."
    AppendAfterHeading "Migration Details" $migrationDetails

    # ==============================================================
    # NOTE: Per instruction Section 13 - Document Generation Summary
    # is NOT appended to the DOCX. It is written to the companion
    # LLD-BSE-Summary.md file only.
    # ==============================================================

    $doc.Save()
    Write-Host "SUCCESS: LLD generated at $outputPath"

} catch {
    Write-Error "Generation failed: $_"
    Write-Error $_.ScriptStackTrace
} finally {
    if ($doc) { $doc.Close($false) }
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}
