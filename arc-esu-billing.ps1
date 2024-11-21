##########################################################################################################################################
# This PowerShell script reads subscription ids from a file and generate a CSV file that contains ESU license assignment details 
# and its cost for all Azure Arc enabled servers within a subscription.
#  
# Input: subscriptions.txt file that contains subscription ids that contains Azure Arc enabled servers
# Output: esu-arc-enabled-server-mgmt.csv file with the following columns:
# 1. Subscription Id - subscription id of the arc enabled server
# 2. Resource Group - resource group of the arc enabled server
# 3. VM Name - name of the arc enabled server
# 4. OS & Version - OS and version detected in the arc enabled server
# 5. Core Count - number of cores detected in the arc enabled server
# 6. ESU Eligibility (Eligible/Inligible) - whether the arc enabled server is eligible for ESU
# 7. ESU Status (Assigned/NotAssigned) - whether an ESU license is assigned to the arc enabled server
# 8. ESU License Name - name of the ESU license assigned to the arc enabled server
# 9. ESU License Cost (Est.) - estimated cost incurred by the ESU license assigned to the arc enabled server
# 10. ESU License Back Billing Cost (Est.) - estimated back billing cost incurred by the ESU license assigned to the arc enabled server
# 11. Total Cost (Est.) - estimated total cost incurred by the ESU license assigned to the arc enabled server
# 12. Tags - tags assigned to the arc enabled server (recommended to add tags to arc enabled server during onboarding)
# 
# Scenario: One ESU license is assigned to One VM
# Important Notes: 
# - This script does not support one ESU license assigned to multiple arc enabled servers but can be easily modified to support this scenario)
# - Please login using Connect-AzAccount before running this script in order to get the Access Token (required for REST API calls)
##########################################################################################################################################

# Get the access token
$token = (Get-AzAccessToken).Token
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
}

# array to hold ESU management details
$esuArcEnabledServerManagement = @()
# csv headers
$esuArcEnabledServerManagement += "Subscription Id,Resource Group,Arc-Enabled Server Name,OS Version,Core Count,ESU Eligibility,ESU Status,ESU License Name,ESU License Cost (Est.), ESU License Back Billing Cost (Est.), Total Cost (Est.),Tags" 
    
# read subscription ids from file
foreach($subscriptionId in Get-Content .\subscriptions.txt) {

    # Get usage details by subscription
    # TODO: add tag to ESU license so that we can filter the response
    #$filter = "tags/type eq 'esu-license'"
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Consumption/usageDetails?api-version=2024-08-01"
    $usageDetails = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers | ConvertTo-Json -Depth 100
    # Write-Output $usageDetails 

    # hash table to store license usage details
    $licenseUsages = @{}
    $licenseBackbillingUsages = @{}
    
    $usageDetailsJson = $usageDetails | ConvertFrom-Json
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

    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.HybridCompute/machines?api-version=2024-07-10"
    $arcEnabledServers = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers | ConvertTo-Json -Depth 100

    $arcEnabledServersJson = $arcEnabledServers | ConvertFrom-Json
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
            $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$machineName/licenseProfiles?api-version=2024-07-10"
            $licenseProfile = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers | ConvertTo-Json -Depth 100
            $licenseProfileJson = $licenseProfile | ConvertFrom-Json
            $licenseProfileJson.value | ForEach-Object {
                $licenseId = $_.properties.esuProfile.assignedLicense
                #Write-Output "License Id: $licenseId"
                $licenseName = $licenseId.Split("/")[8]
                $licenseCost = $licenseUsages[$licenseId]
                $licenseBackbillingCost = $licenseBackbillingUsages[$licenseId]
            }
        }
        $licenseTotalCost = [double] $licenseCost + [double] $licenseBackbillingCost 
        $tags = $_.tags
        Write-Output "Found arc enabled server: $machineName with ESU eligibility: $esuEligibility and license assignment state: $licenseAssignmentState"
        $esuArcEnabledServerManagement += "$subscriptionId,$resourceGroup,$machineName,$osName $osVersion,$coreCount,$esuEligibility,$licenseAssignmentState,$licenseName,$licenseCost,$licenseBackbillingCost,$licenseTotalCost,$tags"
    }
}
$esuArcEnabledServerManagement | Out-File -FilePath "esu-arc-enabled-server-mgmt.csv" 