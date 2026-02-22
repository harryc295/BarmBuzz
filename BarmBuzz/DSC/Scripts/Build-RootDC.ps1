# Build-RootDC.ps1
$DomainCred = Get-Credential -Message "inputdomain admin user and password (use .\Administrator)"
$SafeModeCred = Get-Credential -Message "enter safe mode admin password"

. $PSScriptRoot\..\Configurations\RootDC.ps1
RootDC -DomainCred $DomainCred -SafeModeCred $SafeModeCred -OutputPath "$PSScriptRoot\..\Configurations\RootDC"

Start-DscConfiguration -Path "$PSScriptRoot\..\Configurations\RootDC" -Wait -Verbose -Force