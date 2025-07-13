#!/usr/bin/env bash
set -euo pipefail

# 
#  USER-CONFIGURABLE VARIABLES
# 
RESOURCE_GROUP="n8n-rg"        # same RG that deploy.sh used
LOCATION="eastus2"             # region of the existing VNet
VNET_NAME="n8n-vm-vnet"        # VNet created by the ARM template
SUBNET_NAME="default"          # subnet inside the VNet

VM_NAME="jumphost"
VM_SIZE="Standard_D2s_v3"
ADMIN_USER="n8n-user"
ADMIN_PASS="!!!P455w0rd!!!"    # meets Azure complexity rules - reset after deployment

# Windows Server 2025 Datacenter Azure Edition (Gen2) image URN
IMAGE_URN="MicrosoftWindowsServer:WindowsServer:2025-datacenter-azure-edition:latest"

# 
#  PRE-FLIGHT
# 
#echo "Accepting marketplace terms for $IMAGE_URN (no-op if already done)…"
#az vm image terms accept --urn "$IMAGE_URN" >/dev/null

echo "Fetching VNet ID …"
VNET_ID=$(az network vnet show \
            -g "$RESOURCE_GROUP" -n "$VNET_NAME" \
            --query id -o tsv)

if [[ -z "$VNET_ID" ]]; then
  echo "VNet $VNET_NAME not found in $RESOURCE_GROUP. Aborting." >&2
  exit 1
fi

# 
#  CREATE THE VM
# 
echo "Creating jump-host VM $VM_NAME …"

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --image "$IMAGE_URN" \
  --size "$VM_SIZE" \
  --admin-username "$ADMIN_USER" \
  --admin-password "$ADMIN_PASS" \
  --authentication-type password \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --public-ip-address "" \
  --nsg "" \
  --enable-agent true \
  --license-type "Windows_Server" \
  >/dev/null

# 
#  OUTPUT CONNECTION DETAILS
# 
IP=$(az vm list-ip-addresses \
        -g "$RESOURCE_GROUP" -n "$VM_NAME" \
        --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)

DNS=$(az network private-dns record-set a show \
         -g "$RESOURCE_GROUP" \
         -z "internal.contoso" \
         -n "$VM_NAME" \
         --query "arecords[0].ipv4Address" -o tsv 2>/dev/null \
         && echo "${VM_NAME}.internal.contoso" || true)

echo "Jump-host deployed!"
echo "   Private IP : $IP"
[[ -n "$DNS" ]] && echo "   DNS name   : $DNS"
echo
echo "RDP inside the VNet/VPN:"
echo "   mstsc /v:$IP   # or use the DNS name once it propagates"
