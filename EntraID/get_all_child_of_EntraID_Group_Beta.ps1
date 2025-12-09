# Install the Microsoft Entra PowerShell module if not already installed
# Always required.
#Install-Module -Name Microsoft.Entra -Repository PSGallery -Scope CurrentUser -Force -AllowClobber

#Install-Module -Name Microsoft.Graph.Beta -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
# ( Or
#Install-Module -Name Microsoft.Graph.Beta.Groups -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
# and
#Install-Module -Name Microsoft.Graph.Beta.Users -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
# )

param(
  [string]$GroupName
)

cls

# Connect to Microsoft Entra
Connect-MgGraph -Scopes "GroupMember.Read.All", "User.Read.All", "Application.Read.All"

# Function to recursively enumerate group members
function Get-GroupMembersRecursive {
    param (
        [string]$GroupName,
        [ref]$AllMembers,
        [string]$Identation = ""
    )

    $myMessage = $Identation + "GroupName = '$GroupName'"
    Write-Output $myMessage

    $GroupId = (Get-MgBetaGroup -Filter $("DisplayName eq '$GroupName'")).Id

    $members = Get-MgBetaGroupMember -GroupId $GroupId -All
    foreach ($member in $members) {
        switch ($member.AdditionalProperties['@odata.type']) {
            '#microsoft.graph.user' {
                $user = Get-MgBetaUser -UserId $member.Id

                $myMessage = $Identation + "|  User = '$($user.DisplayName)'"
                Write-Output $myMessage

                $AllMembers.Value += [PSCustomObject]@{
                    GroupName     = $GroupName
                    Type          = "User"
                    Id            = $user.Id
                    DisplayName   = $user.DisplayName
                    PrincipalName = $user.UserPrincipalName
                    Status        = $user.AccountEnabled
                }
            }
            '#microsoft.graph.servicePrincipal' {
                $sp = Get-MgBetaServicePrincipal -ServicePrincipalId $member.Id

                $myMessage = $Identation + "|  SPN  = '$($sp.DisplayName)'"
                Write-Output $myMessage

                $AllMembers.Value += [PSCustomObject]@{
                    GroupName         = $GroupName
                    Type              = "ServicePrincipal"
                    Id                = $sp.Id
                    DisplayName       = $sp.DisplayName
                    PrincipalName     = $sp.AppDisplayName
                    Status            = $sp.AccountEnabled
                }
            }
            '#microsoft.graph.group' {
                # Nested group, recurse
                $newIdentation = $Identation + "|  "
                Get-GroupMembersRecursive -GroupName $member.AdditionalProperties['displayName'] -AllMembers $AllMembers -Identation $newIdentation
            }
            default {
                $myMessage = $Identation + "  ERROR: Unknown member '$member'!"
            }
        }
    }
}

# Execute the function
$AllMembers = @()
Get-GroupMembersRecursive -GroupName $GroupName -AllMembers ([ref]$AllMembers)

# Output results
$AllMembers | Format-Table

# Disconnect session
Disconnect-MgGraph
