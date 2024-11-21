This PowerShell script reads subscription ids from a file and generate a CSV file that contains ESU license assignment details and its cost for all Azure Arc enabled servers within a subscription.
  
Input: subscriptions.txt file that contains subscription ids that contains Azure Arc enabled servers
Output: esu-arc-enabled-server-mgmt.csv file with the following columns:
1. Subscription Id - subscription id of the arc enabled server
2. Resource Group - resource group of the arc enabled server
3. VM Name - name of the arc enabled server
4. OS & Version - OS and version detected in the arc enabled server
5. Core Count - number of cores detected in the arc enabled server
6. ESU Eligibility (Eligible/Inligible) - whether the arc enabled server is eligible for ESU
7. ESU Status (Assigned/NotAssigned) - whether an ESU license is assigned to the arc enabled server
8. ESU License Name - name of the ESU license assigned to the arc enabled server
9. ESU License Cost (Est.) - estimated cost incurred by the ESU license assigned to the arc enabled server
10. ESU License Back Billing Cost (Est.) - estimated back billing cost incurred by the ESU license assigned to the arc enabled server
11. Total Cost (Est.) - estimated total cost incurred by the ESU license assigned to the arc enabled server
12. Tags - tags assigned to the arc enabled server (recommended to add tags to arc enabled server during onboarding)
 
Scenario: One ESU license is assigned to One VM

Important Notes: 
- This script does not support one ESU license assigned to multiple arc enabled servers but can be easily modified to support this scenario)
- Please login using Connect-AzAccount before running this script in order to get the Access Token (required for REST API calls)