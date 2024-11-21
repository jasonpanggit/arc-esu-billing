##########################################################################################################################################
# This PowerShell script reads subscription ids from a file and generate a CSV file that contains ESU license assignment details 
# and its cost for all Azure Arc enabled servers within a subscription.
#
# Author: Jason Pang
# ##########################################################################################################################################

# Get the access token
$token = (Get-AzAccessToken).Token
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
}

# array to hold ESU management details
$esuArcEnabledServerManagement = @()
# csv headers
$esuArcEnabledServerManagement += "Subscription Id,Resource Group,Arc-Enabled Server Name,OS Version,Core Count,ESU Eligibility,ESU Status,License Name,License State,License Target,License Edition,License Core Type,License Core Count,License Cost (Est.),License Back Billing Cost (Est.),License Total Cost (Est.),Tags" 
    
# read subscription ids from file
foreach($subscriptionId in Get-Content .\subscriptions.txt) {

    # hash table to store ESU license details
    $licensesDetails = @{}

    # Get ESU licenses by subscription
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.HybridCompute/licenses?api-version=2024-07-10"
    $licensesDetailsResponse = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers | ConvertTo-Json -Depth 100
    $licensesDetailsJson = $licensesDetailsResponse | ConvertFrom-Json
    $licensesDetailsJson.value | ForEach-Object {
        #Write-Output $_.name $_.properties.licenseDetails
        $licenseName = $_.name
        $licensesDetails.add($licenseName, $_.properties.licenseDetails)
    }

    # Get ESU usage details by subscription
    # TODO: add tag to ESU license so that we can filter the response
    #$filter = "tags/type eq 'esu-license'"
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Consumption/usageDetails?api-version=2024-08-01"
    $usageDetailsResponse = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers | ConvertTo-Json -Depth 100
    # Write-Output $usageDetails 

    # hash table to store ESU license usage details
    $licenseUsages = @{}
    $licenseBackbillingUsages = @{}
    
    $usageDetailsJson = $usageDetailsResponse | ConvertFrom-Json
    $usageDetailsJson.value | ForEach-Object {
        $meterCategory = $_.properties.meterCategory
        $meterSubCategory = $_.properties.meterSubCategory
        $meterName = $_.properties.meterName
        # Write-Output "Meter Category: $meterCategory Meter Sub Category: $meterSubCategory Meter Name: $meterName"

        if (($meterCategory -eq 'Azure Arc') -and ($meterSubCategory -eq 'Azure Arc Extended Security Updates')) {
            # Write-Output $_.properties
            $licenseId = $_.properties.instanceName
            $cost = $_.properties.costInBillingCurrency
           
            if ($meterName.Contains("Back Billing")) {
                Write-Output "ESU License Id: $licenseId Back Billing Cost: $cost"
                if ($licenseBackbillingUsages.ContainsKey($licenseId)) {
                    $licenseBackbillingUsages[$licenseId] = [double] $licenseBackbillingUsages[$licenseId] + [double] $cost
                    Write-Output "Updating license $licenseId with back billing cost $cost"
                } else {
                    Write-Output "Adding license $licenseId with back billing cost $cost"
                    $licenseBackbillingUsages.add($licenseId, [double] $cost)
                }
            } else {
                Write-Output "ESU License Id: $licenseId Cost: $cost"
                if ($licenseUsages.ContainsKey($licenseId)) {
                    $licenseUsages[$licenseId] = [double] $licenseUsages[$licenseId] + [double] $cost
                    Write-Output "Updating license $licenseId with cost $cost"
                } else {
                    Write-Output "Adding license $licenseId with cost $cost"
                    $licenseUsages.add($licenseId, [double] $cost)
                }
            }
        }
    }

    # $licenseUsages.keys | ForEach-Object {
    #     $message = 'License: {0} Cost: {1}' -f $_, $licenseUsages[$_]
    #     Write-Output $message
    # }

    # Get arc enabled servers by subscription    
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.HybridCompute/machines?api-version=2024-07-10"
    $arcEnabledServersResponse = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers | ConvertTo-Json -Depth 100
    $arcEnabledServersJson = $arcEnabledServersResponse | ConvertFrom-Json
    $arcEnabledServersJson.value | ForEach-Object {
        $id = $_.id 
        $resourceGroup = $id.Split("/")[4]
        $machineName = $_.properties.machineFqdn
        $coreCount = $_.properties.detectedProperties.coreCount # might need to search other fields e.g. hardwareProfile
        $osName = $_.properties.osName
        $osVersion = $_.properties.osVersion
        $licenseProfile = $_.properties.licenseProfile
        $esuEligibility = $licenseProfile.esuProfile.esuEligibility
        $licenseAssignmentState = $licenseProfile.esuProfile.licenseAssignmentState
        
        $licenseName = ""
        $licenseCost = ""
        $licenseBackbillingCost = ""
        if ($licenseAssignmentState -eq "Assigned") {
            # Get ESU license profile assigned to arc enabled server
            $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$machineName/licenseProfiles?api-version=2024-07-10"
            $licenseProfileResponse = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers | ConvertTo-Json -Depth 100
            $licenseProfileJson = $licenseProfileResponse | ConvertFrom-Json
            $licenseProfileJson.value | ForEach-Object {
                $licenseId = $_.properties.esuProfile.assignedLicense
                #Write-Output "License Id: $licenseId"
                $licenseName = $licenseId.Split("/")[8]
                $licenseCost = $licenseUsages[$licenseId]
                $licenseBackbillingCost = $licenseBackbillingUsages[$licenseId]
            }
        }
        $licenseDetails = $licensesDetails[$licenseName] 
        $licenseTotalCost = [double] $licenseCost + [double] $licenseBackbillingCost 
        $tags = $_.tags
        Write-Output "Found arc enabled server: $machineName with ESU eligibility: $esuEligibility and license assignment state: $licenseAssignmentState"
        # $esuArcEnabledServerManagement += "$subscriptionId,$resourceGroup,$machineName,$osName $osVersion,$coreCount,$esuEligibility,$licenseAssignmentState,$licenseName,$licenseDetail.state,$licenseDetail.target,$licenseDetail.edition,$licenseDetail.type,$licenseDetail.processors,$licenseCost,$licenseBackbillingCost,$licenseTotalCost,$tags"
        $esuArcEnabledServerManagement += "$subscriptionId,$resourceGroup,$machineName,$osName $osVersion,$coreCount,$esuEligibility,$licenseAssignmentState,$licenseName,$($licenseDetails.state),$($licenseDetails.target),$($licenseDetails.edition),$($licenseDetails.type),$($licenseDetails.processors),$licenseCost,$licenseBackbillingCost,$licenseTotalCost,$tags"
    }
}
$esuArcEnabledServerManagement | Out-File -FilePath "esu-arc-enabled-server-mgmt.csv" 