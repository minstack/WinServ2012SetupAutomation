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



function Set-WDSServer {

    Install-WindowsFeature WDS -ComputerName $Global:sVars['DCName'] -IncludeManagementTools -IncludeAllSubFeature

}

function Init-WDSServer {   

    $dcname=$Global:sVars['DCName']
    $reminstall=$Global:sVars['WDSReminstDir']
    #$domain=$Global:sVars['DomainName']

    #wds boot image
    $bootWim = "$($Global:sVars['RemImagePath'])\boot.wim"
    $bootName = $Global:sVars['RemImageName']
    $bootDesc = $Global:sVars['RemImageDesc']

    #capture image
    $capImageName = $Global:sVars['CaptureImageName']
    $capImageDesc = $Global:sVars['CaptureImageDesc']
    $capImagePath = $reminstall + "\boot\x64\images\" + $Global:sVars['CaptureImageFileName']

    ## bool vals of whether configs set
    # REMOTE COPY
        $RunRemoteCopy = $Global:sVars['RemImagePath'] -and $Global:sVars['RemPass'] -and $Global:sVars['RemUser'] -and $bootName -and $bootDesc
    #
    # CAPTURE IMAGE
        $ProcessCaptureImage = $capImageName -and $capImageDesc

    # initiliaze the WDS server and start assuming it has been properly installed
    Start-WDSServer `
        -Server $dcname `
        -RemInstallDir $reminstall   

    if ($RunRemoteCopy){
        Get-BootImgRemote `
            -RemoteImagePath $Global:sVars['RemImagePath'] `
            -RemotePass $Global:sVars['RemPass'] `
            -User $Global:sVars['RemUser'] `
            -BootImageName $bootName `
            -BootImageDesc $bootDesc
    }
    

    if ($ProcessCaptureImage){
        
        Import-CaptureImageToWDS `
            -ImageNameToCopy $bootName `
            -Server $dcname `
            -Architecture x64 `
            -ImageToCopyFilename boot.wim `
            -CapImageName $capImageName `
            -CapDescription $capImageDesc `
            -CapImageFilename $Global:sVars['CaptureImageFileName']
           
    }
    
    $initialImageGroup = $Global:sVars['InitialImageGroup']
    if($initialImageGroup){
        $imagegrouppath = "$reminstall\images\$initialImageGroup"

        New-Item -Path $imagegrouppath -ItemType Directory
    }
   
 }

 function Start-WDSServer {
    param($Server, $RemInstallDir)
    
    Write-Host "Initializing WDS Server '$Server'..." -ForegroundColor Green
    wdsutil.exe /initialize-server /server:$Server /reminst:$RemInstallDir
    wdsutil.exe /set-server /AnswerClients:All /UseDhcpPorts:No /DhcpOption60:Yes
    wdsutil.exe /start-server
    wdsutil.exe /enable-server /server:$Server

 }

 function Get-BootImgRemote {
    param($RemoteImagePath, $RemotePass, $User, $BootImageName, $BootImageDesc)

    $bootWimPath = $RemoteImagePath + "\boot.wim"
    
    # can't seem to get Import-wdsbootimage from a remote secure share
    # this creates a netpath,logging in and copys the required boot.wim to c:
    # folder.  afterwards deletes this path as well as the boot.wim on c:
    net use z: $RemoteImagePath $RemotePass /user:$User

    Copy-Item $bootWimPath c:\

    Import-WdsBootImage -Path c:\boot.wim -NewImageName $bootImageName -NewDescription $BootImageDesc -SkipVerify

    Remove-Item c:\boot.wim

    net use z: /delete
 }

 function Import-CaptureImageToWDS {
    param($ImageNameToCopy, $Server, $Architecture, $ImageToCopyFilename, $CapImageName
    , $CapDescription, $CapImageFilename)

    $tempDir ="c:\tempmount"
    $tempCap = $tempDir + "\" + $CapImageFilename
    $capImagePath = $reminstall + "\boot\" + $Architecture + "\images\" + $CapImageFilename

    Write-Host "Creating Capture Image from '$ImageNameToCopy'..." -ForegroundColor Green

    mkdir $tempDir

    ## creates the capture image from the provided boot image
    ## then imports that image to WDS server
    wdsutil.exe /Verbose /Progress /New-CaptureImage /Image:$ImageNameToCopy /Server:$Server /Architecture:$Architecture /Filename:$ImageToCopyFilename /DestinationImage /FilePath:$tempCap /Name:$CapImageName /Description:$CapDescription /Overwrite:No
    Write-Host "Importing Image '$CapImageName' to WDS Server..." -ForegroundColor Green
    Import-WdsBootImage -Path $tempCap -SkipVerify

    rm $tempCap

    Write-Host "Patching winload.exe capture image error for '$CapImageName'..." -ForegroundColor Green
    ## DISM
    Fix-WinLoad -ImageFilePath $capImagePath -Index 1 -TempMountDir $tempDir

    rm -r $tempDir

 }
   

