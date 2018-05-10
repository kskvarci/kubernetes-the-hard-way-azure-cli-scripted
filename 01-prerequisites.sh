#!/bin/bash -e

#include parameters file
source ./params.sh

# Prerequisites
# ###########################################################

# Azure CLI (Ubuntu)
# -----------------------------------------------------------
echo "Modify your sources list"
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list

echo "Get the Microsoft signing key"
sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893

echo "Install the CLI"
sudo apt-get install apt-transport-https
sudo apt-get update && sudo apt-get install azure-cli

# Note: Log into the CLI (az login) and select the desired subscription (az account set) before continuing

echo "DONE!"