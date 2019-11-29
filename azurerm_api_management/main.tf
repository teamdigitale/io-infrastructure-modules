# API management

# Create and configure the API management service

# Existing infrastructure

data "azurerm_resource_group" "rg" {
  name = "${local.azurerm_resource_group_name}"
}

data "azurerm_key_vault" "key_vault" {
  name                = "${local.azurerm_key_vault_name}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
}
data "azurerm_virtual_network" "vnet" {
  name                = "${local.azurerm_virtual_network_name}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
}

data "azurerm_subnet" "apim_subnet" {
  name                 = "${local.azurerm_subnet_name}"
  virtual_network_name = "${data.azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${data.azurerm_resource_group.rg.name}"
}
data "azurerm_client_config" "current" {}

# New infrastructure

resource "azurerm_template_deployment" "APIM" {
  name                = "apim"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"

  template_body = <<DEPLOY
{
	"$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
	"contentVersion": "1.0.0.0",
	"parameters": {
		"publisherEmail": {
			"type": "string",
			"minLength": 1,
			"metadata": {
				"description": "The email address of the owner of the service"
			}
		},
		"publisherName": {
			"type": "string",
			"defaultValue": "Contoso",
			"minLength": 1,
			"metadata": {
				"description": "The name of the owner of the service"
			}
		},
		"sku": {
			"type": "string",
			"allowedValues": ["Developer",
			"Standard",
			"Premium"],
			"defaultValue": "Developer",
			"metadata": {
				"description": "The pricing tier of this API Management service"
			}
		},
		"skuCount": {
			"type": "int",
			"defaultValue": 1,
			"metadata": {
				"description": "The instance size of this API Management service."
			}
		},
		"keyVaultName": {
			"type": "string",
			"metadata": {
				"description": "Name of the vault"
			}
		},
		"proxyCustomHostname1": {
			"type": "string",
			"metadata": {
				"description": "Proxy Custom hostname."
			}
		},
		"keyVaultIdToCertificate": {
			"type": "string",
			"metadata": {
				"description": "Reference to the KeyVault certificate. https://contoso.vault.azure.net/secrets/contosogatewaycertificate."
			}
		},
		"apiName": {
			"type": "string",
			"metadata": {
				"description": "The APIM name"
			}
		},
		"location": {
			"type": "string",
			"metadata": {
				"description": "The location for the APIM name"
			}
		},
		"subnetRef": {
			"type": "string",
			"metadata": {
				"description": "The location for the APIM name"
			}
		}
	},
	"variables": {
    	"apimServiceIdentityResourceId": "[concat(resourceId('Microsoft.ApiManagement/service', parameters('apiName')),'/providers/Microsoft.ManagedIdentity/Identities/default')]"
	},
	"resources": [{
		"apiVersion": "2019-01-01",
		"name": "[parameters('apiName')]",
		"type": "Microsoft.ApiManagement/service",
		"location": "[parameters('location')]",
		"tags": {
		},
		"sku": {
			"name": "[parameters('sku')]",
			"capacity": "[parameters('skuCount')]"
		},
		"properties": {
			"publisherEmail": "[parameters('publisherEmail')]",
			"publisherName": "[parameters('publisherName')]",
			"virtualNetworkType": "Internal",
			"virtualNetworkConfiguration": {
				"subnetResourceId": "[parameters('subnetRef')]"
			}
		},
		"identity": {
			"type": "systemAssigned"
		}
	},
	{
		"type": "Microsoft.KeyVault/vaults/accessPolicies",
		"name": "[concat(parameters('keyVaultName'), '/add')]",
		"apiVersion": "2015-06-01",
		"dependsOn": [
			"[resourceId('Microsoft.ApiManagement/service', parameters('apiName'))]"
		],
		"properties": {
			"accessPolicies": [{
				"tenantId": "[reference(variables('apimServiceIdentityResourceId'), '2018-11-30').tenantId]",
				"objectId": "[reference(variables('apimServiceIdentityResourceId'), '2018-11-30').principalId]",
				"permissions": {
					"secrets": ["get"]
				}
			}]
		}
	},
	{
		"apiVersion": "2017-05-10",
		"name": "apimWithKeyVault",
		"type": "Microsoft.Resources/deployments",
		"dependsOn": [
		"[resourceId('Microsoft.ApiManagement/service', parameters('apiName'))]"
		],
		"properties": {
			"mode": "incremental",
			"templateLink": {
				"uri": "https://raw.githubusercontent.com/teamdigitale/io-infrastructure-modules/master/azurerm_api_management/apim.json",
				"contentVersion": "1.0.0.0"
			},
			"parameters": {
				"publisherEmail": { "value": "[parameters('publisherEmail')]"},
				"publisherName": { "value": "[parameters('publisherName')]"},
				"sku": { "value": "[parameters('sku')]"},
				"skuCount": { "value": "[parameters('skuCount')]"},
				"proxyCustomHostname1": {"value" : "[parameters('proxyCustomHostname1')]"},
				"keyVaultIdToCertificate": {"value" : "[parameters('keyVaultIdToCertificate')]"},
				"apimName": {"value" : "[parameters('apiName')]"},
				"subnetRef": {"value" : "[parameters('subnetRef')]"}
			}
		}
	}]
}
DEPLOY
  parameters = {
    "publisherEmail"           = "${var.publisher_email}"
    "publisherName"            = "${var.publisher_name}"
    "sku"                      = "${var.sku_name}"
    "proxyCustomHostname1"     = "${local.hostname_configurations_hostname}"
    "keyVaultIdToCertificate"  = "${local.hostname_configurations_keyvault_id}"
    "keyVaultName"             = "${local.azurerm_key_vault_name}"
    "apiName"                  = "${local.azurerm_apim_name}"
    "location"                 = "${data.azurerm_resource_group.rg.location}"
	"subnetRef"                = "${data.azurerm_subnet.apim_subnet.id}"
  }

  deployment_mode = "Incremental"

}