function Fix-WinLoad {
    param($ImageFilePath, $Index, $TempMountDir)

    dism /Mount-Image /ImageFile:$ImageFilePath /Index:$Index /MountDir:$TempMountDir
    dism /Unmount-Image /MountDir:$TempMountDir /commit
}


function Set-DHCPServer {
    
    #dhcp server info setup
    $comname = $Global:sVars['DCName']    #"DC01"
    $domain = $Global:sVars['DomainName'] #"sungmin.ca"
    $servIP = $Global:sVars['ServIp']     #"10.100.50.2"
    $dnsname = $Global:sVars['DnsCN']     #"$comname.$domain"

    ##for dns credentials
    $secpass = ConvertTo-SecureString "P@ssword" -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ("Administrator@$domain", $secpass)

    ## scope, dns
    $startRange = $Global:sVars['SRange'] #"10.100.50.100"
    $endRange = $Global:sVars['ERange']   #"10.100.50.150"
    $scopeName = $Global:sVars['ScopeName'] #"Assignment2"
    $subnet = $Global:sVars['Subnet']   #"255.255.255.0"
    $sheridanDns = $Global:sVars['Dns2'] #"142.55.100.25"
    $router = $Global:sVars['Gateway']   #"10.100.50.1"
    $scopeId = $Global:sVars['ScopeId']  #"10.100.50.0"

    ## reservation
    $ResCsv = $Global:sVars['Reservations'] #""
    Write-Host "Installing DHCP on '$comname'..." -ForegroundColor Green

    Install-WindowsFeature DHCP -IncludeManagementTools -IncludeAllSubFeature

    Write-Host "Initializing DHCP with configuration provided..." -ForegroundColor Green
    Add-DhcpServerInDc -DnsName $dnsname -IPAddress $servIP
    Add-DHCPServerSecurityGroup -ComputerName $comname
    Set-DHCPServerDnsCredential -ComputerName $comname -Credential $creds
    Add-DHCPServerv4Scope -EndRange $endRange -Name $scopeName -StartRange $startRange -SubnetMask $subnet -State Active
    Write-Host "Scope $startRange - $endRange Created..." -ForegroundColor Green

    Write-Host "DHCP Configuration for Clients:`nServer-$dnsname`nDNS:$servIP,$sheridanDns`nDomain:$domain`nRouter-$router`nScopeID-$scopeId" -ForegroundColor Green
    Set-DHCPServerv4OptionValue -ComputerName $dnsname -DnsServer ($servIP,$sheridanDns) -DnsDomain $domain -Router $router -ScopeId $scopeId

    if ($ResCsv) {
        Write-Host "Creating Reservations based on $ResCsv ..." -ForegroundColor Green        
        Set-DHCPReservationCsv -CSVPath "c:\scripts\bulk\$ResCsv" -ScopeID $scopeId
    }
    
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2

    Write-Host "Restarting DHCP Service..." -ForegroundColor Green
    Restart-Service -Name DHCPServer –Force
}

