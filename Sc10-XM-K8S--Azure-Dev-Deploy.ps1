<#
.SYNOPSIS
    This script builds a "XM" Sitecore 10 non production Azure Kubernetes deployment
    into an azure resource group of your choice. 

.DESCRIPTION
    This is an "all in one" script for deploying Sitecore 10 into AKS

.NOTES
    Author: Colin Cooper
    Last Edit: 2020-12-1
    Version 1.5 Beta - initial release of Sc10 Azure test Deployment Script

***Please CD into the directory that contains the  k8s-sitecore-xm1 folder and execute the script from there***
Be patient, some steps can take a little time to complete.
Some Helm/Nginx Errors are expected, these are safe to ignore

Prerequisites:
Please see the Readme

#>



Write-Host "--- Setting up CLI & Params ---" -ForegroundColor yellow 
$azsubname = 'Your-Azure-Sub-Name' #The name of the target azure sub
$Region = 'eastus2' #location of all Azure resources
$ResourceGroup = 'SC10K8Dev1' # the resource group for Azure Kubernetes
$AcrName = 'SC10K8Dev1'
$SkuAcr = 'Standard'  #the Sku Type of the Azure Container Registry
$AKSname = 'SC10K8DevAKS1' #the name of your Azure Kubernetes cluster
$aksVersion = "1.18.10" #$(az aks get-versions -l $Region --query 'orchestrators[-1].orchestratorVersion' -o tsv)
$AzureWindowsUser = 'azureuser'
$AzureWindowsPassword="Password!12345" #change this to something secure
$namespace = "sitecore"
Write-Host "--- Complete: CLI & Params Configured ---" -ForegroundColor Green


# Create resource group
Write-Host "--- Creating resource group ---" -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Region
Write-Host "--- Complete: resource group ---" -ForegroundColor Green

# Create Azure Container Registry
Write-Host "--- Creating ACR ---" -ForegroundColor Yellow
az acr create -n $AcrName -g $ResourceGroup --sku $SkuAcr --location $Region
Write-Host "--- Complete: ACR ---" -ForegroundColor Green

# Setup CLI & Parameters for AKS creation
Write-Host "--- Setting up CLI & Params ---" -ForegroundColor yellow

$aksVersion = "1.18.8" #$(az aks get-versions -l $Region --query 'orchestrators[-1].orchestratorVersion' -o tsv)
Write-Host "--- Complete: CLI & Params Configured ---" -ForegroundColor Green

# create AKS instance
Write-Host "--- Creating AKS Instance K8s version $aksVersion ---" -ForegroundColor yellow
az aks create `
    --name $AksName `
    --resource-group $ResourceGroup `
    --kubernetes-version $aksVersion `
    --node-count 1 `
    --node-vm-size Standard_D4s_v3 `
    --vm-set-type VirtualMachineScaleSets `
    --generate-ssh-keys `
    --load-balancer-sku standard `
    --network-plugin azure `
    --node-osdisk-size 128 `
    --windows-admin-password $AzureWindowsPassword `
    --windows-admin-username $AzureWindowsUser `
	--enable-addons monitoring `
	--nodepool-name 'linux' `
    --verbose

sleep 30

Write-Host "--- Complete: AKS Created ---" -ForegroundColor Green

# Get the Creds Boy-o
az aks get-credentials --resource-group $ResourceGroup --name $Aksname --overwrite-existing

# link AKS to ACR
Write-Host "--- Linking AKS to ACR ---" -ForegroundColor yellow
$clientID = $(az aks show --resource-group $ResourceGroup --name $AksName --query "servicePrincipalProfile.clientId" --output tsv)
$acrId = $(az acr show --name $AcrName --resource-group $ResourceGroup --query "id" --output tsv)
az role assignment create --assignee $clientID `
    --role acrpull `
    --scope $acrId
Write-Host "--- Complete: AKS & ACR Linked ---" -ForegroundColor Green

sleep 20

# Add windows server nodepool
Write-Host "--- Creating Windows Server Node Pool ---" -ForegroundColor yellow
az aks nodepool add --resource-group $ResourceGroup `
    --cluster-name $AksName `
    --os-type Windows `
    --name win `
    --node-vm-size Standard_D4s_v3 `
    --node-count 1 
