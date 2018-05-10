#!/bin/bash -e

# Run this from a new directory called TLS

#include parameters file
source ../params.sh

# Generating Kubernetes Configuration Files for Authentication
# ###########################################################

# Client Authentication Configs
# -----------------------------------------------------------
echo "Setting up authentication"
echo "- Grabbing the load balancer front-end IP"
KUBERNETES_PUBLIC_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" \
  -n "$resourceRootName-pip" --query "ipAddress" -otsv)

for instance in "$resourceRootName-worker-0" "$resourceRootName-worker-1" "$resourceRootName-worker-2"; do
  echo "- Configuring authentication for $instance"
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done
echo "- Configuring authentication for the cluster"
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-credentials kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# Distribute the Kubernetes Configuration Files
# -----------------------------------------------------------
echo "Distributing config files"
for instance in "$resourceRootName-worker-0" "$resourceRootName-worker-1" "$resourceRootName-worker-2"; do
  PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" \
    -n ${instance}-pip --query "ipAddress" -otsv)
  echo "- Distributing config files to $instance"
  echo " - scp to $PUBLIC_IP_ADDRESS"
  scp ${instance}.kubeconfig kube-proxy.kubeconfig $adminUserName@${PUBLIC_IP_ADDRESS}:~/
done
echo "DONE!"