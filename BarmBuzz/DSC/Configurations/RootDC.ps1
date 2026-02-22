Configuration RootDC {
    param (
        [Parameter(Mandatory)] [PSCredential] $DomainCred,
        [Parameter(Mandatory)] [PSCredential] $SafeModeCred
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory

    Node 'DC-BOLTON' {
        WindowsFeature ADDS {
            Name = 'AD-Domain-Services'
            Ensure = 'Present'
        }

        WindowsFeature ADDSTools {
            Name = 'RSAT-ADDS-Tools'
            Ensure = 'Present'
            DependsOn = '[WindowsFeature]ADDS'
        }

        xADDomain Forest {
            DomainName = 'bolton.local'
            DomainAdministratorCredential = $DomainCred
            SafemodeAdministratorPassword = $SafeModeCred
            DependsOn = '[WindowsFeature]ADDS'
        }
    }
}