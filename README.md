# Arc ESU License Management
This PowerShell script reads subscription ids from a file and generate a CSV file that contains ESU license assignment details and its cost for all Azure Arc enabled servers within a subscription.

# Scenarios
- One ESU license is assigned to One Arc Enabled Server
- One ESU license is assigned to Multiple Arc Enabled Servers (TODO)

# How to run script
1. Clone repo
2. Install ImportExcel module by running Install-Module -Name ImportExcel -Scope CurrentUser
3. Create subscriptions.txt file in the same repo and put the subscription id(s) line by line
4. Login to Azure by running Connect-AzAccount in command prompt and authenticate accordingly
5. Execute arc-esu-billing.ps1 PowerShell script to generate the Excel file

# Input  
subscriptions.txt file that contains subscription ids of ESU licenses and Azure Arc enabled servers

# Output
arc-esu-mgmt.xlsx file with the following worksheets and columns:

License Details worksheet
1. Subscription Id - subscription id of the ESU license
2. License Name - name of the ESU license 
3. License State (Activated/Deactivated) - state of the ESU license 
4. License Target (Windows Server 2012/Windows Server 2012 R2) - target of the ESU license
5. License Edition (Standard/Datacenter) - edition of the ESU license
6. License Core Type (pCore/vCore) - type of the ESU license
7. License Core Count - number of cores covered by the ESU license
8. Tags - tags assigned to the ESU license 
9. ESU License Cost (Est.) - estimated cost incurred by the ESU license 
10. ESU License Back Billing Cost (Est.) - estimated back billing cost incurred by the ESU license 
11. Total Cost (Est.) - estimated total cost incurred by the ESU license
12. Cores Assigned - number of cores already assigned in the ESU license
13. Cores Unassigned - number of cores left unassigned in the ESU license

Arc Enabled Servers worksheet
1. Subscription Id - subscription id of the arc enabled server
2. Resource Group - resource group of the arc enabled server
3. VM Name - name of the arc enabled server
4. OS & Version - OS and version detected in the arc enabled server
5. Core Count - number of cores detected in the arc enabled server
6. ESU Eligibility (Eligible/Inligible) - whether the arc enabled server is eligible for ESU
7. ESU Status (Assigned/NotAssigned) - whether an ESU license is assigned to the arc enabled server
8. Assigned License Name - name of the ESU license assigned to the arc enabled server
9. Tags - tags assigned to the arc enabled server (recommended to add tags to arc enabled server during onboarding)