function Set-DHCPReservationCsv {
    param($CSVPath, $ScopeID)

    Import-Csv $CSVPath |
    foreach {
        Add-DhcpServerv4Reservation -Name $_.CName -ScopeId $ScopeID -IPAddress $_.IP -ClientId $_.Mac
    }  

}

function Set-ReverseZone{
    
    $netId = "$($Global:sVars['ScopeId'])/$($Global:sVars['Cidr'])"
    $dnsCN = $Global:sVars['DnsCN']

    $1oct,$2oct,$3oct,$4oct = $Global:sVars['ServIp'].ToString().Split('.')
    $revAddr = "$3oct.$2oct.$1oct.in-addr.arpa.dns"

    Write-Host "Creating Reverse Zone for $netId : $revAddr" -ForegroundColor Green
    Add-DnsServerPrimaryZone -NetworkID $netId -ZoneFile $revAddr

    $PTR = $revAddr.Substring(0,$revAddr.length-4)
    $fullPTRrev = "$4oct.$PTR"
    Write-Host "Creating PTR for $dnsCN : $fullPTRrev" -ForegroundColor Green
    Add-DnsServerResourceRecordPtr -Name $4oct -ZoneName $PTR -PtrDomainName $dnsCN

}

function Set-ARecordsCsv {
    param($CSVPath)

    Import-Csv $CSVPath |
    foreach {
        $ipOrAlias = [string]$_.IP

        if ($ipOrAlias -like "*$($Global:sVars['DomainName'])") {
            Add-DnsServerResourceRecordCName -Name $_.Name -HostNameAlias $ipOrAlias -ZoneName $_.ZoneName
        }
        else {
            Add-DnsServerResourceRecordA -Name $_.Name -IPv4Address $ipOrAlias -ZoneName $_.ZoneName
        }
        
    }
    

}

function Create-ADReplicationSiteCSV {
    param($CSVPath)

    Import-Csv $CSVPath | 
    foreach {

        $siteName = $_.SiteName

        Write-Host "Creating New AD Replication Site $siteName" -ForegroundColor Green
        New-ADReplicationSite $siteName

    }

}

function Create-ADSiteSubnetCSV {
    param($CSVPath)
     
    Import-Csv $CSVPath | 
    foreach {

        $subnetName = $_.SubnetName
        $site = $_.Site

        Write-Host "Creating New AD Replication Subnet: $subnetName Site: $site" -ForegroundColor Green
        New-ADReplicationSubnet -Name $subnetName -Site $site

    }

}

if ($Global:sVars['SRange']){
    Set-DHCPServer
}

Set-ReverseZone
# server reset for dns2
Write-Host "Resetting '$($Global:sVars['DCName'])' DNS1=127.0.0.1 DNS2=$($Global:sVars['Dns2'])..." -ForegroundColor Green
Set-DnsClientServerAddress -InterfaceIndex $Global:sVars['Interface'] -ServerAddresses ("127.0.0.1",$Global:sVars['Dns2'])


$csvfile = $Global:sVars['DnsArecordsCsv']
if ($csvfile) {
    
    $fullPath = "c:\scripts\bulk\$csvfile"

    Write-Host "Creating A-Records based on $csvfile ..." -ForegroundColor Green
    Set-ARecordsCsv -CSVPath $fullPath
}

if ($Global:sVars['WDSReminstDir']){
    Set-WDSServer
    Init-WDSServer
}

if ($Global:sVars['InstallIIS'] -like "true") {
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
}

## sites and subnets
if ($Global:sVars['AddSites'] -like "true") {
    Create-ADReplicationSiteCSV -CSVPath c:\scripts\bulk\sites.csv
    Write-Host "Renaming Default site to $($Global:sVars['MainSiteName'])" -ForegroundColor Green
    Get-ADReplicationSite -Filter 'Name -like "Default*"' | Rename-ADObject -NewName $Global:sVars['MainSiteName']
}

if ($Global:sVars['AddSiteSubnets'] -like "true") {
    Create-ADSiteSubnetCSV -CSVPath c:\scripts\bulk\sitesubnets.csv
}