# Introduction
This PowerShell script reads subscription ids from a file and generate a CSV file that contains ESU license assignment details and its cost for all Azure Arc enabled servers within a subscription.

# Scenarios
- One ESU license is assigned to One Arc Enabled Server
- One ESU license is assigned to Multiple Arc Enabled Servers (TODO)

# How to run script
1. Clone repo
2. Create subscriptions.txt file in the same repo and put the subscription id(s) line by line
3. Login to Azure by running Connect-AzAccount in command prompt and authenticate accordingly
4. Execute powershell script and check the generated CSV file

# Input  
subscriptions.txt file that contains subscription ids that contains Azure Arc enabled servers

# Output
esu-arc-enabled-server-mgmt.csv file with the following columns:
1. Subscription Id - subscription id of the arc enabled server
2. Resource Group - resource group of the arc enabled server
3. VM Name - name of the arc enabled server
4. OS & Version - OS and version detected in the arc enabled server
5. Core Count - number of cores detected in the arc enabled server
6. ESU Eligibility (Eligible/Inligible) - whether the arc enabled server is eligible for ESU
7. ESU Status (Assigned/NotAssigned) - whether an ESU license is assigned to the arc enabled server
8. License Name - name of the ESU license assigned to the arc enabled server
9. License State (Activated/Deactivated) - state of the ESU license 
10. License Target (Windows Server 2012/Windows Server 2012 R2) - target of the ESU license
11. License Edition (Standard/Datacenter) - edition of the ESU license
12. License Core Type (pCore/vCore) - type of the ESU license
13. License Core Count - number of cores covered by the ESU license
14. ESU License Cost (Est.) - estimated cost incurred by the ESU license assigned to the arc enabled server
15. ESU License Back Billing Cost (Est.) - estimated back billing cost incurred by the ESU license assigned to the arc enabled server
16. Total Cost (Est.) - estimated total cost incurred by the ESU license assigned to the arc enabled server
17. Tags - tags assigned to the arc enabled server (recommended to add tags to arc enabled server during onboarding)
