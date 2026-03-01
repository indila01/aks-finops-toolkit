# Terraform — Dev Environment

Deploys an AKS cluster for the AKS FinOps Toolkit in a dev/test configuration.

---

## Prerequisites

- Azure CLI installed and authenticated: `az login`
- Terraform >= 1.7: `terraform version`
- Subscription with permission to create Resource Groups, AKS clusters, and Log Analytics workspaces
- Azure CLI extension: `az extension add --name aks-preview` (optional, for preview features)

---

## Quick Start

```bash
# 1. Copy and edit the variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set your location, cluster name, etc.

# 2. Initialise Terraform
terraform init

# 3. Preview what will be created
terraform plan

# 4. Apply
terraform apply

# 5. Get cluster credentials
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw cluster_name)

# 6. Verify
kubectl get nodes
```

---

## Remote State (Recommended for Teams)

Uncomment the `backend "azurerm"` block in `main.tf` and create the storage account first:

```bash
# Create storage account for Terraform state (one-time setup)
RESOURCE_GROUP="rg-tfstate"
STORAGE_ACCOUNT="stfinopstfstate$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
CONTAINER="tfstate"

az group create --name $RESOURCE_GROUP --location australiaeast

az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --sku Standard_LRS \
  --encryption-services blob

az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT

echo "Update backend block in main.tf:"
echo "  storage_account_name = \"$STORAGE_ACCOUNT\""
```

Then update `main.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-tfstate"
  storage_account_name = "<your-storage-account>"
  container_name       = "tfstate"
  key                  = "aks-finops-toolkit/dev/terraform.tfstate"
}
```

---

## Required Azure Permissions

The identity running `terraform apply` needs at minimum:

| Permission | Reason |
|---|---|
| `Contributor` on the subscription or target resource group | Create/manage AKS, Log Analytics |
| `User Access Administrator` (or scoped) | Assign managed identity roles |

For CI/CD, create a service principal:
```bash
az ad sp create-for-rbac \
  --name sp-finops-terraform \
  --role Contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth
```

Export as env vars:
```bash
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."
export ARM_TENANT_ID="..."
export ARM_SUBSCRIPTION_ID="..."
```

---

## Teardown

```bash
terraform destroy
```

This will delete the AKS cluster, node pools, Log Analytics workspace, and resource group.
Make sure to drain any persistent data before running this.

---

## What Gets Created

| Resource | Name | Notes |
|---|---|---|
| Resource Group | `var.resource_group_name` | Contains all resources |
| AKS Cluster | `var.cluster_name` | System-assigned identity, RBAC enabled |
| System Node Pool | `system` | Auto-scales 1 to N nodes |
| Log Analytics Workspace | `<cluster_name>-logs` | 30-day retention |
| Monitoring Node Pool | `monitoring` | Only if `create_monitoring_node_pool = true` |
| Kubernetes Namespace | `monitoring` | Created by Terraform |
| Kubernetes Namespace | `vpa-system` | Created by Terraform |
