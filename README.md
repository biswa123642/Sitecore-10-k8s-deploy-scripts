# Colin Coopers "All in one" script for deploying non-production Sitecore 10 "XM" into AKS

## Installing prerequisite software

- [Install Powershell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7)
- [Install the Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) / [Current release of the Azure CLI](https://aka.ms/installazurecliwindows)
- [Install Chocolatey]
`Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))`

- [Install Helm]
`choco install kubernetes-helm`

- [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-windows)


This all in one script will install [Kubernetes](https://kubernetes.io) version ```1.18.10```. If you want to change to another version, please update the script.

``` 
# list Azure locations
az account list-locations -o table

# get  Azure locations
az aks get-versions -l east-us-2 -o table 

KubernetesVersion    Upgrades
-------------------  -----------------------------------------
1.19.3(preview)      None available
1.19.0(preview)      1.19.3(preview)
1.18.10              1.19.0(preview), 1.19.3(preview)
1.18.8               1.18.10, 1.19.0(preview), 1.19.3(preview)
1.17.13              1.18.8, 1.18.10
1.17.11              1.17.13, 1.18.8, 1.18.10
1.16.15              1.17.11, 1.17.13
1.16.13              1.16.15, 1.17.11, 1.17.13
```

## Script Notes

All the scripts has ```default``` values in place.

***Please CD into the directory on your workstation that contains the  k8s-sitecore-xm1 folder and execute the script from there***

In addition to the prerequisites listed you will need a valid Sitecore License File.
The license.xml issued by Sitecore needs to be compressed/encoded into the sitecore-license.txt file in the secrets folder.
A helper script can be found in the official guide which converts the license.xml into this format.
Look on [Page 20 of the official installation guide for this helper script](https://dev.sitecore.net/~/media/D6D6C46E2A89478D92CA10BCDD19BBEF.ashx)

SSL:
I would reccomend generating a wildcard SSL certificate for your test/dev deployments.
In my own testing I have used the free "Lets Encrypt" wildcard certificate to great success.
An excellent guide for getting this done in a windows environment exists [here](https://medium.com/@nvbach91/how-to-create-lets-encrypt-s-free-wildcard-ssl-certificates-for-windows-server-iis-web-servers-aa01d939e0ad0 

Each of the following folders Requires 2 certificate files (tls.crt and tls.key) :
k8s-sitecore-xm1\secrets\tls\global-cd
k8s-sitecore-xm1\secrets\tls\global-cm
k8s-sitecore-xm1\secrets\tls\global-id

The following secret files need to be modified with passwords. Make sure that there are no empty lines.
sitecore-core-database-password.txt
sitecore-core-database-username.txt

sitecore-databasepassword.txt
sitecore-databaseusername.txt

sitecore-web-database-password.txt
sitecore-web-database-username.txt

sitecore-master-database-password.txt
sitecore-master-database-username.txt

sitecore-forms-database-password.txt
sitecore-forms-database-username.txt

Be patient, some steps can take a little time to complete.
You may need to adjust the sleep settings in the script to compensate for differences in execution times in different azure regions
Some Helm/Nginx Errors are expected, these are safe to ignore.

Many thanks to Bart Plasmeijer and Rob Earlam For laying the framework for this at Symposium 2020.