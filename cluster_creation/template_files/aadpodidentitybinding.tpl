apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: advent-azure-identity-binding
spec:
  AzureIdentity: ${msi_name}
  Selector: ${label}