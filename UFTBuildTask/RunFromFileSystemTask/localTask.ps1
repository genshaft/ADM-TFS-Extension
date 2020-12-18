#
# localTask.ps1
#


param()
$testPathInput = Get-VstsInput -Name 'testPathInput' -Require
$timeOutIn = Get-VstsInput -Name 'timeOutIn'
$uploadArtifact = Get-VstsInput -Name 'uploadArtifact' -Require
$artifactType = Get-VstsInput -Name 'artifactType'
#$storageAccount = $env:STORAGE_ACCOUNT
#$container = $env:CONTAINER
$reportFileName = "RunFromFileSystemReport_" + $Env:BUILD_BUILDNUMBER

$uftworkdir = $env:UFT_LAUNCHER
Import-Module $uftworkdir\bin\PSModule.dll


# delete old "UFT Report" file and create a new one
$summaryReport = Join-Path $env:UFT_LAUNCHER -ChildPath "res\UFT Report"
if (Test-Path $summaryReport)
{
	Remove-Item $summaryReport
}


# delete old "TestRunReturnCode" file and create a new one
$retcodefile = Join-Path $env:UFT_LAUNCHER -ChildPath "res\TestRunReturnCode.txt"
if (Test-Path $retcodefile)
{
	Remove-Item $retcodefile
}

# remove temporary files complited
$results = Join-Path $env:UFT_LAUNCHER -ChildPath "res\*.xml"

#Get-ChildItem -Path $results | foreach ($_) { Remove-Item $_.fullname }

Invoke-FSTask $testPathInput $timeOutIn $uploadArtifact $artifactType $env:STORAGE_ACCOUNT $env:CONTAINER $reportFileName -Verbose 

$testPathReportInput = Join-Path $testPathInput -ChildPath "Report\run_results.html"

#connect to Azure account
Connect-AzAccount

#get resource group
$group = $env:RESOURCE_GROUP
$resourceGroup = Get-AzResourceGroup -Name "$($group)"
$groupName = $resourceGroup.ResourceGroupName

#get storage account
$account = $env:STORAGE_ACCOUNT
$storageAccount =  Get-AzStorageAccount -ResourceGroupName "$($groupName)" -Name  "$($account)"

#get storage context
$storageContext = $storageAccount.Context

#get storage container
$container = $env:CONTAINER

$artifact = $reportFileName + ".html"

#upload resource to container
Set-AzStorageBlobContent -Container "$($container)" -File $testPathReportInput -Blob  $artifact -Context $storageContext

# create summary UFT report
if (Test-Path $summaryReport)
{
	#uploads report files to build artifacts
	Write-Host "##vso[task.uploadsummary]$($summaryReport)" | ConvertTo-Html
}

# read return code
if (Test-Path $retcodefile)
{
	$content = Get-Content $retcodefile
	[int]$retcode = [convert]::ToInt32($content, 10)
	
	if($retcode -eq 0)
	{
		Write-Host "Test passed"
	}

	if ($retcode -eq -3)
	{
		Write-Error "Task Failed with message: Closed by user"
	}
	elseif ($retcode -ne 0)
	{
		Write-Host "Return code: $($retcode)"
		Write-Host "Task failed"
		Write-Error "Task Failed"
	}
}