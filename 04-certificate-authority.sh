#!/bin/bash -e

#Note: create a new directory called TLS off the root of the repo and step into that directory before running the remainder of the steps.

#include parameters file
source ../params.sh

# Provisioning a CA and Generating TLS Certificates
# ###########################################################

# Certificate Authority
# -----------------------------------------------------------
echo "Setting up the certificate authority"
echo "- Creating the CA configuration file."
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
echo "- Creating the CA signing request."
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF
echo "- Generating the CA certificate and private key"
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Client and Server Certificates
# -----------------------------------------------------------
echo "Setting up the admin certificates"
echo "- Creating the admin client certificate signing request."
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
echo "- Generating the admin certificate and private key"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

echo "Setting up the worker node certificates"
for instance in "$resourceRootName-worker-0" "$resourceRootName-worker-1" "$resourceRootName-worker-2"; do
echo "- Creating the admin client certificate signing request for $instance"
cat > ${instance}-csr.json <<EOF
{
    "CN": "system:node:${instance}",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "US",
            "L": "Portland",
            "O": "system:nodes",
            "OU": "Kubernetes The Hard Way",
            "ST": "Oregon"
        }
    ]
}
EOF

echo "- grabbing the public IP for $instance"
EXTERNAL_IP=$(az network public-ip show -g "$resourceRootName-Rg" \
-n "$resourceRootName-pip" --query ipAddress -otsv)
echo "- grabbing the private IP for $instance"
INTERNAL_IP=$(az vm show -d -n ${instance} -g "$resourceRootName-Rg" --query privateIps -otsv)
echo "- Creating the worker node certificate signing request for $instance"
cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
    -profile=kubernetes \
    ${instance}-csr.json | cfssljson -bare ${instance}
done
echo "Setting up the kube-proxy certificates"
echo "- Creating the kube-proxy certificate signing request"
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
echo "- Generating the kube-proxy certificate and private key"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
echo "Settings up the API Server certificates"
echo "- Grabbing the LB front end IP"
KUBERNETES_PUBLIC_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" -n "$resourceRootName-pip" --query "ipAddress" -otsv)
echo "- Creating the API server certificate signing request"
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
echo "- Generating the API Server certificate and private key"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

# Distribute the Client and Server Certificates
# -----------------------------------------------------------
echo "Distributing the keys"
for instance in "$resourceRootName-worker-0" "$resourceRootName-worker-1" "$resourceRootName-worker-2"; do
  echo "- Distributing keys to $instance"
  PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" --name ${instance}-pip --query "ipAddress" -otsv)
    echo " - scp to $PUBLIC_IP_ADDRESS"
  scp ca.pem ${instance}-key.pem ${instance}.pem $adminUserName@${PUBLIC_IP_ADDRESS}:~/
done

for instance in "$resourceRootName-controller-0" "$resourceRootName-controller-1" "$resourceRootName-controller-2"; do
  echo "- Distributing keys to $instance"
  PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" --name "${instance}-pip" --query "ipAddress" -otsv)
  echo " - scp to $PUBLIC_IP_ADDRESS"
  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem $adminUserName@${PUBLIC_IP_ADDRESS}:~/
done
echo "DONE!"