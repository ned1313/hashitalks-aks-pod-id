# Running Vault on AKS with Pod Identity

This repository was developed for use with my HashiTalks presentation on February 20, 2020. The intention was to demonstrate using the AKS Pod Identity project with a HashiCorp Vault deployment running on Kubernetes. The Pod Identity project would be used to provide an MSI to the Vault pods for use with the Azure Auth setup. It would also be used to allow other pods in the cluster to authenticate to Vault and retrieve a value stored on Vault's k/v store.

## Pre-requisites

You're going to need the following tools installed:

* Azure CLI
* kubectl
* helm (version 3+)
* git
* terraform (version 0.12+)

You can run the process from Linux, Mac, or Windows

## Set-up process

The setup process is pretty simple.

1. Deploy the AKS cluster and Identity resources using Terraform.
1. Deploy Pod Identity with Helm and add the Custom Resources
1. Deploy Vault with Helm
1. Configure Vault using the CLI
1. Deploy a demo container to test the process

The Terraform configuration is in the cluster_creation directory, along with a script for running it. Once the deployment is complete, you can run through the actions in the `setup.sh` script in the root directory. Part of the process is cloning the Vault repo that has the Helm chart for deploying Vault. Hopefully HashiCorp switches over to an actual Helm repo, and that step will soon no longer be necessary.