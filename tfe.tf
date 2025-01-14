module "station-tfe" {
  source = "./hashicorp/tfe/"

  organization_name     = var.tfe.organization_name
  project_name          = var.tfe.project_name
  workspace_name        = var.tfe.workspace_name
  workspace_description = var.tfe.workspace_description
  vcs_repo              = try(var.tfe.vcs_repo, null)
  workspace_env_vars = merge(try(var.tfe.env_vars, {}), {
    # DOCS: https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration#configure-terraform-cloud
    TFC_AZURE_PROVIDER_AUTH = {
      value       = true
      category    = "env"
      description = "Is true when using dynamic credentials to authenticate to Azure. https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration#configure-terraform-cloud"
    },
    TFC_AZURE_RUN_CLIENT_ID = {
      value       = module.user_assigned_identity.client_id
      category    = "env"
      description = "The client ID for the Service Principal / Application used when authenticating to Azure. https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration#configure-terraform-cloud"
    },
    ARM_SUBSCRIPTION_ID = {
      value       = data.azurerm_client_config.current.subscription_id
      category    = "env"
      description = "The Subscription ID to connect to. https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration#configure-the-azurerm-or-azuread-provider"
    },
    ARM_TENANT_ID = {
      value       = data.azurerm_client_config.current.tenant_id
      category    = "env"
      description = "The Azure Tenant ID to connect to. https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration#configure-the-azurerm-or-azuread-provider"
    },
  }, )

  workspace_vars = merge(try(var.tfe.workspace_vars, {}), {
    # Terraform variables are prefixed with TF_VAR_ to suppress TFC Runner warning of unused variables.
    station_id = {
      value       = random_id.workload.hex
      category    = "terraform"
      description = "Station ID"
      hcl         = false
      sensitive   = false
    },
    workload_resource_group_name = {
      value       = azurerm_resource_group.workload.name
      category    = "terraform"
      description = "Name of the resource group created by Station"
      hcl         = false
      sensitive   = false
    },
    environment_name = {
      value       = var.environment_name
      category    = "terraform"
      description = "Name of the current deployment environment. Often dev/test/stage/prod."
      hcl         = false
      sensitive   = false
    },
    tags = {
      value       = replace(jsonencode(local.tags), "/(\".*?\"):/", "$1 = ")
      category    = "terraform"
      description = "Default tags from Station Deployment"
      hcl         = true
      sensitive   = false
    }
    },
    # Optionals
    #var.tfe.module_outputs_to_workspace_var.groups ? {
    try(var.tfe.module_outputs_to_workspace_var.groups == true, false) ? {
      groups = {
        value = replace(jsonencode({ for k, v in module.ad_groups : k => {
          display_name = v.group.display_name
          object_id    = v.group.object_id
        } }), "/(\".*?\"):/", "$1 = ") # Credit: https://brendanthompson.com/til/2021/03/hcl-enabled-tfe-variables
        category    = "terraform"
        description = "Groups provisioned by Station"
        hcl         = true
        sensitive   = false
      }
    } : {},
    try(var.tfe.module_outputs_to_workspace_var.applications == true, false) ? {
      applications = {
        value = replace(jsonencode({ for k, v in module.applications : k => {
          client_id = v.application.client_id
          object_id = v.application.object_id
        } }), "/(\".*?\"):/", "$1 = ") # Credit: https://brendanthompson.com/til/2021/03/hcl-enabled-tfe-variables
        category    = "terraform"
        description = "User Assigned Identities provisioned by Station"
        hcl         = true
        sensitive   = false
      }
    } : {},
    try(var.tfe.module_outputs_to_workspace_var.user_assigned_identities == true, false) ? {
      user_assigned_identities = {
        value = replace(jsonencode({ for k, identity in module.user_assigned_identities : k => {
          id           = identity.id
          client_id    = identity.client_id
          principal_id = identity.principal_id
        } }), "/(\".*?\"):/", "$1 = ") # Credit: https://brendanthompson.com/til/2021/03/hcl-enabled-tfe-variables
        category    = "terraform"
        description = "Applications provisioned by Station"
        hcl         = true
        sensitive   = false
      }
    } : {},
    try(var.tfe.module_outputs_to_workspace_var.resource_groups == true, false) ? {
      resource_groups = {
        value = replace(jsonencode({ for key, rg in azurerm_resource_group.user_specified : key => {
          name     = rg.name
          location = rg.location
        } }), "/(\".*?\"):/", "$1 = ") # Credit: https://brendanthompson.com/til/2021/03/hcl-enabled-tfe-variables
        category    = "terraform"
        description = "User specified resource groups provisioned by Station"
        hcl         = true
        sensitive   = false
      }
    } : {},
    try(var.tfe.module_outputs_to_workspace_var.role_definitions == true, false) ? {
      role_definitions = {
        value = replace(jsonencode({ for key, role_definition in azurerm_role_definition.user_created : key => {
          id                          = role_definition.id
          role_definition_id          = role_definition.role_definition_id
          role_definition_resource_id = role_definition.role_definition_resource_id
        } }), "/(\".*?\"):/", "$1 = ") # Credit: https://brendanthompson.com/til/2021/03/hcl-enabled-tfe-variables
        category    = "terraform"
        description = "User defined roles provisioned by Station"
        hcl         = true
        sensitive   = false
      }
    } : {}
  )
}