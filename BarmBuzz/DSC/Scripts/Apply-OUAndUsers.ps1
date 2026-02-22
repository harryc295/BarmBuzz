# Load configuration data
$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = "DC-BOLTON"
            PSDscAllowPlainTextPassword = $true
        }
        @{
            NodeName = "DC-DERBY"
            PSDscAllowPlainTextPassword = $true
        }
    )
    NonNodeData = Import-PowerShellDataFile "$PSScriptRoot\..\Data\OUData.psd1"
}

# Compile the configuration
. $PSScriptRoot\..\Configurations\CreateOUAndUsers.ps1
CreateOUAndUsers -ConfigurationData $ConfigData -OutputPath "$PSScriptRoot\..\Configurations\OUAndUsers"

# Apply to both nodes
Start-DscConfiguration -Path "$PSScriptRoot\..\Configurations\OUAndUsers" -Wait -Verbose -Force