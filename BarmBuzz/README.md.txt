Barnbuzz Active Directory Implementation
1. Solution **This ZIP matches the repository as of 2026-02-23 

This implementation builds a 2 domain active directory forest for Barnbuzz which has:

    Root Domain: 'bolton.local'

    Child Domain: 'derby.bolton.local'

    Organisational unit: 'Nottingham' inside Derby

The environment is using Windows Server 2022 domain controllers, Windows 11 Pro and an Ubuntu Desktop client. DSC (Desired State Configuration) is the plan for automation to repeat builds.
2. Architecture Scope and Boundaries

The forest contains two domains to show security boundaries:

    'bolton.local' is the company's HQ

    'derby.bolton.local' is the child domain with delegated administration

    'Nottingham' OU is within the Derby domain for local applications of the policy I have set out

This design shows that domains are security boundaries whereas OUs aren't, e.g. Bolton users can auth in Derby but they don't have access to everything; it's based on permissions that are needed specifically.

Role Based Access Control (RBAC) is active via security groups e.g.

    'BoltonUsers' – contains users from root forest domain

    'DerbyAccessGroup' – controls access to Derby file shares

3. Automation Plan / Strategy

The whole framework was built on first making a baseline that works, then following that the plan is to:

    DSC configurations will define domain controllers, users, groups, GPOs and OUs

    data file in 'DSC/Data' will push user and group creation

    scripts within 'DSC/Scripts/' will make sure correct build order occurs

    MOF files shouldn't be modified as they are generated artefacts

4. Repo Structure

BarmBuzz/
├── README.md
├── Documentation/
│   └── README.docx
├── DSC/
│   ├── Configurations/
│   ├── Data/
│   ├── Modules/
│   └── Scripts/
├── Tests/
│   └── Pester/
└── Evidence/
    ├── Screenshots/
    ├── HealthChecks/
    ├── GPOBackups/
    ├── Transcripts/
    ├── Git/
    └── AI_Log/

All paths are made to ensure it can be portable.
5. Order to Execute / Run Book

To build this manually you need to:

1. Configure VMs with static IPs on internal network

        DC-BOLTON: '192.168.50.1'

        DC-DERBY: '192.168.50.2'

        WinClient: '192.168.50.100' (static or DHCP reserved also works)

2. DC-Bolton to promote it to domain controller with in PowerShell run:

Install-ADDSForest -DomainName "bolton.local" -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) -Force

(IDEALLY USE A DIFFERENT PASSWORD, IT'S FOR LAB ONLY)

3. On DC Derby install AD DS and make it into a child domain:
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Install-ADDSDomain -NewDomainName "derby" -ParentDomainName "bolton.local" -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) -Credential (Get-Credential "administrator@bolton.local") -Force

4.To make the Nottingham OU:
New-ADOrganizationalUnit -Name "Nottingham" -Path "DC=derby,DC=bolton,DC=local"

5.To make users and groups:
DC-Bolton
New-ADUser -Name "BoltonUser" -SamAccountName "boltonuser" -UserPrincipalName "boltonuser@bolton.local" -GivenName "Bolton" -Surname "User" -Enabled $true -AccountPassword (ConvertTo-SecureString "Password123!" -AsPlainText -Force)
New-ADGroup -Name "BoltonUsers" -GroupScope Global -GroupCategory Security -Path "CN=Users,DC=bolton,DC=local"
Add-ADGroupMember -Identity "BoltonUsers" -Members "boltonuser"

DC-DERBY
New-ADUser -Name "DerbyUser" -SamAccountName "derbyuser" -UserPrincipalName "derbyuser@derby.bolton.local" -GivenName "Derby" -Surname "User" -Enabled $true -AccountPassword (ConvertTo-SecureString "Password123!" -AsPlainText -Force)
New-ADGroup -Name "DerbyAccessGroup" -GroupScope Global -GroupCategory Security -Path "CN=Users,DC=derby,DC=bolton,DC=local"
Add-ADGroupMember -Identity "DerbyAccessGroup" -Members "derbyuser"

6.File share on DC-Derby Configuration

