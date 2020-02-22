# Before running these commands you should provision an AKS cluster
# using the Terraform files in cluster creation. Follow the steps in
# the cluster-creation.sh script to provision the cluster

# This script assumes that you have the following installed
#  - Azure CLI
#  - kubectl
#  - helm (version 3+)
#  - jq
#  - git

# Get the K8s credentials from AKS
az aks get-credentials -n vault-aks -g vault-aks

# Use helm charts to install Pod ID
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts

helm install aksid aad-pod-identity/aad-pod-identity

# Create the pod identity and pod identity bindings for the 
# vault-msi and demo-msi Azure Identities

kubectl apply -f ./cluster_creation/yaml_files/aadpodidentity-vault.yaml

kubectl apply -f ./cluster_creation/yaml_files/aadpodidentitybinding-vault.yaml

kubectl apply -f ./cluster_creation/yaml_files/aadpodidentity-demo.yaml

kubectl apply -f ./cluster_creation/yaml_files/aadpodidentitybinding-demo.yaml

# Use Helm to install Vault
# Refer to https://www.vaultproject.io/docs/platform/k8s/helm/

git clone https://github.com/hashicorp/vault-helm.git

cd vault-helm

git checkout v0.3.3

cd ..

helm install vault ./vault-helm  --values vault-values.yaml

### Initialize vault

kubectl get svc

# Change the LB_PUBLIC_IP to the public IP address of the 
# Azure load balancer


#Linux/Mac
export VAULT_SKIP_VERIFY=true
export VAULT_ADDR=http://LB_PUBLIC_IP:8200

#Windows PowerShell
$env:VAULT_SKIP_VERIFY="true"
$env:VAULT_ADDR="http://LB_PUBLIC_IP:8200"

vault operator init -key-shares 1 -key-threshold 1

# Take note of the vault root token and unseal key

vault operator unseal 

# Enter the unseal ley

vault login 

# Enter the root token

# Enable Azure auth for Vault

vault auth enable azure

# Enter the tenant ID (the ID for you Azure AD tenant)

az account show --query tenantId -o tsv

vault write auth/azure/config tenant_id=AZURE_TENANT_ID resource=https://management.azure.com/

# Update the SUBSCRIPTION_ID and AKS_RESOURCE_GROUP from 
# the Terraform output

vault write auth/azure/role/aks-role policies="aks" bound_subscription_ids=SUBSCRIPTION_ID bound_resource_groups=AKS_RESOURCE_GROUP

# Enable a k/v store and add a secret

vault secrets enable -path=aks kv

vault kv put aks/akspass password=42

# Create a policy for the k/v store and the demo-msi

vault policy write aks aks-pol.hcl

# Now deploy a simple pod with the proper label

kubectl apply -f deployment-demo.yaml

# And connect into the pod

kubectl get pods

kubectl exec -it DEMO_POD_NAME -- bash

# From inside the pod session run the following

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


# This part will fail until the User Assigned MSI is supported by Azure Auth
login=$(curl --request POST --data @auth_payload_complete.json $VAULT_ADDR/v1/auth/azure/login)

echo $login

# Exit the pod and view some details about the deployment

# AKS ID info
helm status aksid

helm get all aksid

kubectl get pods
kubectl get daemonset
kubectl get crds

# Show crd info for Azure Identity
kubectl get azureidentities.aadpodidentity.k8s.io

kubectl describe azureidentities.aadpodidentity.k8s.io vault-msi

kubectl get azureidentitybindings.aadpodidentity.k8s.io

kubectl describe azureidentitybindings.aadpodidentity.k8s.io vault-id-binding

# Show vault pod and label

kubectl get pods

kubectl describe pods vault-0

kubectl get azureassignedidentities.aadpodidentity.k8s.io
