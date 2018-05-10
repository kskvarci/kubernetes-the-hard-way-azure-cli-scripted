#!/bin/bash -e

# Parameters
# -----------------------------------------------------------
# Resource Group & Location
resourceRootName="kthw"
location="centralus"

# Network Info
vNetCIDR="10.240.0.0/24"
podCIDRStart="10.200.0.0/24"
adminUserName="ken"
SSHPublicKey=''

