Import-Module servermanager

$Global:sVars=@{}

## init dictionary with variables for server setup
## left hand side of the config.txt must be kept as-is for
## this script to work
Import-Csv c:\scripts\config.txt | 

ForEach {
    [string]$confLine=$_.ConfigVars

    $key,$val = $confLine.Split('=')

    $Global:sVars.Add($key,$val)
}


function Run-AutoADInstall {
    param([string]$DomainName, [string]$NetName)

    # ad domain dc info
    $DomainName = $Global:sVars['DomainName'] #"sungmin.ca"
    $NetName = $Global:sVars['NetName']       #"SUNGMIN"
    $winntds = $Global:sVars['WinNTDS']       #"C:\Windows\NTDS"
    $version = $Global:sVars['Version']       #"Win2012R2"
    $pass = (ConvertTo-SecureString $Global:sVars['Pass'] -AsPlainText -Force)
    $newDomain = ($Global:sVars['NewDomain'] -like "true")
    
    Write-Host "Installing Active Directory..." -ForegroundColor Green
    Add-WindowsFeature AD-Domain-Services -IncludeManagementTools -IncludeAllSubFeature

    Import-Module ADDSDeployment

    

    ## check if variable for new forest exists
    if($newDomain) {
        Write-Host "-Creating new forest and domain..." -ForegroundColor Green

        Install-ADDSForest `
            -CreateDnsDelegation:$false `
            -DatabasePath $winntds `
            -DomainMode $version `
            -DomainName $DomainName `
            -DomainNetBiosName $NetName `
            -ForestMode $version `
            -InstallDns:$true `
            -LogPath $winntds `
            -SysvolPath "C:\Windows\SYSVOL" `
            -NoRebootOnCompletion:$true `
            -Force:$true `
            -SafeModeAdministratorPassword $pass

       

    } else {
        $creds = New-Object System.Management.Automation.PSCredential ("Administrator@$DomainName", $pass)
        $repSource = $Global:sVars['ReplicationSourceDC']
        $siteName = $Global:sVars['SiteNameToAddTo']

        Write-Host "-Adding DC $($Global:sVars['DCName']) to site $siteName in $DomainName..." -ForegroundColor Green

        Install-ADDSDomainController `
            -NoGlobalCatalog:$false `
            -CreateDnsDelegation:$false `
            -Credential $creds `
            -CriticalReplicationOnly:$false `
            -DatabasePath $winntds `
            -DomainName $DomainName `
            -InstallDns:$true `
            -LogPath $winntds `
            -NoRebootOnCompletion:$true `
            -ReplicationSourceDC $repSource `
            -SiteName $siteName `
            -SysvolPath "C:\Windows\SYSVOL" `
            -Force:$true `
            -SafeModeAdministratorPassword $pass
    
    }
    
    ##Restart-Computer
    
}



$objShell = New-Object -ComObject "WScript.Shell"
$objShortCut = $objShell.CreateShortcut($env:USERPROFILE + "\Start Menu\Programs\Startup" + "\InstallDhcpWds.lnk")
$objShortCut.TargetPath ="c:\scripts\bat\InstallDhcpWds.bat"
$objShortCut.Save()

Run-AutoADInstall
Restart-Computer