New-Item -Path "C:\Shares\Confidential" -ItemType Directory -Force
Set-Content -Path "C:\Shares\Confidential\secret.txt" -Value "Derby users only."
$acl = Get-Acl "C:\Shares\Confidential"
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("DERBY\DerbyAccessGroup", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path "C:\Shares\Confidential" -AclObject $acl
New-SmbShare -Name "Confidential" -Path "C:\Shares\Confidential" -FullAccess "DERBY\DerbyAccessGroup"

7.Join WinClient to domain and see if it works and test etc (see section 7.)


6. Rerun Behaviour

The steps given are not repeatable by introducing DSC each one will run on the intended config without making errors or duplicate objects being created.
7. Validation and Testing Model

Validation can be checked via manual testing of cross domain access (section 9 will cover this) or Pester tests to verify domain, OU structure, users and groups as well as GPO links.

Cross domain access tests demonstrate's Derby user (within DerbyAccessGroup) can enter \DC-DERBY\Confidential, and that Bolton user that isn't in the group is denied which shows the domain security boundary is built.

Pester tests – 12 Pester tests validated my core infrastructure such as domain existence, OUs, user and group creation, password rules and GPOs. 9 tests passed but 3 are skipped (file share and GPO links) as they'd need me to manually verify it or specific permissions that I wasn't able to do. The results are given in "\Evidence\Screenshots\Pester_Results.png" which shows that the environment is stable and can be checked and verified after changes.
8. Security Considerations

Credentials: in this lab the passwords are in plain text as it's simpler than the alternative; in a real situation they should be encrypted (certificate encryption) or credential files with ACLs.

Group policy: planned GPOs will implement a baseline security setting e.g. password length, account lockouts, etc. Each GPO will have a reason and analysis behind why it's implemented and the risks of it.

Firewall: the domain controllers had the firewalls turned off for a short time whereas in real production appropriate rules would be set so it wasn't necessary.

The main trade offs: using a single domain controller and relying on a lab only DNS and using generic passwords wouldn't be acceptable in a real situation / deployment but in this assignment it is within scope.

Group Policy Restrict Control Panel Nottingham
Risk: users may intentionally change settings that are important or unintentionally by mistake that could cause problems within the security.
Control: restricting access via Group Policy makes it so they can't change it.
Area/Scope: used on Nottingham OU (Derby child domain) so affecting all users in the OU.

Group Policy Disabling Command Prompt
Risk: users could use cmd tools to bypass security or access could lead to an attack surface.
Control: disabled access to cmd so users can't run cmd.exe and batch scripts.
Scope: used on Nottingham OU which affects all users in the OU.
9. Evidence

    Derby can enter shared files ("\Evidence\Screenshots\DerbyUser_Success.png")

    Bolton user can't access ("\Evidence\Screenshots\BoltonUser_Denied.png")

    Domain controller health (Bolton) "\Evidence\HealthChecks\dcdiag_Bolton.txt"

    Domain controller health (Derby) "\Evidence\HealthChecks\dcdiag_Derby.txt"

    Child domain exists "\Evidence\Screenshots\ADUC_Derby.png"

    Nottingham OU exists "\Evidence\Screenshots\Nottingham_OU.png"

    FGPP made "\Evidence\Screenshots\FGPP_Creation.png"

    FGPP Applied to domain services "\Evidence\Screenshots\FGPP_ApplyToAdmins.png"

    FGPP effective for privileged users "\Evidence\Screenshots\FGPP_AdminResult.png"

    FGPP not effective for normal users "\Evidence\Screenshots\FGPP_UserResult.png"

    Ubuntu is domain‑joined (realm list) "\Evidence/Screenshots/Ubuntu_Realm_List.png"

    Ubuntu has valid keytab "\Evidence/Screenshots/Ubuntu_Keytab.png"

    Ubuntu computer object exists in AD "\Evidence/Screenshots/Ubuntu_ADUC.png"
    Ubuntu Ubuntu ID Use rand Getent "\Evidence\Screenshots\Ubuntu_ID_User_and_Getent.png"
 
    Windows server prevented access to cmd prompt "\Evidence\Screenshots\Windows_server_prevent_cmd.png"

    Nottingham OU management policy "\Evidence\Screenshots\Policy_management_linked.png"

    Command prompt disabled on Nottingham user "\Evidence\Screenshots\Commandpromptdisabled.png"

    Control panel disabled on Nottingham user "\Evidence\Screenshots\Controlpaneldisabled.png"

    GP report of Nottingham user "\Evidence\Screenshots\GPRnottinghamuser.png"

    Automated validation tests pass "\Evidence\Screenshots\Pester_Results.png"
	 
    GitHub repository link ("\Evidence\Git\RepoLink.txt")

    Git commit history ("\Evidence\Git\GitLog.txt")

    Git contribution stats ("\Evidence\Git\Stats.txt")

    Development reflogs ("\Evidence\Git\Reflog\")
	

10. Limitations

    Single domain controllers – in a real life production at least 2 DCs would be needed

    Time sync problems – in a lab to be expected whereas in a real deployment time source would need external time source

    DNS delegation – warnings were ignored as parent zone didn't exist externally

    Manual promotion – the initial build was made manually and automation would be needed for repeatability

    Disabling IPv6 to avoid DNS problems – in a real situation IPv6 would require planning to work

    Passwords – most passwords were generic; in a real life situation would need stronger passwords

 
References

Microsoft Corporation (2024) Active Directory Domain Services Overview. Available at: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview (Accessed: 22 February 2026).

Microsoft Corporation (2024) Install-ADDSForest. Available at: https://learn.microsoft.com/en-us/powershell/module/addsdeployment/install-addsforest (Accessed: 22 February 2026).

Microsoft Corporation (2024) Install-ADDSDomain. Available at: https://learn.microsoft.com/en-us/powershell/module/addsdeployment/install-addsdomain (Accessed: 22 February 2026).

Microsoft Corporation (2024) New-SmbShare. Available at: https://learn.microsoft.com/en-us/powershell/module/smbshare/new-smbshare (Accessed: 22 February 2026).

Microsoft Corporation (2024) Group Policy Overview. Available at: https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/hh147307(v=ws.11) (Accessed: 22 February 2026).

Microsoft Corporation (2024) Windows PowerShell Desired State Configuration Overview. Available at: https://learn.microsoft.com/en-us/powershell/dsc/overview (Accessed: 22 February 2026).

Pester (2024) Pester – The ubiquitous test and mock framework for PowerShell. Available at: https://pester.dev (Accessed: 22 February 2026).

Ubuntu Community (2024) Active Directory authentication with SSSD and realmd. Available at: https://ubuntu.com/server/docs/service-sssd-ad (Accessed: 22 February 2026).