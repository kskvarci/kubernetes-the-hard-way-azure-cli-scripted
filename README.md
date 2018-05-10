# Kubernetes The "Medium-Hard" Way Scripted w/ Azure CLI 2.0

The shell scripts in this repo align directly with Kelsey Hightower's great [Kubernetes The Hard Way](https://github.com/lostintangent/kubernetes-the-hard-way) tutorial. Kelsey's original tutorial is based on GCP.

These scripts have been written spefically for Microsoft Azure using the Azure CLI 2.0. After running through these scripts you'll have a fully bootstrapped Kubernetes cluster running in Azure. 

It's "Medium-Hard" as we're still building the cluster from the ground up. By reading the scripts you'll still have full transparency into each step in the process. The whole point here is to learn the mechanics of a cluster. If you're looking for a managed Kubernetes solution on Azure look into Microsoft's [Azure Kubernetes Service - AKS](https://docs.microsoft.com/en-us/azure/aks/).

## Getting Started

You will of course need an [Azure Subscription](https://azure.microsoft.com/) to deploy into. In total you'll be spinning up 2 Availability Sets, 6 Managed Disks, 1 Load Balancer, 6 Network Interfaces, 1 Network Security Group, 7 Public IPs, 6 Virtual machines and 1 Virtual Network.

These scripts were built and tested on Ubuntu. Either run them from an Ubuntu machine or from the awesome [Ubuntu on Windows](https://www.microsoft.com/en-us/store/p/ubuntu/9nblggh4msv6?rtc=1) which runs on top of the [Linux Subsystem for Windows](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
.
Before starting, make sure that you have the [Azure CLI installed](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). You'll want to be sure that you're [logged in](https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli?view=azure-cli-latest) and that you have your [target subscription selected](https://docs.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-set).

## Running the Scripts

### Update the Parameters Include

First, open and update the params.sh file. The resourceRootName will be prepended to each resource that is created in Azure.

make sure to populate the adminUserName and SSHPublicKey parameters with valid values that you'd like the VMs configured with.

Leave the vNetCIDR and poCIDRStart values at thier defaults.

```
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
```

### Review and Run Steps 01-03

Review each of the below scripts before running. Execute them in order.

```
$ ./01-prerequisites.sh
$ ./02-client-tools.sh
$ ./03-compute-resources.sh
```

### Review and Run Steps 04-12

Create a directory to hold the certificates and configs and cd into it:

```
$ mkdir tls
$ cd tls
```

Review each of the below scripts before running. Execute them in order.

```
$ ../04-certificate-authority.sh
$ ../05-kubernetes-configuration-files.sh
$ ../06-data-encryption-keys.sh
$ ../07-bootstrapping-etcd.sh
$ ../08-bootstrapping-kubernetes-controllers.sh
$ ../09-bootstrapping-kubernetes-workers.sh
$ ../10-configuring-kubectl.sh
$ ../11-pod-network-routes.sh
$ ../12-dns-addon.sh
```

## Running Some Smoke Tests

At this point you should have a fully functional cluster up and running. I've scripted a few smoke tests, but feel free to play around with your new cluster. Break it, fix it, etc ;)

```
$ ../13-smoke-test
```

## Cleaning Up

Cleaning up is as simple as deleting the resource group that you've provisioned into.

## Built With

* [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) - Azure Command Line Interface
* [Visual Studio Code](https://code.visualstudio.com/) - The best code editor out there... Seriously.
* [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-win10) - Linux on Windows

## Contributing

Pull Requests Welcome

## Authors

* **Ken Skvarcius**

## Acknowledgments

* [Kubernetes The Hard Way](https://github.com/lostintangent/kubernetes-the-hard-way)
* Many of the Azure CLI patterns are based on work from [Jonathan Carter's fork](https://github.com/lostintangent/kubernetes-the-hard-way) of Kelsey's original work.
