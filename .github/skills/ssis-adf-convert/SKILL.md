---
name: ssis-adf-convert
description: Analyze SSIS packages, produce ADF artifacts, and generate migration reporting using concise instruction-only playbooks.
metadata:
  id: ssis-adf-convert
  version: 1.0.0
  owner: Data Engineering
  recommended_agent: SSIS to ADF Migration Agent
  execution_model: instruction-only
  scope_includes:
    - SSIS package analysis
    - SSIS-to-ADF artifact conversion
    - Migration reporting
  scope_excludes:
    - Runtime deployment to Azure subscriptions
    - Secret storage and credential provisioning
    - In-place modification of original SSIS files
  inputs_required:
    - packagePath (single .dtsx per run)
    - outputPath
  execution_rules:
    - Analyze exactly one SSIS package per run.
    - If a folder or multiple packages are provided, request one packagePath and stop.
---
 
# SSIS to ADF Conversion (Skill)
 
This skill package defines a repeatable SSIS-to-ADF modernization workflow.
 
Execution model: **instruction-only** (no scripts required).
 
## Playbooks
 
- [01 SSIS Analysis](./01-ssis-analysis.md)
- [02 SSIS to ADF Artifact Conversion](./02-ssis-to-adf-artifact-conversion.md)
- [03 Migration Reporting](./03-migration-reporting.md)
 
## Templates
 
- [SSIS Analysis Report Template](./templates/ssis-analysis-report.md)
- [Migration Report Template](./templates/migration-report.md)