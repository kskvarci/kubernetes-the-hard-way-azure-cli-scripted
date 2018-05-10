#!/bin/bash -e

# Run this from a new directory called TLS

#include parameters file
source ../params.sh

# Generating the Data Encryption Config and Key
# ###########################################################

# The Encryption Key
# -----------------------------------------------------------
echo "Generate a random encryption key"
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# The Encryption Config File
# -----------------------------------------------------------
echo "Generate the encryption config file"
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

echo "Distribute the encryption config file to the controllers"
for instance in "$resourceRootName-controller-0" "$resourceRootName-controller-1" "$resourceRootName-controller-2"; do
  PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" \
    -n ${instance}-pip --query "ipAddress" -otsv)
  echo "- Distributing encryption config file to $instance"
  echo " - scp to $PUBLIC_IP_ADDRESS"
  scp encryption-config.yaml $adminUserName@${PUBLIC_IP_ADDRESS}:~/
done
echo "DONE!"