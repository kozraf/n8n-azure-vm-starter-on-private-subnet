#!/bin/bash

# Variables
RESOURCE_GROUP="n8n-rg"
LOCATION="eastus2"
VM_NAME="n8n-vm"
ADMIN_USERNAME="n8nadmin"
DNS_PREFIX="n8n-$(date +%s | cut -c6-10)"

# Check if resource group exists and has resources
#if az group show --name $RESOURCE_GROUP &>/dev/null; then
#    echo "Resource group $RESOURCE_GROUP exists. Checking for existing resources..."
#    RESOURCE_COUNT=$(az resource list --resource-group $RESOURCE_GROUP --query "length(@)" -o tsv)
#    if [ "$RESOURCE_COUNT" -gt 0 ]; then
#        echo "Found $RESOURCE_COUNT existing resources. Would you like to delete them and redeploy? (y/n)"
#        read -r response
#        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
#            echo "Deleting resource group $RESOURCE_GROUP..."
#            az group delete --name $RESOURCE_GROUP --yes --no-wait
#            echo "Waiting for deletion to complete..."
#            az group wait --deleted --name $RESOURCE_GROUP
#        else
#            echo "Deployment cancelled. Please manually clean up resources or use a different resource group."
#            exit 1
#        fi
#    fi
#fi

# Create resource group
#az group create --name $RESOURCE_GROUP --location $LOCATION

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/id_rsa_n8n ]; then
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa_n8n
fi

# Deploy the VM
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file n8n-vm-template.json \
  --parameters \
    vmName=$VM_NAME \
    adminUsername=$ADMIN_USERNAME \
    adminPasswordOrKey="$(cat ~/.ssh/id_rsa_n8n.pub)" \
    dnsLabelPrefix=$DNS_PREFIX \
    location=$LOCATION

# Wait for deployment to complete
echo "Waiting for deployment to complete..."
az deployment group wait --created --resource-group $RESOURCE_GROUP --name n8n-vm-template

# Get the VM's public IP
VM_IP=$(az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv 2>/dev/null)

# Output connection information
if [ -n "$VM_IP" ]; then
    echo "VM deployed successfully!"
    echo "SSH connection: ssh -i ~/.ssh/id_rsa_n8n $ADMIN_USERNAME@$VM_IP"
    echo "DNS name: $DNS_PREFIX.$LOCATION.cloudapp.azure.com"
    echo "Now run:"
    echo "scp -i ~/.ssh/id_rsa_n8n setup.sh docker-compose.yml backup.sh $ADMIN_USERNAME@$VM_IP:~/"
    echo "ssh -i ~/.ssh/id_rsa_n8n $ADMIN_USERNAME@$VM_IP"
else
    echo "Deployment completed but VM IP not found. Check Azure portal for details."
    echo "DNS name: $DNS_PREFIX.$LOCATION.cloudapp.azure.com"
fi 
