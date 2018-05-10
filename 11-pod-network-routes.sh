#!/bin/bash -e

#Run this from a new directory called TLS

#include parameters file
source ../params.sh

# Provisioning Pod Network Routes
# ###########################################################

# The Routing Table
# -----------------------------------------------------------
echo "Creating UDR to route traffic for the worker nodes"
az network route-table create -g "$resourceRootName-Rg" -n "$resourceRootName-routes"
az network vnet subnet update -g "$resourceRootName-Rg" \
  -n "$resourceRootName-subnet" \
  --vnet-name "$resourceRootName-vnet" \
  --route-table "$resourceRootName-routes"

# Routes
# -----------------------------------------------------------
i=0
for instance in "$resourceRootName-worker-0" "$resourceRootName-worker-1" "$resourceRootName-worker-2"; do
echo "- Adding route for $instance 10.200.${i}.0/24 -> 10.240.0.2${i}"
az network route-table route create -g "$resourceRootName-Rg" \
  -n kubernetes-route-10-200-${i}-0-24 \
  --route-table-name "$resourceRootName-routes" \
  --address-prefix 10.200.${i}.0/24 \
  --next-hop-ip-address 10.240.0.2${i} \
  --next-hop-type VirtualAppliance
i=$((i+1))
done

az network route-table route list -g "$resourceRootName-Rg" --route-table-name "$resourceRootName-routes" -o table
echo "DONE!"