BeforeAll {
    # Load modules we need
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module GroupPolicy -ErrorAction Stop
}

Describe "Domain and Forest" {
    It "should have root domain bolton.local" {
        (Get-ADDomain).DNSRoot | Should -Be "bolton.local"
    }

    It "should have child domain derby.bolton.local" {
        $child = Get-ADDomain -Server derby.bolton.local
        $child.DNSRoot | Should -Be "derby.bolton.local"
    }
}

Describe "organization units (OU'S)" {
    It "should have nottingham ou within derby domain" {
        $ou = Get-ADOrganizationalUnit -Filter "Name -eq 'Nottingham'" -Server derby.bolton.local
        $ou | Should -Not -BeNullOrEmpty
    }
}

Describe "Users and Groups" {
    It "should have BoltonUser in bolton.local" {
        $user = Get-ADUser -Identity boltonuser -Server bolton.local
        $user.Enabled | Should -Be $true
    }

    It "should have DerbyUser in derby.bolton.local" {
        $user = Get-ADUser -Identity derbyuser -Server derby.bolton.local
        $user.Enabled | Should -Be $true
    }

    It "should have BoltonUsers group containing BoltonUser" {
        $members = Get-ADGroupMember -Identity BoltonUsers -Server bolton.local | Select-Object -ExpandProperty SamAccountName
        $members | Should -Contain "boltonuser"
    }

    It "should have DerbyAccessGroup containing DerbyUser" {
        $members = Get-ADGroupMember -Identity DerbyAccessGroup -Server derby.bolton.local | Select-Object -ExpandProperty SamAccountName
        $members | Should -Contain "derbyuser"
    }
}

Describe "password policies" {
    It "should have PrivilegedPolicy applied to Domain Admins" {
        $subjects = Get-ADFineGrainedPasswordPolicySubject -Identity PrivilegedPolicy | Select-Object -ExpandProperty Name
        $subjects | Should -Contain "Domain Admins"
    }

    It "should apply PrivilegedPolicy to Administrator" {
        $result = Get-ADUserResultantPasswordPolicy -Identity Administrator -Server bolton.local
        $result.Name | Should -Be "PrivilegedPolicy"
    }
}

Describe "cross-domain files" {
    It "Confidential share exists on DC-DERBY" -Skip {
        # This test requires WinRM and proper DNS; we have manual screenshots instead.
        $share = Get-SmbShare -Name "Confidential" -CimSession DC-DERBY.derby.bolton.local
        $share | Should -Not -BeNullOrEmpty
    }
}

Describe "group policy" {
    It "restrict control panel gpo linked to nottingham ou" -Skip {
        # Requires admin rights in child domain; manual evidence provided via gpresult.
        $gpo = Get-GPO -Name "Restrict Control Panel - Nottingham" -Server derby.bolton.local
        $gpo | Should -Not -BeNullOrEmpty
        $links = Get-GPLink -Guid $gpo.Id -Server derby.bolton.local
        $links | Where-Object { $_.Target -like "*OU=Nottingham*" } | Should -Not -BeNullOrEmpty
    }

    It "disable command prompt gpo linked to nottingham ou" -Skip {
        # Requires admin rights in child domain; manual evidence provided via gpresult.
        $gpo = Get-GPO -Name "Disable Command Prompt - Nottingham" -Server derby.bolton.local
        $gpo | Should -Not -BeNullOrEmpty
        $links = Get-GPLink -Guid $gpo.Id -Server derby.bolton.local
        $links | Where-Object { $_.Target -like "*OU=Nottingham*" } | Should -Not -BeNullOrEmpty
    }
}