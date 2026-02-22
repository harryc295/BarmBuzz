Configuration CreateOUAndUsers {
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory

    Node $AllNodes.NodeName {
        # which domaain owns this node
        if ($Node.NodeName -eq "DC-BOLTON") {
            $domain = "bolton.local"
            $isDerby = $false
        } else {
            $domain = "derby.bolton.local"
            $isDerby = $true
        }

        # ous on derby only
        if ($isDerby) {
            foreach ($ou in $ConfigurationData.NonNodeData.OUs) {
                xADOrganizationalUnit "OU_$($ou.Name)" {
                    Name = $ou.Name
                    Path = $ou.Path
                    Ensure = "Present"
                }
            }
        }

        # make users on this domain
        foreach ($user in $ConfigurationData.NonNodeData.Users) {
            if ($user.Domain -eq $domain) {
                $securePass = ConvertTo-SecureString $user.Password -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential("dummy", $securePass)
                xADUser "User_$($user.SamAccountName)" {
                    DomainName = $domain
                    UserName = $user.SamAccountName
                    UserPrincipalName = "$($user.SamAccountName)@$($domain)"
                    GivenName = $user.GivenName
                    Surname = $user.Surname
                    Enabled = $user.Enabled
                    Password = $cred
                    Ensure = "Present"
                }
            }
        }

        # make groups for this domain
        foreach ($group in $ConfigurationData.NonNodeData.Groups) {
            if ($group.Domain -eq $domain) {
                xADGroup "Group_$($group.SamAccountName)" {
                    GroupName = $group.SamAccountName
                    GroupScope = $group.GroupScope
                    Ensure = "Present"
                    Members = $group.Members
                    MembershipAttribute = 'SamAccountName'   #allows for sam account names
                }
            }
        }
    }
}