Write-Host "--- Complete: Windows Server Node Pool Created ---" -ForegroundColor Green

sleep 30

# authenticate AKS instance
Write-Host "--- Authenticate with AKS ---" -ForegroundColor yellow
az aks get-credentials -a `
    --resource-group $ResourceGroup `
    --name $AksName `
    --overwrite-existing
Write-Host "--- Complete: Windows Server Node Pool Created ---" -ForegroundColor Green

Sleep 100

Write-Host "--- Creating nginx (Ingress) ---" -ForegroundColor Yellow
# kubectl create namespace ingress-basic 
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update
helm install nginx-ingress stable/nginx-ingress --set controller.replicaCount=1 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux --set-string controller.config.proxy-body-size=10m --set controller.service.externalTrafficPolicy=Local --debug

Write-Host "--- Complete: nginx (ingress) ---" -ForegroundColor Green

sleep 30


# Show the Public IP of the NginX Ingress Controller
$ingressIpAddress = (kubectl get svc nginx-ingress-controller -o jsonpath="{.status.loadBalancer.ingress[*].ip}")


if (-not [string]::IsNullOrEmpty($ingressIpAddress)) {
  Write-Host "Ingress Public IP: $ingressIpAddress" -ForegroundColor Yellow
}


Write-Host "--- Complete: nginx (ingress) ---" -ForegroundColor Green

Write-Host "--- Deploy Secrets ---" -ForegroundColor Yellow
kubectl apply -k ./k8s-sitecore-xm1/secrets/
Write-Host "--- Complete: Deploy Secrets ---" -ForegroundColor Green

Write-Host "--- Deploy External Resources ---" -ForegroundColor Yellow
kubectl apply -f ./k8s-sitecore-xm1/external/
kubectl wait --for=condition=Available deployments --all --timeout=900s
kubectl wait --for=condition=Ready pods --all
Write-Host "--- Complete: Deploy External Resources ---" -ForegroundColor Green

Write-Host "--- Initialize SQl and SOLR ---" -ForegroundColor Yellow
kubectl apply -f ./k8s-sitecore-xm1/init/
kubectl wait --for=condition=Complete job.batch/solr-init --timeout=600s
kubectl wait --for=condition=Complete job.batch/mssql-init --timeout=600s
Write-Host "--- Complete: Initialize SQl and SOLR ---" -ForegroundColor Green

Write-Host "--- Deploy Sitecore ---" -ForegroundColor Yellow
kubectl apply -f ./k8s-sitecore-xm1/
kubectl wait --for=condition=Available deployments --all --timeout=36000s

kubectl apply -f ./k8s-sitecore-xm1/ingress-nginx
kubectl wait --for=condition=Available deployments --all --timeout=36000s
Write-Host "--- Complete: Deploy Sitecore ---" -ForegroundColor Green

Write-Host "--- Sitecore Azure Containers Deployment complete  ---" -ForegroundColor Green
Write-Host "--- Update the local host file with the external IP address Below  ---" -ForegroundColor Green
Write-Host "--- The default hostnames are cm.globalhost cd.globalhost Id.globalhost  ---" -ForegroundColor Green

if (-not [string]::IsNullOrEmpty($ingressIpAddress)) {
  Write-Host "Ingress Public IP: $ingressIpAddress" -ForegroundColor Yellow
}

Write-Host "--- When the deployment is finished, you must configure the SolrCloud search indexes.  ---" -ForegroundColor Green
Write-Host "--- Login to Sitecore CMS with the admin user and password that you configured as a secret  ---" -ForegroundColor Green
Write-Host "--- In the Sitecore Control Panel click Populate Managed Schema and in the Schema Populate dialog box, select all the indexes and then click Populate. ---" -ForegroundColor Green
