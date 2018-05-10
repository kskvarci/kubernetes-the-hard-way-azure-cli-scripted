#!/bin/bash -e

#include parameters file
source ./params.sh

# Provisioning Compute Resources
# ###########################################################

# Functions
# -----------------------------------------------------------
# Pause Function
function pause(){
   read -p "$*"
}

# Prerequisites
# -----------------------------------------------------------
echo "Creating a resource group for the cluster"
az group create --location $location --resource-group "$resourceRootName-Rg" > /dev/null


echo "Provisioning Compute Resources"
# Networking
# -----------------------------------------------------------
echo "- Creating a VNet"
az network vnet create --resource-group "$resourceRootName-Rg" \
  --name "$resourceRootName-vnet" \
  --address-prefix $vNetCIDR \
  --subnet-name "$resourceRootName-subnet" > /dev/null

echo "- Creating an NSG"
az network nsg create --resource-group "$resourceRootName-Rg" --name "$resourceRootName-nsg" > /dev/null
az network vnet subnet update --resource-group "$resourceRootName-Rg" \
  --name "$resourceRootName-subnet" \
  --vnet-name "$resourceRootName-vnet" \
  --network-security-group "$resourceRootName-nsg" > /dev/null

echo "- Adding rules to the NSG"
az network nsg rule create --resource-group "$resourceRootName-Rg" \
  --name kubernetes-allow-ssh \
  --access allow \
  --destination-address-prefix '*' \
  --destination-port-range 22 \
  --direction inbound \
  --nsg-name "$resourceRootName-nsg" \
  --protocol tcp \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --priority 1000 > /dev/null
az network nsg rule create --resource-group "$resourceRootName-Rg" \
  --name kubernetes-allow-api-server \
  --access allow \
  --destination-address-prefix '*' \
  --destination-port-range 6443 \
  --direction inbound \
  --nsg-name "$resourceRootName-nsg" \
  --protocol tcp \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --priority 1001 > /dev/null

  echo "- Creating an Azure Load Balancer and a Static Public IP"
  az network lb create --resource-group "$resourceRootName-Rg" \
  --name "$resourceRootName-lb" \
  --backend-pool-name "$resourceRootName-lb-pool" \
  --public-ip-address "$resourceRootName-pip" \
  --public-ip-address-allocation static > /dev/null
  
  oct1=$(echo ${vNetCIDR} | tr "." " " | awk '{ print $1 }')
  oct2=$(echo ${vNetCIDR} | tr "." " " | awk '{ print $2 }')
  oct3=$(echo ${vNetCIDR} | tr "." " " | awk '{ print $3 }')

  # Compute Instances
  # -----------------------------------------------------------
  echo "- Creating an availability set for the controller VMs"
  az vm availability-set create --resource-group "$resourceRootName-Rg" --name "$resourceRootName-controller-as" > /dev/null

  for i in 0 1 2; do
    echo " - [Controller ${i}] Creating public IP..."
    az network public-ip create --name "$resourceRootName-controller-${i}-pip" --resource-group "$resourceRootName-Rg" > /dev/null

    echo " - [Controller ${i}] Creating NIC..."
    az network nic create --resource-group "$resourceRootName-Rg" \
        --name "$resourceRootName-controller-${i}-nic" \
        --private-ip-address "$oct1.$oct2.$oct3.1${i}" \
        --public-ip-address "$resourceRootName-controller-${i}-pip" \
        --vnet "$resourceRootName-vnet" \
        --subnet "$resourceRootName-subnet" \
        --ip-forwarding \
        --lb-name "$resourceRootName-lb" \
        --lb-address-pools "$resourceRootName-lb-pool" > /dev/null

    echo " - [Controller ${i}] Creating VM..."
    az vm create --resource-group "$resourceRootName-Rg" \
        --name "$resourceRootName-controller-${i}" \
        --image "Canonical:UbuntuServer:16.04.0-LTS:latest" \
        --nics "$resourceRootName-controller-${i}-nic" \
        --availability-set "$resourceRootName-controller-as" \
        --authentication-type "ssh" \
        --admin-username "$adminUserName" \
        --ssh-key-value "$SSHPublicKey" \
        --nsg "" > /dev/null
  done

  podoct1=$(echo ${podCIDRStart} | tr "." " " | awk '{ print $1 }')
  podoct2=$(echo ${podCIDRStart} | tr "." " " | awk '{ print $2 }')
  podoct3=$(echo ${podCIDRStart} | tr "." " " | awk '{ print $3 }')

  echo "- Creating an availability set for the worker VMs"
  az vm availability-set create --resource-group "$resourceRootName-Rg" --name "$resourceRootName-worker-as" > /dev/null
  
  for i in 0 1 2; do
    echo " - [worker ${i}] Creating public IP..."
    az network public-ip create --name "$resourceRootName-worker-${i}-pip" --resource-group "$resourceRootName-Rg" > /dev/null

    echo " - [worker ${i}] Creating NIC..."
    az network nic create --resource-group "$resourceRootName-Rg" \
        --name "$resourceRootName-worker-${i}-nic" \
        --private-ip-address "$oct1.$oct2.$oct3.2${i}" \
        --public-ip-address "$resourceRootName-worker-${i}-pip" \
        --vnet "$resourceRootName-vnet" \
        --subnet "$resourceRootName-subnet" \
        --ip-forwarding > /dev/null


    echo " - [worker ${i}] Creating VM..."
    az vm create --resource-group "$resourceRootName-Rg" \
        --name "$resourceRootName-worker-${i}" \
        --image "Canonical:UbuntuServer:16.04.0-LTS:latest" \
        --nics "$resourceRootName-worker-${i}-nic" \
        --availability-set "$resourceRootName-worker-as" \
        --authentication-type "ssh" \
        --admin-username "$adminUserName" \
        --ssh-key-value "$SSHPublicKey" \
        --tags "pod-cidr=$podoct1.$podoct2.${i}.0/24" \
        --nsg '' > /dev/null
  done

  echo "- VM Creation complete"
  az vm list -d -g "$resourceRootName-Rg" -o table
  echo "DONE!"