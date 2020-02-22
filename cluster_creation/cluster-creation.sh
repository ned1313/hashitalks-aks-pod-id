# This script assumes you are running Terraform 0.12+
# The Azure provider is using the credentials stored by the 
# Azure CLI. Be sure to login to the Azure CLI and select
# the subscription you would like to deploy to prior to 
# running this script

terraform init

terraform plan -out cluster_setup.tfplan

terraform apply cluster_setup.tfplan

# Sometimes you will have to run the plan and apply twice
# The creation of the service principal may not propogate in
# time to be used by AKS. Once you run it a second time AKS
# is able to find the SP successfully.

# Terraform will create four local files that are used to
# deploy the azure identity components in AKS. You should also
# take note of the outputs from the configuration as they
# will be refeenced later

