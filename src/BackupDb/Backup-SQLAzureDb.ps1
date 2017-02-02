
<#PSScriptInfo

.VERSION 1.0

.GUID fa60848a-c703-4d33-9261-f42ccef837b6

.AUTHOR mzaatar@outlook.com

.COMPANYNAME Mohamed Zaatar

.COPYRIGHT GNU GENERAL PUBLIC LICENSE

.TAGS Azure SQL Db backup

.LICENSEURI https://github.com/mzaatar/AzureScripts/blob/AddInitialScript/License.txt

.PROJECTURI https://github.com/mzaatar/AzureScripts

.ICONURI https://upload.wikimedia.org/wikipedia/commons/2/2f/PowerShell_5.0_icon.png

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

#>
<#
    .SYNOPSIS
        This Azure Automation runbook automates the database backup in an Azure. 

    .DESCRIPTION
        The runbook backup your SQL Azure databse into an Azure storage account. 
		This runbook can be scheduled through Azure to maintain your backup up to date daily/monthly/yearly. 
        
        This is a PowerShell powershell runbook script.

        This runbook requires the "Azure" and "AzureRM.Resources" modules which are present by default in Azure Automation accounts.
        For detailed documentation and instructions, see: 
        
        https://automys.com/library/asset/scheduled-virtual-machine-shutdown-startup-microsoft-azure

    .PARAMETER AutomationConnection
        The name of the Azure Connection name asset in the Automation account that contains information required to connect to 
		an external service or application from a runbook or DSC configuration.
		The user who will setup and use this connection must be configured as co-administrator and owner
        of the subscription for best functionality. 

        By default, the runbook will use the credential with name "Default Automation Credential"

        For for details on credential configuration, see:
        http://azure.microsoft.com/blog/2014/08/27/azure-automation-authenticating-to-azure-using-azure-active-directory/
    
    .PARAMETER SubscriptionName
        The name of Azure subscription in which the resources will be created.
    
    .PARAMETER StorageAccount
       The name of the storage account where the database backup will be transfered to.
	   
	.PARAMETER BlobContainer
       The name of the storage blob container that will hold the backup files.
	   
	.PARAMETER StorageKey
       The storage key of the storage account where the database backup will be transfered to. It should have access to write and create blobs.
	   
	.PARAMETER StorageKeytype
       The Storage Key type of the storage account. By default it will use "StorageAccessKey" value.
	   
	.PARAMETER DbName
       The name of the database which will perform the backup on it.
	   
	.PARAMETER ResourceGroupName
       The name of the Resource Group of the database.
	   
	.PARAMETER ServerName
       The name of the Azure SQL Server where the database is.
	   
	.PARAMETER ServerAdmin
       The name of the Azure SQL Admin username.  
	
	.PARAMETER ServerPassword
       The password of the Azure SQL Admin account.  
	
    .EXAMPLE
        For be done later.

    .INPUTS
        None.

    .OUTPUTS
        Human-readable informational and error messages produced during the job. Not intended to be consumed by another runbook.
#>
function Backup-SQLAzureDb {
param(
    [parameter(Mandatory=$true)]
	[String] $AutomationConnection,
    [parameter(Mandatory=$true)]
	[String] $SubscriptionName,
    [parameter(Mandatory=$true)]
    [String]$StorageAccount,
	[parameter(Mandatory=$true)]
    [String]$BlobContainer,
	[parameter(Mandatory=$true)]
    [String]$StorageKey,
	[parameter(Mandatory=$true)]
    [String]$StorageKeytype = "StorageAccessKey",
	[parameter(Mandatory=$true)]
    [String]$DbName,
	[parameter(Mandatory=$true)]
    [String]$ResourceGroupName,
	[parameter(Mandatory=$true)]
    [String]$ServerName,
	[parameter(Mandatory=$true)]
    [String]$serverAdmin,
	[parameter(Mandatory=$true)]
    [String]$ServerPassword
)

$VERSION = "0.1.0"

$securePassword = ConvertTo-SecureString -String $serverPassword -AsPlainText -Force
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $serverAdmin, $securePassword

# Generate a unique filename for the BACPAC
$bacpacFilename = $ServerName + '-' + $DbName + '-' +(Get-Date).ToString("yyyyMMddTHHmmssZ") + ".bacpac"

# Storage account info for the BACPAC
$BaseStorageUri = "https://$storageAccount.blob.core.windows.net/$blobContainer/"
$BacpacUri = $BaseStorageUri + $bacpacFilename

# --------------------------- Main script ---------------------------
Write-Output "Start backing db $DbName to storage account $storageAccount with name $bacpacFilename ..."
try
{
    "Logging in to Azure..."
    # Get the connection "AzureRunAsConnection"  
    $null = Add-AzureRmAccount -ServicePrincipal -TenantId $AutomationConnection.TenantId -ApplicationId $AutomationConnectionName.ApplicationId -CertificateThumbprint $AutomationConnection.CertificateThumbprint
    $null = Select-AzureRmSubscription -SubscriptionName $SubscriptionName
}
catch {
    if (!$AutomationConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$exportRequest = New-AzureRmSqlDatabaseExport -ResourceGroupName $ResourceGroupName -ServerName $ServerName `
   -DatabaseName $DbName -StorageKeytype $StorageKeytype -StorageKey $StorageKey -StorageUri $BacpacUri `
   -AdministratorLogin $creds.UserName -AdministratorLoginPassword $creds.Password

# Check status of the export
$status = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink

Write-Output "Export status is:"
$status

Write-Output "End export"
}
export-modulemember -function Backup-SQLAzureDb
