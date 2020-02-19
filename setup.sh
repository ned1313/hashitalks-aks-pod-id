# This script assumes that an AKS cluster has already been provisioned

# This script also uses the Azure CLI

# Create an Azure Identity in the same resource group as AKS cluster

mc_rg=$(az aks show -g <cluster_resource_group> -n <cluster_name> --query nodeResourceGroup -o tsv)

vault_msi=$(az identity create -g $mc_rg -n vault-msi -o json)

obj_id=$(echo $vault_msi | jq .principalId -r)

rg=$(az group show --name $mc_rg)

rg_id=$(echo $rg | jq .id -r)

az role assignment create --role Contributor --assignee $obj_id --scope $rg_id

# Use helm charts to install Pod ID
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts

helm install aksid aad-pod-identity/aad-pod-identity

kubectl apply -f aadpodidentity.yaml

kubectl apply -f aadpodidentitybinding.yaml

# Use Helm to install Vault

git clone 


# Enable Azure auth for Vault

kubectl get svc

export VAULT_SKIP_VERIFY=true
export VAULT_ADDR=http://LB_PUBLIC_IP:8200

vault auth enable azure

vault write auth/azure/config \
    tenant_id=AZURE_TENANT_ID \
    resource=https://management.azure.com/

vault write auth/azure/role/aks-role \
    policies="aks" \
    bound_subscription_ids=$sub_id \
    bound_resource_groups=$mc_rg

vault secrets enable -path=aks kv

vault kv put aks/akspass password=42

vault policy write aks aks-pol.hcl

# Create an Azure identity for a demo pod

demo_msi=$(az identity create -g $mc_rg -n demo-msi -o json)

kubectl apply -f aadpodidentity-demo.yaml

kubectl apply -f aadpodidentitybinding-demo.yaml

# Now deploy a simple pod with the proper label

kubectl apply -f deployment-demo.yaml

apt update && apt install jq curl -y

metadata=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2019-08-15")

subscription_id=$(echo $metadata | jq -r .compute.subscriptionId)
vm_name=$(echo $metadata | jq -r .compute.name)
vmss_name=$(echo $metadata | jq -r .compute.vmScaleSetName)
resource_group_name=$(echo $metadata | jq -r .compute.resourceGroupName)

response=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -H Metadata:true -s)

jwt=$(echo $response | jq -r .access_token)

cat <<EOF > auth_payload_complete.json
{
    "role": "aks-role",
    "jwt": "$jwt",
    "subscription_id": "$subscription_id",
    "resource_group_name": "$resource_group_name",
    "vm_name": "$vm_name",
    "vmss_name": "$vmss_name"
}
EOF

export VAULT_SKIP_VERIFY=true
export VAULT_ADDR=http://LB_PUBLIC_IP:8200



login=$(curl --request POST --data @auth_payload_complete.json $VAULT_ADDR/v1/auth/azure/login)