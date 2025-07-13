#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="n8n-rg"
LOCATION="eastus2"
VM_NAME="n8n-vm"
ADMIN_USERNAME="n8nadmin"
PRIVATE_DNS_ZONE="internal.contoso"

# 
#  Create (or check) resource group
# 
#az group show --name "$RESOURCE_GROUP" &>/dev/null || \
#  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# 
#  Generate SSH key if missing
# 
KEYFILE="$HOME/.ssh/id_rsa_n8n"
[[ -f "$KEYFILE" ]] || ssh-keygen -t rsa -b 4096 -N "" -f "$KEYFILE"

# 
#  Deploy the template  (note: no dnsLabelPrefix parameter)
# 
az deployment group create \
  --name "n8nPrivateSubnet" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file n8n-vm-template.json \
  --parameters \
      vmName="$VM_NAME" \
      adminUsername="$ADMIN_USERNAME" \
      adminPasswordOrKey="$(cat "$KEYFILE.pub")" \
      location="$LOCATION" \
      privateDnsZoneName=$PRIVATE_DNS_ZONE

echo "Waiting for deployment to finish ..."
az deployment group wait \
  --resource-group "$RESOURCE_GROUP" \
  --name "n8nPrivateSubnet" \
  --created

# 
#  Fetch the VM’s **private** IP and print helper commands
# 
VM_IP=$(az vm list-ip-addresses \
          --resource-group "$RESOURCE_GROUP" \
          --name "$VM_NAME" \
          --query "[0].virtualMachine.network.privateIpAddresses[0]" \
          -o tsv)

echo
echo "VM deployed on private subnet!"
echo "   Private IP : $VM_IP"
echo
echo "SSH (inside VNet or via Bastion):"
echo "   ssh -i $KEYFILE $ADMIN_USERNAME@$VM_IP"


