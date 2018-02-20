# Login using a user account with *owner* or *contributor* access to multiple subscriptions.
$tenantId = "<YOUR TENANT ID>"
Write-Host "Sign-in to Azure using your user Azure credentials"
$user = Login-AzureRmAccount -TenantId $tenantId

# Get a list of all subscriptions this user account has access to.
$subscriptionIds = Get-AzureRmSubscription -TenantId $tenantId | Where-Object { $_.State -eq "Enabled" } | Select -ExpandProperty Id 
Write-Host "User '$($user.Context.Account.Id)' has access to the following Azure subscriptions:"
foreach ($subscriptionId in $subscriptionIds)
{
    Write-Host "  $subscriptionId" -ForegroundColor Green
}

# Create an Azure AD App registration
$ticks = [DateTime]::UtcNow.Ticks
$azureADAppName = "contoso" + $ticks
$azureADAppHomePage = "https://" + $azureADAppName
Write-Host "Creating an Azure AD application registration '$azureADAppName'" -ForegroundColor Yellow
$azureADApp = New-AzureRmADApplication -DisplayName $azureADAppName -HomePage $azureADAppHomePage `
                -IdentifierUris $azureADAppHomePage

# Create a new client secret / credential for the Azure AD App registration
$bytes = New-Object Byte[] 32
$rand = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rand.GetBytes($bytes)
$clientSecret = [System.Convert]::ToBase64String($bytes)
$clientSecretSecured = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$endDate = [System.DateTime]::Now.AddYears(1)
Write-Host "- Adding a client secret / credential for the application" -ForegroundColor Yellow
$azureADAppCred = New-AzureRmADAppCredential -ApplicationId $azureADApp.ApplicationId -Password $clientSecretSecured

# Create an Azure AD Service Principal associated with the Azure AD App
Write-Host "Creating service principal for Azure AD application '$($azureADApp.ApplicationId)'" -ForegroundColor Yellow
$azureADSP = New-AzureRmADServicePrincipal -ApplicationId $azureADApp.ApplicationId

# Need to pause after creating the service principal to allow time for the object to propogate through Azure AD.
# Otherwise, you will probably get an error on the next call indicating the SP doesn't exist.
Start-Sleep -Seconds 25

# Assign the service principal to the Reader role for the Azure subscription
Write-Host "Adding service principal '$($azureADSP.Id)' as a reader to subscriptions." -ForegroundColor Yellow
foreach ($subscriptionId in $subscriptionIds)
{ 
    New-AzureRmRoleAssignment -RoleDefinitionName "Reader" -Scope "/subscriptions/$subscriptionId" -ObjectId $azureADSP.Id
}

# Test SPN access to multuple subscriptions
$cred = New-Object System.Management.Automation.PSCredential $azureADSP.ApplicationId, $clientSecretSecured
$sp = Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId $tenantId
$sp.Context.Account.Id

$subscriptionIds = Get-AzureRmSubscription -TenantId $tenantId | Select -ExpandProperty Id
Write-Host "Service principal '$($sp.Context.Account.Id)' has access to the following Azure subscriptions:"
foreach ($subscriptionId in $subscriptionIds)
{
    Write-Host "  $subscriptionId" -ForegroundColor Green
}

# Clean UP
# Login using a user account with *owner* or *contributor* access to multiple subscriptions.
Write-Host "Sign-in to Azure using your user Azure credentials"
$user = Login-AzureRmAccount -TenantId $tenantId

Write-Host "Removing Azure AD service principal with object ID '$($azureADSP.Id)'." -ForegroundColor Yellow
Remove-AzureRmADServicePrincipal -ObjectId $azureADSP.Id -Force

Write-Host "Removing Azure AD application with object ID '$($azureADApp.ObjectId)'." -ForegroundColor Yellow
Remove-AzureRmADApplication -ObjectId $azureADApp.ObjectId -Force





