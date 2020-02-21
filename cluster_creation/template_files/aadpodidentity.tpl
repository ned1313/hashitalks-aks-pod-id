apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: ${msi_name}
spec:
  type: 0
  ResourceID: ${msi_resource_id}
  ClientID: ${msi_client_id}