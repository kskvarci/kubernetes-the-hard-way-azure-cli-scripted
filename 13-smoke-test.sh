#!/bin/bash -ex

#Run this from a new directory called TLS

#include parameters file
source ../params.sh

# Smoke Test
# ###########################################################

echo "Smoke Test"

# Data Encryption
# -----------------------------------------------------------
echo "- Create a generic secret"
kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"

echo "- Print a hexdump of the secret as stored in etcd"
CONTROLLER="$resourceRootName-controller-0"
PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" \
  -n ${CONTROLLER}-pip --query "ipAddress" -otsv)

ssh $adminUserName@${PUBLIC_IP_ADDRESS} \
  "ETCDCTL_API=3 etcdctl get /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"

# Deployments
# -----------------------------------------------------------
echo "- Create a deployment for nginx"
kubectl run nginx --image=nginx
kubectl get pods -l run=nginx


